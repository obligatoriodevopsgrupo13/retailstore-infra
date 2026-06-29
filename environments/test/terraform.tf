terraform {
  backend "s3" {
    bucket  = "obligatorio-devops-tfstate-13"
    key     = "test/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}

provider "aws" {
  region = var.aws_region
}
