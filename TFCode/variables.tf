variable "dynamodb_table_name" {
  type = string
}
variable "dynamodb_table_capacity" {
  type = string
}
variable "dynamodb_hash_key" {
  type = string
}
variable "lambda_runtime" {
  type = string
}
variable "lambda_handler" {
  type = string
}
variable "lambda_function_name" {
  type = string
}
variable "service_name" {
  description = "The name for the ECS service."
  type        = string
  default     = "flask-docker"
}
variable "ecs_image_url" {
  description = "The desired ECR image URL."
  type        = string
}
variable "flask_port" {
  type = string
}
variable "http_port" {
  type = string
}
variable "https_port" {
  type = string
}
variable "service_prefix" {
  type = string
}
output "dns_name" {
  description = "The DNS of the load balancer."
  value       = aws_lb.lb.dns_name
}
