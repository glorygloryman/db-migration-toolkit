# 函数映射表（MySQL → 瀚高 v4.1.5）

> 瀚高数据库 v4.1.5 基于 PostgreSQL 内核，**不具备类似 GaussDB B 模式的 MySQL 兼容层**；MySQL 专属函数通过**厂家提供的兼容脚本**（见 `./highgo-v4.1.5-mysql-compat-functions.md` 与同目录下 `highgo-v4.1.5-mysql-compat-functions.sql`）在目标库内以 SQL/PLPGSQL 函数方式重建，从而抹平常见函数差异。
>
> 本表针对每一个 MySQL 函数判定：**脚本是否覆盖**、**PG 原生是否等价**，以及最终落地的改写动作。工程实施顺序建议：先执行兼容脚本 → 扫描剩余函数 → 针对未覆盖项按本表逐条改写。
>
> **脚本覆盖列**：🛡️ 已由厂家兼容脚本覆盖，业务代码可免改 / — 脚本未覆盖，需人工改写或依赖 PG 原生
>
> **状态列**：✅ PG 原生直接可用 / ⚠️ 需验证（行为差异或边界风险） / 🔄 需改写为 PG 原生等价 / ❌ 不支持

---

## 字符串

| MySQL | 瀚高 v4.1.5 目标写法 | 脚本覆盖 | 状态 | 说明 |
|-------|---------------------|:-------:|:----:|------|
| `CONCAT(a, b, ...)` | `CONCAT(a, b, ...)`（PG 原生） | — | ⚠️ | PG `CONCAT` 对 NULL 参数按空串处理，MySQL 在任一参数为 NULL 时返回 NULL；NULL 语义敏感场景需改写为 `a \|\| b` 或显式判空 |
| `CONCAT_WS(sep, a, b, ...)` | 同 | — | ✅ | PG 原生等价 |
| `GROUP_CONCAT(col ORDER BY ... SEPARATOR s)` | `STRING_AGG(col::text, s ORDER BY ...)` | — | 🔄 | 必须显式转 `text`；`SEPARATOR` 关键字改为逗号参数 |
| `SUBSTRING(str, pos)` / `SUBSTRING(str, pos, len)` | 脚本重载 `substring(text, bigint)` / `substring(text, bigint, bigint)` | 🛡️ | ✅ | 脚本补齐了 `bigint` 位置/长度的重载；PG 原生仅支持 `int`，未打脚本会因类型推断失败 |
| `SUBSTRING_INDEX(str, delim, n)` | `SPLIT_PART(str, delim, n)` + 负数场景自写 | — | 🔄 | PG `SPLIT_PART` 不支持负数，负数场景需 `REVERSE` 或 `regexp_split_to_array` |
| `LEFT(str, n)` / `RIGHT(str, n)` | 同 | — | ✅ | PG 原生等价 |
| `LPAD(str, len, pad)` / `RPAD` | 同 | — | ✅ | PG 原生等价 |
| `LENGTH(str)`（MySQL 语义：字节长度） | `OCTET_LENGTH(str)` | — | 🔄 | PG `LENGTH` 返回**字符数**而非字节，与 MySQL `LENGTH` 不同；按字节统计必须换 `OCTET_LENGTH` |
| `CHAR_LENGTH(str)` | 同 | — | ✅ | PG 原生等价 |
| `UPPER` / `LOWER` / `TRIM` / `LTRIM` / `RTRIM` | 同 | — | ✅ | PG 原生等价 |
| `REPLACE(str, from, to)` | 同 | — | ✅ | PG 原生等价 |
| `REVERSE(str)` | 同 | — | ✅ | PG 原生等价 |
| `FIND_IN_SET(s, list)` | 脚本提供同名函数 | 🛡️ | ✅ | 业务代码可原样保留 |
| `LOCATE(sub, str)` / `INSTR(str, sub)` | `STRPOS(str, sub)` 或 `POSITION(sub IN str)` | — | 🔄 | 参数顺序与 MySQL 相反，改写时注意不要写反 |
| `REGEXP` / `RLIKE` | `~`（区分大小写）/ `~*`（不区分） | — | 🔄 | 运算符形式；正则语法按 POSIX，复杂正则需逐条回归 |
| `FORMAT(num, decimals)` | `TO_CHAR(num, 'FM999,999,990.00')` | — | 🔄 | PG 无同名等价，需自构格式串；区域设置差异明显 |

