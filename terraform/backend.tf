terraform {
  backend "s3" {
    bucket         = "mlknljnjlbh"   
    key            = "sitio001/terraform.tfstate"     
    region         = "us-east-1"                      
    encrypt        = true                             
  }
}