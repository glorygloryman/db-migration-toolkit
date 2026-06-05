# MySQL 方言遗漏自检 Skill 设计文档

日期：2026-06-05
状态：已实现

## 1. 背景

在 MySQL → 瀚高 v4.1.5 迁移的 5 阶段 SOP 中，Stage 5（db-migration-verify）负责回归测试和验收报告。但 verify 只检查测试是否通过、schema 是否完整，不检查 SQL 源码中是否存在**未被改造的 MySQL 方言**。

需要一个自检 skill，在验收完成后扫描项目中所有 SQL 来源，发现可能遗漏的 MySQL 方言，生成报告供人工确认。

## 2. 关键决策

| 决策项 | 结论 | 原因 |
|--------|------|------|
| 行为 | 仅出报告，不阻断 | 不干扰交付流程，由开发者决定是否处理 |
| 扫描范围 | XML Mapper + Mapper.java + Repository.java + Java 内嵌 SQL | 覆盖应用层所有 SQL 来源，不含 Flyway DDL |
| 兼容函数处理 | 白名单通过 + 已知缺口给提示 | 已兼容的不报，但类型缺口需人工确认 |
| 集成方式 | 独立 skill（db-migration-self-check） | 可单独调用，也可被 work-cycle-auto 集成 |
| 时机 | verify 之后 | 先确保功能正确，再检查遗漏 |

## 3. 扫描范围

| 文件类型 | 匹配方式 | 说明 |
|---------|---------|------|
| MyBatis XML Mapper | `**/*Mapper.xml`、`**/*mapper.xml` | 所有 XML mapper 文件 |
| MyBatis Mapper 接口 | `**/*Mapper.java`、`**/*mapper.java` | 含 `@Select`/`@Update`/`@Delete`/`@Insert` 注解 |
| JPA Repository | `**/*Repository.java` | 含 `@Query` 注解 |
| JdbcTemplate 内嵌 SQL | 搜索含 `"SELECT`/`"INSERT`/`"UPDATE`/`"DELETE` 字符串字面量的 Java 文件 | 非注解形式的内嵌 SQL |

## 4. 检测规则

### A. 语法层 — 必须标记（14 项）

| 编号 | 模式 | MySQL 写法 | PG 替代 |
|------|------|-----------|---------|
| A1 | 反引号标识符 | `` `col_name` `` | 双引号或去引号 |
| A2 | 双引号字符串字面量 | `"0000"` | 单引号 `'0000'` |
| A3 | LIMIT m,n 分页 | `LIMIT 10,20` | `LIMIT 20 OFFSET 10` |
| A4 | ON DUPLICATE KEY | `ON DUPLICATE KEY UPDATE` | `ON CONFLICT ... DO UPDATE` |
| A5 | REPLACE INTO | `REPLACE INTO t ...` | `ON CONFLICT` 或 DELETE+INSERT |
| A6 | INSERT IGNORE | `INSERT IGNORE INTO` | `ON CONFLICT DO NOTHING` |
| A7 | 多表 UPDATE JOIN | `UPDATE t1 JOIN t2 SET` | `UPDATE ... FROM ... WHERE` |
| A8 | UPDATE/DELETE + LIMIT | `DELETE FROM t LIMIT 100` | 子查询限定 |
| A9 | LOCK IN SHARE MODE | `SELECT ... LOCK IN SHARE MODE` | `FOR SHARE` |
| A10 | STRAIGHT_JOIN | `STRAIGHT_JOIN` | 不支持，需调整 |
| A11 | USE/FORCE/IGNORE INDEX | `USE INDEX(idx)` | 不支持，需其他优化手段 |
| A12 | ORDER BY RAND() | `ORDER BY RAND()` | `RANDOM()` |
| A13 | GROUP BY 非严格模式 | 非聚合列不在 GROUP BY 中 | PG 严格模式要求 |
| A14 | PG 保留字冲突 | `user`, `type`, `order`, `desc`, `group`, `role` 作为标识符 | 加引号或改名 |

### B. 函数层 — 兼容白名单（5 项，带缺口提示）

白名单来源：`docs/references/highgo-v4.1.5-mysql-compat-functions.md`

| 函数 | 已知缺口提示 |
|------|------------|
| `IFNULL` | 用于 timestamp/date 类型时脚本无重载，建议确认 |
| `IF` | 用于 numeric/text/int 参数时脚本无重载，建议确认 |
| `DATE_FORMAT` | 存在递归栈溢出风险，建议确认实际调用场景 |
| `TO_DAYS` | 与 MySQL 有 1-2 天偏差，建议确认业务精度要求 |
| `MOD` | 除零时返回 NULL（MySQL 抛错），行为不同，建议确认 |

### C. 函数层 — 必须标记（10 个分类）

| 编号 | 分类 | 涉及函数 |
|------|------|---------|
| C1 | 字符串 | `SUBSTRING_INDEX`、`LOCATE`/`INSTR`、`FORMAT` |
| C2 | 聚合/拼接 | `GROUP_CONCAT`、`CONCAT`（NULL 行为不同） |
| C3 | 数值 | `RAND()`、`ROUND(x,d)` 需 `::numeric`、除零行为 |
| C4 | 日期时间 | `UNIX_TIMESTAMP`、`FROM_UNIXTIME`、`DATE_ADD`/`DATE_SUB`、`DATEDIFF`、`TIMESTAMPDIFF`、`DAYOFWEEK`、`WEEK`、`CONVERT_TZ` |
| C5 | 流程控制 | `ISNULL(expr)` （不是 `IS NULL`） |
| C6 | JSON | `JSON_EXTRACT`、`JSON_OBJECT`、`JSON_ARRAY`、`JSON_CONTAINS`、`JSON_SEARCH`、`JSON_LENGTH` |
| C7 | 加密 | `SHA1`、`SHA2`、`AES_ENCRYPT`/`AES_DECRYPT`、`HEX`、`UNHEX`、`TO_BASE64`、`FROM_BASE64` |
| C8 | 系统 | `DATABASE()`、`LAST_INSERT_ID()`、`UUID()`、`VERSION()`、`USER()` |
| C9 | 正则 | `REGEXP`、`RLIKE` |
| C10 | 隐式类型转换 | `int_col LIKE`、`LEFT(int_col`、`RIGHT(int_col` — 需显式 `::TEXT` |

