-- #### 函数mod(text,int)不存在

CREATE OR REPLACE FUNCTION mod(text_val text, mod_val integer)
RETURNS integer AS $$
DECLARE
   num_val integer;
BEGIN
   num_val := text_val::integer;

   RETURN num_val % mod_val;

EXCEPTION
   WHEN invalid_text_representation THEN
       RAISE NOTICE '无法将文本 "%" 转换为整数', text_val;
       RETURN NULL;
   WHEN division_by_zero THEN
       RAISE NOTICE '除数不能为0';
       RETURN NULL;
END;
$$ LANGUAGE plpgsql;



-- #### ifnull函数

CREATE OR REPLACE FUNCTION ifnull(expr1 integer, expr2 integer)
RETURNS integer AS $$
BEGIN
    IF expr1 IS NULL THEN
        RETURN expr2;
    ELSE
        RETURN expr1;
    END IF;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

CREATE OR REPLACE FUNCTION ifnull(expr numeric, def numeric)
  RETURNS numeric AS $BODY$
BEGIN
    IF expr IS NULL THEN
        RETURN def;
    ELSE
        RETURN expr;
    END IF;
END;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;

CREATE OR REPLACE FUNCTION ifnull(expr1 varchar, expr2 varchar)
RETURNS varchar AS $$
BEGIN
    IF expr1 IS NULL THEN
        RETURN expr2;
    ELSE
        RETURN expr1;
    END IF;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

CREATE OR REPLACE FUNCTION ifnull(expr1 text, expr2 text)
RETURNS text AS $$
BEGIN
    IF expr1 IS NULL THEN
        RETURN expr2;
    ELSE
        RETURN expr1;
    END IF;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- #### substring(text, bigint) does not exist

CREATE OR REPLACE FUNCTION "substring"(pi_1 text, pi_2 bigint)
RETURNS text
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN substring(pi_1, pi_2::int);
END;
$$;

-- ### curdate函数不存在

CREATE OR REPLACE FUNCTION curdate()
  RETURNS "pg_catalog"."date" AS $BODY$
BEGIN
     return CURRENT_DATE;
END;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;

-- #### if函数不存在

CREATE OR REPLACE FUNCTION IF(
    condition BOOLEAN,
    true_value DATE,
    false_value DATE
) RETURNS DATE AS $$
BEGIN
    IF condition THEN
        RETURN true_value;
    ELSE
        RETURN false_value;
    END IF;
END;
$$ LANGUAGE plpgsql IMMUTABLE STRICT;

CREATE OR REPLACE FUNCTION IF(
    condition BOOLEAN,
    true_value timestamp with time zone,
    false_value timestamp with time zone
) RETURNS timestamp with time zone AS $$
BEGIN
    IF condition THEN
        RETURN true_value;
    ELSE
        RETURN false_value;
    END IF;
END;
$$ LANGUAGE plpgsql IMMUTABLE STRICT;

CREATE OR REPLACE FUNCTION IF(
    condition BOOLEAN,
    true_value BOOLEAN,
    false_value BOOLEAN
) RETURNS BOOLEAN AS $$
BEGIN
    IF condition THEN
        RETURN true_value;
    ELSE
        RETURN false_value;
    END IF;
END;
$$ LANGUAGE plpgsql IMMUTABLE STRICT;

-- #### date_format函数不存在

CREATE OR REPLACE FUNCTION date_format("date_val" timestamptz, "format_str" text)
  RETURNS "pg_catalog"."text" AS $BODY$
DECLARE
    pg_format text;
