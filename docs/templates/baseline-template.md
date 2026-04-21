---
updated: YYYY-MM-DD
project: <工程名>
stage: 0-kickoff
---

# <工程名> 数据库改造基线

## 1. 目标库信息

- **目标数据库**：瀚高（HighGo）v4.1.5
- **版本**：v4.1.5（暂定，C1 待核实）
- **内核**：基于 PostgreSQL（具体内核版本 ⚠️ 待核实）
- **部署形态**：单机 / 集群（选一）
- **JDBC 驱动**：`<待确认-瀚高-jdbc-坐标>:<版本>`（C2）
- **MySQL 兼容脚本版本**：注入后执行 `SELECT mysql_compat_version()` 填写，示例 `1.0.0-highgo-v4.1.5-vendor-2026-04-21`（R-017）
- **测试环境连接**：host=<占位>, port=<占位>, db=<占位>，凭据见内部配置
- **与生产区别**：<如有>

## 2. 持久层盘点

| 项 | 当前值 |
|----|--------|
| ORM 框架 | MyBatis / MyBatis-Plus / JPA / JdbcTemplate（可多选） |
| ORM 版本 | |
| 分页插件 | PageHelper / MP `PaginationInnerInterceptor` / 自研 |
| 分页方言（改造后目标） | postgresql |
| 连接池 | Druid / HikariCP |
| 连接池版本 | |
| Flyway / Liquibase | 启用 / 未启用 |
| 当前迁移脚本数 | |
| 存储过程 | 有 / 无，数量 |
| 触发器 | 有 / 无，数量 |
| 事件（EVENT） | 有 / 无 |

## 3. 当前 MySQL 运行信息

- **版本**：MySQL x.x.x
- **字符集**：utf8mb4 / ...
- **排序规则**：utf8mb4_general_ci / ...
- **时区**：`+08:00` / `Asia/Shanghai`
- **`sql_mode`**：<填写>

## 4. 数据源配置现状

- 数据源数量：<填写>
- 是否多数据源 / 读写分离：<填写>
- 是否分库分表（ShardingSphere / MyCat）：<填写>
- 是否涉及跨库事务：<填写>

## 5. SQL 仓统计

| 指标 | 数值 |
|------|------|
| Mapper XML 文件数 | |
| Mapper XML 总行数 | |
| 动态 SQL 片段数 | |
| `@Query` / `@Select` 等注解 SQL 数 | |
| Native Query 方法数 | |
| 代码中字符串拼接 SQL 位置数 | |
| JSON 字段查询位置数 | |

## 6. 关键业务模块

列出本工程中**与数据库交互密度最高**的模块，作为 Stage 1 测试优先补的对象：

| 模块 | 入口 | DAO / Mapper 类数 | 备注 |
|------|------|-------------------|------|
| | | | |

## 7. 测试现状

| 项 | 数值 |
|----|------|
| 单元测试类数 | |
| 集成测试类数 | |
| 覆盖率（若有） | |
| 是否连真实 DB 的集成测试 | 是 / 否 |
| `@MockBean` 替代 DB 情况 | |
| Testcontainers 使用 | 是 / 否 |

## 8. 其他事实

- 是否有跨工程共享 Schema
- 是否有外部系统直接访问本库
- 是否有报表 / BI 工具连本库

## 9. 填写人 / 日期

- 填写人：
- 日期：YYYY-MM-DD
