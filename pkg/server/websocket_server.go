package server

import (
	"bytes"
	"encoding/base64"
	"fmt"
	"net"
	"net/http"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"github.com/gorilla/websocket"
	jsoniter "github.com/json-iterator/go"
	"github.com/projectdiscovery/gologger"
	stringsutil "github.com/projectdiscovery/utils/strings"
)

// WebSocketHandler manages WebSocket OOB interactions
type WebSocketHandler struct {
	options     *Options
	upgrader    websocket.Upgrader
	connTracker *ConnectionTracker
}

// ConnectionTracker limits connections per correlation ID
type ConnectionTracker struct {
	mu          sync.RWMutex
	connections map[string]int
	maxConn     int
}

// NewConnectionTracker creates a new connection tracker
func NewConnectionTracker(maxConn int) *ConnectionTracker {
	return &ConnectionTracker{
		connections: make(map[string]int),
		maxConn:     maxConn,
	}
}

// Add tries to add a connection for correlation ID, returns false if limit reached
func (ct *ConnectionTracker) Add(correlationID string) bool {
	ct.mu.Lock()
	defer ct.mu.Unlock()

	if ct.connections[correlationID] >= ct.maxConn {
		return false
	}
	ct.connections[correlationID]++
	return true
}

// Remove decrements the connection count for correlation ID
func (ct *ConnectionTracker) Remove(correlationID string) {
	ct.mu.Lock()
	defer ct.mu.Unlock()

	if ct.connections[correlationID] > 0 {
		ct.connections[correlationID]--
	}
	if ct.connections[correlationID] == 0 {
		delete(ct.connections, correlationID)
	}
}

// Count returns the current connection count for correlation ID
func (ct *ConnectionTracker) Count(correlationID string) int {
	ct.mu.RLock()
	defer ct.mu.RUnlock()
	return ct.connections[correlationID]
}

// NewWebSocketHandler creates a new WebSocket handler
func NewWebSocketHandler(options *Options) *WebSocketHandler {
	maxConn := options.WSMaxConnections
	if maxConn <= 0 {
		maxConn = 10 // default max connections per correlation ID
	}

	return &WebSocketHandler{
		options: options,
		upgrader: websocket.Upgrader{
			ReadBufferSize:  1024,
			WriteBufferSize: 1024,
			// Allow all origins for OOB testing (this is intentional for security testing)
			CheckOrigin: func(r *http.Request) bool {
				return true
			},
		},
		connTracker: NewConnectionTracker(maxConn),
	}
}

// HandleWebSocket handles WebSocket upgrade requests
// Supports two modes:
// 1. /ws - correlation ID extracted from Host header subdomain
// 2. /ws/{id} - correlation ID in path
func (ws *WebSocketHandler) HandleWebSocket(w http.ResponseWriter, r *http.Request) {
	atomic.AddUint64(&ws.options.Stats.Websocket, 1)

	// Extract correlation ID from subdomain or path
	correlationID, fullID := ws.extractCorrelationID(r)
	if correlationID == "" {
		gologger.Debug().Msgf("WebSocket: No correlation ID found in request")
		http.Error(w, "Bad Request", http.StatusBadRequest)
		return
	}

	// Check connection limit
	if !ws.connTracker.Add(correlationID) {
		gologger.Debug().Msgf("WebSocket: Connection limit reached for %s", correlationID)
		http.Error(w, "Too Many Connections", http.StatusTooManyRequests)
		return
	}
	defer ws.connTracker.Remove(correlationID)

	// Capture upgrade request for logging
	upgradeRequest := ws.buildUpgradeRequestString(r)

	// Get remote address
	var host string
	if originIP := r.Header.Get(ws.options.OriginIPHeader); originIP != "" {
		host = originIP
	} else {
		host, _, _ = net.SplitHostPort(r.RemoteAddr)
	}

	// Record the WebSocket connection interaction
	ws.recordInteraction(correlationID, fullID, "websocket", upgradeRequest, "", host, r)

	// Upgrade connection to WebSocket
	conn, err := ws.upgrader.Upgrade(w, r, nil)
	if err != nil {
		gologger.Debug().Msgf("WebSocket: Upgrade failed for %s: %v", correlationID, err)
		return
	}
	defer conn.Close()

	gologger.Debug().Msgf("WebSocket: Connection established for %s from %s", correlationID, host)

	// Set connection parameters
	timeout := time.Duration(ws.options.WSTimeout) * time.Second
	if timeout <= 0 {
		timeout = 60 * time.Second // default 60 seconds
	}
	maxMsgSize := ws.options.WSMaxMessageSize
	if maxMsgSize <= 0 {
		maxMsgSize = 1024 * 1024 // default 1MB
	}

	conn.SetReadLimit(int64(maxMsgSize))
	_ = conn.SetReadDeadline(time.Now().Add(timeout))

	// Pong handler to extend deadline
	conn.SetPongHandler(func(string) error {
		_ = conn.SetReadDeadline(time.Now().Add(timeout))
		return nil
	})

	// Handle incoming messages
	ws.captureMessages(conn, correlationID, fullID, host, r)
}

