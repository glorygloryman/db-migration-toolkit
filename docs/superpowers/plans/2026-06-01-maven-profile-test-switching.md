# Maven Profile Test Switching Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将工具包中所有 `@ActiveProfiles("integration-mysql-baseline")` 引用替换为"Maven Profile 注入 `spring.profiles.active`"模式，让新项目从 Stage 1 起无需在测试代码中硬编码 profile。

**Architecture:** pom.xml 的 Maven Profile 通过 `maven-surefire-plugin` 的 `systemPropertyVariables` 注入 `spring.profiles.active`，Spring Boot Test 自动拾取。测试代码不写 `@ActiveProfiles`，完全不感知数据库。

**Tech Stack:** Markdown 文档 + Claude Code Skill 定义

---

## File Structure

| 文件 | 操作 | 职责 |
|------|------|------|
| `docs/sop/stage-1-test-baseline.md` | Modify | Stage 1 集成测试配置指引 |
| `docs/sop/stage-2-config-switch.md` | Modify | Stage 2 pom.xml profile 配置模板 |
| `docs/sop/stage-5-verify-deliver.md` | Modify | Stage 5 验收说明补充 |
| `skills/db-migration-test-plan/SKILL.md` | Modify | 测试计划验收标准 |
| `skills/db-migration-test-execute/SKILL.md` | Modify | 测试执行步骤 |
| `skills/work-cycle-auto/SKILL.md` | Modify | 自动化工作流（6 处引用） |
| `docs/templates/test-gap-plan-template.md` | Modify | 测试计划模板验收标准 |
| `CLAUDE.md` | Modify | 工具包自身约定 |

---

### Task 1: docs/sop/stage-1-test-baseline.md

**Files:**
- Modify: `docs/sop/stage-1-test-baseline.md`

- [ ] **Step 1: 修改 §1.3 集成测试配置说明**

将第 50 行：
```
- `@ActiveProfiles("integration-mysql-baseline")`
```

替换为：
```
- 不写 `@ActiveProfiles`，数据库 profile 由 Maven Profile 通过 `maven-surefile-plugin` 的 `systemPropertyVariables` 注入 `spring.profiles.active`，Spring Boot Test 自动拾取
- 确认 `pom.xml` 中 `integration-mysql-baseline` profile 已配置 `systemPropertyVariables`（配置模板见 Stage 2 SOP §2.2）
```

- [ ] **Step 2: 修改 §1.4 运行命令**

当前第 57 行的命令 `mvn -P integration-mysql-baseline test` 保持不变，在其下方增加说明：
```
> Maven Profile 通过 surefire `systemPropertyVariables` 自动将 `spring.profiles.active=integration-mysql-baseline` 注入 JVM，集成测试类无需写 `@ActiveProfiles`。
```

- [ ] **Step 3: Commit**

```bash
git add docs/sop/stage-1-test-baseline.md
git commit -m "docs: Stage 1 SOP 集成测试改为 Maven Profile 注入 spring.profiles.active"
```

---

### Task 2: docs/sop/stage-2-config-switch.md

**Files:**
- Modify: `docs/sop/stage-2-config-switch.md`

- [ ] **Step 1: 在 §2.2 多 profile 配置 末尾新增 pom.xml profile 配置段落**

在第 70 行（`application-integration-highgo.yml` 示例结束后）追加：

```
#### pom.xml Maven Profile 配置（surefire systemPropertyVariables）

为让集成测试通过 `mvn -P <profile> test` 自动切换数据库，在 `pom.xml` 中为两个 profile 配置 `maven-surefire-plugin` 的 `systemPropertyVariables`：

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

配置后，集成测试类**不写 `@ActiveProfiles`**，Spring Boot Test 自动从 `spring.profiles.active` 系统属性读取 profile 并加载对应的 `application-integration-*.yml`。

效果：同一套测试代码，`mvn -P integration-mysql-baseline test` 跑 MySQL，`mvn -P integration-highgo test` 跑瀚高，零代码修改。
```

- [ ] **Step 2: Commit**

