provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Projeto   = var.projeto
      Grupo     = var.grupo
      Entrega   = "2"
      ManagedBy = "terraform"
    }
  }
}
