# Segurança (Entrega 2, Parte B)

Este documento descreve os controles de segurança aplicados na infraestrutura criada por Terraform (`infra/`), as evidências coletadas, o tratamento dos achados das ferramentas de análise e a análise de ameaças.

As evidências citadas estão em `docs/evidencias/`. A infraestrutura foi criada em 16/11/2026 e testada em 17/11/2026, e depois destruída com `terraform destroy` (47 recursos). O que ainda não foi evidenciado está marcado como **pendente**.

## 1. Controles obrigatórios (S1 a S8)

| # | Controle | Como foi aplicado | Evidência |
|---|---|---|---|
| S1 | Endurecimento do SSH | Os três scripts de inicialização (`infra/scripts/*.sh.tftpl`) gravam `/etc/ssh/sshd_config.d/01-hardening.conf` com `PasswordAuthentication no`, `KbdInteractiveAuthentication no` e `PermitRootLogin no`, e reiniciam o serviço. O acesso é só por chave. | `ssh-bastion.png` (login por chave funcionando). **Pendente:** recusa de senha (`Permission denied (publickey)`), coletada na próxima subida (seção 6). |
| S2 | Saída restrita | Nenhum grupo tem a regra padrão de saída total. Bastion: SSH para a aplicação e para o banco. Aplicação: PostgreSQL (5432) só para o grupo do banco. Os três: HTTP/HTTPS (80/443) para atualização de pacotes e DNS (TCP/UDP 53) apenas para o resolvedor da VPC. Todas as regras têm descrição. | `terraform-plan-sem-mudancas.txt`, `security.tf` |
| S3 | HTTPS | A aplicação atende somente por HTTPS na porta 443, com certificado **autoassinado** gerado no primeiro boot (keystore PKCS12). Não existe conector HTTP: as portas 80 e 8080 estão fechadas no grupo de segurança. | `app-lista.png` (https com aviso de certificado), `portas-fechadas.png` (HTTP e 8080 com timeout). **Pendente:** `curl -vk` com a negociação TLS (seção 6). |
| S4 | Gestão de segredos | Senha do banco e senha do keystore são variáveis Terraform com `sensitive = true`, validadas (mínimo 12 caracteres), fornecidas por variáveis de ambiente `TF_VAR_...`. Nenhum segredo está no código nem no Git. Dentro da instância, o arquivo `/etc/produtos/produtos.env` tem permissão 640 (dono root, grupo `produtos`). Limitações na seção 4, ameaça 4. | `gitleaks.json` (nenhum vazamento em 8 commits), `variables.tf` |
| S5 | Menor privilégio | Nenhuma instância acessa serviços da AWS, então **nenhuma instância recebe papel IAM e nenhuma chave de acesso fica gravada nelas**. Sem papel, uma credencial roubada de dentro da instância não dá acesso a nada na conta. O único papel criado é o do serviço de backup (DLM), com a política gerenciada da AWS `AWSDataLifecycleManagerServiceRole`. | `backup.tf` |
| S6 | Criptografia em repouso | Os três discos raiz declaram `encrypted = true` no código. Os snapshots do backup são criados a partir de um volume criptografado e herdam a criptografia. Não há bucket nem banco gerenciado. | `ebs-imdsv2.png` (`Criptografado = True` nos 3 discos). A criptografia do snapshot será conferida na próxima subida (seção 6). |
| S7 | Análise automatizada | Checkov (IaC), Trivy (IaC) e Gitleaks (segredos no histórico). Resultados na seção 2. | `results_cli.txt`, `trivy.txt`, `gitleaks.json` |
| S8 | Proteção da conta | MFA virtual (aplicativo autenticador) habilitado na conta usada pelo grupo. | `mfa-aws.png` |

### Outros controles aplicados

