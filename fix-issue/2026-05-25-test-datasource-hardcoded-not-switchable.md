---
updated: 2026-05-25
source: bigv_data_receive/48fba40
related-risk: R-008
severity: 🟡
category: 其他
---

# 集成测试 DataSource 硬编码导致 Maven profile 切换无效

## 现象

Stage 5 验收执行 `mvn -P integration-mysql-baseline clean test` 和 `mvn -P integration-highgo clean test`，发现两个模块的集成测试无论使用哪个 profile，实际连接的数据库始终不变：

- `file-consumer/FileConsumerTestConfig.java` 硬编码了 MySQL JDBC URL → `integration-highgo` profile 实际仍连 MySQL
- `data_receive/TestDataSourceConfig.java` 硬编码了瀚高 JDBC URL → `integration-mysql-baseline` profile 实际仍连瀚高

后果：
- 无法验证 file-consumer 在瀚高上的真实兼容性
- 无法获取 data_receive 的 MySQL 基线
- 验收报告中"用例数对比"实际是同一数据库的两轮运行，对比无意义

## 根因

集成测试配置类使用 `@SpringBootConfiguration`（非 `@SpringBootTest`），直接在 Java 代码中 new DataSource 并硬编码连接参数。Maven profile 定义了 `spring.datasource.*` 属性，但这些属性仅通过资源过滤写入 yml/properties 文件，不会被 `@SpringBootConfiguration` 的测试上下文读取。

两个模块都绕过了 Spring Boot 的属性绑定机制，导致 profile 属性对测试配置不生效。

## 修复动作 / 规避准则

### 修复方案：System.getProperty() + surefire systemPropertyVariables

1. 测试配置类用 `System.getProperty("test.datasource.url", "默认值")` 读取连接参数
2. Maven profile 中定义 `test.datasource.*` 属性
3. profile 中配置 surefire `systemPropertyVariables` 将属性透传到 JVM

```java
// 测试配置类
private static final String JDBC_URL =
    System.getProperty("test.datasource.url",
        "jdbc:highgo://192.168.211.181:5866/big_data_receive?currentSchema=big_data_receive");
```

```xml
<!-- pom.xml profile -->
<profile>
    <id>integration-highgo</id>
    <properties>
        <test.datasource.url>jdbc:highgo://192.168.211.181:5866/...</test.datasource.url>
        <test.datasource.username>sysdba</test.datasource.username>
        <test.datasource.password>Hello@12345</test.datasource.password>
        <test.datasource.driver>com.highgo.jdbc.Driver</test.datasource.driver>
    </properties>
    <build>
        <plugins>
            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-surefire-plugin</artifactId>
                <configuration>
                    <systemPropertyVariables>
                        <test.datasource.url>${test.datasource.url}</test.datasource.url>
                        <test.datasource.username>${test.datasource.username}</test.datasource.username>
                        <test.datasource.password>${test.datasource.password}</test.datasource.password>
                        <test.datasource.driver>${test.datasource.driver}</test.datasource.driver>
                    </systemPropertyVariables>
                </configuration>
            </plugin>
        </plugins>
    </build>
</profile>
```

### 规避准则

1. 集成测试 DataSource 配置**禁止硬编码**连接参数，必须通过属性注入
2. 使用 `@SpringBootConfiguration` 的测试配置类，不自动读取 Maven 资源过滤的属性，需要通过 `System.getProperty()` + surefire `systemPropertyVariables` 桥接
3. Stage 5 验收时必须**验证连接类型**（检查日志中的 Connection 实现类），不能仅看 BUILD SUCCESS
4. 每个 profile 跑完后检查日志中 `Closing connection com.xxx.jdbc.ConnectionImpl` 或 `com.highgo.jdbc.jdbc.PgConnection`，确认实际连接的数据库

## 影响范围

适用于所有使用 `@SpringBootConfiguration` 手动配置 DataSource 的集成测试场景，特别是：
- 绕过 `@SpringBootTest` 的轻量级测试配置
- 需要多数据库 profile 切换的迁移工程
- Stage 1/Stage 5 需要双轨验证的工程

## 来源

- 工程：bigv_data_receive (trs_data_receive)
- 日期：2026-05-25
- 记录人：wushaohui
