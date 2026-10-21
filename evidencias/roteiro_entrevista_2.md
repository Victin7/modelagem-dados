# Roteiro da 2ª entrevista — Palazio del Chef

Objetivo: fechar as lacunas do README (`[PREENCHER]` e `[VALIDAR]`) e validar as decisões da Entrega 2. Levar impresso o diagrama lógico (`docs/modelo_logico.png`) e a lista de problemas P1 a P6.

**Como registrar:** anotar data, hora, nome e cargo do entrevistado; separar, em duas colunas, **o que foi respondido** e **o que foi observado**; pedir autorização para fotografar (sem clientes na imagem); anotar nome e telefone do responsável.

## A. Abertura e autorização
1. Qual o seu nome completo e cargo? Há quanto tempo trabalha aqui?
2. Podemos citar o nome do estabelecimento e do responsável no trabalho? Podemos fotografar o salão, o caixa e a tela do Garçom Web (sem clientes)?
3. Quem é o responsável pela empresa para constar no relatório e qual o melhor telefone para contato?
4. Qual o vínculo do grupo com o local (conhecido, cliente, familiar)? *(README: "como o grupo tem acesso")*

## B. Equipe (preencher "funcionários por setor")
5. Quantos funcionários há em cada função: garçom, caixa, cozinha, bar, gerência, limpeza?
6. Quantos trabalham por turno? Há turnos diferentes (manhã, tarde, noite)?
7. Quem pode cadastrar produto, mudar preço, fazer compra, ajustar estoque e fechar o caixa?
8. Cada funcionário tem login próprio no Garçom Web? Se não, como se sabe quem lançou o pedido? *(P1)*

## C. Atendimento, mesa e reserva
9. Como a mesa é identificada (número, QR, comanda)? Os bistrôs têm numeração própria?
10. Uma mesa pode ter dois pedidos abertos ao mesmo tempo? E o pedido pode mudar de mesa ou juntar mesas?
11. Como é feita a reserva (nome, telefone, data, quantidade de pessoas)? Há cancelamento ou no-show? Existe limite de reservas por horário?
12. Há consumação mínima, couvert ou outra cobrança além dos 10% de serviço?

## D. Pedido e preparo
13. Quais dados o garçom informa ao lançar um pedido? Há campo de observação (ex.: "sem cebola")?
14. O cliente pode pedir **o mesmo produto de novo** no mesmo pedido? Como aparece no Garçom Web: soma a quantidade ou cria nova linha? *(decide a questão do Item_pedido)*
15. Um item fica com status por **unidade** ou por **produto**? (ex.: 3 caipirinhas, 1 já pronta)
16. Quais são os status de um item (pendente, em preparo, pronto, entregue, cancelado)? Quem altera cada um?
17. Até quando um item pode ser cancelado e quem autoriza? O cancelamento registra motivo?
18. Como a cozinha e o bar sabem que há pedido novo (impressora, tela, aviso)? Quem registra que o prato ficou pronto?
19. Qual o tempo médio de preparo de prato, drink e bebida? *(para validar a massa de dados)*

## E. Pagamento e caixa
20. Pode dividir a conta em várias formas de pagamento e várias pessoas? Como é registrado?
21. Como é feito o pagamento em dinheiro e o troco? O valor entra no sistema?
22. A taxa de 10% pode ser retirada? Quem autoriza e isso fica registrado?
23. Como é o fechamento do caixa: quem faz, a que horas, o que é conferido, o que acontece quando não bate?
24. Há sangria, gorjeta separada ou desconto? Quem pode dar desconto?
25. A nota fiscal é só da maquininha? O sistema guarda o número?

## F. Produtos e preço
26. Como o produto é cadastrado (nome, categoria, código de barras, preço, setor)? Quem faz?
27. Quantos produtos existem hoje e quantos são insumos (não vão ao cardápio)?
28. Quando o preço muda, como se registra? Os pedidos antigos mantêm o preço da época?
29. O cardápio do almoço e da noite têm preços diferentes? Há promoção ou combo?
30. Que produtos têm controle de estoque por unidade (bebidas, sobremesas prontas) e quais não (pratos feitos na hora)? *(valida `in_controla_estoque`)*

## G. Estoque, validade e compras
31. Como se sabe que um produto está acabando? Existe estoque mínimo por produto?
32. Como é feita a baixa de insumos (carne, queijo, verduras): por receita, por pesagem, estimativa, ou não é feita?
33. Quem pode ajustar o estoque manualmente (perda, quebra, vencimento) e quem registra o motivo? O sistema grava quem fez o ajuste? *(decide `id_atendente` em `movimentacao_estoque`)*
34. A validade é conferida só uma vez por mês? Como a planilha é organizada (colunas)? Podemos ver um exemplo?
35. Quem decide o que comprar e quando? Há fornecedor fixo? Quantos fornecedores, de quais produtos?
36. Como a compra é registrada (pedido, nota fiscal, valor, data)? Quem recebe a mercadoria e confere? E se vier errada ou faltando?
37. A compra é paga à vista ou a prazo? Isso entra no sistema?

## H. Garçom Web e dados
38. O que o Garçom Web já faz (pedido, estoque, caixa, relatório) e o que **não** faz?
39. Quais relatórios a gerência usa hoje? Quais decisões gostaria de tomar com dados (horário de pico, produto mais vendido, margem, desempenho por garçom)? *(KPIs)*
40. Os dados antigos ficam guardados por quanto tempo? Quem acessa? *(LGPD, RNF)*
41. Se pudesse resolver **um** problema com o banco de dados, qual seria?

## I. Validação do que já levantamos (mostrar e confirmar)
42. Confirmar o volume: 150 a 300 pedidos em dia útil, 400 a 550 no sábado, cerca de 30 mesas e 25 bistrôs, horários de funcionamento.
43. Confirmar as regras principais: um pedido aberto por mesa; só gerência/sócio muda preço e faz compra; item não cancela depois de pronto; documento para bebida alcoólica (quem confere e se é registrado).
44. Mostrar o diagrama lógico e perguntar se falta alguma informação que o restaurante guarda.

## J. Observação no local (anotar separado das respostas)
- Onde fica o caixa, o ponto de lançamento do pedido e como o garçom usa o Garçom Web.
- Como o pedido chega à cozinha e ao bar.
- Como é a comanda, a planilha de validade e o local do estoque.
- Fotos (com autorização), horário de maior movimento.
