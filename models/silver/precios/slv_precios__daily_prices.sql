{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key='price_id',
        on_schema_change='fail'
    )
}}

-- =============================================================================
-- slv_precios__daily_prices
-- =============================================================================
-- Capa Silver: una fila por día, tienda y producto, con el precio sin IVA.
--   1. Incremental por loaded_at: cada carga de Bronze (la task de las 23:00)
--      solo trae precios nuevos o regenerados, así que se procesa lo escrito
--      después de la última carga ya procesada ({{ this }}).
--      (Blender usa created_at porque cada snapshot es el histórico completo.)
--   2. Deduplica dentro del lote: el merge falla si trae la misma clave dos veces.
--   3. Precio sin IVA (D-06), con el IVA de la variable vat_rate.
--   4. merge por price_id: si un día se regenera, sus precios se actualizan.
-- =============================================================================

with prices as (
    select *
    from {{ ref('stg_precios__daily_prices') }}
    {% if is_incremental() %}
      -- Solo lo escrito en Bronze después de la última carga procesada
      where loaded_at > (select max(loaded_at) from {{ this }})
    {% endif %}
),

-- Una sola fila por día, tienda y producto: la más reciente
deduplicated as (
    select *
    from prices
    qualify row_number() over (
        partition by price_date, store_name, product_name
        order by loaded_at desc
    ) = 1
),

final as (
    select
          to_char(price_date, 'YYYY-MM-DD') || '__' || store_name || '__' || product_name
                                                                            as price_id
        , price_date
        , store_name
        , product_name
        , product_type
        , retail_price_eur::number(10,2)                                    as retail_price_eur
        , round(retail_price_eur / (1 + {{ var('vat_rate') }}), 2)::number(10,2)
                                                                            as price_ex_vat_eur
        , in_stock
        , currency
        , data_source
        , loaded_at
    from deduplicated
)

select * from final