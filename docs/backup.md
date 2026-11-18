# Plano de backup (Entrega 2, Parte D)

Este documento define o plano de backup da aplicação de cadastro de produtos: o que precisa de cópia, as metas de recuperação, a política **conservadora (GFS)**, que fica só no plano, e a política **mínima**, que está configurada por Terraform (`infra/backup.tf`) e foi exercitada na nuvem.

**Alta disponibilidade não substitui backup.** A proposta de alta disponibilidade (`docs/altadisponibilidade.md`) mantém o serviço no ar quando um componente falha, mas uma réplica copia também o erro: uma tabela apagada por engano some nas duas. Só a cópia de um momento anterior permite voltar no tempo.

## B1. Inventário

| Ativo | Onde está | Precisa de backup? | Justificativa |
|---|---|---|---|
| Dados do PostgreSQL (produtos e quantidades) | Disco raiz (20 GB, criptografado) da instância `db` | **Sim** | É o único dado que não pode ser reconstruído pelo código. |
| Estado do Terraform (`terraform.tfstate`) | Arquivo local no computador de quem executa o `apply` | **Sim** | Sem ele o Terraform perde o vínculo com os recursos criados. Hoje existe uma só cópia, local. Em produção deve ir para um backend remoto, versionado e criptografado. |
| Código de infraestrutura e documentos | Repositório Git (GitHub) | Já tem cópia | O Git guarda o histórico e cada integrante tem um clone. |
| JAR da aplicação | Release `v1` do repositório | Já tem cópia | Reproduzível a partir do código (`mvnw`) e publicado na Release. |
| Discos do bastion e da aplicação | Discos raiz das instâncias | **Não** | Sem dados próprios. Recriados pelo Terraform e pelos scripts de inicialização. |
| `/etc/produtos/produtos.env` e certificado autoassinado | Instância da aplicação | **Não** | O arquivo é gerado dos valores das variáveis, e o certificado é gerado de novo a cada primeiro boot. |
| Senhas (banco e keystore) | Variáveis de ambiente de quem executa o Terraform | **Não pelo plano** | Não ficam no repositório. A guarda é do grupo (gerenciador de senhas). |
| Chave privada SSH | Computador de cada integrante | **Não pelo plano** | Se for perdida, gera-se um novo par e o Terraform troca a chave pública. |
| Arquivos enviados por usuários | Não existem | Não se aplica | A aplicação só grava nome e quantidade no banco. |

## B2. RPO e RTO

| Meta | Valor | Justificativa |
|---|---|---|
| **RPO** (quanto dado se aceita perder) | **24 horas** | Uso interno, até 10 usuários simultâneos, cadastro de nome e quantidade. Um dia de cadastros pode ser refeito a partir da contagem física do estoque. Um snapshot diário atende. |
| **RTO** (tempo para voltar) | **4 horas** | O sistema não é crítico fora do horário comercial. Voltar significa recriar a infraestrutura com o Terraform (cerca de 10 minutos), criar um volume a partir do snapshot e conferir a aplicação, dentro de um expediente. |

Se o uso mudasse (por exemplo, pedidos de clientes em tempo real), o RPO de 24 horas deixaria de servir e seria preciso arquivar o log de transações do PostgreSQL (WAL) para recuperar até o minuto.

## B3. Política conservadora (GFS)

Esquema Grandfather-Father-Son aplicado ao disco do banco. Os valores seguem o RPO de 24 horas: o Son diário garante essa meta, e as gerações Father e Grandfather cobrem erros descobertos tardiamente.

| Geração | Frequência | Promoção | Retenção | Classe de armazenamento | Permite restaurar |
|---|---|---|---|---|---|
| Son | Diária, 03:00 UTC (00:00 em Brasília) | Todo dia | 7 cópias | Standard | Qualquer dia da última semana |
| Father | Semanal, domingo 03:00 UTC | A cópia de domingo é a cópia Father | 5 cópias | Standard | Qualquer semana do último mês |
| Grandfather | Mensal, dia 1, 03:00 UTC | A cópia do dia 1 é a cópia Grandfather | 12 cópias | Standard | Qualquer mês do último ano |

