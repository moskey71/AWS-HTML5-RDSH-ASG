variable "region" {
  default = "us-east-1"
}

variable "dns_name" {
  default = "yourname"
}

variable "vpcid" {
  default = "vpc-xxxxxxxx"
}

variable "private_subnets" {
  default = ["subnet-private1", "subnet-private2"]
}

variable "public_subnets" {
  default = ["subnet-private1", "subnet-public2"]
}

variable "key_name" {
  default = "yourkeyname"
}

variable "rdsh_dnszone_id" {
  default = "AAAAAAAAAAAAAA"
}

variable "tag_name" {
  default = "yourtag"
}
