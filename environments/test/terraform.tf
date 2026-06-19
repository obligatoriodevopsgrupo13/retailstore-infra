terraform {
  backend "s3" {
    # Completar con el bucket remoto antes de ejecutar terraform init.
    bucket  = ""
    key     = "test/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}

provider "aws" {
  region = var.aws_region
}
