---
updated: 2026-04-28
source: propagation-billboard/AreaManager
related-risk: R-020
severity: 🟡
category: 类型
---

# AreaManager QueryWrapper IN 查询类型不匹配

## 现象

集成测试 `DictServiceIntegrationTest#test08_southEastAndSouthAreas_返回东南亚南亚国家` 在瀚高数据库上执行失败。

**错误信息**：
```
错误: 操作符不存在: integer = character varying
建议：没有匹配指定名称和参数类型的函数. 您也许需要增加明确的类型转换.
```

影响文件：`propagation-billboard-common/src/main/java/com/trs/propagation/billboard/manager/AreaManager.java`
涉及方法：`southEastAndSouthAreas()`

## 根因

`parent_id` 列类型为 `integer`，但 MyBatis-Plus `QueryWrapper.in()` 传入了 `String[]` 参数。MySQL 会自动隐式将 `varchar` 转为 `integer` 再比较，瀚高（PostgreSQL）严格遵循 SQL 标准，不会做隐式跨类型转换。

原始代码：
```java
.in("parent_id", "3545,3547".split(","))
```

`"3545,3547".split(",")` 产生 `String[]{"3545", "3547"}`，MyBatis-Plus 将其绑定为 `varchar` 类型参数，导致 `integer IN (varchar, varchar)` 类型冲突。

## 修复动作 / 规避准则

**修复**：
```java
.in("parent_id", 3545, 3547)
```

直接传入 `int` 字面量，MyBatis-Plus 绑定为 `Integer` 类型，类型匹配正确。

**通用规则**：

| 场景 | MySQL 行为 | 瀚高(PostgreSQL) 要求 | 修复模式 |
|---|---|---|---|
| `QueryWrapper.in("int_col", String[])` | 隐式转换 varchar→integer | 报错，拒绝跨类型比较 | 传 `Integer[]` 或 `int` 字面量 |
| `QueryWrapper.eq("int_col", String)` | 同上隐式转换 | 同上报错 | 传 `Integer` 值 |

**排查要点**：在 MyBatis-Plus 的 `QueryWrapper` / `LambdaQueryWrapper` 中，所有 `.in()` / `.eq()` 调用的参数类型必须与数据库列类型一致。尤其注意从字符串 `split()` 得到的数组一定是 `String[]`，不可直接用于 `integer` 列。

## 影响范围

所有在 MyBatis-Plus QueryWrapper 中对 integer 列传入 String 参数的场景，尤其注意代码中通过 `String.split()` 构建 IN 参数的模式。其他 20+ 工程若有类似写法均需同步修改。

## 来源

- 工程：propagation-billboard
- 影响文件：`propagation-billboard-common/src/main/java/com/trs/propagation/billboard/manager/AreaManager.java`
- 涉及方法：`southEastAndSouthAreas()`
- 日期：2026-04-28
- 记录人：吴少辉

## 参考

- 相关 risk：R-020（PG 严格类型检查：隐式转型失效）
