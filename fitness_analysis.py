# -*- coding: utf-8 -*-
"""
健身数据分析：热量调整效果评估 / 有氧过程指标 / 平台期规则判定
口径说明：
- 趋势图使用"日历版"体重7日均值：先重建61天日历索引再插值 + 7日固定窗口
  （原始CSV的7日均值列是"记录日口径"，中间隔缺失日，直接画趋势会失真）
- 周度汇总（周均热量、周减重速度）用"记录日口径"，与 data_quality.md 一致
"""

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import matplotlib.dates as mdates
from pathlib import Path

# 中文显示（字体列表含回退，Win/Mac/Linux 都能跑
plt.rcParams["font.sans-serif"] = ["SimHei", "Noto Sans SC", "WenQuanYi Zen Hei", "Arial Unicode MS"]
plt.rcParams["axes.unicode_minus"] = False

# ---------- 路径（默认读取同目录下的 fitness_daily_clean.csv，图表输出到同目录 charts/） ----------
BASE = Path(__file__).resolve().parent
OUT = BASE / "charts"
OUT.mkdir(parents=True, exist_ok=True)

# ---------- 读数据 ----------
daily = pd.read_csv(BASE / "fitness_daily_clean.csv")
daily["日期"] = pd.to_datetime(daily["日期"])

# 日历版均线：重建日历索引填充缺失日，再计算7日均线
full_range = pd.date_range(daily["日期"].min(), daily["日期"].max(), freq="D")
full = daily.set_index("日期").reindex(full_range)          # 缺失日变成新行（NaN）
full["体重7日均值"] = (
    full["体重(kg)"].interpolate(method="time").rolling(7, min_periods=3).mean()
)
# 趋势图改用 full["体重7日均值"]；周度汇总仍用 daily（口径已在报告里注明）
# 采用日历版均线

print("=" * 60)
print("[填充校验] 日历天数: %d, 实际记录: %d, 补出空行: %d"
      % (len(full), daily["体重(kg)"].notna().sum(), len(full) - len(daily)))
print("[填充校验] 新均线首末值: %.2f -> %.2f kg" % (full["体重7日均值"].iloc[0], full["体重7日均值"].iloc[-1]))

# =====================================================================
# 问题1：热量上调后，减重是变慢了还是变稳了？
# =====================================================================
# 只用部分记录=False 的日子算摄入
ok = daily[daily["部分记录"] == False]  # noqa: E712
monthly = ok.groupby(ok["日期"].dt.month)[["总热量(kcal)", "蛋白质(g)"]].mean().round(0)
monthly.index = ["8月", "9月"]
print("\n[问题1] 月均热量/蛋白质（仅 部分记录=False，n=%d 天）" % len(ok))
print(monthly)

# 周减重速度：周度取 体重7日均值 的均值，再 diff（W-SUN周期 = ISO周，周一~周日）
wk_w = full.groupby(full.index.to_period("W-SUN"))["体重7日均值"].mean()
wk_speed = wk_w.diff().round(2)
wk_kcal = ok.groupby(ok["日期"].dt.to_period("W-SUN"))["总热量(kcal)"].mean().round(0)
wk_kcal_ts = wk_kcal.index.to_timestamp(freq="W-SUN")
print("\n[问题1] 周减重速度（kg/周，日历版均线的周均值之差）")
print(pd.DataFrame({"周均体重7日均线": wk_w.round(2), "周减重速度": wk_speed,
                    "周均热量": wk_kcal}).rename_axis("周(止于周日)"))

# ---- 图1：上=体重均线折线，下=周均热量柱状 ----
fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(11, 7), sharex=True,
                               gridspec_kw={"height_ratios": [3, 2]})
ax1.plot(full.index, full["体重7日均值"], color="#d62728", lw=2,
         label="体重7日均值（日历版，插值后）")
