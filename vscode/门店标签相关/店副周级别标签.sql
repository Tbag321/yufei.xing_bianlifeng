with base_manager_tag as 
(
    select 
    staff_code
    ,protect_tag_detail
    ,case when protect_tag_detail = 0 then '钻石'
    when protect_tag_detail = 1 then '金牌'
    when protect_tag_detail = 2 then '银牌'
    when protect_tag_detail = 4  then '铜牌'
    when protect_tag_detail = 5 then '须努力'
    when protect_tag_detail = 3 then '待观察'
    else null end as protect_tag
    ,dt
    from data_shop.dwd_assi_manager_protect_tag_v1_di
    where dt =date_format(date_sub(next_day(current_date(),'mon'),14),'yyyyMMdd')
),
 base_manager_tag_w1 as 
(
    select 
    staff_code
    ,protect_tag_detail
    ,case when protect_tag_detail = 0 then '钻石'
    when protect_tag_detail = 1 then '金牌'
    when protect_tag_detail = 2 then '银牌'
    when protect_tag_detail = 4  then '铜牌'
    when protect_tag_detail = 5 then '须努力'
    when protect_tag_detail = 3 then '待观察'
    else null end as protect_tag
      ,dt
    from data_shop.dwd_assi_manager_protect_tag_v1_di
    where dt = date_format(date_sub(next_day(current_date(),'mon'),21),'yyyyMMdd')
),
manager_tag_daily as 
(
    select 
    t0.staff_code
    ,t0.store_code
    ,t0.store_name
    ,t0.staff_name
    ,case when t0.protect_tag_detail = 0 then '钻石'
    when t0.protect_tag_detail = 1 then '金牌'
    when t0.protect_tag_detail = 2 then '银牌'
    when t0.protect_tag_detail = 4  then '铜牌'
    when t0.protect_tag_detail = 5 then '须努力'
    when t0.protect_tag_detail = 3 then '待观察'
    else null end as protect_tag
    ,t0.protect_tag_detail
    from data_shop.dwd_assi_manager_protect_tag_v1_di t0 
    where t0.dt ='${today-1}' 
),
blacklist as (
    select distinct 
    employee_no
    ,lpad(employee_no,8,'10') as staff_code
from data_shop.pdw_idss_ipes_admin_employee_blacklist_view -- 全量黑名单表
where dt = '${today-1}' 
    and valid_status=1 
    and start_date <= '${TODAY}'
    and end_date >= '${TODAY}'
)
,final_list as (
select 
t0.staff_code
,t0.staff_name
,t0.store_code
,t0.store_name
-- 黑名单为须努力
,t0.protect_tag
,t1.protect_tag as protect_tag_w1
,t3.protect_tag as protect_tag_w2

,case when t2.staff_code is not null then '须努力'
-- 待观察更新 
when t0.protect_tag = '待观察' then t0.protect_tag
when t1.protect_tag = '待观察' then t0.protect_tag
when t3.protect_tag = '待观察' then t0.protect_tag
when t1.protect_tag is null then t0.protect_tag
-- 须努力变好更新
when t1.protect_tag = '须努力' and t0.protect_tag = '铜牌' then t0.protect_tag
when t1.protect_tag = '须努力' and t0.protect_tag = '银牌' then t0.protect_tag
when t1.protect_tag = '须努力' and t0.protect_tag = '金牌' then t0.protect_tag
when t1.protect_tag = '须努力' and t0.protect_tag = '钻石' then t0.protect_tag
-- 连续2周恶化的更新
when t0.protect_tag_detail > t3.protect_tag_detail and t1.protect_tag_detail > t3.protect_tag_detail then t0.protect_tag
-- 连续2周优化的更新
when t0.protect_tag_detail < t3.protect_tag_detail and t1.protect_tag_detail < t3.protect_tag_detail then t0.protect_tag
-- 其他按照原标签
else coalesce(t3.protect_tag,t1.protect_tag) end as protect_tag_final

from manager_tag_daily t0
left join base_manager_tag t1 on t0.staff_code = t1.staff_code
left join  base_manager_tag_w1 t3 on t0.staff_code = t3.staff_code
left join blacklist t2 on t0.staff_code = t2.staff_code
)
select 
staff_code
,staff_name
,store_code
,store_name
,protect_tag
,protect_tag_w1
,protect_tag_w2
,protect_tag_final
,case when protect_tag_final = '钻石' then 0 
    when protect_tag_final ='金牌' then 1 
    when protect_tag_final ='银牌' then 2 
    when protect_tag_final ='铜牌' then 4  
    when  protect_tag_final ='须努力' then 5 
    when protect_tag_final ='待观察' then 3 
    else null end as protect_tag_detail
from final_list