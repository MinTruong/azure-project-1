terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.0.0"
    }
  }
}

provider "azurerm" {
  features {}
}

data "azurerm_image" "custom" {
  name                = "${var.custom_image_name}"
  resource_group_name = "${var.resource_group}"
}

################################################################
#                         Network                              #
################################################################
# Create virtual network
resource "azurerm_virtual_network" "app_network" {
  name                = "${var.resource_group}-network"
  address_space       = ["192.168.0.0/16"]
  location            = "${var.location}"
  resource_group_name = "${var.resource_group}"
}

# Create subnet
resource "azurerm_subnet" "SubnetA" {
  name                 = "SubnetA"
  resource_group_name  = "${var.resource_group}"
  virtual_network_name = azurerm_virtual_network.app_network.name
  address_prefixes     = ["192.168.0.0/24"]
  depends_on = [
    azurerm_virtual_network.app_network
  ]
}
################################################################
#                     interface-NIC                            #
################################################################
// This interface is for appvm1
resource "azurerm_network_interface" "app_interface" {
  count = var.counter
  name                = "app-interface-${count.index}"
  location            = var.location
  resource_group_name = var.resource_group

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.SubnetA.id
    private_ip_address_allocation = "Dynamic"    
  }

  depends_on = [
    azurerm_virtual_network.app_network,
    azurerm_subnet.SubnetA
  ]
}

################################################################
#                     Load Balancer                            #
################################################################
resource "azurerm_public_ip" "myTerraformPublicIp" {
# Create load balancer public IPs
  name                = "lb-PublicIP"
  location            = var.location
  resource_group_name = var.resource_group
  allocation_method   = "Static"
  sku                 = "Basic"
}

# Create load balancer Frontend IP
resource "azurerm_lb" "myLoadBalance" {
   name                = "lb-Fib"
   location            = var.location
   resource_group_name = var.resource_group

   frontend_ip_configuration {
     name                 = "publicIPAddress"
     public_ip_address_id = azurerm_public_ip.myTerraformPublicIp.id
   }
 }

# Create load balancer Rules
resource "azurerm_lb_rule" "loadBalancerRule" {
  loadbalancer_id                = azurerm_lb.myLoadBalance.id
  name                           = "LBRule"
  protocol                       = "Tcp"
  frontend_port                  = 8080
  backend_port                   = 80
  frontend_ip_configuration_name = "publicIPAddress"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.backendApp.id]

  depends_on = [
    azurerm_lb.myLoadBalance
  ]
}

# Create load balancer Backend pool
 resource "azurerm_lb_backend_address_pool" "backendApp" {
   loadbalancer_id     = azurerm_lb.myLoadBalance.id
   name                = "lb-BackendPool"
 }
################################################################
#                     Virtual Machine                          #
################################################################


# Create Network Security Group and rule
resource "azurerm_network_security_group" "app_nsg" {
  name                = "myNetworkSecurityGroup"
  location            = var.location
  resource_group_name = var.resource_group

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
    
  security_rule {
    name                       = "Web"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}
# Connect the security group to the network interface
/* resource "azurerm_network_interface_security_group_association" "example" {
  network_interface_id      = azurerm_network_interface.myterraformnic.count.index
  network_security_group_id = azurerm_network_security_group.myterraformnsg.id
} */
resource "azurerm_subnet_network_security_group_association" "nsg_association" {
  subnet_id                 = azurerm_subnet.SubnetA.id
  network_security_group_id = azurerm_network_security_group.app_nsg.id
  depends_on = [
    azurerm_network_security_group.app_nsg
  ]
}

resource "azurerm_network_interface_backend_address_pool_association" "backendApp1" {
  count = var.counter
  network_interface_id    = element(azurerm_network_interface.app_interface.*.id, count.index)
  ip_configuration_name   = "internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.backendApp.id
  
  depends_on = [
    azurerm_network_interface.app_interface,
    azurerm_lb.myLoadBalance,
    azurerm_lb_backend_address_pool.backendApp
  ]
}
################################################################
#                     Availability Set                         #
################################################################
resource "azurerm_availability_set" "app_set" {
  name                = "app-set"
  location            = var.location
  resource_group_name = var.resource_group
  platform_fault_domain_count = 2
  platform_update_domain_count = 2
}

################################################################
#                     Virtual Machine                          #
################################################################
resource "azurerm_virtual_machine" "app_vm" {
  count = var.count
  name                  = "app_vm-${count.index}"
  location              = var.location
  resource_group_name   = var.resource_group
  vm_size               = "Standard_DS1_v2"
  availability_set_id = azurerm_availability_set.app_set.id
  network_interface_ids = [
    azurerm_network_interface.app_interface[count.index].id,
  ]
  # This means the OS Disk will be deleted when Terraform destroys the Virtual Machine
  # NOTE: This may not be optimal in all cases.

  delete_os_disk_on_termination = true

  storage_image_reference {
    id = "${data.azurerm_image.custom.id}"
  }

  storage_os_disk {
    name              = "osdisk-${count.index}"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "hostname1"
    admin_username = var.username
    admin_password = var.password
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }

  depends_on = [
    azurerm_network_interface.app_interface1,
    azurerm_availability_set.app_set
  ]
}

resource "azurerm_virtual_machine" "app_vm2" {
  name                  = "app_vm2"
  location              = var.location
  resource_group_name   = var.resource_group
  network_interface_ids = ["${azurerm_network_interface.app_interface2.id}"]
  vm_size               = "Standard_DS1_v2"
  availability_set_id = azurerm_availability_set.app_set.id
  # This means the OS Disk will be deleted when Terraform destroys the Virtual Machine
  # NOTE: This may not be optimal in all cases.
  delete_os_disk_on_termination = true

  storage_image_reference {
    id = "${data.azurerm_image.custom.id}"
  }

  storage_os_disk {
    name              = "osdisk-2"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "hostname2"
    admin_username = var.username
    admin_password = var.password
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }

  depends_on = [
    azurerm_network_interface.app_interface2,
    azurerm_availability_set.app_set
  ]
}
