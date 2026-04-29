---
updated: 2026-04-29
source: stream-keywords-search/fbce520
related-risk: 无
severity: 🟡
category: 其他
---

# HighGo DDL 可执行不等于 Flyway 启动迁移链路可用

## 现象

MySQL → 瀚高改造中，项目已经产出 HighGo DDL 脚本，并完成目标库 Schema、DAO / Mapper 真库回归验证；但在应用启动时启用 Flyway 自动迁移链路，`flywayInitializer` 初始化失败，导致 Stage 3 / Stage 5 是否可继续产生争议。

本案例中，HighGo DDL 脚本位于：

```text
src/main/resources/db/migration/highgo/
```

项目 `integration-highgo` profile 配置了 Flyway locations，但主配置 `spring.flyway.enabled=false`，说明当前项目运行主线并未默认使用 Flyway 执行数据库迁移。后续 Stage 5 决策为：HighGo DDL、Schema 完整性、DAO / Mapper 功能回归与应用启动冒烟分别验收；Flyway 启动迁移链路不作为本轮 Stage 5 硬前置。

## 根因

Flyway 链路失败不一定来自业务 DDL。Flyway 对 PostgreSQL 系数据库的适配在 HighGo 上可能触发连接状态恢复、角色恢复或权限相关操作；该类失败会发生在 Flyway 初始化阶段，和 DDL SQL 本身是否可执行不是同一个问题。

如果工具包默认把“HighGo DDL 可执行”与“应用启动时 Flyway 自动迁移可用”绑定为同一个硬前置，就会把本可独立验证通过的 Schema 和业务功能改造阻塞在 Flyway 适配问题上。

## 修复动作 / 规避准则

在 Stage 3 / Stage 5 增加 Flyway 决策点，先判断当前项目中 Flyway 的真实地位：

- `required`：生产或交付明确要求 Flyway 执行迁移，必须把 Flyway 链路跑通。
- `optional`：Flyway 仅作为交付自动化资产或探测入口，可记录为专项风险。
- `not-used`：项目主配置或生产流程不使用 Flyway，不应作为 Stage 5 硬前置。

若 Flyway 不是 `required`，建议拆分验收：

1. DDL SQL 在目标 HighGo 库可执行。
2. Schema 完整性通过表、索引、主键、identity、兼容函数版本等检查。
3. DAO / Mapper 真库功能回归通过。
4. 应用在 HighGo profile 下完成启动冒烟；如 Flyway 非硬前置，可显式使用 `spring.flyway.enabled=false`。
5. Flyway 自动迁移链路作为后续专项记录，不混入 DDL / 功能验收结论。

不要为了让 Flyway 冒烟强行通过而默认引入临时 JDBC wrapper 或连接拦截层。除非用户明确接受该交付策略，否则 wrapper 会扩大运行时行为差异和后续维护风险。

## 影响范围

适用于以下 MySQL → 瀚高 v4.1.5 改造场景：

- 旧项目此前没有把 Flyway 作为正式生产迁移链路。
- 新增了 `db/migration/highgo/` 目录，但主配置默认关闭 Flyway。
- HighGo DDL / Schema 验证可通过，但应用启动 Flyway 初始化失败。
- 项目需要 Stage 5 验收，但 Flyway 自动迁移链路仍存在适配或权限问题。

## 来源

- 工程：stream-keywords-search
- 日期：2026-04-29
- 记录人：李卓尔

## 参考

- 相关报告：`project-docs/reports/2026-04-29-highgo-migration-report.md`
- 相关决策：Stage 5 不必须包含 Flyway 启动链路；HighGo 启动冒烟允许 `spring.flyway.enabled=false`
