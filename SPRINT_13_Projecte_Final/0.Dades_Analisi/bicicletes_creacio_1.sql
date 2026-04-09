-- ATTACH 'bicing.duckdb' AS origen (READ_ONLY);
-- CREATE TABLE bicing AS SELECT * FROM origen.bicing;
-- CREATE TABLE estaciones_bicing AS SELECT * FROM origen.estaciones_bicing;
-- DETACH origen;

CREATE TABLE bicing_clean AS
  WITH valid AS (
    SELECT
      station_id,
      num_bikes_available,
      num_docks_available,
      last_reported,
      last_updated
    FROM bicing
    WHERE
      status = 'IN_SERVICE'
      AND is_renting = '1'
      -- valores válidos en las 4 columnas
      and regexp_full_match(station_id, '^[0-9]+$')
      AND regexp_full_match(num_bikes_available, '^[0-9]+$')
      AND regexp_full_match(num_docks_available, '^[0-9]+$')
      AND regexp_full_match(last_reported, '^[0-9]+$')
      AND CAST(last_reported AS BIGINT) BETWEEN 946684800 AND 2145916800
  ),
  dedup AS (
    SELECT
      station_id,
      last_reported,
      -- elegimos una fila por par usando la de mayor last_updated
      arg_max(num_bikes_available, CAST(last_updated AS BIGINT)) AS num_bikes_available,
      arg_max(num_docks_available,  CAST(last_updated AS BIGINT)) AS num_docks_available
    FROM valid
    GROUP BY station_id, last_reported
  )
  SELECT
    CAST(station_id AS INTEGER)          AS station_id,
    CAST(last_reported AS BIGINT)        AS last_reported,
    CAST(num_bikes_available AS INTEGER) AS num_bikes_available,
    CAST(num_docks_available AS INTEGER) AS num_docks_available
  FROM dedup;

CREATE TABLE bicing_with_delta AS
SELECT
    station_id,
    last_reported,
    num_bikes_available,
    num_docks_available,
    NULL::BIGINT AS prev_last_reported,
    NULL::BIGINT AS seconds_since_prev,
    NULL::INTEGER AS prev_num_bikes_available,
    NULL::INTEGER AS delta_bikes
FROM bicing_clean
LIMIT 0;

INSERT INTO bicing_with_delta
  SELECT
      station_id, 
      last_reported,
      num_bikes_available, 
      num_docks_available,
      LAG(last_reported, 1) OVER w AS prev_last_reported,
      last_reported - LAG(last_reported, 1) OVER w AS seconds_since_prev,
      LAG(num_bikes_available, 1) OVER w AS prev_num_bikes_available,
      num_bikes_available - LAG(num_bikes_available, 1) OVER w AS delta_bikes
  FROM bicing_clean
  WINDOW w AS (
      PARTITION BY station_id
      ORDER BY last_reported
  );

