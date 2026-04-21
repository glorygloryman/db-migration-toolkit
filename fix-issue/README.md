# fix-issue 踩坑库

本目录存放**跨工程可复用**的 MySQL → GaussDB 改造踩坑记录。

## 准入标准（按 CLAUDE.md §5 文档治理协议）

一条 `fix-issue` 必须同时具备四要素：

1. **问题现象**：能复现、可观察
2. **根因分析**：为什么发生
3. **修复动作 或 规避准则**：怎么解决 / 下次怎么避开
4. **真实来源**：来自哪个工程、哪次改造、哪个 commit

不满足上述四要素的问题按 CLAUDE.md §5 分流：
- 仅现象无根因 → `fact`（纳入 `docs/risks/`）
- 操作指引型 → `playbook`（待建目录）
- 方案选型型 → `decision`（留在工程本地 `project-docs/decisions/`）
- 经验答疑型 → `faq`（待建目录）

## 文件命名

`YYYY-MM-DD-<short-slug>.md`

## 文件格式

```markdown
---
updated: YYYY-MM-DD
source: <project-name>/<path or commit>
related-risk: R-xxx（如有）
severity: 🔴 / 🟡 / 🟢
category: 驱动 / 连接池 / 语法 / 函数 / 类型 / 保留字 / 字符集 / 时区 / 存储过程 / 其他
---

# <标题：现象的简短描述>

## 现象

<可复现的错误描述、日志片段、SQL 样例>

## 根因

<为什么发生，涉及的 GaussDB 行为或配置>

## 修复动作 / 规避准则

<具体怎么解、未来怎么避>

## 影响范围

<哪些场景会触发、哪些工程可能遇到>

## 来源

- 工程：<project-name>
- Commit：<sha>
- 日期：YYYY-MM-DD
- 记录人：<name>

## 参考

- 相关 reference：`docs/references/xxx.md`
- 相关 risk：R-xxx
```

## 索引

<!-- Pilot 后在此维护分类索引 -->

暂无条目。Pilot 开始后产出。

## 贡献流程

1. 在本工程 `project-docs/fix-issue/` 产生条目
2. 判断是否"通用性"（其他 MySQL 工程也可能遇到）
3. 拷贝到本目录（保留 `source:` 字段指向原工程）
4. 提 PR 到 `db-migration-toolkit` 仓库
5. 更新本 README 的索引
