-- =============================================================================
-- slv_catalogo__ram_kits
-- =============================================================================
-- Capa Silver: una fila por kit de RAM del catálogo, con los valores
-- convertidos a número.
--   1. Convierte los textos a números con tipo preciso (D-15), con la macro
--      extract_number: "DDR5-6000" -> 6000, "2x16GB" -> 2 módulos de 16 GB.
--   2. Calcula la capacidad total y la latencia real en nanosegundos.
--   3. Precio de referencia en euros sin IVA (macro usd_to_eur, D-06).
-- =============================================================================

with ram_kits as (
    select * from {{ ref('stg_catalogo__ram_kits') }}
),

cleaned as (
    select
        -- Identificación
          ram_kit_name
        , manufacturer
        , memory_type

        -- Velocidad y latencia: "DDR5-6000" (el 1.er número es el 5 de DDR5)
        -- y "30-36-36-96" (el 1.er número es la latencia CAS)
        , {{ extract_number('speed', 2) }}::number(5,0)                         as speed_mts
        , {{ extract_number('timings') }}::number(3,0)                          as cas_latency

        -- Configuración: "2x16GB" -> 2 módulos de 16 GB
        , {{ extract_number('kit_configuration') }}::number(2,0)                as modules
        , {{ extract_number('kit_configuration', 2) }}::number(4,0)             as module_gb
        , {{ extract_number('voltage') }}::number(3,2)                          as voltage_v

        -- Precio
        , reference_price_usd::number(10,2)                                     as reference_price_usd
        , {{ usd_to_eur('reference_price_usd') }}                               as reference_price_eur
        , reference_price_date

        -- Trazabilidad
        , data_source
        , captured_at
        , loaded_at
    from ram_kits
),

-- Métricas calculadas a partir de las columnas ya limpias
final as (
    select
          *
        , (modules * module_gb)::number(4,0)                                    as total_gb
        -- Latencia real en ns = CL × 2000 / velocidad (MT/s).
        -- Permite comparar kits de distinta velocidad: DDR5-6000 CL30 = 10 ns.
        , round(cas_latency * 2000 / speed_mts, 2)::number(5,2)                 as latency_ns
    from cleaned
)

select * from final