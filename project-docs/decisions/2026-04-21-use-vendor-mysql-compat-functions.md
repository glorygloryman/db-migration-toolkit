---
type: decision
title: 使用厂家 MySQL 函数兼容脚本而非逐条改写
created: 2026-04-21
updated: 2026-04-21
status: accepted
supersedes: 无
---

# 使用厂家 MySQL 函数兼容脚本而非逐条改写

## 背景

瀚高 v4.1.5 作为 PG 系数据库，不原生支持 MySQL 函数（`IFNULL` / `DATE_FORMAT` / `FIND_IN_SET` / `IF()` / `STR_TO_DATE` / `TO_DAYS` / `LAST_DAY` / `DAYOFYEAR` / `TRUNCATE` / `CURDATE` / `MONTH` / `YEAR` 等）。工程中这些函数广泛散布于 Mapper XML、`@Query` 注解、字符串拼接 SQL。

厂家提供 [`highgo-v4.1.5-mysql-compat-functions.sql`](../../docs/references/highgo-v4.1.5-mysql-compat-functions.sql)，通过 `CREATE OR REPLACE FUNCTION` 在目标库 DB 层一次性注入兼容函数。

## 候选方案

### 方案 A：注入厂家脚本 ✅ 采纳

**优点**：
- 应用层 SQL 几乎不改（函数调用保持原样）
- 一次注入、全库通用，多工程共享
- 脚本 `CREATE OR REPLACE`，幂等可重放

**代价**：
- DB 层多一层非原生函数，升级/迁移时需同步处理
- 兼容不完整：部分类型重载缺失（`IFNULL` 无 timestamp，`IF` 无 int/text）
- `DATE_FORMAT` 实现存在递归调用自身风险
- 版本兼容性仅验证了 v4.1.5，其他版本 ⚠️

### 方案 B：应用层逐条改写 ❌ 拒绝

工作量巨大；破坏测试基线；违背"不改架构"原则。

### 方案 C：JDBC / MyBatis Interceptor 动态改写 ❌ 拒绝

需要自研 shim；调试困难、性能损耗；与拦截器链冲突。

## 决策

**采用方案 A（注入厂家脚本）**。

## 约束与后果

- **Stage 2 新增动作**：环境搭建时必须先在目标库注入脚本
- **Stage 4 改造指引**：函数层冲突**首选**依赖脚本，不满足时改写 SQL 或上移 Java 层
- **脚本缺口必须记录**：发现某个 MySQL 函数调用不被脚本覆盖，在 `mysql-to-highgo-function-mapping.md` 的"脚本缺口"列追加说明
- **Pilot 验证项**：首要验证 `DATE_FORMAT` 不死循环、`IF()` 类型覆盖、`IFNULL` 时间类型是否降级到 `COALESCE`

## 脚本版本管理（per A4）

**背景**：脚本是 DB 层外挂资产，需要版本追踪机制防止工具包、厂家、下游工程之间漂移。

**机制**：

1. **脚本自带版本函数**：脚本末尾注入
   ```sql
   CREATE OR REPLACE FUNCTION mysql_compat_version()
   RETURNS text AS $$ SELECT '1.0.0-highgo-v4.1.5-vendor-2026-04-21' $$
   LANGUAGE sql IMMUTABLE;
   ```

2. **版本命名约定**：`<工具包封装版本>-highgo-<瀚高版本>-<来源>-<日期>`
   - 工具包封装版本：语义化版本（含本地修改时 bump patch）
   - 来源：`vendor` / `vendor-patched` / `community`

3. **Pilot 注入验证**：
   ```sql
   SELECT mysql_compat_version();
   ```
   结果记录到工程 baseline.md §1"目标库信息"章节。

4. **升级流程**：
   - 厂家发布新版本 → PR 到本仓库，bump 版本号、更新 CHANGELOG
   - 本地发现 Bug 修复 → PR 到本仓库，改 `vendor` 为 `vendor-patched`，bump patch
   - 下游工程发现版本落后 → Stage 2 重新注入新版本脚本

5. **已知风险**：R-017（脚本版本管理在多工程间漂移），见 `known-risks-highgo.md`

## 何时重新评估

- 瀚高后续版本原生提供全部 MySQL 函数
- 兼容脚本发现致命缺陷无法规避
- 新目标库加入，评估是否有类似 shim
