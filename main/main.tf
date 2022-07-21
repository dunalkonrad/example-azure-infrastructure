# Configure the Azure provider
provider "azurerm" {
      version = "= 3.0.2"
      features {}
}
terraform {
    backend "azurerm" {}
}



# First resource group

resource "azurerm_resource_group" "rg-1" {
  name     = "rg-vnet1-terra"
  location = var.location
}

# networking

resource "azurerm_virtual_network" "vnet-1" {
  name                = "VNet1-terra"
  address_space       = ["10.0.1.0/28"]
  location            = var.location
  resource_group_name = azurerm_resource_group.rg-1.name
}

resource "azurerm_subnet" "sub-1" {
  name                 = "sub-1"
  resource_group_name  = azurerm_resource_group.rg-1.name
  virtual_network_name = azurerm_virtual_network.vnet-1.name
  address_prefixes     = ["10.0.1.0/29"]
}

resource "azurerm_public_ip" "ip-vm1" {
  name                = "ip-vm1"
  resource_group_name = azurerm_resource_group.rg-1.name
  location            = azurerm_resource_group.rg-1.location
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               =  [
  "1"
  ]
}

resource "azurerm_network_interface" "nic-1" {
  name                = "nic-1"
  location            = azurerm_resource_group.rg-1.location
  resource_group_name = azurerm_resource_group.rg-1.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.sub-1.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.ip-vm1.id
  }

}

resource "azurerm_virtual_network_peering" "VNet1-VNet2"{
    name                      = "VNet1-VNet2"
    resource_group_name       = azurerm_resource_group.rg-1.name
    virtual_network_name      = azurerm_virtual_network.vnet-1.name
    remote_virtual_network_id = azurerm_virtual_network.vnet-2.id
}

resource "azurerm_virtual_network_peering" "VNet1-VNetPost"{
    name                      = "VNet1-VNetPost"
    resource_group_name       = azurerm_resource_group.rg-1.name
    virtual_network_name      = azurerm_virtual_network.vnet-1.name
    remote_virtual_network_id = azurerm_virtual_network.vnet-post.id
}

# vm

resource "azurerm_linux_virtual_machine" "vm-1" {
  name                  = "vm-1"
  resource_group_name   = azurerm_resource_group.rg-1.name
  location              = var.location
  size                  = "Standard_B1s"
  admin_username        = var.admin
  zone                  =  "1"
  network_interface_ids = [
    azurerm_network_interface.nic-1.id
  ]

 admin_ssh_key {
    username   = var.admin
    public_key = file("/home/konraddunal/test/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }
}

resource "azurerm_managed_disk" "disk-vm1" {
  name                  = "disk-vm1"
  location              = var.location
  resource_group_name   = azurerm_resource_group.rg-1.name
  storage_account_type  = "Standard_LRS"
  create_option         = "Empty"
  disk_size_gb          = 10
  zone                  = "1"
}

resource "azurerm_virtual_machine_data_disk_attachment" "disktovm1" {
  managed_disk_id     = azurerm_managed_disk.disk-vm1.id
  virtual_machine_id  = azurerm_linux_virtual_machine.vm-1.id
  lun                 = "10"
  caching             = "ReadWrite"
}

# Second resource group

resource "azurerm_resource_group" "rg-2" {
  name     = "rg-vnet2-terra"
  location = var.location
}

# networking

resource "azurerm_virtual_network" "vnet-2" {
  name                = "VNet2-terra"
  address_space       = ["10.0.1.16/28"]
  location            = var.location
  resource_group_name = azurerm_resource_group.rg-2.name
}

resource "azurerm_subnet" "sub-2" {
  name                 = "sub-2"
  resource_group_name  = azurerm_resource_group.rg-2.name
  virtual_network_name = azurerm_virtual_network.vnet-2.name
  address_prefixes     = ["10.0.1.16/29"]
}

resource "azurerm_public_ip" "ip-vm2" {
  name                = "ip-vm2"
  resource_group_name = azurerm_resource_group.rg-2.name
  location            = azurerm_resource_group.rg-2.location
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               =  [
  "1"
  ]
}

resource "azurerm_network_interface" "nic-2" {
  name                = "nic-2"
  location            = azurerm_resource_group.rg-2.location
  resource_group_name = azurerm_resource_group.rg-2.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.sub-2.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.ip-vm2.id
  }

}

resource "azurerm_virtual_network_peering" "VNet2-VNet1"{
    name                      = "VNet2-VNet1"
    resource_group_name       = azurerm_resource_group.rg-2.name
    virtual_network_name      = azurerm_virtual_network.vnet-2.name
    remote_virtual_network_id = azurerm_virtual_network.vnet-1.id
}

resource "azurerm_virtual_network_peering" "VNet2-VNetPost"{
    name                      = "VNet2-VNetPost"
    resource_group_name       = azurerm_resource_group.rg-2.name
    virtual_network_name      = azurerm_virtual_network.vnet-2.name
    remote_virtual_network_id = azurerm_virtual_network.vnet-post.id
}

# nsg-vnet1

resource "azurerm_network_security_group" "nsg-vnet1"{
  name                = "nsg-vnet1"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg-1.name

security_rule {
   name                        = "SSH"
    priority                   = 300
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = var.any
    destination_port_range     = "22"
    source_address_prefix      = var.any
    destination_address_prefix = var.any
}

security_rule {
   name                        = "Port_80"
    priority                   = 310
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = var.any
    destination_port_range     = "80"
    source_address_prefix      = var.any
    destination_address_prefix = var.any
}
}

resource "azurerm_subnet_network_security_group_association" "example" {
  subnet_id                 = azurerm_subnet.sub-1.id
  network_security_group_id = azurerm_network_security_group.nsg-vnet1.id
}

# nsg-vnet2

resource "azurerm_network_security_group" "nsg-vnet2"{
  name                = "nsg-vnet2"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg-2.name

security_rule {
    name                       = "SSH"
    priority                   = 300
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = var.any
    destination_port_range     = "22"
    source_address_prefix      = var.any
    destination_address_prefix = var.any
}

security_rule {
    name                       = "Port_80"
    priority                   = 310
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = var.any
    destination_port_range     = "80"
    source_address_prefix      = var.any
    destination_address_prefix = var.any
}
}

resource "azurerm_subnet_network_security_group_association" "example2" {
  subnet_id                 = azurerm_subnet.sub-2.id
  network_security_group_id = azurerm_network_security_group.nsg-vnet2.id
}

# vm

resource "azurerm_linux_virtual_machine" "vm-2" {
  name                = "vm-2"
  resource_group_name = azurerm_resource_group.rg-2.name
  location            = var.location
  size                = "Standard_B1s"
  admin_username      = var.admin
  zone                =  "1"
  network_interface_ids = [
    azurerm_network_interface.nic-2.id
  ]

  admin_ssh_key {
    username   = var.admin
    public_key = file("/home/konraddunal/test/id_rsa.pub")
    }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }
}

