# Web tier - Allow HTTP from the internet
resource "aws_vpc_security_group_ingress_rule" "web_http" {
  security_group_id = aws_security_group.web.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"

  description = "Allow HTTP traffic to web tier"
}

# Web tier - Allow HTTPS from the internet
resource "aws_vpc_security_group_ingress_rule" "web_https" {
  security_group_id = aws_security_group.web.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"

  description = "Allow HTTPS traffic to web tier"
}

# Application tier - Allow traffic from Web tier
resource "aws_vpc_security_group_ingress_rule" "application_from_web" {
  security_group_id            = aws_security_group.application.id
  referenced_security_group_id = aws_security_group.web.id
  from_port                    = 8080
  to_port                      = 8080
  ip_protocol                  = "tcp"

  description = "Allow application traffic from web tier"
}

# Database tier - Allow traffic from Application tier
# PostgreSQL port 5432 is used as an example
resource "aws_vpc_security_group_ingress_rule" "database_from_application" {
  security_group_id            = aws_security_group.database.id
  referenced_security_group_id = aws_security_group.application.id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"

  description = "Allow PostgreSQL traffic from application tier"
}
# Web tier - Allow outbound traffic to Application tier
resource "aws_vpc_security_group_egress_rule" "web_to_application" {
  security_group_id            = aws_security_group.web.id
  referenced_security_group_id = aws_security_group.application.id
  from_port                    = 8080
  to_port                      = 8080
  ip_protocol                  = "tcp"

  description = "Allow web tier to communicate with application tier"
}

# Application tier - Allow outbound traffic to Database tier
resource "aws_vpc_security_group_egress_rule" "application_to_database" {
  security_group_id            = aws_security_group.application.id
  referenced_security_group_id = aws_security_group.database.id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"

  description = "Allow application tier to communicate with database tier"
}