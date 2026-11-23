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
- **A confirmar:** resultado da checagem de integridade em `04_qualidade_dados.sql`. Se estiver tudo consistente, posso adicionar as FKs depois.

### 003 - Correção de "lenght" para "length"
- **Decisão:** renomear `product_name_lenght` e `product_description_lenght` para `product_name_length` e `product_description_length`.
- **Motivo:** o nome vem com erro de digitação na fonte. Corrigi para evitar o erro se propagar para as consultas e para o dashboard.
- **Impacto:** o nome das colunas no banco difere do CSV. A ordem delas é a mesma, então a carga não é afetada.

### 004 - Chave artificial em `order_reviews`
- **Decisão:** usar uma coluna `id` com `AUTO_INCREMENT` como chave primária, em vez de `review_id`.
- **Motivo:** desconfiei que `review_id` não fosse único, e um pedido pode ter mais de uma avaliação.
- **Verificado:** a tabela tem 99.224 linhas e 98.410 `review_id` distintos, ou seja, 814 linhas a mais por causa de repetição. Nos casos que olhei (os 10 mais repetidos), o mesmo `review_id` aparece em 3 pedidos diferentes. Então `review_id` não identifica uma avaliação sozinho e a chave artificial se justifica (ver `04_qualidade_dados.sql`).
- **A confirmar:** por que isso acontece. Os dados não explicam a causa. Também preciso ver quantas avaliações cada pedido tem, para não duplicar linhas ao juntar pedidos com avaliações.

### 005 - Cliente real é `customer_unique_id`, não `customer_id`
- **Decisão:** nas análises de clientes, usar `customer_unique_id`.
- **Motivo:** `customer_id` é gerado por pedido, então a mesma pessoa pode ter vários.
- **A confirmar:** comparar `COUNT(DISTINCT customer_id)` com `COUNT(DISTINCT customer_unique_id)` para quantificar a diferença.

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