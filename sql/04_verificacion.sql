-- =============================================================================
-- 04_verificacion.sql : contrasta la reconstruccion contra el informe de 2024
-- =============================================================================
--
-- Cada fila compara un valor publicado en docs/informe-tp2-postgis.pdf contra
-- el que produce esta base. Sirve para no tener que creer en la palabra del
-- README: si la reconstruccion fuera aproximada, estos numeros no darian.
--
-- Los valores numericos se comparan con tolerancia relativa de 1e-12 y no por
-- igualdad exacta, a proposito. Sobre PostGIS los ocho controles dan identicos
-- al informe hasta el ultimo digito, asi que la igualdad estricta tambien
-- pasaria hoy. Pero al recalcular las mismas distancias por fuera de GEOS, la
-- de Rosario difiere en 1 ULP (~4e-16 relativo) por el orden en que se encadenan
-- las operaciones de punto flotante: un control que dependa de que dos motores
-- multipliquen en el mismo orden es un control que se rompe solo.
--
-- Uso:  psql -d puertos -f sql/04_verificacion.sql
-- =============================================================================

WITH consulta_a AS (
    SELECT
        COUNT(*) AS amarres_disponibles,
        MIN(ST_Distance(a1.ubicacion, a2.ubicacion)) AS min_dist
    FROM
        puertos.amarres a1
        INNER JOIN puertos.puerto p ON ST_Contains(p.ubicacion, a1.ubicacion)
        LEFT JOIN puertos.amarres a2 ON a1.amarreid <> a2.amarreid
    WHERE
        p.puertoid = 1
        AND a1.amarreid NOT IN (Select a1.amarreid From puertos.amarresocupados a1)
        AND  a2.amarreid NOT IN (Select a2.amarreid From puertos.amarresocupados a2)
),
consulta_b AS (
    SELECT
        p.name AS nombre_puerto,
        ST_Distance(b.ubicacion, p.ubicacion) AS dist,
        ROW_NUMBER() OVER (ORDER BY ST_Distance(b.ubicacion, p.ubicacion)) AS pos
    FROM puertos.navio b, puertos.puerto p
    WHERE b.navioid = 1
),
consulta_c AS (
    SELECT n.name
    FROM puertos.navio n
    INNER JOIN puertos.puerto p ON ST_DWithin(p.ubicacion, n.ubicacion, 0.001)
    WHERE
        p.puertoid = 1
        AND n.navioid IN (SELECT s.navioid FROM puertos.solicitud s WHERE s.puertoid = 1)
),
checks (orden, consulta, control, esperado_num, obtenido_num, esperado_txt, obtenido_txt) AS (
    SELECT 1, '(a)', 'Minima distancia entre amarres libres',
           0.00040323814303605505::float8, (SELECT min_dist FROM consulta_a), NULL, NULL
    UNION ALL
    SELECT 2, '(b)', 'Distancia Navio 1 -> Buenos Aires',
           6.774924447736365e-05::float8, (SELECT dist FROM consulta_b WHERE pos = 1), NULL, NULL
    UNION ALL
    SELECT 3, '(b)', 'Distancia Navio 1 -> San Nicolas',
           2.1904473538937164::float8, (SELECT dist FROM consulta_b WHERE pos = 2), NULL, NULL
    UNION ALL
    SELECT 4, '(b)', 'Distancia Navio 1 -> Rosario',
           2.7726090043121796::float8, (SELECT dist FROM consulta_b WHERE pos = 3), NULL, NULL
    UNION ALL
    SELECT 5, '(b)', 'Distancia Navio 1 -> Ushuaia',
           22.52287060745943::float8, (SELECT dist FROM consulta_b WHERE pos = 4), NULL, NULL
    UNION ALL
    SELECT 6, '(b)', 'Orden de los puertos por distancia',
           NULL, NULL,
           'Buenos Aires / San Nicolas / Rosario / Ushuaia',
           (SELECT string_agg(nombre_puerto, ' / ' ORDER BY pos) FROM consulta_b)
    UNION ALL
    SELECT 7, '(c)', 'Cantidad de navios dentro del perimetro',
           NULL, NULL, '1', (SELECT COUNT(*)::text FROM consulta_c)
    UNION ALL
    SELECT 8, '(c)', 'Navio devuelto',
           NULL, NULL, 'Navio 1 - Amarrado', (SELECT string_agg(name, ', ') FROM consulta_c)
)
SELECT
    consulta,
    control,
    COALESCE(esperado_txt, esperado_num::text) AS esperado,
    COALESCE(obtenido_txt, obtenido_num::text) AS obtenido,
    CASE
        WHEN esperado_num IS NOT NULL THEN
            CASE WHEN obtenido_num IS NOT NULL
                  AND abs(obtenido_num - esperado_num) <= 1e-12 * abs(esperado_num)
                 THEN 'OK' ELSE 'FALLA' END
        ELSE
            CASE WHEN esperado_txt IS NOT DISTINCT FROM obtenido_txt
                 THEN 'OK' ELSE 'FALLA' END
    END AS resultado
