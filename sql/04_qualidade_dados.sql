-- =============================================================================
-- 04_qualidade_dados.sql
-- Depois de confirmar que a carga está correta (03), procuro problemas nos
-- dados que possam distorcer a análise. Cada bloco responde a uma pergunta,
-- com o que encontrei e o que isso significa para o projeto.
-- =============================================================================

USE olist;


-- -----------------------------------------------------------------------------
-- 1) review_id se repete em order_reviews?
-- Motivo da pergunta: na criação da tabela usei uma chave artificial (id)
-- porque desconfiei que review_id não fosse único.
--
-- 1.1) Panorama: total de linhas vs. review_id distintos.
-- Resultado: 99.224 linhas e 98.410 review_id distintos, ou seja, 814 linhas a
-- mais por causa de repetição.
-- -----------------------------------------------------------------------------
SELECT
    COUNT(*) AS qtd_registros,
    COUNT(DISTINCT review_id) AS review_id_distintos
FROM order_reviews;


-- 1.2) Quais review_id se repetem e se é no mesmo pedido ou em pedidos
-- diferentes. Olhei só os 10 mais repetidos (LIMIT 10).
-- Resultado: nesses 10 casos, cada review_id aparece em 3 registros e em 3
-- pedidos diferentes (pedidos_distintos = 3). Ou seja, o mesmo review_id está
-- ligado a pedidos distintos, e não repetido dentro de um pedido.
-- Conclusão: review_id não identifica uma avaliação sozinho, então a chave
-- artificial id se justifica. A causa eu não consigo confirmar pelos dados.
-- -----------------------------------------------------------------------------
SELECT
    review_id,
    COUNT(*) AS qtd_registros,
    COUNT(DISTINCT order_id) AS pedidos_distintos
FROM order_reviews
GROUP BY review_id
HAVING COUNT(*) > 1
ORDER BY qtd_registros DESC
LIMIT 10;


-- -----------------------------------------------------------------------------
-- 2) Quantas avaliações cada pedido tem?
-- Motivo da pergunta: se um pedido tiver mais de uma avaliação, ao juntar
-- orders com order_reviews a linha do pedido aparece repetida e distorce
-- contagens, receita e médias de nota.
--
-- 2.1) Distribuição de pedidos por quantidade de avaliações.
-- Resultado: 98.126 pedidos têm 1 avaliação, 543 têm 2 e 4 têm 3. A conta
-- fecha com a tabela (98.126 + 543x2 + 4x3 = 99.224 linhas).
-- Conclusão: 547 pedidos (cerca de 0,55% dos que têm avaliação) têm mais de uma
-- avaliação. É pouco, mas vou precisar de uma regra para ficar com uma
-- avaliação por pedido nas views.
-- -----------------------------------------------------------------------------
WITH avaliacoes_por_pedido AS (
    SELECT
        order_id,
        COUNT(review_score) AS avaliacoes
    FROM order_reviews
    GROUP BY order_id
)
SELECT
    avaliacoes,
    COUNT(*) AS qtd_pedido
FROM avaliacoes_por_pedido
GROUP BY avaliacoes
ORDER BY avaliacoes ASC;


-- 2.2) Pedidos sem nenhuma avaliação.
-- LEFT JOIN a partir de orders mantém todos os pedidos. Nos que não têm
-- avaliação, as colunas de order_reviews vêm NULL, e é isso que filtro.
-- Resultado: 768 pedidos sem avaliação. Bate com a conta de 99.441 pedidos
-- menos 98.673 com avaliação, o que também mostra que todo order_id de
-- order_reviews existe em orders (nenhuma avaliação órfã).
-- Conclusão: nas views de métricas preciso usar LEFT JOIN com as avaliações,
-- senão esses pedidos somem da análise.
-- -----------------------------------------------------------------------------
SELECT
    COUNT(*) AS qtd
FROM orders o
LEFT JOIN order_reviews od
    ON o.order_id = od.order_id
WHERE od.review_score IS NULL;


-- -----------------------------------------------------------------------------
-- 3) Cliente real: customer_id ou customer_unique_id?
-- Motivo da pergunta: customer_id parece ser gerado por pedido, então a mesma
-- pessoa pode ter vários. Se for assim, contar customer_id conta pedidos e não
-- clientes.
--
-- 3.1) Total de customer_id vs. pessoas distintas (customer_unique_id).
-- Resultado: 99.441 customer_id e 96.096 customer_unique_id distintos. São
-- 3.345 linhas a mais por causa de pessoas que aparecem mais de uma vez.
-- Conclusão: contar customer_id superconta clientes em cerca de 3,4%. Para
-- análises sobre pessoas vou usar customer_unique_id.
-- -----------------------------------------------------------------------------
SELECT
    COUNT(*) AS qtd_ids,
    COUNT(DISTINCT customer_unique_id) AS qtd_clientes
FROM customers;


