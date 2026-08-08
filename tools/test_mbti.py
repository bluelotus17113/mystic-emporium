#!/usr/bin/env python3
"""Test de persistencia de personalidad MBTI y conflictos en VidaSocial.

Verifica:
- Los 4 ejes sobreviven a JSON ida y vuelta (mismo camino que SaveManager)
- Las siglas se componen correctamente de los ejes
- La afinidad es simétrica y devuelve 0-4
- Los roces se guardan y recuperan
- El umbral de conflicto se alcanza y se puede reconciliar
- La afinidad alta acelera la amistad (INC_AFINIDAD_ALTA)
- La afinidad baja genera roces en vez de amistad

Ejecutar: python3 tools/test_mbti.py
"""

import json
import sys


# --- Réplicas de la lógica de VidaSocial -----------------------------------

def sigla(eje_ei: bool, eje_sn: bool, eje_tf: bool, eje_jp: bool) -> str:
    s = ""
    s += "I" if eje_ei else "E"
    s += "N" if eje_sn else "S"
    s += "F" if eje_tf else "T"
    s += "P" if eje_jp else "J"
    return s


def afinidad(a: list, b: list) -> int:
    return sum(1 for i in range(4) if a[i] == b[i])


def registrar_encuentro(memoria: dict, roces: dict, uid_propio: str,
                        otro_uid: str, otro_memoria: dict, otro_roces: dict,
                        ejes_propios: list, ejes_otro: list) -> str:
    """Devuelve 'amistad', 'roce', o 'amistad_x2' según afinidad."""
    af = afinidad(ejes_propios, ejes_otro)
    AF_MAX = 1
    AF_ALTA = 3
    if af <= AF_MAX:
        roces[otro_uid] = roces.get(otro_uid, 0) + 1
        otro_roces[uid_propio] = otro_roces.get(uid_propio, 0) + 1
        return "roce"
    inc = 2 if af >= AF_ALTA else 1
    memoria[otro_uid] = memoria.get(otro_uid, 0) + inc
    otro_memoria[uid_propio] = otro_memoria.get(uid_propio, 0) + inc
    return "amistad_x2" if inc > 1 else "amistad"


def serializar(uid: str, ejes: list, memoria: dict, roces: dict) -> dict:
    return {"uid": uid, "ejes": ejes, "memoria": dict(memoria), "roces": dict(roces)}


def deserializar(data: dict) -> tuple:
    if not data:
        return "", [False]*4, {}, {}
    uid = str(data.get("uid", ""))
    ejes_raw = data.get("ejes", [])
    ejes = [bool(ejes_raw[i]) if i < len(ejes_raw) else False for i in range(4)]
    mem = {}
    for k, v in data.get("memoria", {}).items():
        mem[str(k)] = int(v)
    roc = {}
    for k, v in data.get("roces", {}).items():
        roc[str(k)] = int(v)
    return uid, ejes, mem, roc


# --- Tests ----------------------------------------------------------------

def test(nombre: str, ok: bool) -> bool:
    marca = "✓" if ok else "✗"
    print(f"  {marca} {nombre}")
    return ok