**Como a promoção é implementada.** O Data Lifecycle Manager (DLM) aceita várias agendas na mesma política, cada uma com sua frequência e retenção. Em vez de "promover" uma cópia existente, cada agenda cria o seu próprio snapshot no mesmo horário. O resultado equivale à promoção: o snapshot de domingo vale como Father e o do dia 1 como Grandfather, e cada um expira pela retenção da própria agenda.

**Mecanismo por ativo.**

| Ativo | Mecanismo na política conservadora |
|---|---|
| Disco do banco | Snapshots do EBS pelo DLM (três agendas acima), criptografados. Em produção, somar um `pg_dump` semanal em bucket com versionamento, que é consistente do ponto de vista do banco (ver B6). |
| Estado do Terraform | Backend remoto em bucket versionado e criptografado, com regra de ciclo de vida para versões antigas. Não implementado nesta entrega. |

**Uma cópia em outra região (recomendação).** As gerações Father e Grandfather deveriam ser copiadas para outra região, para sobreviver à perda da região de origem. Essa cópia **não foi incluída nos custos de B7**, porque o preço de transferência entre regiões e o do armazenamento na região de destino não foram cotados. Seria um acréscimo ao valor da tabela.

**Classe Archive.** O snapshot em Archive custa menos por GB, mas tem duração mínima de cobrança de 90 dias e custo de recuperação. Como o preço dessa classe não foi cotado e o volume é pequeno, o plano usa só a classe Standard.

## B4. Armazenamento das cópias

- **Fora da instância:** os snapshots do EBS são guardados pela AWS fora do disco e sobrevivem à destruição da instância e do volume.
- **Zona e região:** o armazenamento do snapshot é regional, então a perda da zona `sa-east-1a` não apaga as cópias. A perda da região inteira apagaria, e é o que a cópia em outra região (B3) resolveria. A política mínima não tem essa cópia.
- **Criptografia (S6):** o volume de origem é criptografado (`encrypted = true`) e os snapshots herdam essa criptografia. A prova (`Encrypted: true` no snapshot) está **pendente** de coleta na próxima subida da infraestrutura (`docs/seguranca.md`, seção 6).
- **Acesso (S5):** nenhuma instância tem papel IAM nem pode apagar snapshots. O único papel é `integrador-dlm-backup`, com a política gerenciada `AWSDataLifecycleManagerServiceRole`, usado só pelo serviço DLM. Quem tem permissão de EC2 na conta pode apagar snapshots, e essa é uma fragilidade aceita: não há conta separada de backup nem proteção contra exclusão.

## B5. Responsabilidade compartilhada

| Ativo | O que a AWS garante | O que é responsabilidade do grupo |
|---|---|---|
| Snapshots do EBS | Durabilidade do armazenamento do snapshot e execução da agenda do DLM | Definir a política, a retenção e a criptografia; conferir se as cópias existem; saber restaurar |
| Disco do banco | Disponibilidade e replicação do volume dentro da zona | Consistência dos dados do PostgreSQL no momento da cópia; correção do conteúdo |
| Dados do PostgreSQL | Nada além do disco | Tudo: instalação, configuração, usuários e backup lógico |
| Estado do Terraform | Nada (é um arquivo local) | Guardar, copiar e proteger o arquivo, que contém as senhas em texto |
| Código e documentos | Nada pela AWS (estão no GitHub) | Manter os repositórios e os clones |
| Execução do backup | Disparar o snapshot no horário, de forma assíncrona | Verificar se rodou e se a expiração ocorreu como esperado |

## B6. Política mínima configurada

Aplica só a geração Son, com retenção curta, ao disco do banco. Arquivo: `infra/backup.tf`.

| Parâmetro | Valor configurado |
|---|---|
| Mecanismo | **Opção B**: snapshot agendado do disco, pelo DLM (`aws_dlm_lifecycle_policy`) |
| Alvo | Volumes com a tag `Backup=diario` (só o disco raiz do banco) |
| Frequência | A cada 24 horas, às 03:00 UTC (variável `backup_hora_utc`) |
| Retenção | **2 cópias** (variável `backup_retencao`, limitada entre 1 e 2) |
| Papel IAM | `integrador-dlm-backup`, com a política gerenciada `AWSDataLifecycleManagerServiceRole` |
| Criptografia | Herdada do disco de origem (S6). Prova **pendente** (B4). |
| Cópia existente | Snapshot criado automaticamente às 03:11 UTC de 17/11/2026. Evidências: `docs/evidencias/snapshot-dlm.png` e `snapshot-dlm.json`. |

