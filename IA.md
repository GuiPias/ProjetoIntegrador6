# Declaração de uso de IA

## Ferramentas utilizadas

- **Claude** (Anthropic), pelo site/aplicativo claude.ai. Nenhuma outra ferramenta de IA foi usada.

## Em quais partes do trabalho

| Parte | Como o Claude foi usado |
|---|---|
| Decisões de arquitetura | Conduziu uma conversa de perguntas e respostas; o grupo escolheu provedor (AWS), região (`sa-east-1`), aplicação (cadastro de produtos), linguagem (Java) e o desenho final (bastion, aplicação pública e banco privado) |
| `docs/arquitetura.md` (seções 5.1 a 5.7, 5.9 e 5.10) | Redigiu o texto, as tabelas de endereçamento, rotas, segurança, tecnologias e dimensionamento, e a lista de riscos |
| Custos (`docs/custos/`) | Pesquisou preços públicos da AWS em `sa-east-1`, montou as contas dos dois cenários e orientou, o preenchimento da AWS Pricing Calculator |
| `README.md` e `IA.md` | Auxiliou |

## O que o grupo verificou ou corrigiu

- **Estimativa de custos:** o grupo montou as duas estimativas na calculadora oficial da AWS por conta própria e comparou com as contas do Claude. O total do cenário A (US$ 134,14) bateu com o cálculo prévio. O preço do EBS, que o Claude tinha estimado a partir de fontes divergentes, foi confirmado pela calculadora.
- **Calculadora e NAT Gateway:** a calculadora somava dois NATs (padrão e regional) e chegava a US$ 283,45. O grupo ajustou os campos até o total refletir um único NAT, e o documento registra como isso foi modelado.
- **Dados fornecidos pelo grupo:** o IP público usado na regra SSH do bastion (`200.138.86.47/32`) e as 40 horas do cenário B são do grupo.

## Limitações conhecidas

Nada do projeto foi implantado nesta entrega, então nenhuma regra de rede, instância ou comando foi testado na AWS. As versões de software e os preços podem mudar e devem ser revalidados na Entrega 2.
