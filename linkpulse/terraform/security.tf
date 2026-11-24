resource "aws_security_group" "web" {
  name        = "${var.app_name}-sg"
  description = "${var.app_name}: HTTP 80 from my IP only; no SSH"
  vpc_id      = aws_vpc.main.id

  tags = { Name = "${var.app_name}-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "http_from_my_ip" {
  security_group_id = aws_security_group.web.id
  description       = "my-ip"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "${var.my_ip}/32"
}

# Terraform removes AWS's default "allow all outbound" rule, so add it back:
# the SSM agent, ECR pulls and the k3s installer all need outbound HTTPS.
resource "aws_vpc_security_group_egress_rule" "all_out" {
  security_group_id = aws_security_group.web.id
  description       = "all outbound"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}
