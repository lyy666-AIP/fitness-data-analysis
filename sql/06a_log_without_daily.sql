-- ============================================================
-- 06a_log_without_daily.sql · 交叉检验 ①
-- 训练日志有记录，但每日表整行缺失（"练了未记"）
-- ============================================================
SELECT t.log_date
FROM (SELECT DISTINCT log_date FROM train_log) t
LEFT JOIN daily_clean c ON c.log_date = t.log_date
WHERE c.log_date IS NULL
ORDER BY t.log_date;
-- 预期：4 行 —— 09-13、09-17、09-22、09-26
