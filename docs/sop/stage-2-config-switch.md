# Stage 2 — 依赖与配置切换

## 目标

把工程的**数据源、驱动、连接池、方言、Flyway** 切换到 GaussDB，应用可启动并连得上 GaussDB，但不涉及 SQL 改造。

## 预计工期

0.5 天

## 输入

- GaussDB 测试环境连接信息
- 华为 `gaussdbjdbc.jar`（或对应 Maven 坐标）

## 步骤

### 2.1 JDBC 驱动替换

`pom.xml`：
- 保留 `mysql-connector-java`（Stage 5 之前还要跑 MySQL 基线）
- 新增 `com.huawei.gaussdb:gaussdbjdbc`（具体坐标按实际获取）

**注意**：`gaussdbjdbc` 通常不在 Maven 中央仓库，需通过公司内部仓库或本地 `install` 安装。这一步如遇阻塞，记录到 `project-docs/fix-issue/`。

### 2.2 多 profile 配置

在 `src/main/resources/` 下新建：
- `application-integration-mysql-baseline.yml`（Stage 1 已用）
- `application-integration-gaussdb.yml`（本阶段新建）

两份文件除 `spring.datasource` 外其他一致，便于对照跑测试。

GaussDB 侧示例：
```yaml
spring:
  datasource:
    driver-class-name: com.huawei.gauss200.jdbc.Driver  # 以实际驱动类为准
    url: jdbc:gaussdb://host:port/db?currentSchema=xxx
    username: xxx
    password: xxx
    # 若使用 Druid
    druid:
      db-type: postgresql   # Druid 对 GaussDB 的 dbType，按实际测试
```

### 2.3 连接池方言适配

**Druid**：
- `filters`、`wall` SQL 防火墙对 GaussDB 认知不完整，初期可 `remove wall`
- `db-type` 设为 `postgresql`（B 模式下兼容性较好，待 Pilot 验证）
- `validation-query` 改为 `SELECT 1`（MySQL / GaussDB 均兼容）

**HikariCP**：
- `maximum-pool-size` 下调 30%~50%（GaussDB 连接资源通常比 MySQL 紧）
- `connection-test-query` 设 `SELECT 1`

### 2.4 分页插件方言

**PageHelper**：
```yaml
pagehelper:
  helper-dialect: postgresql   # 即使 B 模式，PageHelper 方言按 pg 走更稳
```

**MyBatis-Plus PaginationInnerInterceptor**：
```java
new PaginationInnerInterceptor(DbType.POSTGRE_SQL)
```

**注意**：此处使用 `postgresql` 方言是**务实选择**——PageHelper / MP 对 GaussDB 无原生方言，B 模式下 `LIMIT m,n` 虽兼容，但插件层生成分页 SQL 时若用 `mysql` 方言可能出现结果集列顺序或 count SQL 问题，走 pg 方言反而更稳。Pilot 中验证确认。

### 2.5 Flyway 目录切分

```
src/main/resources/db/migration/
├── mysql/           # 原有脚本，保留不动
│   ├── V1__...sql
│   └── V2__...sql
└── gaussdb/         # 新建，Stage 3 填充
    └── .gitkeep
```

`application-integration-gaussdb.yml`：
```yaml
spring:
  flyway:
    locations: classpath:db/migration/gaussdb
    baseline-on-migrate: true
    baseline-version: 0
```

**严禁**：修改 `db/migration/mysql/` 下任何历史脚本（CLAUDE.md §3.6）。

### 2.6 字符集与时区

- GaussDB 库级字符集建议 `UTF8`
- `url` 参数：`?currentSchema=xxx&characterEncoding=UTF-8`
- 时区：若工程使用 `TIMESTAMP` 存时间戳，确认 GaussDB 会话时区与 MySQL `time_zone` 一致（通常 `Asia/Shanghai` / `+08:00`）

### 2.7 启动冒烟

```bash
mvn -P integration-gaussdb spring-boot:run
```

目标：**应用启动成功**，即使 Schema 还没建完，至少 DataSource 能初始化、Flyway 能连上。

启动失败的常见原因：
- 驱动类名错误
- Druid 不识别 GaussDB → `db-type` 改 `postgresql`
- Flyway baseline 报错 → 先设 `baseline-on-migrate: true`

把所有报错记录到 `project-docs/fix-issue/`。

## 出口检查

- [ ] `pom.xml` 同时含 MySQL 与 GaussDB 驱动
- [ ] 两份 `application-integration-*.yml` 可独立运行
- [ ] Druid / HikariCP / PageHelper 方言参数已改
- [ ] `db/migration/gaussdb/` 目录已创建，历史脚本未动
- [ ] `mvn -P integration-gaussdb` 启动无致命错

## 产出物

- `pom.xml` 变更
- 两份 profile 配置文件
- `db/migration/gaussdb/` 目录

## 下一阶段

→ [Stage 3 — Schema 迁移](stage-3-schema-migration.md)
