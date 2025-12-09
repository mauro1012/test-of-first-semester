variable "aws_region" {
  description = "Región de AWS para el despliegue"
  default     = "us-east-1" 
}

variable "image_repo_name" {
  description = "mauro28102023/sitio001:latest"
  type        = string
}

variable "instance_type" {
  description = "Tipo de instancia EC2"
  default     = "t3.micro"
}