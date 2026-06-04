--data_shop.app_shop_staff_protect_tag_v2_da

with will_part as (
--汇总意愿度数据
    select distinct
        t1.emplid
        ,t1.staff_code
        ,t1.staff_name
        ,t1.city_name
        ,t1.position_cn
        ,t1.is_store_manager
        ,t1.store_code
        ,t1.store_name
        ,t1.entry_date
        ,t1.t30_attend_hours_after_entry
        ,t1.t30_work_day_cnts_after_entry
        --入职后工作日模拟30天的出勤
        ,t30_workday_attend_hours_after_entry/t30_work_day_cnts_after_entry*30 as mock_workday_t30_attend_hours

        --入职后自然日模拟30天的出勤
        ,case when total_entry_days >= 30 then t30_attend_hours_after_entry
            else t30_attend_hours_after_entry/total_entry_days*30 end as mock_t30_attend_hours

        --除了极特殊情况（入职后60小时全部是非工作日的出勤）用自然日模拟的出勤，其他时候都用工作日模拟的
        ,case when t1.t30_attend_hours_after_entry >= 60
            and (t30_workday_attend_hours_after_entry/t30_work_day_cnts_after_entry*30) = 0
            then (case when total_entry_days >= 30 then t30_attend_hours_after_entry
                else t30_attend_hours_after_entry/total_entry_days*30 end)
            else (t30_workday_attend_hours_after_entry/t30_work_day_cnts_after_entry*30) end as mock_combined_t30_attend_hours
        ,work_day_avail_days/work_day_cnts as workday_avail_rate
        ,cum_attend_hours
        ,case when t1.t30_sop_issue_cnts = 0 or t1.t30_sop_issue_cnts is null then null --如果没有下发sop学习任务则为空
            else round(coalesce(coalesce(t1.t30_sop_finish_cnts,0)/coalesce(t1.t30_sop_issue_cnts,0),0),4) end as sop_learn_rate
        ,case when coalesce(total_day_cnts,0)-coalesce(work_day_cnts,0) = 0 then null --如果没有节假日的可给班则为空
            else (total_avail_days-work_day_avail_days)/(total_day_cnts-work_day_cnts) end as holiday_avail_rate
        ,case when work_day_cnts = 0 or work_day_cnts is null then null --如果没有工作日的可给班则为空
            when work_day_avail_days = 0 or work_day_avail_days is null then 0 --如果工作日可给没给则为0
            else work_day_full_avail_days/work_day_avail_days end as workday_full_avail_rate
        ,case when coalesce(t30_work_shift_hours,0)+coalesce(t30_sum_penalty_roster_hours,0) = 0 then null
            else coalesce((t30_arrive_late_hour+t30_leave_early_hour+t30_absenteeism_hour+t30_sum_penalty_roster_hours)/
                (t30_work_shift_hours+t30_sum_penalty_roster_hours),0) end as ab_hour_rate
        ,t30_ab_leave_arrive_cnts
        ,std_avail_days_rate
        ,cum_attend_hours_after_entry
    from data_shop.dwa_shop_staff_will_v2_da t1
    where t1.dt = '${today-1}'
)

,performance_part as (
--汇总能力数据
    select distinct
        t1.emplid
        ,t7_avg_task_time_rate
        ,round(t30_else_punish_cnts/t30_work_shift_hours*100,3) as t30_else_punish_per_100_hours
        ,round(t30_appeal_punish_cnts/t30_work_shift_hours*100,3) as t30_appeal_punish_per_100_hours
        ,case when t30_avg_task_time_rate>=0.8 then t30_avg_mismatch_ratio else null end as t30_avg_mismatch_ratio
        ,t30_key_task_qualified_hours_rate
        ,t30_sample_punch_cnts -- 随机打卡次数
        ,round(t30_sample_punch_cnts/t30_work_shift_hours*100,3) as t30_sample_punch_per_100_hours
        ,t30_avg_check_order_rate
        --跨店评价
        ,t60_cross_evaluate_cnts
        ,t60_cross_high_skill_cnts / t60_cross_evaluate_cnts as t60_cross_high_skill_rate
        ,t60_cross_work_hard_cnts / t60_cross_evaluate_cnts as t60_cross_work_hard_rate
        ,t60_cross_welcome_cnts / t60_cross_evaluate_cnts as t60_cross_welcome_rate
        ,t60_cross_lazy_cnts / t60_cross_evaluate_cnts as t60_cross_lazy_rate
        ,t60_cross_reject_cnts / t60_cross_evaluate_cnts as t60_cross_reject_rate
    from data_shop.dwa_shop_staff_performance_v2_da t1
    where t1.dt = '${today-1}'
)

