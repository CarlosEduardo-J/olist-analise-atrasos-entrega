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
