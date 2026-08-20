# Gestión de Puertos con PostGIS

Base de datos relacional **geoespacial** para la gestión de puertos y servicios portuarios:
cuatro puertos argentinos georreferenciados con sus muelles, amarres y equipos, y los navíos
que solicitan servicio antes de arribar y una vez amarrados.

Trabajo Práctico N°2 de **Base de Datos II** — Ingeniería en Informática, Universidad Católica
de Santiago del Estero, Departamento Académico Rafaela. Junio de 2024.

![Puerto de Buenos Aires renderizado desde PostGIS sobre Dársena Norte](docs/img/05-geometry-viewer-puerto-buenos-aires.png)

> El polígono azul es el puerto de Buenos Aires almacenado como `geometry(Polygon, 4326)`,
> proyectado con `ST_Transform` y renderizado sobre OpenStreetMap desde el Geometry Viewer de
> pgAdmin.

---

## Índice

- [El caso de estudio](#el-caso-de-estudio)
- [Stack](#stack)
- [Modelo de datos](#modelo-de-datos)
- [Las consultas espaciales](#las-consultas-espaciales)
- [Cómo levantarlo](#cómo-levantarlo)
- [Sobre la reconstrucción del esquema](#sobre-la-reconstrucción-del-esquema)
- [Qué haría distinto hoy](#qué-haría-distinto-hoy)
- [Contenido del repositorio](#contenido-del-repositorio)
- [Créditos](#créditos)

---

## El caso de estudio

La consigna pedía llevar un sistema de gestión portuaria, modelado en un TP anterior como base
relacional clásica, al terreno geoespacial. Los once puntos del enunciado cubrían desde la
instalación de PostGIS hasta una evaluación crítica de la tecnología:

| # | Punto | Dónde está resuelto |
|---|---|---|
| I–II | Instalación de PostGIS y documentación del proceso | [informe](docs/informe-tp2-postgis.pdf), capturas 01–04 |
| III | Tipos de datos espaciales y diferencias con una BD tradicional | informe |
| IV | Estructura de BD: ubicar puertos, equipos, amarres y navíos | [`sql/01_schema.sql`](sql/01_schema.sql), [`sql/02_seed.sql`](sql/02_seed.sql) |
| V | Generar un mapa con los datos geográficos | `ST_Transform` + Geometry Viewer |
| VI | Tres consultas espaciales sobre el caso | [`sql/03_consultas.sql`](sql/03_consultas.sql) |
| VII | Concurrencia: bloqueos, aislamiento, trabajo distribuido | informe |
| VIII–XI | Casos de éxito, ventajas, desventajas, recomendación como DBA | informe |

Sobre el punto VII, la respuesta entregada analizaba bloqueos compartidos y exclusivos, el uso
de `REPEATABLE READ` para lecturas y `SERIALIZABLE` para el resto, y las tres vías de
PostgreSQL para operar distribuido: replicación síncrona/asíncrona, sharding vía Citus y
*foreign data wrappers*. La propuesta concreta era una base por puerto con el nodo de Buenos
Aires como centralizador de réplicas.

## Stack

| Componente | Versión |
|---|---|
| PostgreSQL | 16.3 |
| PostGIS | 3.4.2 (bundle con GDAL 3.8.5, GEOS 3.12.1, PROJ 9.4) |
| Sistema de referencia | EPSG:4326 (WGS 84) |
| Índices espaciales | GiST sobre cada columna geométrica |
| Cliente | pgAdmin 4 (Geometry Viewer sobre Leaflet + OpenStreetMap) |

![Instalación de PostGIS mediante Stack Builder](docs/img/02-instalacion-postgis-bundle.png)

## Modelo de datos

Siete tablas en el schema `puertos`. Cuatro de ellas llevan geometría:

| Tabla | Geometría | Rol |
|---|---|---|
| `puerto` | `Polygon` | superficie operativa del puerto |
| `muelle` | — | estructura de atraque, con su calado |
| `amarres` | `Point` | posición donde se amarra un navío |
| `navio` | `Point` | posición actual del buque, en navegación o amarrado |
| `equipos` | `Point` | maquinaria del puerto |
| `solicitud` | — | pedido de servicio de un navío a un puerto |
| `amarresocupados` | — | qué amarre está tomado, por quién y desde cuándo |

La decisión de modelado que sostiene todo el trabajo es que **el puerto es un polígono y no un
punto**. Eso es lo que permite preguntar qué amarres pertenecen a un puerto por contención
geométrica (`ST_Contains`) en lugar de por una clave foránea, y lo que hace que la distancia de
un navío al puerto sea la distancia a su borde y no a un centroide arbitrario.

Los datos cubren cuatro puertos — Buenos Aires, Ushuaia, Rosario y San Nicolás — con 18
amarres, 8 equipos y 3 navíos.

![Schema puertos en el árbol de pgAdmin, con el polígono renderizado](docs/img/10-schema-puertos-pgadmin.jpeg)

![Polígono del puerto de Ushuaia sobre el muelle real](docs/img/11-poligono-puerto-ushuaia.png)

## Las consultas espaciales

Las tres del ejercicio VI, en [`sql/03_consultas.sql`](sql/03_consultas.sql) tal como se
entregaron en 2024.

### (a) Amarres disponibles y mínima distancia entre ellos

Combina contención (`ST_Contains`) para saber qué amarres son del puerto, con `ST_Distance`
para medir la separación entre los que están libres.

![Consulta de amarres disponibles](docs/img/07-consulta-amarres-disponibles.png)

La mínima distancia publicada, `0.00040323814303605505`, corresponde a los amarres 3 y 4 de
Buenos Aires: unos 45 metros.

### (b) Distancia de un navío al puerto donde solicitó servicio

![Consulta de distancia navío-puerto](docs/img/08-consulta-distancia-navio-puerto.png)

El navío 1 aparece a `6.77e-05` de Buenos Aires y a `22.52` de Ushuaia. El orden es correcto,
pero las unidades no son las que dice el alias de la columna — ver
[Qué haría distinto hoy](#qué-haría-distinto-hoy).

### (c) Navíos dentro de un perímetro

`ST_DWithin` cruzado con la tabla de solicitudes: de los tres navíos que pidieron servicio en
Buenos Aires, sólo uno cae dentro del radio de control.

![Consulta de navíos dentro del perímetro](docs/img/09-consulta-navios-en-perimetro.png)

El WKB devuelto decodifica a `POINT(-58.364412 -34.595558)` en SRID 4326, exactamente la
posición del navío 1.

## Cómo levantarlo

```bash
docker compose up -d
```

Eso arranca PostgreSQL 16 con PostGIS 3.4 en el puerto `5433` y ejecuta el esquema y los datos
automáticamente. Después:

```bash
docker compose exec -T db psql -U postgres -d puertos -f /sql/04_verificacion.sql
```

`04_verificacion.sql` contrasta lo que produce esta base contra los valores publicados en el
informe de 2024 y devuelve OK o FALLA por cada control. Los ocho dan OK.

Después imprime dos diagnósticos más: `80 / 5 / 6` —el conteo inflado de la consulta (a), los
amarres libres reales de Buenos Aires y su total, que es la evidencia del bug del `COUNT(*)`—
y las cuatro filas de amarres que caen fuera del polígono de su puerto.

Para explorar las consultas del ejercicio VI:

```bash
docker compose exec -T db psql -U postgres -d puertos -f /sql/03_consultas.sql
```

## Sobre la reconstrucción del esquema

Vale la pena ser explícito acá, porque hace a la honestidad del repo.

**El backup entregado en 2024 no contiene el schema `puertos`.** Está en
[`data/DBworld-bp1.backup`](data/) y se puede inspeccionar:

```bash
pg_restore -l data/DBworld-bp1.backup
```

Sólo aparecen la capa `world_countries_generalized` y las tablas de soporte de PostGIS, Tiger
y pointcloud. El schema `puertos` vivía dentro de esa misma base `world` — se lo ve en el árbol
de objetos de pgAdmin, en la captura de arriba — pero quedó fuera del archivo entregado.

Por eso `01_schema.sql` y `02_seed.sql` son una **reconstrucción**. No una aproximación
plausible: una restitución verificable. Las fuentes fueron las definiciones de tablas y las
coordenadas de [`docs/notas-del-equipo.txt`](docs/notas-del-equipo.txt), las consultas y tipos
de columna del informe, y el árbol de objetos de las capturas.

Que sea fiel no hay que creerlo, se comprueba: [`sql/04_verificacion.sql`](sql/04_verificacion.sql)
corre las consultas contra esta base y contrasta cada resultado con el que publicó el informe.
Los ocho controles dan en verde.

| Control | Publicado en 2024 | Obtenido |
|---|---|---|
| Mínima distancia entre amarres libres | `0.00040323814303605505` | idéntico |
| Distancia navío 1 → Buenos Aires | `6.774924447736365e-05` | idéntico |
| Distancia navío 1 → San Nicolás | `2.1904473538937164` | idéntico |
| Distancia navío 1 → Rosario | `2.7726090043121796` | idéntico |
| Distancia navío 1 → Ushuaia | `22.52287060745943` | idéntico |
| Orden de los puertos por distancia | Buenos Aires → San Nicolás → Rosario → Ushuaia | idéntico |
| Navíos dentro del perímetro | 1 | idéntico |
| Navío devuelto | `Navio 1 - Amarrado` | idéntico |

Coincidencias de hasta diecisiete dígitos significativos no ocurren por casualidad: las
coordenadas del repo son las que produjeron aquellas salidas.

El único valor que **no** se reproduce es el `COUNT(*) = 64` de la consulta (a), y no se
reproduce porque está mal. Ver el punto siguiente.

## Qué haría distinto hoy

Con el esquema ya ejecutable, releer el trabajo tres años después deja ver cuatro defectos
reales.

**1. Las distancias no están en metros.** La consulta (b) llama `distancia_en_metros` a una
columna calculada con `ST_Distance` sobre geometrías en SRID 4326, que devuelve grados. Los
`22.52` de Ushuaia son 22,5 grados (≈ 2.375 km reales); los `6.77e-05` de Buenos Aires son
≈ 7,5 m. El fix es castear a `geography`:

```sql
ST_Distance(b.ubicacion::geography, p.ubicacion::geography) AS distancia_en_metros
```

El mismo problema afecta el radio `0.001` de la consulta (c): no es un círculo de 111 m sino
una elipse, porque un grado de longitud se acorta con el coseno de la latitud.

**2. La consulta (a) cuenta pares, no amarres.** El `LEFT JOIN` contra `a2` está ahí para poder
calcular `MIN(ST_Distance(a1, a2))`, pero también multiplica las filas que cuenta `COUNT(*)`.
Buenos Aires tiene 6 amarres en total — los 64 publicados no pueden ser amarres disponibles
(con los datos de este repo, la consulta original devuelve 80). Además `a2` no está restringido
al puerto que se consulta: no rompió nada porque los puertos están a cientos de km entre sí,
pero el filtro faltaba. El fix separa el conteo del cálculo de distancia con una CTE de amarres
libres, comparando cada par una sola vez.

**3. Cuatro amarres caen fuera del polígono de su puerto** — el 14 de Rosario y los 17, 18 y 19
de San Nicolás, cuyos polígonos se trazaron como franjas demasiado finas. No afectó la entrega
porque las tres consultas filtran `puertoid = 1`, pero es lo que un `ST_Contains` sobre otro
puerto habría expuesto. Se corrige el trazado y se blinda con un trigger `BEFORE INSERT` (un
`CHECK` no sirve acá: no puede consultar otra tabla).

**4. Comparar geometría por igualdad exacta es frágil.** Al recalcular las distancias por fuera
de PostGIS para validar que las coordenadas eran las correctas, la de Rosario dio 1 ULP distinta
— no por un error en los datos, sino porque GEOS encadena las operaciones de punto flotante en
otro orden. `04_verificacion.sql` compara con tolerancia relativa por esa razón.

Los detalles y el SQL corregido de cada punto están en el historial de commits de este README.

## Contenido del repositorio

```
├── sql/
│   ├── 01_schema.sql          esquema puertos: 7 tablas, PK/FK, índices GiST
│   ├── 02_seed.sql            los datos, con la procedencia de cada coordenada
│   ├── 03_consultas.sql       ejercicio VI, tal como se entregó
│   └── 04_verificacion.sql    contrasta contra los valores del informe
├── data/
│   └── DBworld-bp1.backup     backup original entregado en 2024
├── docs/
│   ├── informe-tp2-postgis.pdf   documento de entrega
│   ├── notas-del-equipo.txt      notas de trabajo con las coordenadas relevadas
│   └── img/                      capturas del desarrollo y de los resultados
└── docker-compose.yml
```

## Créditos

Trabajo grupal de cinco integrantes: **Francisco Fornari**, **Agustín Pluda**,
**Ramiro Wasilewki**, **Lautaro Christiansen** y **Ayrton Marinoni**.

Cátedra: Ing. Marcela Andrea Vera, Ing. Alejandro Aguirre e Ing. Georgina Festa.

Mi participación (Agustín Pluda) estuvo en el modelado y la carga de datos —diseño del schema
`puertos`, relevamiento de los polígonos de los cuatro puertos y carga de amarres, equipos y
navíos—, en las tres consultas espaciales del ejercicio VI, y en la instalación de PostGIS y la
visualización sobre el Geometry Viewer.

La organización de este repositorio, la reconstrucción del esquema y el análisis crítico de la
sección [Qué haría distinto hoy](#qué-haría-distinto-hoy) son posteriores a la entrega.
