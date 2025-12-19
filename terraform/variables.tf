variable "vpc_cidr" { default = "10.0.0.0/16" }

variable "public_subnet_cidrs"      { default = ["10.0.1.0/28", "10.0.5.0/28"] }
variable "private_web_subnet_cidrs" { default = ["10.0.2.0/28", "10.0.6.0/28"] }
variable "private_db_subnet_cidrs"  { default = ["10.0.3.0/28", "10.0.7.0/28"] }
variable "monitoring_subnet_cidr"   { default = "10.0.4.0/28" }

variable "azs"           { default = ["eu-central-1a", "eu-central-1b"] }
variable "instance_type" { default = "t4g.micro" }
variable "ami_id"        { description = "AMI voor EC2 instances (bijv. Ubuntu 22.04 ARM)" }
variable "key_name"      { description = "SSH KeyPair naam" }

variable "db_username" {
  description = "Database admin username"
  type        = string
}

variable "db_password" {
  description = "Database admin password"
  type        = string
  sensitive   = true
}