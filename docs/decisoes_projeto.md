# Diário de decisões

## 001 - CEP como CHAR(5)
- **Decisão:** guardar CEP como texto de 5 caracteres.
- **Motivo:** como número, o CEP 01037 viraria 1037 e quebraria o cruzamento com a geolocalização.
- **Alternativa descartada:** INT.

## 002 - Sem FOREIGN KEY na criação das tabelas
- **Decisão:** criar só índices nas colunas de JOIN.
- **Motivo:** carregar tudo primeiro e checar registros órfãos na etapa de qualidade.
- **A confirmar:** resultado da checagem em 04_qualidade_dados.sql.