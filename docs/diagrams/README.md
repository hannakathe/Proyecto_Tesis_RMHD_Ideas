# Diagramas PlantUML

Cada archivo `.puml` de esta carpeta es el código fuente de un diagrama del Manual Técnico (ver `README.md` en la raíz). Los renders están en `png/`, con el mismo nombre que su `.puml`.

## Cómo regenerar los PNG

Requisitos: Java 8+ y Graphviz (`dot`) en el `PATH` (o en la variable `GRAPHVIZ_DOT`), más el `plantuml.jar` de <https://plantuml.com/download>.

Desde esta carpeta (`docs/diagrams/`), para que cada PNG tome el nombre de su archivo:

```bash
for f in *.puml; do java -jar plantuml.jar -charset UTF-8 -tpng -pipe < "$f" > "png/${f%.puml}.png"; done
```

> Si usas `java -jar plantuml.jar -tpng -o png *.puml`, PlantUML nombra cada PNG según la etiqueta de `@startuml` (p. ej. `diagrama_clases.png`) y no según el archivo; hay que renombrarlos después.

Para revisar solo la sintaxis sin generar imágenes: `java -jar plantuml.jar -checkonly *.puml`.

Tras regenerar, abre los PNG y verifica que ninguno sea la pantalla de error de PlantUML (texto verde sobre fondo negro con "Syntax Error?").

## Nota sobre `11_diagrama_componentes.puml`

Este diagrama usa la directiva `allowmixing`, porque mezcla elementos `component` con un elemento `database` (PostgreSQL). Sin `allowmixing`, PlantUML rechaza el diagrama con un error de sintaxis.
