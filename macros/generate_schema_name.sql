{#
    generate_schema_name
    ---------------------------------------------------------------------------
    Decide el nombre del schema de cada modelo según el entorno:

      DEV  ->  schema del desarrollador + "_" + schema del modelo
               (DBT_ACAMPILLO_CATALOGO). Cada desarrollador tiene sus propias
               tablas: dos personas trabajando a la vez no se pisan.
      PRO  ->  solo el schema del modelo (CATALOGO). En PRO solo escribe el
               job, así que el prefijo no aporta nada y los nombres quedan
               limpios para quien consulta el almacén.

    El entorno llega por la variable DBT_ENVIRONMENT (dev / pro), definida en
    cada entorno de dbt Platform. Si falta, se trata como DEV: en el peor caso
    PRO tendría nombres con prefijo, que se ve enseguida y no pisa nada.

    Si un modelo no tiene schema propio, usa el del entorno (target.schema).
#}
{% macro generate_schema_name(custom_schema_name, node) -%}

    {%- set entorno = env_var('DBT_ENVIRONMENT', 'dev') | trim | lower -%}

    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- elif entorno == 'pro' -%}
        {{ custom_schema_name | trim }}
    {%- else -%}
        {{ target.schema }}_{{ custom_schema_name | trim }}
    {%- endif -%}

{%- endmacro %}