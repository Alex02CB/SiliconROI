{#
=============================================================================
log_run_summary
=============================================================================
Hook de proyecto (on-run-end, en dbt_project.yml). Al terminar cada
ejecución escribe en el log un resumen:
  - entorno (DBT_ENVIRONMENT),
  - modelos, seeds, snapshots y tests correctos,
  - avisos, errores y nodos omitidos (por depender de uno que falló),
  - filas procesadas por cada modelo incremental en esta ejecución.

results: la lista de resultados que dbt pasa a on-run-end (un elemento por
nodo ejecutado, con su estado, su nodo y la respuesta de Snowflake).

Las filas salen de adapter_response.rows_affected. Si Snowflake no las
devuelve, se escribe "n/d" en lugar de fallar: el resumen nunca rompe un job.
No devuelve SQL: solo escribe en el log.
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
        {{ log('  Incrementales (filas procesadas en esta ejecución):', info=True) }}

        {%- for r in results -%}
            {%- if (r.node.resource_type | string | lower) == 'model'
                   and r.node.config.materialized == 'incremental' -%}
                {%- set respuesta = r.adapter_response -%}
                {%- set filas = respuesta.get('rows_affected') if respuesta is mapping else none -%}
                {{ log('    · ' ~ r.node.name ~ ': ' ~ (filas if filas is not none else 'n/d'), info=True) }}
            {%- endif -%}
        {%- endfor -%}

        {{ log('==========================================================', info=True) }}

    {%- endif -%}
{% endmacro %}