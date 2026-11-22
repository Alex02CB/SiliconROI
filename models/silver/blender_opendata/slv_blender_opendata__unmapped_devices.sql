-- =============================================================================
-- slv_blender_opendata__unmapped_devices
-- =============================================================================
-- Capa Silver: cuarentena. Una fila por dispositivo de Blender que no cruza
-- con ningún producto del catálogo, ni directamente ni por el seed.
-- No es basura: documenta el hardware que Blender mide y queda fuera del
-- alcance del proyecto, y señala candidatos a entrar en el catálogo (D-31).
--
-- probable_reason es una clasificación aproximada por el nombre, para revisar
-- la cuarentena de un vistazo:
--   nombre_generico     el nombre no identifica el modelo ("AMD Radeon")
--   apple               Apple Silicon o backend Metal
--   servidor_o_pro      Xeon, Threadripper, RTX A, Quadro, Tesla
--   portatil            sufijos de portátil (H, HX, HS, U, G7, Max-Q, Laptop)
--   fuera_de_catalogo   de sobremesa pero no en el catálogo: candidatos (D-31)
-- =============================================================================

with runs as (
    select * from {{ ref('slv_blender_opendata__benchmark_runs') }}
),

mapped as (
    select distinct device_key
    from {{ ref('slv_blender_opendata__device_products') }}
),

unmapped as (
    select
          r.device_key
        , any_value(r.device_name)                                      as device_name
        , listagg(distinct r.device_type, ', ')
              within group (order by r.device_type)                     as device_types
        , count(distinct r.submission_id)                               as submissions
        , min(r.created_at)                                             as first_seen_at
        , max(r.created_at)                                             as last_seen_at
    from runs r
    left join mapped m
        on r.device_key = m.device_key
    where m.device_key is null
    group by r.device_key
),

final as (
    select
          *
        , case
              when device_key in ('amd radeon', 'intel', 'intel arc', 'virtual', 'radeon rx vega')
                  then 'nombre_generico'
              when device_key like 'apple %' or device_types like '%METAL%'
                  then 'apple'
              when device_key like '%xeon%'
                or device_key like '%threadripper%'
                or device_key like 'nvidia rtx a%'
                or device_key like 'nvidia rtx pro%'
                or device_key like '%rtx 6000 ada%'
                or device_key like 'quadro%'
                or device_key like 'tesla%'
                  then 'servidor_o_pro'
              when device_key like '%laptop%'
                or device_key like '%max-q%'
                or regexp_like(device_key, '.*([0-9](h|hx|hs|hk|u)|g[0-9])$')
                  then 'portatil'
              else 'fuera_de_catalogo'
          end                                                           as probable_reason
    from unmapped
)

select * from final