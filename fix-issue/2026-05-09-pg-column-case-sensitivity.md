---
updated: 2026-05-09
source: tmy-decision-center/AreaHotwordRepository
related-risk: 无
severity: 🟡
category: 保留字
---

# PostgreSQL 列名大小写敏感导致查询失败

## 现象

原生 SQL 中使用 `HotWord`、`RecNum`、`LOADTIME` 等大写驼峰列名。MySQL 对列名不区分大小写，正常运行。PostgreSQL 对未加引号的标识符自动折叠为小写，如果 SQL 中大小写与实际列名不一致则查询失败或返回空结果。

## 根因

PostgreSQL 标识符规则：
- 未加引号 → 折叠为小写
- 加引号 → 保留原始大小写

MySQL 不区分大小写，开发者习惯随意混用大小写。迁移到 PostgreSQL 后，SQL 中的列名必须与数据库实际列名一致（全部小写，或加引号的大写）。

## 修复动作 / 规避准则

将原生 SQL 中的列名全部改为小写：`HotWord` → `hotword`，`RecNum` → `recnum`，`LOADTIME` → `loadtime`。

规避准则：
1. 原生 SQL 中列名**全部使用小写**，与 PostgreSQL 默认行为一致
2. 代码审查扫描原生 SQL 中的大写列名（非关键字的大写标识符）
3. JPA 实体的 `@Column(name = "xxx")` 中的 name 保持小写

## 影响范围

所有原生 SQL（JPA `@Query(nativeQuery=true)`、MyBatis XML）中使用大写列名的查询。影响面取决于开发者对 MySQL 大小写不敏感特性的依赖程度。

## 来源

- 工程：tmy-decision-center
- 源文件：`AreaHotwordRepository.java` → `getHotwords`
- 日期：2026-05-09
- 记录人：吴少辉

## 参考

- 相关 reference：`docs/references/mysql-to-highgo-syntax-mapping.md`（标识符大小写条目）
