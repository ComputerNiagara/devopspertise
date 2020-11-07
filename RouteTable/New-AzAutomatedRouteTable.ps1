<#
    .SYNOPSIS
      Creates a New Route Table based on Azure IP Ranges and Service Tags file from Microsoft.
    .PARAMETER Subscription
      The name of the Subscription that you want to target.
    .PARAMETER ResourceGroupName
      Destination Rresource Group for the new Route Table, in the same Subscription.
    .PARAMETER AssociateSubnets
      Feature toggle to associate subnets after Route Table creation.
    .PARAMETER Cleanup
      Feature toggle to delete old unassigned Route Tables.
    .DESCRIPTION
      This script downloads the latest Azure IP Ranges and Service Tags file from Microsoft.

      It finds all AzureCloud.canadacentral and AzureCloud.canadaeast routes and automates their creation.

      Default route is also applied.

      The new Route Table is then created with all routes in the Subscription and Resource Group defined.

      Route Table can be associated using the AssociateSubnets feature flag.
    .NOTES
      Version: 1.0
      Author:  Lucas Jackson
      Date:    10/25/2020
    .LINK
      https://www.devopspertise.com
    .EXAMPLE
      Creates a new Azure Route Table in ResourceGroupName01 within Subscription01.

      The Route Table is then assigned if associations are defined in the script.

      Unassigned Routes Tables with certain filter are deleted - n-2 is kept.
      .\New-AzAutomatedRouteTable.ps1 -Subscription "Subscription01" -ResourceGroupName "ResourceGroupName01" -AssociateSubnets $true -Cleanup $true
#>

param(
      [Parameter(Mandatory = $true)]
      [ValidateNotNullorEmpty()]
      [String]$Subscription,

      [Parameter(Mandatory = $true)]
      [ValidateNotNullorEmpty()]
      [String]$ResourceGroupName,

      [Parameter(Mandatory = $true)]
      [ValidateNotNullorEmpty()]
      [Bool]$AssociateSubnets,

      [Parameter(Mandatory = $true)]
      [ValidateNotNullorEmpty()]
      [Bool]$Cleanup
)

$ErrorActionPreference = "Stop"

