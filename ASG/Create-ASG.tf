resource "azurerm_resource_group" "application_security_group-rg" {
  name     = "ASG"
  location = "canadacentral"
}

resource "azurerm_application_security_group" "application_security_group-asg-appservers" {
  name                = "AppServers"
  location            = azurerm_resource_group.application_security_group-rg.location
  resource_group_name = azurerm_resource_group.application_security_group-rg.name
}

resource "azurerm_application_security_group" "application_security_group-asg-dbservers" {
  name                = "DbServers"
  location            = azurerm_resource_group.application_security_group-rg.location
  resource_group_name = azurerm_resource_group.application_security_group-rg.name
}