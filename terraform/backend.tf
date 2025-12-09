terraform {
  backend "s3" {
    bucket         = "mauro-terraform-state-bucket"   # ¡Cambia esto por el nombre de tu bucket!
    key            = "sitio001/terraform.tfstate"     # Ruta y nombre del archivo dentro del bucket
    region         = "us-east-1"                      # Asegúrate de que coincida con var.aws_region
    encrypt        = true                             # Buena práctica
  }
}