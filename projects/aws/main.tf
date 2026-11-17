terraform {
  required_version = ">= 1.5.0"
  required_providers { aws = { source = "hashicorp/aws", version = "~> 5.0" } }
}
provider "aws" { region = var.region }
variable "region" { type = string; default = "eu-west-2" }
variable "project" { type = string; default = "portfolio-lab" }
variable "instance_type" { type = string; default = "t3.micro" }
data "aws_ami" "linux" {
  most_recent = true
  owners = ["amazon"]
  filter { name = "name"; values = ["al2023-ami-2023.*-x86_64"] }
  filter { name = "virtualization-type"; values = ["hvm"] }
}
resource "aws_vpc" "lab" { cidr_block = "10.42.0.0/16"; enable_dns_hostnames = true; tags = { Name = "${var.project}-vpc" } }
resource "aws_internet_gateway" "igw" { vpc_id = aws_vpc.lab.id }
resource "aws_subnet" "public" { vpc_id = aws_vpc.lab.id; cidr_block = "10.42.1.0/24"; map_public_ip_on_launch = true; availability_zone = "${var.region}a"; tags = { Name = "${var.project}-public" } }
resource "aws_subnet" "private" { vpc_id = aws_vpc.lab.id; cidr_block = "10.42.2.0/24"; availability_zone = "${var.region}a"; tags = { Name = "${var.project}-private" } }
resource "aws_route_table" "public" { vpc_id = aws_vpc.lab.id; route { cidr_block = "0.0.0.0/0"; gateway_id = aws_internet_gateway.igw.id } }
resource "aws_route_table_association" "public" { subnet_id = aws_subnet.public.id; route_table_id = aws_route_table.public.id }
resource "aws_security_group" "web" {
  name_prefix = "${var.project}-web-"; vpc_id = aws_vpc.lab.id
  ingress { description = "Demo HTTP"; from_port = 80; to_port = 80; protocol = "tcp"; cidr_blocks = ["0.0.0.0/0"] }
  egress { from_port = 0; to_port = 0; protocol = "-1"; cidr_blocks = ["0.0.0.0/0"] }
}
resource "aws_instance" "web" {
  ami = data.aws_ami.linux.id; instance_type = var.instance_type
  subnet_id = aws_subnet.public.id; vpc_security_group_ids = [aws_security_group.web.id]
  metadata_options { http_tokens = "required" }
  root_block_device { encrypted = true; volume_size = 10 }
  user_data = <<-EOF
    #!/bin/bash
    dnf install -y nginx
    echo '<h1>AWS infrastructure lab</h1><p>Terraform deployed</p>' > /usr/share/nginx/html/index.html
    systemctl enable --now nginx
  EOF
  tags = { Name = "${var.project}-web" }
}
resource "aws_s3_bucket" "artifacts" { bucket_prefix = "${var.project}-artifacts-"; force_destroy = true }
resource "aws_s3_bucket_public_access_block" "artifacts" { bucket = aws_s3_bucket.artifacts.id; block_public_acls = true; block_public_policy = true; ignore_public_acls = true; restrict_public_buckets = true }
resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" { bucket = aws_s3_bucket.artifacts.id; rule { apply_server_side_encryption_by_default { sse_algorithm = "AES256" } } }
output "demo_url" { value = "http://${aws_instance.web.public_ip}" }
output "bucket_name" { value = aws_s3_bucket.artifacts.id }
output "private_subnet_id" { value = aws_subnet.private.id }
