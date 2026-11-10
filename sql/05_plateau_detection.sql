-- ============================================================
-- 05_plateau_detection.sql · 问题三：平台期定位（gaps-and-islands）
-- 规则：均线日变化绝对值 < 0.1 kg 且连续 ≥ 4 天
-- （对齐 pandas 版 (end - start).days >= 3 的判定）
-- ============================================================
WITH RECURSIVE spine(d) AS (
    SELECT date(MIN(log_date)) FROM daily_clean
    UNION ALL
    SELECT date(d, '+1 day') FROM spine
    WHERE d < (SELECT MAX(log_date) FROM daily_clean)
),
cal AS (                                   -- 61 天日历，缺失日 weight 为 NULL
    SELECT s.d AS log_date, c.weight_kg
    FROM spine s LEFT JOIN daily_clean c ON c.log_date = s.d
),
anchors AS (                               -- 缺失日前后最近的非空锚点
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
filled AS (                                -- 时间线性插值，等价 pandas interpolate('time')
    SELECT log_date,
      CASE WHEN weight_kg IS NOT NULL THEN weight_kg
           ELSE w_prev + (w_next - w_prev)
                * (julianday(log_date) - julianday(d_prev))
                / (julianday(d_next) - julianday(d_prev))
      END AS w_i
    FROM anchors
),
ma AS (
    SELECT log_date, w_i,
      COUNT(w_i) OVER w AS n_obs,
      AVG(w_i)   OVER w AS ma7_raw
    FROM filled
    WINDOW w AS (ORDER BY log_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW)
),
ma7 AS (
    SELECT log_date, ma7_raw
    FROM ma
    WHERE n_obs >= 3                       -- 复现 min_periods=3
),
flags AS (                                 -- 逐日打标：与昨日均线变化绝对值 < 0.1 kg
    SELECT log_date, ma7_raw,
      CASE WHEN ABS(ma7_raw - LAG(ma7_raw) OVER (ORDER BY log_date)) < 0.1
           THEN 1 ELSE 0 END AS flat
    FROM ma7
),
islands AS (                               -- gaps-and-islands 核心：
    SELECT *,                              -- 全序行号 - 分组内行号 = 连续段 ID
      ROW_NUMBER() OVER (ORDER BY log_date)
    - ROW_NUMBER() OVER (PARTITION BY flat ORDER BY log_date) AS grp
    FROM flags
),
runs AS (
    SELECT grp,
           MIN(log_date) AS start_day,
           MAX(log_date) AS end_day,
           COUNT(*)      AS days
    FROM islands
    WHERE flat = 1
    GROUP BY grp
    HAVING COUNT(*) >= 4
)
SELECT r.start_day,
       r.end_day,
       r.days,
       ROUND(fs.ma7_raw, 2) AS ma_start_zone,   -- 起点当天的均线值
       ROUND(fe.ma7_raw, 2) AS ma_end_zone      -- 终点当天的均线值
FROM runs r
JOIN islands fs ON fs.log_date = r.start_day
JOIN islands fe ON fe.log_date = r.end_day
ORDER BY r.start_day;
-- 预期：19 天平台期（与 pandas 版一致）
