# Stage 5 — 回归与交付

## 目标

确认改造完成质量，产出验收报告，把本工程的踩坑沉淀回工具包。

## 预计工期

0.5~1 天

## 输入

- Stage 4 结束时的代码基线
- Stage 1 的测试集
- 风险矩阵（已全部关闭）

## 步骤

### 5.1 全量回归（瀚高 v4.1.5）

```bash
mvn -P integration-highgo clean test
```

要求：
- 所有单元测试绿
- 所有集成测试绿
- 与 Stage 1 MySQL 基线比对，用例数一致（除非有明确声明的"瀚高特有用例"或"MySQL 特有用例已下线"）

### 5.2 启动冒烟 + 接口回归

- 应用启动成功
- 对外接口按现有 E2E 套跑一遍（若有）
- 关键业务场景手工回归 2~3 个

### 5.3 配置产物复查

- [ ] `application-integration-highgo.yml` 字段齐全
- [ ] Druid / HikariCP 参数合理
- [ ] Flyway `locations` 指向 `highgo` 目录
- [ ] 日志无 `WARN` / `ERROR` 堆栈
- [ ] 连接池空闲 / 活跃数监控指标正常

### 5.4 产出验收报告

调用 Skill `db-migration-verify` 生成骨架，人工补全。

文件：`project-docs/reports/YYYY-MM-DD-highgo-migration-report.md`

参照模板：[`templates/migration-report-template.md`](../templates/migration-report-template.md)

内容包含：
- 工程基本信息
- 各阶段耗时
- 改造范围汇总（文件数、行数、commit 数）
- 风险矩阵关闭情况
- 测试对比：MySQL 基线 vs 瀚高 v4.1.5
- 未解决问题与上游依赖
- 回滚方案（保留 MySQL 配置的情况下如何切回）
- 附录：决策记录索引、踩坑记录索引

### 5.5 踩坑回灌工具包

把本工程发现的**通用性问题**提炼为 `fix-issue` 记录，推送回 `db-migration-toolkit`：

文件命名：`fix-issue/YYYY-MM-DD-<short-slug>.md`

格式（参照 CLAUDE.md §5，fix-issue 四要素）：
```markdown
---
updated: YYYY-MM-DD
source: <project-name>/<path or commit>
---

# 现象
...

# 根因
...

# 修复动作 / 规避准则
...

# 来源
commit: xxx
related-risk: R-xx
```

仅满足 "现象 + 根因 + 修复 / 规避 + 来源" 四要素的问题才放 `fix-issue`；
否则按 CLAUDE.md §5 分流到 `fact` / `playbook` / `decision` / `faq`。

### 5.6 框架反馈

对本次 SOP 使用体验写一份反馈，提到 `db-migration-toolkit` 的 issue 区：
- 哪些步骤耗时超预期？
- 哪些 checklist 项形同虚设？
- 哪些 references 缺了关键条目？
- Skill 哪些地方不好用？

用于 Pilot 结束后集中修订。

### 5.7 交付物打包

- 改造分支 PR（引用本 SOP 与母方案）
- 验收报告
- 决策记录
- 踩坑记录
- PR 描述中贴 [`checklists/migration-pr-checklist.md`](../checklists/migration-pr-checklist.md) 的勾选结果

## 出口检查

使用 [`checklists/acceptance-checklist.md`](../checklists/acceptance-checklist.md)。

## 产出物

- `project-docs/reports/YYYY-MM-DD-highgo-migration-report.md`
- 提交到工具包的 `fix-issue/` 条目（1 个或多个）
- 工具包 issue 反馈
- PR

## 回滚策略

本方案不考虑灰度，但应保留**快速切回 MySQL** 的能力：
- 保留 `application-integration-mysql-baseline.yml`
- 保留 `db/migration/mysql/` 原脚本
- 保留 MySQL 驱动依赖
- 生产部署时通过 profile 切换

回滚即 `--spring.profiles.active=mysql-baseline`（按实际 profile 命名），不需要代码回滚。

## 完成标记

- Git tag `stage-5-highgo-migration-done-vX.Y.Z`
- CHANGELOG（本工程）追加条目
- 通知相关方

---

改造完成 ✅
