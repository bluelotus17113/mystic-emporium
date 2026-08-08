# Encargo — mapa de la vida en la isla

Necesito saber **qué hay ya** antes de programar nada. El usuario quiere que el Patio
Natural se sienta como Tomodachi Life: goblins con personalidad, casa propia, sitios
donde socializar.

Yo ya he mirado por encima y he visto que hay más implementado de lo que parecía. Tu
trabajo es hacer el mapa completo y **corregirme si me equivoco**.

## Lo que creo saber, y quiero que verifiques

En `godot/scripts/ai/worker_base.gd` (1016 líneas) ya existe:

- nombre propio por tipo (`NAMES`, línea 15), nivel y XP
- rasgo de carácter: `enum Trait { DILIGENTE, DORMILON, ENERGICO, CURIOSO }` (línea 30)
- burbujas de emoji según estado (`_maybe_mood`, línea 325)
- saludo al cruzarse (`GREET_RADIUS`, `GREET_EMOTES`, línea 69)
- pausa para "charlar" (`_chat_pause`, `CHAT_EMOTES`)
- energía, descanso y sueño nocturno

Y en `godot/scripts/environment/worker_house.gd` (114 líneas) la casa es un **aforo
compartido de 5** (`CAP`), con contador de ocupantes pero, creo, sin residentes
asignados.

Confírmalo o desmiéntelo con rutas.

## Las preguntas, por orden de importancia

1. **¿Qué hace el rasgo, exactamente?** Localiza cada sitio donde `wtrait` cambia el
   comportamiento y dime cuánto. Sospecho que casi solo la velocidad, y si es así, cuatro
   personalidades que se comportan igual no son cuatro personalidades.

2. **¿Hay residencia asignada?** ¿Puede un worker "vivir" en una casa concreta, o solo
   duerme en la primera con hueco? ¿Se guarda esa relación en la partida
   (`get_save_state` / `load_save_state`)?

3. **¿Qué se puede construir en el patio?** Cuántos construibles tienen
   `allowed_zone = 1`, de qué categorías, y cuáles son *sitios* (algo que un worker pueda
   usar) frente a mera decoración.

4. **¿Cómo se guarda un worker?** Qué campos persisten. Esto decide si añadir "casa
   asignada" o "amistades" es barato o caro.

5. **Economía**: si añadimos 4-6 construibles nuevos al patio (plaza, cafetería, taller,
   banco), ¿qué rango de coste encaja sin descuadrar el ritmo de 18,9 h? Dame números
   apoyados en los costes de los construibles que ya existen.

## Formato

El de tu definición. Con el apartado **PROPUESTAS limitado a cinco**, cada una con
ficheros que toca, qué reutiliza y por qué es barata o cara.

No escribas código de producción. Scripts de análisis en `tools/` sí, si te ayudan.
