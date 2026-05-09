---
updated: 2026-05-08
source: tmy-decision-center/JPA Criteria API
related-risk: R-020
severity: 🔴
category: 语法
---

# JPA Criteria.groupBy / PageInfo.addGroupby 在瀚高方言下不兼容

## 现象

JPA Criteria API 的 `criteria.groupBy("content")` + `repository.findAll(criteria, pageable)` 在瀚高环境下报错：

```
错误: 字段 "weibobombl0_.id" 必须出现在 GROUP BY 子句中或者在聚合函数中使用
```

JPA Specification 翻译生成的 SQL 形如 `SELECT w.id, w.task_id, ... FROM weibo_bomb w WHERE ... GROUP BY w.content`，所有非聚合 SELECT 列既未出现在 GROUP BY 中、也未被聚合函数包装。

## 根因

业务侧使用 `Criteria.groupBy` 实现的是"按列去重取一行"语义，而非真正的分组聚合。MySQL 在 `ONLY_FULL_GROUP_BY=OFF` 下允许 SELECT 中出现非聚合且不在 GROUP BY 的字段（取分组内任意行）。PostgreSQL/瀚高严格遵循 SQL 标准，要求所有非聚合列必须出现在 GROUP BY 中。

风险矩阵仅扫描 Mapper XML / 注解 SQL / 字符串拼接 SQL，**未覆盖 JPA Criteria API 在运行期生成 SQL 的路径**，因此 Stage 4 改写计划中遗漏。

## 修复动作 / 规避准则

将 `Criteria.groupBy(...)` 调用替换为 Native `@Query` + `DISTINCT ON` + 子查询包裹：

```sql
SELECT * FROM (
  SELECT DISTINCT ON (t.title) t.*
  FROM xxx_table t
  WHERE <conditions>
  ORDER BY t.title, <secondary order column> DESC
) sub ORDER BY sub.<final order column> DESC
```

countQuery 使用 `SELECT COUNT(*) FROM (SELECT DISTINCT t.title FROM xxx_table t WHERE ...) sub`。

严禁在 JPA Criteria / PageInfo 上使用 `groupBy(单列)` 实现"去重取一行"语义，必须改为 Native SQL。

风险矩阵补扫描关键字：`Criteria.groupBy` / `addGroupby` / `pageInfo.addGroupby`。

## 影响范围

所有通过 JPA Criteria API / PageInfo 调用 `groupBy` 的代码路径。涉及 6 个文件、10 处调用点（EmergencyNewManagerImpl、RecentMeetingService、RecentPolicyService、ChannelHotpointMgr、FieldHotpointMgr、PortalRankMgr）。

## 来源

- 工程：tmy-decision-center
- 触发测试：`WeiboBombTest.java#test`
- 影响文件：6 个 Manager/Service 文件
- 日期：2026-05-08
- 记录人：吴少辉

## 参考

- 相关 risk：R-020（PG 严格类型检查）
- 关联 fix-issue：`2026-05-08-weibo-bomb-distinct-on-ordering.md`（DISTINCT ON 排序约束）
