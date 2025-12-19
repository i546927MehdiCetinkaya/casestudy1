resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  tags = { Name = "casestudy1-vpc" }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
}

# Public subnets (alleen NAT en OpenVPN)
resource "aws_subnet" "public" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_subnet_cidrs[count.index]
  availability_zone = var.azs[count.index]
  map_public_ip_on_launch = true
  tags = { Name = "public-${count.index}" }
}

# Private web subnets (webservers)
resource "aws_subnet" "web" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.private_web_subnet_cidrs[count.index]
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = false # PRIVATE: geen public IP!
  tags = { Name = "web-${count.index}" }
}

# Private db subnets
resource "aws_subnet" "db" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_db_subnet_cidrs[count.index]
  availability_zone = var.azs[count.index]
  tags = { Name = "db-${count.index}" }
}

# Private monitoring subnet
resource "aws_subnet" "monitoring" {
  vpc_id                   = aws_vpc.main.id
  cidr_block               = var.monitoring_subnet_cidr
  availability_zone        = var.azs[0]
  map_public_ip_on_launch  = false
  tags = { Name = "monitoring" }
}

# NAT Instances
resource "aws_instance" "nat" {
  count         = 2
  ami           = var.ami_id
  instance_type = var.instance_type
  subnet_id     = aws_subnet.public[count.index].id
  associate_public_ip_address = true
  source_dest_check           = false
  vpc_security_group_ids      = [aws_security_group.nat.id]
  key_name      = aws_key_pair.deployer.key_name
  tags = { Name = "nat-${count.index}" }
  user_data = <<-EOF
#!/bin/bash
sysctl -w net.ipv4.ip_forward=1
iptables -t nat -A POSTROUTING -o $(ip route | awk '/default/ {print $5}') -j MASQUERADE
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
apt-get update
apt-get install -y iptables-persistent
EOF
}

# Route tables
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  count  = 2
  vpc_id = aws_vpc.main.id
  tags   = { Name = "private-${count.index}" }
}

resource "aws_route" "private_nat_route" {
  count                  = 2
  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = aws_instance.nat[count.index].primary_network_interface_id
  depends_on             = [aws_instance.nat]
}

# Web subnets zijn private, dus private route table!
resource "aws_route_table_association" "web" {
  count          = 2
  subnet_id      = aws_subnet.web[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

resource "aws_route_table_association" "db" {
  count          = 2
  subnet_id      = aws_subnet.db[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

resource "aws_route_table" "monitoring" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "monitoring" }
}

resource "aws_route" "monitoring_nat_route" {
  route_table_id         = aws_route_table.monitoring.id
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = aws_instance.nat[0].primary_network_interface_id
  depends_on             = [aws_instance.nat]
}

resource "aws_route_table_association" "monitoring" {
  subnet_id      = aws_subnet.monitoring.id
  route_table_id = aws_route_table.monitoring.id
}

# Application Load Balancer in public subnet, webservers in private subnet(targets)
resource "aws_lb" "web_alb" {
  name               = "web-alb"
  internal           = false
  load_balancer_type = "application"
  subnets            = aws_subnet.public[*].id
  security_groups    = [aws_security_group.alb.id]
}

resource "aws_lb_target_group" "web_tg" {
  name     = "web-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
  health_check {
    path = "/"
    port = "80"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.web_alb.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_tg.arn
  }
}