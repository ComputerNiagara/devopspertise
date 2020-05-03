<#
    .SYNOPSIS 
	  Gets the Product Id for an installed application.
	.PARAMETER Name
	  Name of the installed product.
	.DESCRIPTION
	  This script retrieves the ProductId for an installed application. The ProductId is returned for consumption by Ansible.
	  
	  The Name parameter is the product name as seen in the "Control Panel" under "Programs and Features".
	  
	  Name can also be retrieved using 'wmic product list' or from the registry.
    .EXAMPLE
      .\Get-ApplicationProductId.ps1 -Name "Application01"
#>

param(
	[Parameter(Mandatory = $true)]
	[String]$Name
)

Try {
	$regPath = @("HKLM:Software\Microsoft\Windows\CurrentVersion\Uninstall\","HKLM:Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall")
	foreach ($element in $regPath) {
		Get-ChildItem $element -Recurse | ForEach-Object {
			$oKey = (Get-ItemProperty -Path $_.PsPath)
			If ($oKey -match $Name){
				Write-Output $_.PSChildName
				exit 0
			}
		}
	}
	Write-Output "$Name not found on the system, could not locate corresponding ProductId."
	exit 1
}
Catch {
	Write-Output "An error occurred while getting the ProductId for uninstall."
	exit 2
}