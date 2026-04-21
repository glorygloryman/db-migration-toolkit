# Stage 4 — SQL 方言适配（瀚高 v4.1.5）

## 目标

按 Stage 0 产出的风险矩阵，**分类别、分批**修改 SQL / 代码，使其在瀚高 v4.1.5 下可正确执行。与旧假设（GaussDB B 模式下多数 MySQL 语法原生兼容）不同，瀚高基于 PG 方言，**函数层由 Stage 2 注入的厂家脚本抹平**，**语法层必须逐条改写**。

## 预计工期

按风险矩阵行数估算。工作量分布：

- **函数层冲突**（脚本已覆盖）：5 分钟/条（仅需验证 + 跑测试）
- **函数层缺口**（脚本未覆盖或缺重载）：15~30 分钟/条（改写 SQL）
- **语法层（反引号 / LIMIT / ON DUPLICATE / UPDATE JOIN）**：15~30 分钟/条
- **JSON 查询**：30~60 分钟/条（语法差异大）
- **存储过程/触发器**（如存在）：按专项决议，默认上移 Java 层

## 输入

- `risk-matrix.md`（Stage 0 产出）
- `references/mysql-to-highgo-type-mapping.md`
- `references/mysql-to-highgo-syntax-mapping.md`
- `references/mysql-to-highgo-function-mapping.md`（特别关注“脚本覆盖”列）
- `references/highgo-v4.1.5-mysql-compat-functions.md`（兼容脚本说明）
- Stage 1 测试集

## 核心约束

1. **函数层冲突优先查兼容脚本**：脚本已覆盖 → 不改 SQL，跑测试验证；脚本未覆盖或缺重载 → 改写
2. **语法层必须改**：反引号 / `LIMIT m,n` / `ON DUPLICATE KEY UPDATE` 等 PG 不支持，不能跳过
3. **分类别 commit**：每类差异一个 commit，便于回滚与 review
4. **每个 commit 后测试跑绿**再进入下一类
5. **改码 + 改测试分开提交**：若需调整断言，单独 commit 说明原因

## 步骤

### 4.1 按类别分组

参考 `references/mysql-to-highgo-syntax-mapping.md` 的状态列（✅/⚠️/🔄/❌），把风险矩阵中的条目分成若干类：

| 类别 | 典型特征 | 优先级 | 脚本覆盖 | 说明 |
|------|---------|--------|---------|------|
| JDBC URL / 连接参数 | `jdbc:gaussdb:` 残留 | 高 | — | Stage 2 已处理，本阶段复查 |
| 字符集 / 排序规则 | `utf8mb4_general_ci` | 高 | — | 影响比较、排序、索引选择 |
| 时区 / 时间类型语义 | `DATETIME` / `TIMESTAMP` | 高 | 部分 | 易隐蔽，需专项测 |
| 反引号标识符 | `` `user` `` `` `order` `` | 高 | — | ❌ PG 不支持；改双引号或全小写 |
| `LIMIT m, n` 分页 | `LIMIT 10, 20` | 高 | — | ❌ 改 `LIMIT 20 OFFSET 10` |
| `ON DUPLICATE KEY UPDATE` | upsert 用法 | 高 | — | ❌ 改 `INSERT ... ON CONFLICT DO UPDATE` |
| `REPLACE INTO` / `INSERT IGNORE` | mysql 特有 upsert 变种 | 高 | — | ❌ 改 ON CONFLICT |
| `UPDATE/DELETE ... LIMIT n` | 批量带 LIMIT | 中 | — | ❌ 改子查询 `WHERE pk IN (SELECT ... LIMIT n)` |
| `UPDATE t1 JOIN t2` | 多表 UPDATE | 中 | — | ❌ 改 `UPDATE t1 SET ... FROM t2 WHERE ...` |
| 保留字列名 | `user` / `type` / `order` | 中 | — | 加双引号或改名 |
| 函数层脚本已覆盖 | `IFNULL(int, int)` / `FIND_IN_SET` | 低 | ✅ 🛡️ | 不改，跑测试验证 |
| 函数层脚本缺口 | `IFNULL(timestamp, timestamp)` / `IF(cond, int, int)` | 中 | ❌ | 改 `COALESCE` / `CASE WHEN` |
| `DATE_FORMAT` 递归风险 | 所有 `DATE_FORMAT` 调用 | 高 | ⚠️ | Stage 2 已验证通过则免改；未通过需改写 `TO_CHAR` |
| JSON 查询 | `j->'$.a'` / `JSON_EXTRACT` | 高 | — | 语法完全不同，见 function-mapping |
| MySQL Hint | `STRAIGHT_JOIN` / `USE INDEX` | 中 | — | 去除，让优化器决定 |
| `LOCK IN SHARE MODE` | MySQL 共享锁 | 低 | — | 改 `FOR SHARE` |
| 存储过程 / 触发器 | `DELIMITER //` / `CREATE PROCEDURE` | 高（如有） | — | 默认上移 Java 层 |

