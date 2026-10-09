#!/usr/bin/env python3
"""Evidencia estatica del tablero de indicadores.

Lee las tablas de data/processed/tablero.duckdb, las mismas que consume Metabase, y dibuja
cada indicador en un panel de matplotlib. Sirve como evidencia reproducible del tablero y
como respaldo cuando Metabase no esta disponible.

Uso:
    python scripts/graficos_tablero.py      guarda docs/tablero/tablero_parte1.png y tablero_parte2.png
"""

import sys

import matplotlib

import taxis

AMARILLO = "#D99A00"
VERDE = "#2E8B57"
COLORES_TIPO = {"yellow": AMARILLO, "green": VERDE}
NOMBRES_TIPO = {"yellow": "Amarillos", "green": "Verdes"}
COLORES_ANIO = ["#4C72B0", "#C44E52", "#55A868", "#8172B2", "#937860"]
DIAS = ["Lun", "Mar", "Mié", "Jue", "Vie", "Sáb", "Dom"]


def leer_indicadores(base=taxis.BASE_TABLERO):
    """Devuelve un diccionario con cada tabla de indicadores como DataFrame."""
    con = taxis.conectar(base, solo_lectura=True)
    try:
        tablas = [fila[0] for fila in con.execute("SHOW TABLES").fetchall() if fila[0].startswith("ind_")]
        return {tabla: con.execute(f"SELECT * FROM {tabla}").df() for tabla in sorted(tablas)}
    finally:
        con.close()


def color_anio(anios, anio):
    return COLORES_ANIO[sorted(anios).index(anio) % len(COLORES_ANIO)]


