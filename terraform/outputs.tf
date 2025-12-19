output "alb_dns" {
  value = aws_lb.web_alb.dns_name
}
output "monitoring_private_ip" {
  value = aws_instance.monitoring.private_ip
}
output "db_endpoints" {
  value = aws_db_instance.db[*].endpoint
}