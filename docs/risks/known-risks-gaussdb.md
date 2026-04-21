# GaussDB 已知风险库

> 按严重度分级，Pilot 中发现的新风险回灌到本文件。
> 严重度：🔴 高（阻塞 / 数据错误） / 🟡 中（需改造 / 影响功能） / 🟢 低（注意即可）

## R-001 🔴 JDBC 驱动获取与版本

**风险**：`gaussdbjdbc` 通常不在 Maven 中央仓库，依赖公司内部仓库或人工 install。

**影响**：Stage 2 启动阻塞，新成员环境难以复现。

**缓解**：
- 确认公司 Nexus / Artifactory 是否已托管
- 文档化驱动下载链接与 `mvn install:install-file` 命令
- 驱动版本写死，避免 `LATEST` / `RELEASE`

## R-002 🟡 Druid SQL Parser 不识别 GaussDB

**风险**：Druid `wall filter` 对非标准 SQL 可能误报，监控页可能解析失败。

**影响**：启动报错或监控失效。

**缓解**：
- `filters` 中移除 `wall`（初期）
- `db-type` 设 `postgresql`
- 观察启动日志 WARN

## R-003 🟡 时区与 TIMESTAMP 语义

**风险**：MySQL `TIMESTAMP` 自动做时区转换，GaussDB 行为可能不同；应用若强依赖"存 UTC 取本地"的隐式转换，会踩坑。

**影响**：时间字段显示偏差、跨时区比较错误。

**缓解**：
- 库级会话时区显式设置为 `Asia/Shanghai`
- 所有 `TIMESTAMP` 字段在 Pilot 中写专项测试
- 应用层时间处理优先用 `LocalDateTime` + 显式时区

## R-004 🟡 大小写敏感与标识符

**风险**：GaussDB 默认未加引号标识符转小写，若历史 Schema / SQL 混用大小写，可能找不到对象。

**影响**：`Table not found` 等错误。

**缓解**：
- 统一全小写标识符
- Schema 导出后全量转小写
- Mapper XML / 代码 SQL 同步转小写

## R-005 🟢 保留字差异

**风险**：B 模式放宽大量保留字，但仍有差异；部分 MySQL 中可用的列名在 GaussDB 中冲突。

**影响**：DDL 或 DML 失败。

**缓解**：
- 统一策略：冲突列名加双引号 或 改名
- Pilot 中列出本工程的保留字冲突清单

## R-006 🟡 连接池资源紧张

**风险**：GaussDB 分布式版的连接数配额通常小于 MySQL，同参数下可能连接耗尽。

**影响**：高并发场景出错。

**缓解**：
- `maximum-pool-size` 下调 30%~50%
- 监控 `pg_stat_activity` 观察连接使用

## R-007 🟡 PageHelper / MyBatis-Plus 分页方言

**风险**：插件无原生 GaussDB 方言，走 `mysql` 方言可能生成不兼容 SQL，走 `postgresql` 方言与 B 模式有细节差异。

**影响**：分页查询结果错误或 count SQL 报错。

**缓解**：
- 默认配 `postgresql` 方言
- Pilot 中专项测分页
- 复杂分页（带 GROUP BY / ORDER BY）重点测

## R-008 🟡 JSON 函数差异

**风险**：B 模式 JSON 函数语法与 MySQL 基本兼容，但边缘行为（路径语法、返回类型）可能差异。

**影响**：JSON 查询返回值不一致。

**缓解**：
- 识别工程所有 JSON 查询位置
- 每处写专项集成测试
- 记录差异到 `fix-issue/`

## R-009 🟢 执行计划差异

**风险**：相同 SQL 在 GaussDB 下执行计划可能显著不同，部分查询变慢。

**影响**：性能波动，非功能问题。

**缓解**：
- **不在本方案范围内调优**
- 记录明显慢查询，后续专项处理
- 如影响可用性，作为阻塞项上升

## R-010 🔴 存储过程 / 触发器不完全兼容

**风险**：B 模式对 MySQL 存储过程/触发器语法支持不完整，复杂逻辑可能失败。

**影响**：业务逻辑失效。

**缓解**：
- Stage 0 盘点使用情况
- 默认策略：上移到 Java 层
- 无法上移的上升立项

## R-011 🟡 字符集与 collation

**风险**：MySQL `utf8mb4_general_ci` 大小写不敏感比较；GaussDB 默认严格，若业务依赖不敏感比较需显式处理。

**影响**：WHERE 匹配失败、ORDER BY 顺序变化。

**缓解**：
- 识别大小写不敏感依赖点
- 显式加 `LOWER()` 或 `COLLATE`
- Pilot 中专项测

## R-012 🟢 EXPLAIN 输出格式差异

**风险**：运维脚本或监控解析 EXPLAIN 的可能失效。

**影响**：周边工具兼容问题，非主路径。

**缓解**：
- 记录受影响工具清单
- 非本方案范围，单独处理

## R-013 🟡 外部模板 / 非 Mapper SQL

**风险**：工程中可能有配置文件里的 SQL 模板、脚本目录里的 .sql、SQL 注解里的 SQL 被扫描遗漏。

**影响**：运行时报错。

**缓解**：
- Stage 0 SQL 仓清点必须覆盖全部来源
- 全仓 `grep` 验证

---

## 新增风险提交模板

```markdown
## R-xxx <严重度> <简短标题>

**风险**：...
**影响**：...
**缓解**：...
**来源**：<project-name>，commit xxx，日期 YYYY-MM-DD
```

新风险通过 PR 提交到本文件。
