# results/ · 关键结果截图索引

> 全部为本人本地 SQLite（fitness.db）实跑截图，与 `sql/` 脚本一一对应；
> 每个数字均与 README「双实现对账总表」「验证层」及 `data_quality.md` 口径一致。

## 验证层（必看）

| 文件 | 对应脚本 | 关键读数 |
|---|---|---|
| 05_平台期_19天_日历轴.png | `05_plateau_detection.sql` | 最长段 09-08 ~ 09-26，19 天（gaps-and-islands，日历轴） |
| 06d_周训练密度.png | `06d_weekly_training_density.sql` | 第 39 周：记录 1 + 练了未记 2 = 真实 3 练（表面骤降为记录偏差） |
| 08_双口径gap对账.png | `08_caliber_gap.sql` ③ | 47 天 / mean 0.06 / max 0.275（09-28）；末端 49.21 vs 49.36 |
| 08_定点核对.png | `08_caliber_gap.sql` ④b | 08-28 / 09-10 / 09-28 三日两口径均线对照（缺失最密集段差异最大） |
| 09_插值留出_A1总览.png | `09_holdout_interp.sql` A-① | n=47 / mean 0.066 / max 0.417（09-21）/ 8 天 >0.1 |
| 09_均线平滑_B3总览.png | `09_holdout_interp.sql` B-③ | 经 7 日均线平滑后 max 0.032（约 13 倍稀释），平台期内 ≤0.025 |
| 10_记录日轴对照.png | `10_plateau_recaxis.sql` | 3 段（4/6/14 天），边界双向漂移 → 平台期判定必须锚定日历轴 |

## 主链（可选补充）

> 03a / 03b / 04 / 11 四张主链截图可按 `results截图指南.md` A 组随时补拍追加。
