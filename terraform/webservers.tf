resource "aws_instance" "web" {
  count         = 2
  ami           = var.ami_id
  instance_type = var.instance_type
  subnet_id     = aws_subnet.web[count.index].id
  vpc_security_group_ids = [aws_security_group.web.id]
  key_name      = aws_key_pair.deployer.key_name
  tags = { Name = "web-${count.index}" }
  user_data = <<-EOF
#!/bin/bash
apt-get update
apt-get install -y apache2 wget curl unzip postgresql-client

systemctl start apache2
systemctl enable apache2
echo '<h1>Webserver ${count.index} (AZ ${var.azs[count.index]}) - Apache</h1>' > /var/www/html/index.html

# Install node-exporter (ARM64 versie!)
useradd --no-create-home --shell /bin/false node_exporter
wget https://github.com/prometheus/node_exporter/releases/download/v1.8.1/node_exporter-1.8.1.linux-arm64.tar.gz
tar xvf node_exporter-1.8.1.linux-arm64.tar.gz
cp node_exporter-1.8.1.linux-arm64/node_exporter /usr/local/bin/
chown node_exporter:node_exporter /usr/local/bin/node_exporter

cat <<EOL > /etc/systemd/system/node_exporter.service
[Unit]
Description=Node Exporter
After=network.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
EOL

systemctl daemon-reload
systemctl start node_exporter
systemctl enable node_exporter

# Install Promtail for Loki (ARM64)
wget https://github.com/grafana/loki/releases/download/v2.9.4/promtail-linux-arm64.zip
unzip promtail-linux-arm64.zip
mv promtail-linux-arm64 /usr/local/bin/promtail
chmod +x /usr/local/bin/promtail

# Promtail config
cat <<EOL > /etc/promtail.yaml
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://10.0.4.10:3100/loki/api/v1/push

scrape_configs:
  - job_name: "system"
    static_configs:
      - targets: [localhost]
        labels:
          job: "webservers"
          __path__: /var/log/syslog
  - job_name: "apache"
    static_configs:
      - targets: [localhost]
        labels:
          job: "apache"
          __path__: /var/log/apache2/*.log
EOL

# Promtail service
cat <<EOL > /etc/systemd/system/promtail.service
[Unit]
Description=Promtail service
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/promtail -config.file /etc/promtail.yaml

[Install]
WantedBy=multi-user.target
EOL

systemctl daemon-reload
systemctl start promtail
systemctl enable promtail
EOF
}

resource "aws_lb_target_group_attachment" "web" {
  count            = 2
  target_group_arn = aws_lb_target_group.web_tg.arn
  target_id        = aws_instance.web[count.index].id
  port             = 80
}