def dibujar_tablero(indicadores):
    """Construye las dos figuras del tablero y devuelve una lista de pares figura y descripcion."""
    import matplotlib.pyplot as plt
    import matplotlib.ticker as mticker

    ind = indicadores
    anios = sorted(ind["ind_01_resumen_anual"]["anio"].unique())
    ultimo = max(anios)
    texto_anios = ", ".join(map(str, anios))
    miles = mticker.FuncFormatter(lambda x, _: f"{x:,.0f}")

    figura1, ejes = plt.subplots(2, 3, figsize=(18, 10))
    figura1.suptitle(f"Tablero de viajes de taxi de Nueva York, demanda y tiempos, años {texto_anios}", fontsize=14)

    # P1 viajes por dia y ticket promedio por anio
    eje = ejes[0, 0]
    resumen = ind["ind_01_resumen_anual"]
    barras = eje.bar(resumen["anio"].astype(str), resumen["viajes_por_dia"],
                     color=[color_anio(anios, a) for a in resumen["anio"]])
    for barra, ticket, meses in zip(barras, resumen["ticket_promedio"], resumen["meses"]):
        eje.annotate(f"ticket {ticket:,.2f} USD\n{meses} meses", (barra.get_x() + barra.get_width() / 2, barra.get_height()),
                     ha="center", va="bottom", fontsize=9)
    eje.set_title("P1. Viajes válidos por día y ticket promedio")
    eje.set_ylabel("Viajes por día")
    eje.yaxis.set_major_formatter(miles)
    eje.margins(y=0.2)

    # P2 serie mensual de viajes por dia con un eje para cada tipo de taxi
    eje = ejes[0, 1]
    serie = ind["ind_02_tendencia_mensual"]
    amarillos = serie[serie["tipo_taxi"] == "yellow"]
    verdes = serie[serie["tipo_taxi"] == "green"]
    eje_verde = eje.twinx()
    # cada anio se dibuja como un tramo separado para no unir con una linea los anios no consecutivos
    for anio in anios:
        tramo = amarillos[amarillos["anio"] == anio]
        eje.plot(tramo["periodo"], tramo["viajes_por_dia"], color=AMARILLO, marker="o", ms=3)
        tramo = verdes[verdes["anio"] == anio]
        eje_verde.plot(tramo["periodo"], tramo["viajes_por_dia"], color=VERDE, marker="o", ms=3)
    eje.set_title("P2. Viajes por día en cada mes")
    eje.set_ylabel("Amarillos, viajes por día", color=AMARILLO)
    eje_verde.set_ylabel("Verdes, viajes por día", color=VERDE)
    eje.yaxis.set_major_formatter(miles)
    eje_verde.yaxis.set_major_formatter(miles)
    eje.tick_params(axis="x", rotation=45)

    # P3 perfil horario por tipo de dia y anio
    eje = ejes[0, 2]
    horario = ind["ind_03_demanda_horaria"]
    for anio in anios:
        for tipo_dia, estilo in (("Entre semana", "-"), ("Fin de semana", "--")):
            datos = horario[(horario["anio"] == anio) & (horario["tipo_dia"] == tipo_dia)]
            eje.plot(datos["hora"], datos["viajes_promedio_dia"], estilo, color=color_anio(anios, anio),
                     label=f"{anio} {tipo_dia.lower()}")
    eje.set_title("P3. Viajes promedio por hora")
    eje.set_xlabel("Hora de recogida")
    eje.set_ylabel("Viajes promedio por día")
    eje.yaxis.set_major_formatter(miles)
    eje.legend(fontsize=8)

    # P4 velocidad mediana por hora
    eje = ejes[1, 0]
    velocidad = ind["ind_04_velocidad_horaria"]
    for anio in anios:
        datos = velocidad[velocidad["anio"] == anio]
        eje.plot(datos["hora"], datos["velocidad_mediana_mph"], marker="o", ms=3, color=color_anio(anios, anio), label=str(anio))
    eje.set_title("P4. Velocidad mediana por hora")
    eje.set_xlabel("Hora de recogida")
    eje.set_ylabel("Millas por hora")
    eje.legend(fontsize=8)

    # P5 viajes promedio por dia de la semana
    eje = ejes[1, 1]
    semana = ind["ind_05_dia_semana"]
    ancho = 0.8 / len(anios)
    for k, anio in enumerate(anios):
        datos = semana[semana["anio"] == anio].sort_values("dia_semana")
        eje.bar(datos["dia_semana"] + (k - (len(anios) - 1) / 2) * ancho, datos["viajes_promedio_dia"], ancho,
                color=color_anio(anios, anio), label=str(anio))
    eje.set_xticks(range(1, 8), DIAS)
    eje.set_title("P5. Viajes promedio por día de la semana")
    eje.set_ylabel("Viajes promedio por día")
    eje.yaxis.set_major_formatter(miles)
    eje.legend(fontsize=8)

    # P11 participacion de taxis verdes en viajes e ingreso
    eje = ejes[1, 2]
    participacion = ind["ind_11_participacion_tipo"]
    verdes = participacion[participacion["tipo_taxi"] == "green"].sort_values("anio")
    posiciones = range(len(verdes))
    eje.bar([p - 0.2 for p in posiciones], verdes["pct_viajes"], 0.4, color=VERDE, label="Porcentaje de viajes")
    eje.bar([p + 0.2 for p in posiciones], verdes["pct_ingreso"], 0.4, color="#9ACD9A", label="Porcentaje de ingreso")
    eje.set_xticks(list(posiciones), verdes["anio"].astype(str))
    eje.set_title("P11. Participación de los taxis verdes")
    eje.set_ylabel("Porcentaje del total")
    eje.legend(fontsize=8)
    figura1.tight_layout()

    figura2, ejes = plt.subplots(2, 4, figsize=(22, 10))
    figura2.suptitle(f"Tablero de viajes de taxi de Nueva York, pago, geografía y calidad, años {texto_anios}", fontsize=14)

    # P6 metodos de pago por anio, ponderando ambos tipos de taxi
    eje = ejes[0, 0]
    pagos = ind["ind_06_metodo_pago"].groupby(["anio", "metodo_pago"], as_index=False)["viajes"].sum()
    pagos["porcentaje"] = 100 * pagos["viajes"] / pagos.groupby("anio")["viajes"].transform("sum")
    tabla_pagos = pagos.pivot(index="anio", columns="metodo_pago", values="porcentaje").fillna(0)
    tabla_pagos = tabla_pagos[tabla_pagos.sum().sort_values(ascending=False).index]
    tabla_pagos.index = tabla_pagos.index.astype(str)
    tabla_pagos.plot(kind="bar", stacked=True, ax=eje, colormap="tab20c", width=0.7)
    eje.set_title("P6. Métodos de pago")
    eje.set_ylabel("Porcentaje de viajes")
    eje.set_xlabel("")
    eje.tick_params(axis="x", rotation=0)
    eje.legend(fontsize=7, loc="lower left")

    # P7 porcentaje de propina con tarjeta por franja horaria
    eje = ejes[0, 1]
    propina = ind["ind_07_propina"].copy()
    propina["ponderado"] = propina["propina_promedio_pct"] * propina["viajes_tarjeta"]
    propina = propina.groupby(["anio", "franja_horaria"], as_index=False)[["ponderado", "viajes_tarjeta"]].sum()
    propina["propina_pct"] = propina["ponderado"] / propina["viajes_tarjeta"]
    for anio in anios:
        datos = propina[propina["anio"] == anio].sort_values("franja_horaria")
        eje.plot(datos["franja_horaria"].str[2:], datos["propina_pct"], marker="o", color=color_anio(anios, anio), label=str(anio))
    eje.set_title("P7. Propina promedio con tarjeta")
    eje.set_ylabel("Porcentaje sobre la tarifa")
    eje.tick_params(axis="x", rotation=30)
    eje.legend(fontsize=8)

    # P8 zonas de origen con mas viajes en el ultimo anio
    eje = ejes[0, 2]
    zonas = ind["ind_08_zonas_origen"]
    zonas = zonas[(zonas["anio"] == ultimo) & (zonas["posicion"] <= 6)].copy()
    zonas["etiqueta"] = zonas["zona"].str.slice(0, 28) + ", " + zonas["tipo_taxi"].map(NOMBRES_TIPO)
    zonas = zonas.sort_values(["tipo_taxi", "porcentaje"])
    eje.barh(zonas["etiqueta"], zonas["porcentaje"], color=zonas["tipo_taxi"].map(COLORES_TIPO))
    eje.set_title(f"P8. Zonas de origen principales, {ultimo}")
    eje.set_xlabel("Porcentaje de los viajes de su tipo")
    eje.tick_params(axis="y", labelsize=8)

    # P9 distritos de origen en el ultimo anio
    eje = ejes[0, 3]
    distritos = ind["ind_09_distritos"]
    distritos = distritos[distritos["anio"] == ultimo]
    tabla_distritos = distritos.pivot(index="distrito", columns="tipo_taxi", values="porcentaje").fillna(0)
    tabla_distritos = tabla_distritos.loc[tabla_distritos.max(axis=1).sort_values().index]
    tabla_distritos = tabla_distritos.rename(columns=NOMBRES_TIPO)
    tabla_distritos.plot(kind="barh", ax=eje, color=[COLORES_TIPO[t] for t in ("green", "yellow") if NOMBRES_TIPO[t] in tabla_distritos.columns])
    eje.set_title(f"P9. Distrito de origen, {ultimo}")
    eje.set_xlabel("Porcentaje de los viajes de su tipo")
    eje.set_ylabel("")
    eje.legend(fontsize=8)

    # P10 aeropuertos, participacion en viajes frente a ingreso
    eje = ejes[1, 0]
    aeropuertos = ind["ind_10_aeropuertos"]
    aeropuertos = aeropuertos[(aeropuertos["anio"] == ultimo) & (aeropuertos["aeropuerto"] != "Sin aeropuerto")]
    posiciones = range(len(aeropuertos))
    eje.bar([p - 0.2 for p in posiciones], aeropuertos["pct_viajes"], 0.4, color="#4C72B0", label="Porcentaje de viajes")
    eje.bar([p + 0.2 for p in posiciones], aeropuertos["pct_ingreso"], 0.4, color="#DD8452", label="Porcentaje de ingreso")
    for p, ticket, alto in zip(posiciones, aeropuertos["ticket_promedio"], aeropuertos[["pct_viajes", "pct_ingreso"]].max(axis=1)):
        eje.annotate(f"ticket {ticket:,.0f} USD", (p, alto), ha="center", va="bottom", fontsize=8)
    eje.margins(y=0.15)
    eje.set_xticks(list(posiciones), aeropuertos["aeropuerto"])
    eje.set_title(f"P10. Viajes de aeropuerto, {ultimo}")
    eje.set_ylabel("Porcentaje del total")
    eje.legend(fontsize=8)

    # P12 porcentaje de registros excluidos por motivo y anio
    eje = ejes[1, 1]
    calidad = ind["ind_12_calidad_datos"].groupby(["anio", "clasificacion"], as_index=False)["registros"].sum()
    calidad["porcentaje"] = 100 * calidad["registros"] / calidad.groupby("anio")["registros"].transform("sum")
    excluidos = calidad[calidad["clasificacion"] != "Válido"]
    tabla_calidad = excluidos.pivot(index="anio", columns="clasificacion", values="porcentaje").fillna(0)
    tabla_calidad.index = tabla_calidad.index.astype(str)
    tabla_calidad.plot(kind="bar", stacked=True, ax=eje, colormap="tab10", width=0.6)
    eje.set_title("P12. Registros excluidos por regla de calidad")
    eje.set_ylabel("Porcentaje de los registros publicados")
    eje.set_xlabel("")
    eje.tick_params(axis="x", rotation=0)
    eje.legend(fontsize=7)

    # P13 recargos promedio por mes
    eje = ejes[1, 2]
    cargos = ind["ind_13_cargos_mensuales"]
    series = (("cargo_cbd_promedio", "Cargo CBD promedio", "#4C72B0"),
              ("recargo_congestion_promedio", "Recargo de congestión promedio", "#DD8452"),
              ("cargos_no_tarifa_promedio", "Total sin tarifa ni propina", "#55A868"))
    for columna, etiqueta, color in series:
        for k, anio in enumerate(anios):
            tramo = cargos[cargos["anio"] == anio]
            eje.plot(tramo["periodo"], tramo[columna], marker="o", ms=3, color=color, label=etiqueta if k == 0 else None)
    eje.set_title("P13. Recargos promedio por viaje")
    eje.set_ylabel("USD por viaje")
    eje.tick_params(axis="x", rotation=45)
    eje.legend(fontsize=8)

    # tabla de indicadores generales por anio
    eje = ejes[1, 3]
    eje.axis("off")
    kpis = resumen.set_index("anio")[["viajes", "ingreso_total", "ticket_promedio", "distancia_mediana", "duracion_mediana"]]
    filas = [["Viajes válidos"] + [f"{v:,.0f}" for v in kpis["viajes"]],
             ["Ingreso total, USD"] + [f"{v:,.0f}" for v in kpis["ingreso_total"]],
             ["Ticket promedio, USD"] + [f"{v:,.2f}" for v in kpis["ticket_promedio"]],
             ["Distancia mediana, mi"] + [f"{v:,.2f}" for v in kpis["distancia_mediana"]],
             ["Duración mediana, min"] + [f"{v:,.1f}" for v in kpis["duracion_mediana"]]]
    tabla = eje.table(cellText=filas, colLabels=["Indicador"] + [str(a) for a in kpis.index], loc="center", cellLoc="center",
                     colWidths=[0.44] + [0.56 / len(kpis)] * len(kpis))
    tabla.auto_set_font_size(False)
    tabla.set_fontsize(9)
    tabla.scale(1, 1.6)
    eje.set_title("P1. Indicadores generales por año")
    figura2.tight_layout()

    return [
        (figura1, f"Tablero de indicadores, demanda, tiempos y participación por tipo de taxi, años {texto_anios}"),
        (figura2, f"Tablero de indicadores, pago, geografía, aeropuertos, calidad y recargos, años {texto_anios}"),
    ]


def main() -> int:
    matplotlib.use("Agg")
    if not taxis.BASE_TABLERO.exists():
        print("No existe la base del tablero. Ejecute primero scripts/construir_tablero.py")
        return 1
    destino = taxis.DIR_DOCS / "tablero"
    destino.mkdir(parents=True, exist_ok=True)
    for numero, (figura, descripcion) in enumerate(dibujar_tablero(leer_indicadores()), start=1):
        ruta = destino / f"tablero_parte{numero}.png"
        figura.savefig(ruta, dpi=130, bbox_inches="tight")
        print(f"{ruta.relative_to(taxis.RAIZ)}: {descripcion}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
