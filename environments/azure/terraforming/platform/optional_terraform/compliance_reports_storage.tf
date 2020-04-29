resource "azurerm_storage_container" "compliance-reports" {
  name                  = "${var.environment_name}-compliance-reports"
  storage_account_name  = azurerm_storage_account.pas.name
  container_access_type = "private"
}