# ADR-004: Estratégia de alta disponibilidade (incluindo NAT e banco)

**Status:** Aceita como proposta, **não implantada**. Revê, para a proposta, os ADR-001 (acesso administrativo), ADR-002 (NAT) e ADR-003 (banco). A arquitetura implantada continua sendo a descrita por esses três ADR.

No contexto de uma aplicação interna de cadastro de produtos (até 10 usuários simultâneos, RPO de 24 horas e RTO de 4 horas) que a Entrega 1 implantou em uma única zona, com sete pontos únicos de falha,
diante da exigência de projetar a alta disponibilidade sem implantá-la e de comparar o custo com o cenário A,
decidimos propor duas zonas (`sa-east-1a` e `sa-east-1c`), com um Application Load Balancer e um grupo de autoescalonamento de 2 a 4 instâncias t3.small em sub-redes privadas, um NAT Gateway por zona, o RDS PostgreSQL Multi-AZ (db.t3.micro) para o banco e o Session Manager no lugar do bastion,
e descartamos manter uma só zona apoiada apenas em backup, um NAT compartilhado entre as zonas, uma réplica própria do PostgreSQL em EC2 e a duplicação do bastion por zona,
para eliminar a falha de zona e de instância sem depender de ação manual no momento da falha (promoção do banco, troca do NAT, acesso por IP fixo),
aceitando um custo de US$ 285,03 por mês (**+112%** sobre os US$ 134,14 do cenário A), que **não se justifica** para o perfil atual de uso, e por isso a proposta permanece apenas projetada; aceitando também que a falta de login continua, que a região única continua sendo um ponto de falha e que as instâncias novas ainda dependem do GitHub para baixar o JAR.

**Contexto adicional.**

- **NAT por zona:** a recuperação de uma zona depende de instâncias novas que baixam pacotes e o JAR pela internet. Com um NAT compartilhado, a zona sobrevivente perderia essa saída. O NAT compartilhado reduziria o total para US$ 213,49 por mês (+59%) e é o primeiro passo recomendado se o grupo quiser uma versão intermediária.
- **RDS Multi-AZ:** o ADR-003 descartou o RDS por custo e por exigir duas zonas. A segunda razão deixa de valer. O RDS custa US$ 64,24 por mês contra US$ 15,30 da instância EC2, mas dispensa operar a replicação e o failover.
- **Session Manager:** o ADR-001 o descartou porque exigia papel IAM nas instâncias e não substituía a demonstração de SSH da Entrega 2. Como a proposta não é implantada, a demonstração não se aplica, e o papel mínimo (`AmazonSSMManagedInstanceCore`) passa a ser um acréscimo aceito.
- Detalhes, fluxos e tabela de custo em `docs/alta-disponibilidade.md`.
