# Stage 4 — SQL 方言适配

## 目标

按 Stage 0 产出的风险矩阵，**分类别、分批** 修改 SQL / 代码，使其在 GaussDB B 兼容模式下可正确执行。

## 预计工期

按风险矩阵行数估算：低风险 5~10 分钟/条，中风险 15~30 分钟/条，高风险 1~2 小时/条。

## 输入

- `risk-matrix.md`
- `references/mysql-to-gaussdb-{type,syntax,function}-mapping.md`
- Stage 1 测试集

## 核心约束

1. **B 模式原生兼容 ≠ 可以不管**：必须跑测试验证每一类改动
2. **分类别 commit**：每类差异一个 commit，便于回滚与 review
3. **每个 commit 后测试跑绿**再进入下一类
4. **改码 + 改测试分开提交**：若需调整断言，单独 commit 说明原因

## 步骤

### 4.1 按类别分组

参考 `references/mysql-to-gaussdb-syntax-mapping.md` 的 **"B 模式行为差异"** 列，把风险矩阵中的条目分成若干类：

| 类别示例 | 优先级 | 说明 |
|---------|--------|------|
| JDBC URL / 连接参数 | 高 | Stage 2 已处理，本阶段复查 |
| 字符集 / 排序规则 | 高 | 影响比较、排序、索引选择 |
| 时区 / 时间类型语义 | 高 | 易隐蔽，需专项测 |
| 保留字列名 | 中 | 加双引号或改名 |
| 边缘函数差异 | 中 | 如特定位运算、字符串函数 |
| 分页 SQL 细节 | 中 | PageHelper/MP 产生的 SQL |
| 存储过程 / 触发器 | 高（如有） | 语法转换成本高 |
| 执行计划敏感 SQL | 低 | 功能 OK 但性能变化 |

### 4.2 对每一类执行 "小循环"

**小循环** = 改码 → 跑测试 → 修测试 → commit

1. 从风险矩阵挑出该类所有条目
2. 统一改写（调用 Skill `db-migration-dialect-rewrite` 获取建议 diff）
3. **人工 review** Skill 建议（Skill 不自动改码）
4. 应用修改
5. 跑相关测试：`mvn -P integration-gaussdb test -Dtest=<pattern>`
6. 全绿后 commit，消息格式：
   ```
   refactor(db): Stage 4 适配 <类别名>

   - 涉及文件 N 个
   - 风险矩阵条目：R-xx, R-yy, R-zz
   - 验证：XxxMapperIntegrationTest、YyyServiceIntegrationTest 全绿
   ```
7. 更新 `risk-matrix.md` 中对应条目状态为 ✅

### 4.3 无法直接兼容的场景

若某条 SQL 在 B 模式下**无法原样运行**，选择以下策略之一：

- **改写**：调整为 GaussDB 兼容写法（优先）
- **分方言 Mapper**：MyBatis 使用 `databaseId`，同名 statement 区分 mysql / gaussdb
- **Java 侧处理**：把部分逻辑从 SQL 抽到 Service（慎用，偏离"只做适配"约束）

每次选用第二、三种策略需在 `project-docs/decisions/` 记录决策与原因。

### 4.4 集成测试双轨验证

保留 Stage 1 的 `integration-mysql-baseline` profile，Stage 4 期间每次改动后：
- 先跑 `integration-gaussdb` profile，确认新功能绿
- 再跑 `integration-mysql-baseline` profile，确认未破坏 MySQL 行为（如需保留 MySQL 兼容）

**例外**：若改动是 GaussDB 特有（如 `databaseId` 分方言），MySQL 基线应跳过对应用例。

### 4.5 存储过程 / 触发器（如存在）

**默认建议**：在本方案范围内**不重写**存储过程，而是把逻辑提到 Java 层。

理由：
- 跨方言存储过程语法差异大
- 维护成本高、不利测试
- 违反"不改架构"原则但加"改薄架构"收益明确

若业务强依赖无法改，单独立项处理，并记录到 `decisions/`。

## 出口检查

- [ ] `risk-matrix.md` 所有条目状态为 ✅ 或 `decision-deferred`
- [ ] 每类差异都有独立 commit
- [ ] 所有集成测试在 GaussDB 下全绿
- [ ] 未修改 `db/migration/mysql/` 任何文件
- [ ] 所有"分方言"或"架构调整"决策有 `decisions/` 记录

## 产出物

- 一系列 refactor commit
- 更新后的 `risk-matrix.md`
- 若干 `project-docs/decisions/YYYY-MM-DD-*.md`

## 注意事项

- **不要合并多类差异到一个 commit**：出问题不好二分
- **不要跳过测试**：即使是"看起来没影响"的改动
- **Skill 建议要 review**：自动工具可能漏改或误改

## 下一阶段

→ [Stage 5 — 回归与交付](stage-5-verify-deliver.md)