```bash
git add docs/sop/stage-2-config-switch.md
git commit -m "docs: Stage 2 SOP 增加 pom.xml profile systemPropertyVariables 配置模板"
```

---

### Task 3: docs/sop/stage-5-verify-deliver.md

**Files:**
- Modify: `docs/sop/stage-5-verify-deliver.md`

- [ ] **Step 1: 在 §5.1 全量回归 增加说明**

在第 22 行 `mvn -P integration-highgo clean test` 之后追加：

```
> 由于集成测试不写 `@ActiveProfiles`，数据库 profile 由 Maven Profile 的 `systemPropertyVariables` 注入，此处无需修改任何测试代码即可从 MySQL 切换到瀚高。
```

- [ ] **Step 2: Commit**

```bash
git add docs/sop/stage-5-verify-deliver.md
git commit -m "docs: Stage 5 SOP 补充 Maven Profile 切换说明"
```

---

### Task 4: skills/db-migration-test-plan/SKILL.md

**Files:**
- Modify: `skills/db-migration-test-plan/SKILL.md`

- [ ] **Step 1: 修改 §4 产出执行计划中的验收标准（第 79 行）**

将：
```
    - 集成测试使用 `@ActiveProfiles("integration-mysql-baseline")`，连接真实 MySQL，禁止 `@MockBean` 替代数据库，禁止 Testcontainers
```

替换为：
```
    - 集成测试不写 `@ActiveProfiles`，数据库 profile 由 Maven Profile 的 `systemPropertyVariables` 注入（确认 `pom.xml` 已配置），连接真实 MySQL，禁止 `@MockBean` 替代数据库，禁止 Testcontainers
```

- [ ] **Step 2: Commit**

```bash
git add skills/db-migration-test-plan/SKILL.md
git commit -m "docs: db-migration-test-plan Skill 验收标准改为 Maven Profile 注入"
```

---

### Task 5: skills/db-migration-test-execute/SKILL.md

**Files:**
- Modify: `skills/db-migration-test-execute/SKILL.md`

- [ ] **Step 1: 修改 §4 编写测试代码 > 集成测试（第 68 行）**

将：
```
- 使用 `@ActiveProfiles("integration-mysql-baseline")`
```

替换为：
```
- 不写 `@ActiveProfiles`，数据库 profile 由 Maven Profile 通过 `systemPropertyVariables` 注入 `spring.profiles.active`
```

- [ ] **Step 2: 修改 §人工复核要点（第 136 行）**

将：
```
- 集成测试是否使用了 `@ActiveProfiles("integration-mysql-baseline")`
```

替换为：
```
- 集成测试是否未写 `@ActiveProfiles`（应通过 Maven Profile 的 `systemPropertyVariables` 注入 profile）
```

- [ ] **Step 3: Commit**

```bash
git add skills/db-migration-test-execute/SKILL.md
git commit -m "docs: db-migration-test-execute Skill 改为 Maven Profile 注入模式"
```

---

### Task 6: skills/work-cycle-auto/SKILL.md

**Files:**
- Modify: `skills/work-cycle-auto/SKILL.md`

- [ ] **Step 1: 定位并替换全部 6 处 `@ActiveProfiles` 引用**

需替换的 6 处及对应新文本：

**第 271 行：**
```
旧：- `@ActiveProfiles("integration-mysql-baseline")`
新：- 不写 `@ActiveProfiles`，数据库 profile 由 Maven Profile 的 `systemPropertyVariables` 注入
```

**第 282 行：**
```
旧：5. 集成测试使用 `@ActiveProfiles("integration-mysql-baseline")`，连接真实 MySQL，禁止 `@MockBean` 替代数据库，禁止 Testcontainers
新：5. 集成测试不写 `@ActiveProfiles`，数据库 profile 由 Maven Profile 的 `systemPropertyVariables` 注入，连接真实 MySQL，禁止 `@MockBean` 替代数据库，禁止 Testcontainers
```

