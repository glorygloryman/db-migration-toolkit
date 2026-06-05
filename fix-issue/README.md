# fix-issue 踩坑库

本目录存放**跨工程可复用**的 MySQL → 瀚高 v4.1.5 改造踩坑记录。

## 准入标准（按 CLAUDE.md §5 文档治理协议）

一条 `fix-issue` 必须同时具备四要素：

1. **问题现象**：能复现、可观察
2. **根因分析**：为什么发生
3. **修复动作 或 规避准则**：怎么解决 / 下次怎么避开
4. **真实来源**：来自哪个工程、哪次改造、哪个 commit

不满足上述四要素的问题按 CLAUDE.md §5 分流：
- 仅现象无根因 → `fact`（纳入 `docs/risks/`）
- 操作指引型 → `playbook`（待建目录）
- 方案选型型 → `decision`（留在工程本地 `project-docs/decisions/`）
- 经验答疑型 → `faq`（待建目录）

## 文件命名

`YYYY-MM-DD-<short-slug>.md`

## 文件格式

```markdown
---
updated: YYYY-MM-DD
source: <project-name>/<path or commit>
related-risk: R-xxx（如有）
severity: 🔴 / 🟡 / 🟢
category: 驱动 / 连接池 / 语法 / 函数 / 类型 / 保留字 / 字符集 / 时区 / 存储过程 / 其他
---

# <标题：现象的简短描述>

## 现象

<可复现的错误描述、日志片段、SQL 样例>

## 根因

<为什么发生，涉及的瀚高行为或配置>

## 修复动作 / 规避准则

<具体怎么解、未来怎么避>

## 影响范围

<哪些场景会触发、哪些工程可能遇到>

## 来源

- 工程：<project-name>
- Commit：<sha>
- 日期：YYYY-MM-DD
- 记录人：<name>

## 参考

- 相关 reference：`docs/references/xxx.md`
- 相关 risk：R-xxx
```

## 索引

- [TRS 内部 BaseMybatisRepository 在瀚高下的兼容性放行规则](2026-04-22-trs-basemybatis-repository-compat.md) — 🟢 其他 | propagation-billboard | R-019
- [瀚高中文报错导致 safeQuery 跳过逻辑失效](2026-04-27-highgo-chinese-error-safequery.md) — 🟡 其他 | propagation-billboard | R-005
- [聚合除法除零异常 + ROUND 函数签名不匹配](2026-04-28-aggregate-division-round-type-error.md) — 🟡 函数 | propagation-billboard | R-021
- [AccountRankMapper ROUND 类型与 GROUP BY 严格模式修复](2026-04-28-account-rank-round-groupby.md) — 🟡 函数 | propagation-billboard | R-021, R-020
- [AreaManager QueryWrapper IN 查询类型不匹配](2026-04-28-area-manager-in-query-type-mismatch.md) — 🟡 类型 | propagation-billboard | R-020
- [ComprehensiveRankMapper 无 GROUP BY 隐式聚合 + ROUND 类型 + GROUP BY 严格模式](2026-04-28-comprehensive-rank-round-groupby.md) — 🟡 语法 | propagation-billboard | R-021, R-020
- [HighGo DDL 可执行不等于 Flyway 启动迁移链路可用](2026-04-29-highgo-ddl-flyway-not-hard-gate.md) — 🟡 其他 | stream-keywords-search | 无
- [多数据库测试 profile 需要隔离，避免跨库测试串入](2026-04-29-test-profile-cross-database-leak.md) — 🟡 其他 | stream-keywords-search | 无
- [DISTINCT ON 排序语义变化导致分页行为不一致](2026-05-08-weibo-bomb-distinct-on-ordering.md) — 🟡 语法 | tmy-decision-center | 无
- [JPA Criteria.groupBy / PageInfo.addGroupby 在瀚高方言下不兼容](2026-05-08-jpa-criteria-groupby-highgo-incompat.md) — 🔴 语法 | tmy-decision-center | R-020
- [DISTINCT ON → ROW_NUMBER() 窗口函数改写方案](2026-05-09-rownumber-vs-distinct-on.md) — 🟢 语法 | tmy-decision-center | 无
- [日期范围查询从字符串比较改为原生类型范围比较](2026-05-09-date-range-string-to-native-type.md) — 🟡 函数 | tmy-decision-center | 无
- [PostgreSQL 列名大小写敏感导致查询失败](2026-05-09-pg-column-case-sensitivity.md) — 🟡 保留字 | tmy-decision-center | 无
- [Entity 字段类型 String → Integer 修正](2026-05-09-entity-type-string-to-integer.md) — 🟡 类型 | tmy-decision-center | R-020
- [PostgreSQL 拒绝 string 与 date 的隐式比较](2026-06-01-pg-string-date-implicit-comparison.md) — 🟡 类型 | event_server | 无
- [GeneratedKeyHolder 在 PostgreSQL 下返回多列](2026-06-01-generated-key-holder-multi-column.md) — 🟡 其他 | event_server | 无
- [HikariCP connection-init-sql 方言不兼容](2026-06-01-hikari-connection-init-sql-dialect.md) — 🟡 连接池 | event_server | 无
- [Druid 1.1.6 无法识别瀚高 JDBC URL，需显式设置 driverClassName](2026-06-03-druid-highgo-driver-unknown.md) — 🟡 连接池 | interaction-middleware | R-011
- [Druid 1.1.6 WallFilter 不认识瀚高 JDBC URL，无法推断 dbType 导致初始化失败](2026-06-03-druid-wallfilter-highgo-dbtype.md) — 🟡 连接池 | interaction-middleware | R-011
- [JPA @Query 原生 SQL 中 String 参数与 timestamp 列比较需显式 CAST](2026-06-03-jpa-native-query-string-timestamp-cast.md) — 🟡 类型 | interaction-middleware | R-020

## 贡献流程

1. 在本工程 `project-docs/fix-issue/` 产生条目
2. 判断是否"通用性"（其他 MySQL 工程也可能遇到）
3. 拷贝到本目录（保留 `source:` 字段指向原工程）
4. 提 PR 到 `db-migration-toolkit` 仓库
5. 更新本 README 的索引
