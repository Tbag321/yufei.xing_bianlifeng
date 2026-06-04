--月维度连续3个月核心用户数量统计
SELECT
record_month
,store_code
,count(1) as user_num
from
(
SELECT
record_month
,user_id
,store_code
,rn
,rm
,row_number() over(partition by concat(user_id,store_code,rm) order by record_month) as rp
from
(
SELECT
record_month
,user_id
,store_code
,rn
,trunc(add_months(record_month,-rn),'MM') as rm
from
(
SELECT
from_unixtime(unix_timestamp(concat(substr(month_label,1,4),substr(month_label,6,2),'01'),'yyyyMMdd'),'yyyy-MM-dd') as record_month
,user_id
,store_code
,row_number() over(partition by concat(store_code,user_id) order by from_unixtime(unix_timestamp(concat(substr(month_label,1,4),substr(month_label,6,2),'01'),'yyyyMMdd'),'yyyy-MM-dd')) as rn
from data_build.ods_uploads_store_core_user
) a
) b
) c
where c.rp >= '3' --连续3个月
GROUP BY
record_month
,store_code