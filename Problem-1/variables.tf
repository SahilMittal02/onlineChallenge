variable "name" {
    default = "myrg-challenge"
}

variable "location" {
    default = "eastus"
}

variable "storage_account_name" {
    default = "tfstatestorage"
}

variable "container_name" {
    default = "tfstatecontainer"
}

variable "network_name" {
    default = "mynw-challenge"
}

variable "address_space" {
    default = ["10.0.0.0/16"]
}

variable "subnet_name" {
    default = "mysubnet-challenge"
}

variable "lb_name" {
    default = "lb-challenge"
}