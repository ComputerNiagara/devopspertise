<#
    .SYNOPSIS
      Gets all Network Security Groups (NSG) security rules and dumps them to JSON format.
    .PARAMETER Subscription
      The name of the subscription that you want to target.
    .DESCRIPTION
      This script creates JSON files (ARM templates) for each NSG detected in the subscription specified.

      Script will create a file for each NSG, same as "Export to Template" in the Azure Portal.

      Designed for Azure DevOps pipeline usage.
    .NOTES
      Version: 1.0
      Author:  Lucas Jackson
      Date:    09/25/2020
    .EXAMPLE
      .\Get-AzNetworkSecurityGroupSecurityRules.ps1 -Subscription "Subscription01"
    .LINK
      https://www.devopspertise.com
#>

param(
      [Parameter(Mandatory = $true)]
      [ValidateNotNullorEmpty()]
      [String]$Subscription,

      [Parameter(Mandatory = $false)]
      [ValidateNotNullorEmpty()]
      [String]$Path = $env:SYSTEM_DEFAULTWORKINGDIRECTORY
)

$ErrorActionPreference = "Stop"

Try {

  $Path = "$Path\nsgRules\$Subscription"

  Write-Host "Targeting Subscription -> $Subscription`n"
  Set-AzContext -Subscription $Subscription

  Write-Host "Retrieving current status of Network Security Groups from $Subscription..."
  $nsgs = Get-AzNetworkSecurityGroup
  Write-Host "Found" $nsgs.Count "NSGs...`n"

  Write-Host "Creating output directory at $Path"
  mkdir "$Path" -Force | Out-Null

  foreach ($nsg in $nsgs)
  {
    $name = $nsg.Name
    Write-Host "Exporting NSG rules for $name"

    Export-AzResourceGroup -ResourceGroupName $nsg.ResourceGroupName -Resource $nsg.Id -Path "$Path\$name.json" -Force
  }

  Write-Host "Ready for upload to blob storage from $Path"

  exit 0
}
Catch {
      Write-Host $error[0] -ForegroundColor "Red"
      exit 10
}