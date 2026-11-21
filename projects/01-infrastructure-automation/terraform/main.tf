
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "portfolio-three-tier-vpc"
    Project     = "CloudInfrastructurePortfolio"
    Environment = "Lab"
    ManagedBy   = "Terraform"
  }
}
# Public subnet - Web tier
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "eu-north-1a"
  map_public_ip_on_launch = false

  tags = {
    Name        = "portfolio-public-subnet"
    Tier        = "Web"
    Environment = "Lab"
    ManagedBy   = "Terraform"
  }
}

# Private subnet - Application tier
resource "aws_subnet" "application" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "eu-north-1a"

  tags = {
    Name        = "portfolio-application-subnet"
    Tier        = "Application"
    Environment = "Lab"
    ManagedBy   = "Terraform"
  }
}

# Private subnet - Database tier
resource "aws_subnet" "database" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "eu-north-1a"

  tags = {
    Name        = "portfolio-database-subnet"
    Tier        = "Database"
    Environment = "Lab"
    ManagedBy   = "Terraform"
  }
}
# Internet Gateway for the public subnet
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "portfolio-internet-gateway"
    Environment = "Lab"
    ManagedBy   = "Terraform"
  }
}
# Public route table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name        = "portfolio-public-route-table"
    Environment = "Lab"
    ManagedBy   = "Terraform"
  }
}

# Associate public subnet with public route table
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Private route table - Application tier
resource "aws_route_table" "application" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "portfolio-application-route-table"
    Environment = "Lab"
    ManagedBy   = "Terraform"
  }
}

# Associate application subnet
resource "aws_route_table_association" "application" {
  subnet_id      = aws_subnet.application.id
  route_table_id = aws_route_table.application.id
}

# Private route table - Database tier
resource "aws_route_table" "database" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "portfolio-database-route-table"
    Environment = "Lab"
    ManagedBy   = "Terraform"
  }
}

# Associate database subnet
resource "aws_route_table_association" "database" {
  subnet_id      = aws_subnet.database.id
  route_table_id = aws_route_table.database.id
}
# Web tier security group
resource "aws_security_group" "web" {
  name        = "portfolio-web-sg"
  description = "Security group for web tier"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name        = "portfolio-web-sg"
    Environment = "Lab"
    ManagedBy   = "Terraform"
  }
}

# Application tier security group
resource "aws_security_group" "application" {
  name        = "portfolio-application-sg"
  description = "Security group for application tier"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name        = "portfolio-application-sg"
    Environment = "Lab"
    ManagedBy   = "Terraform"
  }
}

# Database tier security group
resource "aws_security_group" "database" {
  name        = "portfolio-database-sg"
  description = "Security group for database tier"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name        = "portfolio-database-sg"
    Environment = "Lab"
    ManagedBy   = "Terraform"
  }
}