-- =============================================================================
-- stg_precios__daily_prices
-- =============================================================================
-- Capa Staging: precios diarios por tienda, 1:1 con Bronze.
-- Solo renombra al inglés; los tipos ya llegan correctos desde Bronze.
-- Quitar el IVA es una regla de negocio y se hace en Silver.
-- =============================================================================

with source as (
    select * from {{ source('precios', 'precios_diarios') }}
),

renamed as (
    select
          fecha           as price_date
        , tienda          as store_name
        , producto        as product_name
        , tipo_producto   as product_type
        , precio_pvp      as retail_price_eur     -- con IVA
        , moneda          as currency
        , en_stock        as in_stock
        , fuente          as data_source
        , _loaded_at      as loaded_at
    from source
)

select * from renamed