// extractCorrelationID extracts correlation ID from the request
// Priority: 1. Path parameter 2. Subdomain
func (ws *WebSocketHandler) extractCorrelationID(r *http.Request) (correlationID, fullID string) {
	// Try path-based extraction: /ws/{id}
	path := strings.TrimPrefix(r.URL.Path, "/ws/")
	path = strings.TrimPrefix(path, "/ws")
	path = strings.TrimPrefix(path, "/")

	if path != "" && len(path) >= ws.options.GetIdLength() {
		for part := range stringsutil.SlideWithLength(path, ws.options.GetIdLength()) {
			normalizedPart := strings.ToLower(part)
			if ws.options.isCorrelationID(normalizedPart) {
				return normalizedPart[:ws.options.CorrelationIdLength], path
			}
		}
	}

	// Try subdomain-based extraction
	parts := strings.Split(r.Host, ".")
	for i, part := range parts {
		for partChunk := range stringsutil.SlideWithLength(part, ws.options.GetIdLength()) {
			normalizedPartChunk := strings.ToLower(partChunk)
			if ws.options.isCorrelationID(normalizedPartChunk) {
				fullID = part
				if i+1 <= len(parts) {
					fullID = strings.Join(parts[:i+1], ".")
				}
				return normalizedPartChunk[:ws.options.CorrelationIdLength], fullID
			}
		}
	}

	// Scan everywhere if enabled
	if ws.options.ScanEverywhere {
		reqStr := fmt.Sprintf("%s %s %s", r.Method, r.URL.String(), r.Host)
		for k, v := range r.Header {
			reqStr += fmt.Sprintf(" %s:%s", k, strings.Join(v, ","))
		}
		chunks := stringsutil.SplitAny(reqStr, ".\n\t\"'/")
		for _, chunk := range chunks {
			for part := range stringsutil.SlideWithLength(chunk, ws.options.GetIdLength()) {
				normalizedPart := strings.ToLower(part)
				if ws.options.isCorrelationID(normalizedPart) {
					return normalizedPart[:ws.options.CorrelationIdLength], part
				}
			}
		}
	}

	return "", ""
}

// buildUpgradeRequestString builds a string representation of the upgrade request
func (ws *WebSocketHandler) buildUpgradeRequestString(r *http.Request) string {
	var builder strings.Builder

	// Request line
	builder.WriteString(fmt.Sprintf("%s %s %s\n", r.Method, r.URL.RequestURI(), r.Proto))

	// Host header
	builder.WriteString(fmt.Sprintf("Host: %s\n", r.Host))

	// Other headers
	for key, values := range r.Header {
		for _, value := range values {
			builder.WriteString(fmt.Sprintf("%s: %s\n", key, value))
		}
	}

	return builder.String()
}

// captureMessages reads and records WebSocket messages
func (ws *WebSocketHandler) captureMessages(conn *websocket.Conn, correlationID, fullID, host string, r *http.Request) {
	for {
		messageType, message, err := conn.ReadMessage()
		if err != nil {
			// Check if it's a close error
			if closeErr, ok := err.(*websocket.CloseError); ok {
				closeReason := fmt.Sprintf("WebSocket closed: code=%d, reason=%s", closeErr.Code, closeErr.Text)
				ws.recordInteraction(correlationID, fullID, "websocket-close", closeReason, "", host, r)
				gologger.Debug().Msgf("WebSocket: Connection closed for %s: %v", correlationID, closeErr)
			} else {
				gologger.Debug().Msgf("WebSocket: Read error for %s: %v", correlationID, err)
			}
			return
		}

		// Determine protocol type based on message type
		protocol := "websocket-message"
		var rawRequest string

		switch messageType {
		case websocket.TextMessage:
			rawRequest = string(message)
			gologger.Debug().Msgf("WebSocket: Received text message for %s: %s", correlationID, rawRequest)
		case websocket.BinaryMessage:
			protocol = "websocket-binary"
			// Encode binary data as base64 for storage
			rawRequest = base64.StdEncoding.EncodeToString(message)
			gologger.Debug().Msgf("WebSocket: Received binary message for %s (%d bytes)", correlationID, len(message))
		case websocket.PingMessage:
			// Respond with pong
			_ = conn.WriteMessage(websocket.PongMessage, message)
			continue
		case websocket.PongMessage:
			// Pong received, update deadline already handled
			continue
		default:
			gologger.Debug().Msgf("WebSocket: Unknown message type %d for %s", messageType, correlationID)
			continue
		}

		// Record the message interaction
		ws.recordInteraction(correlationID, fullID, protocol, rawRequest, "", host, r)
	}
}

// recordInteraction stores a WebSocket interaction
func (ws *WebSocketHandler) recordInteraction(correlationID, fullID, protocol, rawRequest, rawResponse, host string, r *http.Request) {
	interaction := &Interaction{
		Protocol:      protocol,
		UniqueID:      fullID,
		FullId:        fullID,
		RawRequest:    rawRequest,
		RawResponse:   rawResponse,
		RemoteAddress: host,
		Timestamp:     time.Now(),
	}

	buffer := &bytes.Buffer{}
	if err := jsoniter.NewEncoder(buffer).Encode(interaction); err != nil {
		gologger.Warning().Msgf("Could not encode websocket interaction: %s\n", err)
		return
	}

	gologger.Debug().Msgf("WebSocket Interaction: \n%s\n", buffer.String())

	if err := ws.options.Storage.AddInteraction(correlationID, buffer.Bytes()); err != nil {
		gologger.Warning().Msgf("Could not store websocket interaction: %s\n", err)
	}
}

// HandleWebSocketWithPathID handles WebSocket requests with correlation ID in path
func (ws *WebSocketHandler) HandleWebSocketWithPathID(w http.ResponseWriter, r *http.Request) {
	// Same handler, ID extraction from path is automatic
	ws.HandleWebSocket(w, r)
}
