terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  terraform {
    backend "s3" {
      bucket  = "cloudsec-tf-state-tmmuniz"
      key     = "terraform.tfstate"
      region  = "us-east-1"
      encrypt = true
    }
  }
}

provider "aws" {
  # A região é recebida por variável para facilitar testes em ambientes diferentes.
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      ManagedBy   = "Terraform"
      Environment = var.environment
      Portfolio   = "Terraform-Rego-AWS-FreeTier"
    }
  } 
}