,vacation_situation as(  --员工请假情况统计
select
leavepeople
,count(distinct order_id)  as vacation_number  --请假次数
,sum(vacation_time) as vacation_times  --请假总时长
from
(select
t0.order_id --流程编码
,t0.leavepeople --申请员工编码
,t0.diff_start_time --影响班次开始时间
,t0.diff_end_time --影响班次结束时间
,(unix_timestamp(t0.diff_end_time) - unix_timestamp(t0.diff_start_time))/3600 as vacation_time
from data_shop.app_internal_control_vacation_da_view t0
where t0.dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and t0.vacationname = '事假' --请假类型
and reason = '临时身体不适'  --病假
and substr(create_date,1,10) between date_sub(current_date(),30) and date_sub(current_date(),1) --申请时间
group by 
t0.order_id
,t0.leavepeople
,t0.diff_start_time
,t0.diff_end_time
) a
group by
leavepeople
)

--门店运营异常责任人核实 --尾部店工作状态差(028994)
,order_flow_main as(
select
order_id --流程编码(流程信息)
,substr(create_time,1,10) as create_date
,order_status --流程状态(流程信息)
,initiator_code --发起人编码(流程信息)
,create_time --流程发起时间(流程信息)
,flow_ame --流程名称(流程信息)
,org_code --门店编码(流程信息)
,org_name --门店名称(流程信息)
from data_build.pdw_order_store_211_order_detail_flow_main
where dt = date_format(date_sub(current_date,1),'yyyyMMdd')
and flow_code = '028994' --流程code
and flow_ame = '尾部店工作状态差'
and order_status in ('PROCESSING','FINISHED')
),

order_flow_groups as(
select
order_id
,case when form_name = 'finalUsercode' then get_json_object(get_json_object(form_values,'$.[0]'),'$.value') else null end as finalUsercode
from data_build.pdw_order_store_211_order_detail_flow_form_variable_groups_da
where dt = date_format(date_sub(current_date,1),'yyyyMMdd')
and form_name = 'finalUsercode'
--and order_id = '2110160025988320'
),

work_state as(
select
*
from(
select
t0.order_id --流程编码(流程信息)
,t0.create_date
,t0.order_status --流程状态(流程信息)
,t0.initiator_code --发起人编码(流程信息)
,t0.create_time --流程发起时间(流程信息)
,t0.flow_ame --流程名称(流程信息)
,t0.org_code --门店编码(流程信息)
,t0.org_name --门店名称(流程信息)
,lpad(t1.finalUsercode,8,10) as finalUsercode --被惩处人
,row_number() over(partition by lpad(t1.finalUsercode,8,10) order by t0.create_date) as rn --按时间排序，只保留一条数据
from order_flow_main t0
left join order_flow_groups t1 on t0.order_id = t1.order_id
left join will_part t2 on lpad(t1.finalUsercode,8,10) = t2.staff_code
where t0.create_date >= '2024-05-21' --尾部店工作状态差只取21号及以后的
and t0.create_date between date_sub(current_date(),30) and date_sub(current_date(),1) --取过去30天的数据
and t2.position_cn not in ('店经理','店副经理') --只对店员生效
) a
where rn = '1'
)