BEGIN
    pg_format := format_str;
    pg_format := REPLACE(pg_format, '%Y', 'YYYY');
    pg_format := REPLACE(pg_format, '%y', 'YY');
    pg_format := REPLACE(pg_format, '%m', 'MM');
    pg_format := REPLACE(pg_format, '%c', 'MM');
    pg_format := REPLACE(pg_format, '%M', 'Month');
    pg_format := REPLACE(pg_format, '%b', 'Mon');
    pg_format := REPLACE(pg_format, '%d', 'DD');
    pg_format := REPLACE(pg_format, '%e', 'DD');
    pg_format := REPLACE(pg_format, '%H', 'HH24');
    pg_format := REPLACE(pg_format, '%h', 'HH12');
    pg_format := REPLACE(pg_format, '%I', 'HH12');
    pg_format := REPLACE(pg_format, '%k', 'HH24');
    pg_format := REPLACE(pg_format, '%l', 'HH12');
    pg_format := REPLACE(pg_format, '%i', 'MI');
    pg_format := REPLACE(pg_format, '%s', 'SS');
    pg_format := REPLACE(pg_format, '%S', 'SS');
    pg_format := REPLACE(pg_format, '%p', 'AM');
    pg_format := REPLACE(pg_format, '%W', 'Day');
    pg_format := REPLACE(pg_format, '%a', 'Dy');
    pg_format := REPLACE(pg_format, '%j', 'DDD');
    RETURN TO_CHAR(date_val, pg_format);
END;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;

-- #### year函数不存在

CREATE OR REPLACE FUNCTION year(inDate timestamp with time zone)
  RETURNS "pg_catalog"."int4" AS $BODY$
BEGIN
return date_part('year',inDate);
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;


-- #### month函数不存在

CREATE OR REPLACE FUNCTION MONTH(inDate TIMESTAMP with time zone) RETURNS integer AS
--return month
$$
BEGIN
return date_part('month',inDate);
END;
$$
LANGUAGE plpgsql;


-- ####  find_in_set函数不存在

CREATE OR REPLACE FUNCTION find_in_set(
  target text,
  strlist text
) RETURNS integer AS $$
BEGIN
  IF strlist IS NULL OR strlist = '' THEN
    RETURN 0;
  END IF;
  RETURN coalesce(array_position(string_to_array(strlist, ','), target::text), 0);
END;
$$ LANGUAGE plpgsql IMMUTABLE;


-- #### str_to_date函数不存在

CREATE OR REPLACE FUNCTION str_to_date("create_time" text, "format_pattern" text='%Y-%m-%d %H:%i:%s'::text)
  RETURNS "pg_catalog"."timestamp" AS $BODY$
DECLARE
    pg_format text;
BEGIN
    IF format_pattern IS NULL THEN
        format_pattern := '%Y-%m-%d %H:%i:%s';
    END IF;

    pg_format := format_pattern;

    pg_format := REPLACE(pg_format, '%Y', 'YYYY');
    pg_format := REPLACE(pg_format, '%y', 'YY');

    pg_format := REPLACE(pg_format, '%m', 'MM');
    pg_format := REPLACE(pg_format, '%c', 'MM');
    pg_format := REPLACE(pg_format, '%M', 'Month');
    pg_format := REPLACE(pg_format, '%b', 'Mon');

    pg_format := REPLACE(pg_format, '%d', 'DD');
    pg_format := REPLACE(pg_format, '%e', 'DD');

    pg_format := REPLACE(pg_format, '%H', 'HH24');
    pg_format := REPLACE(pg_format, '%h', 'HH12');
    pg_format := REPLACE(pg_format, '%I', 'HH12');
    pg_format := REPLACE(pg_format, '%k', 'HH24');
    pg_format := REPLACE(pg_format, '%l', 'HH12');

    pg_format := REPLACE(pg_format, '%i', 'MI');

    pg_format := REPLACE(pg_format, '%s', 'SS');
    pg_format := REPLACE(pg_format, '%S', 'SS');

    pg_format := REPLACE(pg_format, '%p', 'AM');

    pg_format := REPLACE(pg_format, '%W', 'Day');
    pg_format := REPLACE(pg_format, '%a', 'Dy');

    pg_format := REPLACE(pg_format, '%j', 'DDD');

    RETURN TO_TIMESTAMP(create_time, pg_format);

