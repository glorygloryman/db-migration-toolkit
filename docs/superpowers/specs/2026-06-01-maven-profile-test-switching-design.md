---
name: maven-profile-test-switching
date: 2026-06-01
status: approved
---

# 集成测试 Maven Profile 切换机制

## 背景

工具包原有方案要求每个集成测试类写 `@ActiveProfiles("integration-mysql-baseline")`。Stage 1 写测试时连 MySQL，Stage 5 验收时需改为 `integration-highgo` 连瀚高，涉及逐个修改测试类注解。

Pilot 阶段踩坑（fix-issue 2026-05-25）已验证了通过 Maven Profile + surefire `systemPropertyVariables` 注入 `spring.profiles.active` 的方案可行。现将其标准化为新项目的默认做法。

## 核心变更

**旧模式**：每个集成测试类写 `@ActiveProfiles("integration-mysql-baseline")`，Stage 5 改注解切瀚高。

**新模式**：Maven Profile 通过 `maven-surefire-plugin` 的 `systemPropertyVariables` 注入 `spring.profiles.active`，Spring Boot Test 自动拾取。测试代码不写 `@ActiveProfiles`，完全不感知数据库。

**效果**：同一套测试代码，`mvn -P integration-mysql-baseline test` 跑 MySQL，`mvn -P integration-highgo test` 跑瀚高，零代码修改。

## pom.xml 标准模板（Stage 0/Stage 2 配置）

```xml
<profiles>
    <profile>
        <id>integration-mysql-baseline</id>
        <build>
            <plugins>
                <plugin>
                    <groupId>org.apache.maven.plugins</groupId>
                    <artifactId>maven-surefire-plugin</artifactId>
                    <configuration>
                        <systemPropertyVariables>
                            <spring.profiles.active>integration-mysql-baseline</spring.profiles.active>
                        </systemPropertyVariables>
                    </configuration>
                </plugin>
            </plugins>
        </build>
    </profile>
    <profile>
        <id>integration-highgo</id>
        <build>
            <plugins>
                <plugin>
                    <groupId>org.apache.maven.plugins</groupId>
                    <artifactId>maven-surefire-plugin</artifactId>
                    <configuration>
                        <systemPropertyVariables>
                            <spring.profiles.active>integration-highgo</spring.profiles.active>
                        </systemPropertyVariables>
                    </configuration>
                </plugin>
            </plugins>
        </build>
    </profile>
</profiles>
```

## 集成测试类写法（Stage 1）

```java
@SpringBootTest        // 不写 @ActiveProfiles
// ... 其他注解
class XxxMapperIntegrationTest {
    // ...
}
```

## 受影响的文件清单（8 处）

| 文件 | 变更内容 |
|------|---------|
| `docs/sop/stage-1-test-baseline.md` | §1.3 删 `@ActiveProfiles`，加"通过 Maven Profile 注入 spring.profiles.active"说明 |
| `docs/sop/stage-2-config-switch.md` | §2.2 增加 pom.xml profile 配置的标准模板和说明 |
| `skills/db-migration-test-plan/SKILL.md` | 验收标准删 `@ActiveProfiles`，改为"Maven Profile 已配置 systemPropertyVariables" |
| `skills/db-migration-test-execute/SKILL.md` | 集成测试步骤删 `@ActiveProfiles`，改为不写 profile 注解 |
| `skills/work-cycle-auto/SKILL.md` | 6 处 `@ActiveProfiles` 引用全部替换 |
| `docs/templates/test-gap-plan-template.md` | 2 处验收标准模板更新 |
| `CLAUDE.md` | 更新不可动摇的前提假设或 Skill 写作约定中相关描述 |
| `docs/sop/stage-5-verify-deliver.md` | 确认 Stage 5 的 `mvn -P integration-highgo test` 无需改测试代码的描述准确，补充说明 |

## 不变的部分

- `application-integration-mysql-baseline.yml` 和 `application-integration-highgo.yml` 仍然存在，Spring Boot 按 `spring.profiles.active` 加载对应配置
- `mvn -P integration-mysql-baseline test` / `mvn -P integration-highgo test` 命令不变
- 测试隔离规则（fix-issue 2026-04-29 的 Surefire include/exclude）不变
- 禁止 `@MockBean`、Testcontainers、自建数据库对象等约束不变

## 已验证来源

- fix-issue 2026-05-25：`systemPropertyVariables` + `spring.profiles.active` 在 bigv_data_receive 项目中已验证可行
- fix-issue 2026-04-29：Surefire include/exclude 隔离规则已验证
