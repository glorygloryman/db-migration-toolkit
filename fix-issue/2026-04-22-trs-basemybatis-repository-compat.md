---
updated: 2026-04-22
source: propagation-billboard/2026-04-22（TRS 共享组件 media_base_web_mybatis 核查）
related-risk: R-019
severity: 🟢
category: 其他
---

# TRS 内部 BaseMybatisRepository 在瀚高下的兼容性放行规则

## 现象

baseline 扫描（Stage 0 `db-migration-sql-scan`）在处理继承 TRS 内部
`BaseMybatisRepository` 的 Mapper 时，会将该依赖标记为**阻塞项**，要求人工
确认基类是否包含 MySQL 特有逻辑后才能进入下一阶段。多个工程重复命中，造成
扫描结果噪音。

## 根因

对 `media_base_web_mybatis-1.3.46.jar` 反编译后确认：

- `BaseMybatisRepository` 仅继承 `BaseMapper<T>` + `BaseMybatisDao<T, ID>`
- 所有方法为 default 实现的 MyBatis-Plus 标准 CRUD
- 未发现 MySQL 方言、MySQL 专有函数或 SQL 拼接逻辑

因此**基类本身无数据库方言依赖**，标准 CRUD 路径上是数据库中立的。扫描器
默认保守判定为阻塞，属于误报。

## 修复动作 / 规避准则

baseline 扫描命中该依赖时，按"放行条件 / 一票否决条件"两段式判定：满足全部放行条件即标记为"已验证兼容"跳过，否则转人工或进入 SQL 兼容性检查流程。

放行条件（需同时全部满足，缺一不放行）：

1. Mapper 仅继承 `BaseMybatisRepository`，无自定义方法
2. 无 XML 映射文件
3. 无 `@Select` / `@Update` / `@Delete` / `@*Provider` 等注解 SQL
4. 项目中未使用 `Wrapper.last(...)` / `Wrapper.apply(...)`
5. `BaseMybatisDao` 已单独验证无自定义 SQL
6. 分页插件已配置为 `DbType.POSTGRE_SQL`

一票否决条件（出现任一项即禁用本规则，必须走人工/SQL 兼容性检查流程）：

- Mapper 存在 XML 或自定义 SQL
- 使用 MySQL 专有函数（`ifnull` / `date_format` 等）
- `BaseMybatisDao` 含 SQL 逻辑且未验证
- 分页插件仍为 MySQL 方言

本规则仅覆盖"标准 CRUD 路径"；调用层 `Wrapper.last(...)` / `Wrapper.apply(...)` 等扩展 SQL 片段不在保障范围内。

## 影响范围

所有依赖 `media_base_web_mybatis`（含 `BaseMybatisRepository`）的 TRS 工程，以 `xz-source/` 下的 Java/Spring Boot 工程为主。典型场景：Mapper 接口仅继承基类、CRUD 逻辑全部走 MyBatis-Plus 默认实现、分页走 `PaginationInnerInterceptor`。

## 来源

- 工程：TRS 共享组件 `media_base_web_mybatis`（jar 版本 1.3.46），经 propagation-billboard 广播
- Commit：N/A
- 日期：2026-04-22
- 记录人：吴少辉

## 参考

- 相关 reference：`docs/references/highgo-v4-compatibility.md`
- 相关 risk：R-019（`docs/risks/known-risks-highgo.md`）；分页插件配套约束见 R-008

