# GaussDB 兼容模式详解

> 目的：说明 B 兼容模式"兼容 MySQL"的**真实边界**，避免想当然。
> 本文档随 Pilot 验证持续补充。

## 模式一览

GaussDB 支持多种兼容模式，常见：

| 模式 | 别称 | 兼容目标 | 适用场景 |
|------|------|---------|---------|
| A | ORA | Oracle | Oracle 迁移 |
| B | MY / MYSQL | MySQL | MySQL 迁移（**本方案使用**） |
| C | TD | Teradata | 数仓场景 |
| PG | — | 原生 PostgreSQL | 新建应用 |

模式在**数据库创建时**指定（`CREATE DATABASE xxx DBCOMPATIBILITY 'B'`），**库级**属性，不可动态切换。

## B 兼容模式原生支持

以下 MySQL 特性 **可直接跑不需改**（待 Pilot 逐项验证标注）：

| 特性 | 支持状态（预期） | 待验证 |
|------|-----------------|--------|
| 反引号 `` ` `` 标识符 | ✅ | — |
| `LIMIT offset, count` 分页 | ✅ | — |
| `ON DUPLICATE KEY UPDATE` | ✅ | — |
| `REPLACE INTO` | ✅ | — |
| `INSERT IGNORE` | ✅ | — |
| `AUTO_INCREMENT` | ✅ | 初值、步长行为 |
| `GROUP_CONCAT` | ✅ | 分隔符与排序 |
| `IFNULL` / `IF()` | ✅ | — |
| `DATE_FORMAT` / `STR_TO_DATE` | ✅ | 格式占位符一致性 |
| `UNIX_TIMESTAMP` | ✅ | — |
| `TINYINT(1)` 作 Bool | ✅ | JDBC 映射行为 |
| `DATETIME` / `TIMESTAMP` | ✅ | 时区语义 |
| `ENUM` / `SET` | ⚠️ 部分支持 | 建议仍改为 VARCHAR |
| `TEXT` / `MEDIUMTEXT` / `LONGTEXT` | ✅ | 上限 |
| `JSON` + 相关函数 | ✅ | 部分函数名可能差异 |
| `ENGINE=InnoDB` | ⚠️ 语法兼容但无意义 | 建议移除 |
| `DEFAULT CURRENT_TIMESTAMP ON UPDATE` | ✅ | 行为验证 |

## B 兼容模式下仍有的差异

**即使 B 模式，以下仍需关注**：

### 驱动层

- 必须用 `gaussdbjdbc`（华为）而非 MySQL Connector/J
- JDBC URL 格式：`jdbc:gaussdb://host:port/db` 而非 `jdbc:mysql://...`
- Druid 对 GaussDB 无专门 `dbType`，通常用 `postgresql`
- PageHelper / MyBatis-Plus 分页方言走 `postgresql` 更稳

### 字符集与排序

- GaussDB 默认字符集 `UTF8`（非 `utf8mb4`，但等价支持全部 Unicode）
- 排序规则（collation）模型与 MySQL 不同，大小写不敏感比较需显式 `COLLATE` 或应用层处理
- 字符串尾部空格比较行为可能不同

### 时区

- `TIMESTAMP` 在 GaussDB 中有 `WITH TIME ZONE` / `WITHOUT TIME ZONE` 两种，B 模式默认行为需验证
- 会话时区通过 `SET TIME ZONE` 设定，JDBC 连接时可指定
- 应用层若强依赖 `CURRENT_TIMESTAMP` 的"服务器时间"，确认 GaussDB 会话时区配置

### 保留字

B 模式放宽了大量 MySQL 保留字，但 GaussDB / PostgreSQL 引入的保留字仍冲突，例如：
- `user`、`current_user`、`session_user`：B 模式通常兼容
- `type`、`role`：需验证
- `desc`、`order`、`group`：SQL 标准保留字，均需引号

**策略建议**：所有表名、列名**统一用双引号**或全小写无歧义命名，避免踩坑。

### 大小写

- GaussDB 默认将**未加引号的标识符**转为小写（PG 行为）
- B 模式可能调整此行为，需验证 `dolphin.lower_case_table_names` 等参数
- 实操建议：代码里所有 SQL 标识符全小写，避免依赖大小写保留

### 数据类型边缘

- `TINYINT(1)` 是否被 JDBC 驱动映射为 `Boolean`，需测
- `BIT(n)`、`BIT(1)` 行为
- `YEAR` 类型支持情况
- `FLOAT(p)` 精度语义

### 函数行为

- `NOW()` vs `CURRENT_TIMESTAMP`：返回类型与精度
- `CONCAT` 对 NULL 的处理
- `SUBSTRING_INDEX` 是否支持
- 位运算函数

### 执行计划

即使 SQL 语法相同，执行计划可能显著不同：
- JOIN 顺序选择
- 索引使用偏好
- 子查询物化策略

**本方案不做性能调优**，但需记录明显慢查询到 `risks/`。

### 存储过程 / 触发器

B 模式对 MySQL 存储过程语法支持**不完整**。本方案建议不重写存储过程，而是上移到 Java 层。

## 验证方法

对每一条"预期 ✅"的项目，Pilot 时编写一个最小测试：
- SQL 片段
- 输入数据
- 预期输出
- 在 GaussDB B 模式下实测结果

测试集沉淀到 `db-migration-toolkit` 仓库（后续新增 `tests/compatibility/`）。

## 参考资料

- 华为云 GaussDB 官方文档（兼容性章节）
- PostgreSQL 官方文档（作为底层行为参考）
- 本工具包 `fix-issue/` 下的实测记录
