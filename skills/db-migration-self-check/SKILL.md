---
name: db-migration-self-check
description: MySQL 方言遗漏自检。在验收完成后扫描项目 SQL 源码（Mapper XML、注解 SQL、内嵌 SQL），发现可能遗漏的 MySQL 方言，输出结构化报告。仅出报告，不阻断交付。
---

# db-migration-self-check

## 触发场景

- Stage 5 验收测试已通过，准备交付
- 需要确认项目中不存在未被改造的 MySQL 方言
- work-cycle-auto Stage 6 验收报告生成后自动调用

## 前置条件

- Stage 4 方言适配已完成
- `docs/references/highgo-v4.1.5-mysql-compat-functions.md` 可用（兼容白名单来源）
- `fix-issue/` 目录可用（风险提示关联来源）

## 扫描范围

| 文件类型 | 匹配方式 | 说明 |
|---------|---------|------|
| MyBatis XML Mapper | `**/*Mapper.xml`、`**/*mapper.xml` | 所有 XML mapper 文件 |
| MyBatis Mapper 接口 | `**/*Mapper.java`、`**/*mapper.java` | 含 `@Select`/`@Update`/`@Delete`/`@Insert` 注解 |
| JPA Repository | `**/*Repository.java` | 含 `@Query` 注解 |
| JdbcTemplate 内嵌 SQL | 搜索含 `"SELECT`/`"INSERT`/`"UPDATE`/`"DELETE` 字符串字面量的 Java 文件 | 非注解形式的内嵌 SQL |

## 执行步骤

### 1. 文件发现

使用 Glob 定位所有目标文件：

```
Glob: **/*Mapper.xml
Glob: **/*mapper.xml
Glob: **/*Mapper.java
Glob: **/*mapper.java
Glob: **/*Repository.java
```

对 Java 文件补充内嵌 SQL 扫描：

```
Grep: "SELECT|"INSERT|"UPDATE|"DELETE  (in .java files)
```

记录文件清单和总数。

### 2. 语法层扫描（A 类）

按照 `self-check-rules.md` 中 A1-A14 的 Grep 关键词/正则，对步骤 1 发现的所有文件逐条扫描。

对每个命中记录：
- 文件路径
- 行号
- 匹配内容（含上下文 2-3 行）
- 规则编号和建议

**注释过滤**：命中后阅读上下文，排除以下场景：
- XML 注释 `<!-- ... -->` 中的内容
- Java 单行注释 `// ...`
- Java 多行注释 `/* ... */`
- SQL 单行注释 `-- ...`

### 3. 函数层扫描（B 类 + C 类）

对步骤 1 发现的所有文件，按照 `self-check-rules.md` 中 B1-B5 和 C1-C10 的 Grep 关键词逐条扫描。

分类处理：
- **B 类（兼容白名单）**：命中标记为"已兼容"，附加已知缺口提示文本
- **C 类（必须标记）**：命中标记为"需确认"，附建议替代写法

### 4. 风险模式扫描（D 类）

扫描 `self-check-rules.md` 中 D1-D6 的风险模式。

对每个命中：
- 在 `fix-issue/` 目录中搜索相关条目
- 附带匹配到的 fix-issue 文件路径

### 5. 汇总过滤

- 去重（同文件同行多次匹配合并）
- 排除确认在注释中的命中
- 统计各分类命中数

### 6. 生成报告

写入 `{项目目录}/docs/migration/self-check-report.md`，格式如下：

```markdown
# MySQL 方言自检报告

项目：{项目名}
扫描时间：{timestamp}
扫描文件数：{N} 个

## 摘要

| 分类 | 命中数 |
|------|-------|
| 🔴 语法层（需改造） | {n} |
| 🟡 函数层（需确认） | {n} |
| 🟢 兼容函数（已知缺口提示） | {n} |
| ⚠️ 风险模式（fix-issue 关联） | {n} |

## 详细发现

### 🔴 语法层

（逐条列出命中，含文件路径、行号、匹配内容、建议）

### 🟡 函数层（需确认）

（逐条列出命中）

### 🟢 兼容函数（已知缺口提示）

（逐条列出命中 + 缺口提示文本）

### ⚠️ 风险模式

（逐条列出命中 + fix-issue 关联路径）

## 无命中项

以下规则未检测到命中（供确认覆盖完整性）：
- A1 反引号标识符 ✅
- A2 双引号字符串 ✅
- A3 LIMIT m,n ✅
- ...（列出所有规则及其命中状态）
```

## 输出

- `{项目目录}/docs/migration/self-check-report.md`
- 控制台摘要：命中总数、按分类分布、高风险项 Top 10

## 约束

- **仅出报告，不阻断交付流程**
- 不修改任何代码文件
- 不自动应用修复建议
- 正则匹配假阳性时在报告中标注"需人工复核"
- 扫描覆盖动态 SQL 片段（`<if>` / `<foreach>` 内部 SQL）

## 后续步骤

→ 人工 review 报告
→ 确认命中项是否需要修复
→ 如需修复，回到 Stage 4 处理
