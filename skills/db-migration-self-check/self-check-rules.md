# MySQL 方言遗漏自检规则清单

> 本文件供 `db-migration-self-check` Skill 逐条匹配。规则会随兼容脚本版本升级而变化，独立于 SKILL.md 维护。
> 白名单来源：`docs/references/highgo-v4.1.5-mysql-compat-functions.md`

---

## A. 语法层 — 必须标记

PostgreSQL 完全不支持以下 MySQL 语法，在已改造项目中不应出现。

| 编号 | 模式 | Grep 关键词/正则 | MySQL 写法 | PG 替代                                                                         |
|------|------|-----------------|-----------|-------------------------------------------------------------------------------|
| A1 | 反引号标识符 | `` `[^`]+` `` | `` `col_name` `` | 双引号或去引号                                                                       |
| A2 | 双引号字符串字面量（SQL 上下文内） | `"[^"]*"` 在 SQL 片段中 | `"0000"`、`"%"` | 单引号 `'0000'`、`'%'`                                                            |
| A3 | LIMIT m,n 分页 | `LIMIT\s+\d+\s*,\s*\d+`、`LIMIT\s*#\{[^}]+\}\s*,\s*#\{` | `LIMIT 10,20` | `LIMIT n OFFSET m`                                                            |
| A4 | ON DUPLICATE KEY | `ON\s+DUPLICATE\s+KEY` | `ON DUPLICATE KEY UPDATE` | `ON CONFLICT ... DO UPDATE`                                                   |
| A5 | REPLACE INTO | `REPLACE\s+INTO` | `REPLACE INTO t ...` | `ON CONFLICT` 或 DELETE+INSERT                                                 |
| A6 | INSERT IGNORE | `INSERT\s+IGNORE` | `INSERT IGNORE INTO` | `ON CONFLICT DO NOTHING`                                                      |
| A7 | 多表 UPDATE JOIN | `UPDATE\s+\w+\s+.*\bJOIN\b`（排除子查询） | `UPDATE t1 JOIN t2 SET` | `UPDATE ... FROM ... WHERE`                                                   |
| A8 | UPDATE/DELETE + LIMIT | `(?:UPDATE|DELETE).*\bLIMIT\b` | `DELETE FROM t LIMIT 100`                                                     | 子查询限定 |
| A9 | LOCK IN SHARE MODE | `LOCK\s+IN\s+SHARE\s+MODE` | `SELECT ... LOCK IN SHARE MODE` | `FOR SHARE`                                                                   |
| A10 | STRAIGHT_JOIN | `\bSTRAIGHT_JOIN\b` | `STRAIGHT_JOIN` | 不支持，需调整                                                                       |
| A11 | USE/FORCE/IGNORE INDEX | `\b(?:USE|FORCE| IGNORE)\s+INDEX\b`                                                            | `USE INDEX(idx)` | 不支持 |
| A12 | ORDER BY RAND() | `\bORDER\s+BY\s+RAND\s*\(` | `ORDER BY RAND()` | `RANDOM()`                                                                    |
| A13 | GROUP BY 非严格模式 | 语义判断：SELECT 列中有非聚合、非 GROUP BY 列 | `SELECT a,b,MAX(c) FROM t GROUP BY a` | PG 要求 b 也在 GROUP BY 中                                                         |
| A14 | PG 保留字冲突 | `\b(?:user|type| order                                                                         |desc|group|role|level|status|current_user|session_user)\b` 作为列名/表名 | 列名 `user`、`type` | 加双引号或改名 |
| A15 | 用户变量赋值 | `@\w+\s*:=` | `@curlevel := if(...)` | `CROSS JOIN (SELECT CASE WHEN ... END AS var) sub` + 注意整数列可能需要进行类型转换 `::text` |

---

## B. 函数层 — 兼容白名单（不报，已知缺口给提示）

以下函数已被 `highgo-v4.1.5-mysql-compat-functions.sql` 覆盖，命中时不标记为遗漏，但附带缺口提示。