,main_list as( --历史流程统计
SELECT * 
from data_build.pdw_order_store_211_order_detail_flow_main
where dt = '${today-1}'
and flow_code = '031412' --晋升/接店意愿沟通
)

,result_list as(
select
substr(t1.create_time,1,10) as compute_period --流程发起日期
,t1.order_id --流程编码
,t1.order_status --流程状态
,t1.flow_ame --流程名称
,SUBSTRING(
    t1.flow_ame, 
    LOCATE('(', t1.flow_ame) + 1, 
    LOCATE(')', t1.flow_ame) - LOCATE('(', t1.flow_ame) - 1
  ) AS staff_code --员工编码
,t1.create_time --创建时间
,t2.form_values
,nvl(get_json_object(t2.form_values,'$[0].label'),"未处理") as result --意愿
from main_list t1
left join data_build.pdw_order_store_211_order_detail_flow_form_variable_groups_da t2
on t1.order_id = t2.order_id
and t2.dt = '${today-1}'
and t2.form_name = 'accept'
where substr(t1.create_time,1,10) >= '${TODAY-30}'
)

,refuse_num as( --拒绝晋升次数统计(如果有一次愿意接受，就不再统计拒绝晋升次数)
select
t.staff_code
,count(case when t.compute_period >= '${TODAY-30}' then t.staff_code else null end) as refuse_num_30 --t30拒绝次数
from result_list t
left join
(select
staff_code
from result_list
where result = '愿意接受') t1 on t.staff_code = t1.staff_code
where t1.staff_code is null
group by
t.staff_code
)

,main_vic_list as( --历史流程统计
SELECT * 
from data_build.pdw_order_store_211_order_detail_flow_main
where dt = '${today-1}'
and flow_code = '032042' --晋升店副意愿沟通
)

,result_vic_list as(
select
substr(t1.create_time,1,10) as compute_period --流程发起日期
,t1.order_id --流程编码
,t1.order_status --流程状态
,t1.flow_ame --流程名称
,SUBSTRING(
    t1.flow_ame, 
    LOCATE('(', t1.flow_ame) + 1, 
    LOCATE(')', t1.flow_ame) - LOCATE('(', t1.flow_ame) - 1
  ) AS staff_code --员工编码
,t1.create_time --创建时间
,t2.form_values
,nvl(get_json_object(t2.form_values,'$[0].label'),"未处理") as result --意愿
from main_list t1
left join data_build.pdw_order_store_211_order_detail_flow_form_variable_groups_da t2
on t1.order_id = t2.order_id
and t2.dt = '${today-1}'
and t2.form_name = 'accept'
where substr(t1.create_time,1,10) >= '${TODAY-30}'
)

,refuse_vic_num as( --拒绝晋升次数统计(如果有一次愿意接受，就不再统计拒绝晋升次数)
select
t.staff_code
,count(case when t.compute_period >= '${TODAY-30}' then t.staff_code else null end) as refuse_num_30 --t30拒绝次数
from result_list t
left join
(select
staff_code
from result_list
where result = '愿意接受') t1 on t.staff_code = t1.staff_code
where t1.staff_code is null
group by
t.staff_code
)

,manager_transfer_blacklist as(
select distinct
lpad(staff_code,8,10) as staff_code
from data_shop.dwd_manager_transfer_blacklist_v1_di
where dt = '${today-1}'
)