---

## 数值

| MySQL | 瀚高 v4.1.5 目标写法 | 脚本覆盖 | 状态 | 说明 |
|-------|---------------------|:-------:|:----:|------|
| `ABS` / `CEIL` / `CEILING` / `FLOOR` / `ROUND` | 同 | — | ✅ | PG 原生等价 |
| `MOD(a, b)` | 脚本提供 `mod(text, int)` 等重载 | 🛡️ | ⚠️ | 脚本异常行为：MySQL 在除零时抛错，兼容脚本返回 NULL；业务若依赖报错需额外判空或包一层 |
| `a % b` | 同（PG 运算符） | — | ✅ | 类型匹配时可直接用 |
| `POWER` / `POW` / `SQRT` / `EXP` / `LN` / `LOG` | 同 | — | ✅ | PG 原生等价 |
| `RAND()` | `RANDOM()` | — | 🔄 | PG 无 `RAND`，必须改名 |
| `TRUNCATE(num, d)` | 脚本提供同名函数（包装 `TRUNC`） | 🛡️ | ⚠️ | 脚本内部用 `TRUNC`；**整数除法场景**仍需显式 `::numeric` 防整除截断（参考 `fix-issue` 中整数除法规避） |
| `GREATEST` / `LEAST` | 同 | — | ✅ | PG 原生等价 |
| `SIGN` | 同 | — | ✅ | PG 原生等价 |

---

## 日期时间

| MySQL | 瀚高 v4.1.5 目标写法 | 脚本覆盖 | 状态 | 说明 |
|-------|---------------------|:-------:|:----:|------|
| `NOW()` / `CURRENT_TIMESTAMP` | 同 | — | ⚠️ | PG 返回 `timestamptz`，需确认业务是否依赖无时区 `datetime` |
| `CURDATE()` | 脚本提供同名函数 | 🛡️ | ✅ | 业务代码可原样保留 |
| `CURRENT_DATE` | 同 | — | ✅ | PG 原生等价 |
| `CURTIME()` / `CURRENT_TIME` | 同 | — | ✅ | PG 原生等价 |
| `UNIX_TIMESTAMP(dt)` | `EXTRACT(EPOCH FROM dt)::bigint` | — | 🔄 | PG 无 `UNIX_TIMESTAMP`；注意返回值类型显式转换 |
| `FROM_UNIXTIME(ts)` | `TO_TIMESTAMP(ts)` | — | 🔄 | 返回 `timestamptz`，必要时再 `::timestamp` |
| `DATE_FORMAT(dt, fmt)` | 脚本提供同名函数（内部映射到 `TO_CHAR`） | 🛡️ | ⚠️ | **递归风险**：脚本实现中若与 `TO_CHAR` 存在相互调用，在复杂嵌套或 JIT 场景下可能栈溢出；Pilot 必须压测 + 回归 |
| `STR_TO_DATE(str, fmt)` | 脚本提供同名函数（内部映射到 `TO_TIMESTAMP`/`TO_DATE`） | 🛡️ | ⚠️ | 格式占位符需按脚本实现逐个比对，`%Y-%m-%d %H:%i:%s` 等组合必测 |
| `DATE_ADD(dt, INTERVAL n UNIT)` / `DATE_SUB` | `dt + INTERVAL 'n unit'` / `dt - INTERVAL 'n unit'` | — | 🔄 | PG 无 `DATE_ADD/DATE_SUB`，统一改 `INTERVAL` 表达式 |
| `DATEDIFF(d1, d2)` | `(d1::date - d2::date)` | — | 🔄 | PG 日期相减直接得整数天数；MySQL 语义为 `d1 - d2`，注意参数顺序 |
| `TIMESTAMPDIFF(UNIT, d1, d2)` | 按 UNIT 组合 `EXTRACT` + `AGE` | — | 🔄 | 无直接等价，按 UNIT 自写；`SECOND/MINUTE/HOUR` 可用 `EXTRACT(EPOCH FROM (d2-d1))` 再除 |
| `YEAR(dt)` | 脚本提供同名函数 | 🛡️ | ✅ | 业务代码可原样保留 |
| `MONTH(dt)` | 脚本提供同名函数 | 🛡️ | ✅ | 同上 |
| `DAY(dt)` / `HOUR(dt)` / `MINUTE(dt)` / `SECOND(dt)` | `EXTRACT(DAY FROM dt)` 等 | — | 🔄 | 脚本未覆盖这组，必须改 `EXTRACT` |
| `DAYOFYEAR(dt)` | 脚本提供同名函数 | 🛡️ | ✅ | 业务代码可原样保留 |
| `DAYOFWEEK(dt)` | `EXTRACT(DOW FROM dt) + 1` | — | 🔄 | **周起始差异**：MySQL `DAYOFWEEK` 周日=1，PG `DOW` 周日=0，必须 +1 对齐；`WEEKDAY` 语义又不同需单独处理 |
| `WEEK(dt, mode)` | `EXTRACT(WEEK FROM dt)` 或自写 | — | ⚠️ | `mode` 参数语义在 PG 无对应，多种起始规则需自定义 |
| `LAST_DAY(dt)` | 脚本提供同名函数 | 🛡️ | ✅ | 业务代码可原样保留 |
| `TO_DAYS(dt)` | 脚本提供同名函数 | 🛡️ | ⚠️ | **已知偏差**：脚本实现与 MySQL 结果在历法边界可能有 1~2 天偏差，涉及历史对账字段需验证 |
| `MAKEDATE(year, day)` | `(make_date(year,1,1) + (day-1))` | — | 🔄 | 无直接等价，需组合 |
| `CONVERT_TZ(dt, from_tz, to_tz)` | `dt AT TIME ZONE from_tz AT TIME ZONE to_tz` | — | 🔄 | 时区数据需完整部署 tzdata |

