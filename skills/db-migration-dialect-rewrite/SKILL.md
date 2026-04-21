---
name: db-migration-dialect-rewrite
description: 针对风险矩阵中的某一类差异，给出 MySQL → GaussDB B 兼容模式的建议改写 diff。只产出建议，不自动改码。Stage 4 方言适配时按类别调用。
---

# db-migration-dialect-rewrite

## 触发场景

- Stage 4 准备处理风险矩阵的某一类差异
- 需要一份"改哪里 / 怎么改"的具体建议清单

## 前置条件

- 已有 `project-docs/facts/YYYY-MM-DD-risk-matrix.md`
- 风险矩阵条目已按类别分组
- 已读 `docs/references/mysql-to-gaussdb-*.md`

## 输入

- 类别名（如 "JSON 函数"、"保留字"、"字符集"、"TIMESTAMP 时区"）
- 对应的风险矩阵条目子集

## 执行步骤

### 1. 定位条目

从 risk-matrix.md 中筛选出指定类别的所有条目。

### 2. 按特性提供改写建议

对每个条目，产出：

```
条目 ID：R-xxx
文件：src/main/resources/mapper/UserMapper.xml
位置：第 42 行
原 SQL 片段：
    SELECT GROUP_CONCAT(name ORDER BY id SEPARATOR ',') FROM users

GaussDB B 模式预期行为：原生兼容 ✅
建议动作：
  - 不改 SQL，但增加集成测试验证结果与 MySQL 一致
  - 测试要点：分隔符、排序、NULL 处理

参考：docs/references/mysql-to-gaussdb-function-mapping.md#group_concat
```

```
条目 ID：R-xxx
文件：src/main/resources/mapper/OrderMapper.xml
位置：第 88 行
原 SQL 片段：
    SELECT * FROM orders WHERE `user` = #{userId}

B 模式下状态：保留字 `user`，B 模式兼容但仍建议加引号
建议改写（diff 形式）：
    - SELECT * FROM orders WHERE `user` = #{userId}
    + SELECT * FROM orders WHERE "user" = #{userId}

或改名（影响面评估）：
    - 代码侧：UserMapper.java 有 X 处引用
    - 成本：中

推荐：加双引号（本工程统一策略）
```

### 3. 无法直接改写的场景

若某条 SQL 无简单等价改写：
- 提示"分方言 Mapper（`databaseId`）"方案
- 提示"SQL 逻辑上移到 Service"方案
- 给出示例代码框架

### 4. 影响面评估

对每个建议，估算：
- 单独文件改动量
- 跨文件连带改动（如列改名影响其他 Mapper）
- 测试影响范围

### 5. 产出清单

写入 `<project>/project-docs/plans/YYYY-MM-DD-stage4-<category>-rewrite.md`：

```markdown
# Stage 4 - <类别> 改写清单

## 概览
- 条目数：N
- 纯验证（不改）：M
- 需改写：K
- 预估工时：X

## 详细建议
<上述每条的详细说明>

## 执行顺序
1. ...
2. ...

## 测试策略
<如何验证改写正确>

## Commit 建议
<建议的 commit 消息格式与拆分>
```

## 输出

- `<project>/project-docs/plans/YYYY-MM-DD-stage4-<category>-rewrite.md`
- 控制台摘要

## 约束

- **绝对不直接改代码**
- 所有建议必须引用 `references/` 作为依据
- 建议 diff 使用 `unified diff` 格式，便于复制应用
- 不确定的建议标 `需验证` 或 `需决策`

## 人工操作流程

1. Skill 产出清单
2. 人工 review，挑选要执行的条目
3. 人工或借助 AI 工具应用 diff
4. 跑集成测试
5. 测试绿后 commit
6. 更新 risk-matrix.md 状态

## 后续步骤

→ 按清单逐类闭环
→ 所有类别闭环后进入 Stage 5
