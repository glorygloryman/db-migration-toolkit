---
updated: 2026-06-01
source: event_server/Configuration/src/main/resources/bootstrap.yml
related-risk: 无
severity: 🟡
category: 连接池
---

# HikariCP connection-init-sql 方言不兼容

## 现象

切换数据库后，HikariCP 连接池初始化失败，报 SQL 语法错误：

```
SQLSyntaxErrorException: ... near 'TO 'UTF8'' at line 1
```

或（反向场景）：

```
ERROR: syntax error at or near "NAMES"
```

## 根因

HikariCP 的 `connection-init-sql` 在每次获取连接时执行。MySQL 使用 `SET NAMES 'utf8mb4'`，PostgreSQL/瀚高使用 `SET client_encoding TO 'UTF8'`。两者语法互不兼容，切换数据库时必须同步修改。

配置通常位于：
- `bootstrap.yml` / `application.yml` 中的 `spring.datasource.hikari.connection-init-sql`
- 或环境专用的 properties 文件

## 修复动作 / 规避准则

将 `connection-init-sql` 放入环境专用配置，而非公共配置：

```yaml
# MySQL 环境
spring.datasource.hikari.connection-init-sql=SET NAMES 'utf8mb4'

# PostgreSQL/瀚高 环境
spring.datasource.hikari.connection-init-sql=SET client_encoding TO 'UTF8'
```

或在测试配置中按 profile 隔离：

```properties
# application-integration-highgo.properties
spring.datasource.hikari.connection-init-sql=SET client_encoding TO 'UTF8'

# application-integration-mysql-baseline.properties（不设置，或设为 MySQL 语法）
```

- `connection-init-sql` 是数据库方言相关的，**禁止**放在公共配置中
- 切换数据库时，必须同步检查 `connection-init-sql` 的值
- 扫描方法：`rg 'connection-init-sql' --glob '*.yml' --glob '*.properties'`

## 影响范围

所有使用 HikariCP 并配置了 `connection-init-sql` 的 Spring Boot 工程。迁移到瀚高时若不同步修改，连接池初始化即失败，所有数据库操作不可用。

## 来源

- 工程：event_server
- 文件：Configuration/src/main/resources/bootstrap.yml
- 阶段：Stage 4 方言适配
- 日期：2026-05-29
- 记录人：wushaohui