---

## 流程控制

| MySQL | 瀚高 v4.1.5 目标写法 | 脚本覆盖 | 状态 | 说明 |
|-------|---------------------|:-------:|:----:|------|
| `IF(cond, a, b)` | 脚本提供部分重载 | 🛡️⚠️ | ⚠️ | **脚本只覆盖 `DATE`/`TIMESTAMPTZ`/`BOOLEAN` 返回类型**；`int`/`numeric`/`text`/`varchar` 等常用类型未重载，遇到缺口必须改写为 `CASE WHEN cond THEN a ELSE b END` |
| `IFNULL(a, b)` | 脚本提供部分重载 / `COALESCE(a, b)` | 🛡️⚠️ | ⚠️ | 脚本重载**不含 `date`/`timestamp`/`timestamptz`/`bigint`**，这些类型一律改 `COALESCE`；`COALESCE` 是标准 SQL，推荐默认策略 |
| `NULLIF(a, b)` | 同 | — | ✅ | 标准 SQL，PG 原生 |
| `COALESCE(a, b, ...)` | 同 | — | ✅ | 标准 SQL，PG 原生 |
| `CASE ... WHEN ... THEN ... END` | 同 | — | ✅ | 标准 SQL，PG 原生 |
| `ISNULL(expr)` | `expr IS NULL` | — | 🔄 | PG 无 `ISNULL` 函数形式，改为 `IS NULL` 谓词 |

---

## 聚合

| MySQL | 瀚高 v4.1.5 目标写法 | 脚本覆盖 | 状态 | 说明 |
|-------|---------------------|:-------:|:----:|------|
| `COUNT` / `SUM` / `AVG` / `MIN` / `MAX` | 同 | — | ✅ | PG 原生等价 |
| `GROUP_CONCAT(col ORDER BY ... SEPARATOR s)` | `STRING_AGG(col::text, s ORDER BY ...)` | — | 🔄 | PG 无 `GROUP_CONCAT`，改 `STRING_AGG`；注意 `text` 转型 |
| `BIT_AND` / `BIT_OR` / `BIT_XOR` | 同 | — | ⚠️ | PG 支持但对 NULL 处理细节需核对 |
| `STD` / `STDDEV` / `VARIANCE` | `STDDEV_SAMP` / `STDDEV_POP` / `VAR_SAMP` / `VAR_POP` | — | 🔄 | **样本/总体需显式区分**；MySQL 默认总体，PG 默认样本，结果会不同 |

