-- Ejercicios 7 y 8. Indicadores del tablero.
--
-- Cada bloque define una tabla de la base data/processed/tablero.duckdb, que Metabase
-- abre en modo de solo lectura. scripts/construir_tablero.py ejecuta cada consulta como
-- CREATE TABLE <id> AS <consulta> sobre las vistas viajes_validos y viajes_calidad, por lo
-- que al descargar un año nuevo basta con reconstruir la base para actualizar el tablero.
-- Todas las tablas incluyen el año para que el tablero pueda filtrar y comparar años.

-- id: ind_01_resumen_anual
-- ejercicio: 7
-- indicador: Volumen, ingreso y ticket promedio por año
-- pregunta: P1. ¿Cuántos viajes válidos e ingresos genera el servicio de taxis cada año y cuál es el monto promedio por viaje?
-- objetivo: Resumir en tarjetas numéricas los indicadores generales de cada año.
-- fuentes: vista viajes_validos
-- justificacion: Es el punto de partida del tablero, da la escala del servicio y permite comparar años con viajes e ingreso por día aunque 2026 esté incompleto.
SELECT
    anio_archivo AS anio,
    count(DISTINCT mes_archivo) AS meses,
    count(*) AS viajes,
    round(count(*) / count(DISTINCT fecha), 0) AS viajes_por_dia,
    round(sum(total), 2) AS ingreso_total,
    round(sum(total) / count(DISTINCT fecha), 2) AS ingreso_por_dia,
    round(avg(total), 2) AS ticket_promedio,
    round(median(distancia_millas), 2) AS distancia_mediana,
    round(median(duracion_min), 2) AS duracion_mediana
FROM viajes_validos
GROUP BY ALL
ORDER BY anio;

-- id: ind_02_tendencia_mensual
-- ejercicio: 7
-- indicador: Viajes por día en cada mes y tipo de taxi
-- pregunta: P2. ¿Cómo evoluciona mes a mes la demanda de taxis amarillos y verdes?
-- objetivo: Construir la serie mensual de viajes por día e ingreso por tipo de taxi.
-- fuentes: vista viajes_validos
-- justificacion: La serie temporal muestra estacionalidad y tendencia; se usa viajes por día para que los meses de distinta duración sean comparables.
SELECT
    make_date(anio_archivo, mes_archivo, 1) AS periodo,
    anio_archivo AS anio,
    mes_archivo AS mes,
    tipo_taxi,
    count(*) AS viajes,
    round(count(*) / count(DISTINCT fecha), 1) AS viajes_por_dia,
    round(sum(total), 2) AS ingreso
FROM viajes_validos
GROUP BY ALL
ORDER BY periodo, tipo_taxi DESC;

-- id: ind_03_demanda_horaria
-- ejercicio: 7
-- indicador: Viajes promedio por hora y tipo de día
-- pregunta: P3. ¿En qué horas del día se concentra la demanda y cómo cambia entre semana y fin de semana?
-- objetivo: Calcular los viajes promedio por día en cada hora, separando días entre semana y fines de semana.
-- fuentes: vista viajes_validos
-- justificacion: Identifica horas pico, útil para asignar flota; el promedio por día evita que entre semana domine solo por tener más días.
SELECT
    anio_archivo AS anio,
    tipo_dia,
    hora,
    count(*) AS viajes,
    round(count(*) / count(DISTINCT fecha), 1) AS viajes_promedio_dia
FROM viajes_validos
GROUP BY ALL
ORDER BY anio, tipo_dia, hora;

-- id: ind_04_velocidad_horaria
-- ejercicio: 7
-- indicador: Velocidad y duración mediana por hora
-- pregunta: P4. ¿En qué horas el tráfico hace más lentos los viajes?
-- objetivo: Calcular la velocidad mediana y la duración mediana de los viajes en cada hora.
-- fuentes: vista viajes_validos
-- justificacion: La velocidad es un indicador indirecto de congestión; se usa la mediana por ser robusta a registros extremos.
SELECT
    anio_archivo AS anio,
    hora,
    round(median(velocidad_mph), 2) AS velocidad_mediana_mph,
    round(median(duracion_min), 2) AS duracion_mediana_min,
    round(median(distancia_millas), 2) AS distancia_mediana
FROM viajes_validos
GROUP BY ALL
ORDER BY anio, hora;

