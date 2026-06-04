------------------------------------------------------------------------------------------------------------------------------------------------------------
--增加尾部店降级逻辑
--data_build.dwd_store_construction_manager_tag_weekly_v1_di
with raw_list as(
select 
employee_id
,name 
,store_code 
,store_name
,protect_tag as protect_tag_old
,protect_tag_1_weekly
,case when protect_tag = '钻石' then 0
when protect_tag = '金牌' then 1 
when protect_tag = '银牌' then 2 
when protect_tag = '待观察' then 3 
when protect_tag = '铜牌' then 4 
when protect_tag = '须努力' then 5
else null end as detail_rank 
,case when protect_tag = '钻石' then 'S'
when protect_tag = '金牌' then 'A'
when protect_tag = '银牌' then 'B'
when protect_tag = '待观察' then 'F'
when protect_tag = '铜牌' then 'C'
when protect_tag = '须努力' then 'D'
else null end as final_rank 
,case when protect_tag = '银牌' and total_score >3.4 then '优质银牌'
else protect_tag end as protect_tag_new_old 
,case when protect_tag = '银牌' and total_score >3.4 then 6
when protect_tag = '钻石' then 0
when protect_tag = '金牌' then 1 
when protect_tag = '银牌' then 2 
when protect_tag = '待观察' then 3 
when protect_tag = '铜牌' then 4 
when protect_tag = '须努力' then 5
else null end as detail_new 
,protect_tag_0 -- `本周日维度`
,protect_tag_1 -- `上周日维度`
,protect_tag_1_weekly as protect_tag_1_weekly_2 -- `上周周维度`
,protect_tag_2 -- `w-2周维度`
,total_score -- `本周得分`
,row_number() over(partition by employee_id order by total_score desc) as rn
from data_build.dwd_store_construction_manager_tag_weekly_di 
where dt = '${today-1}'
)

--门店过去30天命中尾部店(T4及以上)天数
--新店长接店原本t值考核豁免7天，规则延用
,opening_days_base as
(select
sale_date as c_date
,shop_code as store_code
,from_unixtime(unix_timestamp(t1.dt,'yyyyMMdd'),'yyyy-MM-dd') as new_dt
from data_build.pdw_idss_mmc_cooperate_shop_open_info_view t1
where t1.dt= '${today-1}'
and shop_type=0
and shop_state=1
and bach_business_time not in ('全天不营业','20:00:00-23:59:59','19:00:00-23:59:59')
and sale_date >= '${TODAY-30}'
and sale_date <= '${TODAY-1}'
)
,t_byday as 
(
select 
t1.shop_id
,t1.alarm_start_date
,t2.start_cdate
,case when t1.alarm_start_date >= t2.start_cdate then 1 else 0 end as is_start_7
,t1.final_level_modify
,substr(t1.final_level_modify,2,1) as final_t_level
from data_shop.dwd_ic_new_import_store_level_da_view t1 
left join data_build.dwd_manager_tag_v1_di t2 on t1.shop_id = t2.store_code and t1.dt = t2.dt
where t1.dt = '${today-1}'
-- and final_level_modify in ('T5','T6') 
 and t1.alarm_start_date >= '${TODAY-30}'
and t1.alarm_start_date <= '${TODAY-1}'
)
,t_final as 
(
select 
shop_id
,count(distinct case when is_start_7 = '1' then alarm_start_date else null end) as total_days --总天数
,count(distinct case when is_start_7 = '1' and final_t_level in ('4','5','6') then alarm_start_date else null end) as end_total_days --命中尾部店天数
from t_byday t1
group by shop_id
)

--当过去30天命中尾部店天数>=18天，在当前基础上降3级
--当过去30天命中尾部店天数>=12天，在当前基础上降2级
--当过去30天命中尾部店天数>=6天，在当前基础上降1级

--钻石
--金牌
--优质银牌
--银牌
--铜牌
--须努力