### D. 风险提示层 — fix-issue 关联

扫描到以下模式时附带相关 fix-issue 链接：
- `DISTINCT ON` 排序约束 → fix-issue DISTINCT ON 条目
- 隐式类型转换（字符串 vs 日期/数字比较）
- GeneratedKeyHolder 多列返回
- 中文错误信息匹配
- JPA `@Query` 中 `::` 语法与 Hibernate 冲突
- PageHelper 方言未配置

## 5. 工作流程

```
db-migration-self-check
        │
        ▼
  ① 文件发现
  Glob 定位所有目标文件
        │
        ▼
  ② 第一轮：语法层快速扫描
  Grep 语法层模式 A1-A14
  记录命中：文件路径、行号、匹配内容
        │
        ▼
  ③ 第二轮：函数层扫描
  Grep 函数名模式（B类 + C1-C10）
  白名单命中 → 标记"已兼容"+ 缺口提示
  非白名单命中 → 标记"需确认"
        │
        ▼
  ④ 第三轮：风险模式扫描
  扫描 D 类风险模式，匹配 fix-issue 知识库
  命中的附带相关 fix-issue 文件路径
        │
        ▼
  ⑤ 汇总过滤
  排除注释中的命中（<!-- -->、//、/* */、--）
  合并同文件多次命中
        │
        ▼
  ⑥ 输出报告
  保存到 {项目目录}/docs/migration/self-check-report.md
```

### 注释过滤规则

skill 在命中后阅读上下文，排除以下场景：
- XML 注释 `<!-- ... -->` 中的内容
- Java 单行注释 `// ...`
- Java 多行注释 `/* ... */`
- SQL 单行注释 `-- ...`

以下场景**不排除**（是有效扫描目标）：
- `@Select("...")`、`@Update("...")`、`@Query("...")` 注解中的 SQL
- MyBatis XML 中 `<select>`、`<insert>`、`<update>`、`<delete>` 标签内的 SQL
- JdbcTemplate 参数中的字符串 SQL

## 6. 输出报告格式

```markdown
# MySQL 方言自检报告

项目：{项目名}
扫描时间：{timestamp}
扫描文件数：{N} 个

## 摘要

| 分类 | 命中数 |
|------|-------|
| 🔴 语法层（需改造） | {n} |
| 🟡 函数层（需确认） | {n} |
| 🟢 兼容函数（已知缺口提示） | {n} |
| ⚠️ 风险模式（fix-issue 关联） | {n} |

## 详细发现

### 🔴 语法层

- **[A3] LIMIT m,n 分页**
  - 文件：`src/main/resources/mapper/UserMapper.xml:42`
  - 内容：`LIMIT #{offset}, #{size}`
  - 建议：改为 `LIMIT #{size} OFFSET #{offset}`

### 🟡 函数层（需确认）

- **[C4] UNIX_TIMESTAMP**
  - 文件：`src/main/java/com/xxx/dao/StatsMapper.java:28`
  - 内容：`@Select("SELECT ... WHERE UNIX_TIMESTAMP(create_time) > #{ts}")`
  - 建议：改为 `EXTRACT(EPOCH FROM create_time)::bigint`

### 🟢 兼容函数（已知缺口提示）

- **[B3] DATE_FORMAT**
  - 文件：`src/main/resources/mapper/OrderMapper.xml:67`
  - 内容：`DATE_FORMAT(order_time, '%Y-%m-%d')`
  - 提示：兼容脚本覆盖，但存在递归栈溢出风险，建议确认

### ⚠️ 风险模式

- **隐式类型转换**
  - 文件：`src/main/java/com/xxx/dao/ProductMapper.java:15`
  - 内容：`WHERE int_col LIKE CONCAT('%', #{val}, '%')`
  - 建议：添加 `::TEXT` 显式转换
  - 参考：fix-issue/2026-06-01-implicit-type-cast.md

## 无命中项

以下规则未检测到命中（供确认覆盖完整性）：
- A1 反引号标识符 ✅
- A2 双引号字符串 ✅
- ...
```

## 7. 与 work-cycle-auto 的集成

在 work-cycle-auto 的 Stage 6 中，verify 之后增加一步：

```
Stage 6 · 验证与交付
  ├── db-migration-verify（回归测试 + 验收报告）
  └── db-migration-self-check（方言遗漏自检，仅出报告）
```

自检报告作为验收附件，不影响交付流程。

## 8. Skill 文件结构

```
skills/db-migration-self-check/
├── SKILL.md                # Skill 主文件（工作流指令）
└── self-check-rules.md     # 检测规则清单
```

- `self-check-rules.md` 独立维护，便于随兼容脚本版本升级而更新
- 白名单来源引用 `docs/references/highgo-v4.1.5-mysql-compat-functions.md`，不重复维护
