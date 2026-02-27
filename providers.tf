terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.17.0"
    }
  }
}


provider "aws" {
  secret_key = var.secret_access_key
  access_key = var.access_key
}
