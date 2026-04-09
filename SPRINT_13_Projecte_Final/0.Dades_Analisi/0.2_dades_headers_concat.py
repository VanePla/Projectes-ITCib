import os
import glob
import hashlib
from pathlib import Path

ROOT_DIR = Path(__file__).parent / "data_raw"
OUTPUT_DIR = Path(__file__).parent / "bicing_grouped"
os.makedirs(OUTPUT_DIR, exist_ok=True)


def get_header_and_hash(path):
    """Lee la primera línea de un CSV y devuelve (header_str_normalizado, hash)."""
    with open(path, "r", encoding="utf-8") as f:
        header = f.readline()
    # normalizamos saltos de línea y espacios de final
    header_norm = header.rstrip("\r\n") + "\n"
    h = hashlib.sha1(header_norm.encode("utf-8")).hexdigest()
    return header_norm, h

def concatenate_files(files, out_path, chunk_size=1024 * 1024):
    """Concatena los cuerpos (sin cabecera) de todos los ficheros en out_path."""
    with open(out_path, "ab") as out_f:
        for path in files:
            with open(path, "r", encoding="utf-8") as in_f:
                in_f.readline()  # saltar cabecera
                while True:
                    chunk = in_f.read(chunk_size)
                    if not chunk:
                        break
                    # Asegurar que el chunk acaba en salto de línea
                    out_f.write(chunk.encode("utf-8"))

def main():
    pattern = os.path.join(ROOT_DIR, "**", "*.csv")
    all_csv_files = glob.glob(pattern, recursive=True)

    groups = {}  # hash_header -> {"header": str, "files": [paths]}

    # 1) Agrupar archivos por encabezado (texto exacto)
    for path in all_csv_files:
        try:
            header, h = get_header_and_hash(path)
        except Exception as e:
            print(f"Error leyendo encabezado de {path}: {e}")
            continue

        if h not in groups:
            groups[h] = {"header": header, "files": []}
        groups[h]["files"].append(path)

    # 2) Para cada grupo, concatenar
    for i, (h, info) in enumerate(groups.items(), start=1):
        files = info["files"]
        header = info["header"]

        if not files:
            continue

        out_name = f"grupo_header_{i}.csv"
        out_path = os.path.join(OUTPUT_DIR, out_name)

        print(f"\nCreando {out_path} a partir de {len(files)} archivos")

        # Asegurarnos de que no exista de antes
        if os.path.exists(out_path):
            os.remove(out_path)

        # 2.1 Escribir el header una sola vez
        with open(out_path, "w", encoding="utf-8", newline="") as out_f:
            out_f.write(header)

        # 2.2 Concatenar cuerpos (sin cabecera)
        try:
            concatenate_files(files, out_path)
            print(f"  Grupo {i} completado.")
        except Exception as e:
            print(f"  ERROR al concatenar grupo {i}: {e}")
       
       
if __name__ == "__main__":
    main()
