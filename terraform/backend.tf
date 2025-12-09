terraform {
  backend "s3" {
    bucket         = "test-fist-quest"   
    key            = "sitio001/terraform.tfstate"     
    region         = "us-east-1"                      
    encrypt        = true                             
  }
}