-- ============================================================
-- 06d_weekly_training_density.sql · 问题四：每周真实训练天数
-- 日历轴 = 两表并集，修复"练了未记"造成的统计盲区
-- ============================================================
WITH RECURSIVE spine(d) AS (
    SELECT date(MIN(log_date)) FROM daily_clean
    UNION ALL
    SELECT date(d, '+1 day') FROM spine
    WHERE d < (SELECT MAX(log_date) FROM daily_clean)
),
wk AS (                                    -- 每个日历日 → 所属周（止于周日）
    SELECT d, date(d, 'weekday 0') AS wk_end FROM spine
),
merged AS (                                -- 日历轴同时左连两张表
    SELECT k.wk_end,
           c.log_date AS rec_date,         -- 每日表当日有记录
           c.is_train AS rec_train,        -- 每日表标记的训练日
           t.log_date AS tl_date,          -- 训练日志当日有记录
           CASE WHEN c.log_date IS NULL AND t.log_date IS NOT NULL
                THEN 1 ELSE 0 END AS trained_unlogged   -- 练了未记
    FROM wk k
    LEFT JOIN daily_clean c ON c.log_date = k.d
    LEFT JOIN (SELECT DISTINCT log_date FROM train_log) t ON t.log_date = k.d
)
SELECT wk_end                                 AS 周止于,
       COUNT(rec_date)                        AS 记录天数,
       SUM(rec_train)                         AS 已记录训练天,
       SUM(trained_unlogged)                  AS 练了未记,
       SUM(rec_train) + SUM(trained_unlogged) AS 真实训练天,
       ROUND((SUM(rec_train) + SUM(trained_unlogged)) / 7.0, 2) AS 周训练密度
FROM merged
GROUP BY wk_end
ORDER BY wk_end;
