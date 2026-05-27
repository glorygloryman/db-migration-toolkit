# 瀚高数据库 BIT 类型兼容性问题 - 快速解决指南

**用途**: MySQL → 瀚高数据库迁移时 BIT 类型字段兼容性问题速查
**版本**: v1.0
**更新**: 2026-05-25

---

## 🚨 问题快速识别

### 错误信息特征

```
错误：字段 "xxx" 数据类型为 bit, 表达式数据类型为 boolean/integ
建议：需要显式写出转换表达式
```

### 影响范围

- 所有使用 `Boolean` 类型对应数据库 `BIT` 字段的场景
- 主要影响：INSERT、UPDATE 操作

---

## ⚡ 3分钟快速解决方案

### 步骤1：在瀚高数据库中执行以下 SQL（1分钟）

```sql
-- 连接到目标数据库
\c <数据库名>

-- 清理旧配置（如果存在）
DROP FUNCTION IF EXISTS public.boolean_to_bit(boolean) CASCADE;
DROP CAST IF EXISTS (boolean AS bit);

-- 创建转换函数（关键：使用位串字面量）
CREATE OR REPLACE FUNCTION public.boolean_to_bit(boolean)
RETURNS bit AS $$
    SELECT CASE
        WHEN $1 = TRUE THEN B'1'::bit
        ELSE B'0'::bit
    END;
$$ LANGUAGE SQL IMMUTABLE STRICT;

-- 创建隐式转换（关键：必须是 IMPLICIT）
CREATE CAST (boolean AS bit)
WITH FUNCTION public.boolean_to_bit(boolean)
AS IMPLICIT;
```

**验证**：
```sql
SELECT TRUE::BIT;   -- 应返回 B'1'
SELECT FALSE::BIT;  -- 应返回 B'0'
```

---

### 步骤2：检查应用层配置（1分钟）

#### ✅ 正确配置

```xml
<!-- ResultMap -->
<result column="is_xxx" jdbcType="BIT" property="isXxx" />

<!-- INSERT/UPDATE -->
#{isXxx,jdbcType=BIT}
```

```java
// Java 实体类
private Boolean isXxx;  // 使用 Boolean 类型
```

#### ❌ 错误配置

```xml
<!-- 错误1：使用 TypeHandler 转换为 Integer -->
#{isXxx,jdbcType=INTEGER,typeHandler=xxx.BooleanToIntegerTypeHandler}

<!-- 错误2：使用错误的 jdbcType -->
#{isXxx,jdbcType=BOOLEAN}
#{isXxx,jdbcType=TINYINT}
```

---

### 步骤3：验证测试（1分钟）

```bash
# 运行包含 BIT 字段的 DAO 测试
mvn test -Dtest=<XXX>DAOTest -Dspring.profiles.active=integration-highgo

# 预期结果
Tests run: X, Failures: 0, Errors: 0, Skipped: 0
BUILD SUCCESS
```

---

## 🔍 根本原因

### MySQL vs 瀚高 BIT 类型差异

| 数据库 | BIT(1) 实际类型 | 接受值类型 | 隐式转换 |
|--------|-----------------|-----------|----------|
| **MySQL** | TINYINT(1) | Integer, Boolean | ✅ 支持 |
| **瀚高** | 位串 (BIT STRING) | 位串字面量 (B'1', B'0') | ❌ 不支持，需手动配置 |

### 为什么 TypeHandler 方案失败？

```java
// TypeHandler 将 Boolean 转换为 Integer(0/1)
ps.setInt(i, parameter ? 1 : 0);

// 瀚高 BIT 字段不接受 Integer 值
// 错误：字段数据类型为 bit, 表达式数据类型为 integer
```

**正确方式**：直接传递 Boolean，让数据库层转换

---

## 📋 完整检查清单

### 数据库层（瀚高技术人员）

- [ ] 连接到正确的数据库
- [ ] 清理旧的函数和 CAST
- [ ] 创建转换函数（使用 `B'1'::bit` 语法）
- [ ] 创建隐式转换（使用 `AS IMPLICIT`）
- [ ] 验证函数工作：`SELECT TRUE::BIT;`
- [ ] 验证 CAST 配置：查询 `pg_cast` 视图

### 应用层（开发人员）

