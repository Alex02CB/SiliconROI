-- =============================================================================
-- fct_daily_prices
-- =============================================================================
-- Hecho de precios (D-12): una fila por día, tienda y producto, con las claves
-- de las dimensiones. Los precios ya llegan limpios y sin IVA desde Silver.
-- =============================================================================

with prices as (
    select * from {{ ref('slv_precios__daily_prices') }}
),

products as (
    select product_key, product_type, product_name
    from {{ ref('dim_products') }}
),

stores as (
    select store_key, store_name
    from {{ ref('dim_stores') }}
),

final as (
    select
          p.price_id
        , p.price_date              as date_day
        , pr.product_key
        , s.store_key
        , p.price_ex_vat_eur
        , p.retail_price_eur
        , p.in_stock
        , p.data_source
    from prices p
    inner join products pr
        on  p.product_type = pr.product_type
        and p.product_name = pr.product_name
    inner join stores s
        on p.store_name = s.store_name
)

select * from final