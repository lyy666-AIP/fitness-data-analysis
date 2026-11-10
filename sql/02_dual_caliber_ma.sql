-- ============================================================
-- 02_dual_caliber_ma.sql · 日历版 7 日体重均线
-- spine → 时间线性插值 → 7 日滚动均值（min_periods=3）
-- 等价 pandas：reindex(full_range).interpolate(method='time')
--                    .rolling(7, min_periods=3).mean()
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
anchors AS (                               -- 缺失日前后最近的非空锚点（SQLite 无 IGNORE NULLS 的替代写法）
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
filled AS (                                -- 时间线性插值，等价 pandas interpolate(method='time')
    SELECT log_date,
      CASE WHEN weight_kg IS NOT NULL THEN weight_kg
           ELSE w_prev + (w_next - w_prev)
                * (julianday(log_date) - julianday(d_prev))
                / (julianday(d_next) - julianday(d_prev))
      END AS w_i                           -- 填充后的完整体重序列
    FROM anchors
),
ma AS (                                    -- 7 日滚动窗口（ROWS 6 PRECEDING ~ CURRENT ROW）
    SELECT log_date, w_i,
      COUNT(w_i) OVER w AS n_obs,          -- COUNT(w_i) 不计 NULL
      AVG(w_i)   OVER w AS ma7_raw
    FROM filled
    WINDOW w AS (ORDER BY log_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW)
)
SELECT log_date,
       CASE WHEN n_obs >= 3 THEN ROUND(ma7_raw, 3) END AS ma7_sql
                                            -- 窗口内观测数 < 3 时置 NULL（复现 min_periods=3）
FROM ma
ORDER BY log_date;
