variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-south-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "domain_name" {
  description = "Domain name for the application"
  type        = string
  default     = "datakeep.ai"
}

variable "certificate_arn" {
  description = "ACM certificate ARN for HTTPS (create with: make cert)"
  type        = string
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "web_desired_count" {
  description = "Desired number of web tasks"
  type        = number
  default     = 1
}

variable "web_max_count" {
  description = "Maximum number of web tasks for auto-scaling"
  type        = number
  default     = 2
}
