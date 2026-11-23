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
