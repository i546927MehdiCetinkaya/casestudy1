provider "aws" {
  region = "eu-central-1"
}

terraform {
  backend "s3" {
    bucket = "mehdi-terraform-state"
    key    = "infra/terraform.tfstate"
    region = "eu-central-1"
  }
}