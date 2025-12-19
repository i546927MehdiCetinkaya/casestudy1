resource "aws_db_subnet_group" "db" {
  name       = "db-subnet-group"
  subnet_ids = aws_subnet.db[*].id
}

resource "aws_db_instance" "db" {
  count                     = 2
  identifier                = "case-db-${count.index}"
  engine                    = "postgres"
  instance_class            = "db.t4g.micro"
  db_subnet_group_name      = aws_db_subnet_group.db.name
  allocated_storage         = 20
  username                  = var.db_username
  password                  = var.db_password
  vpc_security_group_ids    = [aws_security_group.db.id]
  skip_final_snapshot       = true
  publicly_accessible       = false
  multi_az                  = false
  db_name                   = "case_db"
  availability_zone         = var.azs[count.index]
  tags = { Name = "rds-db-${count.index}" }
}