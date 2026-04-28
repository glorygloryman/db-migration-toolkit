---
updated: 2026-04-27
source: propagation-billboard/9119d533
related-risk: R-005
severity: 🟡
category: 其他
---

# 瀚高中文报错导致集成测试 safeQuery 跳过逻辑失效

## 现象

集成测试中使用 `safeQuery` 模式，通过匹配异常消息中的关键字（如 `doesn't exist`）来跳过因表不存在等 Schema 差异导致的测试失败。切换到瀚高数据库后，同样的"表不存在"错误不再被匹配，测试直接抛异常而非跳过。

原因：瀚高（中文环境安装）的报错信息为中文，例如：

```
关系 "xxx" 不存在
```

而原有的匹配逻辑只检查英文关键字 `doesn't exist` / `Table.*not found`。

## 根因

瀚高数据库的错误消息语言取决于安装时的 locale 设置。中文环境下，PostgreSQL 内核的错误消息会以中文输出（通过 `gettext` 国际化）。`pg_catalog` 级别的错误（如 `undefined_table`）会被翻译为中文。

原有 safeQuery 未考虑中文 locale，导致错误消息匹配失败。

## 修复动作 / 规避准则

在 safeQuery 的错误匹配中同时兼容中英文报错信息：

```java
private <T> T safeQuery(Supplier<T> query) {
    try {
        return query.get();
    } catch (Exception e) {
        String msg = e.getMessage() != null ? e.getMessage() : "";

        // 同时兼容英文 + 瀚高中文报错
        if (msg.contains("doesn't exist")
            || (msg.contains("Table") && msg.contains("not found"))
            || (msg.contains("关系") && msg.contains("不存在"))) {
            Assume.assumeTrue("SCHEMA_GAP: " + msg, false);
        }

        if (msg.contains("not found") && msg.contains("Available parameters")) {
            Assume.assumeTrue("PARAM_BINDING_GAP: " + msg, false);
        }
        throw e;
    }
}
```

**排查建议**：搜索项目中所有通过异常消息匹配来做跳过/降级处理的测试代码，检查是否需要同时兼容中文。

## 影响范围

所有使用中文 locale 安装的瀚高数据库环境，以及集成测试中依赖错误消息匹配的场景。其他 20+ 工程如使用类似 safeQuery 模式，均需同步修改。

## 来源

- 工程：propagation-billboard
- Commit：9119d533786398515364384f6c894bf1990a6eae
- 日期：2026-04-27
- 记录人：吴少辉

## 参考

- 相关 risk：R-005（大小写敏感与标识符 — 追加了中文报错说明）