CREATE TABLE mesuraments AS
SELECT
  -- Campos originales de bicing_with_delta
  b.station_id as id_estacio,
  b.last_reported as darrera_notificacio,
  b.num_bikes_available as num_bicis_disponibles,
  b.num_docks_available as num_anclatges_disponibles,
  b.prev_num_bikes_available as num_bicis_disponibles_anterior,
  b.delta_bikes as delta_bicis,

  -- Timestamp UTC a partir del epoch
  to_timestamp(last_reported)                        AS ts_utc,

  -- Timestamp en hora local de Barcelona (Europe/Madrid)
  (to_timestamp(last_reported)::TIMESTAMPTZ
     AT TIME ZONE 'Europe/Madrid')                 AS ts_local,

  CAST(
    to_timestamp(b.last_reported)::TIMESTAMPTZ AT TIME ZONE 'Europe/Madrid'
    AS DATE
  ) AS data,

  -- Partes de fecha / hora
  year(to_timestamp(b.last_reported)::TIMESTAMPTZ AT TIME ZONE 'Europe/Madrid') AS any_,
  month(to_timestamp(b.last_reported)::TIMESTAMPTZ AT TIME ZONE 'Europe/Madrid') AS num_mes,
  day(to_timestamp(b.last_reported)::TIMESTAMPTZ AT TIME ZONE 'Europe/Madrid') AS dia_mes,
  isodow(to_timestamp(b.last_reported)::TIMESTAMPTZ AT TIME ZONE 'Europe/Madrid') AS dia_setmana,
  hour(to_timestamp(b.last_reported)::TIMESTAMPTZ AT TIME ZONE 'Europe/Madrid') AS hora_dia,
  minute(to_timestamp(b.last_reported)::TIMESTAMPTZ AT TIME ZONE 'Europe/Madrid') AS minut,
  second(to_timestamp(b.last_reported)::TIMESTAMPTZ AT TIME ZONE 'Europe/Madrid') AS segon,
  
  -- Número de estació de l'any (1 a 4)
  CASE
    WHEN month(to_timestamp(b.last_reported)::TIMESTAMPTZ AT TIME ZONE 'Europe/Madrid') IN (12, 1, 2) THEN 1  -- Hivern
    WHEN month(to_timestamp(b.last_reported)::TIMESTAMPTZ AT TIME ZONE 'Europe/Madrid') IN (3, 4, 5) THEN 2  -- Primavera
    WHEN month(to_timestamp(b.last_reported)::TIMESTAMPTZ AT TIME ZONE 'Europe/Madrid') IN (6, 7, 8) THEN 3  -- Estiu
    ELSE 4                                 -- Tardor
  END AS num_estacio_any,

  -- Nom de l'estació de l'any en català
  CASE
    WHEN month(to_timestamp(b.last_reported)::TIMESTAMPTZ AT TIME ZONE 'Europe/Madrid') IN (12, 1, 2) THEN 'Hivern'
    WHEN month(to_timestamp(b.last_reported)::TIMESTAMPTZ AT TIME ZONE 'Europe/Madrid') IN (3, 4, 5) THEN 'Primavera'
    WHEN month(to_timestamp(b.last_reported)::TIMESTAMPTZ AT TIME ZONE 'Europe/Madrid') IN (6, 7, 8) THEN 'Estiu'
    ELSE 'Tardor'
  END AS nom_estacio_any,

  -- Enriquecimiento con datos de estaciones_bicing
  e.lat,
  e.lon,
  e.codigo_distrito AS codi_districte,
  e.nombre_distrito as nom_districte

FROM bicing_with_delta b
JOIN estaciones_bicing e
  ON e.id_estacion = b.station_id;

create table viatges as 
SELECT
    id_estacio,
    data,
    any_,
    num_mes,
    dia_mes,
    dia_setmana,
    hora_dia,
    num_estacio_any,
    nom_estacio_any,
    lat,
    lon,
    codi_districte,
    nom_districte,
    SUM(
      CASE
        WHEN delta_bicis < 0 THEN -delta_bicis
        ELSE 0
      END
    ) AS viatges
  FROM mesuraments
  GROUP BY 
    id_estacio,
    data,
    any_,
    num_mes,
    dia_mes,
    dia_setmana,
    hora_dia,
    num_estacio_any,
    nom_estacio_any,
    lat,
    lon,
    codi_districte,
    nom_districte;
  

-- las que siguen son tablas muy específicas que generé para facilitar el mostrar los datos en notebooks python

create table viatges_mes as
select
	any_,
	num_mes,
	sum(viatges) as viatges_mes
from viatges
where any_ >= 2022
group by any_, num_mes
order by any_, num_mes;


create table viatges_mes_estacio as
select
	id_estacio,
	any_,
	num_mes,
	sum(viatges) as viatges_mes
from viatges
where any_ >= 2022
group by id_estacio, any_, num_mes
order by id_estacio, any_, num_mes;


create table mitj_viatges_mes_estacio as
select v.*, e.lat, e.lon, e.codigo_distrito as codi_districte, e.nombre_distrito as nom_districte
from
(
	select 
		id_estacio,
		avg(viatges_mes) as mitj_viatges_mes
	from viatges_mes_estacio
	group by id_estacio
) v
join estaciones_bicing e on e.id_estacion = v.id_estacio
order by id_estacion;


create table viatges_dia as
select
	data,
	sum(viatges) as viatges_dia
from viatges
group by data
order by data;


CREATE TABLE mitj_viatges_hora_dia_setmana AS
WITH trips_by_day_hour AS (
    SELECT data, dia_setmana, hora_dia,
           SUM(viatges) AS viatges_total_dia_hora
    FROM viatges WHERE any_ BETWEEN 2022 AND 2025
    GROUP BY data, dia_setmana, hora_dia
)
SELECT dia_setmana, hora_dia,
       AVG(viatges_total_dia_hora) AS mitj_viatges_hora_dia
