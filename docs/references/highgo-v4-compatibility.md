# 瀚高 v4.1.5 特性详解（MySQL 迁入视角）

> **目的**：从 MySQL 迁入瀚高（HighGo）v4.1.5 的视角，梳理方言 / 驱动 / 字符集 / 时区 / 保留字 / 锁 / 执行计划 / 存储过程等维度的真实边界，避免想当然地以"原生兼容 MySQL"假设推进改造。
> **适用范围**：瀚高 v4.1.5（C10：其他版本适用性 ⚠️ 待 Pilot 核实）。
> **配套脚本**：函数层借厂家 MySQL 函数兼容脚本补齐，详见 [`./highgo-v4.1.5-mysql-compat-functions.md`](./highgo-v4.1.5-mysql-compat-functions.md)。
> **验证原则**：本文所有"预期"结论需 Pilot 在真实目标库逐项实测后标注 ✅ / ❌ / ⚠️；未经验证的项目以 `⚠️ 待 Pilot 核实（Cx）` 形式标注。

---

## 1. 瀚高 v4.1.5 基础定位

- 瀚高数据库 v4.1.5 **基于 PostgreSQL 内核**，是国产 PG 系商用数据库，非 GaussDB。
- 瀚高 v4.1.5 **不存在 "B 兼容模式"** 这一概念 —— 方言层接近**原生 PostgreSQL**，MySQL 生态的反引号、`LIMIT m,n`、`ON DUPLICATE KEY UPDATE` 等语法**不原生支持**。
- MySQL **函数**可通过厂家提供的 MySQL 函数兼容脚本一次性在目标库注入抹平（见配套脚本）。
- MySQL **语法**（反引号、分页语法、Upsert、多表 UPDATE 等）**不被脚本覆盖**，必须在应用层改写。

> **重要**：项目早期曾假定目标库为 GaussDB B 兼容模式（原生兼容大量 MySQL 语法）。此假设已废弃，详见 `project-docs/decisions/2026-04-21-target-db-highgo-v4.md`。本文替代旧版《GaussDB 兼容模式详解》。

---

## 2. 与 MySQL 的核心差异（❌ 必须改写 / ⚠️ 必须验证）

### 2.1 语法层：明确不兼容，必须改写

| 特性 | MySQL 写法 | 瀚高 v4.1.5 支持 | 推荐改法 | 关联 |
|------|-----------|------------------|----------|------|
| 标识符反引号 | `` `col` `` / `` `user` `` | ❌ 不支持 | 改双引号 `"col"`，推荐统一全小写无歧义命名 | C5 |
| 分页 `LIMIT m,n` | `LIMIT 10, 20` | ❌ 不支持 | 改 `LIMIT 20 OFFSET 10` | C6 |
| Upsert | `INSERT ... ON DUPLICATE KEY UPDATE` | ❌ 不支持 | 改 `INSERT ... ON CONFLICT (...) DO UPDATE SET ...` | C7 |
| 多表 UPDATE | `UPDATE a JOIN b ON ... SET ...` | ❌ 不支持 | 改 `UPDATE a SET ... FROM b WHERE ...` |  |
| 带 LIMIT 的 UPDATE / DELETE | `UPDATE t SET ... LIMIT n` | ❌ 不支持 | 改写为子查询 `WHERE pk IN (SELECT pk FROM t ... LIMIT n)` |  |
| `REPLACE INTO` | `REPLACE INTO t ...` | ❌ 不支持 | 改 `INSERT ... ON CONFLICT ... DO UPDATE` |  |
| `INSERT IGNORE` | `INSERT IGNORE INTO t ...` | ❌ 不支持 | 改 `INSERT ... ON CONFLICT ... DO NOTHING` |  |

> 上述 ❌ 判定来源于"瀚高 v4.1.5 基于 PG 内核且不提供 B 兼容"这一架构前提；Pilot 仍应以最小用例逐项实测确认。

### 2.2 驱动层

| 项 | 取值 | 备注 |
|----|------|------|
| JDBC 坐标 | `<待确认-瀚高-jdbc-坐标>` | ⚠️ 待 Pilot 核实（C2） |
| JDBC 驱动类 | `<待确认-瀚高-驱动类>` | ⚠️ 待 Pilot 核实（C2） |
| JDBC URL scheme | `jdbc:highgo://host:port/db` | ⚠️ 待 Pilot 核实（C3） |
| Druid `dbType` | `postgresql` | ⚠️ 待 Pilot 核实（C4） |
| MyBatis-Plus / PageHelper 方言 | 走 `postgresql` 方言 | ⚠️ 待 Pilot 核实（C4） |

