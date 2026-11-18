# Cadastro de Produtos na AWS (Entrega 2: implantação, segurança, alta disponibilidade e backup)

Projeto Integrador | Uniamérica Descomplica | Professor Gildomiro Bairros

## Grupo

| Integrante | Demonstração na apresentação |
|---|---|
| Luiz Guilherme Moura Pias | D1 e D2 |
| Daniel Spies Amaral | D3 e D4 |
| Joao Victor Godoy | D5 e D6 |
| Mohamad Jbahi | D7 e encerramento |

## Visão geral

Aplicação web de cadastro de produtos (Spring Boot, Java 21, PostgreSQL 16) na AWS, região `sa-east-1` (São Paulo). A infraestrutura é criada inteira com Terraform: VPC `10.20.0.0/16` com sub-rede pública `pub-a` (bastion e aplicação) e sub-rede privada `priv-a` (banco, sem IP público), saída para a internet pelo NAT Gateway, aplicação em HTTPS (porta 443, certificado autoassinado) e backup diário do disco do banco com o Amazon Data Lifecycle Manager (DLM).

Escopo da Entrega 2:

| Parte | Situação |
|---|---|
| A. Infraestrutura base (R1 a R12) | Implementada em Terraform (47 recursos) |
| B. Segurança (S1 a S8) | Implementada; evidências em `docs/seguranca.md` e `docs/evidencias/` |
| C. Alta disponibilidade | Somente proposta (diagrama, riscos e custo), sem implantação |
| D. Backup | Política GFS descrita no papel; política mínima (diária, retenção 2) configurada |

## Estrutura do repositório

| Caminho | Conteúdo |
|---|---|
| `infra/` | Código Terraform (VPC, grupos de segurança, instâncias, NAT, backup) e scripts de inicialização |
| `docs/arquitetura.md` | Arquitetura da Entrega 1 (endereçamento, rotas, tecnologias, dimensionamento) |
| `docs/seguranca.md` | Medidas S1 a S8, ferramentas de varredura e evidências |
| `docs/alta-disponibilidade.md` | Proposta da Parte C: 2 zonas, ALB, RDS Multi-AZ, riscos e custo |
| `docs/backup.md` | Estratégia de backup: GFS, RPO 24 h, RTO 4 h, custo e política mínima |
| `docs/adr/` | ADRs 001 a 005 |
| `docs/diagramas/` | `arquitetura` (implantada) e `arquitetura-ha` (proposta), em `.drawio` e `.png` |
| `docs/custos/` | Estimativas da AWS Pricing Calculator (cenários A e B, EBS, ALB e RDS) |
| `docs/evidencias/` | Saídas de comandos e capturas da implantação |
| `docs/errata.md` | Divergências entre a Entrega 1 e o que foi implantado |
| `IA.md` | Declaração de uso de IA |

## Pré-requisitos

- Terraform 1.9 ou superior (menor que 2.0) e AWS CLI configurados com credenciais de um usuário IAM com permissões para VPC, EC2, EBS, IAM e DLM.
- Cliente SSH (OpenSSH) e `git`.
- Um par de chaves SSH para acessar as instâncias.

## Como implantar (PowerShell)

```powershell
# 1. Clonar
git clone https://github.com/GuiPias/ProjetoIntegrador6.git
cd ProjetoIntegrador6\infra

# 2. Criar a chave SSH (sem senha só para o laboratório)
ssh-keygen -t ed25519 -f $env:USERPROFILE\.ssh\chave-grupo
Get-Content $env:USERPROFILE\.ssh\chave-grupo.pub

# 3. Descobrir o IP público atual (vai para ssh_allowed_cidr)
curl.exe -s https://ifconfig.me

# 4. Criar o terraform.tfvars a partir do exemplo e preencher
Copy-Item terraform.tfvars.example terraform.tfvars
notepad terraform.tfvars
```

No `terraform.tfvars`, preencha `grupo`, `ssh_allowed_cidr` (seu IP seguido de `/32`; `0.0.0.0/0` é recusado), `ssh_public_key` (conteúdo do `.pub`) e `jar_url`:

