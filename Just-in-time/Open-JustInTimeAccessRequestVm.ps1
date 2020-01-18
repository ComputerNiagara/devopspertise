<#
    .SYNOPSIS 
      Starts a 3 hour Just-in-time (JIT) session for a virtual machine.
    .PARAMETER Subscription
      Subscription to target.
    .PARAMETER ResourceGroupName
      Name of the resource group where the VM resides.
    .PARAMETER Name
      Name of the Virtual Machine (VM).
    .PARAMETER PortNumber
      Port number that you would like to open (22,3389,5585,5586).
    .DESCRIPTION
      In short, JIT is basically a dynamic Network Security Group (NSG) rule. Once a VM has a JIT policy applied, a user must request access to a VM.
      If the user has the appropriate Role Based Access Control (RBAC), then the request will be granted, otherwise it will be denied.
      Azure Security Center (ASC) automatically configures the NSG and Azure Firewall to allow inbound traffic to the selected ports and requested source IP addresses or ranges, for the amount of time that was specified.
      After the time has expired, Security Center restores the NSGs to their previous states. Those connections that are already established are not being interrupted, however.

      More information is available here: https://docs.microsoft.com/en-us/azure/security-center/security-center-just-in-time
      RBAC permissions needed to configure and use JIT are available here: https://docs.microsoft.com/en-us/azure/security-center/security-center-just-in-time#permissions-needed-to-configure-and-use-jit

      This script will send a "Request Access" operation for a VM that has a JIT access policy enabled.
      
      Location is hard-coded to canadacentral, change it if required.

      This script is for users who want to request access programmatically versus using the Azure Portal.
      You can request access using the Azure Portal by going to the VM and clicking Connect, or by going to ASC and clicking on Just in time VM access.

      Common use cases for this script is when you want to use the management ports of a VM, eg. SSH (port 22) or RDP (port 3389). By default the access request asks that the port be opened for a duration of 3 hours.
      Any connection established during the 3 hour window that persists after the window expires will stay active.    

      Start-AzJitNetworkAccessPolicy cmdlet currently doesn't support the param allowedSourceAddressPrefixes, however the REST API does, therefore we are forced to use a REST API instead of the cmdlet.

      Required modules:
      - Az.Accounts
      - Az.Compute
      - Az.Security
    .NOTES
      Version: 1.0
      Author:  Lucas Jackson
      Date:    1/18/2020
    .EXAMPLE
     .\Open-JustInTimeAccessRequestVm.ps1 -Subscription "Subscription01" -ResourceGroupName "ResourceGroup01" -Name "Server01" -PortNumber 3389

      Requests access to a Virtual Machine over port 3389 (Remote Desktop Port).
    .LINK
      https://www.devopspertise.com
#>

param(
      [String]$Location = "canadacentral",

      [Parameter(Mandatory = $true)]
      [ValidateNotNullorEmpty()]
      [String]$Subscription,
      
      [Parameter(Mandatory = $true)]
      [ValidateNotNullorEmpty()]
      [String]$ResourceGroupName,

      [Parameter(Mandatory = $true)]
      [ValidateNotNullorEmpty()]
      [String]$Name,

      [Parameter(Mandatory = $true)]
      [ValidateSet(22,3389,5585,5586)]
      [ValidateNotNullorEmpty()]
      [Int]$PortNumber

)

$ErrorActionPreference = "Stop"

Write-Host "$Subscription subscription selected`n"