- [ ] ResultMap 使用 `jdbcType="BIT"`
- [ ] INSERT/UPDATE 使用 `jdbcType=BIT`
- [ ] 移除 TypeHandler（如果使用了）
- [ ] Java 实体类使用 `Boolean` 类型
- [ ] 运行集成测试验证

---

## 🛠️ 故障排查

### 问题1：函数已存在但仍然报错

**检查**：
```sql
SELECT proname, prorettype::regtype, proargtypes::regtype[]
FROM pg_proc
WHERE proname = 'boolean_to_bit';
```

**解决**：
```sql
-- 删除旧函数
DROP FUNCTION IF EXISTS public.boolean_to_bit(boolean);

-- 重新创建（使用位串字面量）
CREATE OR REPLACE FUNCTION public.boolean_to_bit(boolean)
RETURNS bit AS $$
    SELECT CASE WHEN $1=TRUE THEN B'1'::bit ELSE B'0'::bit END;
$$ LANGUAGE SQL IMMUTABLE STRICT;
```

---

### 问题2：CAST 创建成功但不是隐式转换

**检查**：
```sql
SELECT castsource::regtype, casttarget::regtype, castcontext
FROM pg_cast
WHERE castsource = 'boolean'::regtype AND casttarget = 'bit'::regtype;
```

**预期结果**：`castcontext` 应该是 `i` (implicit)

**如果不是**：
```sql
-- 删除旧 CAST
DROP CAST IF EXISTS (boolean AS bit);

-- 重新创建为隐式转换
CREATE CAST (boolean AS bit)
WITH FUNCTION public.boolean_to_bit(boolean)
AS IMPLICIT;
```

---

### 问题3：应用层配置正确但测试仍失败

**可能原因**：MyBatis 缓存了旧的 Mapper XML

**解决**：
```bash
# 清理并重新编译
mvn clean test -Dtest=<XXX>DAOTest -Dspring.profiles.active=integration-highgo
```

---

## 📌 关键要点速记

### ✅ DO（正确做法）

1. **数据库层**：使用位串字面量 `B'1'::bit`, `B'0'::bit`
2. **应用层**：使用 `jdbcType=BIT`
3. **CAST 配置**：必须标记为 `AS IMPLICIT`
4. **函数位置**：创建在 `public` schema 中

### ❌ DON'T（错误做法）

1. ❌ 不要使用 TypeHandler 转换为 Integer
2. ❌ 不要使用 `jdbcType=INTEGER`
3. ❌ 不要使用整数 `1::bit`, `0::bit`
4. ❌ 不要使用 `AS EXPLICIT` 或 `AS ASSIGNMENT`

---

## 📚 相关命令速查

### 查找所有 BIT 字段

```sql
SELECT table_name, column_name, data_type
FROM information_schema.columns
WHERE data_type = 'bit'
AND table_schema = '<schema名>';
```

### 查看所有 CAST 配置

```sql
SELECT
    castsource::regtype AS source,
    casttarget::regtype AS target,
    castfunc::regproc AS function,
    castcontext AS context
FROM pg_cast
WHERE castsource = 'boolean'::regtype
   OR casttarget = 'bit'::regtype
ORDER BY castsource, casttarget;
```

### 测试转换函数

```sql
-- 直接测试函数
SELECT public.boolean_to_bit(TRUE);
SELECT public.boolean_to_bit(FALSE);

-- 测试隐式转换
SELECT TRUE::BIT;
SELECT FALSE::BIT;

-- 测试实际插入
CREATE TEMP TABLE test_bit (id INT, flag BIT);
INSERT INTO test_bit VALUES (1, TRUE), (2, FALSE);
SELECT * FROM test_bit;
```

---

## 🔗 相关文档

- **详细问题分析**: `HIGHGO-BIT-TYPE-ISSUE.md`
- **诊断指南**: `HIGHGO-CAST-TROUBLESHOOTING.md`
- **完整解决方案**: `BIT-TYPE-SOLUTION-SUMMARY.md`

---

## 📞 联系人

- **数据库问题**: 瀚高技术人员
- **应用层问题**: 开发团队

---

**快速参考** | **下次遇到类似问题时，直接从"3分钟快速解决方案"开始执行**
