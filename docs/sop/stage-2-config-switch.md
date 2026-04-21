# Stage 2 — 依赖与配置切换（瀚高 v4.1.5）

## 目标

把工程的**数据源、驱动、连接池、分页方言、Flyway 目录**切换到瀚高 v4.1.5（基于 PostgreSQL 内核），并**注入厂家 MySQL 兼容脚本**，使应用可启动并连得上瀚高，同时抹平函数层的主要差异。本阶段**不涉及业务 SQL 改造**。

## 预计工期

0.5 ~ 1 天（含兼容脚本注入与冒烟验证）

## 输入

- 瀚高 v4.1.5 测试环境连接信息（host / port / db / schema / user / pwd）
- 瀚高官方 JDBC 驱动 jar（坐标见 §2.1）
- 厂家提供的 **MySQL 兼容脚本**（SQL 文件，由 DBA 或驱动包附带）
- Stage 1 已锁定的 MySQL 基线测试集

## 步骤

### 2.1 JDBC 驱动替换

`pom.xml`：

- **保留** `mysql-connector-java`（Stage 5 之前需要继续跑 `integration-mysql-baseline` profile 做双轨验证）
- **新增** 瀚高 JDBC 驱动：

```xml
<!-- 瀚高 JDBC 驱动 -->
<dependency>
  <!-- 待确认坐标，从厂家获取后回填 -->
  <groupId><待确认-瀚高-jdbc-坐标></groupId>
  <artifactId><待确认-瀚高-jdbc-坐标></artifactId>
  <version><待确认-瀚高-jdbc-坐标></version>
</dependency>
```

**注意**：瀚高驱动通常**不在 Maven 中央仓库**，需通过公司内部 Nexus 或 `mvn install:install-file` 将 jar 装入本地仓库。坐标与驱动类名确认后回填占位符；这一步如遇阻塞，记录到 `project-docs/fix-issue/`。

### 2.2 多 profile 配置

在 `src/main/resources/` 下保持两份 profile 并存：

- `application-integration-mysql-baseline.yml`（Stage 1 已用，保留不动）
- `application-integration-highgo.yml`（本阶段新建）

两份文件除 `spring.datasource` / `spring.flyway.locations` 之外其他尽量一致，便于对照跑测试。

瀚高侧示例（字段按实际环境填写）：

```yaml
spring:
  datasource:
    driver-class-name: <待确认-瀚高-驱动类>
    url: jdbc:highgo://host:port/db?currentSchema=xxx&characterEncoding=UTF-8
    username: xxx
    password: xxx
```

### 2.3 连接池方言适配

**Druid**：

- `db-type` 设为 `postgresql`（瀚高基于 PG 内核，Druid 对 PG 方言识别稳定）
- `filters`、`wall` SQL 防火墙对瀚高认知不完整，初期建议 `remove wall`
- `validation-query` 改为 `SELECT 1`（MySQL / 瀚高 均兼容）

**HikariCP**：

- `maximum-pool-size` 视实际压测下调 30% ~ 50%（PG 系连接资源通常比 MySQL 紧）
- `connection-test-query` 设 `SELECT 1`

### 2.4 分页插件方言

**PageHelper**：

```yaml
pagehelper:
  helper-dialect: postgresql
```

**MyBatis-Plus PaginationInnerInterceptor**：

```java
new PaginationInnerInterceptor(DbType.POSTGRE_SQL)
```

**说明**：瀚高基于 PG 内核，分页语法为 `LIMIT n OFFSET m`（不支持 MySQL 的 `LIMIT m, n`），分页插件必须走 PG 方言；代码侧如有裸写 `LIMIT m, n` 的地方由 Stage 4 按风险矩阵改写。

### 2.5 Flyway 目录切分

```
src/main/resources/db/migration/
├── mysql/           # 原有脚本，保留不动
│   ├── V1__...sql
│   └── V2__...sql
└── highgo/          # 新建，Stage 3 填充业务 Schema，本阶段仅放 V0_0_1 前置脚本（可选，见 §2.6）
    └── .gitkeep
```

`application-integration-highgo.yml`：

```yaml
spring:
  flyway:
    locations: classpath:db/migration/highgo
    baseline-on-migrate: true
    baseline-version: 0
```

**严禁**：修改 `db/migration/mysql/` 下任何历史脚本（CLAUDE.md §3.6）。

### 2.6 注入厂家 MySQL 兼容脚本（R-002 / R-015 / R-017）

瀚高 v4.1.5 提供一份 **MySQL 兼容脚本**（SQL 文件，厂家交付物），通过创建 PG 函数、扩展算子与重载抹平 `DATE_FORMAT` / `IFNULL` / `FIND_IN_SET` / `TRUNCATE` 等常用 MySQL 函数。**本阶段必须完成注入**，否则 Stage 4 的函数层适配策略不成立。

#### 方式 A：DBA 手动 psql 注入（推荐用于首次落地）

由 DBA 在目标库以管理员账号执行：

```bash
psql -h <host> -p <port> -U <admin> -d <target-db> -f mysql_compat_functions.sql
```

适用场景：首次部署、脚本版本变更、需要人工审查脚本内容。优点：与业务 Flyway 解耦；缺点：新环境搭建时容易漏掉。

#### 方式 B：Flyway `V0_0_1` 前置脚本自动化（推荐用于 CI / 新环境）

