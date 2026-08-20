-- =============================================================================
-- 02_seed.sql : datos del caso de estudio
-- =============================================================================
--
-- PROCEDENCIA DE LAS COORDENADAS
--
-- Todas las coordenadas de este archivo salen de docs/notas-del-equipo.txt, las
-- notas de trabajo del grupo (vertices relevados sobre epsg.io en SRID 4326).
-- No son datos inventados: reproducen exactamente los resultados numericos
-- publicados en el informe de 2024. Ver sql/04_verificacion.sql.
--
-- El orden de los vertices de cada poligono se respeta tal como fue relevado,
-- porque es el que produce las distancias publicadas.
--
-- Lo que NO estaba en las notas y hubo que decidir aca (marcado con [ASUMIDO]):
--   * el calado de los muelles          -> queda NULL, no se inventa
--   * la descripcion de cada equipo     -> etiqueta generica
--   * las fechas de solicitud y arribo  -> fechas de la entrega (junio 2024)
--   * que amarre ocupa el Navio 1       -> ver nota en amarresocupados
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Puertos. Los anillos se cierran repitiendo el primer vertice, como exige el
-- tipo Polygon de OGC.
-- -----------------------------------------------------------------------------
INSERT INTO puertos.puerto (puertoid, name, ubicacion) VALUES
(1, 'Buenos Aires', ST_GeomFromText('POLYGON((
    -58.363409 -34.596671,
    -58.363900 -34.595291,
    -58.364396 -34.595388,
    -58.363817 -34.597170,
    -58.363270 -34.597058,
    -58.363409 -34.596671))', 4326)),
(2, 'Ushuaia', ST_GeomFromText('POLYGON((
    -68.302402 -54.809254,
    -68.295350 -54.810804,
    -68.295515 -54.811080,
    -68.304970 -54.809023,
    -68.302402 -54.809254))', 4326)),
(3, 'Rosario', ST_GeomFromText('POLYGON((
    -60.617495 -32.979706,
    -60.617656 -32.975548,
    -60.619544 -32.975098,
    -60.619222 -32.980156,
    -60.617495 -32.979706))', 4326)),
(4, 'San Nicolas', ST_GeomFromText('POLYGON((
    -60.169850 -33.355214,
    -60.179833 -33.348481,
    -60.180134 -33.349181,
    -60.170960 -33.356090,
    -60.169850 -33.355214))', 4326));

-- -----------------------------------------------------------------------------
-- Muelles: un muelle por puerto. [ASUMIDO] Las notas definen la tabla
-- Muelle(PuertoID, Calado, ID) pero no listan muelles ni calados individuales;
-- se crea el minimo necesario para sostener la FK de amarres.
-- -----------------------------------------------------------------------------
INSERT INTO puertos.muelle (muelleid, puertoid, calado) VALUES
(1, 1, NULL),
(2, 2, NULL),
(3, 3, NULL),
(4, 4, NULL);

-- -----------------------------------------------------------------------------
-- Amarres. Los IDs siguen la numeracion original de las notas, que salta el 13:
-- ese amarre no figura en el material recuperado y el hueco se conserva a
-- proposito, para no fabricar un dato que no existe.
-- -----------------------------------------------------------------------------
INSERT INTO puertos.amarres (amarreid, muelleid, ubicacion) VALUES
-- Buenos Aires
( 1, 1, ST_SetSRID(ST_MakePoint(-58.363476, -34.596569), 4326)),
( 2, 1, ST_SetSRID(ST_MakePoint(-58.363669, -34.595997), 4326)),
( 3, 1, ST_SetSRID(ST_MakePoint(-58.363945, -34.595346), 4326)),
( 4, 1, ST_SetSRID(ST_MakePoint(-58.364345, -34.595397), 4326)),
( 5, 1, ST_SetSRID(ST_MakePoint(-58.364085, -34.596198), 4326)),
( 6, 1, ST_SetSRID(ST_MakePoint(-58.363790, -34.597141), 4326)),
-- Ushuaia
( 7, 2, ST_SetSRID(ST_MakePoint(-68.300870, -54.809611), 4326)),
( 8, 2, ST_SetSRID(ST_MakePoint(-68.299014, -54.810035), 4326)),
( 9, 2, ST_SetSRID(ST_MakePoint(-68.296337, -54.810631), 4326)),
(10, 2, ST_SetSRID(ST_MakePoint(-68.296520, -54.810851), 4326)),
(11, 2, ST_SetSRID(ST_MakePoint(-68.299170, -54.810235), 4326)),
(12, 2, ST_SetSRID(ST_MakePoint(-68.302179, -54.809596), 4326)),
-- Rosario
(14, 3, ST_SetSRID(ST_MakePoint(-60.617543, -32.979994), 4326)),
(15, 3, ST_SetSRID(ST_MakePoint(-60.617629, -32.977226), 4326)),
-- San Nicolas
(16, 4, ST_SetSRID(ST_MakePoint(-60.170563, -33.354737), 4326)),
(17, 4, ST_SetSRID(ST_MakePoint(-60.173192, -33.352828), 4326)),
(18, 4, ST_SetSRID(ST_MakePoint(-60.175799, -33.351027), 4326)),
(19, 4, ST_SetSRID(ST_MakePoint(-60.178825, -33.349154), 4326));

