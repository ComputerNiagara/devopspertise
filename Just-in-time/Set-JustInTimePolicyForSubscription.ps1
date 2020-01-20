<#
    .SYNOPSIS 
      Configures a Just-in-time (JIT) access policy on all Virtual Machines (VM) within a subscription.
    .PARAMETER Subscription
      Subscription to target.
    .PARAMETER AllowedSourceAddressPrefixes
      Source subnets allowed for JIT access profile.
    .PARAMETER ResourceGroupName
      Resource Group Name to target. (Optional)
    .DESCRIPTION
      In short, JIT is basically a dynamic Network Security Group (NSG) rule. Once a VM has a JIT policy applied, a user must request access to a VM.
      If the user has the appropriate Role Based Access Control (RBAC), then the request will be granted, otherwise it will be denied.
      Azure Security Center (ASC) automatically configures the NSG and Azure Firewall to allow inbound traffic to the selected ports and requested source IP addresses or ranges, for the amount of time that was specified.
      After the time has expired, Security Center restores the NSGs to their previous states. Those connections that are already established are not being interrupted, however.

      More information is available here: https://docs.microsoft.com/en-us/azure/security-center/security-center-just-in-time
      RBAC permissions needed to configure and use JIT are available here: https://docs.microsoft.com/en-us/azure/security-center/security-center-just-in-time#permissions-needed-to-configure-and-use-jit

      This script will query all VMs within the selected subscription and attempt to apply the JIT access policy below to each and every VM that is found.

      JIT policy breakdown:
      - Ports: 22, 3389, 5585, 5586
      - Protocol: *
      - AllowedSourceAddressPrefix: Allowed Source Subnets for JIT access profile, provided by input parameter AllowedSourceAddressPrefixes.
      - MaxRequestAccessDuration: 3 Hours
      If you need to change any of these values (Ports, Protocol, MaxRequestAccessDuration), edit the function Set-JustInTimePolicyForVM in this script.
      Location is also hard-coded to canadacentral, change it if required.

      Since JIT policies work at the Resource Group (RG) level, we loop through each RG looking for VMs and build a JIT policy based on this logic.

      JIT Access Policy must be named "default" for ASC to treat it as configured JIT enabled VM.

      Pre-requisites: Azure Security Center needs to be enabled (Standard plan), this enables the JIT functionality.
      If it's not set to Standard plan, script will throw "Subscription is not in the Standard or Standard Trial subscription plan. Please upgrade to use this feature." when trying to create JIT policy.
      VMs also require the following: 
      - Resource type: Azure Resource Manager (no Classic resources)
      - Associated NSG at subnet or nic level, or both.

      Through testing it was determined that:
      - The default inbound allow rule priority start at 100, incrementing by 1 each time.
      - The default inbound deny rule priority starts at 1014, incrementing by 1 each time.

      Warning: When applying a JIT access policy to a VM or a series of VMs, Microsoft will reprioritize inbound rules within the NSG.
      Warning: If a VM is moved to a new RG after a JIT access policy was applied, the VM will be removed from the existing policy and a new JIT access policy must be applied.
      Also, there may be manual cleanup required to the inbound security rules for the NSG if this occurs.

      To delete all JIT access policies within a Subsciption, use the following command: Get-AzJitNetworkAccessPolicy | Remove-AzJitNetworkAccessPolicy
      To delete all JIT access policies within a Resource Group, use the following command: Get-AzJitNetworkAccessPolicy -ResourceGroupName "ResourceGroup01" | Remove-AzJitNetworkAccessPolicy

      Required modules:
      - Az.Accounts
      - Az.Compute
      - Az.Network
      - Az.Resources
      - Az.Security
    .NOTES
      Version: 1.0
      Author:  Lucas Jackson
      Date:    1/18/2020
    .EXAMPLE
      .\Set-JustInTimePolicyForSubscription.ps1 -Subscription "Subscription01" -AllowedSourceAddressPrefix "172.16.1.0/24","192.168.1.0/24"

      This command onboards all Virtual Machines within the specified Subscription and only allows requests from 172.16.1.0/24 and 192.168.1.0/24.
    .EXAMPLE
      .\Set-JustInTimePolicyForSubscription.ps1 -Subscription "Subscription01" -ResourceGroupName "ResourceGroup01" -AllowedSourceAddressPrefix "*"

      This command onboards all Virtual Machines within the specified Resource Group and allows requests from all source IPs.
    .LINK
      https://www.devopspertise.com
#>
[CmdLetBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullorEmpty()]
    [String]$Subscription,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullorEmpty()]
    [String[]]$AllowedSourceAddressPrefixes,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullorEmpty()]
    [String]$ResourceGroupName
  )

$ErrorActionPreference = "Stop"

if($ResourceGroupName) {
  Write-Host "$Subscription subscription and $ResourceGroupName resource group selected"
}
else {
  Write-Host "$Subscription subscription selected"
}