resource "azurerm_managed_disk" "disk-vm2" {
  name                  = "disk-vm2"
  location              = var.location
  resource_group_name   = azurerm_resource_group.rg-2.name
  storage_account_type  = "Standard_LRS"
  create_option         = "Empty"
  disk_size_gb          = 10
  zone                  = "1"
}

resource "azurerm_virtual_machine_data_disk_attachment" "disktovm2" {
  managed_disk_id     = azurerm_managed_disk.disk-vm2.id
  virtual_machine_id  = azurerm_linux_virtual_machine.vm-2.id
  lun                 = "10"
  caching             = "ReadWrite"
}

# Third resource group

resource "azurerm_resource_group" "rg-global" {
  name     = "rg-global-terra"
  location = var.location
}

# networking

resource "azurerm_virtual_network" "vnet-post" {
  name                = "VNet-postgresSQL-terra"
  address_space       = ["10.0.1.32/29"]
  location            = var.location
  resource_group_name = azurerm_resource_group.rg-global.name
}

resource "azurerm_subnet" "sub-post" {
  name                 = "sub-post"
  resource_group_name  = azurerm_resource_group.rg-global.name
  virtual_network_name = azurerm_virtual_network.vnet-post.name
  address_prefixes     = ["10.0.1.32/29"]
  delegation {
    name = "delegation"

    service_delegation {
      name    = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action", "Microsoft.Network/virtualNetworks/subnets/prepareNetworkPolicies/action"]
    }
  }

}

resource "azurerm_public_ip" "ip-lb1" {
  name                = "ip-lb1"
  resource_group_name = azurerm_resource_group.rg-global.name
  location            = azurerm_resource_group.rg-global.location
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               =  [
  "2",
  "3",
  "1"
  ]
}

resource "azurerm_public_ip" "ip-lb2" {
  name                = "ip-lb2"
  resource_group_name = azurerm_resource_group.rg-global.name
  location            = azurerm_resource_group.rg-global.location
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               =  [
  "2",
  "3",
  "1"
  ]
}

resource "azurerm_virtual_network_peering" "VNetPost-VNet1"{
    name                      = "VNetPost-VNet1"
    resource_group_name       = azurerm_resource_group.rg-global.name
    virtual_network_name      = azurerm_virtual_network.vnet-post.name
    remote_virtual_network_id = azurerm_virtual_network.vnet-1.id
}

resource "azurerm_virtual_network_peering" "VNetPost-VNet2"{
    name                      = "VNetPost-VNet2"
    resource_group_name       = azurerm_resource_group.rg-global.name
    virtual_network_name      = azurerm_virtual_network.vnet-post.name
    remote_virtual_network_id = azurerm_virtual_network.vnet-2.id
}

