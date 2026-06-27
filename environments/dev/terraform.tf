terraform {
  backend "s3" {
    bucket  = "obligatorio-devops-tfstate-grupo13-2026"
    key     = "dev/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}

provider "aws" {
  region = var.aws_region
}
