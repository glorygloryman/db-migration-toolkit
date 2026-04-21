# 函数映射表（MySQL → GaussDB B 兼容模式）

> B 模式原生提供大量 MySQL 函数。本表标注**已知差异点与需验证项**。
> 状态：✅ 直接可用 / ⚠️ 需验证 / 🔄 建议改写

## 字符串

| MySQL | GaussDB B 模式 | 状态 | 说明 |
|-------|----------------|------|------|
| `CONCAT(a, b, ...)` | 同 | ⚠️ | NULL 传播行为可能差异（MySQL NULL 参数返回 NULL） |
| `CONCAT_WS(sep, a, b, ...)` | 同 | ✅ | |
| `GROUP_CONCAT(col ORDER BY ... SEPARATOR ...)` | 同 | ✅ | B 模式支持 |
| `SUBSTRING(str, pos, len)` | 同 或 `SUBSTR` | ✅ | |
| `SUBSTRING_INDEX(str, delim, n)` | 同 | ⚠️ | B 模式支持 |
| `LEFT(str, n)` / `RIGHT(str, n)` | 同 | ✅ | |
| `LPAD(str, len, pad)` / `RPAD` | 同 | ✅ | |
| `LENGTH(str)`（字节长度） | 同 | ⚠️ | 注意字符集下字节数 |
| `CHAR_LENGTH(str)`（字符数） | 同 | ✅ | |
| `UPPER` / `LOWER` | 同 | ✅ | |
| `TRIM` / `LTRIM` / `RTRIM` | 同 | ✅ | |
| `REPLACE(str, from, to)` | 同 | ✅ | |
| `REVERSE(str)` | 同 | ✅ | |
| `FIND_IN_SET(s, list)` | 同 | ⚠️ | B 模式支持，需验证 |
| `LOCATE(sub, str)` / `INSTR` | 同 | ✅ | |
| `REGEXP` / `RLIKE` | 同 | ⚠️ | 正则语法差异，复杂正则需测 |
| `FORMAT(num, decimals)` | 同 | ⚠️ | 区域设置差异 |

## 数值

| MySQL | GaussDB B 模式 | 状态 | 说明 |
|-------|----------------|------|------|
| `ABS` / `CEIL` / `CEILING` / `FLOOR` / `ROUND` | 同 | ✅ | |
| `MOD(a, b)` / `a % b` | 同 | ✅ | |
| `POWER` / `POW` / `SQRT` / `EXP` / `LN` / `LOG` | 同 | ✅ | |
| `RAND()` | `RAND()` 或 `RANDOM()` | ⚠️ | B 模式两者可能都支持 |
| `TRUNCATE(num, d)` | 同 | ⚠️ | 与 SQL 关键字 TRUNCATE 表区分 |
| `GREATEST` / `LEAST` | 同 | ✅ | |
| `SIGN` | 同 | ✅ | |

## 日期时间

| MySQL | GaussDB B 模式 | 状态 | 说明 |
|-------|----------------|------|------|
| `NOW()` / `CURRENT_TIMESTAMP` | 同 | ⚠️ | 返回类型与精度验证 |
| `CURDATE()` / `CURRENT_DATE` | 同 | ✅ | |
| `CURTIME()` / `CURRENT_TIME` | 同 | ✅ | |
| `UNIX_TIMESTAMP(dt)` | 同 | ✅ | B 模式支持 |
| `FROM_UNIXTIME(ts)` | 同 | ✅ | |
| `DATE_FORMAT(dt, fmt)` | 同 | ⚠️ | 格式占位符逐一验证（`%Y-%m-%d` 等） |
| `STR_TO_DATE(str, fmt)` | 同 | ⚠️ | 同上 |
| `DATE_ADD(dt, INTERVAL n UNIT)` | 同 | ✅ | |
| `DATE_SUB(dt, INTERVAL n UNIT)` | 同 | ✅ | |
| `DATEDIFF(d1, d2)` | 同 | ⚠️ | 返回单位可能差异 |
| `TIMESTAMPDIFF(UNIT, d1, d2)` | 同 | ✅ | |
| `YEAR` / `MONTH` / `DAY` / `HOUR` / `MINUTE` / `SECOND` | 同 | ✅ | |
| `DAYOFWEEK` / `WEEKDAY` / `DAYOFYEAR` | 同 | ⚠️ | 周起始差异（MySQL 周日=1） |
| `WEEK(dt, mode)` | 同 | ⚠️ | mode 参数语义 |
| `LAST_DAY(dt)` | 同 | ✅ | |
| `MAKEDATE(year, day)` | 同 | ⚠️ | |
| `CONVERT_TZ(dt, from_tz, to_tz)` | 同 | ⚠️ | 时区数据依赖 |