ax1.scatter(daily["日期"], daily["体重(kg)"], s=18, color="#7f7f7f", alpha=.6,
            label="实际称重（记录日）")
ax1.axvline(pd.Timestamp("2026-09-01"), color="#1f77b4", ls="--", lw=1, alpha=.8)
ax1.annotate("9月起热量上调", xy=(pd.Timestamp("2026-09-02"), 53.1),
             fontsize=9, color="#1f77b4")
hot = daily[daily["特殊事件"] == "放纵餐"]
ax1.scatter(hot["日期"], hot["体重(kg)"], s=60, marker="v", color="#ff7f0e", zorder=5,
            label="火锅放纵餐 08-30")
ax1.set_ylabel("体重 (kg)")
ax1.set_title("问题1：体重7日均值趋势 vs 周均热量（8月 vs 9月）")
ax1.legend(loc="lower left", fontsize=9)
ax1.grid(alpha=.3)

colors = ["#1f77b4" if t.month == 8 else "#2ca02c" for t in wk_kcal_ts]
ax2.bar(wk_kcal_ts, wk_kcal.values, width=5.5,
        color=colors, alpha=.85)
m8, m9 = monthly.loc["8月", "总热量(kcal)"], monthly.loc["9月", "总热量(kcal)"]
ax2.axhline(m8, color="#1f77b4", ls=":", lw=1.2)
ax2.axhline(m9, color="#2ca02c", ls=":", lw=1.2)
ax2.text(wk_kcal_ts[0], m8 + 15, f"8月均值 {m8:.0f}", fontsize=8, color="#1f77b4",
         bbox=dict(fc="white", alpha=.7, ec="none"))
ax2.text(wk_kcal_ts[0], m9 + 15, f"9月均值 {m9:.0f}", fontsize=8, color="#2ca02c",
         bbox=dict(fc="white", alpha=.7, ec="none"))
ax2.set_ylabel("周均热量 (kcal)")
ax2.set_xlabel("日期（周）")
ax2.grid(alpha=.3, axis="y")
fig.tight_layout()
fig.savefig(OUT / "图1_体重趋势与周均热量.png", dpi=150)
plt.close(fig)

# =====================================================================
# 问题2：有氧表现进步了吗？
# =====================================================================
# 有氧配速这里实为"速度 km/h" = 有氧距离 / 训练分钟 * 60（原CSV该列同口径，个别行缺字段）
m = (daily["有氧距离"] > 0) & (daily["训练分钟"] > 0)
cardio = daily.loc[m, ["日期", "有氧距离", "训练分钟"]].copy()
cardio["速度km/h"] = (cardio["有氧距离"] / cardio["训练分钟"] * 60).round(2)

def action(v):
    if v >= 15:  return "单车(≥15)"
    if v >= 6:   return "跑步(6~12)"
    return "游泳/快走(<3)"
cardio["动作(按速度区间推断)"] = cardio["速度km/h"].apply(action)
print("\n[问题2] 有氧速度分组统计（km/h）")
print(cardio.groupby("动作(按速度区间推断)")["速度km/h"]
      .agg(次数="count", 最小="min", 最大="max", 均值="mean").round(2))
print("\n[问题2] 单车逐次记录：")
print(cardio[cardio["动作(按速度区间推断)"].str.startswith("单车")]
      [["日期", "速度km/h"]].to_string(index=False))

# ---- 图2：散点图，不同动作不同颜色 ----
fig, ax = plt.subplots(figsize=(11, 5))
palette = {"单车(≥15)": "#d62728", "跑步(6~12)": "#1f77b4", "游泳/快走(<3)": "#2ca02c"}
for name, g in cardio.groupby("动作(按速度区间推断)"):
    ax.scatter(g["日期"], g["速度km/h"], s=55, color=palette[name], label=name, alpha=.85)
