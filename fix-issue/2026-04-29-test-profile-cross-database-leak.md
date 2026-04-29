---
updated: 2026-04-29
source: stream-keywords-search/b8a1917
related-risk: 无
severity: 🟡
category: 其他
---

# 多数据库测试 profile 需要隔离，避免跨库测试串入

## 现象

MySQL → 瀚高改造的后续 SOP 会反复执行不同数据库 profile 的测试：Stage 4 方言改造后会跑 `integration-highgo` 并复跑 `integration-mysql-baseline`，Stage 5 验收会先跑 MySQL 基线回归，再跑瀚高全量回归。

如果 Maven Surefire 的 include / exclude 边界不清，测试入口就可能跨库误匹配：执行 MySQL baseline 时扫到 HighGo 真库测试，或执行 HighGo 回归时扫到 MySQL-only 测试。本案例实际发生的是前者。

Stage 5 收口复跑 `integration-mysql-baseline` 时，后续阶段新增的 `HighGo*DAOIntegrationTest` 被 MySQL baseline 测试入口误匹配执行，导致 MySQL baseline 回归结果出现非预期 skipped：

```text
mvn -o -Pintegration-mysql-baseline clean test
49 tests, 0 failures, 0 errors, 4 skipped
```

排查发现，4 个 skipped 均为 `HighGo*DAOIntegrationTest`。这些测试属于 HighGo 真库验证资产，不属于 MySQL baseline。修正 profile 边界后复跑：

```text
mvn -o -Pintegration-mysql-baseline test
45 tests, 0 failures, 0 errors, 0 skipped
```

## 根因

Maven Surefire 的 include 规则过宽。MySQL baseline profile 使用了 `**/*DAOIntegrationTest.java` 等通用匹配规则；当项目进入后续阶段并新增 HighGo 测试类后，`HighGoMicroblogUserDAOIntegrationTest`、`HighGoNewsUserDAOIntegrationTest` 等也被同一规则匹配。

在多数据库迁移工程中，MySQL baseline、HighGo 回归、DDL smoke、兼容函数 smoke 往往共用 `src/test/java`。如果只按 `*IntegrationTest` / `*DAOIntegrationTest` 这类后缀收集测试，而不排除其他数据库前缀，就容易出现跨库测试串入。

## 修复动作 / 规避准则

为每个测试 profile 明确测试边界：

```xml
<profile>
  <id>integration-mysql-baseline</id>
  ...
  <includes>
    <include>**/*DAOTest.java</include>
    <include>**/*MapperTest.java</include>
    <include>**/*MapperIntegrationTest.java</include>
    <include>**/*DAOIntegrationTest.java</include>
  </includes>
  <excludes>
    <exclude>**/HighGo*.java</exclude>
  </excludes>
</profile>
```

同时让目标库 profile 只显式 include 自己的测试资产：

```xml
<profile>
  <id>integration-highgo</id>
  ...
  <includes>
    <include>**/HighGoMigrationAssetTest.java</include>
    <include>**/HighGoDdlGuardSyntaxSmokeTest.java</include>
    <include>**/HighGoGeneratedKeysSmokeTest.java</include>
    <include>**/HighGoJdbcSmokeTest.java</include>
    <include>**/HighGoCompatibilitySmokeTest.java</include>
    <include>**/HighGo*DAOIntegrationTest.java</include>
    <include>**/HighGoStringSemanticsIntegrationTest.java</include>
  </includes>
</profile>
```

规避准则：

1. 测试类命名携带数据库或阶段前缀，如 `HighGo*`、`MySql*`。
2. 源库 baseline profile 必须 exclude 目标库测试类。
3. 目标库 profile 尽量显式 include 目标库测试类，不依赖宽泛后缀。
4. Stage 报告必须记录 tests / failures / errors / skipped 四个数字。
5. 非预期 skipped 不应视为通过；必须确认 skipped 是否属于当前 profile 预期边界。

## 影响范围

适用于所有同时保留源库 baseline 与目标库回归测试的迁移工程，尤其是以下场景：

- MySQL baseline 与 HighGo 测试类共用同一个 `src/test/java`。
- Maven profile 使用 `*IntegrationTest`、`*DAOIntegrationTest` 等宽泛 include。
- 目标库测试依赖运行时凭据，缺失凭据时会 skipped。
- 后续阶段需要复跑源库 baseline 或复用源库 profile 做定向验证。

该问题会污染阶段结论：`BUILD SUCCESS` 可能掩盖 profile 边界错误，导致 Stage 1 baseline 或 Stage 5 回归的测试范围不可解释。

工具包 SOP 引用：

- Stage 1 SOP：`docs/sop/stage-1-test-baseline.md` 要求 Stage 1 形成 MySQL baseline，并明确这是回归对照基准，Stage 5 将使用同一测试集在瀚高下重跑。
- Stage 2 SOP：`docs/sop/stage-2-config-switch.md` 要求保留 `mysql-connector-java` 和 `application-integration-mysql-baseline.yml`，因为 Stage 5 之前需要继续跑 `integration-mysql-baseline` profile 做双轨验证。该阶段是 profile 共存的开始，不是本问题的主要触发点。
- Stage 4 SOP：`docs/sop/stage-4-dialect-adapt.md` 要求保留 Stage 1 的 `integration-mysql-baseline` profile，并在 Stage 4 每次改动后先跑 `integration-highgo`，再跑 `integration-mysql-baseline`，确认未破坏 MySQL 行为。
- Stage 5 SOP / 验收：`skills/db-migration-verify/SKILL.md` 要求先跑 MySQL 基线回归 `mvn -P integration-mysql-baseline clean test`，再跑瀚高全量回归；`docs/checklists/acceptance-checklist.md` 也要求 `mvn -P integration-mysql-baseline test` 全绿并核对测试数量差异。

## 来源

- 工程：stream-keywords-search
- 日期：2026-04-29
- 记录人：李卓尔

## 参考

- 相关 SOP：`docs/sop/stage-1-test-baseline.md`
- 相关 SOP：`docs/sop/stage-2-config-switch.md`
- 相关 SOP：`docs/sop/stage-4-dialect-adapt.md`
- 相关 SOP：`docs/sop/stage-5-verify-deliver.md`
- 相关 Skill：`skills/db-migration-verify/SKILL.md`
- 相关 checklist：`docs/checklists/acceptance-checklist.md`
- 相关配置：`pom.xml` 中 `integration-mysql-baseline` 与 `integration-highgo` profile 的 Surefire include / exclude