FROM trips_by_day_hour
GROUP BY dia_setmana, hora_dia;


-- estas tablas son importantes porque permiten el análisis de las estaciones por franjas de 30 minutos

create table estacions as
select 
	id_estacion as id_estacio,
	lat,
	lon,
	codigo_distrito as codi_districte,
	nombre_distrito as nom_districte
from estaciones_bicing
order by id_estacion;


-- tabla con slots con mediciones
CREATE OR REPLACE TABLE indicadors_mitja_hora AS
SELECT
	id_estacio,
	data,
	hora_dia,
	case when minut < 30 then 0 else 1 end as mitja_hora,

	MIN(num_bicis_disponibles)                    AS min_bicis,
	MAX(num_bicis_disponibles)                    AS max_bicis,
	ROUND(AVG(num_bicis_disponibles),        2)   AS avg_bicis,

	MIN(num_anclatges_disponibles)                AS min_anclatges,
	MAX(num_anclatges_disponibles)                AS max_anclatges,
	ROUND(AVG(num_anclatges_disponibles),    2)   AS avg_anclatges,

	ROUND(AVG(
		(num_bicis_disponibles
		 + num_anclatges_disponibles)::FLOAT
	), 2)                                         AS avg_capacitat
FROM mesuraments
WHERE any_ >= 2022
GROUP BY 
	id_estacio,
	data,
	hora_dia,
	case when minut < 30 then 0 else 1 end;

	
CREATE TABLE mitja_hores AS
SELECT
  CAST(ts AS DATE) AS data,
  EXTRACT(HOUR FROM ts) AS hora_dia,
  CASE
    WHEN EXTRACT(MINUTE FROM ts) = 0 THEN 0
    ELSE 1
  END AS mitja_hora
FROM generate_series(
  TIMESTAMP '2022-01-01 00:00:00',
  TIMESTAMP '2025-09-30 23:30:00',
  INTERVAL 30 MINUTE
) AS t(ts);

create table comb as
select
	e.id_estacio,
	e.lat,
	e.lon,
	e.codi_districte,
	e.nom_districte,
	m.data,
	m.hora_dia,
	m.mitja_hora
from estacions e
cross join mitja_hores m;


create table totes_mitja_hores as
SELECT
	c.id_estacio,
	c.lat,
	c.lon,
	c.codi_districte,
	c.nom_districte,
	c.data,
	c.hora_dia,
	c.mitja_hora,
	a.min_bicis,
	a.max_bicis,
	a.avg_bicis,
	a.min_anclatges,
	a.max_anclatges,
	a.avg_anclatges,
	a.avg_capacitat,
	CASE
		WHEN a.id_estacio IS NULL                     THEN 'sense_mesures'
		WHEN a.min_bicis < 0 OR a.min_anclatges < 0  THEN 'altres'
		WHEN a.min_bicis = 0 AND a.min_anclatges = 0 THEN 'extremes'
		WHEN a.min_bicis = 0                          THEN 'buida'
		WHEN a.min_anclatges = 0                      THEN 'plena'
		ELSE                                               'normal'
	END AS estat
FROM comb c
LEFT JOIN indicadors_mitja_hora a ON
	c.id_estacio = a.id_estacio
	and c.data = a.data
	and c.hora_dia = a.hora_dia
	and c.mitja_hora = a.mitja_hora;


-- estas tablas son para calcular features que se usaran en el clustering de las estaciones

CREATE OR REPLACE TABLE feat_estructura AS
SELECT
  id_estacio,
	lat,
	lon,
	nom_districte,
  AVG(avg_capacitat) AS capacitat_mitja
FROM totes_mitja_hores
where year(data) in (2022, 2023, 2024)
GROUP BY    
	id_estacio,
	lat,
	lon,
	nom_districte;


CREATE OR REPLACE TABLE nab_base AS
SELECT
    id_estacio,
    hora_dia,
    mitja_hora,
    AVG(avg_bicis / NULLIF(avg_capacitat, 0)) FILTER (WHERE isodow(data) BETWEEN 1 AND 5) AS nab_lab,
    AVG(avg_bicis / NULLIF(avg_capacitat, 0)) FILTER (WHERE isodow(data) IN (6, 7)) AS nab_fest
