# Diário de decisões

Registro das decisões que tomei ao longo do projeto, com o motivo de cada uma.
Itens marcados com **A confirmar** dependem de uma checagem que ainda não fiz.

---

## Modelagem do banco (`sql/01_criar_banco_e_tabelas.sql`)

### 001 - CEP como `CHAR(5)`
- **Decisão:** guardar o CEP como texto de 5 caracteres.
- **Motivo:** como número, o CEP `01037` viraria `1037` e o cruzamento entre clientes, vendedores e geolocalização falharia.
- **Alternativa descartada:** `INT`.
- **Verificado:** nas 3 tabelas com CEP (`customers`, `sellers` e `geolocation`) todos os valores têm 5 caracteres e vários começam com `0`, então o zero à esquerda foi preservado (ver `03_verificacao_carga.sql`, bloco 3).

### 002 - Sem `FOREIGN KEY` na criação das tabelas
- **Decisão:** criar apenas índices nas colunas usadas em JOIN.
- **Motivo:** prefiro carregar tudo primeiro e checar registros órfãos na etapa de qualidade, em vez de a carga travar por causa de uma FK.
- **Verificado:** conferi 6 relações (`orders`→`customers`; `order_items`→`orders`, `products` e `sellers`; `order_payments`→`orders`; `order_reviews`→`orders`) com `LEFT JOIN` e `IS NULL`, e não há registros órfãos em nenhuma delas (ver `04_qualidade_dados.sql`, bloco 4). Com isso, a carga teria funcionado mesmo com FKs.
- **A decidir:** se adiciono as FKs agora, com `ALTER TABLE`, ou deixo só os índices.

### 003 - Correção de "lenght" para "length"
- **Decisão:** renomear `product_name_lenght` e `product_description_lenght` para `product_name_length` e `product_description_length`.
- **Motivo:** o nome vem com erro de digitação na fonte. Corrigi para evitar o erro se propagar para as consultas e para o dashboard.
- **Impacto:** o nome das colunas no banco difere do CSV. A ordem delas é a mesma, então a carga não é afetada.

### 004 - Chave artificial em `order_reviews`
- **Decisão:** usar uma coluna `id` com `AUTO_INCREMENT` como chave primária, em vez de `review_id`.
- **Motivo:** desconfiei que `review_id` não fosse único, e um pedido pode ter mais de uma avaliação.
- **Verificado:** a tabela tem 99.224 linhas e 98.410 `review_id` distintos, ou seja, 814 linhas a mais por causa de repetição. Nos casos que olhei (os 10 mais repetidos), o mesmo `review_id` aparece em 3 pedidos diferentes. Então `review_id` não identifica uma avaliação sozinho e a chave artificial se justifica (ver `04_qualidade_dados.sql`).
- **Avaliações por pedido:** 98.126 pedidos têm 1 avaliação, 543 têm 2 e 4 têm 3, ou seja, 547 pedidos com mais de uma. Ao juntar `orders` com `order_reviews`, esses pedidos apareceriam em mais de uma linha e inflariam contagens e médias. Ainda preciso definir como tratar isso nas views.
- **Pedidos sem avaliação:** 768. Nas views de métricas preciso usar `LEFT JOIN`, senão eles somem da análise sem aviso.
- **A confirmar:** por que `review_id` se repete. Os dados não explicam a causa.

### 005 - Cliente real é `customer_unique_id`, não `customer_id`
- **Decisão:** nas análises de clientes, usar `customer_unique_id`.
- **Motivo:** `customer_id` é gerado por pedido, então a mesma pessoa pode ter vários.
- **Verificado:** `customers` tem 99.441 `customer_id` e 96.096 `customer_unique_id` distintos, então contar `customer_id` superconta clientes em cerca de 3,4%. Ao agrupar por pessoa, 93.099 têm só 1 `customer_id`, 2.745 têm 2 e as demais têm de 3 a 17, somando 2.997 pessoas com mais de um (cerca de 3%). Os números fecham com os totais da tabela (ver `04_qualidade_dados.sql`, bloco 3).
- **A confirmar:** se cada `customer_id` corresponde a exatamente um pedido. A contagem de 99.441 é igual à de `orders`, o que sugere isso, mas ainda não conferi o vínculo. Se for verdade, as pessoas com mais de um `customer_id` são as que voltaram a comprar.

---

## Carga dos dados (`sql/02_carga_dados.sql`)