- **SSH restrito:** o grupo do bastion aceita a porta 22 somente do CIDR informado em `ssh_allowed_cidr`. A variável rejeita `0.0.0.0/0`. A aplicação e o banco só aceitam SSH vindo do grupo do bastion. Teste: o SSH direto na aplicação deu timeout (`portas-fechadas.png`).
- **Banco isolado:** sem IP público, em sub-rede privada. Só a aplicação alcança a porta 5432, e o PostgreSQL só aceita o IP da aplicação, com `scram-sha-256`. O banco sai para a internet pelo NAT (`ssh-banco-nat.png` mostra o IP do NAT como origem).
- **IMDSv2 obrigatório** nas três instâncias (`http_tokens = required`), o que reduz o risco de roubo de credenciais por SSRF (`ebs-imdsv2.png`).
- **Aplicação sem privilégio:** roda como usuário `produtos`, sem login, com `NoNewPrivileges` e apenas a permissão para usar a porta 443.
- **Grupo de segurança padrão da VPC sem regras.**
- **Conta de execução do Terraform:** o usuário IAM `terraform` recebeu uma política em linha adicional, restrita a um único papel (`integrador-dlm-backup`), apenas para criar o papel do backup.

## 2. Análise automatizada (S7)

Executada em 17/11/2026 sobre `infra/`.

| Ferramenta | Alvo | Resultado |
|---|---|---|
| Checkov 3.4.5 | Terraform | 1ª execução: 98 aprovadas, 14 falhas. Após a correção do `ebs_optimized`: **101 aprovadas, 11 falhas** |
| Trivy | Terraform | 1 achado (**MEDIUM**): VPC sem Flow Logs |
| Gitleaks | Histórico do Git (8 commits) | **Nenhum vazamento** |

**Sobre a severidade.** A versão gratuita do Checkov não informa severidade e o Trivy informou só o achado de Flow Logs. As duas ferramentas têm cobertura diferente: o Checkov avalia os recursos `aws_vpc_security_group_*_rule` e o Trivy não apontou nada sobre eles, então o Trivy **não** foi tratado como prova de que o restante está limpo. Os 11 achados do Checkov foram tratados individualmente, mesmo sem severidade informada, e os de natureza potencialmente alta (SSH aberto e IP público) estão marcados.

## 3. Tratamento dos achados

| Achado | Severidade | Recurso | Decisão | Justificativa |
|---|---|---|---|---|
| CKV_AWS_135: EC2 sem otimização de EBS | Não informada | `aws_instance.bastion`, `.db`, `.app` | **Corrigido** | Sem custo. Adicionado `ebs_optimized = true` nas 3 instâncias. Checkov passou de 14 para 11 falhas. |
| CKV_AWS_24: SSH liberado para 0.0.0.0/0 | Potencialmente alta | `aws_vpc_security_group_ingress_rule.app_ssh`, `.db_ssh` | **Falso positivo** | As duas regras não têm CIDR: a origem é o grupo de segurança do bastion (`referenced_security_group_id`), como mostra o `terraform plan`. O único CIDR de SSH é o do bastion, que vem de variável e rejeita `0.0.0.0/0`. O Trivy também não apontou. |
| CKV_AWS_88: instância com IP público | Potencialmente alta | `aws_instance.bastion`, `.app` | **Aceito** | Por desenho: bastion e aplicação são os dois componentes expostos. O bastion só aceita SSH do CIDR do grupo; a aplicação só expõe a 443. O banco não tem IP público. |
| CKV_AWS_126: monitoramento detalhado desligado | Não informada | `bastion`, `db`, `app` | **Aceito** | Custa a mais por instância ao mês e o monitoramento básico (5 minutos) atende o escopo do trabalho. |
| CKV2_AWS_41: instância sem papel IAM | Não informada | `bastion`, `db`, `app` | **Aceito** | Nenhuma instância acessa serviços da AWS. Sem papel, não há credencial a roubar (controle S5). |
| CKV2_AWS_11 / AWS-0178: VPC sem Flow Logs | **Média** (Trivy) | `aws_vpc.main` | **Aceito** | Os logs gerariam custo de armazenamento e não há equipe para analisá-los. Limitação de detecção descrita na ameaça 3. Em produção, deve ser habilitado. |

### Riscos aceitos que as ferramentas não apontaram