FROM totes_mitja_hores
where year(data) in (2022, 2023, 2024)
GROUP BY id_estacio, hora_dia, mitja_hora;


CREATE OR REPLACE TABLE feat_nab AS
SELECT
    id_estacio,

    AVG(nab_lab)  FILTER (WHERE hora_dia in (6,7)) AS nab_lab_h06_08,
    AVG(nab_lab)  FILTER (WHERE hora_dia in (8,9)) AS nab_lab_h08_10,
    AVG(nab_lab)  FILTER (WHERE hora_dia in (10,11)) AS nab_lab_h10_12,
    AVG(nab_lab)  FILTER (WHERE hora_dia in (12,13)) AS nab_lab_h12_14,
    AVG(nab_lab)  FILTER (WHERE hora_dia in (14,15)) AS nab_lab_h14_16,
    AVG(nab_lab)  FILTER (WHERE hora_dia in (16,17)) AS nab_lab_h16_18,
    AVG(nab_lab)  FILTER (WHERE hora_dia in (18,19)) AS nab_lab_h18_20,
    AVG(nab_lab)  FILTER (WHERE hora_dia in (20,21)) AS nab_lab_h20_22,
    AVG(nab_lab)  FILTER (WHERE hora_dia in (22,23)) AS nab_lab_h22_00,
    
    AVG(nab_fest) FILTER (WHERE hora_dia in (6,7,8,9)) AS nab_fest_h06_10,
    AVG(nab_fest) FILTER (WHERE hora_dia in (10,11,12,13)) AS nab_fest_h10_14,
    AVG(nab_fest) FILTER (WHERE hora_dia in (14,15,16,17)) AS nab_fest_h14_18,
    AVG(nab_fest) FILTER (WHERE hora_dia in (18,19,20,21)) AS nab_fest_h18_22,
    AVG(nab_fest) FILTER (WHERE hora_dia in (22,23)) AS nab_fest_h22_00
FROM nab_base
GROUP BY id_estacio;


CREATE OR REPLACE TABLE feat_variabilitat AS
WITH base AS (
    SELECT
        id_estacio,
        isodow(data) as dia_setmana,
        hora_dia,
        mitja_hora,
        estat,
        avg_bicis / NULLIF(avg_capacitat, 0) AS nab,
        max_bicis - min_bicis AS rang_bicis,
        max_anclatges - min_anclatges AS rang_anclatges,
        avg_capacitat,
        (dia_setmana BETWEEN 1 AND 5 AND (hora_dia BETWEEN 7 AND 9 OR hora_dia BETWEEN 17 AND 19)) AS es_hora_punta
    FROM totes_mitja_hores
    where year(data) in (2022, 2023, 2024)
)
SELECT
    id_estacio,
    STDDEV(nab) AS std_nab_global,
    AVG(nab) AS mitja_nab_global,
    STDDEV(nab) FILTER (WHERE dia_setmana BETWEEN 1 AND 5 AND hora_dia BETWEEN 7 AND 9) AS std_nab_punta_matinada,
    STDDEV(nab) FILTER (WHERE dia_setmana BETWEEN 1 AND 5 AND hora_dia BETWEEN 17 AND 19) AS std_nab_punta_tarda,
    AVG(rang_bicis / NULLIF(avg_capacitat, 0)) AS mitja_rang_bicis_norm,
    AVG(rang_anclatges / NULLIF(avg_capacitat, 0)) AS mitja_rang_anclatges_norm,
    COUNT(*) FILTER (WHERE estat = 'buida')::DOUBLE / NULLIF(COUNT(*), 0) AS ratio_buida_global,
    COUNT(*) FILTER (WHERE estat = 'plena')::DOUBLE / NULLIF(COUNT(*), 0) AS ratio_plena_global,
    COUNT(*) FILTER (WHERE estat = 'extremes')::DOUBLE / NULLIF(COUNT(*), 0) AS ratio_extremes_global,
    COUNT(*) FILTER (WHERE estat = 'buida' AND es_hora_punta)::DOUBLE / NULLIF(COUNT(*) FILTER (WHERE es_hora_punta), 0) AS ratio_buida_hora_punta,
    COUNT(*) FILTER (WHERE estat = 'plena' AND es_hora_punta)::DOUBLE / NULLIF(COUNT(*) FILTER (WHERE es_hora_punta), 0) AS ratio_plena_hora_punta,
    AVG(nab) FILTER (WHERE dia_setmana BETWEEN 1 AND 5 AND hora_dia BETWEEN 7 AND 9) AS nab_mitja_punta_matinada,
    AVG(nab) FILTER (WHERE dia_setmana BETWEEN 1 AND 5 AND hora_dia BETWEEN 17 AND 19) AS nab_mitja_punta_tarda
