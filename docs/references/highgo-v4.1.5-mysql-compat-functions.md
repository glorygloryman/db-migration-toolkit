# 瀚高 v4.1.5 MySQL 函数兼容脚本说明

> **脚本位置**：`docs/references/highgo-v4.1.5-mysql-compat-functions.sql`
> **来源**：瀚高厂家提供（C10：适用版本范围 ⚠️ 待 Pilot 核实）
> **版权**：⚠️ 待 Pilot 核实（C8）
> **注入时机**：Stage 2（目标库一次性预装，先于 Schema 迁移）
> **注入权限**：⚠️ 待 Pilot 核实（C9，暂按建库 owner 权限）
> **版本标记**：脚本末尾 `mysql_compat_version()` 返回形如 `1.0.0-highgo-v4.1.5-vendor-2026-04-21`

## 覆盖的 MySQL 函数清单

| MySQL 函数 | 脚本内函数签名 | 用途 | 注意 |
|-----------|---------------|------|------|
| `MOD(text, int)` | `mod(text_val text, mod_val integer) → integer` | 文本转整数后取模 | 转换失败或除零返回 NULL（不抛错，与 MySQL 行为略异） |
| `IFNULL(a, b)` | 4 个重载：integer / numeric / varchar / text | NULL 兜底 | **不含 timestamp/date 重载**，时间类型需显式 `COALESCE` |
| `SUBSTRING(text, bigint)` | `substring(pi_1 text, pi_2 bigint) → text` | 大整数偏移量支持 | 内部转 int 调用原生 substring |
| `CURDATE()` | `curdate() → date` | 当前日期 | 等价 `CURRENT_DATE` |
| `IF(cond, true_val, false_val)` | 3 个重载：DATE / TIMESTAMPTZ / BOOLEAN | 三目表达式 | **不含 numeric/text/int 重载**，需补齐或改 `CASE WHEN` |
| `DATE_FORMAT(timestamptz, text)` | `date_format(date_val, format_str) → text` | MySQL 格式符日期格式化 | **⚠️ 内部递归调用 DATE_FORMAT**，需确认瀚高是否已原生支持；若否此函数会栈溢出 |
| `YEAR(timestamptz)` | `year(inDate) → int4` | 取年份 | 等价 `EXTRACT(YEAR FROM ...)` |
| `MONTH(timestamptz)` | `month(inDate) → integer` | 取月份 | 等价 `EXTRACT(MONTH FROM ...)` |
| `FIND_IN_SET(text, text)` | `find_in_set(target, strlist) → integer` | 逗号分隔列表查找 | 基于 `string_to_array` 实现 |
| `STR_TO_DATE(text, text)` | `str_to_date(create_time, format_pattern) → timestamp` | MySQL 格式符解析时间 | 含 MySQL→PG 格式符转换与异常兜底 |
| `LAST_DAY(date)` | `last_day(p_date) → date` | 月末日期 | |
| `TRUNCATE(numeric, int)` | `truncate(p_number, p_decimals) → numeric` | 截断到指定小数位 | 调用 PG 原生 `TRUNC`；⚠️ 除法场景须显式 `::numeric` |
| `DAYOFYEAR(timestamptz)` | `dayofyear(p_date) → integer` | 年内第几天 | 等价 `EXTRACT(DOY FROM ...)` |
| `TO_DAYS(timestamp/date)` | 2 个重载 | MySQL 自公元起天数 | 实测有微小偏差，财务/审计勿依赖 |

## 使用注意

1. **函数仅覆盖，不覆盖语法**：反引号、`LIMIT m,n`、`ON DUPLICATE KEY UPDATE` 等语法**仍需应用层改写**
2. **`DATE_FORMAT` 递归风险**：脚本内 `date_format` 实现调用了大写 `DATE_FORMAT(...)`。若瀚高 v4.1.5 未原生提供 `DATE_FORMAT`，将无限递归栈溢出。**Pilot 首验证项**（见 R-002）
3. **`IF` 函数类型缺口**：仅 DATE/TIMESTAMPTZ/BOOLEAN 三个重载。工程使用 `IF(cond, int, int)` / `IF(cond, text, text)` 必须改写为 `CASE WHEN`
4. **`IFNULL` 类型缺口**：无 timestamp/date 重载。时间类型改 `COALESCE`
5. **`MOD` 与原生行为**：脚本版本吞 NULL 返回而非抛错，与 MySQL 严格模式行为不一致
6. **幂等注入**：脚本全部 `CREATE OR REPLACE FUNCTION`，重复执行安全

## 版本管理（per decision）

- 脚本末尾 `mysql_compat_version()` 返回版本字符串
- 下游工程 Stage 2 注入完成后执行 `SELECT mysql_compat_version()` 记录到 baseline
- 脚本任何改动（修 bug、补重载）须 bump 版本号并记 CHANGELOG
- Pilot 工程发现厂家有更新版本，先 PR 到本仓库、bump 版本标记、再下发

## 何时不需要使用

- 瀚高后续版本原生提供全部 MySQL 函数 → 本脚本退役
- 改造策略选择"全部 MySQL 函数在应用层替换为 PG 等价调用" → 不注入（工作量显著增大，不推荐）

## 关联决策

- [`project-docs/decisions/2026-04-21-use-vendor-mysql-compat-functions.md`](../../project-docs/decisions/2026-04-21-use-vendor-mysql-compat-functions.md)
- [`project-docs/decisions/2026-04-21-target-db-highgo-v4.md`](../../project-docs/decisions/2026-04-21-target-db-highgo-v4.md)

## 关联风险

- R-002 🔴 DATE_FORMAT 递归风险
- R-015 🟡 脚本重载类型缺口
- R-017 🟡 兼容脚本版本管理
