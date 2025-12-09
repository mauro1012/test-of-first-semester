output "alb_dns_name" {
  description = "El DNS Name del Application Load Balancer"
  value       = aws_lb.web_lb.dns_name
}