-- -----------------------------------------------------------------------------
-- Equipos: dos por puerto. [ASUMIDO] la descripcion; las coordenadas son reales.
-- -----------------------------------------------------------------------------
INSERT INTO puertos.equipos (equiposid, puertoid, descripcion, ubicacion) VALUES
(1, 1, 'Equipo 1 - Buenos Aires', ST_SetSRID(ST_MakePoint(-58.363743, -34.596469), 4326)),
(2, 1, 'Equipo 2 - Buenos Aires', ST_SetSRID(ST_MakePoint(-58.364010, -34.595724), 4326)),
(3, 2, 'Equipo 3 - Ushuaia',      ST_SetSRID(ST_MakePoint(-68.301677, -54.809569), 4326)),
(4, 2, 'Equipo 4 - Ushuaia',      ST_SetSRID(ST_MakePoint(-68.298858, -54.810188), 4326)),
(5, 3, 'Equipo 5 - Rosario',      ST_SetSRID(ST_MakePoint(-60.617661, -32.978739), 4326)),
(6, 3, 'Equipo 6 - Rosario',      ST_SetSRID(ST_MakePoint(-60.617698, -32.976597), 4326)),
(7, 4, 'Equipo 7 - San Nicolas',  ST_SetSRID(ST_MakePoint(-60.176361, -33.350912), 4326)),
(8, 4, 'Equipo 8 - San Nicolas',  ST_SetSRID(ST_MakePoint(-60.178658, -33.349467), 4326));

-- -----------------------------------------------------------------------------
-- Navios. Los nombres son los que aparecen en las salidas del informe.
-- El escenario: tres navios con servicio solicitado en Buenos Aires, uno ya
-- amarrado y dos todavia navegando, uno de ellos fuera del perimetro de control.
-- -----------------------------------------------------------------------------
INSERT INTO puertos.navio (navioid, name, dimensiones, ubicacion) VALUES
(1, 'Navio 1 - Amarrado',           NULL, ST_SetSRID(ST_MakePoint(-58.364412, -34.595558), 4326)),
(2, 'Navio 2 - No Amarrado',        NULL, ST_SetSRID(ST_MakePoint(-58.362542, -34.593543), 4326)),
(3, 'Navio 3 - No Amarrado, Lejos', NULL, ST_SetSRID(ST_MakePoint(-58.355867, -34.589817), 4326));

-- -----------------------------------------------------------------------------
-- Solicitudes: los tres navios pidieron servicio en Buenos Aires (puertoid = 1).
-- Es lo que exige la consulta (c) del ejercicio VI. [ASUMIDO] las fechas.
-- -----------------------------------------------------------------------------
INSERT INTO puertos.solicitud (navioid, puertoid, amarreid, fecha_solicitud, fecha_arribo) VALUES
(1, 1, 1,    DATE '2024-06-20', DATE '2024-06-22'),
(2, 1, NULL, DATE '2024-06-21', NULL),
(3, 1, NULL, DATE '2024-06-21', NULL);

-- -----------------------------------------------------------------------------
-- Amarres ocupados.
--
-- [ASUMIDO] Las notas no registran QUE amarre ocupaba el Navio 1. Se le asigna
-- el amarre 1, y no el geometricamente mas cercano (el 4), por una razon
-- concreta: el informe publica como minima distancia entre amarres libres el
-- valor 0.00040323814303605505, que es exactamente la distancia entre los
-- amarres 3 y 4. Para que ese resultado se reproduzca, ambos tienen que estar
-- libres. Es decir: el propio resultado publicado descarta que el Navio 1
-- ocupara el amarre 4.
-- -----------------------------------------------------------------------------
INSERT INTO puertos.amarresocupados (amarreid, navioid, fecha_arribo) VALUES
(1, 1, DATE '2024-06-22');
