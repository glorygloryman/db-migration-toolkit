# 前置调研清单（Stage 0 出口）

> 用途：Stage 0 结束前逐项核对，任何一项未完成不得进入 Stage 1。

## 1. 基线文档

- [ ] `project-docs/facts/YYYY-MM-DD-db-migration-baseline.md` 已产出
- [ ] `project-docs/facts/YYYY-MM-DD-risk-matrix.md` 已产出
- [ ] `project-docs/facts/YYYY-MM-DD-test-gap.md` 已产出
- [ ] 三份文件均含 `updated:` 字段

## 2. 目标库信息

- [ ] GaussDB 版本号已记录
- [ ] 兼容模式确认 = B（MySQL 兼容）
- [ ] 部署形态确认（集中式 / 分布式 / DWS）
- [ ] JDBC 驱动获取渠道已确认
- [ ] 测试环境连接信息已获取（或已明确获取时间点）

## 3. 持久层盘点完成

- [ ] ORM 框架类型、版本已记录
- [ ] 分页插件及现有方言已记录
- [ ] 连接池类型、版本已记录
- [ ] Flyway / Liquibase 状态已记录
- [ ] 存储过程 / 触发器 / 事件使用情况已排查

## 4. MySQL 特性依赖扫描

- [ ] 语法类扫描完成（反引号、LIMIT m,n、ON DUPLICATE KEY 等）
- [ ] 类型类扫描完成（TINYINT(1)、ENUM、JSON、TEXT 家族）
- [ ] 保留字冲突扫描完成
- [ ] 大小写敏感性评估完成
- [ ] 自增 / 序列使用情况评估完成
- [ ] 隐式类型转换点评估完成

## 5. SQL 仓统计

- [ ] Mapper XML 文件数、行数已记录
- [ ] 动态 SQL 占比已记录
- [ ] Native Query 占比已记录
- [ ] 硬编码 SQL 位置已记录

## 6. 测试基线评估

- [ ] 本地 MySQL 环境可用
- [ ] `application-integration-mysql-baseline.yml` 已就绪
- [ ] "关键路径"清单已圈定
- [ ] 测试缺口按优先级排序

## 7. 风险矩阵

- [ ] 每条风险有：文件、特性、严重度、建议动作
- [ ] 高风险项已上浮，有沟通记录（若有重大风险）
- [ ] 范围外问题（性能、架构、灰度）已标注"不在本方案范围内"
