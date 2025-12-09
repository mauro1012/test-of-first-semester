terraform {
  backend "s3" {
    bucket         = "mauro-terraform-state-bucket"   
    key            = "sitio001/terraform.tfstate"     
    region         = "us-east-1"                      
    encrypt        = true                             
  }
}