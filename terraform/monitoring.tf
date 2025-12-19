resource "aws_instance" "monitoring" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.monitoring.id
  vpc_security_group_ids = [aws_security_group.monitoring.id]
  key_name               = aws_key_pair.deployer.key_name
  private_ip             = "10.0.4.10"

  user_data = <<-EOF
    #!/bin/bash
    set -eux

    # Forceer resolv.conf statisch naar VPC DNS (vervang systemd-resolved symlink!)
    rm -f /etc/resolv.conf
    echo "nameserver 10.0.0.2" > /etc/resolv.conf

    apt-get update
    apt-get install -y docker.io docker-compose
    systemctl enable docker

    echo '{ "dns": ["10.0.0.2"] }' > /etc/docker/daemon.json
    systemctl restart docker

    mkdir -p /opt/monitoring

    cat > /opt/monitoring/docker-compose.yml <<EOL
    version: '3'
    services:
      prometheus:
        image: prom/prometheus:latest
        ports:
          - "9090:9090"
        volumes:
          - ./prometheus.yml:/etc/prometheus/prometheus.yml
      grafana:
        image: grafana/grafana:latest
        ports:
          - "3000:3000"
      loki:
        image: grafana/loki:latest
        ports:
          - "3100:3100"
    EOL

    cat > /opt/monitoring/prometheus.yml <<EOL
    global:
      scrape_interval: 15s
    scrape_configs:
      - job_name: 'prometheus'
        static_configs:
          - targets: ['localhost:9090']
      - job_name: 'webservers'
        static_configs:
          - targets: ['web0.casestudy1.local:9100', 'web1.casestudy1.local:9100']
    EOL

    cd /opt/monitoring
    docker-compose up -d
  EOF

  tags = {
    Name = "monitoring"
  }
}