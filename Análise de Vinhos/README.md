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

Abaixo estão 5 análises estratégicas desenvolvidas para responder às dores do negócio, divididas por blocos de inteligência comercial.

## 📊Bloco 1: Modelagem Temporal & Crescimento de Negócio:

## Análise 1.1: Avaliação de Sazonalidade Mensal e Performance MoM:

**🎯Objetivo:** Analisar a evolução histórica do faturamento global mês a mês, identificando os períodos de pico e vale na receita, além de calcular a variação percentual em relação ao mês anterior(MoM). 
```sql
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
```
**💻Resultado esperado do Output (Recorte):**

<img width="669" height="394" alt="image" src="https://github.com/user-attachments/assets/0ca12fe1-2d9b-41e5-8da5-07c70a59a92e" />

**💡Insight:** 

**- Estabilidade da Receita:** O faturamento se estabiliza acima de **$2,2 milhões entre maio e janeiro, tendo seu maior salto inicial em maio (+55.27%). 

**- Ponto de atenção:** Fevereiro apresenta a maior retração da série (-8.75%), apontando para uma desaceleração sazonal global  de consumo, o que permite que importadores gerenciem seus fluxos de compras e estoque de forma estratégica.

## 📊Bloco 2: Inteligência de Mercado & Posicionamento de Portifólio:

## Análise 2.1: Top Variedades Líderes de Faturamento por País:

**🎯Objetivo:** Identificar e rankear as principais variedades de uvas líderes em faturamento dentro de cada país produtor, utilizando funções de janela (DENSE_RANK). Permite mapear o core business de cada país, servindo como guia estratégico para entender as forças comerciais de cada região. 
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

<img width="672" height="221" alt="image" src="https://github.com/user-attachments/assets/a10ec893-326a-4f78-9e66-8bc94ee5fd6a" />

(Output resumido para fins de demonstração executiva do funcionamento da partição por país).

**💡Insight:** 

**- Assimetria de Mercado:** O Chile demonstra uma tração comercial infinitamente superior à do Canadá em termos de volume de receita, liderado pelo Red Blend (88,4 mil), destacando-se como mercado de alto volume e relevância para o comércio internacional de vinhos.

**- Mapeamento de Preferências:** Enquanto o Canadá se posiciona fortemente com vinhos brancos aromáticos (Riesling e Chardonnay nas primeiras posições), o Chile tem sua força  concentrada em vinhos encorpados (Red Blend, Cabernet e Carmenère).

**- Estratégia de Precificação:** Saber a variedade de uva líder em cada país direciona as estratégias de negociação por ganho de escala.

## Análise 2.2: Score de Performance de Vendas por Vinícola:

**🎯Objetivo:** Avaliar a tração comercial das marcas produtoras do mercado global por meio de um indicador composto ponderado (40% volume, 40% faturamento e 20% frequência de compra) normalizado pelo valor máximo. O objetivo é cruzar o score de desempenho com o preço médio e nota técnica de cada vinho, para identificar marcas estratégicas e distorções de valor.
```sql
with performance_vinicola as (
select w.winery as vinicola, w.country as pais, w.province as provincia, 
round(avg(w.price), 2) as preco_medio,
round(avg(w.points::NUMERIC), 1) as nota_tecnica_media,
sum(v.quantidade)::NUMERIC as volume_vendas, 
sum(v.quantidade * w.price)::NUMERIC as faturamento_total,
count (v.id_venda)::NUMERIC as frequencia_compra
from vendas3 v join winetable w on v.id_vinho = w.id_table
group by w.winery, w.country, w.province
)
select vinicola, pais, provincia, preco_medio, nota_tecnica_media, 
round(((volume_vendas/max(volume_vendas) over())*0.4 + 
(faturamento_total/max(faturamento_total)over()) * 0.4
+ (frequencia_compra/max(frequencia_compra) over()) * 0.2), 4) as score_performance
from performance_vinicola
order by score_performance desc
```
**💻Resultado esperado do Output (Recorte):**

<img width="1073" height="196" alt="image" src="https://github.com/user-attachments/assets/5e8ecbf9-dd7b-44d8-8ab5-12e94a6bdfb1" />

