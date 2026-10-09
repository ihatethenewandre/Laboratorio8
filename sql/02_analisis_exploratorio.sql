-- Capas de preparación y Ejercicio 4. Análisis exploratorio con DuckDB.
--
-- Las tres primeras sentencias construyen las capas reutilizadas por el resto del
-- laboratorio, todas sobre la vista normalizada "viajes" que genera scripts/taxis.py
-- y que lee directamente los archivos Parquet:
--   zonas            tabla pequeña con la tabla de zonas de la TLC
--   viajes_calidad   vista con etiquetas, variables derivadas y reglas de calidad
--   viajes_validos   vista con los viajes que cumplen todas las reglas, unida a zonas
-- Parámetro: {ruta_zonas} ruta del archivo taxi_zone_lookup.csv

-- id: crear_tabla_zonas
-- ejercicio: preparación
-- objetivo: Cargar la tabla de zonas de taxi de la TLC para traducir los identificadores de zona a distrito y nombre.
-- fuentes: data/raw/zonas/taxi_zone_lookup.csv
-- decision: Es la única tabla materializada de la capa de análisis porque tiene 265 filas y se une con cada consulta por zona.
CREATE OR REPLACE TABLE zonas AS
SELECT
    CAST(LocationID AS INTEGER) AS zona,
    Borough AS distrito,
    Zone AS nombre_zona,
    service_zone AS zona_servicio
FROM read_csv('{ruta_zonas}', header = true);

-- id: crear_vista_calidad
-- ejercicio: preparación
-- objetivo: Agregar a cada viaje etiquetas legibles, variables de calendario, velocidad y las reglas de calidad definidas en el Ejercicio 3.
-- fuentes: vista viajes
-- decision: Ningún registro se elimina de los archivos; las reglas solo marcan el motivo de exclusión para poder contar y justificar cada descarte.
CREATE OR REPLACE VIEW viajes_calidad AS
WITH base AS (
    SELECT
        *,
        CAST(fecha_recogida AS DATE) AS fecha,
        hour(fecha_recogida) AS hora,
        isodow(fecha_recogida) AS dia_semana,
        CASE WHEN distancia_millas > 0 AND duracion_min > 0
             THEN distancia_millas / (duracion_min / 60.0) END AS velocidad_mph
    FROM viajes
)
SELECT
    *,
    CASE WHEN dia_semana IN (6, 7) THEN 'Fin de semana' ELSE 'Entre semana' END AS tipo_dia,
    CASE
        WHEN hora BETWEEN 0 AND 5 THEN '1 Madrugada 0 a 5'
        WHEN hora BETWEEN 6 AND 9 THEN '2 Mañana 6 a 9'
        WHEN hora BETWEEN 10 AND 15 THEN '3 Mediodía 10 a 15'
        WHEN hora BETWEEN 16 AND 19 THEN '4 Tarde 16 a 19'
        ELSE '5 Noche 20 a 23'
    END AS franja_horaria,
    CASE tipo_pago
        WHEN 1 THEN 'Tarjeta de crédito'
        WHEN 2 THEN 'Efectivo'
        WHEN 3 THEN 'Sin cargo'
        WHEN 4 THEN 'Disputa'
        WHEN 6 THEN 'Viaje anulado'
        ELSE 'Sin registro'
    END AS metodo_pago,
    CASE codigo_tarifa
        WHEN 1 THEN 'Estándar'
        WHEN 2 THEN 'JFK'
        WHEN 3 THEN 'Newark'
        WHEN 4 THEN 'Nassau o Westchester'
        WHEN 5 THEN 'Negociada'
        WHEN 6 THEN 'Viaje grupal'
        ELSE 'Desconocida'
    END AS tarifa_aplicada,
    CASE
        WHEN anio_archivo IS NULL OR year(fecha_recogida) <> anio_archivo OR month(fecha_recogida) <> mes_archivo
            THEN 'Fecha fuera del mes del archivo'
        WHEN duracion_min IS NULL OR duracion_min <= 0 THEN 'Duración nula o negativa'
        WHEN duracion_min > 360 THEN 'Duración mayor a 6 horas'
        WHEN distancia_millas IS NULL OR distancia_millas <= 0 THEN 'Distancia cero'
        WHEN distancia_millas > 200 THEN 'Distancia mayor a 200 millas'
        WHEN velocidad_mph > 80 THEN 'Velocidad mayor a 80 mph'
        WHEN tarifa IS NULL OR total IS NULL OR tarifa < 0 OR total < 0 THEN 'Monto negativo o ajuste'
        WHEN total > 1000 THEN 'Total mayor a 1000 dólares'
        ELSE NULL
    END AS motivo_exclusion
