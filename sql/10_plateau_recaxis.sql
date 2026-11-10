-- ============================================================
-- 10_plateau_recaxis.sql · 验证层：平台期判定 · 记录日轴对照实验
-- 与 05 对照：同一规则、同一阈值，仅去掉日历轴与插值
-- 实测结论：记录日轴上边界双向漂移 —— 8 月段被截短（8 → 6 天），
-- 9 月段延伸至 09-29（日历轴上 09-26 已结束）；"14 个记录日"与
-- "19 个日历日"不可比，平台期判定必须锚定日历轴
-- ============================================================
WITH rec AS (
    SELECT log_date, weight_kg
    FROM daily_clean
    WHERE weight_kg IS NOT NULL
),
ma AS (
    SELECT log_date, weight_kg AS w,
           COUNT(weight_kg) OVER w AS n_obs,
           AVG(weight_kg)   OVER w AS ma7_raw
    FROM rec
    WINDOW w AS (ORDER BY log_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW)
),
ma7 AS (
    SELECT log_date, ma7_raw FROM ma WHERE n_obs >= 3
),
flags AS (
    SELECT log_date, ma7_raw,
           CASE WHEN ABS(ma7_raw - LAG(ma7_raw) OVER (ORDER BY log_date)) < 0.1
                THEN 1 ELSE 0 END AS flat
    FROM ma7
),
islands AS (
    SELECT *,
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
SELECT r.start_day, r.end_day, r.days,
       ROUND(fs.ma7_raw, 2) AS ma_start,
       ROUND(fe.ma7_raw, 2) AS ma_end
FROM runs r
JOIN islands fs ON fs.log_date = r.start_day
JOIN islands fe ON fe.log_date = r.end_day
ORDER BY r.start_day;
