package options

import (
	"github.com/projectdiscovery/gologger"
	"github.com/projectdiscovery/utils/auth/pdcp"
	updateutils "github.com/projectdiscovery/utils/update"
)

const Version = "1.0.0"

var banner = (`
  _  __                         ______     _           
 | |/ /__ _ _ __ _ __ ___   __ _|  ____|___| |__   ___  
 | ' // _' | '__| '_ ' _ \ / _' | |__  / __| '_ \ / _ \ 
 | . \ (_| | |  | | | | | | (_| |  __|| (__| | | | (_) |
 |_|\_\__,_|_|  |_| |_| |_|\__,_|_____|\___| | |_|\___/ 
`)

func ShowBanner() {
	gologger.Print().Msgf("%s\n", banner)
	gologger.Print().Msgf("\t\tkarmagate.com\n\n")
}

// GetUpdateCallback returns a callback function that updates karmaecho
func GetUpdateCallback(assetName string) func() {
	return func() {
		ShowBanner()
		updateutils.GetUpdateToolFromRepoCallback(assetName, Version, "karmaecho")()
	}
}

// AuthWithPDCP is used to authenticate with PDCP
func AuthWithPDCP() {
	ShowBanner()
	pdcp.CheckNValidateCredentials("karmaecho")
}
