with base_list as(
SELECT
concat(month_label,"-01") as month
,store_code
,user_id
from data_build.ods_uploads_store_core_user
),

three_list as(
select
t1.month
,t1.store_code
,t1.user_id as t1_user_id
,t2.user_id as t2_user_id--上月核心
,t3.user_id as t3_user_id--上上月核心
from base_list t1
left join base_list t2 on t1.store_code = t2.store_code and t1.user_id = t2.user_id and t1.month = add_months(t2.month,1)
left join base_list t3 on t1.store_code = t3.store_code and t1.user_id = t3.user_id and t1.month = add_months(t3.month,2)
),

final_list as(
select
month
,store_code
,case when t1_user_id is not null and t2_user_id is not null and t3_user_id is not null then 1 else 0 end as con
from three_list
)

select
month
,store_code
,sum(con) as core_num
from final_list
group by
month
,store_code