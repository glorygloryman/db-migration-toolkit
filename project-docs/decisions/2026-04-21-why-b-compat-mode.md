---
type: decision
title: 为什么选 GaussDB B 兼容模式而非 PG 模式
created: 2026-04-21
updated: 2026-04-21
status: superseded
superseded_by: project-docs/decisions/2026-04-21-target-db-highgo-v4.md
---

# 为什么选 GaussDB B 兼容模式而非 PG 模式

> ⚠️ **本决策已废弃**（2026-04-21）。项目真实目标库为瀚高 v4.1.5，非 GaussDB。
> 见替代决策：[`2026-04-21-target-db-highgo-v4.md`](./2026-04-21-target-db-highgo-v4.md)。
> 本文件保留用于记录思维演化，**不再作为行动指引**。

## 背景

GaussDB 支持多种兼容模式，其中与本工具包相关的两种：

- **B 兼容模式**：语法兼容 MySQL
- **PG 兼容模式**（默认）：语法贴近 PostgreSQL

`xz-source/` 下现有工程全部基于 MySQL 构建，持久层采用 MyBatis / JPA / JdbcTemplate。必须选定一种兼容模式作为**本工具包的唯一目标**，否则 SOP / 对照表 / Skill 无法收敛。

## 候选方案

### 方案 A：B 兼容模式 ✅ 采纳

**优点**：
- 原生支持反引号、`LIMIT m,n`、`ON DUPLICATE KEY UPDATE`、`AUTO_INCREMENT`、`GROUP_CONCAT`、`IFNULL`、`DATE_FORMAT`、`TINYINT(1)` 等 MySQL 高频特性
- 预估 Stage 4（方言适配）工作量较 PG 模式下降 **60%~80%**
- 与"不改架构，只做方言适配"原则匹配（`master-plan.md §1.1`）
- Schema DDL 改动面小（类型映射表大部分可恒等）

**代价**：
- B 模式并非 GaussDB 默认模式，需在建库时显式指定
- B 模式功能支持略滞后于 PG 模式（新特性优先在 PG 模式落地）
- 仍有少量边缘差异必须处理：JDBC 驱动 `gaussdbjdbc`、Druid `dbType`、字符集、时区、保留字清单、部分函数行为、存储过程/触发器语法

### 方案 B：PG 兼容模式 ❌ 拒绝

**优点**：
- GaussDB 官方主推模式，功能完整度最高
- 未来若 `xz-source/` 有新工程直接上 PG 生态可复用

**代价**：
- Stage 4 工作量爆炸：`LIMIT`、反引号、大量 MySQL 专属函数需逐个改写
- 可能触发 Stage 3 Schema 层面的类型与默认值语义差异
- 违背"不改架构"原则，实际接近"迁移到 PostgreSQL"的体量
- 对存量 20+ 工程推广成本过高

## 决策

**采用方案 A（B 兼容模式）**，原因：

1. 工具包的核心价值命题是"让存量 MySQL 工程以最低成本切到 GaussDB"，B 模式直接对齐这一命题
2. 改造量可控意味着单工程周期可压缩到 2~5 天，利于规模化推广到 20+ 工程
3. 即便 B 模式有边缘差异，也已收敛到可枚举的清单（见 `docs/references/gaussdb-compatibility-modes.md`）

## 约束与后果

- 所有 `docs/references/*.md` 对照表**默认目标是 B 模式**，PG 模式下的差异不在对照表范围内
- 所有 Skill 的扫描规则、建议改写策略**默认 B 模式行为**
- 若未来某工程被要求上 PG 模式——**视为另一类改造**，不走本工具包 SOP，单独评估
- `application.yml` 与 JDBC URL 层面必须显式指定 B 模式参数（具体参数由 Pilot 阶段落实到 `stage-2-config-switch.md`）

## 何时重新评估

- GaussDB 官方弃用或大幅收缩 B 模式支持
- `xz-source/` 生态整体迁移到非 MySQL 家族（概率极低）
- Pilot 发现 B 模式下某类关键特性不支持且无替代方案
