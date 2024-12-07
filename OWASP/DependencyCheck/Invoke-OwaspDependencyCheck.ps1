<#
 	.SYNOPSIS 
	Runs OWASP Dependency-Check.

	.DESCRIPTION
	This script if required will install or upgrade the OWASP Dependency-Check based on DevOps variable group configuration.

	Subsequently it will run the tool against the sources for the project.

	For more detailed information about OWASP Dependency-Check, visit the DevOps Wiki or Repository.

	.EXAMPLE
	PS> .\Invoke-OwaspDependencyCheck.ps1
	Runs OWASP Dependency-Check 

	.NOTES
	Author: Lucas Jackson
	Date: December 18, 2023
#>

$ErrorActionPreference = 'Stop'

# Verify the url is the same as expected version, without this check it could force unnecessary re-install of OWASP Dependency-Check on each run.
If(!($env:ODC_URLDOWNLOAD -like "*$env:ODC_REQUIREVERSION*")) {
	Write-Host "Please verify variable group values, there is a version mismatch between odcUrlDownload and odcRequireVersion.`nThese two variables should be in alignment.`n`nodcUrlDownload: $env:ODC_URLDOWNLOAD`nodcRequireVersion: $env:ODC_REQUIREVERSION`n`nExiting."
	exit 1
}

# Look for OWASP Dependency-Check CLI and verify version.
If(Test-Path "$env:ODC_PATHCLI") {
	Write-Host "Executable found: $env:ODC_PATHCLI`n"
	$versionCli=Invoke-Expression "$env:ODC_PATHCLI -v"
	Write-Host $versionCli
	
	If($versionCli -like "*$env:ODC_REQUIREVERSION*") {
		Write-Host "Version is as expected: v$env:ODC_REQUIREVERSION`n"
	}
	Else {
		Write-Host "Version mismatch, expected: v$env:ODC_REQUIREVERSION`nRe-installing.`n"
		$flagInstall = $true
	}
}
else {
	Write-Host "Executable not found. Will attempt install.`n"
	$flagInstall = $true
}

# If install flag is raised, OWASP Dependency-Check will be downloaded and installed.
If($flagInstall) {
	Write-Host "Downloading OWASP Dependency-Checker from $env:ODC_URLDOWNLOAD`n"
	Invoke-WebRequest $env:ODC_URLDOWNLOAD -OutFile "$env:AGENT_TEMPDIRECTORY\dependency-check.zip"

	if($env:ODC_PATHDELETE -like "*dependency-check*") {
		Write-Host "Deleting $env:ODC_PATHDELETE if it exists.`n"
		Remove-Item -Path $env:ODC_PATHDELETE -Force -Recurse -ErrorAction SilentlyContinue
	}

	Write-Host "Extracting to $env:ODC_PATHINSTALL.`n"
	Add-Type -AssemblyName System.IO.Compression.FileSystem ; [System.IO.Compression.ZipFile]::ExtractToDirectory("$env:AGENT_TEMPDIRECTORY\dependency-check.zip", "$env:ODC_PATHINSTALL")
}

# Run OWASP Dependency-Check against the sources directory for the project and produce a report in the Agent temp directory for artifact publishing.
Write-Host "Running OWASP dependency-check"
Invoke-Expression "$env:ODC_PATHCLI --project '$env:ODC_PROJECTNAME' --scan '$env:BUILD_SOURCESDIRECTORY' --out '$env:BUILD_ARTIFACTSTAGINGDIRECTORY' --format HTML --format JSON --format JUNIT --nvdApiKey '$env:ODC_NVDAPIKEY'"