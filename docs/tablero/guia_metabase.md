# Guía del tablero en Metabase

Esta guía describe cómo conectar Metabase a la base de indicadores y cómo armar el tablero de los Ejercicios 7 y 8. Cada tarjeta lee una tabla de `data/processed/tablero.duckdb`. Esas tablas se calculan con las consultas de `sql/05_indicadores.sql`, por lo que en Metabase no se escribe SQL nuevo: cada tarjeta es una pregunta simple sobre una tabla ya calculada.

## 1. Construir la base de indicadores

Un archivo DuckDB admite un solo proceso con escritura. Por eso Metabase se detiene mientras se construye la base y se vuelve a iniciar al terminar.

```bash
docker compose stop metabase
docker compose exec lab python scripts/construir_tablero.py --anios 2024 2026
docker compose start metabase
```

Para el Ejercicio 8 se usa el mismo comando sin `--anios`, que incluye todos los años descargados. Las celdas 7.2 y 8.4 del notebook hacen lo mismo.

## 2. Conectar Metabase a DuckDB

1. Abrir http://localhost:3001 y crear la cuenta de administrador la primera vez.
2. Ir a Configuración de administrador, Bases de datos, Agregar base de datos.
3. Tipo de base de datos: DuckDB.
4. Nombre a mostrar: Taxis NY.
5. Archivo de base de datos: `/workspace/data/processed/tablero.duckdb`. Es la ruta dentro del contenedor y no la de la computadora anfitriona.
6. Activar la opción de conexión de solo lectura, read only. Así otros procesos pueden seguir abriendo el archivo.
7. Guardar. Metabase sincroniza el esquema y muestra las 13 tablas `ind_01` a `ind_13`.

Después de reconstruir la base en el Ejercicio 8, ir a la base Taxis NY y pulsar Sincronizar el esquema de la base de datos ahora, y luego Volver a escanear los valores de los campos.

## 3. Tarjetas del tablero

Cada tarjeta se crea con Nueva, Pregunta, Taxis NY y la tabla indicada. Luego se elige la visualización y los campos. El tablero se llama Viajes de Taxi de Nueva York. En las tarjetas que usan anio como eje o serie se desactiva la agrupación en intervalos y se usa escala ordinal, para que el año no aparezca con separador de miles.

| Tarjeta | Tabla | Visualización | Configuración |
| --- | --- | --- | --- |
| P1 Indicadores generales | ind_01_resumen_anual | Tabla | Todas las columnas, una fila por año |
| P1 Viajes válidos por día | ind_01_resumen_anual | Barras | Eje X anio, eje Y viajes_por_dia |
| P2 Tendencia mensual | ind_02_tendencia_mensual | Líneas | Eje X periodo por mes, eje Y viajes_por_dia, serie tipo_taxi |
| P3 Demanda por hora | ind_03_demanda_horaria | Líneas | Eje X hora, eje Y viajes_promedio_dia, serie tipo_dia |
| P4 Velocidad por hora | ind_04_velocidad_horaria | Líneas | Eje X hora, eje Y velocidad_mediana_mph, serie anio |
| P5 Día de la semana | ind_05_dia_semana | Barras | Eje X dia, eje Y viajes_promedio_dia, serie anio |
| P6 Métodos de pago | ind_06_metodo_pago | Barras apiladas al 100 % | Resumir suma de viajes por anio y metodo_pago |
| P7 Propina con tarjeta | ind_07_propina | Líneas | Eje X franja_horaria, eje Y propina_promedio_pct, serie tipo_taxi |
| P8a Zonas de origen de los amarillos | ind_08_zonas_origen | Barras horizontales | Filtros tipo_taxi igual a yellow y posicion menor o igual a 10, eje X zona, eje Y suma de viajes |
| P8b Zonas de origen de los verdes | ind_08_zonas_origen | Barras horizontales | Filtros tipo_taxi igual a green y posicion menor o igual a 10, eje X zona, eje Y suma de viajes |
| P9 Distritos de origen | ind_09_distritos | Barras horizontales | Resumir promedio de porcentaje por distrito y tipo_taxi |
| P10 Aeropuertos | ind_10_aeropuertos | Barras | Filtro aeropuerto distinto de Sin aeropuerto, eje X aeropuerto, ejes Y pct_viajes y pct_ingreso |
| P11 Participación por tipo | ind_11_participacion_tipo | Barras apiladas al 100 % | Eje X anio, eje Y viajes, serie tipo_taxi |
| P12 Calidad de datos | ind_12_calidad_datos | Barras sin apilar | Filtro clasificacion distinta de Válido, eje X anio, eje Y porcentaje, serie clasificacion |
| P13 Recargos | ind_13_cargos_mensuales | Líneas | Eje X periodo por mes, ejes Y cargo_cbd_promedio y recargo_congestion_promedio |

## 4. Organización y filtro

El tablero se organiza en tres secciones de arriba hacia abajo:

1. Resumen: tarjetas P1, P11 y P2.
2. Tiempo: P3, P4 y P5.
3. Pago, geografía y calidad: P6, P7, P8a, P8b, P9, P10, P12 y P13.

Se agrega un filtro de tablero de tipo Número llamado Año y se conecta a la columna anio de cada tarjeta. Así el tablero completo se puede ver para un año o para todos.

## 5. Evidencia

Al terminar cada ejercicio se guarda una captura del tablero completo y una captura de cada tarjeta, porque la imagen del tablero completo reduce la resolución de cada gráfico:

- Ejercicio 7, con 2024 y 2026: `docs/tablero/tablero_metabase_2024_2026.png` y las tarjetas en `docs/tablero/e7/`.
- Ejercicio 8, con los tres años: `docs/tablero/tablero_metabase_2024_2025_2026.png` y las tarjetas en `docs/tablero/e8/`.

Las tarjetas se guardan con los nombres p01a_indicadores_generales, p01b_viajes_por_dia, p02_tendencia_mensual, p03_demanda_hora, p04_velocidad_hora, p05_dia_semana, p06_metodos_pago, p07_propina, p08a_zonas_amarillos, p08b_zonas_verdes, p09_distritos, p10_aeropuertos, p11_participacion_tipo, p12_calidad_datos y p13_recargos. El notebook muestra estas capturas en las secciones 7.4 y 8.4. Como respaldo reproducible, `python scripts/graficos_tablero.py` dibuja los mismos indicadores con Matplotlib en `docs/tablero/tablero_parte1.png` y `docs/tablero/tablero_parte2.png`.
