---
updated: YYYY-MM-DD
project: <工程名>
stage: 0-kickoff
---

# <工程名> 测试缺口清单

## 1. 总体统计

| 指标 | 数值 |
|------|------|
| DAO / Mapper 类总数 | |
| DAO / Mapper 方法总数 | |
| 已有单元测试覆盖的方法数 | |
| 已有集成测试覆盖的方法数 | |
| 零覆盖方法数 | |

## 2. 关键路径覆盖清单（必须在 Stage 1 补齐）

> 按 Stage 1 的优先级定义，`优先级 = 是否公共 + 是否事务 / 批量 + 是否使用 MySQL 特性 + 是否对外接口直达`

| Mapper / DAO 类 | 方法 | 优先级 | 已有单测 | 已有集测 | 使用 MySQL 特性 | 备注 |
|-----------------|------|--------|---------|---------|-----------------|------|
| UserMapper | insertOrUpdate | 高 | ❌ | ❌ | ON DUPLICATE KEY | 公共 |
| OrderMapper | batchInsert | 高 | ❌ | ✅ | 多值 INSERT | 批量 |
| ReportMapper | aggregate | 高 | ✅ | ❌ | GROUP_CONCAT | 需补集测 |
| ... | | | | | | |

## 3. 非关键路径（Stage 1 之后按需补）

| Mapper / DAO 类 | 方法 | 已有覆盖 | 备注 |
|-----------------|------|---------|------|
| | | | |

## 4. 测试基础设施缺口

- [ ] 本地 MySQL 实例
- [ ] 本地瀚高 v4.1.5 实例 / 可访问共享测试库（已注入 MySQL 兼容脚本）
- [ ] `application-integration-mysql-baseline.yml`
- [ ] `application-integration-highgo.yml`
- [ ] 测试造数工具（SQL / `@Sql` / 工具类）
- [ ] 测试后清理机制

## 5. 补测工作量估算

- 需补单元测试：<N> 个方法，约 <X> 工时
- 需补集成测试：<N> 个方法，约 <X> 工时
- 测试基础设施搭建：约 <X> 工时

## 6. 出口标准

Stage 1 完成条件：
- 本清单中"关键路径"一栏全部补齐
- 在 MySQL 下全绿
- 本文件 `updated:` 字段刷新
- 所有"已有覆盖"勾选真实反映代码状态