FROM checks
ORDER BY orden;


-- -----------------------------------------------------------------------------
-- El unico valor del informe que NO se reproduce, y por que.
--
-- La consulta (a) publica amarres_disponibles = 64. Buenos Aires tiene 6
-- amarres en total, asi que 64 no puede ser una cantidad de amarres: el
-- COUNT(*) esta contando PARES (a1, a2) generados por el LEFT JOIN, no amarres
-- distintos. Ademas el contenido de `amarresocupados` no quedo registrado en el
-- material recuperado, asi que el factor exacto de aquella corrida no es
-- reconstruible.
--
-- Con los datos de este repo, la consulta original devuelve 80 (5 amarres
-- libres en Buenos Aires x 16 contrapartes libres). El numero cambia con el
-- contenido de amarresocupados; lo que no cambia es que no son amarres.
-- -----------------------------------------------------------------------------
SELECT
    (SELECT COUNT(*)
     FROM puertos.amarres a1
     INNER JOIN puertos.puerto p ON ST_Contains(p.ubicacion, a1.ubicacion)
     LEFT JOIN puertos.amarres a2 ON a1.amarreid <> a2.amarreid
     WHERE p.puertoid = 1
       AND a1.amarreid NOT IN (Select a1.amarreid From puertos.amarresocupados a1)
       AND  a2.amarreid NOT IN (Select a2.amarreid From puertos.amarresocupados a2)
    ) AS count_original_cuenta_pares,
    (SELECT COUNT(DISTINCT a1.amarreid)
     FROM puertos.amarres a1
     INNER JOIN puertos.puerto p ON ST_Contains(p.ubicacion, a1.ubicacion)
     WHERE p.puertoid = 1
       AND a1.amarreid NOT IN (SELECT amarreid FROM puertos.amarresocupados)
    ) AS amarres_libres_reales,
    (SELECT COUNT(*)
     FROM puertos.amarres a
     INNER JOIN puertos.puerto p ON ST_Contains(p.ubicacion, a.ubicacion)
     WHERE p.puertoid = 1
    ) AS amarres_totales_buenos_aires;


-- -----------------------------------------------------------------------------
-- Control de calidad de los datos: amarres que caen FUERA del poligono de su
-- propio puerto. Son un bug latente del dataset original; no afectaron la
-- entrega porque las tres consultas del ejercicio VI filtran puertoid = 1.
-- Se esperan 4 filas: los amarres 14 (Rosario) y 17, 18, 19 (San Nicolas).
-- -----------------------------------------------------------------------------
SELECT
    p.name AS puerto,
    a.amarreid,
    ST_Contains(p.ubicacion, a.ubicacion) AS dentro_del_poligono
FROM puertos.amarres a
JOIN puertos.muelle m ON m.muelleid = a.muelleid
JOIN puertos.puerto p ON p.puertoid = m.puertoid
WHERE NOT ST_Contains(p.ubicacion, a.ubicacion)
ORDER BY a.amarreid;