## 流程控制

| MySQL | GaussDB B 模式 | 状态 | 说明 |
|-------|----------------|------|------|
| `IF(cond, a, b)` | 同 | ✅ | B 模式支持 |
| `IFNULL(a, b)` | 同 | ✅ | B 模式支持 |
| `NULLIF(a, b)` | 同 | ✅ | 标准 SQL |
| `COALESCE(a, b, ...)` | 同 | ✅ | 标准 SQL |
| `CASE ... WHEN ... THEN ... END` | 同 | ✅ | |
| `ISNULL(expr)` | 同 | ⚠️ | B 模式支持 |

## 聚合

| MySQL | GaussDB B 模式 | 状态 | 说明 |
|-------|----------------|------|------|
| `COUNT` / `SUM` / `AVG` / `MIN` / `MAX` | 同 | ✅ | |
| `GROUP_CONCAT` | 同 | ✅ | 分隔符与 ORDER BY 支持 |
| `BIT_AND` / `BIT_OR` / `BIT_XOR` | 同 | ⚠️ | |
| `STD` / `STDDEV` / `VARIANCE` | 同 或 `STDDEV_SAMP` 等 | ⚠️ | 样本/总体区分 |

## JSON

| MySQL | GaussDB B 模式 | 状态 | 说明 |
|-------|----------------|------|------|
| `JSON_EXTRACT(j, path)` / `j->'$.a'` | 同 | ⚠️ | 路径语法可能差异 |
| `JSON_UNQUOTE(j)` / `j->>'$.a'` | 同 | ⚠️ | |
| `JSON_OBJECT` / `JSON_ARRAY` | 同 | ⚠️ | |
| `JSON_CONTAINS` / `JSON_SEARCH` | 同 | ⚠️ | |
| `JSON_LENGTH` | 同 | ⚠️ | |

**JSON 为 Pilot 重点验证项**，把工程中所有 JSON 相关查询写成专项测试。

## 系统

| MySQL | GaussDB B 模式 | 状态 | 说明 |
|-------|----------------|------|------|
| `DATABASE()` | 同 或 `CURRENT_DATABASE()` | ⚠️ | |
| `USER()` / `CURRENT_USER()` | 同 | ⚠️ | |
| `VERSION()` | 同 | ⚠️ | 返回字符串格式不同 |
| `LAST_INSERT_ID()` | 同 | ⚠️ | 与 IDENTITY/SERIAL 配合 |
| `UUID()` | 同 或 `gen_random_uuid()` | ⚠️ | |

## 加密与编码

| MySQL | GaussDB B 模式 | 状态 | 说明 |
|-------|----------------|------|------|
| `MD5` / `SHA1` / `SHA2` | 同 | ⚠️ | |
| `AES_ENCRYPT` / `AES_DECRYPT` | 同 | ⚠️ | 密钥与模式参数 |
| `PASSWORD(str)` | 已废弃 | 🔄 | 建议应用层加密 |
| `HEX` / `UNHEX` | 同 | ✅ | |
| `TO_BASE64` / `FROM_BASE64` | 同 | ⚠️ | |

## 处理原则

1. **先假定兼容**：B 模式设计目标就是少改动
2. **关键函数必测**：凡打了 ⚠️ 的，Pilot 阶段专项测
3. **测出不兼容即记录**：写入本工程 `risk-matrix.md` 与工具包 `fix-issue/`
4. **函数不可用的 Fallback**：优先找等价函数，其次上移到 Java 层