Try {

    Write-Host "Targeting Subscription -> $Subscription`n"
    Select-AzSubscription -SubscriptionName $Subscription

    Write-Host "`nChecking existence of Resource Group -> $ResourceGroupName"
    Get-AzResourceGroup -Name $ResourceGroupName

    # Azure IP Ranges and Service Tags Uri
    $uri = "https://www.microsoft.com/en-us/download/confirmation.aspx?id=56519"

    # Getting date in EST format since this runs on agent
    $dateEst = [System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId((Get-Date), "Eastern Standard Time")
    $date = Get-Date $dateEst -format "yyyyMMddHHmm"
    $routes = @()

    # Determine Subscription Route Table naming and associations
    # !!! Update this section to on-board your Subscription and Subnet associations !!!
    $nameRouteTableCleanupFilter = "routeTable-*"
    $nameRouteTable = "routeTable-$date"
    Switch ($Subscription) {
        "Subscription01" {
            $associations = @(
                @{virtualNetwork="vnet01"; subnet="vnetsubnet01"}
                @{virtualNetwork="vnet01"; subnet="vnetsubnet02"}
            )
        }
        "Subscription02" {
            $associations = @(
                @{virtualNetwork="vnet01"; subnet="vnetsubnet01"}
                @{virtualNetwork="vnet01"; subnet="vnetsubnet02"}
            )
        }
        default {
            Write-Host "`n$Subscription is not defined, please on-board $Subscription to continue."
            exit 0
        }
    }
    Write-Host "`nAzure Route Table will be named -> $nameRouteTable"

    # Download "Azure IP Ranges and Service Tags" file from Microsoft and parse direct link from web request
    # Current format: ServiceTags_Public_20200928.json
    # Set up resource tags for tracking
    Write-Host "`nQuerying Azure IP Ranges and Service Tags -> $uri"
    $uriIpRange = Invoke-WebRequest -Uri $uri -UseBasicParsing
    $uriDirect = $uriIpRange.Links | Select-Object href | Where-Object href -Like "*download.microsoft.com*"

    if ($uriDirect) {
        Write-Host "`nParsed download location ->" $uriDirect.href[0]
        $fileName = $uriDirect.href[0] | Split-Path -Leaf
        $tags = @{sourceTruthFile=$fileName;sourceTruthUri=$uriDirect.href[0]}
        Write-Host "`nSet sourceTruthFile tag ->" $tags.sourceTruthFile
        Write-Host "`nSet sourceTruthUri tag ->" $tags.sourceTruthUri
        if($env:Build_BuildId) {
            $tags += @{devOpsBuildUri="$env:System_TeamFoundationCollectionUri$env:System_TeamProject/_build/results?buildId=$env:Build_BuildId&view=results"}
        }
    }
    else {
        Write-Host "`nCould not parse download location.`nValidate the Uri is accessible -> $uri" -ForegroundColor "Red"
        exit 11
    }

    # Get all existing Route Tables in the Subscription
    # Check for new release based against sourceTruthFile tag, we are only checking uniqueness
    # We could check for gt/lt, but uniqueness works best in this scenario
    $routeTables = Get-AzRouteTable
    foreach ($tag in $routeTables.Tag.sourceTruthFile) {
        if($tag -eq $fileName) {
            Write-Host "`nMatching Route Table found with sourceTruthFile tag -> $tag" -ForegroundColor "Green"
            Write-Host "Route Table is current - no update required." -ForegroundColor "Green"
            exit 0
        }
    }

    # Import JSON file to PSObject then filter on canadacentral and canadaeast independently
    $jsonIpRange = Invoke-WebRequest -Uri $uriDirect.href[0] -UseBasicParsing | ConvertFrom-Json
    $filteredIpRangeCc = $jsonIpRange.values | Where-Object {$_.id -like "AzureCloud.canadacentral"}
    $filteredIpRangeCe = $jsonIpRange.values | Where-Object {$_.id -like "AzureCloud.canadaeast"}
    $count = 0
    Write-Host "`nGenerating routes..."

    # Check if all routes are found
    if ($filteredIpRangeCc -and $filteredIpRangeCe) {
        Write-Host "`nFound routes for canadacentral and canadaeast."
        Write-Host "AzureCloud.canadacentral Routes found ->" $filteredIpRangeCc.properties.addressPrefixes.Count "routes"
        Write-Host "AzureCloud.canadaeast Routes found ->" $filteredIpRangeCe.properties.addressPrefixes.Count "routes`n"
    }
    else {
        Write-Host "`nCould not find all routes." -ForegroundColor "Red"
        Write-Host "AzureCloud.canadacentral Routes found ->" $filteredIpRangeCc.properties.addressPrefixes.Count "routes"
        Write-Host "AzureCloud.canadaeast Routes found ->" $filteredIpRangeCe.properties.addressPrefixes.Count "routes"
        exit 12
    }
    # Add each route based for canadacentral
    foreach ($addressPrefix in $filteredIpRangeCc.properties.addressPrefixes) {
        $name = "AzureCloud-canadacentral-{0:0000}" -f $count
        Write-Host $name "->" $addressPrefix "~ Internet"
        $routes += New-AzRouteConfig -Name $name -AddressPrefix $addressPrefix -NextHopType "Internet"
        $count++
    }

    # Add each route based for canadaeast
    foreach ($addressPrefix in $filteredIpRangeCe.properties.addressPrefixes) {
        $name = "AzureCloud-canadaeast-{0:0000}" -f $count
        Write-Host $name "->" $addressPrefix "~ Internet"
        $routes += New-AzRouteConfig -Name $name -AddressPrefix $addressPrefix -NextHopType "Internet"
        $count++
    }

    # Add default route
    # !!! Update this section and add your default route !!!
    $name = "defaultRoute-{0:0000}" -f $count
    Write-Host $name "-> 0.0.0.0/0 ~ VirtualAppliance 192.168.0.4"
    $routes += New-AzRouteConfig -Name $name -AddressPrefix "0.0.0.0/0" -NextHopType "VirtualAppliance" -NextHopIpAddress "192.168.0.4"
    $count++

    Write-Host "`n$count routes were generated."

    # Create Route Table
    Write-Host "`nCreating Azure Route Table -> $nameRouteTable"
    $routeTable = New-AzRouteTable -Name $nameRouteTable -ResourceGroupName $ResourceGroupName -Location "canadacentral" -Route $routes -Tag $tags
    Write-Host "Azure Route Table was created successfully -> $nameRouteTable"

    # Apply associations, only if they exist and feature is toggled
    if($AssociateSubnets -and $associations) {
        Write-Host "`nAssigning Route Table..."

        foreach ($association in $associations) {
            Write-Host $association.virtualNetwork "->" $association.subnet
            $virtualNetwork = Get-AzVirtualNetwork -Name $association.virtualNetwork
            $subnet = $virtualNetwork | Get-AzVirtualNetworkSubnetConfig -Name $association.subnet
            Set-AzVirtualNetworkSubnetConfig -Name $association.subnet -VirtualNetwork $virtualNetwork -AddressPrefix $subnet.AddressPrefix -RouteTable $routeTable | Out-Null

            Write-Host "`nUpdating Virtual Network configuration..."
            $virtualNetwork | Set-AzVirtualNetwork | Out-Null
        }
    }

    # Cleanup old unassigned Route Tables - keep n-2
    if($Cleanup) {
        Write-Host "`nFinding unassigned Route Tables with pattern -> $nameRouteTableCleanupFilter"
        $routeTablesAutomation = Get-AzRouteTable | Where-Object Name -like $nameRouteTableCleanupFilter | Sort-Object -Property Name
        $count = $routeTablesAutomation.Count
        Write-Host "`n$count Route Tables were found."
        $routeTablesAutomation.Name
        if($count -le 3) {
            Write-Host "`nNo cleanup required (n-2)."
            exit 0
        }
        while ($count -gt 3) {
            foreach($routeTable in $routeTablesAutomation) {
                if($routeTable.Subnets.Count -gt 0) {
                    Write-Host "`nCannot delete old Route Table ->" $routeTable.Name "`nRoute Table is assigned to:"
                    $routeTable.Subnets.Id
                    $count--
                }
                else {
                    Write-Host "`nDeleting old Route Table ->" $routeTable.Name
                    Remove-AzRouteTable -ResourceGroupName $routeTable.ResourceGroupName -Name $routeTable.Name -Force
                    Write-Host "Route Table deleted ->" $routeTable.Name
                    $count--
                }
                if($count -le 3) {
                    break
                }
            }
        }
        Write-Host "`nCleanup complete."
    }

    Write-Host "`nSUCCESS!`nAzure Route Table automation has completed successfully." -ForegroundColor "Green"
    exit 0
}
Catch {
    Write-Host $error[0] -ForegroundColor "Red"
    exit 10
}