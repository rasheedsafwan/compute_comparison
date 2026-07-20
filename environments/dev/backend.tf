terraform {
  backend "s3" {
    bucket         = "compute-comparison-tfstate-safwinho"
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "compute-comparison-tf-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = "us-east-1"
}