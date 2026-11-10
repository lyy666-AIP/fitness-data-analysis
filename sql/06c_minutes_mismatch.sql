-- ============================================================
-- 06c_minutes_mismatch.sql · 交叉检验 ③
-- 两边都有记录但训练时长对不上（SQL 版新增的量级一致性校验）
-- 口径：每日表 train_min = 训练日志当天各行 duration_min 之和
-- ============================================================
SELECT c.log_date,
       c.train_min               AS daily_min,
       ROUND(t.total_min, 0)     AS trainlog_min,
       c.train_min - t.total_min AS diff_min
FROM daily_clean c
JOIN (
    SELECT log_date, SUM(duration_min) AS total_min
    FROM train_log
    GROUP BY log_date
) t ON t.log_date = c.log_date
WHERE ABS(c.train_min - t.total_min) > 1;
-- 预期：0 行（如有命中，回原始 Excel 逐行核对）