FROM base;

-- id: crear_vista_validos
-- ejercicio: preparación
-- objetivo: Definir la vista de viajes válidos con distrito y nombre de las zonas de origen y destino.
-- fuentes: vista viajes_calidad y tabla zonas
-- decision: Todo el análisis posterior usa esta vista, de modo que las reglas de calidad se aplican igual en el análisis, el benchmark y el tablero.
CREATE OR REPLACE VIEW viajes_validos AS
SELECT
    v.* EXCLUDE (motivo_exclusion),
    coalesce(zo.distrito, 'Desconocido') AS distrito_origen,
    coalesce(zo.nombre_zona, 'Desconocida') AS nombre_origen,
    coalesce(zd.distrito, 'Desconocido') AS distrito_destino,
    coalesce(zd.nombre_zona, 'Desconocida') AS nombre_destino,
    CASE
        WHEN v.zona_origen = 132 OR v.zona_destino = 132 THEN 'JFK'
        WHEN v.zona_origen = 138 OR v.zona_destino = 138 THEN 'LaGuardia'
        WHEN v.zona_origen = 1 OR v.zona_destino = 1 THEN 'Newark'
        ELSE 'Sin aeropuerto'
    END AS aeropuerto,
    CASE WHEN v.tipo_pago = 1 AND v.tarifa > 0 THEN 100.0 * v.propina / v.tarifa END AS propina_pct
FROM viajes_calidad v
LEFT JOIN zonas zo ON v.zona_origen = zo.zona
LEFT JOIN zonas zd ON v.zona_destino = zd.zona
WHERE v.motivo_exclusion IS NULL;

-- id: e4_calidad_exclusiones
-- ejercicio: 4
-- objetivo: Pregunta 1. Qué proporción de registros incumple alguna regla de calidad y por qué motivo, en cada tipo de taxi.
-- fuentes: vista viajes_calidad sobre los archivos de 2026
-- decision: Si las exclusiones son una fracción pequeña del total, el análisis sobre viajes válidos representa bien al conjunto; los motivos dominantes se reportan como limitaciones.
SELECT
    tipo_taxi,
    coalesce(motivo_exclusion, 'Válido') AS clasificacion,
    count(*) AS registros,
    round(100.0 * count(*) / sum(count(*)) OVER (PARTITION BY tipo_taxi), 3) AS porcentaje
FROM viajes_calidad
GROUP BY tipo_taxi, clasificacion
ORDER BY tipo_taxi DESC, registros DESC;

-- id: e4_viajes_mensuales
-- ejercicio: 4
-- objetivo: Pregunta 2. Cómo evoluciona el número de viajes y el ingreso de cada mes por tipo de taxi.
-- fuentes: vista viajes_validos
-- decision: Los meses con menos días o con eventos particulares se comparan con viajes promedio por día y no solo con el total mensual.
SELECT
    tipo_taxi,
    anio_archivo AS anio,
    mes_archivo AS mes,
    count(*) AS viajes,
    round(count(*) / count(DISTINCT fecha), 0) AS viajes_por_dia,
    round(sum(total) / 1e6, 3) AS ingreso_millones,
    round(avg(total), 2) AS total_promedio
