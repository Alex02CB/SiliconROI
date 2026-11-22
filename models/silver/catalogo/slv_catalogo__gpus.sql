-- =============================================================================
-- slv_catalogo__gpus
-- =============================================================================
-- Capa Silver: una fila por GPU del catálogo, con los valores convertidos a
-- número.
--   1. Convierte los textos con unidades a números con tipo preciso (D-15),
--      con la macro extract_number.
--   2. Separa la VRAM ("16 GB") de su tipo ("GDDR6X"): la VRAM es el umbral
--      de los perfiles (D-04).
--   3. Precio de lanzamiento en euros sin IVA (macro usd_to_eur, D-06).
--   4. device_key: la clave para cruzar con Blender (macro clean_device_name).
-- =============================================================================

with gpus as (
    select * from {{ ref('stg_catalogo__gpus') }}
),

cleaned as (
    select
        -- Identificación
          gpu_name
        , {{ clean_device_name('gpu_name', as_key=true) }}                      as device_key
        , manufacturer
        , architecture
        , launch_date

        -- Memoria: "16 GB GDDR6X" -> 16 y GDDR6X
        , {{ extract_number('memory') }}::number(3,0)                           as vram_gb
        , regexp_substr(memory, 'G?DDR[0-9]X?')                                 as memory_type
        , {{ extract_number('memory_bus') }}::number(4,0)                       as memory_bus_bits
        , {{ extract_number('memory_bandwidth') }}::number(5,0)                 as memory_bandwidth_gbs

        -- Consumo
        , {{ extract_number('tdp') }}::number(4,0)                              as tdp_w

        -- Precio
        , launch_price_usd::number(10,2)                                        as launch_price_usd
        , {{ usd_to_eur('launch_price_usd') }}                                  as launch_price_eur

        -- Trazabilidad
        , data_source
        , captured_at
        , loaded_at
    from gpus
)

select * from cleaned