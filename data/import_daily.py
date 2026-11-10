"""导入每日记录表：fitness_daily_clean.csv → SQLite（fitness.db / daily_clean）。

- 中文表头映射为英文短名（与 sql/ 层字段口径一致）
- partial 列统一为 0/1 整数
- 建表后用 typeof() 抽查存储类型与缺失分布
"""
import pandas as pd
import sqlite3

df = pd.read_csv("fitness_daily_clean.csv")
print(df.columns.tolist())
# ['日期', '体重(kg)', '总热量(kcal)', '蛋白质(g)', '睡眠时长(小时)',
#  '是否训练日(0/1)', '饮食是否记完整(0/1)', '备注', '部分记录', '特殊事件',
#  '训练分钟', '有氧距离', '体重7日均值', '有氧配速', '周']

df.columns = df.columns.str.strip()
df = df.rename(columns={
    "日期": "log_date",
    "体重(kg)": "weight_kg",
    "总热量(kcal)": "calories",
    "蛋白质(g)": "protein_g",
    "睡眠时长(小时)": "sleep_h",
    "是否训练日(0/1)": "is_train",
    "饮食是否记完整(0/1)": "diet_complete",
    "备注": "note",
    "部分记录": "partial",
    "特殊事件": "special_event",
    "训练分钟": "train_min",
    "有氧距离": "cardio_km",
    "体重7日均值": "ma7_py",
    "有氧配速": "pace_py",
    "周": "iso_week",
})

required = ["log_date", "weight_kg", "calories", "protein_g", "sleep_h",
            "is_train", "diet_complete", "note", "partial", "special_event",
            "train_min", "cardio_km", "ma7_py", "pace_py", "iso_week"]
missing = [c for c in required if c not in df.columns]
if missing:
    raise ValueError(f"这些列没改名成功（CSV表头和字典键不一致）：{missing}")

df["partial"] = df["partial"].astype(bool).astype(int)

conn = sqlite3.connect("fitness.db")
df.to_sql("daily_clean", conn, if_exists="replace", index=False)
print(pd.read_sql(
    "SELECT typeof(weight_kg), typeof(partial), COUNT(*) "
    "FROM daily_clean GROUP BY 1, 2", conn))
# 预期：null / integer 1 行（首两日体重缺失），real / integer 49 行