(Output resumido com as 5 principais vinícolas do ranking geral para fins de análise).

**💡Insight:** 

**- Destaque de Alto Valor Agregado:** A francesa Louis Latour lidera o mercado global com um score de **0.9140**, impulsionada por um forte faturamento  gerado pelo alto preço médio ($123.58), consolidando-se como uma marca de alta relevância financeira e posicionamento premium.

**- Oportunidade de Custo-Benefício:** A americana Williams Selyem ocupa a segunda posição com score **0.9268**, apresentando a maior nota técnica do topo do ranking (92.8), mas com preço médio aproximadamente 50% menor que o da líder ($60.01). Isso indica um produto de alta qualidade com preço competitivo e forte tração de mercado.

**- Eficiência e Volume:** A vinícola Chateau Ste.Michelle consegue se posicionar no Top 5 mesmo com um preço médio baixo ($23.12), o que comprova que o score é sustentado por um alto volume de vendas e frequência no mercado.

## 📊Bloco 3: Governança de Pricing & Eficiência Operacional::

## Análise 3.1: Curva ABC por País (Classificação por Relevância de Faturamento):

**🎯Objetivo:** Aplicar o princípio de Pareto (regra dos 80/20) para categorizar os países produtores de vinho em classes (A, B e C) com base na receita acumulada. Esta análise macroeconômica visa identificar os mercados de maior relevância financeira global.
```sql
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
```
**💻Resultado esperado do Output (Recorte):**

<img width="741" height="190" alt="image" src="https://github.com/user-attachments/assets/0aca8739-f8d7-4c50-a424-1e35a191dbd7" />

(Output resumido com as 5 primeiras linhas para demonstrar o ponto de virada analítica entre as classes A e B. O resultado total abrange 43 países produtores).

**💡Insight:** 

**- Hiperconcentração de Mercado (Classe A):** Apenas 3 países (Estados Unidos, França e Itála) detém praticamente 80% do faturamento mundial de vinhos do dataset, o que revela onde está o core financeiro.

**- Ponto de Inflexão (Transição para a Classe B):** Portugal e Espanha abrem a classe B com receitas individuais na casa de 1 milhão. Embora tenham reputação de qualidade, operam em uma escala financeira bem menor do que os países da Classe A.

**- Visão de Mitigação de Risco:** Para grandes players de logística e distribuição, focar o planejamento em mercados da Classe A garante estabilidade de receita, enquanto os países das classes B e C servem para diversificar o portifólio.

## Análise 3.2: Detecção de Outliers de Preço por País (Volumetria de Dispersão):

**🎯Objetivo:** Quantificar volumetricamente a distribuição de rótulos que operam fora das faixas normais de preço (limites de +- 2 desvios padrões) agrupados por país produtor e mapear quais mercados globais concentram o maior volume de produtos de exceção, servindo como um diagnóstico macro da dispersão de preços em cada região.
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

<img width="804" height="219" alt="image" src="https://github.com/user-attachments/assets/5f4b38fa-99c3-4671-ac18-11c90bf6af2f" />

(Output resumido com os 6 países com maior volume de dados para demonstrar a eficiência do modelo estatístico de dispersão. O resultado total engloba 40 países auditados.

**💡Insight:** 

**- Assimetria de Preços:** A presença constante de 0 outliers baratos em todas as praças comprova que o mercado global possui uma barreira natural de preço mínimo. Em contrapartida, o volume de outliers caros reflete a forte presença de rótulos premium e safras exclusivas de colecionadores.

**- Comportamento de Mercado (EUA vs Europa):** Embora a França e Itália tenham volumes similares de vinhos no padrão (casa de 20 mil), o mercado americano (US) se destaca com 1.825 vinhos considerados como outliers caros. Isso indica que os EUA operam em uma dinâmica de mercado com dispersão muito mais agressiva para o segmento super premium.

**- Direcionamento de Auditoria Detalhada:** Essa visão macro funciona como um dashboard de controle. Ao perceber que uma região apresenta quantidade anormal de outliers, o analista ganha direcionamento estratégico de qual país precisa sofrer um drill-down em uma análise subsequente.













