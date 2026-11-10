-- ============================================================
-- 03b_weekly_speed.sql · 问题一：周减重速度 + 周均热量
-- 日历版 7 日均线按"止于周日的周"（W-SUN）聚合，LAG 求周环比
-- 对齐 pandas 版 fitness_analysis.py 的周度打印表
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
ma7 AS (                                   -- 复现 min_periods=3（序列起点存在 NULL）
    SELECT log_date,
           CASE WHEN n_obs >= 3 THEN ma7_raw END AS ma7_sql
    FROM ma
),
wk AS (                                    -- 周键 = 本周止于的周日，对齐 pandas 的 W-SUN
    SELECT date(log_date, 'weekday 0') AS wk_end, ma7_sql
    FROM ma7
),
wk_ma AS (                                 -- 周均体重均线（对应 wk_w.round(2)）
    SELECT wk_end, ROUND(AVG(ma7_sql), 2) AS wk_avg
    FROM wk
    WHERE ma7_sql IS NOT NULL              -- 剔除序列起点均线为 NULL 的日期
    GROUP BY wk_end
),
wk_speed AS (                              -- 周减重速度 = 相邻周均线之差（对应 diff）
    SELECT wk_end, wk_avg,
           ROUND(wk_avg - LAG(wk_avg) OVER (ORDER BY wk_end), 2) AS wow_kg
    FROM wk_ma
),
wk_kcal AS (                               -- 周均热量（仅 partial=0，对应 wk_kcal）
    SELECT date(log_date, 'weekday 0') AS wk_end,
           ROUND(AVG(calories), 0) AS wk_kcal,
           COUNT(*)                AS valid_days
    FROM daily_clean
    WHERE partial = 0
    GROUP BY wk_end
)
SELECT s.wk_end     AS 周止于,
       s.wk_avg     AS 周均均线,
       s.wow_kg     AS 周减重速度,
       k.wk_kcal    AS 周均热量,
       k.valid_days AS 有效热量天数
FROM wk_speed s
LEFT JOIN wk_kcal k ON k.wk_end = s.wk_end
ORDER BY s.wk_end;