**Por que o disco raiz.** O banco grava em `/var/lib/postgresql`, no mesmo disco raiz de 20 GB, porque a arquitetura da Entrega 1 usa um só disco por instância. Para a política mínima, capturar o disco inteiro preserva banco e configuração do sistema. Em produção o certo seria um disco de dados dedicado, com política e retenção próprias.

**Consistência.** Um snapshot tirado com o PostgreSQL em execução é consistente apenas como uma queda de energia (*crash-consistent*): ao subir de novo, o banco refaz o log de transações e provavelmente se recupera, mas transações em andamento no instante da cópia podem se perder. Em produção, as formas de reduzir esse risco seriam:

- executar `pg_dump` (consistente do ponto de vista do banco) antes do snapshot ou em paralelo a ele;
- usar `pg_backup_start`/`pg_backup_stop` em torno do snapshot, para a cópia ser um backup físico consistente;
- ou pausar as gravações por instantes e congelar o sistema de arquivos (`fsfreeze`) durante o snapshot.

**Expiração assíncrona.** O DLM executa a agenda e a retenção por conta própria, e a expiração pode não ocorrer no minuto exato. Por isso o número de cópias pode passar de 2 por algum tempo antes da limpeza.

**Atenção ao destruir o ambiente.** Os snapshots criados pelo DLM **não são removidos pelo `terraform destroy`**, porque o Terraform não os criou. Depois de cada `destroy`, listar e apagar manualmente:

```powershell
aws ec2 describe-snapshots --owner-ids self --query "Snapshots[].SnapshotId" --output text
aws ec2 delete-snapshot --snapshot-id <ID>
```

## B7. Custos

### Valores unitários e como foram obtidos

A calculadora oficial (`calculator.aws`, EBS, região América do Sul – São Paulo, 1 volume gp3 de 20 GB, snapshot diário, 1 GB alterado por snapshot) retornou **US$ 5,42 por mês** (US$ 65,04 em 12 meses). Com 30 GB, o resultado foi US$ 7,62 por mês. A estimativa exportada da calculadora está em `docs/custos/estimativa-ebs.pdf`.

A tela da calculadora não mostra o preço do snapshot por GB. Ele foi **derivado** dessas duas estimativas, com o gp3 de São Paulo a US$ 0,152 por GB-mês:

| Volume | Total | Disco gp3 | Snapshots (total menos disco) |
|---|---|---|---|
| 20 GB | US$ 5,42 | US$ 3,04 | US$ 2,38 |
| 30 GB | US$ 7,62 | US$ 4,56 | US$ 3,06 |

A razão entre os dois custos de snapshot (1,29) só fecha se a calculadora contar o snapshot como o tamanho do volume mais 15 GB de alterações (1 GB por dia, em média metade do mês). Com isso, o preço do snapshot Standard resulta em **cerca de US$ 0,068 por GB-mês**. É um valor calculado a partir da calculadora, e não lido numa tabela de preços; deve ser conferido na página de preços do EBS antes de uso real.

**Outros itens considerados:** o serviço DLM não tem cobrança própria (só os snapshots são cobrados); não há requisições ou transferência de dados cobradas dentro da região; não foi usada restauração rápida de snapshot. A cópia em outra região e a classe Archive **não** estão incluídas.

### Custo da política mínima no período do trabalho

Retenção de 2 cópias. Pela calculadora (que supõe o volume inteiro de 20 GB mais 15 GB de alterações), os snapshots custam no máximo **US$ 2,38 por mês**, cerca de **US$ 0,55 por semana**. Com a premissa mais realista da tabela abaixo (cerca de 12 GB retidos), o valor fica em torno de **US$ 0,19 por semana**. Em qualquer dos casos é **próximo de zero**, desde que os snapshots sejam apagados após o `destroy`.

### Custo anual da política conservadora (12 meses)

