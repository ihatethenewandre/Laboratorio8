#!/usr/bin/env python3
"""Benchmark de consultas sobre archivos Parquet frente a tablas materializadas en DuckDB.

Ejecuta las consultas de sql/04_benchmark.sql con las dos estrategias y con volumenes
crecientes de datos: 1 mes, 3 meses, 12 meses y todos los meses descargados. Por cada
volumen crea una vista sobre los Parquet y una tabla DuckDB con exactamente los mismos
registros, de modo que la unica diferencia entre estrategias es la fuente.

Uso:
    python scripts/benchmark.py                          todos los anios descargados
    python scripts/benchmark.py --anios 2024 2026        solo esos anios
    python scripts/benchmark.py --repeticiones 5

Resultados:
    docs/benchmark/benchmark_detalle.csv     tiempo de cada repeticion
    docs/benchmark/benchmark_resumen.csv     mediana por consulta, volumen y estrategia
    docs/benchmark/benchmark_comparacion.csv mediana de ambas estrategias y su cociente
    docs/benchmark/benchmark_cargas.csv      volumenes, tamanio en disco y tiempo de materializacion
    data/processed/benchmark.duckdb          base con la tabla materializada del volumen completo
"""

import argparse
import platform
import sys

import duckdb

import taxis

DIR_RESULTADOS = taxis.DIR_DOCS / "benchmark"
SEPARADOR = "-" * 60


def main() -> int:
    parser = argparse.ArgumentParser(description="Benchmark Parquet frente a tablas DuckDB.")
    parser.add_argument("--anios", type=int, nargs="+", default=None,
                        help="anios a incluir; por defecto todos los descargados")
    parser.add_argument("--repeticiones", type=int, default=5,
                        help="repeticiones medidas por consulta y estrategia, por defecto 5")
    argumentos = parser.parse_args()

    anios = argumentos.anios or taxis.anios_disponibles()
    if not anios:
        print("No hay archivos Parquet descargados. Ejecute primero scripts/download_data.py")
        return 1
    volumenes = taxis.volumenes_benchmark(anios)

    print("BENCHMARK PARQUET FRENTE A TABLA DUCKDB")
    print(SEPARADOR)
    print(f"  DuckDB       : {duckdb.__version__}")
    print(f"  Plataforma   : {platform.platform()}")
    print(f"  Anios        : {', '.join(map(str, anios))}")
    print(f"  Repeticiones : {argumentos.repeticiones}")
    print(SEPARADOR)

    detalle, cargas = taxis.ejecutar_benchmark(volumenes, argumentos.repeticiones)
    resumen, comparacion = taxis.resumir_benchmark(detalle)

    DIR_RESULTADOS.mkdir(parents=True, exist_ok=True)
    detalle.to_csv(DIR_RESULTADOS / "benchmark_detalle.csv", index=False)
    resumen.to_csv(DIR_RESULTADOS / "benchmark_resumen.csv", index=False)
    comparacion.to_csv(DIR_RESULTADOS / "benchmark_comparacion.csv", index=False)
    cargas.to_csv(DIR_RESULTADOS / "benchmark_cargas.csv", index=False)

    print(SEPARADOR)
    print(comparacion.round(4).to_string(index=False))
    print(SEPARADOR)
    print(f"  Resultados en {DIR_RESULTADOS.relative_to(taxis.RAIZ)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
