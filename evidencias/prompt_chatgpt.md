# Prompt usado no ChatGPT (texto enviado pelo grupo)

Texto integral do prompt enviado ao ChatGPT para organizar a Entrega 1. A conversa compartilhada está em <https://chatgpt.com/share/6ac6b6d5-d03c-83e9-8cb3-1928b9067b78> (título "Modelagem de banco").

````text
Estou desenvolvendo a Entrega 1 de um projeto acadêmico da disciplina de Modelagem de Banco de Dados.

Quero que você me ajude a organizar, revisar e completar a Entrega 1 do projeto sem inventar informações que não foram definidas pelo grupo.

## 📌 Projeto

Nome do estabelecimento: Palazio del Chef

Segmento: Restaurante e bar

Porte: Médio

O estabelecimento possui um fluxo considerável de clientes e foi escolhido por apresentar uma estrutura operacional e de processos adequada para aplicação dos conceitos de modelagem de banco de dados.

## 👥 Integrantes

- Victor Anjos
- Thiago Rodrigues
- Ricardo Santos
- Raphael Luiz

## 🎯 Objetivo do projeto

Analisar os processos do Palazio del Chef e desenvolver uma modelagem de banco de dados capaz de organizar as principais informações relacionadas ao atendimento, pedidos, produtos, mesas, setores e atendentes.

## 🔍 Problema identificado

Foi identificado um problema relacionado ao controle dos funcionários responsáveis pelo atendimento, pois atualmente a equipe não é registrada por meio de credenciais.

Isso dificulta a identificação do responsável pelo registro dos pedidos e o controle das atividades realizadas no sistema.

## 💡 Solução proposta

Criar a entidade ATENDENTE no modelo de dados para identificar o funcionário responsável pelo registro dos pedidos.

A ideia é permitir que cada pedido seja associado ao respectivo atendente responsável.

IMPORTANTE:
O professor orientou alterar o nome "Funcionário" para "Atendente" e especificar a função de cada funcionário/atendente.

## 🗺️ Processos mapeados

Os principais processos identificados são:

- Atendimento ao cliente
- Registro do pedido
- Preparação do pedido
- Encaminhamento para cozinha/bar
- Pagamento
- Controle de estoque
- Cadastro e controle de atendentes

## ⚙️ Requisitos

### Requisito funcional

O sistema deve permitir que o atendente registre um pedido de forma eficiente.

### Requisitos não funcionais

- Somente funcionários devidamente autorizados devem visualizar informações restritas referentes ao bar ou à cozinha.
- O sistema deve possuir controle de acesso, garantindo segurança e confidencialidade das informações de acordo com os níveis de permissão.

## 📜 Regras de negócio

1. Todo pedido deve estar obrigatoriamente associado a um atendente responsável pelo seu registro.

2. Todo pedido deve estar vinculado a uma mesa.

3. Todos os produtos cadastrados devem possuir código de barras para facilitar o registro e o controle de estoque.

## 🗄️ Entidades atuais

Após as orientações do professor, o modelo deve considerar:

- Atendente
- Pedido
- Produto
- Mesa
- Setor
- Histórico_Produto

## 🔄 Alterações solicitadas pelo professor no diagrama

O professor pediu especificamente:

1. Funcionário → Atendente
2. Especificar a função de cada funcionário/atendente
3. Valor → Preço
4. Item_pedido → inexistente/remover
5. Cardinalidade do Atendente → (1,N)
6. Adicionar Histórico_Produto

Não altere essas orientações.

## 💰 Produto

O atributo relacionado ao valor do produto deve ser alterado para representar PREÇO.

Usar uma nomenclatura consistente, como:

`preco_produto`

Evitar utilizar "valor" quando a intenção for representar o preço do produto.

## ❌ Item_pedido

A entidade/tabela `Item_pedido` deve ser removida do modelo porque o professor determinou que ela é inexistente.

Não mantenha `Item_pedido` no DER ou na lista principal de entidades.

ATENÇÃO:
Ao remover `Item_pedido`, verifique cuidadosamente como o relacionamento entre Pedido e Produto ficará representado e onde será armazenada a quantidade de produtos de um pedido. Não invente uma solução sem indicar que essa questão precisa ser validada caso não esteja definida pelo professor.

## 📜 Histórico_Produto

Adicionar uma entidade `Historico_Produto` ao modelo.

Ela deverá representar o histórico relacionado às alterações de preço do produto.