---

## JSON

> **路径语法完全不同是 JSON 区域最大风险**。MySQL 用 `$.a.b[0]` 形式字符串路径；PG 用 `->`/`->>`/`#>`/`#>>` 运算符 + 数组下标。所有 JSON 函数一律 🔄 改写，脚本未提供兼容层。

| MySQL | 瀚高 v4.1.5 目标写法 | 脚本覆盖 | 状态 | 说明 |
|-------|---------------------|:-------:|:----:|------|
| `j->'$.a'` / `JSON_EXTRACT(j, '$.a')` | `j->'a'`（返回 json）或 `j#>'{a}'` | — | 🔄 | 去掉 `$.` 前缀，嵌套路径改 `j#>'{a,b}'` |
| `j->>'$.a'` / `JSON_UNQUOTE(JSON_EXTRACT(...))` | `j->>'a'`（返回 text） | — | 🔄 | 直接用 `->>` 一步到位 |
| `JSON_OBJECT(k, v, ...)` | `jsonb_build_object(k, v, ...)` 或 `json_build_object` | — | 🔄 | 函数名与行为差异 |
| `JSON_ARRAY(a, b, ...)` | `jsonb_build_array(a, b, ...)` | — | 🔄 | 同上 |
| `JSON_CONTAINS(j, candidate, path)` | `j @> candidate`（jsonb 包含运算符） | — | 🔄 | 需先 `::jsonb`；`path` 定位需配合 `#>` 切片 |
| `JSON_SEARCH` | 无直接等价，需 `jsonb_path_query` 或递归 | — | 🔄 | 实现复杂，Pilot 重点 |
| `JSON_LENGTH(j, path)` | `jsonb_array_length(j)` 或 `jsonb_object_keys` 计数 | — | 🔄 | 按数组/对象场景分别改写 |

**JSON 是 Pilot 必测专项**，将工程内所有 JSON 相关查询抽出独立测试集，逐条验证路径改写结果。

---

## 系统

| MySQL | 瀚高 v4.1.5 目标写法 | 脚本覆盖 | 状态 | 说明 |
|-------|---------------------|:-------:|:----:|------|
| `DATABASE()` | `CURRENT_DATABASE()` | — | 🔄 | PG 无 `DATABASE()`，改标准函数 |
| `USER()` / `CURRENT_USER()` | `CURRENT_USER` / `SESSION_USER` | — | ⚠️ | 返回格式不含 `@host` 部分 |
| `VERSION()` | `VERSION()` | — | ⚠️ | 返回字符串格式完全不同（PG 版本串，非 MySQL 格式） |
| `LAST_INSERT_ID()` | `currval('seq_name')` 或 SQL `INSERT ... RETURNING id` | — | 🔄 | 无全局会话级函数；推荐用 `RETURNING` 或显式 sequence |
| `UUID()` | `gen_random_uuid()`（需 `pgcrypto`） | — | 🔄 | 扩展需预装；返回 `uuid` 类型非字符串 |

---

## 加密与编码

