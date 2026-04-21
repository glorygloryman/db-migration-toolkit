# 改造 PR 清单

> 用途：贴入每个数据库改造 PR 的描述模板，逐项勾选。

## 范围声明

- [ ] 本 PR 仅涉及数据库改造（MySQL → 瀚高 v4.1.5），不夹带业务变更
- [ ] 改造对应 SOP 阶段：Stage __（0 / 1 / 2 / 3 / 4 / 5）
- [ ] 引用母方案：`db-migration-toolkit/docs/2026-04-18-master-plan.md`

## 代码

- [ ] 未修改 `db/migration/mysql/` 下任何历史脚本
- [ ] 新增 Flyway 脚本位于 `db/migration/highgo/`，带 `IF NOT EXISTS` / `IF EXISTS` 防护，R-018 已冒烟通过
- [ ] 无 `DROP DATABASE` / `TRUNCATE` 等破坏性语句
- [ ] 保留字列名统一策略已应用（双引号 或 改名）
- [ ] 大小写策略已明确并应用
- [ ] 方言特异 SQL 有注释说明原因

## 配置

- [ ] `application-integration-highgo.yml` 未含明文密码（走占位或环境变量）
- [ ] `application-integration-mysql-baseline.yml` 保留未删
- [ ] Druid / HikariCP 参数经过评估
- [ ] 分页插件方言参数已调整

## 测试

- [ ] 本 PR 涉及的模块，单元测试全绿
- [ ] 本 PR 涉及的模块，集成测试在瀚高下全绿
- [ ] 无 `@MockBean` 替代数据库
- [ ] 无 Testcontainers 依赖引入
- [ ] 若有用例增删，PR 描述说明原因

## 文档

- [ ] 相关风险矩阵条目已标记为 ✅
- [ ] 如做"分方言 Mapper"或"SQL 逻辑上移"，有 `decisions/` 记录
- [ ] 如发现通用踩坑，工具包 `fix-issue/` 有待提交的条目

## Commit 规范

- [ ] 每类差异独立 commit
- [ ] Commit 消息含阶段、类别、风险矩阵引用
- [ ] 无混入格式化 / 无关重构的大 diff

## 审阅自查

- [ ] 自己以 reviewer 视角过了一遍 diff
- [ ] 关键改动已在 PR 描述中解释"为什么这么改"
