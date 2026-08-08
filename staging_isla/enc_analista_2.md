# Encargo 2 — qué construir para poblar la isla

Vuelca el informe a `staging_isla/construibles.md`. **No lo respondas solo por pantalla**:
la lectura de tu panel me devuelve vacío y no puedo verlo.

## Contexto

El usuario quiere que el Patio Natural se sienta como Tomodachi Life: además de casas,
sitios donde los goblins hagan cosas — talleres, cafeterías, plazas.

Ya me diste cinco propuestas y dos me parecieron mejores que las mías: dar propósito
social a un construible que ya existe (el banco de jardín), y la memoria de saludos como
proto-amistad. Esto va sobre la primera línea.

## Lo que quiero saber

### 1. El inventario real de sitios

De los construibles con `allowed_zone = 1` (el patio), **cuáles podrían ser un "sitio"**
donde un ayudante vaya a hacer algo, frente a los que son puro adorno.

Para cada candidato: su id, su coste, su sprite, y **si ya pertenece a algún grupo**
(`warm_spot`, `worker_house`…). Los que ya están en un grupo son los más baratos de
convertir, porque el worker ya sabe buscarlos.

### 2. Qué patrón se puede copiar

`worker_house.gd` (114 líneas) tiene el patrón completo: aforo `CAP`, `enter()`/`leave()`,
contador de ocupantes, badge visible, `door_point()`. Un sitio social sería eso mismo
pero más simple.

Dime **qué partes de ese patrón hacen falta de verdad** para un sitio de reunión y
cuáles sobran. Sé concreto: ¿hace falta `door_point()` en una plaza al aire libre?

### 3. Cuánto puede costar sin romper el ritmo

El ritmo de partida está medido en **18,9 h** y se apoya en los costes de los
construibles. Dame un rango para 3-4 sitios sociales nuevos, apoyado en lo que cuestan
los construibles que ya existen en el patio. Con números, no con "barato".

### 4. Qué pasa si no hay nadie

Riesgo que ya apuntaste: si el aforo es 1-2, los ayudantes hacen cola sin hacer nada.
¿Cuántos ayudantes puede tener el jugador a la vez? Búscalo — eso decide el aforo.

## Las propuestas

**Máximo cuatro**, y cada una con: qué es, qué reutiliza (sprite, escena, grupo,
patrón), qué ficheros toca, coste en monedas y por qué ese, y qué la hace cara o barata.

Prefiero **una idea bien medida a cuatro genéricas**. Si al mirarlo resulta que con dos
sitios sociales basta para que la isla se sienta viva, dilo — es más útil que rellenar
la lista.

## Recuerda

Cada afirmación con `fichero:línea` o un número que mediste. No escribes código de
producción; scripts de análisis en `tools/` sí.
