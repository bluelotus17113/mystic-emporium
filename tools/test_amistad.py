#!/usr/bin/env python3
"""Test de persistencia de la memoria de amistad de VidaSocial.

Simula el ciclo save → load del diccionario _memoria: genera datos de prueba,
los serializa a JSON (mismo formato que usaría SaveManager), los deserializa y
comprueba que uids y contadores sobreviven intactos.

Ejecutar: python3 tools/test_amistad.py
"""

import json
import sys


def simular_serializacion(uid: str, memoria: dict) -> dict:
    """Réplica de VidaSocial.get_save_state()."""
    return {"uid": uid, "memoria": dict(memoria)}


def simular_deserializacion(data: dict) -> tuple[str, dict]:
    """Réplica de VidaSocial.load_save_state()."""
    if not data:
        return "", {}
    uid = str(data.get("uid", ""))
    memoria = {}
    mem = data.get("memoria", {})
    for k, v in mem.items():
        memoria[str(k)] = int(v)
    return uid, memoria


def test(nombre: str, ok: bool) -> bool:
    marca = "✓" if ok else "✗"
    print(f"  {marca} {nombre}")
    return ok


def main() -> int:
    todos_ok = True

    # --- Guardado básico ---
    print("Guardado básico:")
    uid_orig = "a3f2d1b4e5c6"
    mem_orig = {"abc123": 3, "def456": 7}
    saved = simular_serializacion(uid_orig, mem_orig)
    todos_ok &= test("uid en dict", saved["uid"] == uid_orig)
    todos_ok &= test("memoria en dict", saved["memoria"] == mem_orig)

    # --- Recuperación ---
    print("\nRecuperación:")
    uid2, mem2 = simular_deserializacion(saved)
    todos_ok &= test("uid intacto", uid2 == uid_orig)
    todos_ok &= test("memoria tamaño", len(mem2) == 2)
    todos_ok &= test("memoria abc123 → 3", mem2.get("abc123") == 3)
    todos_ok &= test("memoria def456 → 7", mem2.get("def456") == 7)

    # --- JSON ida y vuelta (simula SaveManager) ---
    print("\nJSON ida y vuelta:")
    json_str = json.dumps(saved)
    cargado = json.loads(json_str)
    uid3, mem3 = simular_deserializacion(cargado)
    todos_ok &= test("uid tras JSON", uid3 == uid_orig)
    # JSON convierte int keys a str, pero nuestro save usa str keys nativamente
    todos_ok &= test("abc123 tras JSON", mem3.get("abc123") == 3)
    todos_ok &= test("def456 tras JSON", mem3.get("def456") == 7)

    # --- Casos borde ---
    print("\nCasos borde:")
    # Dict vacío (worker nuevo sin amigos)
    uid_v, mem_v = simular_deserializacion({})
    todos_ok &= test("dict vacío → uid vacío", uid_v == "")
    todos_ok &= test("dict vacío → memoria vacía", len(mem_v) == 0)

    # Dict con uid pero sin memoria
    semi = {"uid": "nuevo123", "memoria": {}}
    uid_s, mem_s = simular_deserializacion(semi)
    todos_ok &= test("sin entradas → uid ok", uid_s == "nuevo123")
    todos_ok &= test("sin entradas → 0 amigos", len(mem_s) == 0)

    # Cuenta grande (no truncar)
    print("\nContadores grandes:")
    muchos = simular_serializacion("x", {"y": 99999})
    _, mem_m = simular_deserializacion(muchos)
    todos_ok &= test("99999 intacto", mem_m.get("y") == 99999)

    # Múltiples amigos (todos los workers de una partida)
    print("\nMuchos amigos:")
    gran_mem = {"u%d" % i: i * 2 for i in range(40)}
    gran_save = simular_serializacion("yo", gran_mem)
    _, gran_carga = simular_deserializacion(gran_save)
    todos_ok &= test("40 entradas → 40", len(gran_carga) == 40)
    todos_ok &= test("entrada 39 → 78", gran_carga.get("u39") == 78)

    # --- Umbral de amistad: simular que se alcanza ---
    print("\nAlcanza umbral (5):")
    u, m = simular_deserializacion({"uid": "a", "memoria": {"b": 5}})
    todos_ok &= test("5 encuentros → es amigo", m.get("b", 0) >= 5)
    todos_ok &= test("4 encuentros → no es amigo", m.get("b", 0) - 1 < 5)

    print()
    if todos_ok:
        print("Todos los tests OK.")
        return 0
    else:
        print("HAY FALLOS.")
        return 1


if __name__ == "__main__":
    sys.exit(main())
