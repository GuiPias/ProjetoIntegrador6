resource "aws_security_group" "bastion" {
  name        = "grupo-bastion"
  description = "Bastion: acesso administrativo por SSH"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "sg-bastion"
  }
}

resource "aws_security_group" "app" {
  name        = "grupo-app"
  description = "Aplicacao: HTTPS publico e SSH apenas via bastion"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "sg-app"
  }
}

resource "aws_security_group" "db" {
  name        = "grupo-db"
  description = "Banco de dados: acessivel apenas pela aplicacao e pelo bastion"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "sg-db"
  }
}

# ---------------- Entrada ----------------

resource "aws_vpc_security_group_ingress_rule" "bastion_ssh" {
  security_group_id = aws_security_group.bastion.id
  description       = "SSH somente do CIDR autorizado do grupo"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = var.ssh_allowed_cidr
}

resource "aws_vpc_security_group_ingress_rule" "app_https" {
  security_group_id = aws_security_group.app.id
  description       = "HTTPS publico (a aplicacao e o componente exposto)"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "app_ssh" {
  security_group_id            = aws_security_group.app.id
  description                  = "SSH somente a partir do bastion"
  ip_protocol                  = "tcp"
  from_port                    = 22
  to_port                      = 22
  referenced_security_group_id = aws_security_group.bastion.id
}

resource "aws_vpc_security_group_ingress_rule" "db_postgres" {
  security_group_id            = aws_security_group.db.id
  description                  = "PostgreSQL somente a partir da aplicacao"
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  referenced_security_group_id = aws_security_group.app.id
}

resource "aws_vpc_security_group_ingress_rule" "db_ssh" {
  security_group_id            = aws_security_group.db.id
  description                  = "SSH somente a partir do bastion"
  ip_protocol                  = "tcp"
  from_port                    = 22
  to_port                      = 22
  referenced_security_group_id = aws_security_group.bastion.id
}

# ---------------- Saída (restrita ao necessário) ----------------

resource "aws_vpc_security_group_egress_rule" "bastion_to_app_ssh" {
  security_group_id            = aws_security_group.bastion.id
  description                  = "SSH do bastion para a aplicacao"
  ip_protocol                  = "tcp"
  from_port                    = 22
  to_port                      = 22
  referenced_security_group_id = aws_security_group.app.id
}

resource "aws_vpc_security_group_egress_rule" "bastion_to_db_ssh" {
  security_group_id            = aws_security_group.bastion.id
  description                  = "SSH do bastion para o banco"
  ip_protocol                  = "tcp"
  from_port                    = 22
  to_port                      = 22
  referenced_security_group_id = aws_security_group.db.id
}

resource "aws_vpc_security_group_egress_rule" "app_to_db_postgres" {
  security_group_id            = aws_security_group.app.id
  description                  = "PostgreSQL da aplicacao para o banco"
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  referenced_security_group_id = aws_security_group.db.id
}

locals {
  sg_ids = {
    bastion = aws_security_group.bastion.id
    app     = aws_security_group.app.id
    db      = aws_security_group.db.id
  }

  # HTTP e HTTPS para a internet (atualizacao de pacotes) em cada grupo
  web_egress = {
    for pair in setproduct(keys(local.sg_ids), ["80", "443"]) :
    "${pair[0]}-${pair[1]}" => { sg = local.sg_ids[pair[0]], port = tonumber(pair[1]) }
  }

  # DNS (TCP e UDP) para o resolvedor da VPC em cada grupo
  dns_egress = {
    for pair in setproduct(keys(local.sg_ids), ["tcp", "udp"]) :
    "${pair[0]}-${pair[1]}" => { sg = local.sg_ids[pair[0]], proto = pair[1] }
  }
}

resource "aws_vpc_security_group_egress_rule" "web" {
  for_each = local.web_egress

  security_group_id = each.value.sg
  description       = "HTTP/HTTPS para atualizacao de pacotes"
  ip_protocol       = "tcp"
  from_port         = each.value.port
  to_port           = each.value.port
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "dns" {
  for_each = local.dns_egress

  security_group_id = each.value.sg
  description       = "DNS para o resolvedor da VPC"
  ip_protocol       = each.value.proto
  from_port         = 53
  to_port           = 53
  cidr_ipv4         = var.vpc_cidr
}
