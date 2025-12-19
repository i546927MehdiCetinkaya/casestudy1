resource "aws_instance" "openvpn" {
  ami           = var.ami_id
  instance_type = var.instance_type
  subnet_id     = aws_subnet.public[0].id
  vpc_security_group_ids = [aws_security_group.vpn.id]
  key_name      = aws_key_pair.deployer.key_name
  tags = { Name = "openvpn" }
  user_data = <<-EOF
    #!/bin/bash
    set -eux

    export DEBIAN_FRONTEND=noninteractive

    apt-get update
    apt-get install -y wget

    # Download OpenVPN install script (gebruik de RAW githubusercontent link!)
    wget https://raw.githubusercontent.com/Nyr/openvpn-install/master/openvpn-install.sh -O /root/openvpn-install.sh
    chmod +x /root/openvpn-install.sh

    # Installeer OpenVPN en maak client 'mehdi' direct aan (NON-INTERACTIEF)
    AUTO_INSTALL=y \
    APPROVE_INSTALL=y \
    APPROVE_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4) \
    APPROVE_DNS=1 \
    ENDPOINT=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4) \
    CLIENT=mehdi \
    bash /root/openvpn-install.sh

    # Forceer push van AWS VPC DNS naar clients (voor casestudy1.local DNS resolutie)
    echo 'push "dhcp-option DNS 10.0.0.2"' >> /etc/openvpn/server.conf

    # Herstart OpenVPN om DNS wijziging actief te maken
    systemctl restart openvpn@server

    # Zet .ovpn bestand klaar voor download
    cp /root/mehdi.ovpn /home/ubuntu/
    chown ubuntu:ubuntu /home/ubuntu/mehdi.ovpn
  EOF
}