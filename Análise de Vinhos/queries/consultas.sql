--GITHUB--

--CASE DE NEGÓCIO: ANÁLISE DE VENDAS DE VINHOS (KAGGLE)
--AUTOR: DEBORA ESCOBAR
--Scripts das Consultas Analíticas--
=================================================================================================================================================

--Bloco 1: MODELAGEM TEMPORAL E CRESCIMENTO DE NEGÓCIO:
-------------------------------------------------------------------------------------------------------------------------------------------------
-- Análise 1.1: Avaliação de Sazonalidade Mensal e Performance MoM:  
with faturamento_mensal as (
select date_trunc('month', v.data_venda) as mes_data,
sum(v.quantidade * w.price) as faturamento
from vendas3 v join winetable w
on v.id_vinho = w.id_table 
where v.data_venda < '2026-04-01'
group by mes_data)
select to_char(mes_data, 'mm-yyyy') as mes,
faturamento,
lag(faturamento) over (order by mes_data) as faturamento_mes_anterior,
faturamento - lag(faturamento) over (order by mes_data) as variacao,
round((faturamento - lag(faturamento) over (order by mes_data))/
nullif (lag(faturamento) over (order by mes_data), 0)*100, 2) as var_percentual
from faturamento_mensal
order by mes_data

------------------------------------------------------------------------------------------------------------------------------------------------
--Bloco 2: Inteligência de Mercado & Posicionamento de Portifólio:
------------------------------------------------------------------------------------------------------------------------------------------------

--Análise 2.1: Top Variedades Líderes de Faturamento por País:

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

--Análise 2.2: Score de Performance de Vendas por Vinícola:

with performance_vinicola as (
select w.winery as vinicola, w.country as pais, w.province as provincia, 
round(avg(w.price), 2) as preco_medio,
round(avg(w.points::NUMERIC), 1) as nota_tecnica_media,
sum(v.quantidade)::NUMERIC as volume_vendas, 
sum(v.quantidade * w.price)::NUMERIC as faturamento_total,
count (v.id_venda)::NUMERIC as frequencia_compra
from vendas3 v join winetable w on v.id_vinho = w.id_table
group by w.winery, w.country, w.province)
select vinicola, pais, provincia, preco_medio, nota_tecnica_media, 
round(((volume_vendas/max(volume_vendas) over())*0.4 + 
(faturamento_total/max(faturamento_total)over()) * 0.4
+ (frequencia_compra/max(frequencia_compra) over()) * 0.2), 4) as score_performance
from performance_vinicola
order by score_performance desc

------------------------------------------------------------------------------------------------------------------------------------------------
--Bloco 3: Governança de Pricing & Eficiência Operacional:
------------------------------------------------------------------------------------------------------------------------------------------------

--Análise 3.1: Curva ABC por País (Classificação por Relevância de Faturamento):

with faturamento_pais as (
select w.country as pais, sum(v.quantidade*w.price) as receita
from vendas3 v join winetable w 
on v.id_vinho = w.id_table
where w.country is not null
group by w.country),
ranking_acumulado as (
select pais, receita, sum(receita) over(order by receita desc) as receita_acumulada,
sum(receita) over () as receita_total from faturamento_pais)
select pais, receita, 
round((receita_acumulada/receita_total)*100,2) as percentual_acumulado,
case when (receita_acumulada/receita_total) <= 0.80 then 'A (Altamente Crítico - 80% da Receita)'
     when (receita_acumulada/receita_total) <= 0.95 then 'B (Intermediário - 15% da Receita)'
	 else  'C (Baixo Impacto - 5% da Receita)'
	 end as classe_ABC
	 from ranking_acumulado
order by receita desc

--Análise 3.2: Detecção de Outliers de Preço por País (Volumetria de Dispersão):

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