FROM viajes_validos
GROUP BY ALL
ORDER BY tipo_taxi DESC, anio, mes;

-- id: e4_patron_horario
-- ejercicio: 4
-- objetivo: Pregunta 3. En qué horas y tipo de día se concentra la demanda y cómo cambia la velocidad del tráfico.
-- fuentes: vista viajes_validos
-- decision: El promedio diario por hora permite comparar entre semana y fin de semana aunque tengan distinto número de días.
SELECT
    tipo_dia,
    hora,
    count(*) AS viajes,
    round(count(*) / count(DISTINCT fecha), 1) AS viajes_por_dia,
    round(median(duracion_min), 1) AS duracion_mediana_min,
    round(median(velocidad_mph), 1) AS velocidad_mediana_mph
FROM viajes_validos
GROUP BY ALL
ORDER BY tipo_dia, hora;

-- id: e4_caracteristicas_tipo
-- ejercicio: 4
-- objetivo: Pregunta 4. En qué se diferencian los viajes de taxis amarillos y verdes en distancia, duración, pasajeros y monto.
-- fuentes: vista viajes_validos
-- decision: Se reportan medianas y percentiles porque las distribuciones de distancia y monto son asimétricas y el promedio se ve arrastrado por los viajes largos.
SELECT
    tipo_taxi,
    count(*) AS viajes,
    round(avg(pasajeros), 2) AS pasajeros_promedio,
    round(quantile_cont(distancia_millas, 0.25), 2) AS distancia_p25,
    round(median(distancia_millas), 2) AS distancia_mediana,
    round(quantile_cont(distancia_millas, 0.75), 2) AS distancia_p75,
    round(quantile_cont(distancia_millas, 0.99), 2) AS distancia_p99,
    round(median(duracion_min), 1) AS duracion_mediana,
    round(quantile_cont(duracion_min, 0.99), 1) AS duracion_p99,
    round(median(total), 2) AS total_mediano,
    round(quantile_cont(total, 0.99), 2) AS total_p99,
    round(100.0 * count(*) FILTER (WHERE aeropuerto <> 'Sin aeropuerto') / count(*), 2) AS pct_aeropuerto
FROM viajes_validos
GROUP BY ALL
ORDER BY tipo_taxi DESC;

-- id: e4_distribucion_distancia
-- ejercicio: 4
-- objetivo: Pregunta 5. Cómo se distribuyen las distancias de los viajes en intervalos de una milla por tipo de taxi.
-- fuentes: vista viajes_validos
-- decision: La distribución por intervalos permite ver la cola de viajes largos que el resumen estadístico solo insinúa.
SELECT
    tipo_taxi,
    least(floor(distancia_millas), 30) AS millas,
    count(*) AS viajes,
    round(100.0 * count(*) / sum(count(*)) OVER (PARTITION BY tipo_taxi), 3) AS porcentaje
FROM viajes_validos
GROUP BY tipo_taxi, millas
ORDER BY tipo_taxi DESC, millas;

-- id: e4_pago_propina
-- ejercicio: 4
-- objetivo: Pregunta 6. Cómo se reparten los métodos de pago y qué porcentaje de propina se registra en cada uno.
-- fuentes: vista viajes_validos
-- decision: La TLC solo registra propinas pagadas con tarjeta, por lo que el porcentaje de propina se calcula sobre pagos con tarjeta.
SELECT
    tipo_taxi,
    metodo_pago,
    count(*) AS viajes,
    round(100.0 * count(*) / sum(count(*)) OVER (PARTITION BY tipo_taxi), 2) AS porcentaje_viajes,
    round(avg(total), 2) AS total_promedio,
    round(100.0 * count(*) FILTER (WHERE propina > 0) / count(*), 2) AS pct_con_propina,
    round(median(100.0 * propina / nullif(tarifa, 0)), 2) AS propina_mediana_pct