```
jar_url = "https://github.com/GuiPias/ProjetoIntegrador6/releases/download/v1/produtos.jar"
```

As senhas **não** vão em arquivo. Defina-as só na sessão atual do PowerShell (mínimo de 12 caracteres, apenas letras, números, `_`, `.` e `-`):

```powershell
$env:TF_VAR_db_password       = "<senha-do-banco>"
$env:TF_VAR_keystore_password = "<senha-do-certificado>"
```

Depois:

```powershell
terraform init
terraform fmt -check
terraform validate
terraform plan -out tfplan
terraform apply tfplan
terraform output
```

O `apply` leva alguns minutos; a aplicação ainda precisa de cerca de 2 a 3 minutos depois disso para baixar o JAR e subir.

## Como acessar

Atualize o `HostName` do bloco `Host bastion` em `~/.ssh/config` com o valor de `bastion_ip_publico` (os IPs elásticos mudam a cada `apply`). O arquivo deve conter:

```
Host bastion
  HostName <bastion_ip_publico>
  User ubuntu
  IdentityFile ~/.ssh/chave-grupo

Host banco
  HostName 10.20.10.10
  User ubuntu
  IdentityFile ~/.ssh/chave-grupo
  ProxyJump bastion
```

```powershell
ssh bastion                       # entra no bastion
ssh banco                         # entra no banco, passando pelo bastion
curl.exe -k https://<app_ip_publico>   # aplicação (certificado autoassinado, por isso -k)
```

No navegador, abra a `app_url` e aceite o aviso do certificado.

## Variáveis principais

| Variável | Padrão | Observação |
|---|---|---|
| `grupo` | obrigatória | Identificador usado nos nomes dos recursos |
| `ssh_allowed_cidr` | obrigatória | IP de origem do SSH no bastion; não aceita `0.0.0.0/0` |
| `ssh_public_key` | obrigatória | Chave pública para as instâncias |
| `jar_url` | `""` | URL do JAR da aplicação (Release `v1`) |
| `db_password`, `keystore_password` | obrigatórias | Sensíveis; vêm de `TF_VAR_*` |
| `region` / `availability_zone` | `sa-east-1` / `sa-east-1a` | |
| `bastion_instance_type`, `app_instance_type`, `db_instance_type` | `t3.micro`, `t3.small`, `t3.micro` | |
| `bastion_volume_gb`, `app_volume_gb`, `db_volume_gb` | 8, 10, 20 | Discos gp3 criptografados |
| `backup_hora_utc` | `"03:00"` | Horário do snapshot diário (UTC) |
| `backup_retencao` | 2 | Snapshots mantidos (1 a 2) |

## Custo e como desligar

Ligada o tempo todo, a infraestrutura custa cerca de **US$ 134,14 por mês** (cenário A); usada só durante o trabalho (cerca de 40 horas), cerca de **US$ 7,57** (cenário B). O maior custo é o NAT Gateway, que cobra por hora mesmo sem tráfego. **Destrua a infraestrutura ao terminar cada sessão.**

```powershell
terraform destroy
```

O `destroy` **não** apaga os snapshots criados pelo DLM. Depois dele, confira que nada ficou (NAT, IPs elásticos, volumes, snapshots) e apague os snapshots restantes:

```powershell
aws ec2 describe-snapshots --owner-ids self --query "Snapshots[].SnapshotId" --output text
aws ec2 delete-snapshot --snapshot-id <snap-id>
```

## Limitações conhecidas

- Zona única (`sa-east-1a`): uma falha da zona derruba tudo; a alternativa com 2 zonas está só proposta em `docs/alta-disponibilidade.md`.
- Certificado HTTPS autoassinado: o navegador exibe aviso.
- A aplicação não tem tela de login; HTTPS protege o tráfego, mas não restringe quem acessa.
- Snapshots do DLM são consistentes apenas em caso de falha (crash-consistent) e a política mínima mantém só 2 cópias.
- Os IPs elásticos mudam a cada `apply`; o `~/.ssh/config` e a regra de SSH devem ser atualizados.
- Divergências em relação à Entrega 1 estão em `docs/errata.md`.
