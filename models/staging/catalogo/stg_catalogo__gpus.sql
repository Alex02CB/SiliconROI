-- =============================================================================
-- stg_catalogo__gpus
-- =============================================================================
-- Capa Staging: relación 1:1 con Bronze. Renombrado al inglés, sin cambiar
-- el contenido. VRAM, ancho de banda y consumo siguen siendo texto con
-- unidades ("16 GB GDDR6", "640 GB/s"): se convierten en números en Silver.
-- =============================================================================

with source as (
    select * from {{ source('catalogo', 'gpus') }}
),

renamed as (
    select
          gpu_nombre            as gpu_name
        , fabricante            as manufacturer
        , arquitectura          as architecture
        , fecha_lanzamiento     as launch_date
        , memoria               as memory
        , bus_memoria           as memory_bus
        , ancho_banda           as memory_bandwidth
        , tdp                   as tdp
        , precio_lanzamiento_usd as launch_price_usd
        , fuente                 as data_source
        , fecha_captura          as captured_at
        , _loaded_at             as loaded_at
    from source
)

select * from renamed