-- Ejercicio 6. Consultas del benchmark Parquet frente a tabla DuckDB.
--
-- Cada consulta se ejecuta dos veces por volumen de datos, cambiando únicamente la fuente:
--   {fuente} = parquet_vN  vista normalizada que lee los archivos Parquet en cada ejecución
--   {fuente} = tabla_vN    tabla DuckDB materializada a partir de esa misma vista
-- Como la vista y la tabla tienen las mismas columnas y filas, ambas estrategias reciben
-- exactamente la misma consulta y devuelven el mismo resultado.

-- id: b1_conteo_total
-- ejercicio: 6
-- objetivo: Contar todos los registros, la consulta más simple posible, que en Parquet puede resolverse con metadatos.
-- fuentes: {fuente}
-- decision: Mide el costo mínimo de abrir la fuente.
SELECT count(*) AS registros
FROM {fuente};

-- id: b2_agregado_mensual
-- ejercicio: 6
-- objetivo: Agregar viajes, ingreso y distancia por tipo de taxi, año y mes, como en el análisis temporal.
-- fuentes: {fuente}
-- decision: Representa las consultas de tendencia que leen pocas columnas de todas las filas.
SELECT
    tipo_taxi,
    year(fecha_recogida) AS anio,
    month(fecha_recogida) AS mes,
    count(*) AS viajes,
    sum(total) AS ingreso,
    avg(distancia_millas) AS distancia_promedio
FROM {fuente}
GROUP BY ALL
ORDER BY ALL;

-- id: b3_filtro_selectivo
-- ejercicio: 6
-- objetivo: Filtrar los viajes que salen de los aeropuertos con más de 10 millas y resumirlos por aeropuerto.
-- fuentes: {fuente}
-- decision: Representa consultas con filtros muy selectivos, donde las estadísticas por grupo de filas permiten saltar datos.
SELECT
    zona_origen,
    count(*) AS viajes,
    avg(total) AS total_promedio,
    avg(duracion_min) AS duracion_promedio
FROM {fuente}
WHERE zona_origen IN (1, 132, 138)
  AND distancia_millas > 10
GROUP BY ALL
ORDER BY viajes DESC;

-- id: b4_patron_horario
-- ejercicio: 6
-- objetivo: Calcular viajes y duración mediana por día de la semana y hora.
-- fuentes: {fuente}
-- decision: Representa agregaciones con muchas combinaciones de grupo y una mediana, que exigen ordenar valores.
SELECT
    isodow(fecha_recogida) AS dia_semana,
    hour(fecha_recogida) AS hora,
    count(*) AS viajes,
    median(duracion_min) AS duracion_mediana
FROM {fuente}
GROUP BY ALL
ORDER BY ALL;

-- id: b5_percentiles
-- ejercicio: 6
-- objetivo: Calcular percentiles de distancia y total por tipo de taxi y método de pago.
-- fuentes: {fuente}
-- decision: Representa el análisis de distribuciones, la operación más costosa en memoria del exploratorio.
SELECT
    tipo_taxi,
    tipo_pago,
    quantile_cont(distancia_millas, [0.25, 0.5, 0.75, 0.99]) AS distancia_percentiles,
    quantile_cont(total, [0.25, 0.5, 0.75, 0.99]) AS total_percentiles
FROM {fuente}
GROUP BY ALL
ORDER BY ALL;

-- id: b6_union_zonas
-- ejercicio: 6
-- objetivo: Unir los viajes con la tabla de zonas y resumir viajes e ingreso por distrito de origen y destino.
-- fuentes: {fuente} y tabla zonas
-- decision: Representa las consultas que combinan los viajes con otra tabla, como las del tablero por zona.
SELECT
    zo.distrito AS distrito_origen,
    zd.distrito AS distrito_destino,
    count(*) AS viajes,
    sum(v.total) AS ingreso
FROM {fuente} v
JOIN zonas zo ON v.zona_origen = zo.zona
JOIN zonas zd ON v.zona_destino = zd.zona
GROUP BY ALL
ORDER BY viajes DESC;
