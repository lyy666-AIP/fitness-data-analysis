-- ============================================================
-- 00_date_spine.sql · 日历轴重建 + 缺失日定位
-- 递归 CTE 生成 MIN~MAX 记录日之间的连续日期序列，
-- 左连 daily_clean 反查无记录的日期（对应 pandas 的 full_range.difference）
-- ============================================================

-- ① 日历轴总天数
WITH RECURSIVE spine(d) AS (
    SELECT date(MIN(log_date)) FROM daily_clean
    UNION ALL
    SELECT date(d, '+1 day') FROM spine
    WHERE d < (SELECT MAX(log_date) FROM daily_clean)
)
SELECT COUNT(*) AS calendar_days FROM spine;
-- 预期：61

-- ② 缺失日清单
-- 注：CTE 仅作用于紧随其后的一条 SELECT，故这里重建一次 spine
WITH RECURSIVE spine(d) AS (
    SELECT date(MIN(log_date)) FROM daily_clean
    UNION ALL
    SELECT date(d, '+1 day') FROM spine
    WHERE d < (SELECT MAX(log_date) FROM daily_clean)
)
SELECT s.d AS missing_day
FROM spine s
LEFT JOIN daily_clean c ON c.log_date = s.d
WHERE c.log_date IS NULL
ORDER BY s.d;
-- 预期：11 行 —— 08-08 08-09 08-17 08-26 09-04 09-06 09-13 09-17 09-22 09-26 09-27
