-- =============================================================================
-- int_product_performance
-- =============================================================================
-- Puntuación de rendimiento de cada CPU y GPU, a partir de fct_benchmark_results.
--   1. Solo las versiones de Blender de referencia (var blender_reference_versions,
--      D-21): cada versión cambia el motor de render y no se mezclan.
--   2. Solo el backend principal de cada fabricante (D-21):
--      CPU -> CPU · NVIDIA -> OPTIX · AMD -> HIP · Intel -> ONEAPI.
--      Se descartan CUDA (más lento en la misma tarjeta) y METAL (Macs).
--   3. Mediana de los envíos: no le afectan los valores extremos (equipos con
--      overclock, ejecuciones con el equipo ocupado).
--   4. Mínimo de envíos (var min_benchmark_samples, D-22): un producto con
--      menos envíos no tiene puntuación fiable y no se recomienda.
--   5. Índices de 0 a 100 dentro de cada tipo: el mejor producto vale 100.
--      Así los pesos de los perfiles combinan CPU y GPU en la misma escala.
-- =============================================================================

with benchmarks as (
    select
          b.product_key
        , b.device_type
        , b.blender_version_minor
        , b.score
        , b.date_day
        , p.product_type
        , p.product_name
        , case
              when p.product_type = 'cpu'           then 'CPU'
              when upper(p.manufacturer) = 'NVIDIA' then 'OPTIX'
              when upper(p.manufacturer) = 'AMD'    then 'HIP'
              when upper(p.manufacturer) = 'INTEL'  then 'ONEAPI'
          end                                       as expected_backend
    from {{ ref('fct_benchmark_results') }} b
    inner join {{ ref('dim_products') }} p
        on b.product_key = p.product_key
),

-- Versiones de referencia y backend principal de cada fabricante
filtered as (
    select *
    from benchmarks
    where device_type = expected_backend
      and blender_version_minor in (
          {%- for version in var('blender_reference_versions') %}
          '{{ version }}'{% if not loop.last %},{% endif %}
          {%- endfor %}
      )
),

-- Una puntuación por producto: mediana de sus envíos
aggregated as (
    select
          product_key
        , product_type
        , product_name
        , device_type                               as backend
        , count(*)                                  as benchmark_samples
        , median(score)                             as median_score
        , min(date_day)                             as first_benchmark_date
        , max(date_day)                             as last_benchmark_date
    from filtered
    group by product_key, product_type, product_name, device_type
    having count(*) >= {{ var('min_benchmark_samples') }}
),

-- Rendimiento monohilo de las CPUs (catálogo), para los perfiles de oficina y BIM
single_thread as (
    select
          product_key
        , cpu_single_thread_score
    from {{ ref('dim_products') }}
    where product_type = 'cpu'
),

final as (
    select
          a.product_key
        , a.product_type
        , a.product_name
        , a.backend
        , a.benchmark_samples
        , round(a.median_score, 2)::number(12,2)                            as median_score
        , round(
              a.median_score / max(a.median_score) over (partition by a.product_type) * 100
          , 1)::number(4,1)                                                 as performance_index
        , st.cpu_single_thread_score
        , round(
              st.cpu_single_thread_score
              / max(st.cpu_single_thread_score) over (partition by a.product_type) * 100
          , 1)::number(4,1)                                                 as single_thread_index
        , a.first_benchmark_date
        , a.last_benchmark_date
    from aggregated a
    left join single_thread st
        on a.product_key = st.product_key
)

select * from final