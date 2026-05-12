---
updated: 2026-05-11
source: xz_yq_server/MonitorAlertDAO
related-risk: R-004
severity: 🔴
category: 全文检索
---

# 用 LIKE / HighGo 字符串匹配替代 MATCH AGAINST

## 现象

MySQL Mapper 中存在 `MATCH ... AGAINST ... IN BOOLEAN MODE` 全文检索语法：

```xml
AND ( match(alert.msg_uname) against('${keyword}+' in boolean mode) AND alert.situation NOT IN ( 30, 60, 61, 62, 110, 120 ) )
```

来源：

- 工程：`xz_yq_server`
- 文件：`src/main/java/trs/cloud/xz/mapper/generator/sqlmap-custom-monitorAlert.xml`
- DAO：`MonitorAlertDAO`
- 场景：`searchLocation == 2` 时按 `alert.msg_uname` 做账号名 / 用户名检索

## 根因

`MATCH(...) AGAINST(... IN BOOLEAN MODE)` 是 MySQL FULLTEXT 查询语法。HighGo / PostgreSQL 系不支持该语法，迁移时不能直接保留。

该 SQL 还有一个独立风险：`${keyword}` 是字符串直拼。迁移时应同步改为 `#{keyword}` 参数化，避免关键字中的特殊字符破坏 SQL，并降低 SQL 注入风险。

## 选定方案

采用 `LIKE` / HighGo 字符串匹配替代 `MATCH AGAINST`。

建议改写方向：

```xml
AND (
  alert.msg_uname LIKE CONCAT('%', #{keyword}, '%')
  AND alert.situation NOT IN (30, 60, 61, 62, 110, 120)
)
```

实施要点：

1. 使用 `#{keyword}` 参数化，不再使用 `${keyword}` 拼接。
2. 保留原有 `alert.situation NOT IN (30, 60, 61, 62, 110, 120)` 业务过滤。
3. 保留 Mapper 查询结构，不把该查询上移到服务层，也不切到外部搜索服务。
4. 在 HighGo 环境补等价测试，覆盖命中、不命中和排除场景。

## 选择原因

选择 `LIKE` / HighGo 字符串匹配的原因：

1. 当前命中点只有 1 处，且字段是 `msg_uname` 账号名 / 用户名，不是正文大字段搜索。
2. 为单个账号字段引入 PG / HighGo full-text 会增加索引、分词配置和动态表索引维护成本。
3. 外部搜索服务会改变当前 SQL 与其他 Mapper 条件的组合方式，容易造成结果集、分页和总数语义偏差。
4. 服务层过滤需要先查出候选集再过滤，可能改变分页语义，并放大内存和网络开销。
5. `LIKE` 方案改动范围最小，可以同时完成参数化改造，适合第一轮 HighGo 迁移验证。

## 后续验证建议

1. 在 MySQL baseline 和 HighGo 目标库分别验证 `searchLocation == 2` 场景。
2. 使用相同关键字比对总数和前若干条 `alert_id`。
3. 重点验证：
   - 能命中包含关键字的 `msg_uname`
   - 不命中无关键字记录
   - 仍排除 `situation IN (30, 60, 61, 62, 110, 120)` 的记录
4. 如果真实数据量下 `LIKE '%keyword%'` 性能不可接受，再单独评估 HighGo 可用的全文索引、三元组索引或表达式索引；该优化不作为第一轮迁移阻塞项。

## 参考

- 相关 risk：`R-004 MATCH AGAINST`
- 已同步到：`docs/references/mysql-to-highgo-syntax-mapping.md` 的全文检索条目
