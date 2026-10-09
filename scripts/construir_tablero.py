#!/usr/bin/env python3
"""Construye la base de indicadores que consume el tablero de Metabase.

Ejecuta cada consulta de sql/05_indicadores.sql sobre la vista de viajes validos y guarda
el resultado como una tabla en data/processed/tablero.duckdb. Metabase se conecta a esa
base en modo de solo lectura, por lo que debe detenerse mientras la base se reconstruye.

Uso:
    docker compose stop metabase
    python scripts/construir_tablero.py                    todos los anios descargados
    python scripts/construir_tablero.py --anios 2024 2026  solo esos anios
    docker compose start metabase

Tambien se guarda docs/tablero/indicadores.csv con el resumen de las tablas creadas.
"""

import argparse
import sys

import taxis

SEPARADOR = "-" * 60


def main() -> int:
    parser = argparse.ArgumentParser(description="Construye la base de indicadores del tablero.")
    parser.add_argument("--anios", type=int, nargs="+", default=None,
                        help="anios a incluir; por defecto todos los descargados")
    argumentos = parser.parse_args()

    anios = argumentos.anios or taxis.anios_disponibles()
    if not anios:
        print("No hay archivos Parquet descargados. Ejecute primero scripts/download_data.py")
        return 1

    print("CONSTRUCCION DE LA BASE DEL TABLERO")
    print(SEPARADOR)
    print(f"  Anios : {', '.join(map(str, anios))}")
    print(f"  Base  : {taxis.BASE_TABLERO.relative_to(taxis.RAIZ)}")
    print(SEPARADOR)
    try:
        resumen = taxis.construir_tablero(anios)
    except PermissionError as error:
        print(f"  ERROR: {error}")
        return 1

    destino = taxis.DIR_DOCS / "tablero"
    destino.mkdir(parents=True, exist_ok=True)
    resumen.to_csv(destino / "indicadores.csv", index=False)
    print(SEPARADOR)
    print(f"  Tablas creadas : {len(resumen)}")
    print(f"  Resumen        : {(destino / 'indicadores.csv').relative_to(taxis.RAIZ)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