> 不得继续使用 MySQL Connector/J 或 GaussDB JDBC（`com.huawei.gaussdb:gaussdbjdbc`）坐标。

### 2.3 字符集与排序规则

- PG 生态默认字符集 `UTF8`（而非 `utf8mb4`，语义上等价支持完整 Unicode）。
- 排序规则（collation）模型与 MySQL 不同：
  - MySQL 列级 `utf8mb4_general_ci` 的大小写不敏感比较，PG 默认**区分大小写**；需要时以 `COLLATE "C"` / `ILIKE` / `LOWER()` 或应用层降级处理。
  - 字符串尾部空格比较行为与 MySQL 可能不一致。
- 索引选择、`ORDER BY` 稳定性与 collation 绑定，需 Pilot 在真实数据上回归。

### 2.4 时区与 `TIMESTAMP` 语义

- PG 有两类时间戳：`TIMESTAMP WITHOUT TIME ZONE`（无时区，仅存字面量）与 `TIMESTAMP WITH TIME ZONE`（`TIMESTAMPTZ`，按会话时区转换）。
- MySQL 迁移建议：
  - `DATETIME` → `TIMESTAMP WITHOUT TIME ZONE`（PG 无 `DATETIME` 类型）。
  - `TIMESTAMP` → `TIMESTAMPTZ`（保留时区语义更稳妥）。
- `ON UPDATE CURRENT_TIMESTAMP` 列级修饰 **PG 不原生支持**，需触发器模拟或应用层在 UPDATE 时显式赋值。
- 会话时区：JDBC 连接参数或 `SET TIME ZONE` 设定。若应用强依赖"服务器时间"，Pilot 必须落实会话时区默认值与 `CURRENT_TIMESTAMP` 返回值。

### 2.5 保留字

- 瀚高继承 PG 保留字体系，对 MySQL 常用列名可能冲突：`user`、`order`、`group`、`desc`、`type`、`role`、`current_user`、`session_user` 等。
- **策略**：所有可能冲突的标识符统一加双引号 `"user"`，或改名为无歧义形式（如 `user_info`、`order_info`）。
- 完整保留字清单 ⚠️ 待 Pilot 核实瀚高 v4.1.5 官方文档（是否在 PG 基础上新增保留字）。

### 2.6 事务与锁

- PG 采用 MVCC，可重复读 / 已提交读 / 可串行化三个隔离级别实现细节与 MySQL InnoDB 存在差异。
- `SELECT ... FOR UPDATE` / `FOR SHARE` 在 PG 中行为基于行版本，对**未命中索引**的锁放大范围与 MySQL 间隙锁不同。
- 死锁检测与日志格式差异 —— ⚠️ 待 Pilot 核实。
- 建议迁移期间专项回归核心事务场景（幂等下单、库存扣减、唯一索引竞争）。

### 2.7 执行计划

即便 SQL 语法一致，执行计划可能显著不同：
- JOIN 顺序与物化策略与 MySQL 优化器不同。
- PG 基于统计信息估算，`ANALYZE` / `autovacuum` 行为需纳入运维 SOP。
- 子查询展开、`LATERAL`、`DISTINCT ON` 等 PG 特性可用作性能改写手段。
- **本方案不做性能调优**；Pilot 发现的明显慢查询记录至 `docs/risks/known-risks-highgo.md`。

### 2.8 存储过程 / 触发器

- PG 使用 `PL/pgSQL`，与 MySQL 存储过程语法完全不同。
- 瀚高 v4.1.5 是否额外提供 MySQL 存储过程语法糖：⚠️ 待 Pilot 核实。
- **策略**：本方案原则上**不重写存储过程**，推动业务上移到 Java 层；必须保留的过程由 DBA 单独改写为 PL/pgSQL。

---

## 3. 与 MySQL 的对齐项（函数层：借兼容脚本）

以下 MySQL 函数在瀚高 v4.1.5 下**通过厂家 MySQL 函数兼容脚本**（`highgo-v4.1.5-mysql-compat-functions.sql`）一次性预装提供，迁入工程通常**无需改写**：

