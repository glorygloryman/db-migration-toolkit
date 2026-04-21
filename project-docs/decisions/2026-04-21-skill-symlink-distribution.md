---
type: decision
title: 为什么用软链而非复制/包管理分发 Skills
created: 2026-04-21
updated: 2026-04-21
status: accepted
supersedes: 无
---

# 为什么用软链而非复制/包管理分发 Skills

## 背景

`xz-source/` 下 20+ 工程需要消费本工具包的 Claude Code Skills（落在每个工程的 `.claude/skills/` 目录下，才能被 Claude Code 识别）。分发方式决定"工具包升级"与"工程端感知"之间的耦合形态。

## 候选方案

### 方案 A：软链（symlink）✅ 采纳

```bash
# 消费方工程根目录
mkdir -p .claude/skills
cd .claude/skills
ln -s ../../../db-migration-toolkit/skills/db-migration-baseline .
# ... 其余 5 个
```

**优点**：
- 工具包一处修改，所有消费方立即同步，无版本漂移
- 零工具链依赖——只要文件系统支持软链即可
- 对 Claude Code 完全透明，识别到的是真实的 `SKILL.md`
- Git 层面每个消费方只提交一条软链指针，不污染其仓库

**代价**：
- 依赖**固定的相对路径布局**：假定 `db-migration-toolkit` 与消费方工程都在 `xz-source/` 下同级
- Windows 原生不支持符号链接（需要管理员权限或 WSL）——当前 `xz-source/` 全部开发在 macOS/Linux，暂无影响
- 消费方工程如果被独立 clone 到别处，软链会失效

### 方案 B：Git submodule ❌ 拒绝

**优点**：版本可锁定；跨平台兼容。
**代价**：
- 20+ 工程各自维护 submodule 指针，升级需逐个 PR
- 消费方开发者需要理解 submodule 心智模型（团队当前不熟悉）
- 实质上造成版本漂移，违背"一处修改全局生效"目标

### 方案 C：复制 + 脚本同步 ❌ 拒绝

**优点**：无路径假设，完全自治。
**代价**：
- 20+ 工程各有一份拷贝，极易漂移
- 需要额外维护同步脚本和 CI
- 无法在 Skill 修改后立即生效，必须触发同步

### 方案 D：发布成 npm / pip 包 ❌ 拒绝

**优点**：标准化、版本化、可发现。
**代价**：
- Claude Code Skills 目前没有标准包管理通路
- 对"Markdown 即产品"的工具包是过度工程
- 发布/订阅开销显著大于收益

## 决策

**采用方案 A（软链）**，原因：

1. 命中核心诉求"一处修改、全局生效"——Pilot 阶段 SOP 会频繁迭代，版本漂移会让迭代成本失控
2. 消费方工程布局已固定在 `xz-source/` 下同级——路径假设成立
3. 零工具链、零学习成本，20+ 工程接入只需 `ln -s` 命令一次

## 约束与后果

- 工具包与消费方的**目录布局契约**必须稳定：
  - 工具包始终位于 `<xz-source>/db-migration-toolkit/`
  - 消费方始终位于 `<xz-source>/<project>/`
  - 软链写死 `../../../db-migration-toolkit/skills/<name>`
- 迁移工具包仓库时（如改名、换路径），必须一次性更新所有消费方的软链（需提供迁移脚本）
- `README.md` 的"如何在工程中使用 Skills"章节是唯一接入指南，**不得被 Skill 内部文档覆盖或绕过**

## 何时重新评估

- 引入 Windows 原生开发机
- 消费方工程迁出 `xz-source/` 共同父目录
- Claude Code 官方提供标准 Skill 包管理机制
- 工具包稳定到 v1.0.0+ 后改为季度发布节奏（届时版本锁定收益开始超过即时同步收益）
