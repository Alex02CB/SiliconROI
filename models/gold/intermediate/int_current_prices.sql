-- =============================================================================
-- int_current_prices
-- =============================================================================
-- Mejor precio actual de cada producto: el del último día cargado, en la
-- tienda más barata que lo tenga en stock.
--   - Un producto sin stock en ninguna tienda ese día no aparece: no se puede
--     comprar, así que no se recomienda.
--   - Si dos tiendas empatan, se elige por orden alfabético (resultado estable
--     entre ejecuciones).
-- =============================================================================

with prices as (
    select * from {{ ref('fct_daily_prices') }}
),

stores as (
    select store_key, store_name
    from {{ ref('dim_stores') }}
),

latest_date as (
    select max(date_day) as last_date
    from prices
),

current_prices as (
    select
          p.product_key
        , p.date_day
        , s.store_key
        , s.store_name
        , p.price_ex_vat_eur
        , p.retail_price_eur
        , count(*)                over (partition by p.product_key)   as stores_in_stock
        , max(p.price_ex_vat_eur) over (partition by p.product_key)   as highest_price_ex_vat_eur
    from prices p
    inner join latest_date l
        on p.date_day = l.last_date
    inner join stores s
        on p.store_key = s.store_key
    where p.in_stock
),

final as (
    select
          product_key
        , date_day                          as price_date
        , store_key                         as best_store_key
        , store_name                        as best_store_name
        , price_ex_vat_eur                  as best_price_ex_vat_eur
        , retail_price_eur                  as best_retail_price_eur
        , highest_price_ex_vat_eur
        , stores_in_stock
    from current_prices
    qualify row_number() over (
        partition by product_key
        order by price_ex_vat_eur, store_name
    ) = 1
)

select * from final