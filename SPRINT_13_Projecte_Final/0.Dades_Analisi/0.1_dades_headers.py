import os
import glob
import hashlib
from pathlib import Path

ROOT_DIR = Path(__file__).parent / "data_raw"

def get_header_norm(path):
    """Devuelve el header normalizado (una sola línea) de un CSV."""
    with open(path, "r", encoding="utf-8") as f:
        header = f.readline()
    # Normalizar saltos de línea
    return header.rstrip("\r\n")

def main():
    pattern = os.path.join(ROOT_DIR, "**", "*.csv")
    all_csv_files = glob.glob(pattern, recursive=True)

    # hash_header -> {"header": str, "count": int}
    headers = {}

    for path in all_csv_files:
        try:
            header = get_header_norm(path)
        except Exception as e:
            print(f"Error leyendo encabezado de {path}: {e}")
            continue

        # Usamos un hash para clave estable y breve
        h = hashlib.sha1(header.encode("utf-8")).hexdigest()

        if h not in headers:
            headers[h] = {"header": header, "count": 0}
        headers[h]["count"] += 1

    # Mostrar resultados
    print("\nEncabezados distintos encontrados:\n")
    for i, (h, info) in enumerate(headers.items(), start=1):
        print(f"=== Header #{i} ===")
        print(f"Hash: {h}")
        print(f"Archivos con este header: {info['count']}")
        print("Header:")
        print(info["header"])
        print("-" * 60)


if __name__ == "__main__":
    main()
