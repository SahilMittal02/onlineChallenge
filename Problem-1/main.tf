data "azurerm_resource_group" "myrg" {
    name = var.name
}
data "azurerm_storage_account" "mysg" {
    name = var.storage_account_name
}

terraform {
    backend "azurerm" {
        resource_group_name  = "${azurerm_resource_group.myrg.name}"
        storage_account_name = "${azurerm_storage_account.mysg.name}"
        container_name       = "${var.container_name}"
        key                  = "terraform.tfstate"
    }
}
resource "azurerm_virtual_network" "network" {
    name = var.network_name
    location = data.azurerm_resource_group.myrg.location
    resource_group_name = data.azurerm_resource_group.myrg.name
    address_space = var.address_space
    subnet {
        name = var.subnet_name
        address_prefix = var.address_prefix
    }
}

resource "azurerm_public_ip" "pubip" {
    name = var.public_ip
    location = data.azurerm_resource_group.myrg.location
    resource_group_name = data.azurerm_resource_group.myrg.name
    allocation_method = "Static"
}

resource "azurerm_lb" "lb" {
    name = var.lb_name
    location = data.azurerm_resource_group.myrg.location
    resource_group_name = data.azurerm_resource_group.myrg.name

    frontend_ip_configuration {
        name = "PublicIP"
        public_ip_address_id = azurerm_public_ip.pubip.id
    }
}

resource "azurerm_lb_backend_address_pool" "bpepool" {
  resource_group_name = data.azurerm_resource_group.myrg.name
  loadbalancer_id     = azurerm_lb.lb.id
  name                = "BackEndAddressPool"
}

resource "azurerm_lb_nat_pool" "lbnatpool" {
  resource_group_name            = data.azurerm_resource_group.myrg.name
  name                           = "ssh"
  loadbalancer_id                = azurerm_lb.lb.id
  protocol                       = "Tcp"
  frontend_port_start            = 50000
  frontend_port_end              = 50119
  backend_port                   = 22
  frontend_ip_configuration_name = "PublicIPAddress"
}

resource "azurerm_lb_probe" "lbprobe" {
  resource_group_name = data.azurerm_resource_group.myrg.name
  loadbalancer_id     = azurerm_lb.lb.id
  name                = "http-probe"
  protocol            = "Http"
  request_path        = "/health"
  port                = 8080
}

resource "azurerm_virtual_machine_scale_set" "vmss" {
  name                = var.vmss_name
  location            = data.azurerm_resource_group.myrg.location
  resource_group_name = data.azurerm_resource_group.myrg.name

  # automatic rolling upgrade
  automatic_os_upgrade = true
  upgrade_policy_mode  = "Rolling"

  rolling_upgrade_policy {
    max_batch_instance_percent              = 20
    max_unhealthy_instance_percent          = 20
    max_unhealthy_upgraded_instance_percent = 5
    pause_time_between_batches              = "PT0S"
  }

  # required when using rolling upgrade policy
  health_probe_id = azurerm_lb_probe.lbprobe.id

  sku {
    name     = "Standard_F2"
    tier     = "Standard"
    capacity = 2
  }

  storage_profile_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

  storage_profile_os_disk {
    name              = ""
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  storage_profile_data_disk {
    lun           = 0
    caching       = "ReadWrite"
    create_option = "Empty"
    disk_size_gb  = 10
  }

  os_profile {
    computer_name_prefix = "testvm"
    admin_username       = "myadmin"
  }

  os_profile_linux_config {
    disable_password_authentication = true

    ssh_keys {
      path     = "/home/myadmin/.ssh/authorized_keys"
      key_data = file("~/.ssh/demo_key.pub")
    }
  }

  network_profile {
    name    = "terraformnetworkprofile"
    primary = true

    ip_configuration {
      name                                   = "TestIPConfiguration"
      primary                                = true
      subnet_id                              = azurerm_virtual_network.network.subnet.id
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.bpepool.id]
      load_balancer_inbound_nat_rules_ids    = [azurerm_lb_nat_pool.lbnatpool.id]
    }
  }

}

# Internal load balancer to take input from Vmss and send to database

resource "azurerm_lb" "lb" {
    name = var.lb_name
    location = data.azurerm_resource_group.myrg.location
    resource_group_name = data.azurerm_resource_group.myrg.name
}

resource "azurerm_lb_backend_address_pool" "bpepool" {
  resource_group_name = data.azurerm_resource_group.myrg.name
  loadbalancer_id     = azurerm_lb.lb.id
  name                = "BackEndAddressPool"
}

resource "azurerm_lb_nat_rule" "example" {
  resource_group_name            = data.azurerm_resource_group.myrg.name
  loadbalancer_id                = azurerm_lb.lb.id
  name                           = "Databaseconnnect"
  protocol                       = "Tcp"
  frontend_port                  = 22
  backend_port                   = 1443
}

# database creation
resource "azurerm_sql_server" "example" {
  name                         = "myexamplesqlserver"
  resource_group_name          = azurerm_resource_group.example.name
  location                     = "West US"
  version                      = "12.0"
  administrator_login          = "sqladmin"
  administrator_login_password = "4-v3ry-53cr37-p455w0rd"
}

resource "azurerm_storage_account" "example" {
  name                     = "examplesa"
  resource_group_name      = azurerm_resource_group.example.name
  location                 = azurerm_resource_group.example.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_sql_database" "example" {
  name                = "myexamplesqldatabase"
  resource_group_name = azurerm_resource_group.example.name
  location            = "West US"
  server_name         = azurerm_sql_server.example.name

  extended_auditing_policy {
    storage_endpoint                        = azurerm_storage_account.example.primary_blob_endpoint
    storage_account_access_key              = azurerm_storage_account.example.primary_access_key
    storage_account_access_key_is_secondary = true
    retention_in_days                       = 6
  }
}
