
# ==========================================
# AWS Infrastructure Portfolio
# Terraform Outputs
# ==========================================

# VPC
output "vpc_id" {
  description = "ID of the portfolio VPC"
  value       = aws_vpc.main.id
}

# Subnets
output "public_subnet_id" {
  description = "ID of the public web subnet"
  value       = aws_subnet.public.id
}

output "application_subnet_id" {
  description = "ID of the private application subnet"
  value       = aws_subnet.application.id
}

output "database_subnet_id" {
  description = "ID of the private database subnet"
  value       = aws_subnet.database.id
}

# Internet Gateway
output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = aws_internet_gateway.main.id
}

# Security Groups
output "web_security_group_id" {
  description = "ID of the web tier security group"
  value       = aws_security_group.web.id
}

output "application_security_group_id" {
  description = "ID of the application tier security group"
  value       = aws_security_group.application.id
}

output "database_security_group_id" {
  description = "ID of the database tier security group"
  value       = aws_security_group.database.id
}