# PostgresSQL
resource "azurerm_private_dns_zone" "postgresSQL" {
  name                = "postgresSQL.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.rg-global.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "zone-postgresSQL" {
  name                  = "zone-postgresSQL"
  private_dns_zone_name = azurerm_private_dns_zone.postgresSQL.name
  virtual_network_id    = azurerm_virtual_network.vnet-post.id
  resource_group_name   = azurerm_resource_group.rg-global.name
}

resource "azurerm_postgresql_flexible_server" "server-postgressql-terra" {
  name                   = "server-postgressql-terra"
  resource_group_name    = azurerm_resource_group.rg-global.name
  location               = var.location
  version                = "13"
  delegated_subnet_id    = azurerm_subnet.sub-post.id
  private_dns_zone_id    = azurerm_private_dns_zone.postgresSQL.id
  administrator_login    = var.admin
  administrator_password = "Admin123."
  zone                   = "1"

  storage_mb = 32768

  sku_name   = "B_Standard_B1ms"
  depends_on = [azurerm_private_dns_zone_virtual_network_link.zone-postgresSQL]

}

# Loadbalancers
resource "azurerm_lb" "lb-vnet1"{
  name                = "lb-vnet1"
  location            = azurerm_resource_group.rg-global.location
  resource_group_name = azurerm_resource_group.rg-global.name
  sku                 = "Standard"
  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.ip-lb1.id
  }
}

resource "azurerm_lb_backend_address_pool" "lb1-pool" {
  loadbalancer_id = azurerm_lb.lb-vnet1.id
  name            = "lb1-pool"
}

resource "azurerm_network_interface_backend_address_pool_association" "astonic1" {
  network_interface_id    = azurerm_network_interface.nic-1.id
  ip_configuration_name   = "internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.lb1-pool.id
}

resource "azurerm_lb_probe" "probe-1" {
  loadbalancer_id = azurerm_lb.lb-vnet1.id
  name            = "probe-1"
  protocol        = "Http"
  request_path    = "/"
  port            = 80
}

resource "azurerm_lb_rule" "rule-1" {
  loadbalancer_id                 = azurerm_lb.lb-vnet1.id
  name                            = "rule-1"
  protocol                        = "Tcp"
  frontend_port                   = 80
  backend_port                    = 80
  frontend_ip_configuration_name  = "PublicIPAddress"
  probe_id                        = azurerm_lb_probe.probe-1.id
  backend_address_pool_ids        = [
    azurerm_lb_backend_address_pool.lb1-pool.id
  ]

}

resource "azurerm_lb" "lb-vnet2"{
  name                = "lb-vnet2"
  location            = azurerm_resource_group.rg-global.location
  resource_group_name = azurerm_resource_group.rg-global.name
  sku                 = "Standard"
  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.ip-lb2.id
  }
}

resource "azurerm_lb_backend_address_pool" "lb2-pool" {
  loadbalancer_id = azurerm_lb.lb-vnet2.id
  name            = "lb2-pool"
}

resource "azurerm_network_interface_backend_address_pool_association" "astonic2" {
  network_interface_id    = azurerm_network_interface.nic-2.id
  ip_configuration_name   = "internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.lb2-pool.id
}


resource "azurerm_lb_probe" "probe-2" {
  loadbalancer_id = azurerm_lb.lb-vnet2.id
  name            = "probe-2"
  protocol        = "Http"
  request_path    = "/"
  port            = 80
}

resource "azurerm_lb_rule" "rule-2" {
  loadbalancer_id                 = azurerm_lb.lb-vnet2.id
  name                            = "rule-2"
  protocol                        = "Tcp"
  frontend_port                   = 80
  backend_port                    = 80
  frontend_ip_configuration_name  = "PublicIPAddress"
    probe_id                      = azurerm_lb_probe.probe-2.id
  backend_address_pool_ids        = [
    azurerm_lb_backend_address_pool.lb2-pool.id
  ]
} 

# DNS

resource "azurerm_dns_zone" "nudesky" {
  name                = "nudesky.pl"
  resource_group_name = azurerm_resource_group.rg-global.name
}

resource "azurerm_dns_a_record" "vm1" {
  name                = "vm1"
  zone_name           = azurerm_dns_zone.nudesky.name
  resource_group_name = azurerm_resource_group.rg-global.name
  ttl                 = 300
  target_resource_id  = azurerm_public_ip.ip-lb1.id
}

resource "azurerm_dns_a_record" "vm2" {
  name                = "vm2"
  zone_name           = azurerm_dns_zone.nudesky.name
  resource_group_name = azurerm_resource_group.rg-global.name
  ttl                 = 300
  target_resource_id  = azurerm_public_ip.ip-lb2.id
}