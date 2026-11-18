# ADR-005: Estratégia de backup (política GFS, mecanismo e local)

**Status:** Aceita. A política mínima está **implantada** (`infra/backup.tf`); a política conservadora (GFS) existe só no plano. Complementa o ADR-003, cuja consequência (banco sem backup) é tratada aqui.

No contexto de um banco PostgreSQL em uma instância EC2 (ADR-003), sem backup na Entrega 1, com RPO de 24 horas e RTO de 4 horas,
diante da exigência de um plano conservador no esquema GFS e de uma política mínima configurada por Terraform, com custo próximo de zero,
decidimos adotar, no plano, snapshots do disco do banco pelo Data Lifecycle Manager (DLM) em três gerações (Son diária com 7 cópias, Father semanal com 5 e Grandfather mensal com 12, às 03:00 UTC, classe Standard) e, na implantação, apenas a geração Son, com retenção de 2 cópias, tag `Backup=diario` e snapshots criptografados por herança do volume,
e descartamos o dump lógico em bucket S3 (exigiria um papel IAM nas instâncias, contrariando o controle S5, e um bucket), a classe de armazenamento Archive e a cópia entre regiões (sem preço cotado, fora do cálculo de custo),
para ter o backup do disco inteiro com o mecanismo nativo da AWS e sem dar às instâncias acesso a serviços da conta, a um custo estimado de US$ 21,01 em 12 meses na política GFS e de poucos centavos por semana na política mínima,
aceitando que os snapshots são consistentes apenas como uma queda de energia (*crash-consistent*), que a política mínima não permite voltar mais de 2 dias nem tem cópia em outra região, e que os snapshots criados pelo DLM não são removidos pelo `terraform destroy` e precisam ser apagados manualmente.

**Contexto adicional.**

- O preço do snapshot (US$ 0,068 por GB-mês) foi derivado das estimativas da calculadora, e não lido numa tabela de preços; as premissas estão em `docs/backup.md`, item B7.
- Em produção, a consistência seria melhorada com `pg_dump` ou com `pg_backup_start`/`pg_backup_stop` em torno do snapshot.
- Com o RDS da proposta de alta disponibilidade (ADR-004), a geração Son passaria a ser o backup automático do serviço, e o custo do backup precisaria ser recalculado.
