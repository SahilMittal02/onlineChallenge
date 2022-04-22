terraform {
    required_providers {
        azurerm = {
            source = "hashicorp/azurerm"
            version = ">=2.85"
        }
    }
    backend "azurerm" {
        resource_group_name = "${azurerm_resource_group.myrg.name}"
        storage_account_name = "${azurerm_storage_account.remotestate.name}"
        container_name       = "${azurerm_storage_container.container.name}"
        key = "terraform.tfstate"
    }
}

provider "azurerm" {
    features {}
}

resource "azurerm_resource_group" "myrg" {
    name = var.name
    location = var.location
}

resource "azurerm_storage_account" "remotestate" {
    name = var.storage_account_name
    resource_group_name = azurerm_resource_group.myrg.name
    location = azurerm_resource_group.myrg.location
    account_kind = "Storage"
    account_tier = "Standard"
    account_replication_type = "LRS"
    min_tls_version = "TLS1_2"
}

resource "azurerm_storage_container" "container" {
    name = var.container_name
    storage_account_name = azurerm_storage_account.remotestate.name
    container_access_type = "private"
}