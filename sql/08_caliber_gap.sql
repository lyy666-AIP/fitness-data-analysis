-- ============================================================
-- 08_caliber_gap.sql · 验证层：双口径 gap 对账
-- 自包含（仅依赖 daily_clean），整段一次性执行（含临时表）
-- 口径A 日历版：61 天日历轴 + 线性插值 + 7 日均线（窗口 >= 3 观测）
-- 口径B 记录日版：仅记录日 + 最近 7 个非空记录日均线（窗口 >= 3 观测）
-- ③ 口径A vs 口径B：口径分歧
-- ④b 分歧最大的 5 天 + 定点核对
-- ============================================================

-- ① 物化日历版填充序列（61 天，缺失日已插值）
DROP TABLE IF EXISTS _cal_w;
CREATE TEMP TABLE _cal_w AS
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
SELECT log_date, w_i FROM filled;

-- ② 两条 ma7
DROP TABLE IF EXISTS _ma7_cal;
CREATE TEMP TABLE _ma7_cal AS
SELECT log_date,
       COUNT(w_i) OVER w AS n_obs,
       AVG(w_i)   OVER w AS ma7
FROM _cal_w
WINDOW w AS (ORDER BY log_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW);

DROP TABLE IF EXISTS _ma7_rec;
CREATE TEMP TABLE _ma7_rec AS
SELECT log_date,
       COUNT(weight_kg) OVER w AS n_obs,
       AVG(weight_kg)   OVER w AS ma7
FROM daily_clean
WHERE weight_kg IS NOT NULL          -- 先过滤：窗口 = 最近 7 个非空记录日
WINDOW w AS (ORDER BY log_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW);

-- ③ 口径分歧（两口径只在记录日上可比）
WITH cmp AS (
    SELECT c.log_date, c.ma7 AS ma7_cal, r.ma7 AS ma7_rec
    FROM _ma7_cal c
    JOIN _ma7_rec  r ON r.log_date = c.log_date
    WHERE c.n_obs >= 3 AND r.n_obs >= 3
)
SELECT COUNT(*) AS common_days,
       ROUND(AVG(ABS(ma7_cal - ma7_rec)), 4) AS mean_abs_gap,
       ROUND(MAX(ABS(ma7_cal - ma7_rec)), 3) AS max_abs_gap,
       ROUND((SELECT ma7_cal FROM cmp ORDER BY log_date DESC LIMIT 1), 2) AS cal_end,
       ROUND((SELECT ma7_rec  FROM cmp ORDER BY log_date DESC LIMIT 1), 2) AS rec_end
FROM cmp;
-- 实测：47 天 / mean 0.06 / max 0.275（最大分歧日 09-28，缺失最密集段）

-- ④ 分歧最大的 5 天
WITH cmp AS (
    SELECT c.log_date, c.ma7 AS ma7_cal, r.ma7 AS ma7_rec
    FROM _ma7_cal c JOIN _ma7_rec r ON r.log_date = c.log_date
    WHERE c.n_obs >= 3 AND r.n_obs >= 3
)
SELECT log_date,
       ROUND(ma7_cal, 2) AS ma7_cal,
       ROUND(ma7_rec, 2) AS ma7_rec,
       ROUND(ma7_cal - ma7_rec, 3) AS gap
FROM cmp
ORDER BY ABS(ma7_cal - ma7_rec) DESC
LIMIT 5;

-- ④b 定点核对：指定日期的两口径均线值
SELECT c.log_date, ROUND(c.ma7, 2) AS cal, ROUND(r.ma7, 2) AS rec
FROM _ma7_cal c JOIN _ma7_rec r ON r.log_date = c.log_date
WHERE c.log_date IN ('2026-08-28', '2026-09-10', '2026-09-28');
