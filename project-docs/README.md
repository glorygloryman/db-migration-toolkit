# project-docs

本目录存放**本工具包自身**的元治理文档，与 `docs/` 区分：

| 目录 | 对象 | 读者 |
|------|------|------|
| `../docs/` | **交付给下游消费方**的产品文档（SOP、模板、对照表） | `xz-source/` 下 20+ 消费方工程 |
| `project-docs/`（本目录） | **工具包自身**的计划、决策、事实、踩坑 | 工具包维护者（含未来 Claude Code 实例） |

## 子目录

- `plans/` — 路线图、迭代 TODO（例：v1.0.0 出口条件）
- `decisions/` — 架构/设计决策记录（为什么选 A 不选 B）
- `facts/` — 当前真实状态（消费方清单、Pilot 进度），含 `updated:` 字段，会过期
- `fix-issue/`（预留，暂未建立）— 若工具包自身运维出现踩坑，落此处；**跨工程通用的 MySQL→瀚高 踩坑仍放根目录 `fix-issue/`**（那是产品侧踩坑库）
- `_meta/doc-catalog.yaml` — 文档索引，按 `~/.claude/CLAUDE.md §5` 文档治理协议维护

## 文档命名

`YYYY-MM-DD-<slug>.md`，日期为首次创建日期。

## 新增文档流程

1. 判断语义类型（`plan` / `decision` / `fact` / `fix-issue`）并落到对应子目录
2. 按全局 §5 文档治理协议的 frontmatter 要求填 `updated:` 等字段
3. 在 `_meta/doc-catalog.yaml` 增加索引条目
4. 若是 `fact` 类，30 天未更新需标注"可能过时"
