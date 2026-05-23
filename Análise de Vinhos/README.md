# 📊Análise de Dados e Performance de Vendas - Case Vinhos (Kaggle)

## 1. Contexto do Negócio:🎯
Análise exploratória e estratégica de uma base de dados de vendas de vinhos extraída do Kaggle, focada em identificar padrões de consumo, performance de produtos e oportunidades de otimização de receita.

## 🛠️2. Engenharia de Dados & Estrutura do Banco:
Para este projeto, os dados brutos foram tratados e modelados em um banco de dados PostgreSQL. Foi criada uma tabela transacional de vendas para otimizar as consultas e ampliar a análise. 
````sql
-- Estrutura de criação de tabela de vendas:
CREATE TABLE vendas3 (
id_venda SERIAL PRIMARY KEY,
id_vinho Integer,
data_venda DATE,
quantidade INTEGER,
valor_total NUMERIC(10,2));

insert into vendas3 (id_vinho, data_venda, quantidade, valor_total)
select (random() * 130000 + 1)::int,
CURRENT_DATE - (random()*365)::int,
(random()*5 + 1)::int,
ROUND((random()*300+10)::numeric, 2)
FROM generate_series (1,200000);

-- A tabela winetable foi obtida através do seguinte link: https://www.kaggle.com/datasets/zynicide/wine-reviews
Foi efetuado o download da tabela winemag-data-130k-v2.csv, a qual foi importada para o PostgreSQL através do pqsl:

CREATE TABLE winetable
(id_table SERIAL PRIMARY KEY,
country TEXT,
description TEXT,
designation TEXT,points TEXT,
price NUMERIC(10,2),
province TEXT,
region_1 TEXT,
region_2 TEXT,
taster_name TEXT,
taster_twitter_handle TEXT,
title TEXT,
variety TEXT,winery TEXT)

\copy winetable (id_table,country,description,designation,points,price,province,region_1,region_2,taster_name,taster_twitter_handle,title,variety,winery)
from 'C:/Users/Debora Escobar/Desktop/winetable.csv'
with (Format csv, HEADER true, Encoding 'UTF8')
````

## 3. Consultas analíticas (SQL) e Insights de Negócio:

Abaixo estão 8 análises estratégicas desenvolvidas para responder às dores do negócio, divididas por blocos de inteligência comercial.

## 📊Bloco 1: Modelagem Temporal & Crescimento de Negócio:

## Análise 3.1: Avaliação de Sazonalidade Mensal com função de Lag: :
**🎯Objetivo:** 
```sql
with faturamento_mensal as (
select date_trunc('month', v.data_venda) as mes_data,
sum(v.quantidade * w.price) as faturamento
from vendas3 v join winetable w
on v.id_vinho = w.id_table group by mes_data)
select to_char(mes_data, 'mm-yyyy') as mes,
faturamento,
lag(faturamento) over (order by mes_data) as mes_anterior,
faturamento - lag(faturamento) over (order by mes_data) as variacao,
round((faturamento - lag(faturamento) over (order by mes_data))/
nullif (lag(faturamento) over (order by mes_data), 0)*100, 2) as var_percentual
from faturamento_mensal
order by mes_data
```
**💻Resultado esperado do Output (Recorte):**
**💡Insight:** 

## 📊Bloco 2: Inteligência de Mercado & Posicionamento de Portifólio:

## Análise 3.2: Top Variedades Líderes de Faturamento por País:
**🎯Objetivo:** 
```sql
with ranking_pais as (
select w.country as pais, w.variety as variedade_uva, 
round(sum(v.quantidade * coalesce(w.price, 0)),2) as faturamento_total,
dense_rank() over (partition by w.country order by sum(v.quantidade * coalesce(w.price,0)) desc) 
as posicao_ranking
from vendas3 v inner join winetable w 
on v.id_vinho = w.id_table
group by w.country, w.variety
)
select pais, variedade_uva, faturamento_total, posicao_ranking
from ranking_pais
where posicao_ranking <=3
order by pais asc, faturamento_total desc
```
**💻Resultado esperado do Output (Recorte):**
**💡Insight:** 

## Análise 3.3: Score de Performance Geral de Vendas:
**🎯Objetivo:** 
```sql
with performance as (
select w.id_table, w.winery,sum(v.quantidade)::NUMERIC as volume, sum(v.quantidade * w.price)::NUMERIC as faturamento,
count (v.id_venda)::NUMERIC as frequencia
from vendas3 v join winetable w on v.id_vinho = w.id_table
group by w.id_table, w.winery)
select id_table, winery, volume, faturamento, frequencia, 
round(((volume/max(volume) over())*0.4 + 
(faturamento/max(faturamento)over()) * 0.4
+ (frequencia/max(frequencia) over()) * 0.2)::NUMERIC, 4) as score
from performance
order by score desc
```
**💻Resultado esperado do Output (Recorte):**
**💡Insight:** 

## 📊Bloco 3: Governança de Pricing & Eficiência Operacional::

## Análise 3.4: Classificação ABC por Faturamento:
**🎯Objetivo:**.
```sql
with faturamento as (
select w.id_table, w.winery,sum(v.quantidade*w.price) as receita
from vendas3 v join winetable w 
on v.id_vinho = w.id_table 
group by w.id_table, w.winery),
ranking as (
select *, sum(receita) over(order by receita desc) as receita_acumulada,
sum(receita) over () as receita_total from faturamento)
select id_table, winery, receita, 
round(receita_acumulada/receita_total*100,2) as percentual_acumulado
from ranking
order by receita desc
```
**💻Resultado esperado do Output (Recorte):**
**💡Insight:** 

## Análise 3.5: Detecção de Outliers de Preço por Categoria:
**🎯Objetivo:**
```sql
with estatistica_pais as (
select w.country as pais, avg(price) as media_preco, stddev(price) as  desvio_preco
from winetable w 
group by country
having count(*)> 1
)
select  w.country as pais, count (case when w.price > (s.media_preco + (2*s.desvio_preco))
then 1 end) as qtd_outliers_caros, 
count (case when w.price < (s.media_preco - (2*s.desvio_preco)) then 1 end) as qtd_outliers_baratos,
count (case when w.price >= (s.media_preco - (2*s.desvio_preco)) and
w.price <= (s.media_preco + (2*s.desvio_preco))  then 1 end) as qtd_vinhos_padrao,
count (*) as total_vinho_pais
from winetable w join estatistica_pais s 
on w.country = s.pais
where price is not null
group by w.country
order by total_vinho_pais desc
```
**💻Resultado esperado do Output (Recorte):**
**💡Insight:** 