FROM base
GROUP BY id_estacio;


CREATE OR REPLACE TABLE features_clustering AS
SELECT
    e.id_estacio,
    e.lat,
    e.lon,
    e.nom_districte,
    e.capacitat_mitja,
    n.* EXCLUDE (id_estacio),
    var.* EXCLUDE (id_estacio)
FROM feat_estructura e
LEFT JOIN feat_nab n USING (id_estacio)
LEFT JOIN feat_variabilitat var USING (id_estacio)
order by e.id_estacio;




-- ============================================================
-- PASO 1: Historical Average MEJORADO (entrenado con 2022-2024)
-- Para cada estación + mes + semana del mes + día de la semana
-- + hora + mitja_hora: la clase modal histórica (la más frecuente).
--
-- La "semana del mes" se calcula como CEIL(día / 7), dando valores
-- de 1 a 5. Esto permite que al predecir, p.ej., el martes de la
-- 2ª semana de mayo de 2025, se use el promedio de los martes de
-- la 2ª semana de mayo de 2022, 2023 y 2024.
-- ============================================================
CREATE OR REPLACE TABLE baseline_ha AS
SELECT
    id_estacio,
    month(data)                        AS num_mes,
    CEIL(day(data) / 7.0)::INTEGER     AS setmana_mes,   -- 1-5
    isodow(data)                       AS dia_setmana,    -- 1=dl … 7=dg
    hora_dia,
    mitja_hora,
    -- estado más frecuente histórico (mode)
    mode(estat) AS ha_pred
FROM totes_mitja_hores
WHERE
    data >= '2022-01-01'
    AND data <= '2024-12-31'
    AND estat NOT IN ('sense_mesures', 'altres', 'extremes')
GROUP BY
    id_estacio,
    month(data),
    CEIL(day(data) / 7.0)::INTEGER,
    isodow(data),
    hora_dia,
    mitja_hora;


-- ============================================================
-- PASO 2: Seasonal Naive 7d
-- Para cada franja del período de test, buscar el estado real
-- de la misma estación, misma franja, 7 días antes
-- ============================================================
CREATE OR REPLACE TABLE baseline_sn7 AS
SELECT
    tmh.id_estacio,
    tmh.data,
    tmh.hora_dia,
    tmh.mitja_hora,
    tmh_prev.estat AS sn7_pred
FROM totes_mitja_hores tmh
LEFT JOIN totes_mitja_hores tmh_prev
    ON  tmh_prev.id_estacio = tmh.id_estacio
    AND tmh_prev.data       = tmh.data - INTERVAL 7 DAY
    AND tmh_prev.hora_dia   = tmh.hora_dia
    AND tmh_prev.mitja_hora = tmh.mitja_hora
WHERE
    tmh.data >= '2025-01-01'
    AND tmh.data <= '2025-09-30';


-- ============================================================
-- PASO 3: Tabla de evaluación final
-- Período de test: 2025-01-01 a 2025-09-30
-- Une el estado real con las dos predicciones
-- ============================================================
CREATE OR REPLACE TABLE eval_baselines AS
SELECT
    tmh.id_estacio,
    tmh.lat,
    tmh.lon,
    tmh.codi_districte,
    tmh.nom_districte,
    tmh.data,
    tmh.hora_dia,
    tmh.mitja_hora,
    -- tipo de día de la franja de test
    CASE
        WHEN dayofweek(tmh.data) IN (6, 7) THEN 'fest'
        ELSE 'lab'
    END AS tipus_dia,
    -- estado real
    tmh.estat AS estat_real,
    -- predicción Seasonal Naive 7d
    sn7.sn7_pred,
    -- predicción Historical Average (mejorado: mes + setmana_mes + dia_setmana)
    ha.ha_pred
FROM totes_mitja_hores tmh
LEFT JOIN baseline_sn7 sn7
    ON  sn7.id_estacio = tmh.id_estacio
    AND sn7.data       = tmh.data
    AND sn7.hora_dia   = tmh.hora_dia
    AND sn7.mitja_hora = tmh.mitja_hora
