provider "aws" {
  profile = "kh-labs"
  region  = "me-south-1"
}

module "jenkins" {
  name            = var.name
  env             = "jenkins"
  source          = "./jenkins"
  key_name        = var.key_name
  public_key_path = var.public_key_path
}

