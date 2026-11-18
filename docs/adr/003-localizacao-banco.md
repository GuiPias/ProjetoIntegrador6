# ADR-003: Localização do banco de dados

**Status:** Aceita e implantada. A consequência de ficar sem backup foi tratada pelo ADR-005, que complementa esta decisão. Para a proposta de alta disponibilidade (não implantada), revista pelo ADR-004, que usa RDS Multi-AZ.

No contexto de uma aplicação que persiste produtos (nome e quantidade em estoque) em um banco PostgreSQL,
diante da necessidade de um banco inacessível pela internet, de baixo custo (pago pelo grupo) e que possa ser recriado por script,
decidimos instalar o PostgreSQL 16 em uma instância EC2 t3.micro na sub-rede privada `priv-a`, acessível apenas pela `sg-app` na porta 5432,
e descartamos o Amazon RDS para PostgreSQL e o Amazon Aurora,
para ter menor custo, controle total da instalação por cloud-init e nenhuma obrigação de criar sub-redes em uma segunda zona (o RDS exige um grupo de sub-redes que cubra ao menos duas zonas de disponibilidade),
aceitando que o grupo assume sozinho os backups, as atualizações de versão e a recuperação do banco, sem failover automático, e que, se a instância for destruída ao recriar o ambiente sem um snapshot do disco, os dados cadastrados são perdidos.

**Contexto adicional.** Esta decisão será revista na Entrega 2, quando o plano de backup definirá como proteger os dados (por exemplo, snapshots do volume EBS).