-- id: ind_05_dia_semana
-- ejercicio: 7
-- indicador: Viajes promedio y ticket por día de la semana
-- pregunta: P5. ¿Qué días de la semana tienen más viajes y viajes más caros?
-- objetivo: Calcular viajes promedio por fecha y monto promedio para cada día de la semana.
-- fuentes: vista viajes_validos
-- justificacion: Complementa el perfil horario y muestra si el fin de semana cambia el tipo de viaje además del volumen.
SELECT
    anio_archivo AS anio,
    dia_semana,
    CASE dia_semana WHEN 1 THEN '1 Lunes' WHEN 2 THEN '2 Martes' WHEN 3 THEN '3 Miércoles'
        WHEN 4 THEN '4 Jueves' WHEN 5 THEN '5 Viernes' WHEN 6 THEN '6 Sábado' ELSE '7 Domingo' END AS dia,
    round(count(*) / count(DISTINCT fecha), 1) AS viajes_promedio_dia,
    round(avg(total), 2) AS ticket_promedio,
    round(median(distancia_millas), 2) AS distancia_mediana
FROM viajes_validos
GROUP BY ALL
ORDER BY anio, dia_semana;

-- id: ind_06_metodo_pago
-- ejercicio: 7
-- indicador: Participación de métodos de pago
-- pregunta: P6. ¿Cómo pagan los pasajeros y cómo cambia la participación de cada método entre años?
-- objetivo: Calcular la participación de cada método de pago por año y tipo de taxi.
-- fuentes: vista viajes_validos
-- justificacion: El método de pago condiciona la propina registrada y refleja la adopción de pagos electrónicos.
SELECT
    anio_archivo AS anio,
    tipo_taxi,
    metodo_pago,
    count(*) AS viajes,
    round(100.0 * count(*) / sum(count(*)) OVER (PARTITION BY anio_archivo, tipo_taxi), 2) AS porcentaje
FROM viajes_validos
GROUP BY anio_archivo, tipo_taxi, metodo_pago
ORDER BY anio, tipo_taxi DESC, viajes DESC;

-- id: ind_07_propina
-- ejercicio: 7
-- indicador: Porcentaje de propina con tarjeta por franja horaria
-- pregunta: P7. ¿Qué porcentaje de propina dejan los pasajeros que pagan con tarjeta y cómo varía por franja horaria y tipo de taxi?
-- objetivo: Calcular el porcentaje promedio y mediano de propina sobre la tarifa en pagos con tarjeta.
-- fuentes: vista viajes_validos
-- justificacion: La propina es parte relevante del ingreso del conductor y solo es observable en pagos con tarjeta, lo que se respeta en el cálculo.
SELECT
    anio_archivo AS anio,
    tipo_taxi,
    franja_horaria,
    count(*) AS viajes_tarjeta,
    round(avg(propina_pct), 2) AS propina_promedio_pct,
    round(median(propina_pct), 2) AS propina_mediana_pct,
    round(100.0 * count(*) FILTER (WHERE propina > 0) / count(*), 2) AS pct_con_propina
FROM viajes_validos
WHERE tipo_pago = 1 AND tarifa > 0
GROUP BY ALL
ORDER BY anio, tipo_taxi DESC, franja_horaria;

-- id: ind_08_zonas_origen
-- ejercicio: 7
-- indicador: Zonas de origen con más viajes
-- pregunta: P8. ¿Desde qué zonas sale la mayor cantidad de viajes de cada tipo de taxi?
-- objetivo: Obtener las 15 zonas de origen con más viajes por año y tipo de taxi.
-- fuentes: vista viajes_validos y tabla zonas
-- justificacion: Muestra la concentración geográfica de la demanda y la diferencia de cobertura entre taxis amarillos y verdes.
SELECT *
FROM (
    SELECT
        anio_archivo AS anio,
        tipo_taxi,
        nombre_origen AS zona,
        distrito_origen AS distrito,
        count(*) AS viajes,
        round(100.0 * count(*) / sum(count(*)) OVER (PARTITION BY anio_archivo, tipo_taxi), 2) AS porcentaje,
        row_number() OVER (PARTITION BY anio_archivo, tipo_taxi ORDER BY count(*) DESC) AS posicion
    FROM viajes_validos
    GROUP BY anio_archivo, tipo_taxi, nombre_origen, distrito_origen
)
WHERE posicion <= 15
ORDER BY anio, tipo_taxi DESC, posicion;

-- id: ind_09_distritos
-- ejercicio: 7
-- indicador: Viajes e ingreso por distrito de origen
-- pregunta: P9. ¿Cómo se reparten los viajes y el ingreso entre los distritos de la ciudad?
-- objetivo: Calcular viajes, ingreso y ticket promedio por distrito de origen y tipo de taxi.
-- fuentes: vista viajes_validos y tabla zonas
-- justificacion: Resume la geografía a un nivel legible y evidencia la especialización de los taxis verdes fuera del centro de Manhattan.
SELECT
    anio_archivo AS anio,
    tipo_taxi,
    distrito_origen AS distrito,
    count(*) AS viajes,
    round(100.0 * count(*) / sum(count(*)) OVER (PARTITION BY anio_archivo, tipo_taxi), 2) AS porcentaje,
    round(sum(total), 2) AS ingreso,
    round(avg(total), 2) AS ticket_promedio
