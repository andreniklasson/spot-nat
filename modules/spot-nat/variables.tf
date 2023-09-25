variable "name" {
  default = "NAT"
  type    = string
}

variable "vpc_id" {
  type = string
}

variable "ami_id" {
  default = "ami-019743dbff6bf9883"
  type    = string
  description = "A standard Amazon Linux dist or your own AMI"
}

variable "instance_types" {
  type = list(string)
  default = [
    "t3.medium",
  ]
}

variable "vpc_cidr_blocks" {
  type = list(string)
}

variable "key_name" {
  type = string
}

variable "vpc_info" {
  description = "A list of objects that dictate what subnet the NAT instance should run in and what route tables it should manage. One NAT Instance for every entry"
  type = list(object({
    public_subnet_ids  = list(string)
    route_table_ids    = list(string)
    elastic_ip_address = string
    nat_gateway_id     = string
  }))
}
