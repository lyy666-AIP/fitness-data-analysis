-- ============================================================
-- 03a_monthly_summary.sql · 问题一：月均热量 / 蛋白质
-- 仅统计完整记录日（partial = 0），对齐 pandas 版月度表
-- ============================================================
SELECT CASE WHEN strftime('%m', log_date) = '08' THEN '8月' ELSE '9月' END AS 月份,
       ROUND(AVG(calories), 0)  AS 月均热量,
       ROUND(AVG(protein_g), 0) AS 月均蛋白质,
       COUNT(*)                 AS 有效天数,
       SUM(protein_g IS NULL)   AS 蛋白质缺失
FROM daily_clean
WHERE partial = 0
GROUP BY 1
ORDER BY 1;
-- 预期：8月 956 / 73 / 23 天 / 缺 2；9月 1245 / 92 / 19 天 / 缺 1；合计 n = 42
-- （AVG 自动跳过 NULL，与 pandas monthly 行为一致）
-- 蛋白质缺失行：08-19、08-24、09-09，其中 2 行在 8 月
