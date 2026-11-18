# ADR-001: Estratégia de acesso administrativo

**Status:** Aceita e implantada. Para a proposta de alta disponibilidade (não implantada), revista pelo ADR-004, que troca o bastion pelo Session Manager. A consequência prevista de que o IP do grupo poderia mudar ocorreu (ver `docs/errata.md`, item 3).

No contexto de uma aplicação cujo banco de dados fica em sub-rede privada e precisa ser administrado por SSH,
diante da regra de que o SSH nunca pode ser liberado para 0.0.0.0/0 e da exigência de demonstrar SSH na Entrega 2,
decidimos usar um bastion (instância EC2 t3.micro na sub-rede `pub-a`, com Elastic IP), cujo grupo `sg-bastion` aceita TCP 22 somente de `200.138.86.47/32`, enquanto `sg-app` e `sg-db` aceitam SSH somente de `sg-bastion`,
e descartamos IP público direto na aplicação e no banco com SSH liberado para o IP do grupo, e um serviço gerenciado de acesso (AWS Systems Manager Session Manager ou EC2 Instance Connect Endpoint),
para ter um único ponto de entrada administrativo, restrito a um IP, mantendo o banco sem IP público e sem nenhuma porta 22 aberta para a internet,
aceitando que o bastion é uma instância a mais, paga 24 horas por dia (decisão do grupo de mantê-lo ligado), que ele é um ponto único de falha do acesso administrativo, e que a regra por `/32` bloqueia o SSH de qualquer integrante em outra rede e deixa de funcionar se o IP público do grupo mudar, até que o `sg-bastion` seja atualizado.

**Contexto adicional.** O IP direto no banco foi descartado porque contradiz o requisito de componente não exposto. O Session Manager dispensaria o bastion e a porta 22, mas exigiria perfil IAM nas instâncias e não substitui a demonstração de SSH exigida na Entrega 2, por isso o grupo manteve o caminho tradicional por SSH.
