-- ============================================================
-- 01_data_quality.sql · 数据质量核查
-- 各字段缺失量、800 kcal 阈值可分性、部分记录日明细
-- ============================================================

-- ① 缺失统计与部分记录天数
SELECT COUNT(*)               AS rows_n,
       SUM(weight_kg IS NULL) AS w_miss,
       SUM(calories IS NULL)  AS kcal_miss,
       SUM(protein_g IS NULL) AS pro_miss,
       SUM(sleep_h IS NULL)   AS sleep_miss,
       SUM(partial)           AS partial_days
FROM daily_clean;
-- 预期：50 行；缺失 1 / 7 / 7 / 10；partial_days = 8
-- 注：数据质量文档记 7 天，实际 8 天（多出 09-08，见 ③）

-- ② 800 阈值的可分性：部分记录最大值 vs 完整记录最小值
SELECT MAX(CASE WHEN partial = 1 THEN calories END) AS max_partial,
       MIN(CASE WHEN partial = 0 THEN calories END) AS min_complete
FROM daily_clean;
-- 预期：720 / 840，800 落在空隙中间，阈值成立

-- ③ 部分记录日明细
SELECT log_date, calories
FROM daily_clean
WHERE calories IS NULL OR calories < 800
ORDER BY log_date;
-- 预期：8 行，比数据质量文档清单多 09-08