,prep_info as (
--计算标签前准备：
--所有_score后缀的均为该指标的得分
--所有_check后缀的均为该指标是否有效的判断
    select distinct
        --基础信息
        t1.emplid
        ,t1.staff_code
        ,t1.staff_name
        ,t1.city_name
        ,t1.position_cn
        ,t1.is_store_manager
        ,t1.store_code
        ,t1.store_name
        ,t1.entry_date
        ,t1.t30_attend_hours_after_entry
        ,t1.cum_attend_hours_after_entry

        --意愿
        ,t1.mock_workday_t30_attend_hours
        ,t1.mock_t30_attend_hours
        ,t1.mock_combined_t30_attend_hours
        ,t1.workday_avail_rate
        ,t1.cum_attend_hours
        ,t1.sop_learn_rate
        ,t1.holiday_avail_rate
        ,t1.workday_full_avail_rate
        ,t1.ab_hour_rate
        ,t1.t30_ab_leave_arrive_cnts
        ,t1.std_avail_days_rate

        --能力
        ,t2.t7_avg_task_time_rate
        ,coalesce(t2.t30_else_punish_per_100_hours,0) as t30_else_punish_per_100_hours
        ,coalesce(t2.t30_appeal_punish_per_100_hours,0) as t30_appeal_punish_per_100_hours
        ,t2.t30_avg_mismatch_ratio
        ,coalesce(t2.t30_sample_punch_per_100_hours,0) as t30_sample_punch_per_100_hours
        ,round(t2.t30_sample_punch_cnts,0) as t30_sample_punch_cnts
        ,t2.t30_avg_check_order_rate
        ,t2.t60_cross_evaluate_cnts
        ,t2.t60_cross_high_skill_rate
        ,t2.t60_cross_work_hard_rate
        ,t2.t60_cross_welcome_rate
        ,t2.t60_cross_lazy_rate
        ,t2.t60_cross_reject_rate

        --意愿得分
        --基础分
        ,case
            when round(t1.mock_combined_t30_attend_hours,0) >= 300 then 1
            when round(t1.mock_combined_t30_attend_hours,0) >= 250 then 2
            when round(t1.mock_combined_t30_attend_hours,0) >= 150 then 3
        else 4 end as t30_attend_hours_score
        ,case
            when t1.workday_avail_rate >= 0.93 then 1
            when t1.workday_avail_rate >= 0.78 then 2
            when t1.workday_avail_rate >= 0.38 then 3
        else 4 end as workday_avail_score --0813改标准，因为改为未来四周给班，标准下调2%
        --加分
        ,case
            when t1.cum_attend_hours >= 1500 then 4
            when t1.cum_attend_hours >= 600 then 3
            when t1.cum_attend_hours >= 200 then 2
        else 1 end as cum_attend_score
        ,case
            when t1.sop_learn_rate >= 0.95 then 4
            when t1.sop_learn_rate >= 0.75 then 3
            when t1.sop_learn_rate >= 0.6 then 2
            when t1.sop_learn_rate >= 0.5 then 1
        else 0 end as sop_learn_score
        ,case when t1.sop_learn_rate is not null then 4 else 0 end as sop_check
        ,case
            when t1.holiday_avail_rate >= 1 then 4
            when t1.holiday_avail_rate >= 0.9 then 3
            when t1.holiday_avail_rate >= 0.85 then 2
            when t1.holiday_avail_rate >= 0.8 then 1
        else 0 end as holiday_avail_score
        ,case when t1.holiday_avail_rate is not null then 4 else 0 end as holiday_check
        ,case
            when t1.workday_full_avail_rate >= 1 then 4
            when t1.workday_full_avail_rate >= 0.95 then 3
            when t1.workday_full_avail_rate >= 0.9 then 2
            when t1.workday_full_avail_rate >= 0.7 then 1
        else 0 end as workday_full_avail_score
        ,case when t1.workday_full_avail_rate is not null then 4 else 0 end as workday_check
        --减分
        ,case
            when t1.ab_hour_rate >= 0.03 then 4
            when t1.ab_hour_rate >= 0.01 then 3
            when t1.ab_hour_rate >= 0.005 then 2
            when t1.ab_hour_rate > 0 then 1
        else 0 end as ab_hour_score
        ,case when t1.ab_hour_rate is not null then 4 else 0 end as ab_hour_check
        ,case
            when t1.t30_ab_leave_arrive_cnts >= 4 then 4
            when t1.t30_ab_leave_arrive_cnts >= 3 then 3
            when t1.t30_ab_leave_arrive_cnts >= 2 then 2
            when t1.t30_ab_leave_arrive_cnts > 0 then 1
        else 0 end as ab_attend_score
        ,case when t1.t30_ab_leave_arrive_cnts >= 0 and t1.t30_attend_hours_after_entry > 0 then 4 else 0 end as t30_ab_attend_check
        ,case
            when t1.std_avail_days_rate >= 0.45 then 4
            when t1.std_avail_days_rate >= 0.40 then 3
            when t1.std_avail_days_rate >= 0.35 then 2
            when t1.std_avail_days_rate >= 0.25 then 1
        else 0 end as std_avail_days_score --0813改标准，因为改为未来四周给班，标准上调5%
        ,case when t1.std_avail_days_rate >= 0 then 4 else 0 end as std_avail_check

        --能力得分
        --基础分
        ,case
            when t2.t7_avg_task_time_rate >= 0.95 then 1
            when t2.t7_avg_task_time_rate >= 0.9 then 2
            when t2.t7_avg_task_time_rate >= 0.8 then 3
            when t2.t7_avg_task_time_rate >= 0 then 4
        end as t7_avg_task_time_score
        ,case
            when t2.t30_else_punish_per_100_hours > 2.4 then 4
            when t2.t30_else_punish_per_100_hours > 1.6 then 3
            when t2.t30_else_punish_per_100_hours > 0.8 then 2
            when t2.t30_else_punish_per_100_hours >= 0 then 1
        end as t30_else_punish_score
        --减分
        ,case
            when t2.t30_sample_punch_per_100_hours >0 then 4
        end as t30_sample_punch_score
        ,case when t2.t30_sample_punch_cnts = 1 then 1
        when t2.t30_sample_punch_cnts in (2,3) then 2
        when t2.t30_sample_punch_cnts > 3 then 3
        end as t30_sample_punch_cnts_score
        ,case
            when t2.t30_avg_mismatch_ratio >= 0.25 then 4
            when t2.t30_avg_mismatch_ratio >= 0.1 then 3
            when t2.t30_avg_mismatch_ratio >= 0.05 then 2
            when t2.t30_avg_mismatch_ratio > 0 then 1
        else 0 end as t30_avg_mismatch_ratio_score
        ,case when t2.t30_key_task_qualified_hours_rate < 0.9 then 4 
        when t30_key_task_qualified_hours_rate < 0.95 then 2 
        else 0 end as t30_key_task_qualified_hours_rate_score
        -- 0830新增
        ,case when t2.t30_avg_mismatch_ratio >= 0 and t1.t30_attend_hours_after_entry > 0 then 4 else 0 end as mismatch_ratio_check
        ,case when t2.t30_key_task_qualified_hours_rate >=0 then 4 else 0 end as key_task_qualified_hours_rate_check
        ,case
            when t2.t30_appeal_punish_per_100_hours >= 1 then 4
            when t2.t30_appeal_punish_per_100_hours >= 0.5 then 3
            when t2.t30_appeal_punish_per_100_hours >= 0.3 then 2
            when t2.t30_appeal_punish_per_100_hours > 0 then 1
        else 0 end as t30_appeal_punish_score
        ,case when t2.t30_appeal_punish_per_100_hours >= 0 and t1.t30_attend_hours_after_entry > 0 then 4 else 0 end as appeal_check
        ,case
            when t2.t30_avg_check_order_rate >= 0.95 then 0
            when t2.t30_avg_check_order_rate >= 0.9 then 1
            when t2.t30_avg_check_order_rate >= 0.75 then 2
            when t2.t30_avg_check_order_rate >= 0.7 then 3
            when t2.t30_avg_check_order_rate >= 0 then 4
        end as t30_avg_check_order_score
        ,case when t2.t30_avg_check_order_rate >= 0 and t1.t30_attend_hours_after_entry > 0 then 4 else 0 end as check_order_check
        
        ,case when t60_cross_evaluate_cnts >=3 
            and t60_cross_high_skill_rate >=0.75 
            and t60_cross_work_hard_rate >=0.75 
            and t60_cross_welcome_rate >=0.75 then 4 end as cross_eval_good_score
        ,case when t60_cross_evaluate_cnts >=3 then 4 else 0 end as cross_eval_check
        --加分
        ,case when t60_cross_evaluate_cnts >=3 
            and (t60_cross_lazy_rate >= 0.5 or t60_cross_reject_rate >= 0.5) then 4 end as cross_eval_bad_score
        --0424新增
        ,case when vacation_number >= 5 then 1.5 else 0 end as vacation_score
        --1219新增晋升黑名单员工减分
        ,case when t4.staff_code is not null then 0.75 else 0 end as manager_transfer_blacklist_score
        --0519新增拒绝晋升店长店副员工减分
        ,case when t5.refuse_num_30 > 0 or t6.refuse_num_30 > 0 then 1 else 0 end as refuse_promotion_score

    from will_part t1
    left join performance_part t2
    on t1.emplid = t2.emplid
    left join vacation_situation t3
    on t1.emplid = t3.leavepeople
    left join manager_transfer_blacklist t4
    on lpad(t1.emplid,8,10) = t4.staff_code
    left join refuse_num t5
    on lpad(t1.emplid,8,10) = t5.staff_code
    left join refuse_vic_num t6
    on lpad(t1.emplid,8,10) = t6.staff_code
)

