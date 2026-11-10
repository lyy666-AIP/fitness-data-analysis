"""导入训练日志：健身数据记录表（有数据）.xlsx → SQLite（fitness.db / train_log）。

- 读取 sheet「2-训练记录」，中文表头映射为英文短名
- log_date 统一为 'YYYY-MM-DD' 文本（与 daily_clean 口径一致）
- 建表后核对总行数与覆盖天数
"""
import pandas as pd
import sqlite3

train = pd.read_excel("健身数据记录表（有数据）.xlsx", sheet_name="2-训练记录")
train = train.rename(columns={
    "日期": "log_date",
    "时长(分钟)": "duration_min",
    "距离(km)": "distance_km",
    "训练动作": "action",
})
train["log_date"] = pd.to_datetime(train["log_date"]).dt.strftime("%Y-%m-%d")

conn = sqlite3.connect("fitness.db")
train.to_sql("train_log", conn, if_exists="replace", index=False)
print(pd.read_sql(
    "SELECT COUNT(*) AS rows_n, COUNT(DISTINCT log_date) AS days "
    "FROM train_log", conn))
# 预期：rows_n = 36（按动作逐行记录，同一天可有多行），days = 32
