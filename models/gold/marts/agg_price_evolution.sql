-- =============================================================================
-- agg_price_evolution
-- =============================================================================
-- Caso de uso 3 · Evolución de precios y cuándo comprar.
-- Una fila por producto y mes, con todas las tiendas juntas:
--   - Precio medio, mínimo y máximo (sin IVA) y medio con IVA.
--   - volatility_pct: desviación típica / media × 100. Cuánto se mueve el
--     precio dentro del mes.
--   - change_vs_prev_month_pct: variación del precio medio frente al mes anterior.
--   - diff_vs_product_avg_pct: cuánto más caro o barato está ese mes frente a
--     la media de todo el histórico del producto.
--   - is_cheapest_month: el mes con el precio medio más bajo (el mejor
--     momento para comprar según el histórico).
-- El mes en curso está incompleto: se indica con days_observed.
-- =============================================================================

with prices as (
    select
          f.product_key
        , f.date_day
        , f.price_ex_vat_eur
        , f.retail_price_eur
        , f.in_stock
        , d.year_month
    from {{ ref('fct_daily_prices') }} f
    inner join {{ ref('dim_date') }} d
        on f.date_day = d.date_day
),

products as (
    select
          product_key
        , product_type
        , product_name
        , manufacturer
    from {{ ref('dim_products') }}
),

monthly as (
    select
          product_key
        , year_month
        , count(distinct date_day)                                                    as days_observed
        , round(avg(price_ex_vat_eur), 2)::number(10,2)                               as avg_price_ex_vat_eur
        , min(price_ex_vat_eur)                                                       as min_price_ex_vat_eur
        , max(price_ex_vat_eur)                                                       as max_price_ex_vat_eur
        , round(avg(retail_price_eur), 2)::number(10,2)                               as avg_retail_price_eur
        , round(stddev(price_ex_vat_eur) / nullif(avg(price_ex_vat_eur), 0) * 100, 2)::number(6,2)
                                                                                      as volatility_pct
        , round(avg(iff(in_stock, 1, 0)) * 100, 1)::number(4,1)                       as in_stock_pct
    from prices
    group by product_key, year_month
),

final as (
    select
          m.product_key
        , p.product_type
        , p.product_name
        , p.manufacturer
        , m.year_month
        , m.days_observed
        , m.avg_price_ex_vat_eur
        , m.min_price_ex_vat_eur
        , m.max_price_ex_vat_eur
        , m.avg_retail_price_eur
        , m.volatility_pct
        , m.in_stock_pct
        , round(
              (m.avg_price_ex_vat_eur
               / lag(m.avg_price_ex_vat_eur) over (partition by m.product_key order by m.year_month)
               - 1) * 100
          , 2)::number(8,2)                                                           as change_vs_prev_month_pct
        , round(
              (m.avg_price_ex_vat_eur
               / avg(m.avg_price_ex_vat_eur) over (partition by m.product_key)
               - 1) * 100
          , 2)::number(8,2)                                                           as diff_vs_product_avg_pct
        , rank() over (
              partition by m.product_key
              order by m.avg_price_ex_vat_eur
          ) = 1                                                                       as is_cheapest_month
    from monthly m
    inner join products p
        on m.product_key = p.product_key
)

select * from final