-- 3.2) Quantos customer_id cada pessoa tem.
-- Primeiro conto os customer_id de cada customer_unique_id (a CTE) e depois
-- agrupo por essa contagem para ver quantas pessoas há em cada grupo.
-- Resultado: 93.099 pessoas têm 1 customer_id, 2.745 têm 2, 203 têm 3, 30 têm 4,
-- 8 têm 5, 6 têm 6, 3 têm 7, 1 tem 9 e 1 tem 17. As contas fecham: 96.096
-- pessoas e 99.441 customer_id.
-- Conclusão: cerca de 3% das pessoas (2.997) têm mais de um customer_id. Se
-- cada customer_id corresponder a um pedido (ainda não conferi), é uma taxa de
-- recompra baixa. Vale lembrar disso mais adiante.
-- -----------------------------------------------------------------------------
WITH ids_por_cliente AS (
    SELECT
        customer_unique_id,
        COUNT(*) AS qtd_ids
    FROM customers
    GROUP BY customer_unique_id
)
SELECT
    qtd_ids,
    COUNT(customer_unique_id) AS qtd_clientes
FROM ids_por_cliente
GROUP BY qtd_ids
ORDER BY qtd_ids DESC;


-- -----------------------------------------------------------------------------
-- 4) Registros órfãos
-- Como não criei FOREIGN KEY, nada no banco impede um registro de apontar para
-- algo que não existe na outra tabela. Aqui confiro cada relação.
-- Padrão usado: LEFT JOIN a partir da tabela que pode ter registros sem
-- correspondente e filtro com IS NULL na chave da tabela da direita. Quando não
-- há correspondência, as colunas do lado direito vêm NULL, então o COUNT(*)
-- conta justamente os órfãos.
-- Esperado: 0 em todas as relações.
--
-- 4.1) Pedidos sem cliente (orders -> customers).
-- Resultado: 0.
-- -----------------------------------------------------------------------------
SELECT
    COUNT(*) AS pedidos_orfaos
FROM orders o
LEFT JOIN customers c
    ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL;


-- 4.2) Itens sem pedido (order_items -> orders).
-- Resultado: 0.
-- -----------------------------------------------------------------------------
SELECT
    COUNT(*) AS itens_sem_pedido
FROM order_items oi
LEFT JOIN orders o
    ON oi.order_id = o.order_id
WHERE o.order_id IS NULL;


-- 4.3) Itens sem produto (order_items -> products).
-- Resultado: 0.
-- -----------------------------------------------------------------------------
SELECT
    COUNT(*) AS itens_sem_produto
FROM order_items oi
LEFT JOIN products p
    ON oi.product_id = p.product_id
WHERE p.product_id IS NULL;


-- 4.4) Itens sem vendedor (order_items -> sellers).
-- Resultado: 0.
-- -----------------------------------------------------------------------------
SELECT
    COUNT(*) AS itens_sem_vendedor
FROM order_items oi
LEFT JOIN sellers s
    ON oi.seller_id = s.seller_id
WHERE s.seller_id IS NULL;


-- 4.5) Pagamentos sem pedido (order_payments -> orders).
-- Resultado: 0.
-- -----------------------------------------------------------------------------
SELECT
    COUNT(*) AS pagamentos_sem_pedido
FROM order_payments op
LEFT JOIN orders o
    ON op.order_id = o.order_id
WHERE o.order_id IS NULL;


-- 4.6) Avaliações sem pedido (order_reviews -> orders).
-- Já tinha deduzido que dava 0 pela conta dos 768 pedidos sem avaliação (2.2),
-- mas conferi com uma consulta direta.
-- Resultado: 0.
-- -----------------------------------------------------------------------------
SELECT
    COUNT(*) AS avaliacoes_sem_pedido
FROM order_reviews orv
LEFT JOIN orders o
    ON orv.order_id = o.order_id
WHERE o.order_id IS NULL;


-- Conclusão: nenhuma das 6 relações tem registros órfãos.
--
-- 4.7) Categorias de products sem tradução em product_category_translation.
-- Aqui não é uma relação de chave: quero saber se alguma categoria ficaria sem
-- nome em inglês na análise por categoria. Deixei de fora os produtos sem
-- categoria (NULL), porque nesse caso falta a própria categoria e não a
-- tradução.
-- Resultado: 2 categorias sem tradução: pc_gamer (3 produtos) e
-- portateis_cozinha_e_preparadores_de_alimentos (10 produtos), 13 no total.
-- Sem o filtro de NULL, o LEFT JOIN trazia 623 produtos, então os outros 610
-- são produtos sem categoria.
-- Conclusão: na análise por categoria vou precisar tratar esses 13 produtos
-- (sem tradução) e os 610 (sem categoria), senão somem de um JOIN comum ou
-- aparecem sem nome.
-- -----------------------------------------------------------------------------
SELECT
    p.product_category_name,
    COUNT(*) AS qtd_produtos
FROM products p
LEFT JOIN product_category_translation pt
    ON p.product_category_name = pt.product_category_name
WHERE pt.product_category_name IS NULL
  AND p.product_category_name IS NOT NULL
GROUP BY p.product_category_name;