ax.set_title("问题2：有氧运动速度随时间的变化（速度=有氧距离/训练分钟×60，动作按速度区间推断）")
ax.set_ylabel("速度 (km/h)")
ax.set_xlabel("日期")
ax.legend(title="动作", loc="upper left")
ax.grid(alpha=.3)
ax.xaxis.set_major_formatter(mdates.DateFormatter("%m-%d"))
fig.tight_layout()
fig.savefig(OUT / "图2_有氧速度散点图.png", dpi=150)
plt.close(fig)

# =====================================================================
# 问题3：平台期到底在哪几天？
# =====================================================================
# 找 体重7日均线 连续多日日变化 < 0.1 kg 的区间（用日历版均线）
d = full["体重7日均值"].diff().abs()
flat = (d < 0.1) & d.notna()
runs, start = [], None
for dt, flag in flat.items():
    if flag and start is None:
        start = dt
    elif not flag and start is not None:
        runs.append((start, dt - pd.Timedelta(days=1)))
        start = None
if start is not None:
    runs.append((start, flat.index[-1]))
plateaus = [(s, e) for s, e in runs if (e - s).days >= 3]  # 连续≥4天
print("\n[问题3] 均线连续≥4天日变化<0.1kg 的平台期区间：")
for s, e in plateaus:
    seg = full.loc[s:e, "体重7日均值"]
    print("  %s ~ %s（%d天，均线 %.2f -> %.2f）" % (s.date(), e.date(), (e - s).days + 1, seg.iloc[0], seg.iloc[-1]))

# ---- 图3：体重散点 + 均线 + axvspan标平台期 ----
fig, ax = plt.subplots(figsize=(11, 5.5))
ax.scatter(daily["日期"], daily["体重(kg)"], s=22, color="#7f7f7f", alpha=.6, label="实际称重（记录日）")
ax.plot(full.index, full["体重7日均值"], color="#d62728", lw=2, label="体重7日均值（日历版）")
for i, (s, e) in enumerate(plateaus):
    ax.axvspan(s, e, color="#ffcc00", alpha=.3,
               label="平台期（均线日变化<0.1kg，连续≥4天）" if i == 0 else None)
hot2 = daily[daily["特殊事件"] == "放纵餐"]
ax.scatter(hot2["日期"], hot2["体重(kg)"], s=60, marker="v", color="#ff7f0e", zorder=5, label="火锅放纵餐 08-30")
ax.set_title("问题3：平台期定位（体重7日均线连续≥4天日变化<0.1kg）")
ax.set_ylabel("体重 (kg)")
ax.set_xlabel("日期")
ax.legend(loc="lower left", fontsize=9)
ax.grid(alpha=.3)
ax.xaxis.set_major_formatter(mdates.DateFormatter("%m-%d"))
fig.tight_layout()
fig.savefig(OUT / "图3_平台期定位.png", dpi=150)
plt.close(fig)

# =====================================================================
# 问题4（可选）：每周训练天数的演变
# =====================================================================
wk_train = daily.groupby(daily["日期"].dt.to_period("W-SUN"))["是否训练日(0/1)"].sum()
wk_train_lbl = wk_train.index.to_timestamp(freq="W-SUN").strftime("%m-%d")
print("\n[问题4] 每周训练天数：")
print(wk_train.to_string())

fig, ax = plt.subplots(figsize=(10, 4))
ax.bar(wk_train_lbl, wk_train.values, color="#9467bd", alpha=.85)
ax.set_title("问题4：每周训练天数（记录日口径）")
ax.set_ylabel("训练天数 (天)")
ax.set_xlabel("所在周（周日结尾）")
ax.set_ylim(0, 7)
for x, v in enumerate(wk_train.values):
    ax.text(x, v + 0.1, str(int(v)), ha="center", fontsize=9)
ax.grid(alpha=.3, axis="y")
fig.tight_layout()
fig.savefig(OUT / "图4_每周训练天数.png", dpi=150)
plt.close(fig)

print("\n图表已保存到:", OUT)