| 编号 | 函数 | Grep 关键词 | 已知缺口提示 |
|------|------|------------|------------|
| B1 | IFNULL | `\bIFNULL\s*\(` | 用于 timestamp/date 类型时脚本无重载，建议确认 |
| B2 | IF | `\bIF\s*\(`（排除 `IF NOT EXISTS`、`IF EXISTS`） | 用于 numeric/text/int 参数时脚本无重载，建议确认 |
| B3 | DATE_FORMAT | `\bDATE_FORMAT\s*\(` | 存在递归栈溢出风险（R-002），建议确认实际调用场景 |
| B4 | TO_DAYS | `\bTO_DAYS\s*\(` | 与 MySQL 有 1-2 天偏差，建议确认业务精度要求 |
| B5 | MOD | `\bMOD\s*\(` | 除零时返回 NULL（MySQL 抛错），行为不同，建议确认 |

---

## C. 函数层 — 必须标记

以下函数未被兼容脚本覆盖，若出现在已改造项目中，标记为可能遗漏。

| 编号 | 分类 | Grep 关键词 | 说明 |
|------|------|------------|------|
| C1 | 字符串 | `\bSUBSTRING_INDEX\s*\(` | → `SPLIT_PART`（负数需额外处理） |
| C1 | 字符串 | `\bLOCATE\s*\(`、`\bINSTR\s*\(` | 参数顺序与 PG 相反 |
| C1 | 字符串 | `\bFORMAT\s*\(`（MySQL 数值格式化） | → `TO_CHAR` |
| C2 | 聚合/拼接 | `\bGROUP_CONCAT\s*\(` | → `STRING_AGG` |
| C2 | 聚合/拼接 | `\bCONCAT\s*\(` | NULL 行为不同（MySQL 任一 NULL → NULL，PG 按 NULL 空串处理） |
| C3 | 数值 | `\bRAND\s*\(` | → `RANDOM()` |
| C3 | 数值 | `\bROUND\s*\(` | PG 只接受 `(numeric, int)`，需显式 `::numeric` |
| C4 | 日期时间 | `\bUNIX_TIMESTAMP\s*\(` | → `EXTRACT(EPOCH FROM ...)::bigint` |
| C4 | 日期时间 | `\bFROM_UNIXTIME\s*\(` | → `TO_TIMESTAMP(epoch)` |
| C4 | 日期时间 | `\bDATE_ADD\s*\(`、`\bDATE_SUB\s*\(` | → `INTERVAL` 表达式 |
| C4 | 日期时间 | `\bDATEDIFF\s*\(` | → `(d1::date - d2::date)` |
| C4 | 日期时间 | `\bTIMESTAMPDIFF\s*\(` | 无直接等价，需按 UNIT 组合 |
| C4 | 日期时间 | `\bDAYOFWEEK\s*\(` | 周起始不同（MySQL 周日=1，PG 周日=0），需 +1 |
| C4 | 日期时间 | `\bWEEK\s*\(` | mode 参数语义在 PG 无对应 |
| C4 | 日期时间 | `\bCONVERT_TZ\s*\(` | → `AT TIME ZONE` |
| C5 | 流程控制 | `\bISNULL\s*\(`（非 `IS NULL`） | MySQL `ISNULL(expr)` 是函数 → PG `expr IS NULL` 谓词 |
| C6 | JSON | `\bJSON_EXTRACT\s*\(` | → `j->'key'` 或 `j#>'{key}'` |
| C6 | JSON | `\bJSON_OBJECT\s*\(` | → `jsonb_build_object` |
| C6 | JSON | `\bJSON_ARRAY\s*\(` | → `jsonb_build_array` |
| C6 | JSON | `\bJSON_CONTAINS\s*\(` | → `@>` 运算符 |
| C6 | JSON | `\bJSON_SEARCH\s*\(` | → `jsonb_path_query` |
| C6 | JSON | `\bJSON_LENGTH\s*\(` | 按数组/对象分别改写 |
| C7 | 加密 | `\bSHA1\s*\(` | → `encode(digest(str,'sha1'),'hex')` |
| C7 | 加密 | `\bSHA2\s*\(` | → `encode(digest(str,'sha'||bits),'hex')` |
| C7 | 加密 | `\bAES_ENCRYPT\s*\(`、`\bAES_DECRYPT\s*\(` | 默认分组模式/填充不同，密文不兼容 |
| C7 | 加密 | `\bHEX\s*\(` | → `ENCODE(str::bytea, 'hex')` |
| C7 | 加密 | `\bUNHEX\s*\(` | → `DECODE(hex_str, 'hex')` |
| C7 | 加密 | `\bTO_BASE64\s*\(`、`\bFROM_BASE64\s*\(` | → `ENCODE/DECODE` |
| C8 | 系统 | `\bDATABASE\s*\(\)` | → `CURRENT_DATABASE()` |
| C8 | 系统 | `\bLAST_INSERT_ID\s*\(` | → `currval('seq_name')` 或 `INSERT ... RETURNING id` |
| C8 | 系统 | `\bUUID\s*\(` | → `gen_random_uuid()` |
| C8 | 系统 | `\bVERSION\s*\(\)` | 返回格式完全不同 |
| C9 | 正则 | `\bREGEXP\b`、`\bRLIKE\b` | → `~`/`~*` |
| C10 | 隐式类型转换 | `\w+_id\s+LIKE\b`、`\w+_id\)\s+LIKE\b`、`LEFT\s*\(\s*\w+_id`、`RIGHT\s*\(\s*\w+_id` | 整数列参与 LIKE/LEFT/RIGHT → 需显式 `::TEXT` |

