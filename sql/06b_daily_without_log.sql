-- ============================================================
-- 06b_daily_without_log.sql · 交叉检验 ②
-- 每日表标记训练日（is_train = 1），但训练日志无记录
-- ============================================================
SELECT c.log_date, c.train_min, c.cardio_km
FROM daily_clean c
LEFT JOIN (SELECT DISTINCT log_date FROM train_log) t
       ON t.log_date = c.log_date
WHERE c.is_train = 1 AND t.log_date IS NULL
ORDER BY c.log_date;
-- 预期：0 行（反向校验无差异）
