-- ============================================================
-- 04_cardio_pace.sql · 问题二：分动作配速
-- 按速度区间推断动作类型（与 pandas 版同口径）
-- ============================================================
SELECT CASE WHEN cardio_km*1.0/train_min*60 >= 15 THEN '单车'
            WHEN cardio_km*1.0/train_min*60 >= 6  THEN '跑步'
            ELSE '游泳/快走' END AS action,
       COUNT(*) AS cnt,
       ROUND(MIN(cardio_km*1.0/train_min*60), 1) AS mn,
       ROUND(MAX(cardio_km*1.0/train_min*60), 1) AS mx,
       ROUND(AVG(cardio_km*1.0/train_min*60), 1) AS avg_pace
FROM daily_clean
WHERE cardio_km > 0 AND train_min > 0
GROUP BY 1
ORDER BY avg_pace DESC;
-- 预期：单车 n=4（17.1→24.2）、跑步 n=5（≈8.0）、游泳/快走 n=6（≈1.5）
