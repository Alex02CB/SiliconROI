-- =============================================================================
-- fct_daily_prices
-- =============================================================================
-- Hecho de precios (D-12): una fila por día, tienda y producto, con las claves
-- de las dimensiones. Los precios ya llegan limpios y sin IVA desde Silver.
--
-- Incremental, como slv_precios__daily_prices: la cadena de precios es
-- incremental de punta a punta. Cada noche solo entran las filas que Silver
-- ha cargado después de la última ejecución (loaded_at), 580 en un día normal.
-- Merge por price_id: si un día se regenera en origen, se actualiza en lugar
-- de duplicarse. on_schema_change='fail': un cambio de columnas obliga a
-- reconstruir con --full-refresh, nunca pasa en silencio.
-- El test equal_rowcount comprueba que el hecho tiene las mismas filas que
-- Silver: si la cadena se rompiera, fallaría.
-- =============================================================================

{{ config(
    materialized='incremental',
    incremental_strategy='merge',
    unique_key='price_id',
    on_schema_change='fail'
) }}

with prices as (
    select * from {{ ref('slv_precios__daily_prices') }}
    {% if is_incremental() %}
    -- Solo lo que Silver ha cargado después de la última ejecución
    where loaded_at > (select max(loaded_at) from {{ this }})
    {% endif %}
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
        , p.loaded_at
    from prices p
    inner join products pr
        on  p.product_type = pr.product_type
        and p.product_name = pr.product_name
    inner join stores s
        on p.store_name = s.store_name
)

select * from final