$appAsg = Get-AzApplicationSecurityGroup -ResourceGroupName ASG -Name AppServers
$vmNic = Get-AzNetworkInterface -Name vm-nic01 -ResourceGroupName resourceGroup01
$vmNic.IpConfigurations[0].ApplicationSecurityGroups = $appAsg
$vmNic | Set-AzNetworkInterface