FROM viajes_validos
GROUP BY tipo_taxi, metodo_pago
ORDER BY tipo_taxi DESC, viajes DESC;

-- id: e4_zonas_origen
-- ejercicio: 4
-- objetivo: Pregunta 7. Desde qué zonas y distritos sale la mayor parte de los viajes de cada tipo de taxi.
-- fuentes: vista viajes_validos y tabla zonas
-- decision: Se comparan las diez zonas principales de cada tipo para verificar la separación geográfica de los servicios.
SELECT *
FROM (
    SELECT
        tipo_taxi,
        nombre_origen AS zona,
        distrito_origen AS distrito,
        count(*) AS viajes,
        round(100.0 * count(*) / sum(count(*)) OVER (PARTITION BY tipo_taxi), 2) AS porcentaje,
        row_number() OVER (PARTITION BY tipo_taxi ORDER BY count(*) DESC) AS posicion
    FROM viajes_validos
    GROUP BY tipo_taxi, nombre_origen, distrito_origen
)
WHERE posicion <= 10
ORDER BY tipo_taxi DESC, posicion;

-- id: e4_aeropuertos
-- ejercicio: 4
-- objetivo: Pregunta 8. Cuánto pesan los viajes de aeropuerto y en qué se diferencian del resto.
-- fuentes: vista viajes_validos
-- decision: Los viajes de aeropuerto se analizan aparte porque tienen tarifa fija o recargos propios y elevan los promedios generales.
SELECT
    tipo_taxi,
    aeropuerto,
    count(*) AS viajes,
    round(100.0 * count(*) / sum(count(*)) OVER (PARTITION BY tipo_taxi), 2) AS porcentaje,
    round(median(distancia_millas), 2) AS distancia_mediana,
    round(median(duracion_min), 1) AS duracion_mediana,
    round(median(total), 2) AS total_mediano
FROM viajes_validos
GROUP BY tipo_taxi, aeropuerto
ORDER BY tipo_taxi DESC, viajes DESC;

-- id: e4_atipicos_tarifa
-- ejercicio: 4
-- objetivo: Pregunta 9. Qué viajes válidos tienen una tarifa por milla atípica según el criterio de rango intercuartílico.
-- fuentes: vista viajes_validos
-- decision: Los viajes fuera del rango intercuartílico no se eliminan porque pueden ser legítimos, como tarifas negociadas o viajes muy cortos; se reporta su proporción.
WITH tarifas AS (
    SELECT tipo_taxi, tarifa / distancia_millas AS tarifa_por_milla
    FROM viajes_validos
    WHERE distancia_millas >= 0.1
),
limites AS (
    SELECT
        tipo_taxi,
        quantile_cont(tarifa_por_milla, 0.25) AS q1,
        quantile_cont(tarifa_por_milla, 0.75) AS q3
    FROM tarifas
    GROUP BY ALL
)
SELECT
    t.tipo_taxi,
    round(l.q1, 2) AS q1,
    round(l.q3, 2) AS q3,
    round(l.q3 + 1.5 * (l.q3 - l.q1), 2) AS limite_superior,
    count(*) AS viajes,
    count(*) FILTER (WHERE t.tarifa_por_milla > l.q3 + 1.5 * (l.q3 - l.q1)) AS atipicos_altos,
    count(*) FILTER (WHERE t.tarifa_por_milla < l.q1 - 1.5 * (l.q3 - l.q1)) AS atipicos_bajos,
    round(100.0 * count(*) FILTER (WHERE t.tarifa_por_milla > l.q3 + 1.5 * (l.q3 - l.q1)
                                     OR t.tarifa_por_milla < l.q1 - 1.5 * (l.q3 - l.q1)) / count(*), 2) AS pct_atipicos
FROM tarifas t
JOIN limites l USING (tipo_taxi)
GROUP BY ALL
ORDER BY t.tipo_taxi DESC;