select
employee_id
,name 
,store_code 
,store_name
,case when t0.protect_tag_old = '钻石' and t1.end_total_days >= '18' then '银牌'
when t0.protect_tag_old = '钻石' and t1.end_total_days >= '12' then '银牌'
when t0.protect_tag_old = '钻石' and t1.end_total_days >= '6' then '金牌'
when t0.protect_tag_old = '金牌' and t1.end_total_days >= '18' then '铜牌'
when t0.protect_tag_old = '金牌' and t1.end_total_days >= '12' then '银牌'
when t0.protect_tag_old = '金牌' and t1.end_total_days >= '6' then '银牌'
when t0.protect_tag_old = '银牌' and total_score >3.4 and t1.end_total_days >= '18' then '须努力'
when t0.protect_tag_old = '银牌' and total_score >3.4 and t1.end_total_days >= '12' then '铜牌'
when t0.protect_tag_old = '银牌' and total_score >3.4 and t1.end_total_days >= '6' then '银牌'
when t0.protect_tag_old = '银牌' and t1.end_total_days >= '18' then '须努力'
when t0.protect_tag_old = '银牌' and t1.end_total_days >= '12' then '须努力'
when t0.protect_tag_old = '银牌' and t1.end_total_days >= '6' then '铜牌'
when t0.protect_tag_old = '铜牌' and t1.end_total_days >= '18' then '须努力'
when t0.protect_tag_old = '铜牌' and t1.end_total_days >= '12' then '须努力'
when t0.protect_tag_old = '铜牌' and t1.end_total_days >= '6' then '须努力'
else t0.protect_tag_old end as protect_tag
,protect_tag_1_weekly
,detail_rank
,final_rank
,case when t0.protect_tag_new_old = '钻石' and t1.end_total_days >= '18' then '银牌'
when t0.protect_tag_new_old = '钻石' and t1.end_total_days >= '12' then '优质银牌'
when t0.protect_tag_new_old = '钻石' and t1.end_total_days >= '6' then '金牌'
when t0.protect_tag_new_old = '金牌' and t1.end_total_days >= '18' then '铜牌'
when t0.protect_tag_new_old = '金牌' and t1.end_total_days >= '12' then '银牌'
when t0.protect_tag_new_old = '金牌' and t1.end_total_days >= '6' then '优质银牌'
when t0.protect_tag_new_old = '优质银牌' and t1.end_total_days >= '18' then '须努力'
when t0.protect_tag_new_old = '优质银牌' and t1.end_total_days >= '12' then '铜牌'
when t0.protect_tag_new_old = '优质银牌' and t1.end_total_days >= '6' then '银牌'
when t0.protect_tag_new_old = '银牌' and t1.end_total_days >= '18' then '须努力'
when t0.protect_tag_new_old = '银牌' and t1.end_total_days >= '12' then '须努力'
when t0.protect_tag_new_old = '银牌' and t1.end_total_days >= '6' then '铜牌'
when t0.protect_tag_new_old = '铜牌' and t1.end_total_days >= '18' then '须努力'
when t0.protect_tag_new_old = '铜牌' and t1.end_total_days >= '12' then '须努力'
when t0.protect_tag_new_old = '铜牌' and t1.end_total_days >= '6' then '须努力'
else t0.protect_tag_new_old end as protect_tag_new
,case when t0.protect_tag_new_old = '钻石' and t1.end_total_days >= '18' then 2
when t0.protect_tag_new_old = '钻石' and t1.end_total_days >= '12' then 6
when t0.protect_tag_new_old = '钻石' and t1.end_total_days >= '6' then 1
when t0.protect_tag_new_old = '金牌' and t1.end_total_days >= '18' then 4
when t0.protect_tag_new_old = '金牌' and t1.end_total_days >= '12' then 2
when t0.protect_tag_new_old = '金牌' and t1.end_total_days >= '6' then 6
when t0.protect_tag_new_old = '优质银牌' and t1.end_total_days >= '18' then 5
when t0.protect_tag_new_old = '优质银牌' and t1.end_total_days >= '12' then 4
when t0.protect_tag_new_old = '优质银牌' and t1.end_total_days >= '6' then 2
when t0.protect_tag_new_old = '银牌' and t1.end_total_days >= '18' then 5
when t0.protect_tag_new_old = '银牌' and t1.end_total_days >= '12' then 5
when t0.protect_tag_new_old = '银牌' and t1.end_total_days >= '6' then 4
when t0.protect_tag_new_old = '铜牌' and t1.end_total_days >= '18' then 5
when t0.protect_tag_new_old = '铜牌' and t1.end_total_days >= '12' then 5
when t0.protect_tag_new_old = '铜牌' and t1.end_total_days >= '6' then 5
else t0.detail_new end as detail_new
,protect_tag_0 --as `本周日维度`
,protect_tag_1 --as `上周日维度`
,protect_tag_1_weekly_2 --as `上周周维度`
,protect_tag_2 --as `w-2周维度`
,total_score --as `本周得分`
,t0.protect_tag_old
,t0.protect_tag_new_old
,t1.end_total_days
from raw_list t0
left join t_final t1 on t0.store_code = t1.shop_id
where t0.rn = 1