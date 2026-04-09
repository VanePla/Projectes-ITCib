-- Para Random Forest

CREATE OR REPLACE TABLE rf_nab_perfil AS
SELECT
    id_estacio,
    hora_dia,
    mitja_hora,
    CAST(CASE WHEN EXTRACT(isodow FROM data) >= 6 THEN 1 ELSE 0 END AS TINYINT)
        AS es_festiu,
    CAST(AVG(avg_bicis / NULLIF(avg_capacitat, 0)) AS FLOAT) AS nab_mig,
    CAST(STDDEV(avg_bicis / NULLIF(avg_capacitat, 0)) AS FLOAT) AS nab_std,
    CAST(AVG(avg_capacitat) AS FLOAT) AS cap_mitja,
    CAST(AVG(CASE WHEN estat = 'buida' THEN 1.0 ELSE 0.0 END) AS FLOAT) AS ratio_buida,
    CAST(AVG(CASE WHEN estat = 'plena' THEN 1.0 ELSE 0.0 END) AS FLOAT) AS ratio_plena
FROM totes_mitja_hores
WHERE estat IN ('normal', 'buida', 'plena')
  AND year(data) BETWEEN 2022 AND 2024
GROUP BY id_estacio, hora_dia, mitja_hora, es_festiu;


CREATE OR REPLACE TABLE rf_features_train AS
WITH amb_lag AS (
    SELECT
        t.id_estacio,
        t.data,
        CAST(t.hora_dia AS SMALLINT) AS hora_dia,
        CAST(t.mitja_hora AS SMALLINT) AS mitja_hora,
        t.estat,
        CAST(EXTRACT(month FROM t.data) AS TINYINT) AS mes,
        CAST(EXTRACT(isodow FROM t.data) AS TINYINT) AS dia_setmana,
        CAST(CASE WHEN EXTRACT(isodow FROM t.data) >= 6 THEN 1 ELSE 0 END AS TINYINT)
            AS es_festiu,
        CAST(CASE
            WHEN EXTRACT(month FROM t.data) IN (12, 1, 2) THEN 1
            WHEN EXTRACT(month FROM t.data) IN (3, 4, 5)  THEN 2
            WHEN EXTRACT(month FROM t.data) IN (6, 7, 8)  THEN 3
            ELSE 4
        END AS TINYINT) AS estacio_any,
        -- Features observacionals de t−2 (LAG 2)
        CAST(LAG(t.avg_bicis, 2) OVER w AS FLOAT)
            AS prev_avg_bicis,
        CAST(LAG(t.avg_anclatges, 2) OVER w AS FLOAT)
            AS prev_avg_anclatges,
        CAST(LAG(COALESCE(t.avg_capacitat, 20.0), 2) OVER w AS FLOAT)
            AS prev_avg_capacitat,
        CAST(CASE LAG(t.estat, 2) OVER w
            WHEN 'buida'  THEN 0
            WHEN 'normal' THEN 1
            WHEN 'plena'  THEN 2
            ELSE -1
        END AS TINYINT) AS prev_estat_num,
        -- Tendència t−3 → t−2
        CAST(LAG(t.avg_bicis, 2) OVER w - LAG(t.avg_bicis, 3) OVER w AS FLOAT)
            AS delta_bicis,
        CAST(LAG(t.avg_anclatges, 2) OVER w - LAG(t.avg_anclatges, 3) OVER w AS FLOAT)
            AS delta_anclatges
    FROM totes_mitja_hores t
    WHERE t.estat IN ('normal', 'buida', 'plena')
    WINDOW w AS (PARTITION BY t.id_estacio ORDER BY t.data, t.hora_dia, t.mitja_hora)
)
SELECT
    a.id_estacio,
    a.data,
    a.hora_dia,
    a.mitja_hora,
    a.estat,
    a.mes,
    a.dia_setmana,
    a.es_festiu,
    a.estacio_any,
    a.prev_avg_bicis,
    a.prev_avg_anclatges,
    a.prev_avg_capacitat,
    a.prev_estat_num,
    a.delta_bicis,
    a.delta_anclatges,
    COALESCE(n.nab_mig, g.nab_mig_global)         AS nab_mig,
    COALESCE(n.nab_std, g.nab_std_global)          AS nab_std,
    COALESCE(n.cap_mitja, g.cap_mitja_global)      AS cap_mitja,
    COALESCE(n.ratio_buida, g.ratio_buida_global)  AS ratio_buida,
    COALESCE(n.ratio_plena, g.ratio_plena_global)  AS ratio_plena,
    CAST(COALESCE(c.cluster, -1) AS TINYINT)       AS cluster
