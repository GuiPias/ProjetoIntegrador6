# ADR-002: Saída para a internet da sub-rede privada

**Status:** Aceita e implantada. Para a proposta de alta disponibilidade (não implantada), revista pelo ADR-004, que usa um NAT Gateway por zona.

No contexto de um banco PostgreSQL em sub-rede privada que precisa baixar e atualizar pacotes,
diante da exigência de que ele não tenha IP público e de que o NAT gerenciado seja obrigatório na Entrega 2,
decidimos usar um NAT Gateway gerenciado na sub-rede `pub-a`, com Elastic IP, e a rota `0.0.0.0/0 → NAT Gateway` na tabela `rt-priv`,
e descartamos um NAT em instância EC2 (com a verificação de origem e destino desativada) e a ausência de saída para a internet,
para dar acesso de saída ao banco sem expô-lo e sem que o grupo precise administrar, atualizar e recuperar um servidor de NAT,
aceitando que o NAT Gateway é cobrado por hora e por GB processado, mesmo com tráfego mínimo, e que provavelmente será o item mais caro da arquitetura em `sa-east-1` (a confirmar na calculadora), e que existe um único NAT em uma única zona de disponibilidade, ponto único de falha da saída do banco.

**Contexto adicional.** O NAT em instância seria mais barato (uma t3.nano), mas traria manutenção manual, limite de banda da instância e outro ponto de falha. Sem saída para a internet o custo seria zero, porém o banco não instalaria nem atualizaria pacotes, a menos que se usasse uma imagem pré-pronta, o que contraria a instalação automatizada por cloud-init e a exigência do enunciado.
