{#
    generate_schema_name
    ---------------------------------------------------------------------------
    Sustituye la regla por defecto de dbt para nombrar los schemas.

    Por defecto: schema del entorno + "_" + schema del modelo
                 (DBT_ACAMPILLO_BLENDER_OPENDATA).
    Con esta macro: solo el schema del modelo (BLENDER_OPENDATA).

    Por qué: cada entorno tiene sus propias databases (SILICONROI_DEV_*,
    SILICONROI_PRO_*), así que el prefijo no hace falta para separarlos, y en
    PRO los schemas quedan con nombres limpios: SILICONROI_PRO_SILVER_DB.CATALOGO.

    Riesgo que asumimos (Día 04): sin prefijo, dos desarrolladores que
    compartieran la database de DEV pisarían las mismas tablas. En este
    proyecto las databases de DEV son de un solo desarrollador.

    Si un modelo no tiene schema propio, usa el del entorno (target.schema).
#}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}