FROM amb_lag a
CROSS JOIN (
    SELECT
        AVG(nab_mig) AS nab_mig_global,
        AVG(nab_std) AS nab_std_global,
        AVG(cap_mitja) AS cap_mitja_global,
        AVG(ratio_buida) AS ratio_buida_global,
        AVG(ratio_plena) AS ratio_plena_global
    FROM rf_nab_perfil
) g
LEFT JOIN rf_nab_perfil n
    ON  a.id_estacio = n.id_estacio
    AND a.hora_dia   = n.hora_dia
    AND a.mitja_hora = n.mitja_hora
    AND a.es_festiu  = n.es_festiu
LEFT JOIN estacio_cluster c
    ON  a.id_estacio = c.id_estacio
WHERE a.prev_avg_bicis IS NOT NULL
  AND a.delta_bicis IS NOT NULL
  AND year(a.data) BETWEEN 2022 AND 2024;


CREATE OR REPLACE TABLE rf_features_test AS
WITH amb_lag AS (
    SELECT
        t.id_estacio,
        t.data,
        CAST(t.hora_dia AS SMALLINT) AS hora_dia,
        CAST(t.mitja_hora AS SMALLINT) AS mitja_hora,
        t.estat,
        CAST(EXTRACT(month FROM t.data) AS TINYINT) AS mes,
        CAST(EXTRACT(isodow FROM t.data) AS TINYINT) AS dia_setmana,
        CAST(CASE WHEN EXTRACT(isodow FROM t.data) >= 6 THEN 1 ELSE 0 END AS TINYINT)
            AS es_festiu,
        CAST(CASE
            WHEN EXTRACT(month FROM t.data) IN (12, 1, 2) THEN 1
            WHEN EXTRACT(month FROM t.data) IN (3, 4, 5)  THEN 2
            WHEN EXTRACT(month FROM t.data) IN (6, 7, 8)  THEN 3
            ELSE 4
        END AS TINYINT) AS estacio_any,
        CAST(LAG(t.avg_bicis, 2) OVER w AS FLOAT)
            AS prev_avg_bicis,
        CAST(LAG(t.avg_anclatges, 2) OVER w AS FLOAT)
            AS prev_avg_anclatges,
        CAST(LAG(COALESCE(t.avg_capacitat, 20.0), 2) OVER w AS FLOAT)
            AS prev_avg_capacitat,
        CAST(CASE LAG(t.estat, 2) OVER w
            WHEN 'buida'  THEN 0
            WHEN 'normal' THEN 1
            WHEN 'plena'  THEN 2
            ELSE -1
        END AS TINYINT) AS prev_estat_num,
        CAST(LAG(t.avg_bicis, 2) OVER w - LAG(t.avg_bicis, 3) OVER w AS FLOAT)
            AS delta_bicis,
        CAST(LAG(t.avg_anclatges, 2) OVER w - LAG(t.avg_anclatges, 3) OVER w AS FLOAT)
            AS delta_anclatges
    FROM totes_mitja_hores t
    WHERE t.estat IN ('normal', 'buida', 'plena')
    WINDOW w AS (PARTITION BY t.id_estacio ORDER BY t.data, t.hora_dia, t.mitja_hora)
)
SELECT
    a.id_estacio,
    a.data,
    a.hora_dia,
    a.mitja_hora,
    a.estat,
    a.mes,
    a.dia_setmana,
    a.es_festiu,
    a.estacio_any,
    a.prev_avg_bicis,
    a.prev_avg_anclatges,
    a.prev_avg_capacitat,
    a.prev_estat_num,
    a.delta_bicis,
    a.delta_anclatges,
    COALESCE(n.nab_mig, g.nab_mig_global)         AS nab_mig,
    COALESCE(n.nab_std, g.nab_std_global)          AS nab_std,
    COALESCE(n.cap_mitja, g.cap_mitja_global)      AS cap_mitja,
    COALESCE(n.ratio_buida, g.ratio_buida_global)  AS ratio_buida,
    COALESCE(n.ratio_plena, g.ratio_plena_global)  AS ratio_plena,
    CAST(COALESCE(c.cluster, -1) AS TINYINT)       AS cluster
FROM amb_lag a
CROSS JOIN (
    SELECT
        AVG(nab_mig) AS nab_mig_global,
        AVG(nab_std) AS nab_std_global,
        AVG(cap_mitja) AS cap_mitja_global,
        AVG(ratio_buida) AS ratio_buida_global,
        AVG(ratio_plena) AS ratio_plena_global
    FROM rf_nab_perfil
) g
LEFT JOIN rf_nab_perfil n
    ON  a.id_estacio = n.id_estacio
    AND a.hora_dia   = n.hora_dia
    AND a.mitja_hora = n.mitja_hora
    AND a.es_festiu  = n.es_festiu
LEFT JOIN estacio_cluster c
    ON  a.id_estacio = c.id_estacio
WHERE a.prev_avg_bicis IS NOT NULL
  AND a.delta_bicis IS NOT NULL
  AND year(a.data) = 2025
  AND EXTRACT(month FROM a.data) <= 9;
    