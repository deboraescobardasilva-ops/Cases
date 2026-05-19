--GITHUB--

--CASE DE NEGÓCIO: ANÁLISE DE VENDAS DE VINHOS (KAGGLE)
--AUTOR: DEBORA ESCOBAR
--Scripts das Consultas Analíticas--
=================================================================================================================================================

--Bloco 1: PERFORMANCE DE PRODUTO E MIX DE VENDAS:
-------------------------------------------------------------------------------------------------------------------------------------------------
--Análise 3.1: Classificação de Curva ABC por Faturamento:

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

--Análise 3.2: Identificação das Variedades mais Lucrativas:

select w.variety, sum(v.quantidade * w.price) as faturamento, sum(v.quantidade) as volume
from vendas3 v join winetable w 
on v.id_vinho = w.id_table
group by w.variety
order by faturamento desc
limit 10

--Análise 3.3: Vinhos nunca Vendidos:

select w.id_table, w.winery, w.variety, w.price 
from winetable w left join vendas3 v 
on v.id_vinho = w.id_table
where v.id_vinho is null
------------------------------------------------------------------------------------------------------------------------------------------------
--Bloco 2: Elastidade de Preço e Inteligência Geográfica:
------------------------------------------------------------------------------------------------------------------------------------------------
--Análise 3.4: Análise de Preços vs Volume de Vendas:

select case when w.price < 50 then 'Barato'
            when w.price between 50 and 100 then 'Médio'
            else 'Premium'
end as  faixa_preco,
sum(v.quantidade) as volume_vendido,
round(avg(w.price),2) as ticket_medio
from vendas3 v join winetable w 
on v.id_vinho = w.id_table
group by faixa_preco
order by ticket_medio

--Análise 3.5: Ticket_Médio (TM) e Faturamento por País de Origem:

select w.country, round(avg(price),2) as ticket_medio
from vendas3 v join winetable w 
on v.id_vinho = w.id_table
group by w.country 
order by ticket_medio desc

--Análise 3.6: Detecção de Outliers de Preço por Categoria:

with stats as (
select avg(price) as media_preco, stddev (price) as desvio_preco from winetable
)
select variety, country, province, winery, price, round(media_preco + 2*s.desvio_preco,2) as limite_superior,
round(media_preco - 2*s.desvio_preco,2) as limite_inferior
from winetable w cross join stats s
where w.price > s.media_preco + 2*s.desvio_preco 
or w.price < s.media_preco - 2*s.desvio_preco 

--query ajustada, uma vez que rodando a query acima detectamos que o limite inferior resultou em valor negativo--
with stats as (
select avg(price) as media_preco, stddev (price) as desvio_preco from winetable
)
select variety, country, province, winery, price, round(media_preco + 2*s.desvio_preco,2) as limite_superior,
from winetable w cross join stats s
where w.price > s.media_preco + 2*s.desvio_preco 

------------------------------------------------------------------------------------------------------------------------------------------------
--Bloco 3: Modelagem Temporal e Crescimento de Negócio:
------------------------------------------------------------------------------------------------------------------------------------------------

--Análise 3.7: Avaliação de Sazonalidade Mensal com função de Lag:

with faturamento_mensal as
(select to_char(date_trunc('month', v.data_venda),'mm-yyyy') as mes, sum(v.quantidade * w.price) as faturamento
from vendas3 v join winetable w
on v.id_vinho = w.id_table group by mes)
select mes, faturamento, lag(faturamento) over (order by mes) as mes_anterior,
faturamento - lag(faturamento) over (order by mes) as variacao,
round((faturamento - lag(faturamento) over (order by mes))/lag(faturamento) over (order by mes),2) as var_prc
from faturamento_mensal
order by mes

--Análise 3.8: Score de Performance Geral de Vendas:

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

---------------------------------------------------------------------------------------------------------------------------------------------
