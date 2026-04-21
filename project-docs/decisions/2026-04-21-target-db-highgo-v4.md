---
type: decision
title: 目标库改为瀚高（HighGo）v4.1.5
created: 2026-04-21
updated: 2026-04-21
status: accepted
supersedes: project-docs/decisions/2026-04-21-why-b-compat-mode.md
---

# 目标库改为瀚高（HighGo）v4.1.5

## 背景

项目启动时假定目标库为 GaussDB B 兼容模式（见已废弃决策 `why-b-compat-mode.md`）。2026-04-21 根据最新实施环境信息，目标库确认为**瀚高数据库 v4.1.5**，非 GaussDB。需要调整工具包的全部假设、SOP、对照表、Skills。

## 新的事实

1. 瀚高 v4.1.5 基于 **PostgreSQL 内核**，非 GaussDB
2. 瀚高**不提供** GaussDB 式的 "B 兼容模式" —— 方言层接近原生 PG
3. 厂家提供 **MySQL 函数兼容脚本**（`docs/references/highgo-v4.1.5-mysql-compat-functions.sql`），覆盖常用 MySQL 函数（IFNULL / DATE_FORMAT / FIND_IN_SET / IF / STR_TO_DATE 等）
4. 脚本仅覆盖**函数**，不覆盖**语法**（反引号、LIMIT m,n、ON DUPLICATE KEY UPDATE 等仍需改写）

## 决策

- **目标库统一为瀚高 v4.1.5**，不再面向 GaussDB
- **基础方言按 PostgreSQL** 处理
- **MySQL 函数优先依赖厂家兼容脚本**抹平；无法覆盖的再走 Stage 4 逐条改写
- 改造量预估重新校准（见 `docs/2026-04-18-master-plan.md §1.2`）

## 后果

- 工具包全部文档、对照表、SOP、Skills 需整改
- Stage 4 工作量比"GaussDB B 模式"假设下显著增加（语法层无法偷懒），但比"纯 PG 无兼容脚本"假设下显著减少（函数层全免改）
- `references/` 新增"瀚高 v4.1.5 特性详解"与"兼容脚本说明"两份资产
- 旧决策 `why-b-compat-mode.md` 保留但状态置 `superseded`

## 何时重新评估

- 瀚高后续版本原生提供 MySQL 语法兼容
- 消费方被要求切换到其他 PG 系数据库（openGauss / KingbaseES / 达梦 PG 模式等），评估本工具包能否通用