| Item | Risco | Decisão | Justificativa |
|---|---|---|---|
| Entrada 443 aberta para 0.0.0.0/0 no grupo da aplicação | Exposição pública da aplicação | **Aceito** | É a função da aplicação (requisito R12). Mitigado por HTTPS, usuário sem privilégio e banco isolado. Sem WAF no escopo. |
| Saída 80/443 para 0.0.0.0/0 nos três grupos | Uma instância comprometida poderia enviar dados para fora | **Aceito** | Necessária para atualizar pacotes e baixar o JAR. O destino não pode ser reduzido a um CIDR fixo. A saída é restrita às portas 80, 443 e DNS (controle S2). |
| Certificado autoassinado | O navegador mostra aviso e o certificado não prova a identidade do servidor | **Aceito** | Permitido pelo enunciado. Um certificado válido exigiria domínio próprio. |

## 4. Análise de ameaças

| # | Ameaça | Ativo afetado | Controle aplicado | Risco residual |
|---|---|---|---|---|
| 1 | Força bruta ou uso de credenciais no SSH do bastion | Bastion | S1 (sem senha, sem root), SSH restrito por CIDR (R7), chave pública no Terraform | Roubo da chave privada de um integrante, que daria acesso ao bastion e, por ele, às outras instâncias |
| 2 | Exploração de falha na aplicação web exposta | Aplicação | Só a porta 443 está aberta, aplicação com usuário sem privilégio e `NoNewPrivileges`, IMDSv2 obrigatório | Superfície pública sem WAF; uma falha no código ou em dependência do Spring Boot continua explorável |
| 3 | Movimentação lateral e ausência de detecção | VPC e instâncias | Grupos de segurança por referência, saída restrita (S2), banco sem IP público | Sem Flow Logs nem alertas, um ataque em andamento não seria percebido |
| 4 | Vazamento da senha do banco | Banco e state do Terraform | S4: variáveis sensíveis por variável de ambiente, nada no Git (Gitleaks), arquivo de ambiente com permissão 640 | A senha é passada pelo `user_data` (legível a quem tem permissão de consultar a instância na AWS) e fica em texto no arquivo de state, que é local e fora do Git. Mitigação futura: serviço de segredos e state remoto criptografado |
| 5 | Comprometimento da aplicação levando ao banco | Banco | Banco só aceita o IP da aplicação, `scram-sha-256`, porta 5432 só do grupo da aplicação | Quem controla a aplicação usa as credenciais dela e acessa todos os dados do banco |
| 6 | Perda ou corrupção de dados (exclusão acidental, falha de disco) | Disco do banco | Snapshot diário criptografado pelo DLM (Parte D) | Política mínima: cópias na mesma região e zona, e só 2 gerações (ver `docs/backup.md`) |
| 7 | Adulteração do JAR baixado da internet | Aplicação | JAR publicado em uma Release do repositório do próprio grupo, baixado por HTTPS | Não há verificação de checksum nem assinatura; quem alterar a Release altera o que é instalado |
| 8 | Uso indevido da conta da AWS (chaves de acesso ou senha do console) | Conta AWS | S8: MFA no console; usuário `terraform` com permissões limitadas | As chaves de acesso do usuário `terraform` ficam no computador do integrante e não têm MFA |

## 5. Como reproduzir as verificações

```powershell
# Checkov (a partir da raiz do repositório)
python -m checkov.main -d infra --framework terraform --compact --quiet

# Trivy (usa as variáveis de ambiente TF_VAR_... e o terraform.tfvars local)
trivy config infra --tf-vars infra\terraform.tfvars

# Gitleaks (histórico do Git)
gitleaks git . -v
```

## 6. Evidências pendentes

Serão coletadas em uma subida curta da infraestrutura, antes da entrega, e este documento será atualizado:

- **S1:** `ssh -o PubkeyAuthentication=no -o PreferredAuthentications=password ubuntu@<IP_DO_BASTION>`, esperando `Permission denied (publickey)`.
- **S3:** `curl -vk https://<IP_DA_APLICACAO>`, mostrando a versão do TLS negociada.
- **S6:** `aws ec2 describe-snapshots --owner-ids self --query "Snapshots[].Encrypted"`, esperando `true`.
