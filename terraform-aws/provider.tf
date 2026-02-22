provider "aws" {
  region = "eu-central-1"
}
#------------------------------------key pair----------------------------------------------------#
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
    }
    tls = {
      source  = "hashicorp/tls"
    }
    local = {
      source  = "hashicorp/local"
    }
  }
}