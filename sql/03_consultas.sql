-- =============================================================================
-- 03_consultas.sql : Ejercicio VI del TP - las tres consultas espaciales
-- =============================================================================
--
-- Estas consultas estan transcriptas TAL COMO SE ENTREGARON en junio de 2024,
-- con sus alias y su formato originales. No se corrigieron. Los defectos que
-- tienen tres años despues estan analizados en el README, en la seccion
-- "Que haria distinto hoy", y las versiones corregidas viven ahi.
--
-- Debajo de cada consulta se transcribe el resultado publicado en el informe.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- (a) Dado un puerto, indique la cantidad de amarres disponibles, y la minima
--     distancia entre estos amarres libres.
-- -----------------------------------------------------------------------------
SELECT
    COUNT(*) AS amarres_disponibles,
    MIN(ST_Distance(a1.ubicacion, a2.ubicacion)) AS min_distancia_entre_amarres
FROM
    puertos.amarres a1
    INNER JOIN puertos.puerto p ON ST_Contains(p.ubicacion, a1.ubicacion)
    LEFT JOIN puertos.amarres a2 ON a1.amarreid <> a2.amarreid
WHERE
    p.puertoid = 1
    AND a1.amarreid NOT IN (Select a1.amarreid From puertos.amarresocupados a1)
    AND  a2.amarreid NOT IN (Select a2.amarreid From puertos.amarresocupados a2);

-- Resultado publicado en el informe (docs/img/07-consulta-amarres-disponibles.png):
--   amarres_disponibles | min_distancia_entre_amarres
--   --------------------+-----------------------------
--                    64 |      0.00040323814303605505
--
-- La distancia se reproduce exacta. El 64 no: ver README.


-- -----------------------------------------------------------------------------
-- (b) Dado un barco que aun no ha llegado al puerto, calcular la distancia al
--     puerto donde solicito servicio.
-- -----------------------------------------------------------------------------
SELECT
    b.name AS nombre_barco,
    p.name AS nombre_puerto,
    ST_Distance(b.ubicacion, p.ubicacion) AS distancia_en_metros
FROM
    puertos.navio b,
    puertos.puerto p
WHERE
    b.navioid = 1
ORDER BY
    distancia_en_metros;

-- Resultado publicado en el informe (docs/img/08-consulta-distancia-navio-puerto.png):
--   nombre_barco       | nombre_puerto | distancia_en_metros
--   -------------------+---------------+------------------------
--   Navio 1 - Amarrado | Buenos Aires  |  6.774924447736365e-05
--   Navio 1 - Amarrado | San Nicolas   |    2.1904473538937164
--   Navio 1 - Amarrado | Rosario       |    2.7726090043121796
--   Navio 1 - Amarrado | Ushuaia       |     22.52287060745943
--
-- Ojo con el alias: esos numeros NO son metros. Ver README.


-- -----------------------------------------------------------------------------
-- (c) Muestre todos los barcos que han solicitado servicio a un puerto, y se
--     encuentran dentro de un perimetro indicado.
-- -----------------------------------------------------------------------------
SELECT n.name, n.ubicacion
FROM puertos.navio n
INNER JOIN puertos.puerto p ON ST_DWithin(p.ubicacion, n.ubicacion, 0.001)
WHERE
    p.puertoid = 1
    AND n.navioid IN (SELECT s.navioid
                      FROM puertos.solicitud s
                      WHERE s.puertoid = 1);

-- Resultado publicado en el informe (docs/img/09-consulta-navios-en-perimetro.png):
--   name               | ubicacion
--   -------------------+--------------------------------------------
--   Navio 1 - Amarrado | 0101000020E61000008E226B0DA52E4DC0826F...
--
--   Total rows: 1 of 1
--
-- Ese WKB decodifica a POINT(-58.364412 -34.595558) en SRID 4326, que es
-- exactamente la posicion del Navio 1 en docs/notas-del-equipo.txt.