function Set-JustInTimePolicyForVM {
param(
      [Parameter(Mandatory = $true)]
      [ValidateNotNullorEmpty()]
      [String[]] $AllowedSourceAddressPrefixes,

      [Parameter(Mandatory = $true)]
      [ValidateNotNullorEmpty()]
      [String]$Id
)
  process
    {
      if($AllowedSourceAddressPrefixes -eq "*") {
        $JitPolicy = (@{
          Id=$Id
          Ports=(@{
            number=22;
            protocol="*";
            allowedSourceAddressPrefix=@("*");
            maxRequestAccessDuration="PT3H"},
            @{
            number=3389;
            protocol="*";
            allowedSourceAddressPrefix=@("*");
            maxRequestAccessDuration="PT3H"},
            @{
            number=5585;
            protocol="*";
            allowedSourceAddressPrefix=@("*");
            maxRequestAccessDuration="PT3H"},
            @{
            number=5586;
            protocol="*";
            allowedSourceAddressPrefix=@("*");
            maxRequestAccessDuration="PT3H"})})
      } 
      else {
        $JitPolicy = (@{
          Id=$Id
          Ports=(@{
            number=22;
            protocol="*";
            allowedSourceAddressPrefixes=$AllowedSourceAddressPrefixes;
            maxRequestAccessDuration="PT3H"},
            @{
            number=3389;
            protocol="*";
            allowedSourceAddressPrefixes=$AllowedSourceAddressPrefixes;
            maxRequestAccessDuration="PT3H"},
            @{
            number=5585;
            protocol="*";
            allowedSourceAddressPrefixes=$AllowedSourceAddressPrefixes;
            maxRequestAccessDuration="PT3H"},
            @{
            number=5586;
            protocol="*";
            allowedSourceAddressPrefixes=$AllowedSourceAddressPrefixes;
            maxRequestAccessDuration="PT3H"})})
      }
      
      $JitPolicyArr=@($JitPolicy)
      return $JitPolicyArr
  }
}

# Set Context, see if we have access
# Get all Virtual Machines
# Loop through Virtual Machines applying the JIT policy defined
Try {
  # Set Context
  Set-AzContext -Subscription $Subscription

  # Get Resource Groups within Context
  # Check if ResourceGroupName param has been passed or not
  if ($ResourceGroupName) {
    $allRgs = $ResourceGroupName
  }
  else {
    $allRgs = Get-AzResourceGroup
  }

  # Get Virtual Machines within Resource Group
  foreach($rg in $allRgs) {
    $setJitPolicyArr = $null

    if ($ResourceGroupName) {
      $resourceGroupNameCurrent = $ResourceGroupName
    }
    else {
      $resourceGroupNameCurrent = $rg.ResourceGroupName
    }
    
    Write-Host "`nGetting VMs in $resourceGroupNameCurrent"
    $allVmsRg = Get-AzVm -ResourceGroup $resourceGroupNameCurrent

      foreach($vm in $allVmsRg) {
        $nsgFound = $false

        Write-Host $vm.Name $vm.Id
        foreach($nic in $vm.NetworkProfile.NetworkInterfaces.Id) {
          Write-Host "NIC: $nic"
          $existNsgVm = Get-AzNetworkInterface | Where-Object Id -eq $nic

          if ($existNsgVm.NetworkSecurityGroup.Id) {
            Write-Host "NSG NIC:" $existNsgVm.NetworkSecurityGroup.Id`n
            $nsgFound = $true
            break
          }

          $vmIpConfig = Get-AzNetworkInterface | Where-Object Id -eq $nic | Get-AzNetworkInterfaceIpConfig
          $allVirtualNetwork = Get-AzVirtualNetwork

          foreach($virtualNetwork in $allVirtualNetwork) {
            foreach($subnet in $virtualNetwork.Subnets) {
              if($subnet.Id -eq $vmIpConfig.Subnet.Id -and $subnet.NetworkSecurityGroup.Id) {
                Write-Host "NSG SUBNET:" $subnet.NetworkSecurityGroup.Id`n
                $nsgFound = $true
                break
              }
            }
          }
        } 
        
        if($nsgFound) {
          $setJitPolicy = Set-JustInTimePolicyForVM -Id $vm.Id -AllowedSourceAddressPrefixes $allowedSourceSubnets
          $setJitPolicyArr+=@($setJitPolicy)
        }
        else {
          Write-Host "WARNING: No NSG found for" $vm.Name "<--- resource ignored`n" -ForegroundColor "Yellow"
        }
      }
      if($setJitPolicyArr) {
        Set-AzJitNetworkAccessPolicy -Kind "Basic" -Location "canadacentral" -Name "default" -ResourceGroupName $resourceGroupNameCurrent -VirtualMachine $setJitPolicyArr
      }
      else {
        Write-Host "No suitable VMs found for onboarding in resource group $resourceGroupNameCurrent"
      }
  }
}
Catch {
  Write-Host $error[0] -ForegroundColor "Red"
  exit 10
}
