provider "azurerm" {
  version = "2.0.0"
  features  {}
}

variable "username" {}
variable "accountpass" {}
variable "resourcename" {}
variable "counts" {}


resource "azurerm_resource_group" "rg" {
  name     = "${var.resourcename}"
  location = "north europe"
  tags = {
    enviroment = "demo"
  }
}


resource "azurerm_virtual_network" "vnet" {
  name                = "${var.resourcename}"
  location            = "${azurerm_resource_group.rg.location}"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  address_space       = ["192.168.0.0/16"]
  tags = {
    enviroment = "demo"
  }
}

resource "azurerm_subnet" "subnet" {
  name                 = "${var.resourcename}"
  resource_group_name  = "${azurerm_resource_group.rg.name}"
  virtual_network_name = "${azurerm_virtual_network.vnet.name}"
  address_prefix       = "192.168.1.0/24"
}

resource "azurerm_public_ip" "ipaddress" {
  count               = "${var.counts}"
  name                = "${var.resourcename}${count.index}"
  location            = "${azurerm_resource_group.rg.location}"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  allocation_method   = "Dynamic"
  tags = {
    enviroment = "demo"
  }
}

resource "azurerm_network_security_group" "nsg" {
  count               = "${var.counts}"
  name                = "${var.resourcename}${count.index}"
  location            = "${azurerm_resource_group.rg.location}"
  resource_group_name = "${azurerm_resource_group.rg.name}"

  security_rule {
    
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    enviroment = "demo"
  }
}

resource "azurerm_network_interface" "nic" {
  count               = "${var.counts}"
  name                = "${var.resourcename}${count.index}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = "${azurerm_resource_group.rg.name}"
  ip_configuration {
    name                          = "ipaddress${count.index}"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = "${azurerm_public_ip.ipaddress.*.id[count.index]}"
    
  }

  tags = {
    enviroment = "demo"
  }
}

#connecting the nic id to the security Id - association

resource "azurerm_network_interface_security_group_association" "example" {
  count                     = "${var.counts}"
  network_interface_id      = "${azurerm_network_interface.nic.*.id[count.index]}"
  network_security_group_id = "${azurerm_network_security_group.nsg.*.id[count.index]}"
}

resource "azurerm_storage_account" "storageaccount" {
  count = "${var.counts}"
  name                     = "${var.resourcename}${count.index}store"
  location                 = azurerm_resource_group.rg.location
  account_replication_type = "LRS"
  resource_group_name      = azurerm_resource_group.rg.name
  account_kind             = "storage"
  account_tier             = "standard"
  tags = {
    enviroment = "demo"
  }
}

variable "var" {
  default = "azuretest"
}



resource "azurerm_linux_virtual_machine" "vm" {
  count = "${var.counts}"
  name                  = "${var.resourcename}${count.index}"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids =  ["${azurerm_network_interface.nic.*.id[count.index]}"]
  size                  = "Standard_B1MS"

  os_disk {
    name                 = "${var.resourcename}-${count.index}-os"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04.0-LTS"
    version   = "latest"
  }


  computer_name                   = "${var.resourcename}-${count.index}-os"
  admin_username                  = "${var.username}"
  disable_password_authentication = false
  admin_password = "${var.accountpass}"
  



  tags = {
    environment = "demo"
  }
}

