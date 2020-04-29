resource "azurerm_public_ip" "cluster-lb" {
  name                = "${var.environment_name}-${cluster_name}-cluster-lb-ip"
  location            = var.location
  resource_group_name = azurerm_resource_group.platform.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = merge(
    var.tags,
    { name = "${var.environment_name}-${cluster_name}-cluster" },
  )
}

resource "azurerm_lb" "cluster" {
  name                = "${var.environment_name}-${cluster_name}-cluster-lb"
  location            = var.location
  sku                 = "Standard"
  resource_group_name = azurerm_resource_group.platform.name

  frontend_ip_configuration {
    name                 = azurerm_public_ip.cluster-lb.name
    public_ip_address_id = azurerm_public_ip.cluster-lb.id
  }


  tags = merge(
    var.tags,
    { name = "${var.environment_name}-${cluster_name}-cluster" },
  )
}

resource "azurerm_lb_backend_address_pool" "cluster-lb" {
  name                = "${var.environment_name}-${cluster_name}-cluster-backend-pool"
  resource_group_name = azurerm_resource_group.platform.name
  loadbalancer_id     = azurerm_lb.cluster.id
}

resource "azurerm_lb_probe" "cluster-lb-tls" {
  name                = "${var.environment_name}-${cluster_name}-cluster-lb-tls-health-probe"
  resource_group_name = azurerm_resource_group.platform.name
  loadbalancer_id     = azurerm_lb.cluster.id
  protocol            = "Tcp"
  interval_in_seconds = 5
  number_of_probes    = 2
  port                = 443
}

resource "azurerm_lb_rule" "cluster-lb-tls" {
  name                           = "${var.environment_name}-${cluster_name}-cluster-lb-tls-rule"
  resource_group_name            = azurerm_resource_group.platform.name
  loadbalancer_id                = azurerm_lb.cluster.id
  protocol                       = "Tcp"
  frontend_port                  = 443
  backend_port                   = 443
  frontend_ip_configuration_name = azurerm_public_ip.cluster-lb.name
  probe_id                       = azurerm_lb_probe.cluster-lb-tls.id
  backend_address_pool_id        = azurerm_lb_backend_address_pool.cluster-lb.id
}

resource "azurerm_application_security_group" "cluster-api" {
  name                = "${var.environment_name}-${cluster_name}-cluster-api-app-sec-group"
  location            = var.location
  resource_group_name = azurerm_resource_group.platform.name
}

resource "azurerm_network_security_group" "cluster-api" {
  name                = "${var.environment_name}-${cluster_name}-cluster-api-sg"
  location            = var.location
  resource_group_name = azurerm_resource_group.platform.name

  security_rule {
    name                                       = "api"
    priority                                   = 100
    direction                                  = "Inbound"
    access                                     = "Allow"
    protocol                                   = "Tcp"
    source_port_range                          = "*"
    destination_port_ranges                    = ["443"]
    source_address_prefix                      = "*"
    destination_application_security_group_ids = [azurerm_application_security_group.cluster-api.id]
  }
}

resource "azurerm_dns_a_record" "cluster" {
  name                = "cluster"
  zone_name           = data.azurerm_dns_zone.hosted.name
  resource_group_name = data.azurerm_dns_zone.hosted.resource_group_name
  ttl                 = "60"
  records             = [azurerm_public_ip.cluster-lb.ip_address]

  tags = merge(
    var.tags,
    { name = "cluster.${var.environment_name}-${cluster_name}" },
  )
}