Não invente atributos definitivos se eles ainda não tiverem sido aprovados pelo professor. Caso sugira atributos, deixe claro que são sugestões.

## 🔢 Cardinalidade do Atendente

O professor solicitou que o relacionamento do Atendente seja:

Atendente (1,N) → registra → Pedido (1,1)

Interpretar isso como:

- Um Atendente registra um ou vários pedidos.
- Cada Pedido está associado a um único Atendente.

## 🧩 Diagrama

O projeto possui um Diagrama Entidade-Relacionamento (DER), desenvolvido durante a disciplina.

O README deve possuir uma seção específica para o diagrama.

A imagem do diagrama ficará no GitHub em:

`docs/diagrama-der.png`

O README deve utilizar:

`./docs/diagrama-der.png`

para exibir a imagem.

## 📖 README

O README deve conter, nesta ordem:

1. Contextualização e Visão Geral
2. Integrantes
3. Análise e Modelagem
4. Requisitos e Regras
5. Dicionário de Dados
6. Diagrama Entidade-Relacionamento
7. Modelo Relacional
8. Normalização
9. Implementação do Banco de Dados
10. Consultas SQL
11. Estrutura do Projeto
12. Status do Projeto
13. Uso de Inteligência Artificial
14. Contexto Acadêmico
15. Equipe

## 🤖 Uso do ChatGPT

O professor pediu que o uso de Inteligência Artificial fosse informado.

No README deve existir uma seção explicando que o ChatGPT foi utilizado como ferramenta de apoio na:

- organização da documentação;
- estruturação do README;
- revisão do texto;
- melhoria da clareza das informações;
- padronização da documentação.

Deixar claro que as informações do estabelecimento, requisitos, regras de negócio, entidades, atributos e decisões de modelagem foram definidas e revisadas pelos integrantes do grupo.

## 📁 Estrutura do GitHub

A estrutura planejada é:

Palazio-del-Chef/
├── docs/
│   └── diagrama-der.png
├── sql/
│   ├── create_tables.sql
│   ├── insert_data.sql
│   └── consultas.sql
└── README.md

## 🛠️ Tecnologias e ferramentas

Até o momento, considerar:

- PostgreSQL
- SQL
- BRModelo
- Git
- GitHub

Não afirmar que alguma tecnologia já foi utilizada em uma etapa que ainda não foi realizada.

## 📌 Status

O README deve mostrar claramente o que já foi concluído e o que ainda está em desenvolvimento.

Exemplo:

- Contextualização — concluído
- Identificação do problema — concluído
- Requisitos — concluído
- Regras de negócio — concluído
- Dicionário de dados — em desenvolvimento
- DER — em desenvolvimento
- Modelo relacional — pendente
- Normalização — pendente
- Implementação SQL — pendente
- Consultas SQL — pendente
- Documentação final — pendente

## ⚠️ Regras para sua resposta

- Não invente informações sobre o Palazio del Chef.
- Não crie entidades que o professor não solicitou sem avisar.
- Preserve as alterações solicitadas pelo professor.
- Diferencie claramente o que já foi definido pelo grupo de sugestões.
- Não considere `Item_pedido` existente, pois o professor determinou sua remoção.
- Considere `Atendente (1,N)` conforme orientação do professor.
- Inclua `Historico_Produto`.
- Use "preço" em vez de "valor" para representar o preço do produto.
- Mantenha a documentação com linguagem acadêmica, mas simples e objetiva.
- Quando sugerir alterações no DER, explique exatamente o que deve ser apagado, renomeado, adicionado ou alterado.
- O objetivo é deixar a Entrega 1 organizada, coerente com as orientações do professor e pronta para apresentação/avaliação.
````


---

## Prompt 2 (versão curta enviada pelo grupo)

> **Atenção:** esta seção é um resumo do conteúdo do segundo prompt. O texto na íntegra deve ser colado aqui pelo grupo. A **resposta** do ChatGPT também ainda precisa ser registrada (o link da conversa não é legível por ferramentas externas).

Conteúdo: repete as orientações do professor para o DER — Funcionário → Atendente; especificar a função do atendente; Valor → Preço; **remover Item_pedido**; Atendente (1,N) — registra — Pedido (1,1); adicionar Histórico_Produto. Entidades listadas: Atendente, Pedido, Produto, Mesa, Setor, Histórico_Produto. Regra do prompt: "Não invente informações que não foram definidas pelo grupo ou pelo professor."