LEFT JOIN baseline_ha ha
    ON  ha.id_estacio   = tmh.id_estacio
    AND ha.num_mes      = month(tmh.data)
    AND ha.setmana_mes  = CEIL(day(tmh.data) / 7.0)::INTEGER
    AND ha.dia_setmana  = isodow(tmh.data)
    AND ha.hora_dia     = tmh.hora_dia
    AND ha.mitja_hora   = tmh.mitja_hora
WHERE
    tmh.data >= '2025-01-01'
    AND tmh.data <= '2025-09-30'
    AND tmh.estat NOT IN ('sense_mesures', 'altres', 'extremes');



-- ============================================================
-- Matriz de confusión — Seasonal Naive 7d
-- Solo filas donde tenemos predicción válida (no NULL)
-- ============================================================
create or replace table matriu_confusio_sn7 as
SELECT
    estat_real,
    sn7_pred      AS estat_predit,
    COUNT(*)      AS n_franges,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY estat_real), 2) AS pct_sobre_real
FROM eval_baselines
WHERE sn7_pred IS NOT NULL
GROUP BY estat_real, sn7_pred
ORDER BY estat_real, sn7_pred;

-- ============================================================
-- Matriz de confusión — Historical Average
-- Solo filas donde tenemos predicción válida (no NULL)
-- ============================================================
create or replace table matriu_confusio_ha as
SELECT
    estat_real,
    ha_pred       AS estat_predit,
    COUNT(*)      AS n_franges,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY estat_real), 2) AS pct_sobre_real
FROM eval_baselines
WHERE ha_pred IS NOT NULL
GROUP BY estat_real, ha_pred
ORDER BY estat_real, ha_pred;



-- ============================================================
-- Métricas por clase: precision, recall y F1
-- Requiere la vista eval_baselines creada previamente
-- ============================================================
create or replace table metriques_classe as
WITH metrics AS (
    SELECT
        'sn7' AS baseline,
        estat_real,
        sn7_pred AS estat_pred,
        COUNT(*) AS n
    FROM eval_baselines
    WHERE sn7_pred IS NOT NULL
    GROUP BY estat_real, sn7_pred

    UNION ALL

    SELECT
        'ha' AS baseline,
        estat_real,
        ha_pred AS estat_pred,
        COUNT(*) AS n
    FROM eval_baselines
    WHERE ha_pred IS NOT NULL
    GROUP BY estat_real, ha_pred
),
classes AS (
    SELECT 'buida' AS classe
    UNION ALL
    SELECT 'plena'
    UNION ALL
    SELECT 'normal'
),
pred_counts AS (
    SELECT
        baseline,
        estat_pred,
        SUM(n) AS n_pred
    FROM metrics
    GROUP BY baseline, estat_pred
),
real_counts AS (
    SELECT
        baseline,
        estat_real,
        SUM(n) AS n_real
    FROM metrics
    GROUP BY baseline, estat_real
),
tp_counts AS (
    SELECT
        baseline,
        estat_real AS classe,
        SUM(n) AS tp
    FROM metrics
    WHERE estat_real = estat_pred
    GROUP BY baseline, estat_real
)
SELECT
    b.baseline,
    c.classe,
    COALESCE(tp.tp, 0) AS tp,
    COALESCE(p.n_pred, 0) AS predichos_como_clase,
    COALESCE(r.n_real, 0) AS reales_de_clase,
    ROUND(100.0 * COALESCE(tp.tp, 0) / NULLIF(COALESCE(p.n_pred, 0), 0), 2) AS precision_pct,
    ROUND(100.0 * COALESCE(tp.tp, 0) / NULLIF(COALESCE(r.n_real, 0), 0), 2) AS recall_pct,
    ROUND(
        100.0 * (
            2.0 * (COALESCE(tp.tp, 0)::DOUBLE / NULLIF(COALESCE(p.n_pred, 0), 0)) *
                   (COALESCE(tp.tp, 0)::DOUBLE / NULLIF(COALESCE(r.n_real, 0), 0))
        )
        / NULLIF(
            (COALESCE(tp.tp, 0)::DOUBLE / NULLIF(COALESCE(p.n_pred, 0), 0)) +
            (COALESCE(tp.tp, 0)::DOUBLE / NULLIF(COALESCE(r.n_real, 0), 0)),
            0
        ),
        2
    ) AS f1_pct
