-- t7门店t值
with base_manager_info as (
        select t0.store_code,
t0.employee_id,
t0.name,
t0.store_name,
t0.city_name,
t0.difficulty_level_new,
t0.entry_date,
t0.entry_days,
t0.change_date0,
t0.cal_days_0,
t0.change_date,
t0.cal_days,
t0.start_cdate,
t0.cal_dyas_14,
t0.change_date_14,
t0.b_manager_date,
t0.b_manager_days,
from_unixtime(unix_timestamp(t0.dt,'yyyyMMdd'),'yyyy-MM-dd') as work_dt
from data_build.dwd_store_construction_manager_base_info_vi_di t0
where t0.dt ='${today-1}' 
)
,opening_days_base as
(select
 sale_date as c_date
 ,case when sale_date >= change_date then 1 else 0 end as is_start
 ,case when sale_date >= start_cdate then 1 else 0 end as is_start_7
 ,weekofyear(sale_date) as week_of_year
 ,date_sub(next_day(sale_date,'mon'),7) as roster_week
 ,shop_code as store_code
 ,from_unixtime(unix_timestamp(t1.dt,'yyyyMMdd'),'yyyy-MM-dd') as new_dt

 from data_build.pdw_idss_mmc_cooperate_shop_open_info_view t1
 left join base_manager_info t2 on t1.shop_code = t2.store_code
 -- left join default.dim_date_ya_v2 t2
   -- on from_unixtime(unix_timestamp(t1.dt,'yyyyMMdd'),'yyyy-MM-dd') = t2.date_key
 where t1.dt= '${today-1}'
 and shop_type=0
 and shop_state=1
 and bach_business_time not in ('全天不营业','20:00:00-23:59:59','19:00:00-23:59:59')
 and sale_date >= '${TODAY-7}'
 and sale_date <= '${TODAY-1}'
 ),
opening_days2 as 
(
select distinct
store_code
,c_date
from opening_days_base 
 where is_start_7 = 1
),
opening_days3 as 
(
select 
store_code
,count(distinct c_date) as opening_days
from opening_days_base 
group by store_code
),
t_byday as 
(
select 
 shop_id
 ,alarm_start_date
 ,case when alarm_start_date >= start_cdate then 1 else 0 end as is_start_7
 ,final_level_modify
 ,substr(final_level_modify,2,1) as final_t_level
from data_shop.dwd_ic_new_import_store_level_da_view t1 
left join base_manager_info t2 on t1.shop_id = t2.store_code
where dt = '${today-1}'
-- and final_level_modify in ('T5','T6') 
 and alarm_start_date >= '${TODAY-7}'
and alarm_start_date <= '${TODAY-1}'
),
t_final_7 as 
(
select 
t1.store_code
,avg(final_t_level) as final_t_level_7

from opening_days2 t1 
left join t_byday t2 on t1.store_code = t2.shop_id
and t1.c_date = t2.alarm_start_date
where t2.is_start_7 = 1
group by t1.store_code
)

select 
employee_id
,emplid
,name
,t1.store_code
,store_name
,city_name
,change_days as `成为本店架构负责人天数`
,work_shift_hours_2 as `t30累计出勤工时`
,delay_task_count_24 as `t30日均24h以上超时任务数`
,attend_ab_cnts as `t30出勤违规次数`
,ab_attend_hours as `t30出勤违规时长`
,b_manager_days as `成为架构负责人天数`
,vo_attendhours as `t30超时打卡小时数`
,work_shift_score as `出勤工时分`
,delay_task_score as `超时任务分`
,ab_attend_score as `出勤违规扣分`
,manager_days_score as `工龄分`
,vo_scores as `义务工时分`
,will_score as `意愿度总分`

,t30_avg_task_time_rate as `工序工时合格率`
,key_task_qualified_hours_rate as `重点工序执行率`
,waste_rate as `t30废弃率`
,t30_avg_check_order_rate as `t30盘点执行率`
,check_diff_per as `t30盘点差异率`
,cash_rate as `t30现金存缴率`
,t30_verification_num_per as `t30发票回收完成率`
,execute_rate as `库存出店执行率`
,task_time_score as `工序合格分`
,key_task_qualified_hours_rate_score as `重点工序执行率得分`
,waste_score as `废弃得分`
,check_score as `盘点得分`
,cash_score as `现金存缴扣分`
,verification_score as `发票回收扣分`
,execute_score as `库存出店扣分`
,performance_score as `个人能力总分`

,final_t_level as `t30门店t值`
,appeal_punish_orderbase_score as `客诉分数`
,result as `品控结果`
,t_score as `t档分数`
,punish_score as `客诉分数扣分`
,result_score as `品控得分加分`
,store_score as `门店质量总分`

,difficulty_level_new as `招聘等级指标`
,good_er2 as `t30好店员工时占比`
,fail_hours_per as `t30失败小时占比`
,sop_finish_per as `t30团队蜂窝SOP学习率`
,good_score as `好店员工时占比得分`
,fail_score as `失败小时占比得分`
,sop_score as `sop学习率加分`
,manage_score as `团队管理总分`

,work_level as `运营难度`
,work_level_score as `运营难度得分`
,total_score as `总分`
--,final_rank as `最终评级`
-- S是钻石，A是金牌，B是银牌，C是铜牌，D是须努力，F是待观察
,case when final_rank='S' THEN '钻石'
when final_rank='A' THEN '金牌'
when final_rank='B' THEN '银牌'
when final_rank='C' THEN '铜牌'
when final_rank='D' THEN '须努力'
when final_rank='F' THEN '待观察'
else null end as `最终评级`
,dt
,final_t_level_7

from data_build.dwd_manager_tag_v1_di t1
left join t_final_7 t2 on t1.store_code = t2.store_code
where dt = '${today-1}'