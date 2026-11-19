-- =============================================================================
-- slv_blender_opendata__benchmark_runs
-- =============================================================================
-- Capa Silver: una fila por envío y escena, solo esquema v4.
--   1. Filtra la v4: es la única comparable con el hardware actual.
--   2. FLATTEN: desempaqueta las escenas de cada envío.
--   3. Deduplica: si un envío llega en varios snapshots, se queda el más reciente.
-- Los envíos incompletos y los equipos con varias GPUs NO se descartan aquí:
-- se filtran en Gold, al calcular la puntuación. Silver no pierde información.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- PASO 1 · Leer Staging y quedarnos solo con la v4
-- -----------------------------------------------------------------------------
-- ref() lee otro modelo de dbt (nuestra vista de Staging). Así dbt sabe que
-- este modelo depende de ella y siempre la construye antes.
with submissions as (
    select *
    from {{ ref('stg_blender_opendata__submissions') }}
    -- v1, v2 y v3 miden otra cosa (tiempo de render, escenas antiguas):
    -- no se pueden comparar con la v4. Siguen en Bronze por si hicieran falta.
    where schema_version = 'v4'
),


-- -----------------------------------------------------------------------------
-- PASO 2 · FLATTEN: una fila por cada escena del envío
-- -----------------------------------------------------------------------------
-- Cada envío trae en benchmark_data una lista con sus escenas.
-- lateral flatten recorre esa lista y devuelve un elemento por fila:
--   un envío con 3 escenas  →  3 filas.
-- f.value es la escena de cada fila; con ":" entramos en sus campos
-- y con "::" los convertimos al tipo que queremos.
scenes as (
    select
          s.submission_id                                            -- el envío al que pertenece la escena
        , f.value:scene:label::varchar                               -- monster, junkshop o classroom
                                                                     as scene_name
        , f.value:device_info:device_type::varchar                   -- cómo calculó: CPU, OPTIX, HIP...
                                                                     as device_type
        , f.value:device_info:compute_devices[0]:name::varchar       -- nombre del componente tal cual llega;
                                                                     -- [0] = primer dispositivo de la lista
                                                                     as device_name_raw
        , array_size(f.value:device_info:compute_devices)            -- cuántos dispositivos usó; si son
                                                                     -- más de 1 (p. ej. dos GPUs), Gold lo descartará
                                                                     as num_compute_devices
        , f.value:blender_version:label::varchar                     -- versión de Blender: no se mezclan versiones
                                                                     as blender_version
        , f.value:stats:samples_per_minute::float                    -- la puntuación de la escena (más es mejor)
                                                                     as samples_per_minute
        , f.value:timestamp::timestamp_tz                            -- cuándo se ejecutó la escena
                                                                     as run_at
        -- Columnas del envío: se repiten en cada una de sus escenas
        , s.created_at                                               -- cuándo se subió el envío
        , s.snapshot_date                                            -- de qué snapshot viene
        , s.loaded_at                                                -- cuándo llegó a Bronze
    from submissions s
       , lateral flatten(input => s.benchmark_data) f                -- "para cada envío s, recorre su lista de escenas"
),


-- -----------------------------------------------------------------------------
-- PASO 3 · Deduplicar: una sola fila por envío y escena
-- -----------------------------------------------------------------------------
-- Cada snapshot de Blender trae otra vez todo el histórico. Al cargar un
-- segundo snapshot, la misma pareja envío + escena aparecería dos veces.
-- row_number() numera las copias de cada pareja (partition by), de la más
-- reciente a la más antigua (order by ... desc), y qualify se queda solo
-- con la número 1: la versión más reciente.
deduplicated as (
    select *
    from scenes
    qualify row_number() over (
        partition by submission_id, scene_name        -- cada pareja envío + escena es un grupo
        order by snapshot_date desc, loaded_at desc   -- la más reciente primero
    ) = 1                                             -- nos quedamos solo con esa
),


-- -----------------------------------------------------------------------------
-- PASO 4 · Resultado final con su clave única
-- -----------------------------------------------------------------------------
-- run_id identifica cada fila: envío + escena (p. ej. "abc123__monster").
-- Será la clave con la que el modelo incremental sabrá qué filas ya tiene.
final as (
    select
          submission_id || '__' || scene_name   as run_id
        , *
    from deduplicated
)

select * from final