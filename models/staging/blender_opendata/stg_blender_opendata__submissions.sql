-- =============================================================================
-- stg_blender_opendata__submissions
-- =============================================================================
-- Capa Staging: relación 1:1 con Bronze. Solo renombrado y tipado.
-- No se filtra la versión de esquema ni se deduplica: eso es trabajo de Silver.
-- benchmark_data se mantiene como VARIANT: su estructura cambia entre versiones
-- (objeto en v1, lista de escenas en v3 y v4) y se desempaqueta en Silver.
-- =============================================================================

with source as (
    select * from {{ source('blender_opendata', 'submissions') }}
),

renamed as (
    select
          raw:id::varchar                     as submission_id
        , raw:schema_version::varchar         as schema_version
        , raw:created_at::timestamp_tz        as created_at
        , raw:data                            as benchmark_data
        , to_date(regexp_substr(_source_file, '[0-9]{4}-[0-9]{2}-[0-9]{2}'))
                                              as snapshot_date
        , _source_file                        as source_file
        , _source_row                         as source_row
        , _loaded_at                          as loaded_at
    from source
)

select * from renamed