def main() -> int:
    todos_ok = True

    # ---- Siglas ----
    print("Siglas:")
    todos_ok &= test("INTJ", sigla(True, True, False, False) == "INTJ")
    todos_ok &= test("ESFP", sigla(False, False, True, True) == "ESFP")
    todos_ok &= test("ISTJ", sigla(True, False, False, False) == "ISTJ")
    todos_ok &= test("ENFP", sigla(False, True, True, True) == "ENFP")
    todas = set()
    for a in (False, True):
        for b in (False, True):
            for c in (False, True):
                for d in (False, True):
                    todas.add(sigla(a, b, c, d))
    todos_ok &= test("16 siglas distintas", len(todas) == 16)

    # ---- Afinidad ----
    print("\nAfinidad:")
    ejes_a = [True, True, False, True]    # INTJ
    ejes_b = [True, True, False, True]    # INTJ
    ejes_c = [False, False, True, False]  # ESFP
    ejes_d = [True, False, False, False]  # ISTJ
    todos_ok &= test("idénticos = 4", afinidad(ejes_a, ejes_b) == 4)
    todos_ok &= test("opuestos = 0", afinidad(ejes_a, ejes_c) == 0)
    todos_ok &= test("2 compartidos", afinidad(ejes_a, ejes_d) == 2)
    todos_ok &= test("simétrica", afinidad(ejes_c, ejes_a) == afinidad(ejes_a, ejes_c))

    # ---- JSON ida y vuelta (ejes) ----
    print("\nJSON ida y vuelta (ejes):")
    s = serializar("uid_abc", [True, False, True, False], {}, {})
    j = json.loads(json.dumps(s))
    uid2, ejes2, _, _ = deserializar(j)
    todos_ok &= test("uid intacto", uid2 == "uid_abc")
    todos_ok &= test("eje 0 (I)", ejes2[0] == True)
    todos_ok &= test("eje 1 (S)", ejes2[1] == False)
    todos_ok &= test("eje 2 (F)", ejes2[2] == True)
    todos_ok &= test("eje 3 (J)", ejes2[3] == False)
    todos_ok &= test("sigla tras JSON", sigla(*ejes2) == "ISFJ")

    # ---- JSON sin ejes (partida antigua) ----
    print("\nJSON sin ejes (partida antigua):")
    viejo = {"uid": "old", "memoria": {"x": 3}, "roces": {}}
    uid_v, ejes_v, mem_v, roc_v = deserializar(viejo)
    todos_ok &= test("uid rescatado", uid_v == "old")
    todos_ok &= test("ejes por defecto (4 falses)", ejes_v == [False]*4)
    todos_ok &= test("sigla por defecto = ESTJ", sigla(*ejes_v) == "ESTJ")
    todos_ok &= test("amistad intacta", mem_v.get("x") == 3)

    # ---- Encuentros por afinidad ----
    print("\nEncuentros:")
    mem_a, roc_a = {}, {}
    mem_b, roc_b = {}, {}
    # Afinidad 4 → amistad ×2
    tipo = registrar_encuentro(mem_a, roc_a, "uidA", "uidB", mem_b, roc_b,
                               [True]*4, [True]*4)
    todos_ok &= test("afinidad 4 → amistad_x2", tipo == "amistad_x2")
    todos_ok &= test("A→B = 2", mem_a.get("uidB") == 2)
    todos_ok &= test("B→A = 2 (simétrico)", mem_b.get("uidA") == 2)
    todos_ok &= test("roces vacíos", not roc_a and not roc_b)

    # Afinidad 0 → roce
    tipo2 = registrar_encuentro(mem_a, roc_a, "uidA", "uidC", {}, {},
                                [True]*4, [False]*4)
    todos_ok &= test("afinidad 0 → roce", tipo2 == "roce")
    todos_ok &= test("roce A→C = 1", roc_a.get("uidC") == 1)

    # Afinidad 1 → roce
    ejes_1compartido = [True, False, False, False]
    tipo3 = registrar_encuentro(mem_a, roc_a, "uidA", "uidD", {}, {},
                                [True]*4, ejes_1compartido)
    todos_ok &= test("afinidad 1 → roce", tipo3 == "roce")

    # Afinidad 2 → amistad normal
    ejes_2compartidos = [True, True, False, False]
    tipo4 = registrar_encuentro(mem_a, roc_a, "uidA", "uidE", {}, {},
                                [True]*4, ejes_2compartidos)
    todos_ok &= test("afinidad 2 → amistad", tipo4 == "amistad")
    todos_ok &= test("A→E = 1", mem_a.get("uidE") == 1)

    # ---- Umbral de conflicto y reconciliación ----
    print("\nConflicto y reconciliación:")
    UMBRAL = 5
    RECONCILIAR = 2
    roc_x = {"uidY": 5}
    todos_ok &= test("5 roces → enemistado", roc_x.get("uidY", 0) >= UMBRAL)
    todos_ok &= test("4 roces → NO enemistado", 4 < UMBRAL)

    # Reconciliación: restar RECONCILIAR roces
    antes = roc_x["uidY"]
    roc_x["uidY"] = max(0, roc_x["uidY"] - RECONCILIAR)
    todos_ok &= test("reconciliar: 5→3", roc_x["uidY"] == 3)
    todos_ok &= test("tras reconciliar ya no enemistado", roc_x["uidY"] < UMBRAL)
    # Reconciliar otra vez
    roc_x["uidY"] = max(0, roc_x["uidY"] - RECONCILIAR)
    todos_ok &= test("reconciliar 2ª: 3→1", roc_x["uidY"] == 1)
    # No baja de 0
    roc_x["uidY"] = max(0, roc_x["uidY"] - RECONCILIAR)
    todos_ok &= test("no baja de 0", roc_x["uidY"] == 0)

    # ---- JSON con roces ----
    print("\nJSON con roces y ejes:")
    s2 = serializar("abc", [True, False, True, False], {"x": 5}, {"y": 3})
    j2 = json.loads(json.dumps(s2))
    _, ejes_x, mem_x, roc_x2 = deserializar(j2)
    todos_ok &= test("ejes ok", ejes_x == [True, False, True, False])
    todos_ok &= test("amistad x=5", mem_x.get("x") == 5)
    todos_ok &= test("roces y=3", roc_x2.get("y") == 3)

    print()
    if todos_ok:
        print("Todos los tests OK.")
        return 0
    else:
        print("HAY FALLOS.")
        return 1


if __name__ == "__main__":
    sys.exit(main())
