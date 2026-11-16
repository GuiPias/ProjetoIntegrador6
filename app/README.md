# Cadastro de Produtos

Aplicação web simples (Java 21 + Spring Boot 3.5) para listar, criar, editar e excluir produtos
(nome e quantidade em estoque). As páginas são renderizadas no servidor com Thymeleaf e servidas
pelo Tomcat embutido. Em produção usa PostgreSQL 16 e atende **somente HTTPS**.

Pré-requisito: **JDK 21** instalado (`java -version` deve mostrar 21). O Maven não precisa ser
instalado: use o Maven Wrapper (`mvnw` / `mvnw.cmd`) incluído nesta pasta.

Todos os comandos abaixo são executados dentro da pasta `app/`.

## Rodar localmente (perfil `local`)

O perfil `local` usa H2 em memória (sem PostgreSQL), HTTP na porta 8080 e sem SSL.
Os dados são perdidos ao parar a aplicação; 3 produtos de exemplo são inseridos a cada início.

Windows (PowerShell):

```powershell
.\mvnw.cmd spring-boot:run "-Dspring-boot.run.profiles=local"
```

Linux:

```bash
./mvnw spring-boot:run -Dspring-boot.run.profiles=local
```

Abra <http://localhost:8080>. Health check: <http://localhost:8080/actuator/health>.

## Gerar o JAR

Windows (PowerShell):

```powershell
.\mvnw.cmd clean package
```

Linux:

```bash
./mvnw clean package
```

O resultado é um único JAR executável em `target/produtos.jar`.

Para rodar o JAR com o perfil local: `java -jar target/produtos.jar --spring.profiles.active=local`.

## Gerar um keystore autoassinado (HTTPS)

Em produção a aplicação precisa de um keystore PKCS12 com o certificado TLS. Para testes, gere um
autoassinado (RSA 2048, validade de 365 dias). O `keytool` vem junto com o JDK.

Windows (PowerShell):

```powershell
keytool -genkeypair -alias produtos -keyalg RSA -keysize 2048 -validity 365 `
  -storetype PKCS12 -keystore keystore.p12 -dname "CN=localhost"
```

Linux:

```bash
keytool -genkeypair -alias produtos -keyalg RSA -keysize 2048 -validity 365 \
  -storetype PKCS12 -keystore keystore.p12 -dname "CN=localhost"
```

O comando pede a senha do keystore; ela será o valor de `SSL_KEYSTORE_PASSWORD`.

> **O keystore nunca vai para o Git.** Ele contém a chave privada do certificado. O `.gitignore`
> da raiz ignora `*.p12` e `*.jks`. Gere o keystore direto no servidor (ou copie por um canal
> seguro) e guarde a senha fora do repositório.

Como o certificado é autoassinado, navegadores mostram um aviso e o `curl` precisa de `-k`.

## Variáveis de ambiente (perfil padrão / produção)

| Variável                | Uso                          | Padrão     |
|-------------------------|------------------------------|------------|
| `DB_HOST`               | host do PostgreSQL           | sem padrão |
| `DB_PORT`               | porta do PostgreSQL          | `5432`     |
| `DB_NAME`               | nome do banco                | `produtos` |
| `DB_USER`               | usuário do banco             | sem padrão |
| `DB_PASSWORD`           | senha do banco               | sem padrão |
| `SERVER_PORT`           | porta HTTPS da aplicação     | `8443`     |
| `SSL_KEYSTORE_PATH`     | caminho do keystore PKCS12   | sem padrão |
| `SSL_KEYSTORE_PASSWORD` | senha do keystore            | sem padrão |

Sem as variáveis "sem padrão", a aplicação não sobe. A tabela `produtos` é criada automaticamente
(`ddl-auto=update`). O único endpoint do Actuator exposto é `/actuator/health`. Os logs vão para a
saída padrão (no servidor, ficam no journal do systemd).

## Instalar em uma instância Ubuntu 24.04

Os arquivos de exemplo estão em [`deploy/`](deploy/): `produtos.service` (unidade systemd) e
`produtos.env.example` (modelo das variáveis, sem segredos).

1. Instalar o Java 21 (somente o runtime):

   ```bash
   sudo apt update
   sudo apt install -y openjdk-21-jre-headless
   ```

2. Criar o usuário de sistema `produtos` (sem login):

   ```bash
   sudo useradd --system --no-create-home --shell /usr/sbin/nologin produtos
   ```

3. Copiar o JAR para `/opt/produtos/` (a partir do seu computador, por exemplo com `scp`, e depois
   no servidor):

   ```bash
   scp -i chave.pem target/produtos.jar deploy/produtos.service deploy/produtos.env.example ubuntu@IP_DA_INSTANCIA:~
   ```

   ```bash
   sudo mkdir -p /opt/produtos
   sudo cp ~/produtos.jar /opt/produtos/produtos.jar
   sudo chown -R produtos:produtos /opt/produtos
   ```

4. Criar `/etc/produtos/produtos.env` com permissão restrita e preencher os valores reais
   (troque todos os `TROCAR_...`):

   ```bash
   sudo mkdir -p /etc/produtos
   sudo cp ~/produtos.env.example /etc/produtos/produtos.env
   sudo nano /etc/produtos/produtos.env
   sudo chown produtos:produtos /etc/produtos/produtos.env
   sudo chmod 600 /etc/produtos/produtos.env
   ```

5. Gerar o keystore no servidor (comando `keytool` acima) em `/etc/produtos/keystore.p12` e
   restringir o acesso:

   ```bash
   sudo keytool -genkeypair -alias produtos -keyalg RSA -keysize 2048 -validity 365 \
     -storetype PKCS12 -keystore /etc/produtos/keystore.p12 -dname "CN=localhost"
   sudo chown produtos:produtos /etc/produtos/keystore.p12
   sudo chmod 600 /etc/produtos/keystore.p12
   ```

6. Instalar e habilitar o serviço systemd:

   ```bash
   sudo cp ~/produtos.service /etc/systemd/system/produtos.service
   sudo systemctl daemon-reload
   sudo systemctl enable --now produtos
   ```

   A unidade usa `AmbientCapabilities=CAP_NET_BIND_SERVICE`, o que permite usar a porta 443
   (`SERVER_PORT=443`) sem rodar como root.

7. Verificar:

   ```bash
   sudo systemctl status produtos
   curl -k https://localhost/actuator/health
   ```

   A resposta esperada é `{"status":"UP"}`. Logs: `sudo journalctl -u produtos -f`.

Para atualizar a aplicação: copie o novo JAR para `/opt/produtos/produtos.jar` e rode
`sudo systemctl restart produtos`.