Try {
      # Set Context
      $azContext = Set-AzContext -Subscription $Subscription
      $subscriptionId = $azContext.Subscription.Id

      # Get Bearer token for REST API from the current authenticated session
      $azProfile = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile
      $profileClient = New-Object Microsoft.Azure.Commands.ResourceManager.Common.RMProfileClient($azProfile)
      Write-Host "Getting Bearer token for current session...`n"
      $token = $profileClient.AcquireAccessToken($azContext.Tenant.TenantId)
      $tokenBearer = ('Bearer {0}' -f ($token.AccessToken))

      # Get the VM
      $vmTarget = Get-AzVm -Name $Name -ResourceGroup $ResourceGroupName

      # Get the ASC JIT Access Policy for the Resource Group
      Write-Host "Getting corresponding Azure Security Center Just-in-time access policy for $Name"
      $jitPolicy = Get-AzJitNetworkAccessPolicy -ResourceGroupName $ResourceGroupName -Name "default" -Location $Location

      # Determine if there is a JIT Access Policy associated to the VM
      # Since each entry is unique, we can use IndexOf to determine the allowedSourceAddressPrefix(es)
      $arrayJitPolicy = $jitPolicy.VirtualMachines.Id
      foreach($vm in $arrayJitPolicy) {
            if($vm -eq $vmTarget.Id) {
                  $foundPolicy = $true
                  $arrayIndexVM = $arrayJitPolicy.IndexOf($vm)
                  $arrayAllowedSourcePorts = $jitPolicy.VirtualMachines[$arrayIndexVM].Ports.Number
                  foreach($port in $arrayAllowedSourcePorts) {
                        if($port -eq $PortNumber) {
                              $arrayIndexPort = $arrayAllowedSourcePorts.IndexOf($port)
                              $arrayAllowedSourceAddressPrefix = $jitPolicy.VirtualMachines[$arrayIndexVM].Ports[$arrayIndexPort].AllowedSourceAddressPrefix
                              $arrayAllowedSourceAddressPrefixes = $jitPolicy.VirtualMachines[$arrayIndexVM].Ports[$arrayIndexPort].AllowedSourceAddressPrefixes
                              if($foundPolicy -and ($arrayAllowedSourceAddressPrefix -or $arrayAllowedSourceAddressPrefixes)) {
                                    Write-Host ("Found: " + $jitPolicy.Id)
                                    if($arrayAllowedSourceAddressPrefix) {
                                          Write-Host "AllowedSourceAddressPrefix: $arrayAllowedSourceAddressPrefix"
                                    } else {
                                          Write-Host "AllowedSourceAddressPrefixes: $arrayAllowedSourceAddressPrefixes"
                                    }
                                    $justication = "Automated JIT Access Request"
                              }
                              break
                        }
                  }
                  break
            }
      }
      if(!$foundPolicy) {
            Write-Host "`nERROR: Could not find corresponding Azure Security Center Just-in-time access policy for $Name" -ForegroundColor "Red"
            exit 20
      }
            
      # Build the JIT policy request
      # Build request header and body to pass with REST API request
      if($arrayAllowedSourceAddressPrefix) {
            $JitPolicyVm = (@{
                  virtualMachines=(@(@{
                  id=$vmTarget.Id
                  ports=(@(@{
                  number=$PortNumber;
                  endTimeUtc=[DateTime]::UtcNow.AddHours(3);
                  allowedSourceAddressPrefix=$arrayAllowedSourceAddressPrefix}))}))
                  justification=$justication})
      }
      elseif($arrayAllowedSourceAddressPrefixes) {
            $JitPolicyVm = (@{
                  virtualMachines=(@(@{
                  id=$vmTarget.Id
                  ports=(@(@{
                  number=$PortNumber;
                  endTimeUtc=[DateTime]::UtcNow.AddHours(3);
                  allowedSourceAddressPrefixes=@($arrayAllowedSourceAddressPrefixes)}))}))
                  justification=$justication})
      }
      else {
            Write-Host "`nERROR: Could not find AllowedSourceAddressPrefix(es) for port $PortNumber" -ForegroundColor "Red"
            exit 21
      }

      $requestBody = $JitPolicyVm | ConvertTo-Json -Depth 5

      $requestHeader = @{
            'Authorization'=$tokenBearer
      }

      # Request access to VM using REST API
      $uri = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Security/locations/$Location/jitNetworkAccessPolicies/default/initiate?api-version=2015-06-01-preview"
      Write-Host "`nRequesting Just-in-time access to $Name for 3 hours"
      Write-Host $requestBody`n
      Write-Host $uri`n
      Invoke-RestMethod -Uri $uri -Headers $requestHeader -Body $requestBody -Method POST -ContentType 'application/json'

      # Request access to the VM using PowerShell
      # Cannot use this method since cmdlet does not support allowedSourceAddressPrefixes at time of script creation
      #$JitPolicyArr=@($JitPolicy)
      #Write-Host "Requesting Just-in-time access to $Name for 3 hours"
      #Start-AzJitNetworkAccessPolicy -ResourceId $jitPolicy.Id -VirtualMachine $JitPolicyArr
}
Catch {
      Write-Host $error[0] -ForegroundColor "Red"
      exit 10
}