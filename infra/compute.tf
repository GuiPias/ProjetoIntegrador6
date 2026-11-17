data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_key_pair" "grupo" {
  key_name   = "chave-${var.grupo}"
  public_key = var.ssh_public_key

  tags = {
    Name = "chave-${var.grupo}"
  }
}

# ---------------- Bastion ----------------

resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.bastion_instance_type
  ebs_optimized               = true
  subnet_id                   = aws_subnet.public.id
  private_ip                  = var.bastion_ip
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  key_name                    = aws_key_pair.grupo.key_name
  associate_public_ip_address = true
  user_data                   = templatefile("${path.module}/scripts/bastion.sh.tftpl", {})
  user_data_replace_on_change = true

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.bastion_volume_gb
    encrypted             = true
    delete_on_termination = true
  }

  tags = {
    Name  = "bastion"
    Papel = "bastion"
  }

  depends_on = [aws_internet_gateway.main]

  lifecycle {
    ignore_changes = [ami]
  }
}

resource "aws_eip" "bastion" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.main]

  tags = {
    Name = "eip-bastion"
  }
}

resource "aws_eip_association" "bastion" {
  instance_id   = aws_instance.bastion.id
  allocation_id = aws_eip.bastion.id
}

# ---------------- Banco de dados (sub-rede privada, sem IP público) ----------------

resource "aws_instance" "db" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.db_instance_type
  ebs_optimized               = true
  subnet_id                   = aws_subnet.private.id
  private_ip                  = var.db_ip
  vpc_security_group_ids      = [aws_security_group.db.id]
  key_name                    = aws_key_pair.grupo.key_name
  associate_public_ip_address = false
  user_data_replace_on_change = true

  user_data = templatefile("${path.module}/scripts/db.sh.tftpl", {
    db_ip       = var.db_ip
    app_ip      = var.app_ip
    db_name     = var.db_name
    db_user     = var.db_user
    db_password = var.db_password
  })

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.db_volume_gb
    encrypted             = true
    delete_on_termination = true

    # A política de backup (backup.tf) seleciona o disco por esta tag.
    tags = {
      Name   = "disco-banco"
      Backup = "diario"
    }
  }

  tags = {
    Name  = "banco"
    Papel = "banco"
  }

  # A saída pelo NAT precisa existir antes do boot (instalação de pacotes).
  depends_on = [aws_route.private_nat]

  lifecycle {
    ignore_changes = [ami]
  }
}

# ---------------- Aplicação (sub-rede pública, HTTPS) ----------------

resource "aws_instance" "app" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.app_instance_type
  ebs_optimized               = true
  subnet_id                   = aws_subnet.public.id
  private_ip                  = var.app_ip
  vpc_security_group_ids      = [aws_security_group.app.id]
  key_name                    = aws_key_pair.grupo.key_name
  associate_public_ip_address = true
  user_data_replace_on_change = true

  user_data = templatefile("${path.module}/scripts/app.sh.tftpl", {
    db_host           = var.db_ip
    db_name           = var.db_name
    db_user           = var.db_user
    db_password       = var.db_password
    keystore_password = var.keystore_password
    jar_url           = var.jar_url
  })

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.app_volume_gb
    encrypted             = true
    delete_on_termination = true
  }

  tags = {
    Name  = "aplicacao"
    Papel = "aplicacao"
  }

  depends_on = [aws_internet_gateway.main, aws_instance.db]

  lifecycle {
    ignore_changes = [ami]
  }
}

resource "aws_eip" "app" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.main]

  tags = {
    Name = "eip-aplicacao"
  }
}

resource "aws_eip_association" "app" {
  instance_id   = aws_instance.app.id
  allocation_id = aws_eip.app.id
}
