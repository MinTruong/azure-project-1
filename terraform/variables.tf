variable "resource_group" {
  description = "The prefix which should be used for all resources in this example"
  default = "Azuredevops"
}
variable "custom_image_name" {
  description = "name of VM image"
  default = "myPackerImage1"
}

variable "location" {
  description = "The Azure Region in which all resources in this example should be created."
  default = "East US"
}

variable "username" {
  description = "admin_username of MC"
  default = "minh"
}

variable "password" {
  description = "password of MC"
  default = "Azuredevops@1ww9"
}
