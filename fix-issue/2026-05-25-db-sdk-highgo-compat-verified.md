---
updated: 2026-05-25
source: bigv_data_receive/stage-5-highgo-migration-1.0.0
related-risk: R-008
severity: 🟢
category: 框架兼容性
---

# db-sdk (trs-db-sdk) 瀚高兼容性验证通过

## 背景

风险矩阵 R-008 标记 db-sdk 1.4.11 为 🟡 中风险（框架级），原因：

- db-sdk 内部 SQL 生成逻辑是否已支持瀚高方言未确认
- file-consumer 模块使用 `AbsBeanRepository` → `DhMediaAnalysisRepository` / `PictureRelationInfoRepository`
- 依赖方担心 db-sdk 的 SQL 拼接、类型映射等在瀚高下报错

## 验证方式

Stage 5 验收中，file-consumer 模块在瀚高环境下跑完全部 30 个集成测试（`mvn -P integration-highgo clean test`），连接类型确认切换为 `com.highgo.jdbc.jdbc.PgConnection`。

```
Tests run: 30, Failures: 0, Errors: 0, Skipped: 0
BUILD SUCCESS
```

包含 db-sdk 相关 Repository 的测试类全部通过。

## 结论

db-sdk 1.4.11 **当前使用模式**在瀚高环境下无兼容性问题。

关键原因：db-sdk 在本工程中的使用模式是 **实体映射 + Hybase 搜索引擎操作**，不涉及关系型 SQL 生成（无 SELECT/INSERT/UPDATE/DELETE 拼接）。因此瀚高方言差异对 db-sdk 无影响。

## 适用范围与前提

此验证结论仅适用于以下条件：

1. db-sdk 版本为 1.4.11
2. 使用模式为 `AbsBeanRepository` 子类 + Hybase 搜索操作
3. 不涉及 db-sdk 的关系型 SQL 生成功能（如有，需另行验证）

**如果其他工程使用 db-sdk 的关系型 SQL 功能（如自定义 SQL 拼接、复杂查询构建器等），仍需单独验证。**

## 对工具包 SOP 的建议

在风险评估阶段，如果 db-sdk 的使用仅限于 Hybase 搜索引擎操作，R-008 可直接降级为 🟢 低风险并标注"已验证"，无需 decision-deferred。

## 来源

- 工程：bigv_data_receive (trs_data_receive)
- 验证环境：瀚高 v4.1.5，`192.168.211.181:5866`
- 脚本版本：`1.0.0-highgo-v4.1.5-vendor-2026-04-21`
- 日期：2026-05-25
- 记录人：wushaohui