- `IFNULL(a, b)`（integer / numeric / varchar / text 重载）
- `IF(cond, a, b)`（DATE / TIMESTAMPTZ / BOOLEAN 重载）
- `DATE_FORMAT(ts, fmt)`
- `STR_TO_DATE(str, fmt)`
- `FIND_IN_SET(needle, haystack)`
- `TO_DAYS(date)` / `LAST_DAY(date)` / `DAYOFYEAR(date)`
- `CURDATE()` / `MONTH(ts)` / `YEAR(ts)`
- `TRUNCATE(num, decimals)`
- 其他常用 MySQL 函数见脚本说明文档

> **详细覆盖清单、签名、已知缺口**：见 [`./highgo-v4.1.5-mysql-compat-functions.md`](./highgo-v4.1.5-mysql-compat-functions.md)。

---

## 4. 已知缺口（脚本未覆盖，Pilot 必验）

| 缺口 | 现象 | 规避 / 改写 |
|------|------|------------|
| `IFNULL` 无 timestamp / date 重载 | `IFNULL(NULL::timestamp, NOW())` 将报 `function ifnull(timestamp, timestamp) does not exist` | 时间类型改 `COALESCE(a, b)` |
| `IF` 无 int / text / numeric 重载 | `IF(cond, 1, 0)` / `IF(cond, 'a', 'b')` 解析失败 | 改写为 `CASE WHEN cond THEN ... ELSE ... END` |
| `DATE_FORMAT` 递归风险 | 脚本内 `date_format(...)` 实现调用大写 `DATE_FORMAT(...)`；若瀚高 v4.1.5 未原生提供 `DATE_FORMAT`，将发生无限递归栈溢出 | **Pilot 首验证项**，关联风险 R-002；若未原生支持，必须由 DBA 修补脚本或改 `to_char(ts, ...)` |
| 脚本版权与分发限制 | ⚠️ 待 Pilot 核实（C8） | 内部使用前确认厂家授权范围 |
| 脚本注入权限 | ⚠️ 待 Pilot 核实（C9） | 暂按建库 owner 在 public schema 注入 |

---

## 5. 验证方法

对每一条"预期 ❌ / ✅ / ⚠️"项目，Pilot 阶段编写一个最小测试用例，内容包含：

1. **SQL 片段**（最短能暴露差异的语句）
2. **输入数据**（必要时 `VALUES (...)` 或临时表）
3. **预期输出**（MySQL 下的结果 / 预设瀚高下的结果）
4. **瀚高 v4.1.5 实测结果**（连同版本号、会话参数）

关键快速验证集（节选，完整集合另行沉淀至 `tests/compatibility/`）：

```sql
-- 1. DATE_FORMAT 不递归栈溢出（R-002 关键）
SELECT DATE_FORMAT(NOW(), '%Y-%m-%d');
SELECT DATE_FORMAT('2025-01-01'::timestamptz, '%Y%m');

-- 2. IFNULL 整型重载可用
SELECT IFNULL(NULL::integer, 0);

-- 3. IFNULL 无 timestamp 重载（预期报错）
SELECT IFNULL(NULL::timestamp, NOW());

-- 4. 反引号（预期语法错，C5）
SELECT `id` FROM demo;

-- 5. LIMIT m,n（预期语法错，C6）
SELECT 1 LIMIT 10, 20;

-- 6. ON DUPLICATE KEY UPDATE（预期语法错，C7）
INSERT INTO t(id, v) VALUES (1, 'a') ON DUPLICATE KEY UPDATE v = 'b';
```

测试结果与踩坑实录沉淀至 `fix-issue/` 与 `project-docs/facts/`（含 `updated` 字段）。

---

## 6. 参考资料

- 瀚高数据库 v4.1.5 官方文档（⚠️ 待 Pilot 补具体链接与版本号）
- PostgreSQL 官方文档（作为底层行为参照）
- 厂家 MySQL 函数兼容脚本说明：[`./highgo-v4.1.5-mysql-compat-functions.md`](./highgo-v4.1.5-mysql-compat-functions.md)
- 类型映射：[`./mysql-to-highgo-type-mapping.md`](./mysql-to-highgo-type-mapping.md)
- 语法映射：[`./mysql-to-highgo-syntax-mapping.md`](./mysql-to-highgo-syntax-mapping.md)
- 函数映射：[`./mysql-to-highgo-function-mapping.md`](./mysql-to-highgo-function-mapping.md)
- 已知风险：[`../risks/known-risks-highgo.md`](../risks/known-risks-highgo.md)
- 目标库切换决策：`project-docs/decisions/2026-04-21-target-db-highgo-v4.md`
- 本工具包 `fix-issue/` 下的实测记录