**第 308 行：**
```
旧：5. 集成测试使用 @ActiveProfiles("integration-mysql-baseline")，连接真实 MySQL，禁止 @MockBean 替代数据库，禁止 Testcontainers
新：5. 集成测试不写 @ActiveProfiles，数据库 profile 由 Maven Profile 的 systemPropertyVariables 注入，连接真实 MySQL，禁止 @MockBean 替代数据库，禁止 Testcontainers
```

**第 319 行：**
```
旧：- 集成测试 @ActiveProfiles("integration-mysql-baseline")
新：- 集成测试不写 @ActiveProfiles，数据库 profile 由 Maven Profile 注入
```

**第 374 行：**
```
旧：5. **真实 MySQL 连接**：集成测试有 `@ActiveProfiles("integration-mysql-baseline")`，无 `@MockBean`/`Testcontainers`
新：5. **真实 MySQL 连接**：集成测试不写 `@ActiveProfiles`，通过 Maven Profile `systemPropertyVariables` 注入 profile，无 `@MockBean`/`Testcontainers`
```

**第 379 行**（此行为验收检查项，确认是第 379 行附近）：
先 Read 该文件确认行号，再做替换。

- [ ] **Step 2: 逐个替换并验证无遗漏**

替换后执行 `grep -n "@ActiveProfiles" skills/work-cycle-auto/SKILL.md`，确认输出为空。

- [ ] **Step 3: Commit**

```bash
git add skills/work-cycle-auto/SKILL.md
git commit -m "docs: work-cycle-auto Skill 6 处 @ActiveProfiles 改为 Maven Profile 注入"
```

---

### Task 7: docs/templates/test-gap-plan-template.md

**Files:**
- Modify: `docs/templates/test-gap-plan-template.md`

- [ ] **Step 1: 修改第 84 行验收标准**

将：
```
- [ ] 使用 `@ActiveProfiles("integration-mysql-baseline")`
```

替换为：
```
- [ ] `pom.xml` 已配置 Maven Profile `systemPropertyVariables` 注入 `spring.profiles.active`，集成测试不写 `@ActiveProfiles`
```

- [ ] **Step 2: 修改第 112 行验收标准**

将：
```
- [ ] 集成测试使用 `@ActiveProfiles("integration-mysql-baseline")`，连接真实 MySQL，禁止 `@MockBean` 和 Testcontainers
```

替换为：
```
- [ ] 集成测试不写 `@ActiveProfiles`，通过 Maven Profile `systemPropertyVariables` 注入 profile，连接真实 MySQL，禁止 `@MockBean` 和 Testcontainers
```

- [ ] **Step 3: Commit**

```bash
git add docs/templates/test-gap-plan-template.md
git commit -m "docs: test-gap-plan 模板验收标准改为 Maven Profile 注入"
```

---

### Task 8: CLAUDE.md

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: 在不可动摇的前提假设中补充第 8 条**

在第 7 条（Flyway 严禁改历史脚本）之后追加：

```
8. **集成测试不写 `@ActiveProfiles`**：数据库 profile 由 Maven Profile 通过 `maven-surefire-plugin` 的 `systemPropertyVariables` 注入 `spring.profiles.active`，测试代码完全不感知数据库——`mvn -P integration-mysql-baseline test` 跑 MySQL，`mvn -P integration-highgo test` 跑瀚高，零代码修改
```

- [ ] **Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: CLAUDE.md 补充集成测试 profile 切换前提假设"
```

---

### Task 9: 全局验证

- [ ] **Step 1: 全局搜索确认无遗漏**

```bash
cd db-migration-toolkit
grep -rn "@ActiveProfiles" --include="*.md" .
```

预期：输出为空（所有 `@ActiveProfiles` 引用均已替换）。

- [ ] **Step 2: 验证 `systemPropertyVariables` 覆盖完整**

```bash
grep -rn "systemPropertyVariables" --include="*.md" .
```

预期：stage-2-config-switch.md、stage-1-test-baseline.md、CLAUDE.md 中有引用。

- [ ] **Step 3: 最终 commit**

如有微调，追加 commit；无则跳过。