把厂家脚本落地到 `src/main/resources/db/migration/highgo/V0_0_1__mysql_compat_functions.sql`，作为最低版本的 Flyway 迁移脚本，在任何业务 `V{YYYYMMDDHHmm}__` 之前执行。

要求：

- 脚本内容**原样**使用厂家交付版本，不要人为修改；如需修改，走 `project-docs/decisions/` 备案
- 脚本末尾须有 `mysql_compat_version()` 返回值，便于 §2.6 冒烟与 Stage 5 溯源
- 脚本具备幂等能力（`CREATE OR REPLACE FUNCTION`），重复执行不报错
- `application-integration-highgo.yml` 中 `baseline-version` 设为小于 `0.0.1` 的值（如 `0`），使前置脚本能被应用

#### 注入后必测（Pilot 首验证项，R-002 / R-015）

在目标库执行下列 7 条 SQL，**任何一条异常都必须立刻回到 `project-docs/fix-issue/` 记录，评估是否修改脚本实现**；反向测试意外通过说明脚本被私自扩展了重载，需同步更新 `docs/references/mysql-to-highgo-function-mapping.md` 的"脚本覆盖"列。

```sql
-- === 正向可用性测试（4 条）===

-- 1. DATE_FORMAT 不递归栈溢出（R-002 关键）
SELECT DATE_FORMAT(NOW(), '%Y-%m-%d');          -- 期望返回形如 '2026-04-21'
SELECT DATE_FORMAT('2025-01-01'::timestamptz, '%Y%m');  -- 期望 '202501'

-- 2. IFNULL integer 重载可用
SELECT IFNULL(NULL::integer, 0);                -- 期望 0

-- 3. FIND_IN_SET 可用
SELECT FIND_IN_SET('b', 'a,b,c');               -- 期望 2

-- 4. TRUNCATE 可用（含除法场景）
SELECT TRUNCATE(100 / 3::numeric, 2);           -- 期望 33.33（不是 33.00）

-- === 反向缺口验证（3 条，用于确认 Stage 0 SQL 扫描必须标记的调用）===

-- 5. IFNULL 无 timestamp 重载（预期报错）
SELECT IFNULL(NULL::timestamp, NOW());          -- 期望：ERROR function ifnull(timestamp, timestamp) does not exist

-- 6. IF 无 int 重载（预期报错）
SELECT IF(true, 1, 2);                          -- 期望：ERROR function if(boolean, integer, integer) does not exist

-- 7. 版本标记函数返回值（R-017）
SELECT mysql_compat_version();                  -- 期望：'1.0.0-highgo-v4.1.5-vendor-2026-04-21'
```

任一"正向"测试失败或"反向"测试意外通过，立即记录到 `project-docs/fix-issue/`，评估是否修改脚本实现。反向测试意外通过说明脚本被私自扩展过重载，需同步更新 function-mapping 文档的"脚本覆盖"列。

### 2.7 字符集与时区

- 瀚高库级字符集建议 `UTF8`（建库时 `ENCODING 'UTF8' LC_COLLATE 'C' LC_CTYPE 'C'` 或按厂家推荐）
- JDBC URL 参数：`?currentSchema=xxx&characterEncoding=UTF-8`
- 时区：若工程使用 `TIMESTAMP` 存时间戳，确认瀚高会话时区与 MySQL `time_zone` 一致（通常 `Asia/Shanghai` / `+08:00`）；可在连接串追加 `&TimeZone=Asia/Shanghai` 或 Spring 侧统一设置

### 2.8 启动冒烟

```bash
mvn -P integration-highgo spring-boot:run
```

目标：**应用启动成功**，即使业务 Schema 还没建完，至少 DataSource 能初始化、Flyway 能连上目标库、`V0_0_1`（若采用方式 B）执行成功。

启动失败的常见原因：

- 驱动类名错误 → 回到 §2.1 校对 `<待确认-瀚高-驱动类>`
- Druid 不识别瀚高 → `db-type` 设为 `postgresql`
- Flyway baseline 报错 → 确认 `baseline-on-migrate: true` 与 `baseline-version`
- 兼容脚本注入失败 → 回到 §2.6 检查方式 A 是否已执行，或 `V0_0_1` 是否被 Flyway 扫描到

把所有报错记录到 `project-docs/fix-issue/`。

## 出口检查

- [ ] `pom.xml` 同时含 MySQL 与瀚高驱动（坐标占位符已回填真实值）
- [ ] 两份 `application-integration-*.yml` 可独立运行
- [ ] Druid / HikariCP / PageHelper / MyBatis-Plus 方言参数已切到 `postgresql` / `POSTGRE_SQL`
- [ ] `db/migration/highgo/` 目录已创建，历史 `db/migration/mysql/` 脚本未动
- [ ] **兼容脚本已注入目标库（方式 A 或 B），4 项正向冒烟 SQL 全通过，3 项反向冒烟 SQL 全按预期报错，`mysql_compat_version()` 返回预期版本串**
- [ ] `mvn -P integration-highgo spring-boot:run` 启动无致命错

## 产出物

- `pom.xml` 变更
- 两份 profile 配置文件（`application-integration-mysql-baseline.yml` 保留、`application-integration-highgo.yml` 新增）
- `src/main/resources/db/migration/highgo/` 目录（可选含 `V0_0_1__mysql_compat_functions.sql`）
- §2.6 冒烟 SQL 执行记录（粘贴到 `project-docs/reports/` 或测试基线目录）

## 下一阶段

→ [Stage 3 — Schema 迁移](stage-3-schema-migration.md)
