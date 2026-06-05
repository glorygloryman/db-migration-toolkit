---
updated: 2026-06-03
source: interaction-middleware/DruidDBConfig.java
related-risk: R-011
severity: 🟡
category: 连接池
---

# Druid 1.1.6 WallFilter 不认识瀚高 JDBC URL，无法推断 dbType 导致初始化失败

## 现象

Druid 配置了 `filters=stat,wall` 时，连接瀚高数据库启动报错：

```
java.lang.IllegalStateException: dbType not support : null, url jdbc:highgo://192.168.211.181:5866/interaction?currentSchema=interaction
    at com.alibaba.druid.wall.WallFilter.init(WallFilter.java:159)
```

## 根因

Druid 的 `WallFilter`（SQL 防火墙）初始化时需要知道数据库类型（`dbType`），用于选择对应的 SQL 解析器。WallFilter 通过 `JdbcUtils.getDbType(url, null)` 从 URL 推断 dbType。

Druid 1.1.6 的 `JdbcUtils` 只认识 `jdbc:mysql://` → `mysql`、`jdbc:postgresql://` → `postgresql` 等主流协议。**`jdbc:highgo://` 不在识别列表中**，返回 null，WallFilter 抛出 `IllegalStateException: dbType not support : null`。

StatFilter 不依赖 dbType，所以不受影响。

## 修复动作 / 规避准则

**方案一（推荐）**：去掉 WallFilter，只保留 StatFilter

```properties
# 修复前
spring.datasource.filters=stat,wall

# 修复后
spring.datasource.filters=stat
```

同时在 `connectionProperties` 中显式指定 dbType：

```properties
spring.datasource.connectionProperties=druid.stat.mergeSql=true;druid.stat.slowSqlMillis=5000;druid.dbType=postgresql
```

**方案二**：通过编程方式设置 WallFilter 的 dbType

```java
WallFilter wallFilter = new WallFilter();
wallFilter.setDbType("postgresql");
wallFilter.setConfig(new WallConfig("postgresql"));
datasource.setProxyFilters(Arrays.asList(statFilter, wallFilter));
```

规避准则：
1. **使用瀚高/国产数据库时，Druid 的 `filters` 不能包含 `wall`**（除非通过编程方式显式设置 dbType）
2. `spring.datasource.dbType=postgresql` 不是 Druid 1.1.6 的有效 Spring Boot 绑定属性，需通过 `connectionProperties` 的 `druid.dbType` 参数传递
3. 扫描方法：`rg 'filters.*wall' --glob '*.properties' --glob '*.yml'`

## 影响范围

所有使用 Druid 连接池 + `wall` filter + 瀚高/国产数据库的项目。

## 来源

- 工程：interaction-middleware
- 文件：interaction-core/src/main/resources/application.properties（及测试配置）
- 阶段：Stage 4 方言适配
- 日期：2026-06-03
- 记录人：wushaohui

## 参考

- Druid 源码：`com.alibaba.druid.wall.WallFilter.init()`、`com.alibaba.druid.util.JdbcUtils.getDbType()`
- 相关 fix-issue：[Druid 无法识别瀚高 JDBC URL，需显式设置 driverClassName](2026-06-03-druid-highgo-driver-unknown.md)
