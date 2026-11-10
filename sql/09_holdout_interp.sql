-- ============================================================
-- 09_holdout_interp.sql · 验证层：插值留出验证
-- 自包含（仅依赖 daily_clean），语句按序执行（含临时表）
-- Part A 单点留出：把每个记录日假装缺失，前后锚点插值 vs 真实值
-- Part B 对均线的影响：藏起 4 个留出日 → 重建插值与 ma7 → 对比原 ma7
-- 日期用 %m-%d 匹配，不依赖年份
-- ============================================================

-- ---------- Part A ----------

DROP TABLE IF EXISTS _est;
CREATE TEMP TABLE _est AS
WITH rec AS (
    SELECT log_date, weight_kg,
           LAG(log_date)   OVER (ORDER BY log_date) AS d_prev,
           LAG(weight_kg)  OVER (ORDER BY log_date) AS w_prev,
           LEAD(log_date)  OVER (ORDER BY log_date) AS d_next,
           LEAD(weight_kg) OVER (ORDER BY log_date) AS w_next
    FROM daily_clean
    WHERE weight_kg IS NOT NULL
)
SELECT log_date,
       weight_kg AS w_true,
       w_prev + (w_next - w_prev)
         * (julianday(log_date) - julianday(d_prev))
         / (julianday(d_next) - julianday(d_prev)) AS w_est
FROM rec
WHERE d_prev IS NOT NULL AND d_next IS NOT NULL;

-- A-① 总览（实测：n=47，mean=0.066，max=0.417 @ 09-21）
SELECT COUNT(*)                           AS n_holdout,
       ROUND(AVG(ABS(w_est - w_true)), 3) AS mean_abs_err,
       ROUND(MAX(ABS(w_est - w_true)), 3) AS max_abs_err,
       SUM(ABS(w_est - w_true) > 0.1)     AS n_err_gt_01
FROM _est;

-- A-② 误差最大的 5 天
SELECT log_date, w_true, ROUND(w_est, 2) AS w_est,
       ROUND(w_est - w_true, 3) AS err
FROM _est
ORDER BY ABS(w_est - w_true) DESC
LIMIT 5;

-- A-③ 四个指定观察日（覆盖陡峭段与平台期）
SELECT log_date, w_true, ROUND(w_est, 2) AS w_est,
       ROUND(w_est - w_true, 3) AS err
FROM _est
WHERE strftime('%m-%d', log_date) IN ('08-06', '08-20', '09-01', '09-15');

-- ---------- Part B ----------

DROP TABLE IF EXISTS _holdout;
CREATE TEMP TABLE _holdout AS
SELECT log_date FROM daily_clean
WHERE strftime('%m-%d', log_date) IN ('08-06', '08-20', '09-01', '09-15');

-- B-① 原版 ma7（日历轴 + 插值 + >= 3 观测）
DROP TABLE IF EXISTS _ma7_true;
CREATE TEMP TABLE _ma7_true AS
WITH RECURSIVE spine(d) AS (
    SELECT date(MIN(log_date)) FROM daily_clean
    UNION ALL
    SELECT date(d, '+1 day') FROM spine
    WHERE d < (SELECT MAX(log_date) FROM daily_clean)
),
cal AS (
    SELECT s.d AS log_date, c.weight_kg
    FROM spine s LEFT JOIN daily_clean c ON c.log_date = s.d
),
anchors AS (
    SELECT c.log_date, c.weight_kg,
      (SELECT p.weight_kg FROM cal p WHERE p.weight_kg IS NOT NULL
         AND p.log_date <= c.log_date ORDER BY p.log_date DESC LIMIT 1) AS w_prev,
      (SELECT p.log_date  FROM cal p WHERE p.weight_kg IS NOT NULL
         AND p.log_date <= c.log_date ORDER BY p.log_date DESC LIMIT 1) AS d_prev,
      (SELECT n.weight_kg FROM cal n WHERE n.weight_kg IS NOT NULL
         AND n.log_date >= c.log_date ORDER BY n.log_date ASC  LIMIT 1) AS w_next,
      (SELECT n.log_date  FROM cal n WHERE n.weight_kg IS NOT NULL
         AND n.log_date >= c.log_date ORDER BY n.log_date ASC  LIMIT 1) AS d_next
    FROM cal c
),
filled AS (
    SELECT log_date,
      CASE WHEN weight_kg IS NOT NULL THEN weight_kg
           ELSE w_prev + (w_next - w_prev)
                * (julianday(log_date) - julianday(d_prev))
                / (julianday(d_next) - julianday(d_prev))
      END AS w_i
    FROM anchors
)
SELECT log_date,
       COUNT(w_i) OVER w AS n_obs,
       AVG(w_i)   OVER w AS ma7
