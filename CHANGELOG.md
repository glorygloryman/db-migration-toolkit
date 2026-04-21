# Changelog

## v0.1.0 — 2026-04-18

首发骨架版。

### 新增
- 母方案文档（五段式 SOP）
- 六份阶段操作手册（Stage 0 ~ Stage 5）
- 三份检查清单（前置调研 / PR / 验收）
- 四份参考对照表（类型 / 语法 / 函数 / 兼容模式）
- 四份文档模板（baseline / risk-matrix / test-gap / report）
- 一份风险库（GaussDB 已知风险）
- 六个 Skills 骨架（步骤大纲，Pilot 后精化）

### 前提
- 目标库：GaussDB B 兼容模式
- 不做数据迁移，仅程序适配
- 不改架构，保留原持久层结构
- 集成测试用本地/共享真实库

### 待办
- Pilot 工程 `stream_keywords_search` 启动
- 根据 Pilot 输出回灌 fix-issue 与 references
- 预计 Pilot 完成后发布 v1.0.0
