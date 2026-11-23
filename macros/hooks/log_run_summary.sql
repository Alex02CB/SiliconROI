{#
=============================================================================
log_run_summary
=============================================================================
Hook de proyecto (on-run-end, en dbt_project.yml). Al terminar cada
ejecución escribe en el log un resumen:
  - entorno (DBT_ENVIRONMENT),
  - modelos, seeds, snapshots y tests correctos,
  - avisos, errores y nodos omitidos (por depender de uno que falló),
  - filas totales de cada modelo incremental al terminar (día a día se ve
    cuánto crece: +580 precios por noche).

results: la lista de resultados que dbt pasa a on-run-end (un elemento por
nodo ejecutado, con su estado y su nodo).

Las filas se cuentan con un count(*) sobre la tabla. No se usa
adapter_response.rows_affected: en dbt Fusion devuelve 0 en los merge
incrementales aunque inserten filas (comprobado en PRO el 23/11: 0 frente a
+580 precios reales). No devuelve SQL: solo escribe en el log.
=============================================================================
#}

{% macro log_run_summary(results) %}
    {%- if execute -%}

        {%- set c = namespace(modelos=0, seeds=0, snapshots=0, tests=0, avisos=0, errores=0, omitidos=0) -%}

        {%- for r in results -%}
            {%- set estado = r.status | string | lower -%}
            {%- set tipo   = r.node.resource_type | string | lower -%}
            {%- if estado in ['error', 'fail', 'runtime error'] -%}
                {%- set c.errores = c.errores + 1 -%}
            {%- elif estado == 'skipped' -%}
                {%- set c.omitidos = c.omitidos + 1 -%}
            {%- elif estado == 'warn' -%}
                {%- set c.avisos = c.avisos + 1 -%}
            {%- elif tipo == 'model' -%}
                {%- set c.modelos = c.modelos + 1 -%}
            {%- elif tipo == 'seed' -%}
                {%- set c.seeds = c.seeds + 1 -%}
            {%- elif tipo == 'snapshot' -%}
                {%- set c.snapshots = c.snapshots + 1 -%}
            {%- elif tipo in ['test', 'unit_test'] -%}
                {%- set c.tests = c.tests + 1 -%}
            {%- endif -%}
        {%- endfor -%}

        {{ log('==========================================================', info=True) }}
        {{ log('SiliconROI · resumen [' ~ (env_var('DBT_ENVIRONMENT', 'dev') | upper) ~ ']', info=True) }}
        {{ log('  Modelos OK:    ' ~ c.modelos, info=True) }}
        {{ log('  Seeds OK:      ' ~ c.seeds, info=True) }}
        {{ log('  Snapshots OK:  ' ~ c.snapshots, info=True) }}
        {{ log('  Tests OK:      ' ~ c.tests, info=True) }}
        {{ log('  Avisos:        ' ~ c.avisos, info=True) }}
        {{ log('  Errores:       ' ~ c.errores, info=True) }}
        {{ log('  Omitidos:      ' ~ c.omitidos, info=True) }}
        {{ log('  Incrementales (filas totales al terminar):', info=True) }}

        {%- for r in results -%}
            {%- if (r.node.resource_type | string | lower) == 'model'
                   and r.node.config.materialized == 'incremental'
                   and (r.status | string | lower) == 'success' -%}
                {%- set tabla = r.node.database ~ '.' ~ r.node.schema ~ '.' ~ (r.node.alias or r.node.name) -%}
                {%- set conteo = run_query('select count(*) from ' ~ tabla) -%}
                {{ log('    · ' ~ r.node.name ~ ': ' ~ conteo.columns[0].values()[0], info=True) }}
            {%- endif -%}
        {%- endfor -%}

        {{ log('==========================================================', info=True) }}

    {%- endif -%}
{% endmacro %}