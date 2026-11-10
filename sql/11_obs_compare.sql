-- ============================================================
-- 11_obs_compare.sql · 验证层：训练日 vs 非训练日（观察性对比）
-- 观察性研究：只能谈关联、不能谈因果（声明见 README）
-- ============================================================

-- ⓪ 预检：确认实际列名（sleep_h / partial 若与下方查询不一致，按预检结果替换）
SELECT name FROM pragma_table_info('daily_clean');

-- ① 分组描述统计（实测：n=25/17，热量差 -64，睡眠差 -0.02）
SELECT is_train,
       COUNT(*)                AS n,
       ROUND(AVG(calories), 0) AS mean_cal,
       ROUND(AVG(sleep_h), 2)  AS mean_sleep
FROM daily_clean
WHERE partial = 0
GROUP BY is_train;

-- ② 热量差异的 Welch t 检验（手写版，报 t² 以不依赖 SQRT）
--    经验判定线：t² > 4 ≈ |t| > 2 ≈ 本样本量下近似显著
WITH g AS (
    SELECT is_train,
           COUNT(*) AS n,
           AVG(calories) AS m,
           (AVG(calories*calories) - AVG(calories)*AVG(calories))
             * COUNT(*) / (COUNT(*) - 1) AS v
    FROM daily_clean
    WHERE partial = 0
    GROUP BY is_train
),
a AS (SELECT * FROM g WHERE is_train = 1),
b AS (SELECT * FROM g WHERE is_train = 0)
SELECT ROUND(a.m - b.m, 0) AS diff_mean,
       ROUND((a.m - b.m) * (a.m - b.m) / (a.v/a.n + b.v/b.n), 2) AS t_sq
FROM a, b;

-- ③ 睡眠同款
WITH g AS (
    SELECT is_train,
           COUNT(*) AS n,
           AVG(sleep_h) AS m,
           (AVG(sleep_h*sleep_h) - AVG(sleep_h)*AVG(sleep_h))
             * COUNT(*) / (COUNT(*) - 1) AS v
    FROM daily_clean
    WHERE partial = 0
    GROUP BY is_train
),
a AS (SELECT * FROM g WHERE is_train = 1),
b AS (SELECT * FROM g WHERE is_train = 0)
SELECT ROUND(a.m - b.m, 2) AS diff_mean,
       ROUND((a.m - b.m) * (a.m - b.m) / (a.v/a.n + b.v/b.n), 2) AS t_sq
FROM a, b;