FROM filled
WINDOW w AS (ORDER BY log_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW);

-- B-② 扰动版：留出日按缺失处理，重建插值与 ma7
DROP TABLE IF EXISTS _ma7_pert;
CREATE TEMP TABLE _ma7_pert AS
WITH RECURSIVE spine(d) AS (
    SELECT date(MIN(log_date)) FROM daily_clean
    UNION ALL
    SELECT date(d, '+1 day') FROM spine
    WHERE d < (SELECT MAX(log_date) FROM daily_clean)
),
cal2 AS (
    SELECT s.d AS log_date,
           CASE WHEN h.log_date IS NOT NULL THEN NULL
                ELSE c.weight_kg END AS weight_kg
    FROM spine s
    LEFT JOIN daily_clean c ON c.log_date = s.d
    LEFT JOIN _holdout h    ON h.log_date = s.d
),
anchors2 AS (
    SELECT c.log_date, c.weight_kg,
      (SELECT p.weight_kg FROM cal2 p WHERE p.weight_kg IS NOT NULL
         AND p.log_date <= c.log_date ORDER BY p.log_date DESC LIMIT 1) AS w_prev,
      (SELECT p.log_date  FROM cal2 p WHERE p.weight_kg IS NOT NULL
         AND p.log_date <= c.log_date ORDER BY p.log_date DESC LIMIT 1) AS d_prev,
      (SELECT n.weight_kg FROM cal2 n WHERE n.weight_kg IS NOT NULL
         AND n.log_date >= c.log_date ORDER BY n.log_date ASC  LIMIT 1) AS w_next,
      (SELECT n.log_date  FROM cal2 n WHERE n.weight_kg IS NOT NULL
         AND n.log_date >= c.log_date ORDER BY n.log_date ASC  LIMIT 1) AS d_next
    FROM cal2 c
),
filled2 AS (
    SELECT log_date,
      CASE WHEN weight_kg IS NOT NULL THEN weight_kg
           ELSE w_prev + (w_next - w_prev)
                * (julianday(log_date) - julianday(d_prev))
                / (julianday(d_next) - julianday(d_prev))
      END AS w_i
    FROM anchors2
)
SELECT log_date,
       COUNT(w_i) OVER w AS n_obs,
       AVG(w_i)   OVER w AS ma7
FROM filled2
WINDOW w AS (ORDER BY log_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW);

-- B-③ Δma7 总览：平滑后的净影响（实测：mean=0.0051，max=0.032）
WITH cmp AS (
    SELECT t.log_date, p.ma7 - t.ma7 AS d_ma7,
           CASE WHEN h.log_date IS NOT NULL THEN 1 ELSE 0 END AS is_holdout
    FROM _ma7_true t
    JOIN _ma7_pert p ON p.log_date = t.log_date
    LEFT JOIN _holdout h ON h.log_date = t.log_date
    WHERE t.n_obs >= 3 AND p.n_obs >= 3
)
SELECT COUNT(*)                                                     AS days_cmp,
       ROUND(AVG(ABS(d_ma7)), 4)                                    AS mean_abs_d,
       ROUND(MAX(ABS(d_ma7)), 3)                                    AS max_abs_d,
       ROUND(MAX(ABS(CASE WHEN is_holdout = 1 THEN d_ma7 END)), 3)  AS max_d_holdout,
       ROUND(MAX(ABS(CASE WHEN is_holdout = 0 THEN d_ma7 END)), 3)  AS max_d_other
FROM cmp;

-- B-④ 留出日明细：单点误差 vs 平滑后误差（应满足 |d_ma7| <= |err_single|）
SELECT e.log_date,
       e.w_true,
       ROUND(e.w_est, 2)            AS w_est,
       ROUND(e.w_est - e.w_true, 3) AS err_single,
       ROUND(p.ma7 - t.ma7, 3)      AS d_ma7
FROM _est e
JOIN _holdout  h ON h.log_date = e.log_date
JOIN _ma7_true t ON t.log_date = e.log_date
JOIN _ma7_pert p ON p.log_date = e.log_date
ORDER BY e.log_date;
