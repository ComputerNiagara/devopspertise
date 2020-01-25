New-AzResourceGroup -Name ASG -Location canadacentral
New-AzApplicationSecurityGroup -ResourceGroupName ASG -Name AppServers -Location canadacentral
New-AzApplicationSecurityGroup -ResourceGroupName ASG -Name DbServers -Location canadacentral