resource "aws_route53_zone" "main" {
  name = "casestudy1.local"
  vpc {
    vpc_id = aws_vpc.main.id
  }
}
resource "aws_route53_record" "web" {
  count   = length(aws_instance.web)
  zone_id = aws_route53_zone.main.zone_id
  name    = "web${count.index}"
  type    = "A"
  ttl     = 300
  records = [aws_instance.web[count.index].private_ip]
}

# Optioneel: een overkoepelend web record (voor round robin op beide webservers)
resource "aws_route53_record" "web_main" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "web"
  type    = "A"
  ttl     = 300
  records = [for w in aws_instance.web : w.private_ip]
}

resource "aws_route53_record" "monitoring" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "monitoring"
  type    = "A"
  ttl     = 300
  records = [aws_instance.monitoring.private_ip]
}

resource "aws_route53_record" "db" {
  count   = 2
  zone_id = aws_route53_zone.main.zone_id
  name    = "db${count.index}"
  type    = "CNAME"
  ttl     = 300
  records = [aws_db_instance.db[count.index].endpoint]
}

# Optioneel: een enkelvoudig db record voor makkelijke connectie (verwijst naar de eerste DB instance)
resource "aws_route53_record" "db_main" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "db"
  type    = "CNAME"
  ttl     = 300
  records = [aws_db_instance.db[0].endpoint]
}