
remote_state {
    backend = "azurerm"
    config = {
        resource_group_name  = "storage"
        storage_account_name = "dunalkonrad"
        container_name       = "infra-1"
        key                  = "prod.terraform.infra-1"
    }
}


inputs = {
    location = "norwayeast"
}