param(
  [Parameter(Mandatory = $true)]
  [String]$regFind
)

Try {
  $regPath = @("HKLM:Software\Microsoft\Windows\CurrentVersion\Uninstall\","HKLM:Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall")
  foreach ($element in $regPath) {
      Get-ChildItem $element -Recurse | ForEach-Object {
        $oKey = (Get-ItemProperty -Path $_.PsPath)
        If ($oKey -match $regFind){
          Write-Output $_.PSChildName
          exit 0
        }
      }
    }
  Write-Output "$regFind DisplayName not found on the system, could not locate corresponding ProductID."
  exit 1
}
Catch {
  Write-Output "An error occurred while getting the Product ID for uninstall."
  exit 2
}