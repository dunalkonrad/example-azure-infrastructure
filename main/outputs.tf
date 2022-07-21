output "ip_loadbalancer_vnet1" {
    value = azurerm_public_ip.ip-lb1.ip_address
    description = "IP of LoadBalancer to VNet1"
}

output "ip_loadbalancer_vnet2" {
    value = azurerm_public_ip.ip-lb2.ip_address
    description = "IP of LoadBalancer to VNet2"
}

output "system_version_of_vm" {
    value = azurerm_linux_virtual_machine.vm-1.source_image_reference[0].sku
    description = "Version of Linux virtual machine"
}