EXCEPTION
    WHEN others THEN
        BEGIN
            IF format_pattern = '%Y-%m-%d %H:%i:%s' THEN
                RETURN TO_TIMESTAMP(create_time, 'YYYY-MM-DD HH24:MI:SS');
            ELSIF format_pattern = '%Y-%m-%d' THEN
                RETURN TO_TIMESTAMP(create_time, 'YYYY-MM-DD');
            ELSIF format_pattern = '%Y/%m/%d %H:%i:%s' THEN
                RETURN TO_TIMESTAMP(create_time, 'YYYY/MM/DD HH24:MI:SS');
            ELSE
                RAISE NOTICE '无法解析时间字符串: %, 格式: %', create_time, format_pattern;
                RETURN NULL;
            END IF;
        EXCEPTION
            WHEN others THEN
                RETURN NULL;
        END;
END;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;


-- #### LAST_DAY函数不存在

CREATE OR REPLACE FUNCTION last_day(p_date DATE)
RETURNS DATE AS $$
BEGIN
    RETURN (
        TO_DATE(TO_CHAR(p_date, 'YYYY-MM') || '-01', 'YYYY-MM-DD') +
        INTERVAL '1 MONTH' -
        INTERVAL '1 DAY'
    );
END;
$$ LANGUAGE plpgsql;

-- #### TRUNCATE函数不存在

CREATE OR REPLACE FUNCTION TRUNCATE(p_number NUMERIC, p_decimals INTEGER)
RETURNS NUMERIC AS $$
BEGIN
    RETURN TRUNC(p_number, p_decimals);
END;
$$ LANGUAGE plpgsql IMMUTABLE STRICT;
-- 注意：如果有/号还是需要这样SELECT TRUNCATE(100 / 3::numeric, 2);
-- 不然拿到的值是33.00，而不是33.33


-- #### DAYOFYEAR函数不存在

CREATE OR REPLACE FUNCTION DAYOFYEAR(p_date TIMESTAMP with time zone)
RETURNS INTEGER AS $$
BEGIN
    RETURN EXTRACT(DOY FROM p_date)::INTEGER;
END;
$$ LANGUAGE plpgsql IMMUTABLE STRICT;


-- #### ERROR: function to_days(timestamp without time zone) does not exist

CREATE OR REPLACE FUNCTION to_days(timestamp without time zone)
RETURNS integer AS $$
BEGIN
  RETURN EXTRACT(DAY FROM ($1 - timestamp '0001-01-01 00:00:00'))::integer + 366;
END;
$$ LANGUAGE plpgsql IMMUTABLE STRICT;

CREATE OR REPLACE FUNCTION to_days(date)
RETURNS INTEGER AS $$
SELECT ($1 - '0001-01-01 BC'::date)::int
$$ IMMUTABLE STRICT LANGUAGE SQL;


-- =============================================================
-- 工具包版本标记（per db-migration-toolkit v0.2.0）
-- Pilot 注入后 `SELECT mysql_compat_version()` 确认版本
-- =============================================================
CREATE OR REPLACE FUNCTION mysql_compat_version()
RETURNS text AS $$ SELECT '1.0.0-highgo-v4.1.5-vendor-2026-04-21' $$
LANGUAGE sql IMMUTABLE;

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

-- LAST_INSERT_ID()函数
CREATE OR REPLACE FUNCTION LAST_INSERT_ID()
RETURNS BIGINT AS $$
DECLARE
trigger_value BIGINT;
    lastval_value BIGINT;
BEGIN
    -- 优先检查触发器记录的值
BEGIN
        trigger_value := current_setting('app.last_insert_id', true)::BIGINT;
EXCEPTION WHEN OTHERS THEN
        trigger_value := NULL;
END;

    -- 如果触发器有值，返回触发器记录的值
    IF trigger_value IS NOT NULL THEN
        RETURN trigger_value;
END IF;

    -- 回退到lastval()
BEGIN
RETURN lastval();
EXCEPTION WHEN OTHERS THEN
        RETURN 0;
END;