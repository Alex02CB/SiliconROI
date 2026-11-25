## SiliconROI v1.0 · Entrega final

Versión entregada y presentada el 25/11/2026.

### Qué incluye
- **Arquitectura medallion** en Snowflake: Bronze → Staging → Silver → Gold (core, intermediate y marts), con entornos DEV y PRO.
- **23 modelos dbt**: 6 de staging, 7 de Silver y 10 de Gold, con un modelo en estrella de dos hechos (`fct_daily_prices`, `fct_benchmark_results`).
- **3 incrementales con merge** (precios en Silver y Gold, y envíos de Blender) y **3 snapshots SCD2** del catálogo.
- **Calidad**: más de 100 tests genéricos, 2 singulares, 1 unit test y freshness en los precios.
- **4 seeds** de reglas de negocio, **4 macros** y un **hook** `on-run-end` con el resumen de cada ejecución.
- **Grants** declarados en `dbt_project.yml`: la app solo lee los marts.
- **Jobs**: carga diaria DEV → PRO encadenada, reconstrucción completa y job de demo.
- **README** con la arquitectura, el modelo de datos y cómo ejecutarlo.

### Casos de uso
- `agg_value_ranking`: rendimiento por cada 100 € de CPUs y GPUs.
- `agg_profile_recommendations`: el mejor equipo por perfil profesional y presupuesto.
- `agg_price_evolution`: evolución del precio de cada producto para decidir cuándo comprar.