---

## D. 风险提示层 — fix-issue 关联

扫描到以下模式时，在报告中附带相关 fix-issue 文件路径供参考。

| 编号 | 风险模式 | Grep 关键词 | 关联 fix-issue |
|------|---------|------------|---------------|
| D1 | DISTINCT ON 排序约束 | `\bDISTINCT\s+ON\b` | 搜索 `fix-issue/` 中含 `DISTINCT ON` 的条目 |
| D2 | 隐式类型转换（字符串 vs 日期/数字） | 字符串参数与日期/数字列比较 | 搜索 `fix-issue/` 中含 `implicit` 或 `隐式` 的条目 |
| D3 | GeneratedKeyHolder 多列返回 | `GeneratedKeyHolder`、`KeyHolder` | 搜索 `fix-issue/` 中含 `GeneratedKeyHolder` 的条目 |
| D4 | 中文错误信息匹配 | `getMessage`、`contains` + 错误信息匹配 | 搜索 `fix-issue/` 中含 `中文` 或 `报错` 的条目 |
| D5 | JPA `::` 与 Hibernate 冲突 | `::` 在 `@Query` 注解中 | 搜索 `fix-issue/` 中含 `Hibernate` 或 `@Query` 的条目 |
| D6 | PageHelper 方言 | `pagehelper`、`PageHelper` | 搜索 `fix-issue/` 中含 `PageHelper` 或 `分页` 的条目 |

---

## 注释过滤

命中后阅读上下文，排除以下场景的命中：

| 类型 | 排除模式 | 说明 |
|------|---------|------|
| XML 注释 | `<!-- ... -->` | MyBatis XML 中的注释块 |
| Java 单行注释 | `// ...` | Java 代码注释 |
| Java 多行注释 | `/* ... */` | Java 代码注释块 |
| SQL 单行注释 | `-- ...` | SQL 行注释 |

以下场景**不排除**（是有效扫描目标）：
- `@Select("...")`、`@Update("...")`、`@Delete("...")`、`@Insert("...")` 注解中的 SQL
- `@Query("...")` 注解中的 JPQL/Native SQL
- MyBatis XML 中 `<select>`、`<insert>`、`<update>`、`<delete>` 标签内的 SQL（含 `<if>`、`<foreach>` 内的动态 SQL）
- JdbcTemplate 参数中的字符串 SQL
