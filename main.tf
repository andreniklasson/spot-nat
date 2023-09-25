terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.17.0"
    }
  }
}

provider "aws" {
  region = "eu-west-1"
}

module "nat_instances" {
  source = "./modules/spot-nat"
  name   = "NAT-spot-instance"
  ami_id = "ami-0648880541a3156f7"
  key_name = "KEY_NAME"
  instance_types = [
    "t3.medium"
  ]
  vpc_cidr_blocks = [
    "10.153.64.0/20",
    "10.153.80.0/20",
    "10.153.96.0/20",
  ]
  vpc_id = "VPC_ID"
  vpc_info = [
    {
      public_subnet_ids = [
        "PUBLIC_SUBNET_A_ID"
      ]
      route_table_ids = [
        "PRIVATE_ROUTE_TABLE_A"
      ]
      elastic_ip_address = "NAT_EIP_1"
      nat_gateway_id     = "NAT_GW_ID"
    },
    {
      public_subnet_ids = [
        "PUBLIC_SUBNET_B_ID"
      ]
      route_table_ids = [
        "PRIVATE_ROUTE_TABLE_B"
      ]
      elastic_ip_address = "NAT_EIP_2"
      nat_gateway_id     = "NAT_GW_ID"
    }
  ]
}