FROM viajes_validos
GROUP BY anio_archivo, tipo_taxi, distrito_origen
ORDER BY anio, tipo_taxi DESC, viajes DESC;

-- id: ind_10_aeropuertos
-- ejercicio: 7
-- indicador: Viajes de aeropuerto
-- pregunta: P10. ¿Qué peso tienen los viajes hacia o desde aeropuertos y cuánto más cuestan que un viaje urbano?
-- objetivo: Comparar viajes, participación, monto y duración de los viajes con JFK, LaGuardia, Newark y sin aeropuerto.
-- fuentes: vista viajes_validos
-- justificacion: Los aeropuertos son pocos viajes pero de alto valor, por lo que explican parte importante del ingreso.
SELECT
    anio_archivo AS anio,
    aeropuerto,
    count(*) AS viajes,
    round(100.0 * count(*) / sum(count(*)) OVER (PARTITION BY anio_archivo), 2) AS pct_viajes,
    round(100.0 * sum(total) / sum(sum(total)) OVER (PARTITION BY anio_archivo), 2) AS pct_ingreso,
    round(avg(total), 2) AS ticket_promedio,
    round(median(duracion_min), 1) AS duracion_mediana
FROM viajes_validos
GROUP BY anio_archivo, aeropuerto
ORDER BY anio, viajes DESC;

-- id: ind_11_participacion_tipo
-- ejercicio: 7
-- indicador: Participación de taxis amarillos y verdes
-- pregunta: P11. ¿Qué participación tienen los taxis verdes frente a los amarillos en viajes e ingreso y cómo cambia en el tiempo?
-- objetivo: Calcular viajes, ingreso y participación por tipo de taxi y año.
-- fuentes: vista viajes_validos
-- justificacion: Permite seguir la evolución relativa de ambos servicios, que operan con reglas y zonas distintas.
SELECT
    anio_archivo AS anio,
    tipo_taxi,
    count(*) AS viajes,
    round(100.0 * count(*) / sum(count(*)) OVER (PARTITION BY anio_archivo), 2) AS pct_viajes,
    round(sum(total), 2) AS ingreso,
    round(100.0 * sum(total) / sum(sum(total)) OVER (PARTITION BY anio_archivo), 2) AS pct_ingreso,
    round(avg(total), 2) AS ticket_promedio
FROM viajes_validos
GROUP BY anio_archivo, tipo_taxi
ORDER BY anio, tipo_taxi DESC;

-- id: ind_12_calidad_datos
-- ejercicio: 7
-- indicador: Proporción de registros excluidos por regla de calidad
-- pregunta: P12. ¿Qué proporción de los registros publicados no es utilizable y por qué motivo?
-- objetivo: Contar los registros válidos y excluidos por motivo, año y tipo de taxi.
-- fuentes: vista viajes_calidad
-- justificacion: Hace visible la confiabilidad de los demás indicadores y documenta cuántos registros se descartan en cada año.
SELECT
    anio_archivo AS anio,
    tipo_taxi,
    coalesce(motivo_exclusion, 'Válido') AS clasificacion,
    count(*) AS registros,
    round(100.0 * count(*) / sum(count(*)) OVER (PARTITION BY anio_archivo, tipo_taxi), 3) AS porcentaje
FROM viajes_calidad
GROUP BY anio_archivo, tipo_taxi, clasificacion
ORDER BY anio, tipo_taxi DESC, registros DESC;

-- id: ind_13_cargos_mensuales
-- ejercicio: 7
-- indicador: Recargos promedio por mes
-- pregunta: P13. ¿Cómo cambian los recargos que paga el pasajero, en particular el cargo de congestión CBD?
-- objetivo: Calcular por mes el monto promedio de cada recargo y el porcentaje de viajes con cargo CBD.
-- fuentes: vista viajes_validos
-- justificacion: Los recargos explican cambios en el total pagado que no se deben a la tarifa; el cargo CBD solo aparece en los archivos desde 2025.
SELECT
    make_date(anio_archivo, mes_archivo, 1) AS periodo,
    anio_archivo AS anio,
    round(avg(coalesce(cargo_cbd, 0)), 3) AS cargo_cbd_promedio,
    round(100.0 * count(*) FILTER (WHERE cargo_cbd > 0) / count(*), 2) AS pct_con_cargo_cbd,
    round(avg(recargo_congestion), 3) AS recargo_congestion_promedio,
    round(avg(total - tarifa - propina), 2) AS cargos_no_tarifa_promedio,
    round(avg(tarifa), 2) AS tarifa_promedio,
    round(avg(total), 2) AS total_promedio
FROM viajes_validos
GROUP BY ALL
ORDER BY periodo;