--通过基础分/加分/减分，按照阈值规则计算保护标签
select
    tmp.emplid
    ,tmp.staff_code
    ,tmp.staff_name
    ,tmp.city_name
    ,tmp.position_cn
    ,tmp.is_store_manager
    ,tmp.store_code
    ,tmp.store_name
    ,tmp.entry_date
    ,tmp.t30_attend_hours_after_entry
    ,tmp.cum_attend_hours_after_entry

    ,tmp.mock_workday_t30_attend_hours
    ,tmp.mock_t30_attend_hours
    ,tmp.mock_combined_t30_attend_hours
    ,tmp.workday_avail_rate
    ,tmp.cum_attend_hours
    ,tmp.sop_learn_rate
    ,tmp.holiday_avail_rate
    ,tmp.workday_full_avail_rate
    ,tmp.ab_hour_rate
    ,tmp.t30_ab_leave_arrive_cnts
    ,tmp.std_avail_days_rate

    ,tmp.t7_avg_task_time_rate
    ,tmp.t30_else_punish_per_100_hours
    ,tmp.t30_appeal_punish_per_100_hours
    ,tmp.t30_avg_mismatch_ratio
    ,tmp.t30_sample_punch_per_100_hours
    ,tmp.t30_avg_check_order_rate

    ,tmp.t30_attend_hours_score
    ,tmp.workday_avail_score
    ,tmp.cum_attend_score
    ,tmp.sop_learn_score
    ,tmp.holiday_avail_score
    ,tmp.workday_full_avail_score
    ,tmp.ab_hour_score
    ,tmp.ab_attend_score
    ,tmp.std_avail_days_score
    ,tmp.sop_check
    ,tmp.holiday_check
    ,tmp.workday_check
    ,tmp.ab_hour_check
    ,tmp.t30_ab_attend_check
    ,tmp.std_avail_check

    ,tmp.t7_avg_task_time_score
    ,tmp.t30_else_punish_score
    ,tmp.t30_sample_punch_score
    ,tmp.t30_avg_mismatch_ratio_score
    
    ,tmp.t30_appeal_punish_score
    ,tmp.t30_avg_check_order_score
    ,tmp.mismatch_ratio_check
    
    ,tmp.appeal_check
    ,tmp.check_order_check

    ,tmp.will_base
    ,tmp.will_up
    ,tmp.will_down
    ,tmp.perfm_base
    ,tmp.perfm_down

    --,tmp.vacation_score

    ,round(coalesce(will_base,0)-coalesce(will_up,0)+coalesce(will_down,0),1) +
        --如果能力的基础分和加减分都是null，则default给3分
        --如果加减分任意一个不为null但基础分为null，则default给2.4分
        round(coalesce(perfm_base,(case when perfm_down is null and perfm_up is null then 3 else 2.4 end)) +
            coalesce(perfm_down,0)-coalesce(perfm_up,0),1) + vacation_score + manager_transfer_blacklist_score + refuse_promotion_score as protect_tag_raw
    ,case when cum_attend_hours_after_entry < 60 and t1.finalUsercode is null then 3
          when cum_attend_hours_after_entry < 60 and t1.finalUsercode is not null then 3 + 1
        else (case when round(coalesce(will_base,0)-coalesce(will_up,0)+coalesce(will_down,0),1) +
                round(coalesce(perfm_base,(case when perfm_down is null and perfm_up is null then 3 else 2.4 end)) +
                    coalesce(perfm_down,0)-coalesce(perfm_up,0),1) + vacation_score + manager_transfer_blacklist_score + refuse_promotion_score < 3.5 and t1.finalUsercode is null then 1
                   when round(coalesce(will_base,0)-coalesce(will_up,0)+coalesce(will_down,0),1) +
                round(coalesce(perfm_base,(case when perfm_down is null and perfm_up is null then 3 else 2.4 end)) +
                    coalesce(perfm_down,0)-coalesce(perfm_up,0),1) + vacation_score + manager_transfer_blacklist_score + refuse_promotion_score < 3.5 and t1.finalUsercode is not null then 1 + 3
            when round(coalesce(will_base,0)-coalesce(will_up,0)+coalesce(will_down,0),1) +
                round(coalesce(perfm_base,(case when perfm_down is null and perfm_up is null then 3 else 2.4 end)) +
                    coalesce(perfm_down,0)-coalesce(perfm_up,0),1) + vacation_score + manager_transfer_blacklist_score + refuse_promotion_score < 5.5 and t1.finalUsercode is null then 2
                   when round(coalesce(will_base,0)-coalesce(will_up,0)+coalesce(will_down,0),1) +
                round(coalesce(perfm_base,(case when perfm_down is null and perfm_up is null then 3 else 2.4 end)) +
                    coalesce(perfm_down,0)-coalesce(perfm_up,0),1) + vacation_score + manager_transfer_blacklist_score + refuse_promotion_score < 5.5 and t1.finalUsercode is not null then 2 + 2
            when round(coalesce(will_base,0)-coalesce(will_up,0)+coalesce(will_down,0),1) +
                round(coalesce(perfm_base,(case when perfm_down is null and perfm_up is null then 3 else 2.4 end)) +
                    coalesce(perfm_down,0)-coalesce(perfm_up,0),1) + vacation_score + manager_transfer_blacklist_score + refuse_promotion_score < 7.5 and t1.finalUsercode is null then 4 else 5 end)
    end as protect_tag_detail

    ,tmp.perfm_up
    ,tmp.cross_eval_good_score
    ,tmp.cross_eval_bad_score
    ,tmp.cross_eval_check
    ,tmp.t30_key_task_qualified_hours_rate_score
    ,tmp.key_task_qualified_hours_rate_check