### 006 - `LOAD DATA LOCAL INFILE` em vez do Import Wizard
- **Decisão:** carregar os CSVs por script SQL.
- **Motivo:** o script fica versionado no repositório e qualquer pessoa consegue repetir a carga. O wizard é clique em interface e não deixa registro. Também é bem mais rápido para a tabela `geolocation`, que tem cerca de 1 milhão de linhas.
- **Alternativa descartada:** Import Wizard.

### 007 - Campos vazios convertidos em `NULL`
- **Decisão:** ler as colunas que podem vir vazias numa variável e converter com `NULLIF(@var, '')`.
- **Motivo:** o MySQL lê campo vazio como texto vazio, o que dá erro em colunas de data e número. É o caso de datas de entrega em pedidos cancelados e de medidas de produtos.

### 008 - Caminho dos CSVs sem acento
- **Problema:** o `LOAD DATA` não encontrava o arquivo (erro 2) porque o caminho passava por `Usuário`.
- **Decisão:** copiar os CSVs para uma pasta sem acento só para a carga local. Os arquivos em `data/raw/` continuam onde estão.
- **No repositório:** o script usa o placeholder `C:/CAMINHO/PROJETO` e o README avisa que o caminho deve ser ajustado.

### 009 - Terminador de linha `\r\n` em `order_reviews`
- **Problema:** a primeira carga de `order_reviews` terminou com avisos 4096 (`Delimiter '\r' in position 19 in datetime value`).
- **Causa:** esse CSV termina as linhas com `\r\n`, e os demais com `\n`. Com `\n`, o `\r` ficava grudado na última coluna (`review_answer_timestamp`).
- **Decisão:** usar `LINES TERMINATED BY '\r\n'` só nesse bloco.
- **Resultado:** `99224` linhas carregadas, mesmo número de registros do CSV, com `Warnings: 0`.

---

## Verificação da carga (`sql/03_verificacao_carga.sql`)

### 010 - Contagem dos CSVs com `Import-Csv`
- **Decisão:** conferir a carga comparando o `COUNT(*)` de cada tabela com a contagem de registros de cada CSV, feita no PowerShell com `(Import-Csv arquivo.csv).Count`.
- **Motivo:** o `Import-Csv` conta registros, não linhas de texto. Isso importa em `order_reviews`, porque os comentários têm quebras de linha dentro das aspas.
- **Resultado:** as 9 contagens bateram, sem linhas perdidas nem duplicadas.

### 011 - Datas ausentes em `orders` ficam como `NULL`
- **Decisão:** não preencher nem estimar as datas que faltam. Mantenho como `NULL`.
- **Motivo:** preencher seria inventar dado. Antes de decidir, olhei onde os `NULL` aparecem: dos 2.965 pedidos sem data de entrega, 1.850 estão em status que não chegam à entrega (canceled, unavailable, invoiced, processing, created, approved), 1.107 estão em `shipped` e 8 em `delivered`. Ou seja, na maior parte dos casos o `NULL` faz sentido.
- **Impacto:** as médias e contagens de atraso ignoram `NULL` por padrão no MySQL, então não preciso tratar isso a cada consulta.

### 012 - Análise de atraso só com pedidos `delivered` e data de entrega preenchida
- **Decisão:** deixar de fora da análise de atraso qualquer pedido sem `order_delivered_customer_date`.
- **Motivo:** sem a data de entrega não consigo calcular atraso. Pedidos cancelados ou que nunca chegaram à entrega também não têm atraso para medir.
- **Impacto:** 8 pedidos `delivered` ficam de fora, cerca de 0,008% dos 96.478 entregues. Não deve mudar o resultado.
- **Sobre os 8 pedidos `delivered` sem data:** olhei as outras datas deles e estão preenchidas. Isso sugere que a falha foi só no registro da entrega, mas não consigo confirmar a causa pelos dados.
- **A confirmar:** o que aconteceu com os 1.107 pedidos `shipped` sem entrega registrada. Podem ter sido pedidos ainda em trânsito quando o dataset foi extraído ou podem ter sido extraviados. Os dados desta etapa não distinguem, então pode virar uma análise à parte.

---

## Qualidade dos dados (`sql/04_qualidade_dados.sql`)

### 013 - Produtos sem categoria ou sem tradução
- **Problema:** em `products`, 610 produtos não têm categoria (`NULL`) e 13 têm categoria sem tradução em `product_category_translation`: `pc_gamer` (3 produtos) e `portateis_cozinha_e_preparadores_de_alimentos` (10).
- **Impacto:** na análise por categoria, esses produtos somem de um `JOIN` comum ou aparecem sem nome em inglês.
- **A decidir:** como tratar nas views. Opções: usar `LEFT JOIN` e mostrar o nome em português quando faltar a tradução, e rotular os 610 como "sem categoria".
