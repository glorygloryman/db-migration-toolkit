---
updated: 2026-06-03
source: interaction-middleware/DruidDBConfig.java
related-risk: R-011
severity: 🟡
category: 连接池
---

# Druid 1.1.6 无法识别瀚高 JDBC URL，需显式设置 driverClassName

## 现象

使用 Druid 1.1.6 连接瀚高数据库时，即使 `spring.datasource.driver-class-name` 配置正确，DruidDataSource 初始化仍报错：

```
java.sql.SQLException: unkow jdbc driver : jdbc:highgo://192.168.211.181:5866/interaction?currentSchema=interaction
```

后续获取连接时报 NullPointerException。

## 根因

Druid 的 `DruidDataSource` 初始化流程中，如果没有显式设置 `driverClassName`，会调用 `JdbcUtils.getDriverClassName(url)` 从 URL 协议自动推断驱动类名。Druid 1.1.6 的 `JdbcUtils` 只认识 `jdbc:mysql://`、`jdbc:oracle://`、`jdbc:postgresql://` 等主流协议，**不认识 `jdbc:highgo://`**，返回 null 导致 NPE。

**关键点**：`spring.datasource.driver-class-name` 是 Spring Boot 的属性，DruidDBConfig 中如果只设置了 `url/username/password` 而没有调用 `setDriverClassName()`，Druid 不会自动使用 Spring 的 driver-class-name 配置。

## 修复动作 / 规避准则

1. 在 `DruidDBConfig.getDruidDataSource()` 中添加 `datasource.setDriverClassName(driverClassName)`，通过 `@Value` 注入 `spring.datasource.driver-class-name`

```java
@Value("${spring.datasource.driver-class-name}")
private String driverClassName;

// 在 getDruidDataSource() 方法中：
datasource.setDriverClassName(driverClassName);
```

2. 扫描方法：搜索所有自定义 `DruidDataSource` Bean 配置（`DataSourceConfig`、`DruidDBConfig` 等），确认是否调用了 `setDriverClassName()`

规避准则：
- **任何非主流 JDBC URL 协议（瀚高、达梦、人大金仓等国产数据库），必须在 DruidDataSource 中显式设置 driverClassName**
- 不能依赖 Druid 的 URL 自动推断

## 影响范围

所有使用 Druid 连接池 + 瀚高/国产数据库的 Spring Boot 项目。影响条件：
1. 使用 Druid 连接池（`DruidDataSource`）
2. 通过自定义 Bean 配置 DataSource（非 Spring Boot 自动配置）
3. JDBC URL 使用非主流协议（`jdbc:highgo://`、`jdbc:dm://` 等）

## 来源

- 工程：interaction-middleware
- 文件：interaction-core/src/main/java/com/trs/interaction/core/datasource/DruidDBConfig.java
- 阶段：Stage 4 方言适配
- 日期：2026-06-03
- 记录人：wushaohui

## 参考

- Druid 源码：`com.alibaba.druid.util.JdbcUtils.getDriverClassName(String url)`
- 相关 fix-issue：[Druid WallFilter 不认识瀚高 URL 导致 dbType 推断失败](2026-06-03-druid-wallfilter-highgo-dbtype.md)