from (
--汇总出意愿度和能力的基础分/加分/减分
    select
        t1.emplid
        ,t1.staff_code
        ,t1.staff_name
        ,t1.city_name
        ,t1.position_cn
        ,t1.is_store_manager
        ,t1.store_code
        ,t1.store_name
        ,t1.entry_date
        ,t1.t30_attend_hours_after_entry
        ,t1.cum_attend_hours_after_entry

        ,t1.mock_workday_t30_attend_hours
        ,t1.mock_t30_attend_hours
        ,t1.mock_combined_t30_attend_hours
        ,t1.workday_avail_rate
        ,t1.cum_attend_hours
        ,t1.sop_learn_rate
        ,t1.holiday_avail_rate
        ,t1.workday_full_avail_rate
        ,t1.ab_hour_rate
        ,t1.t30_ab_leave_arrive_cnts
        ,t1.std_avail_days_rate

        ,t1.t7_avg_task_time_rate
        ,t1.t30_else_punish_per_100_hours
        ,t1.t30_appeal_punish_per_100_hours
        ,t1.t30_avg_mismatch_ratio
        ,t1.t30_sample_punch_per_100_hours
        ,t1.t30_avg_check_order_rate

        ,t1.t30_attend_hours_score
        ,t1.workday_avail_score
        ,t1.cum_attend_score
        ,t1.sop_learn_score
        ,t1.holiday_avail_score
        ,t1.workday_full_avail_score
        ,t1.ab_hour_score
        ,t1.ab_attend_score
        ,t1.std_avail_days_score
        ,t1.sop_check
        ,t1.holiday_check
        ,t1.workday_check
        ,t1.ab_hour_check
        ,t1.t30_ab_attend_check
        ,t1.std_avail_check

        ,t1.t7_avg_task_time_score
        ,t1.t30_else_punish_score
        ,t1.t30_sample_punch_score
        ,t1.t30_avg_mismatch_ratio_score
        ,t1.t30_key_task_qualified_hours_rate_score
        ,t1.t30_appeal_punish_score
        ,t1.t30_avg_check_order_score
        ,t1.mismatch_ratio_check
        ,t1.key_task_qualified_hours_rate_check
        ,t1.appeal_check
        ,t1.check_order_check
        ,t1.vacation_score
        ,t1.manager_transfer_blacklist_score
        ,t1.refuse_promotion_score

        ,0.5 * coalesce(t1.t30_attend_hours_score,0) + 0.5 * coalesce(t1.workday_avail_score,0) as will_base --基础分
        ,coalesce(t1.cum_attend_score,0)/3.2 + --0723调整，取消SOP学习率得分，增加累计出勤工时得分
            (--coalesce(t1.sop_learn_score,0) + 
            coalesce(t1.holiday_avail_score,0) + coalesce(t1.workday_full_avail_score,0))/
                (--coalesce(t1.sop_check,0) + 
                coalesce(t1.holiday_check,0) + coalesce(t1.workday_check,0)) as will_up --加分
        ,(coalesce(t1.ab_hour_score,0) + coalesce(t1.ab_attend_score,0) + coalesce(t1.std_avail_days_score,0))/
            (coalesce(ab_hour_check,0) + coalesce(t30_ab_attend_check,0) + coalesce(std_avail_check,0)) as will_down --减分

        ,case when t1.t30_else_punish_score is null and t1.t7_avg_task_time_score is null then null
            when t1.t7_avg_task_time_score is null then t1.t30_else_punish_score
            when t1.t30_else_punish_score is null then t1.t7_avg_task_time_score
            else 0.7 * t1.t30_else_punish_score + 0.3 * t1.t7_avg_task_time_score end as perfm_base
        ,case when t30_sample_punch_score is null and t30_key_task_qualified_hours_rate_score is null
            and t30_appeal_punish_score is null and t30_avg_check_order_score is null 
            and cross_eval_bad_score is null then null
        else (coalesce(t30_sample_punch_cnts_score,0) +
            (coalesce(t30_key_task_qualified_hours_rate_score,0) + coalesce(t30_appeal_punish_score,0) + coalesce(t30_avg_check_order_score,0) + coalesce(t1.cross_eval_bad_score,0))/
                (coalesce(key_task_qualified_hours_rate_check,0) + coalesce(appeal_check,0) + coalesce(check_order_check,0) + coalesce(t1.cross_eval_check,0))) 
                end as perfm_down
        ,case when t1.cross_eval_good_score = 4 then 1 end as perfm_up

        ,t1.cross_eval_good_score
        ,t1.cross_eval_bad_score
        ,t1.cross_eval_check
    from prep_info t1
) tmp
left join work_state t1 on tmp.staff_code = t1.finalUsercode