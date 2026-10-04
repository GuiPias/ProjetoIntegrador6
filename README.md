# Cadastro de Produtos na AWS: Projeto de Arquitetura (Entrega 1)

Projeto Integrador | Uniamérica Descomplica | Professor Gildomiro Bairros

## Grupo

| Integrante |
|---|---|
| Luiz Guilherme Moura Pias |
| Daniel Spies Amaral |
| Mohamad Jbahi |
| Joao Victor Godoy |

## Visão geral

Aplicação web de cadastro de produtos (nome e quantidade em estoque, com criar, listar, editar e excluir), em Spring Boot (Java 21) com banco PostgreSQL 16, hospedada na AWS (região `sa-east-1`, São Paulo) em uma VPC com sub-rede pública (bastion e aplicação) e sub-rede privada (banco), com saída para a internet pelo NAT Gateway. A infraestrutura será criada com Terraform na Entrega 2.

## Estrutura do repositório

| Caminho | Conteúdo |
|---|---|
| `docs/arquitetura.md` | Descrição, endereçamento, rotas, segurança, tecnologias, dimensionamento, custos e riscos |
| `docs/adr/` | Três ADRs: acesso administrativo, saída da sub-rede privada e localização do banco |
| `docs/diagramas/` | Diagrama editável (`arquitetura.drawio`) e imagem (`arquitetura.png`) |
| `docs/custos/` | Estimativas exportadas da AWS Pricing Calculator (cenários A e B) |
| `infra/` | Vazio nesta entrega; será usado para o Terraform na Entrega 2 |
| `IA.md` | Declaração de uso de IA |

## Resumo da arquitetura

- VPC `10.20.0.0/16`, zona única `sa-east-1a`, sub-redes `pub-a` (10.20.1.0/24) e `priv-a` (10.20.10.0/24).
- SSH somente do IP do grupo, pelo bastion; banco sem IP público, acessível apenas pela aplicação.
- Custo estimado: US$ 134,14 por mês com a infraestrutura ligada sempre (cenário A) e cerca de US$ 7,57 no período de trabalho da Entrega 2 (cenário B).