| MySQL | 瀚高 v4.1.5 目标写法 | 脚本覆盖 | 状态 | 说明 |
|-------|---------------------|:-------:|:----:|------|
| `MD5(str)` | `MD5(str)` | — | ✅ | PG 原生等价，返回十六进制 text |
| `SHA1(str)` | `encode(digest(str,'sha1'),'hex')` | — | ⚠️ | **需 `pgcrypto` 扩展**；无扩展则不可用 |
| `SHA2(str, bits)` | `encode(digest(str,'sha'\|\|bits),'hex')` | — | ⚠️ | 同上，需 `pgcrypto` |
| `AES_ENCRYPT(data, key)` | `encrypt(data::bytea, key::bytea, 'aes')`（`pgcrypto`） | — | 🔄 | 默认分组模式/填充不同，**密文不兼容**，迁移存量密文需重加密 |
| `AES_DECRYPT(data, key)` | `decrypt(data, key::bytea, 'aes')`（`pgcrypto`） | — | 🔄 | 同上 |
| `PASSWORD(str)` | 应用层加密 | — | ❌ | MySQL 已废弃，不再迁移，改应用层方案 |
| `HEX(str)` | `ENCODE(str::bytea, 'hex')` | — | 🔄 | PG 无同名函数 |
| `UNHEX(hex_str)` | `DECODE(hex_str, 'hex')` | — | 🔄 | 返回 `bytea`，按需再转 text |
| `TO_BASE64` / `FROM_BASE64` | `ENCODE(..., 'base64')` / `DECODE(..., 'base64')` | — | 🔄 | PG 通过 `ENCODE/DECODE` 统一入口 |

---

## 处理原则

1. **先查脚本覆盖**：任何 MySQL 函数出现在业务 SQL 中，先确认 `highgo-v4.1.5-mysql-compat-functions.md` 是否覆盖；覆盖则免改，直接引用脚本部署结果。
2. **脚本缺口必须记录**：一旦发现脚本未覆盖的类型重载或异常行为缺口，写入本工程 `docs/risks/known-risks-gaussdb.md`（已更名语境下对应的瀚高风险矩阵）与 `fix-issue/`，不要靠记忆。
3. **PG 原生等价逐条改写**：对 🔄 项，严格按本表目标写法改写，避免自造函数重复造轮子。
4. **不可用的 Fallback**：脚本未覆盖且 PG 也无等价的（如 `JSON_SEARCH`、`TIMESTAMPDIFF`），优先在 SQL 层用 `jsonb_path_query` 等原生扩展实现；仍不可行则上移到 Java 层处理。
5. **所有 ⚠️ Pilot 必测**：凡打了 ⚠️ 的条目（含脚本覆盖但有已知行为差异的 🛡️⚠️ 项），Pilot 阶段单列测试用例，覆盖边界、NULL、类型转换、并发等场景，通过后方可扩大范围。

---

## 脚本缺口明细（v4.1.5 已知）

下列缺口来自对 `highgo-v4.1.5-mysql-compat-functions.sql` 的逐函数清点，实施时需特别注意：

| 缺口 | 表现 | 规避策略 |
|------|------|---------|
| `IF(cond, a, b)` 重载不全 | 脚本只重载返回 `DATE` / `TIMESTAMPTZ` / `BOOLEAN` 的版本；`int`/`numeric`/`text`/`varchar` 等类型未重载 | 业务 SQL 中涉及这些返回类型的 `IF` 调用，**一律改写为 `CASE WHEN ... THEN ... ELSE ... END`** |
| `IFNULL(a, b)` 重载不全 | 脚本重载不包含 `date` / `timestamp` / `timestamptz` / `bigint` | 这些类型的 `IFNULL` 全部替换为 `COALESCE`（标准 SQL，推荐作为默认策略） |
| `MOD(a, b)` 异常行为差异 | 脚本在除零等异常输入上返回 NULL，而 MySQL 抛错 | 若业务依赖"除零报错"的防御逻辑，需在调用处显式判 `b = 0` 并抛 `RAISE EXCEPTION` |
| `DATE_FORMAT` 递归风险 | 脚本内部与 `TO_CHAR` 相互转换，在复杂格式或大批量调用下可能触发栈/性能问题 | Pilot 阶段压测覆盖高频格式（如 `%Y-%m-%d %H:%i:%s`、`%W` 等），必要时改直接 `TO_CHAR` |
| `TO_DAYS` 结果偏差 | 脚本实现与 MySQL 在部分历法边界存在 1~2 天偏差 | 涉及历史对账、跨日数计算的字段，**不得直接依赖脚本结果**，改用 `(dt::date - DATE '0001-01-01')` 或业务协商统一基准 |

后续若发现新的脚本缺口，追加到本节并同步更新风险矩阵。
