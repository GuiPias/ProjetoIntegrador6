variable "region" {
  type        = string
  description = "Região da AWS."
  default     = "sa-east-1"
}

variable "availability_zone" {
  type        = string
  description = "Zona de disponibilidade onde ficam todos os recursos."
  default     = "sa-east-1a"
}

variable "projeto" {
  type        = string
  description = "Nome do projeto, usado na tag Projeto."
  default     = "integrador"
}

variable "grupo" {
  type        = string
  description = "Identificação do grupo, usada na tag Grupo."
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR da VPC."
  default     = "10.20.0.0/16"
}

variable "public_subnet_cidr" {
  type        = string
  description = "CIDR da sub-rede pública (pub-a)."
  default     = "10.20.1.0/24"
}

variable "private_subnet_cidr" {
  type        = string
  description = "CIDR da sub-rede privada (priv-a)."
  default     = "10.20.10.0/24"
}

variable "bastion_ip" {
  type        = string
  description = "IP privado fixo do bastion (dentro da sub-rede pública)."
  default     = "10.20.1.10"
}

variable "app_ip" {
  type        = string
  description = "IP privado fixo da aplicação (dentro da sub-rede pública)."
  default     = "10.20.1.20"
}

variable "db_ip" {
  type        = string
  description = "IP privado fixo do banco (dentro da sub-rede privada)."
  default     = "10.20.10.10"
}

variable "ssh_allowed_cidr" {
  type        = string
  description = "CIDR autorizado a acessar o bastion por SSH (ex.: IP do grupo com /32). Nunca 0.0.0.0/0."

  validation {
    condition     = can(cidrhost(var.ssh_allowed_cidr, 0)) && var.ssh_allowed_cidr != "0.0.0.0/0"
    error_message = "Informe um CIDR válido e diferente de 0.0.0.0/0."
  }
}

variable "ssh_public_key" {
  type        = string
  description = "Chave pública SSH (conteúdo do arquivo .pub). A chave privada nunca entra no repositório."
}

variable "bastion_instance_type" {
  type        = string
  description = "Tipo da instância do bastion."
  default     = "t3.micro"
}

variable "app_instance_type" {
  type        = string
  description = "Tipo da instância da aplicação."
  default     = "t3.small"
}

variable "db_instance_type" {
  type        = string
  description = "Tipo da instância do banco de dados."
  default     = "t3.micro"
}

variable "bastion_volume_gb" {
  type        = number
  description = "Tamanho do disco gp3 do bastion, em GB."
  default     = 8
}

variable "app_volume_gb" {
  type        = number
  description = "Tamanho do disco gp3 da aplicação, em GB."
  default     = 10
}

variable "db_volume_gb" {
  type        = number
  description = "Tamanho do disco gp3 do banco, em GB."
  default     = 20
}

variable "db_name" {
  type        = string
  description = "Nome do banco de dados da aplicação."
  default     = "produtos"
}

variable "db_user" {
  type        = string
  description = "Usuário do banco de dados da aplicação."
  default     = "produtos"
}

variable "db_password" {
  type        = string
  description = "Senha do banco. Informar por variável de ambiente TF_VAR_db_password. Apenas letras, números, ponto, hífen e sublinhado, com 12 ou mais caracteres."
  sensitive   = true

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]{12,}$", var.db_password))
    error_message = "Use 12 ou mais caracteres entre letras, números, ponto, hífen e sublinhado."
  }
}

variable "keystore_password" {
  type        = string
  description = "Senha do keystore HTTPS autoassinado. Informar por variável de ambiente TF_VAR_keystore_password. Mesmas regras da senha do banco."
  sensitive   = true

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]{12,}$", var.keystore_password))
    error_message = "Use 12 ou mais caracteres entre letras, números, ponto, hífen e sublinhado."
  }
}

variable "jar_url" {
  type        = string
  description = "URL pública do produtos.jar (ex.: release do GitHub). Se vazio, o JAR é copiado manualmente por SCP, conforme o README."
  default     = ""
}

variable "backup_hora_utc" {
  type        = string
  description = "Horário diário (UTC, formato HH:MM) em que a política de backup tira o snapshot do disco do banco."
  default     = "03:00"
}

variable "backup_retencao" {
  type        = number
  description = "Quantidade de snapshots diários retidos (política mínima: no máximo 2)."
  default     = 2

  validation {
    condition     = var.backup_retencao >= 1 && var.backup_retencao <= 2
    error_message = "A política mínima exige retenção de 1 a 2 cópias."
  }
}
