-- =============================================================================
-- stg_catalogo__ram_kits
-- =============================================================================
-- Capa Staging: relación 1:1 con Bronze. Renombrado al inglés, sin cambiar
-- el contenido. Velocidad, latencia y voltaje siguen siendo texto
-- ("DDR5-6000", "30-36-36-96", "1.35 V"): se convierten en números en Silver.
-- =============================================================================

with source as (
    select * from {{ source('catalogo', 'ram_kits') }}
),

renamed as (
    select
          ram_kit_nombre            as ram_kit_name
        , fabricante                as manufacturer
        , tipo                      as memory_type
        , velocidad                 as speed
        , latencia                  as timings
        , configuracion             as kit_configuration
        , voltaje                   as voltage
        , precio_referencia_usd     as reference_price_usd
        , fecha_precio_referencia   as reference_price_date
        , fuente                    as data_source
        , fecha_captura             as captured_at
        , _loaded_at                as loaded_at
    from source
)

select * from renamed