**Premissas**

| Premissa | Valor | Observação |
|---|---|---|
| Dados do banco no início | 10 GB | Sistema, PostgreSQL e dados. É uma premissa, não uma medição. O snapshot guarda só blocos usados. |
| Crescimento dos dados | 0,5 GB por mês | Cadastro de nome e quantidade. |
| Dados alterados únicos | 2 GB por mês | Dados que mudam e ficam presos nas cópias antigas. O mesmo bloco sobrescrito várias vezes conta uma vez. |
| Volume armazenado no mês | Dados do mês + 2 GB × meses de histórico retido (máximo 12) | O primeiro snapshot guarda todos os blocos usados, e os seguintes guardam só as diferenças. |
| Cópias retidas | 7 Son + até 5 Father + até 12 Grandfather | No mês 1 há 4 cópias Father e 1 Grandfather. Cópias de dias que coincidem foram contadas em separado, por prudência. |
| Preço | US$ 0,068 por GB-mês (Standard) | Derivado, como explicado acima. |

| Mês | Dados do banco (GB) | Cópias retidas (Son + Father + Grandfather) | Volume armazenado em backup (GB) | Custo mensal estimado (US$) |
|---|---|---|---|---|
| 1 | 10,0 | 12 | 12,0 | 0,82 |
| 2 | 10,5 | 14 | 14,5 | 0,99 |
| 3 | 11,0 | 15 | 17,0 | 1,16 |
| 4 | 11,5 | 16 | 19,5 | 1,33 |
| 5 | 12,0 | 17 | 22,0 | 1,50 |
| 6 | 12,5 | 18 | 24,5 | 1,67 |
| 7 | 13,0 | 19 | 27,0 | 1,84 |
| 8 | 13,5 | 20 | 29,5 | 2,01 |
| 9 | 14,0 | 21 | 32,0 | 2,18 |
| 10 | 14,5 | 22 | 34,5 | 2,35 |
| 11 | 15,0 | 23 | 37,0 | 2,52 |
| 12 | 15,5 | 24 | 39,5 | 2,69 |
| **Total no ano** | | | | **US$ 21,01** |

O custo cresce todo mês porque as cópias acumulam até a geração Grandfather completar 12 meses. A partir daí ele se estabiliza, e o segundo ano custaria cerca de US$ 2,70 por mês mais o crescimento dos dados.

### Parâmetro de maior impacto

O custo é mais sensível à **quantidade de dados que muda por mês** do que à retenção. Com a mesma tabela e **10 GB alterados por mês** (cinco vezes mais), o total anual sobe de US$ 21,01 para **US$ 63,44**, e o mês 12 chega a US$ 9,21. Já o **tamanho do volume** pouco influencia: os snapshots guardam os blocos usados, não os 20 GB provisionados. Dentro do plano, a retenção da geração Grandfather (12 meses) é o parâmetro que mais pesa, porque ela guarda o histórico de alterações de um ano inteiro (24 dos 39,5 GB do mês 12).

## O que a política mínima não protege

Comparada com a política conservadora:

- **Erro descoberto depois de 2 dias:** com 2 cópias e frequência diária, uma tabela apagada e só notada no terceiro dia não pode mais ser recuperada. A conservadora volta até 7 dias (Son), 5 semanas (Father) e 12 meses (Grandfather).
- **Sem histórico semanal ou mensal:** não há Father nem Grandfather.
- **Sem cópia em outra região:** a perda da região inteira apagaria os snapshots.
- **Perda de até 24 horas de dados** (RPO), e de transações em andamento no instante do snapshot, por ser *crash-consistent*.
- **Sem backup lógico** (`pg_dump`): não há uma cópia independente do formato do disco, e portanto nenhuma proteção contra corrupção silenciosa que já esteja no disco no momento do snapshot.
- **Sem proteção contra exclusão:** quem tem permissão de EC2 na conta apaga todos os snapshots. Não há conta separada de backup nem bloqueio.
- **Estado do Terraform sem cópia:** se o computador de quem fez o `apply` for perdido, o estado se perde junto.
- **Sem teste de restauração:** a entrega não exige, e a restauração a partir do snapshot não foi exercitada.
