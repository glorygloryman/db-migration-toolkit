# 验收清单（Stage 5 出口）

> 用途：Stage 5 完成后，逐项核对，任一未通过不得关闭改造任务。

## 功能

- [ ] 应用在 GaussDB profile 下启动成功，无致命错
- [ ] 应用在 MySQL profile 下仍可启动（回滚能力保留）
- [ ] 关键业务接口手工回归通过
- [ ] 无日志堆栈 `ERROR`（非预期的）

## 测试

- [ ] `mvn -P integration-gaussdb test` 全绿
- [ ] `mvn -P integration-mysql-baseline test` 全绿（或已声明的差异项除外）
- [ ] 单元测试与集成测试数量与 Stage 1 基线一致（或差异有说明）
- [ ] 测试运行耗时无爆炸性增长（如超 2×，记录说明）

## Schema

- [ ] `flyway_schema_history` 表显示所有脚本成功
- [ ] Schema 对比报告无遗漏
- [ ] 索引、约束、默认值齐全

## 配置

- [ ] 连接池参数合理
- [ ] 字符集、排序规则、时区配置正确
- [ ] Druid 监控可正常打开（若启用）

## 风险矩阵

- [ ] 所有条目状态为 ✅ 或 `decision-deferred`（有 `decisions/` 记录）
- [ ] 无 `pending` / `blocked` 状态条目

## 文档

- [ ] `project-docs/reports/YYYY-MM-DD-gaussdb-migration-report.md` 已产出
- [ ] `project-docs/decisions/` 决策记录齐全
- [ ] 已向 `db-migration-toolkit/fix-issue/` 推送通用踩坑（或明确声明"无通用性新坑"）
- [ ] 已向 `db-migration-toolkit` 提交 SOP 反馈（Pilot 工程必填，后续工程酌情）

## 交付

- [ ] PR 已创建，PR checklist 全部勾选
- [ ] 分支 tag `stage-5-gaussdb-migration-done-vX.Y.Z` 已打
- [ ] 通知相关方
- [ ] 回滚方案已文档化

## 遗留

- [ ] 所有遗留问题已记录到 `project-docs/plans/` 或 `decisions/`
- [ ] 不在本方案范围内的发现（性能、架构、灰度）已单独上升沟通