FROM
    (SELECT 'sn7' AS baseline UNION ALL SELECT 'ha') b
CROSS JOIN classes c
LEFT JOIN tp_counts tp
    ON tp.baseline = b.baseline
   AND tp.classe = c.classe
LEFT JOIN pred_counts p
    ON p.baseline = b.baseline
   AND p.estat_pred = c.classe
LEFT JOIN real_counts r
    ON r.baseline = b.baseline
   AND r.estat_real = c.classe
ORDER BY b.baseline, c.classe;



-- ============================================================
-- Métricas agregadas: balanced accuracy y macro-F1
-- Requiere la vista eval_baselines
-- ============================================================

CREATE OR REPLACE TABLE agg_confusion AS
SELECT
    baseline,
    estat_real AS classe_real,
    estat_pred AS classe_pred,
    COUNT(*) AS n
FROM (
    SELECT 'sn7' AS baseline, estat_real, sn7_pred AS estat_pred
    FROM eval_baselines
    WHERE sn7_pred IS NOT NULL

    UNION ALL

    SELECT 'ha' AS baseline, estat_real, ha_pred AS estat_pred
    FROM eval_baselines
    WHERE ha_pred IS NOT NULL
) t
GROUP BY baseline, classe_real, classe_pred;


CREATE OR REPLACE TABLE class_metrics AS
WITH classes AS (
    SELECT 'sn7' AS baseline
    UNION ALL
    SELECT 'ha'
),
labels AS (
    SELECT 'buida' AS classe
    UNION ALL
    SELECT 'plena'
    UNION ALL
    SELECT 'normal'
),
tp AS (
    SELECT
        baseline,
        classe_real AS classe,
        SUM(n) AS tp
    FROM agg_confusion
    WHERE classe_real = classe_pred
    GROUP BY baseline, classe_real
),
preds AS (
    SELECT
        baseline,
        classe_pred AS classe,
        SUM(n) AS predichos_como_clase
    FROM agg_confusion
    GROUP BY baseline, classe_pred
),
reals AS (
    SELECT
        baseline,
        classe_real AS classe,
        SUM(n) AS reales_de_clase
    FROM agg_confusion
    GROUP BY baseline, classe_real
)
SELECT
    b.baseline,
    l.classe,
    COALESCE(tp.tp, 0) AS tp,
    COALESCE(p.predichos_como_clase, 0) AS predichos_como_clase,
    COALESCE(r.reales_de_clase, 0) AS reales_de_clase,
    CASE WHEN COALESCE(p.predichos_como_clase, 0) > 0
        THEN 1.0 * COALESCE(tp.tp, 0) / p.predichos_como_clase
        ELSE NULL
    END AS precision,
    CASE WHEN COALESCE(r.reales_de_clase, 0) > 0
        THEN 1.0 * COALESCE(tp.tp, 0) / r.reales_de_clase
        ELSE NULL
    END AS recall,
    CASE
        WHEN COALESCE(p.predichos_como_clase, 0) > 0
         AND COALESCE(r.reales_de_clase, 0) > 0
         AND (1.0 * COALESCE(tp.tp, 0) / p.predichos_como_clase
             + 1.0 * COALESCE(tp.tp, 0) / r.reales_de_clase) > 0
        THEN
            2.0
            * (1.0 * COALESCE(tp.tp, 0) / p.predichos_como_clase)
            * (1.0 * COALESCE(tp.tp, 0) / r.reales_de_clase)
            / (
                (1.0 * COALESCE(tp.tp, 0) / p.predichos_como_clase)
                + (1.0 * COALESCE(tp.tp, 0) / r.reales_de_clase)
            )
        ELSE NULL
    END AS f1
FROM classes b
CROSS JOIN labels l
LEFT JOIN tp
    ON tp.baseline = b.baseline AND tp.classe = l.classe
LEFT JOIN preds p
    ON p.baseline = b.baseline AND p.classe = l.classe
LEFT JOIN reals r
    ON r.baseline = b.baseline AND r.classe = l.classe;

create or replace table balanced_accuracy as
SELECT
    baseline,
    ROUND(100.0 * AVG(recall), 2) AS balanced_accuracy_pct,
    ROUND(100.0 * AVG(f1), 2) AS macro_f1_pct
FROM class_metrics
GROUP BY baseline
ORDER BY baseline;

