# Errata: divergências entre a Entrega 1 e o que foi implantado

Este documento registra tudo o que a implantação da Entrega 2 fez de forma diferente do projeto da Entrega 1, com o motivo. Os documentos da Entrega 1 (`docs/arquitetura.md` e os ADR-001 a ADR-003) foram mantidos como entregues; o diagrama da Entrega 1 foi atualizado nos pontos abaixo.

**Sobre os ADR.** Nenhuma decisão registrada nos ADR da Entrega 1 foi trocada na implantação, então nenhum recebeu o status "substituída". Os ADR-001, ADR-002 e ADR-003 continuam válidos para o que foi implantado, e receberam uma linha de status: eles são revistos, apenas para a **proposta de alta disponibilidade** (não implantada), pelo ADR-004. O ADR-003 é complementado pelo ADR-005 (backup).

## Divergências e acréscimos

| # | Item | Entrega 1 | Implantado | Motivo | ADR afetado | Evidência |
|---|---|---|---|---|---|---|
| 1 | Protocolo e porta da aplicação | HTTP na porta 8080, sem HTTPS (`arquitetura.md`, seções 5.1, 5.2 e 5.5, e risco 6) | HTTPS na porta 443, com certificado autoassinado. As portas 80 e 8080 ficam fechadas | Controle S3 da Entrega 2 | Nenhum (a decisão estava na descrição da aplicação, não em um ADR) | `app-lista.png`, `portas-fechadas.png` |
| 2 | Nomes dos grupos de segurança | `sg-bastion`, `sg-app`, `sg-db` | Nomes `grupo-bastion`, `grupo-app`, `grupo-db`. A tag `Name` continua `sg-bastion`, `sg-app`, `sg-db` | A AWS não aceita nomes de grupo que começam com `sg-` (a validação do Terraform falhou) | Nenhum | `infra/security.tf` |
| 3 | IP de origem do SSH | `200.138.86.47/32` (`arquitetura.md`, seção 5.5) | `177.73.97.182/32` em 17/11/2026, informado por variável (`ssh_allowed_cidr`). Deve ser conferido a cada `apply` | O IP público do provedor mudou, como o ADR-001 previa nas consequências | ADR-001 (decisão mantida, consequência ocorrida) | `docs/seguranca.md` |
| 4 | Regras explícitas de DNS | A Entrega 1 dizia que o DNS não passa pelos grupos e que isso seria confirmado | Foram criadas regras de saída para DNS (TCP e UDP 53) até o resolvedor da VPC, em cada grupo | Documentar a saída por completo (controle S2). A necessidade na AWS não foi testada sem elas | Nenhum | `infra/security.tf` |
| 5 | Backup | Banco sem backup (`arquitetura.md`, risco 2, e consequência do ADR-003) | Política mínima por DLM: snapshot diário do disco do banco, retenção de 2 cópias, snapshots criptografados | Parte D da Entrega 2 | ADR-003 (mantido e complementado), ADR-005 (novo) | `snapshot-dlm.png`, `snapshot-dlm.json` |
| 6 | Papéis e permissões IAM | A Entrega 1 não previa papéis | Papel `integrador-dlm-backup` (serviço DLM). Nenhuma instância recebe papel. O usuário `terraform` ganhou a política em linha `terraform-backup-dlm`, restrita a esse papel | O DLM precisa de um papel para criar snapshots, e o Terraform precisou de permissão para criá-lo (erro `AccessDenied` na primeira execução) | ADR-005 | `docs/seguranca.md` |
| 7 | Endereços IP públicos | "IP público estático" na aplicação e no bastion (diagrama) | São Elastic IPs criados a cada `apply` e liberados no `destroy`, portanto **mudam a cada recriação** | O ambiente é destruído entre as sessões, como definido na estratégia de custo do cenário B | ADR-001 (o bastion usa Elastic IP) | `docs/arquitetura.md`, seção 5.9 |
| 8 | Proteções de disco e de instância | Não especificadas | Discos raiz criptografados (S6), IMDSv2 obrigatório, `ebs_optimized = true` | Controles S6 e S7 e correção de achado do Checkov | Nenhum | `ebs-imdsv2.png`, `docs/seguranca.md` |
| 9 | Custo real do período de testes | Cenário B: US$ 7,57 para 40 horas | Primeira execução de cerca de 22 horas, com custo estimado de cerca de US$ 4. **A conferir no painel de faturamento** | Ambiente destruído ao fim de cada sessão | Nenhum | Painel de faturamento (a coletar) |

## Diagrama da Entrega 1

`docs/diagramas/arquitetura.drawio` e `arquitetura.png` foram atualizados para refletir a implantação: a aplicação passa a aparecer com HTTPS na porta 443 (item 1), e as notas do diagrama deixam de dizer que não há HTTPS. O restante do diagrama (zona única, sub-redes, NAT, bastion) corresponde ao que foi implantado.

## Situação dos riscos da seção 5.10 da Entrega 1

| # | Risco | Situação após a Entrega 2 |
|---|---|---|
| 1 | Zona única | Mantido. A alta disponibilidade é apenas projetada (`docs/alta-disponibilidade.md`) |
| 2 | Banco único, sem backup | **Reduzido**: há snapshot diário com retenção de 2 cópias. A instância continua única |
| 3 | Aplicação em uma instância | Mantido |
| 4 | NAT único | Mantido |
| 5 | Bastion único e SSH preso ao IP | Mantido. O IP do grupo mudou e foi atualizado por variável (item 3) |
| 6 | HTTP sem HTTPS e sem login | **HTTPS resolvido** (item 1). A falta de login continua |
| 7 | Limite de créditos de CPU das instâncias T3 | Mantido |
