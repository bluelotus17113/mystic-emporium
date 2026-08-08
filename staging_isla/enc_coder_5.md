# Encargo 5 — memoria de saludos: que se hagan amigos

Fichero a editar: `godot/scripts/ai/vida_social.gd` (134 líneas, es TUYO)
**No toques `worker_base.gd`.** Acabo de sacar la vida social de ahí justamente para
que este encargo no le sume ni una línea.

## La idea

Los ayudantes ya se saludan al cruzarse (`tick_saludos` → `_iniciar` → `responder`).
Pero cada saludo es el primero: nadie recuerda a nadie.

Que lleven la cuenta. A partir de cierto número de encuentros con **el mismo** ayudante,
el saludo cambia: emoji distinto, más cálido. Nada más.

Es lo más Tomodachi que se puede hacer con menos código, porque el gancho —el saludo por
proximidad— ya está escrito y funcionando.

## Lo que hay que añadir

- Un diccionario en `VidaSocial`: quién y cuántas veces.
- Al iniciar o responder una charla, sumar uno a ese compañero.
- Si la cuenta pasa el umbral, el emoji sale de un juego "de amigos" en vez del normal.
- Que se guarde: si al cargar la partida se olvidan, no hay memoria que valga.

## El identificador del compañero, que es la trampa

**No uses el nombre.** `worker_base.gd:15` tiene pocos nombres por tipo —ocho duendes,
seis gólems, cuatro leñadores— así que con plantilla llena hay repetidos seguro, y dos
"Pip" distintos compartirían amistad.

Necesitas algo estable que sobreviva a guardar y cargar. **Piénsalo tú y razónalo en el
informe.** Si no encuentras nada fiable, dilo en vez de inventarlo: es mejor que me lo
digas a que la memoria se mezcle entre ayudantes en silencio.

Pista de por dónde mirar: `worker_base.gd:265` tiene `get_save_dict()`, y ahí se ve qué
sobrevive hoy a una recarga y qué no.

## Los números

Elígelos y razónalos. Piensa en cuánto tarda en verse: si el umbral es 50 saludos, nadie
llegará nunca; si es 2, todos son amigos a los cinco minutos y deja de significar nada.
`GREET_COOLDOWN` son 12 s, y eso te dice el ritmo máximo al que puede subir la cuenta.

## Lo que NO quiero

- Niveles de amistad, corazones, barras de progreso ni interfaz.
- Que la amistad dé bonificaciones. En cuanto premie, deja de ser una relación y pasa a
  ser una estadística que optimizar.
- Enemistades, ni afinidades por rasgo.
- Tocar `worker_base.gd`. Si crees que hace falta, descríbelo en el informe y lo hago yo.

Esto son unas 30 líneas dentro de un fichero que ya existe. Si escribes 100, te has
pasado.

## Comprobar

    godot --headless --import
    godot --headless --quit-after 400

Línea base: `Items: 131 | Recipes: 111 | Orders: 84 | Research: 40 | Buildables: 224`.

Y esta vez **prueba el guardado**: escribe un script de usar y tirar que serialice y
deserialice la memoria y confirme que sobrevive. La última vez te pedí una prueba así y
no la hiciste; la lógica de persistencia es justo la que no se puede dar por buena
leyéndola.

## Informe

El de tu definición, con **cómo identificas al compañero y por qué**, los números
razonados, y el **DESCARTADO** relleno.