### 4.2 对每一类执行“小循环”

**小循环** = 改码 → 跑测试 → 修测试 → commit

1. 从风险矩阵挑出该类所有条目
2. 统一改写（调用 Skill `db-migration-dialect-rewrite` 获取建议 diff，**Skill 不自动改码**）
3. **人工 review** Skill 建议
4. 应用修改
5. 跑相关测试：`mvn -P integration-highgo test -Dtest=<pattern>`
6. 全绿后 commit，消息格式：

   ```
   refactor(db): Stage 4 适配 <类别名>

   - 涉及文件 N 个
   - 风险矩阵条目：R-xx, R-yy, R-zz
   - 验证：XxxMapperIntegrationTest、YyyServiceIntegrationTest 全绿
   ```

7. 更新 `risk-matrix.md` 中对应条目状态为 ✅

### 4.3 函数层兼容脚本验证子流程

针对“函数层脚本已覆盖”类别，因为**不改 SQL 就过**，需额外谨慎：

1. 确认 Stage 2 已成功注入脚本且 7 条冒烟 SQL 全通过
2. 对每个涉及函数的 Mapper 方法，至少一条集成测试覆盖真实数据
3. 特别关注 `DATE_FORMAT` / `TRUNCATE`（除法）/ `MOD(text, int)` 这类有“已知行为差异”的函数
4. 测试失败回到 4.2 作为“脚本缺口”类别改写

### 4.4 无法直接兼容的场景

若某条 SQL 在瀚高下**无法原样运行**（脚本不覆盖、语法不能改写、业务无法上移 Java 层）：

- **策略 1 改写**：调整为瀚高 PG 方言写法（优先）
- **策略 2 分方言 Mapper**：MyBatis 使用 `databaseId`，同名 statement 区分 mysql / highgo
- **策略 3 Java 侧处理**：把部分逻辑从 SQL 抽到 Service（慎用，偏离“只做适配”约束）

每次选用策略 2 / 3 需在 `project-docs/decisions/` 记录决策与原因。

### 4.5 集成测试双轨验证

保留 Stage 1 的 `integration-mysql-baseline` profile，Stage 4 期间每次改动后：

- 先跑 `integration-highgo` profile，确认新功能绿
- 再跑 `integration-mysql-baseline` profile，确认未破坏 MySQL 行为（保留 MySQL 兼容时）

**例外**：若改动是瀚高特有（如 `databaseId` 分方言），MySQL 基线应跳过对应用例。

### 4.6 存储过程 / 触发器（如存在）

**默认建议**：不重写存储过程，把逻辑提到 Java 层。

理由：
- PG PL/pgSQL 与 MySQL 存储过程语法**完全不同**，兼容脚本不覆盖此类
- 维护成本高、不利测试
- 违反“不改架构”原则但加“改薄架构”收益明确

若业务强依赖无法改，单独立项处理，并记录到 `decisions/`。

## 出口检查

- [ ] `risk-matrix.md` 所有条目状态为 ✅ 或 `decision-deferred`
- [ ] 每类差异都有独立 commit
- [ ] 所有集成测试在瀚高下全绿
- [ ] 函数层脚本已覆盖的条目均有测试覆盖（而非仅靠 ✅ 假设通过）
- [ ] 未修改 `db/migration/mysql/` 任何文件
- [ ] 所有“分方言”或“架构调整”决策有 `decisions/` 记录

## 产出物

- 一系列 refactor commit
- 更新后的 `risk-matrix.md`
- 若干 `project-docs/decisions/YYYY-MM-DD-*.md`

## 注意事项

- **不要合并多类差异到一个 commit**：出问题不好二分
- **不要跳过测试**：即使是“看起来没影响”的改动
- **脚本覆盖 ≠ 免测**：函数层脚本已覆盖只是说“不改 SQL”，仍必须测
- **Skill 建议要 review**：自动工具可能漏改或误改

## 下一阶段

→ [Stage 5 — 回归与交付](stage-5-verify-deliver.md)
