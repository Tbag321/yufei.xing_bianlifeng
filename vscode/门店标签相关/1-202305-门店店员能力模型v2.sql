--data_shop.dwa_shop_staff_performance_v2_da

with work_reference as (
--判断每一天是否是工作日
    select distinct
        date_key
        ,day_of_week
        ,case when day_of_week in ('6','7')
            and holiday_type = '2' then '1'
            else is_working_day end as is_work_day
    from data_shop.dim_date_ya_v2_view
)

,cum_attend_info as ( --part1.熟练度类型
    select
        employee_no
        ,sum(attendance_work_hours) as cum_attend_hours
        -- ,sum(is_night_shift) as night_shift_cnts
        -- ,sum(is_weekend_shift) as weekend_shift_cnts
        -- ,sum(is_long_shift) as long_shift_cnts
        ,sum(case when date_format(attend_date,'yyyyMMdd') >= '${today-30}' then work_shift_hours end) as t30_work_shift_hours
    from (
        select distinct
            t1.employee_no
            ,t1.work_shift_id
            ,date_format(t1.work_shift_date, 'yyyy-MM-dd') as attend_date
            -- ,case when date_format(t1.work_shift_date,'yyyyMMdd') >= date_format(t2.hps_hire_dt,'yyyyMMdd') then '1' else '0' end as is_latest_entry
            ,t1.attendance_work_hours
            ,t1.work_shift_hours
            -- ,case
            --     when to_date(nvl(attendance_start_time,punch_start_time))<>to_date(nvl(attendance_end_time,punch_end_time)) then '1'
            --     when to_date(nvl(attendance_start_time,punch_start_time))<>work_shift_date then '1'
            --     else '0'
            -- end as is_night_shift
            -- ,case when t3.day_of_week in ('6','7') then '1' else '0' end as is_weekend_shift
            -- ,case when t1.attendance_work_hours >= 8 then '1' else '0' end as is_long_shift
        from data_shop.pdw_opc_shop_attendance_report_work_shift_view t1
        inner join data_shop.pdw_psprod_ps_blf_ehr_pers_vw_view t2
        on t1.employee_no = t2.emplid and t2.dt = '${today-1}'
        left join work_reference t3
        on date_format(t1.work_shift_date, 'yyyy-MM-dd') = t3.date_key
        where t1.dt = '${today-1}'
            and t1.work_shift_type in (1,9,12)
            and t2.hps_d_hr_status in ('在职')
            and t2.hps_dept_descr_lv1 in ('运营管理部A','运营管理部B')
            and t2.hps_d_jobcode in ('店经理', '门店伙伴', '店员', '社会PT', '学生PT', '见习店经理','店副经理','内部合作经营者','内部合作辅助人','内部合作伙伴','外部合作经营者','外部合作辅助人','外部合作伙伴')
    ) tmp
    group by employee_no
)

,task_hour_info as ( --员工工序工时合格率
    select
        employee_id
        ,avg(case when dt >= '${today-7}' then qualified_task_time_exclude_free_rate end) as t7_avg_task_time_rate --工时合格率t7
        ,avg(qualified_task_time_exclude_free_rate) as t30_avg_task_time_rate --工时合格率t30
    from (
        select
            t1.work_date
            ,t1.dt
            ,t1.employee_id
            ,qualified_task_time_exclude_free_rate
        from data_shop.app_mmc_store_employee_qualified_task_time_rate_di_v3_view t1 --日级别增量表，过去数据需要修改dt
        where t1.dt >= '${today-30}'
            and t1.dt <= '${today-1}'
            -- and t1.dt = date_format(t1.work_date, 'yyyyMMdd')
    ) tmp
    group by employee_id
)

,task_execute_detail as ( --员工工序未按sop执行天维度明细
    select
        lpad(a1.staff_code,8,'10') as staff_code
        ,a3.store_code
        ,a3.roster_date
        ,count(*) as task_cnts
        ,sum(if(check_result_status = 1,1,0))/count(*) as mismatch_ratio --工序未按sop执行率
    from
    (
        select get_json_object(item_detail_result,'$.contentInfo.baseInfo.formVariables[0].value') as staff_code
            ,check_result_status
            ,shop_task_id
        from data_shop.pdw_idss_ice_ddp_remote_inspect_shop_item_result_view
        where dt = date_format(date_sub(current_date(),2),'yyyyMMdd')
            and business_type = 4
            and date_format(create_time,'yyyyMMdd') >= '${today-30}' -- 最近30天
    ) a1
    left outer join
    (
        select id
            ,business_code
        from data_shop.pdw_idss_ice_ddp_remote_inspect_shop_task_view
        where dt = '${today-1}'
    ) a2
    on a1.shop_task_id = a2.id
    left outer join
    (
        select task_id
            ,shop_code as store_code
            ,work_date as roster_date
        from data_shop.dm_mmc_task_di_view
        where dt >= '${today-30}'
    ) a3
    on a2.business_code = a3.task_id
    group by
        lpad(a1.staff_code,8,'10')
        ,a3.store_code
        ,a3.roster_date
)

,task_execute_info as ( --员工工序未按sop执行率(指标越小越好)
    select
        staff_code
        ,avg(mismatch_ratio) as t30_avg_mismatch_ratio --未按sop执行率
        ,sum(task_cnts) as t30_sum_task_cnts --点击执行数
    from task_execute_detail
    group by staff_code
)
,key_task_qualified_info as ( -- 员工重点工序执行率
select 
lpad(t1.staff_code,8,'10') as staff_code

,sum(qualified_key_task_hours) as qualified_key_task_hours
,sum(key_task_hours) as key_task_hours
,sum(qualified_key_task_hours)/sum(key_task_hours) as key_task_qualified_hours_rate
from data_smartorder.app_mmc_key_task_qualified_rate_di t1 
where t1.dt = '${today-1}'
and t1.work_date <= '${TODAY-1}' 
 and t1.work_date >= '${TODAY-30}' 
 group by lpad(t1.staff_code,8,'10')

)
,check_order_info as ( --员工盘点执行率
    select
        executor
        ,avg(check_order_rate) as t30_avg_check_order_rate
    from (
        select
            t1.executor
            ,t1.work_date
            ,t1.biz_order_id
            ,t1.task_finish_work_num/task_work_num as check_order_rate
        from data_shop.dwa_shop_horae_task_operation_checkorder_da t1
        where t1.dt = date_format(date_sub(current_date(),2),'yyyyMMdd')  and date_format(t1.work_date,'yyyyMMdd') >= '${today-30}'
    ) tmp
    group by executor
)

-- ,ab_time_detail as ( --违规发生时间表
--     select
--         flow_name
--         ,order_id
--         ,max(case when form_name='createTime' then get_json_object(hivemall.json_split(form_values)[0],'$.value') end) as occur_time
--         ,max(case when form_name='createTime' then form_values end) as occur_time_raw
--     from (
--         select
--             t1.flow_ame    as flow_name
--             ,t1.order_id
--             ,t2.form_name
--             ,t2.form_values
--             ,t2.index
--             ,t2.seq
--             ,row_number() over (partition by t1.order_id,t2.form_name,t2.index,t2.seq order by t2.dt desc)  as rm
--         from data_build.pdw_order_store_211_order_detail_flow_main t1
--         left join data_build.pdw_order_store_211_order_detail_flow_form_variable_groups_di t2
--             on t1.order_id = t2.order_id
--             and t2.dt >= '20220101'
--         where t1.dt = '${today-1}'
--             and t1.flow_code = '023898'
--     )t1
--     where rm = 1
--     group by
--         flow_name
--         ,order_id
-- )

,punish_detail as ( --惩处明细
    select
        t1.previous_order_id                                                                                            as order_id
        ,to_date(t1.1st_create_date)                                                                                    as order_create_date
        -- ,t2.occur_time                                                                                                  as ab_create_time
        ,t1.chain_status                                                                                                as order_status
        ,case when locate('#', regexp_replace(t1.1st_item_id,'[0-9]','#')) > 0
            then t1.1st_flow_name else t1.1st_item_id end                                                               as punish_item
        ,coalesce(t1.3rd_operate_results,t1.2nd_operate_results,t1.1st_operate_results)                                 as operate_results
        ,t1.1st_shop_code                                                                                               as shop_code
        -- ,t3.hps_dept_code_lv5                                                                                           as dept_code
        ,coalesce(t1.3rd_final_user_name,t1.2nd_final_user_name,t1.1st_final_user_name)                                 as staff_name
        ,coalesce(t1.3rd_final_user_code,t1.2nd_final_user_code,t1.1st_final_user_code)                                 as emplid
        ,lpad(coalesce(t1.3rd_final_user_code,t1.2nd_final_user_code,t1.1st_final_user_code),8,'10')                    as staff_code
        ,case
            when coalesce(3rd_final_feedback_type,2nd_final_feedback_type,2nd_feedback_type
                ,1st_final_feedback_type,1st_feedback_type) = '工时数量扣减'
            then '工时数量扣减' else '工时工资扣减' end                                                                     as punish_type
        ,case
            when coalesce(3rd_final_feedback_type,2nd_final_feedback_type
                ,2nd_feedback_type,1st_final_feedback_type,1st_feedback_type) = '工时数量扣减'
                then 20*round(coalesce(3rd_final_feedback_result_value,3rd_feedback_result_value
                        ,2nd_final_feedback_result_value,2nd_feedback_result_value
                        ,1st_final_feedback_result_value,1st_feedback_result_value),2)
            else round(coalesce(3rd_final_feedback_result_value,3rd_feedback_result_value
                        ,2nd_final_feedback_result_value,2nd_feedback_result_value
                        ,1st_final_feedback_result_value,1st_feedback_result_value),2) end                              as punish_value
        ,case
            when coalesce(3rd_final_feedback_type,2nd_final_feedback_type
                ,2nd_feedback_type,1st_final_feedback_type,1st_feedback_type) = '工时数量扣减'
                then 20*round(coalesce(3rd_feedback_result_value
                        ,2nd_feedback_result_value
                        ,1st_feedback_result_value),2)
            else round(coalesce(3rd_feedback_result_value
                        ,2nd_feedback_result_value
                        ,1st_feedback_result_value),2) end                                                              as punish_value_origin
    from data_build.dwd_store_construction_operation_punish_flow_pipeline_v1 t1
    -- left join ab_time_detail t2
    -- on coalesce(t1.next_order_id_2,t1.next_order_id,t1.previous_order_id) = t2.order_id
    -- left join data_shop.pdw_psprod_ps_blf_ehr_pers_vw_view t3
    -- on t3.dt <= '${today-1}' and date_format(date_sub(to_date(t2.occur_time),1),'yyyyMMdd') = t3.dt
    --     and coalesce(t1.3rd_final_user_code,t1.2nd_final_user_code,t1.1st_final_user_code) = t3.emplid
    where t1.dt = '${today-1}'
        and date_format(t1.1st_create_date,'yyyyMMdd') >= '${today-30}'
        and (case when locate('#', regexp_replace(1st_item_id,'[0-9]','#')) > 0
            then 1st_flow_name else 1st_item_id end) not in ('请假/拒绝班次惩处','超成本工时费用')
)

,sample_punch_detail as ( --随机打卡
    select distinct
        emplid
        ,order_create_date
        -- ,ab_create_time
        ,shop_code
        -- ,dept_code
        ,order_id
        ,punish_item
        ,punish_type
        ,punish_value
        ,punish_value_origin
    from punish_detail
    where punish_item = '随机打卡任务超时'
        and operate_results = '运营问题'
        and order_status = 'FINISHED'
)

,sample_punch_info as ( --随机打卡final
    select
        emplid
        ,count(distinct order_id) as  sample_punch_cnts
        ,sum(punish_value) as sample_punch_punish_value
        ,sum(punish_value_origin) as sample_punch_punish_value_origin
    from sample_punch_detail
    where date_format(order_create_date,'yyyyMMdd') >= '${today-30}'
    group by emplid
)

,appeal_text_detail as ( --客诉详细说明
    select distinct
        order_id
        ,abnormal_explain
        ,exemption
        ,split(inspection_order_id,' ')[1] as inspection_order_id
    from data_build.dwd_store_construction_operation_punish_flow_details_long_middle_v1 t1
    where t1.dt = '${today-1}' and rm = 1
)

,appeal_punish_detail as ( --客诉
    select distinct
        t1.emplid
        ,t1.order_create_date
        -- ,t1.ab_create_time
        ,t1.shop_code
        -- ,t1.dept_code
        ,t1.order_id
        ,t1.punish_item
        ,t1.punish_type
        ,t1.punish_value
        ,t1.punish_value_origin
        ,t2.abnormal_explain
        ,t2.exemption
    from punish_detail t1
    left join appeal_text_detail t2
    on t1.order_id = t2.order_id
    where t1.punish_item = '客诉惩处'
        and t1.operate_results = '运营问题'
        and t1.order_status = 'FINISHED'
        and (
            (t2.exemption = '客诉-业务来源: 日配客诉'
                and t2.abnormal_explain in ('客诉-投诉分类: 二级/BZ/变质','客诉-投诉分类: 二级/GQ/过期','客诉-投诉分类: 二级/YW/异物'
                ,'客诉-投诉分类: 三级/口感/口感','客诉-投诉分类: 三级/品质/品质'))
            or
            (t2.abnormal_explain in ('客诉-投诉分类: 四级/服务问题/服务态度问题','客诉-投诉分类: 四级/服务问题/技能/专业不熟练'
                ,'客诉-投诉分类: 四级/配送问题/配送超时','客诉-投诉分类: 四级/配送问题/商品漏送','客诉-投诉分类: 四级/配送问题/商品送错'
                ,'客诉-投诉分类: 四级/退换货问题/店员给错商品','客诉-投诉分类: 一级/CT/服务冲突'))
        )
)

,appeal_punish_info as ( --客诉final
    select
        emplid
        ,count(distinct order_id) as  appeal_punish_cnts
        ,sum(punish_value) as appeal_punish_value
        ,sum(punish_value_origin) as appeal_punish_value_origin
    from appeal_punish_detail
    where date_format(order_create_date,'yyyyMMdd') >= '${today-30}'
    group by emplid
)

,else_punish_detail as ( --其他惩处
    select distinct
        emplid
        ,order_create_date
        -- ,ab_create_time
        ,shop_code
        -- ,dept_code
        ,order_id
        ,punish_item
        ,punish_type
        ,punish_value
        ,punish_value_origin
    from punish_detail
    where punish_item not in ('工序任务未按sop执行（原工序任务真实执行率）','工序任务工时合格率不达标','客诉惩处','随机打卡任务超时')
        and operate_results = '运营问题'
        and order_status = 'FINISHED'
)

,else_punish_info as ( --客诉final
    select
        emplid
        ,count(distinct order_id) as  else_punish_cnts
        ,sum(punish_value) as else_punish_value
        ,sum(punish_value_origin) as else_punish_value_origin
    from else_punish_detail
    where date_format(order_create_date,'yyyyMMdd') >= '${today-30}'
    group by emplid
)

,cross_eval_detail as ( --跨店评价明细
    select
        t1.dynamic_shift_id
        ,t2.id
        ,t3.work_shift_id
        ,t1.cross_employee_id
        ,t1.cross_store_code
        ,t1.evaluator
        ,t1.roster_store_code
        ,t1.roster_date
        ,t3.work_shift_type
        ,t3.work_shift_second_desc
        ,t1.roster_arrange
        ,t1.skill_level
        ,t1.need_improve_skill
        ,t1.work_state
        ,t1.welcome
    from data_shop.pdw_opc_roster_cross_store_staff_evaluation_view t1
    left join data_shop.pdw_opc_shop_attendance_shop_roster_detail_view t2
    on t2.dt = '${today-1}'
        and t1.dynamic_shift_id = t2.dynamic_shift_id
    left join data_shop.pdw_opc_shop_attendance_report_work_shift_view t3
    on t3.dt = '${today-1}'
        and t2.id = t3.work_shift_id
    where t1.dt = '${today-1}'
        and t1.evaluator is not null
        and date_format(t1.roster_date,'yyyyMMdd') >= '${today-60}'
        and t3.work_shift_second_desc <> '新人班次'
)

,cross_eval_info as ( --跨店指标汇总
    select
        cross_employee_id
        ,count(distinct work_shift_id) as evaluate_cnts
        ,count(distinct case when skill_level = '高' then work_shift_id end) as high_skill_cnts
        ,count(distinct case when work_state = '一直努力' then work_shift_id end) as work_hard_cnts
        ,count(distinct case when welcome = '十分希望' then work_shift_id end) as welcome_cnts
        ,count(distinct case when work_state = '一直偷懒' then work_shift_id end) as lazy_cnts
        ,count(distinct case when welcome = '拒绝' then work_shift_id end) as reject_cnts
    from cross_eval_detail
    group by cross_employee_id
)

select
    distinct
    t1.emplid
    ,lpad(t1.emplid,8,'10') as staff_code
    ,t1.name as staff_name
    ,t1.hps_d_city as city_name
    ,t1.hps_d_jobcode as position_cn
    ,case when t0.store_manager_no is not null then '1' else '0' end as is_store_manager
    ,t1.hps_dept_code_lv5 as store_code
    ,t1.hps_dept_descr_lv5 as store_name

    -- ,coalesce(t2.cum_attend_hours,0) as cum_attend_hours
    ,coalesce(t2.t30_work_shift_hours,0) as t30_work_shift_hours
    -- ,case when t2.night_shift_cnts>0 then 1 else 0 end as has_night_shift
    -- ,case when t2.weekend_shift_cnts>0 then 1 else 0 end as has_weekend_shift
    -- ,case when t2.long_shift_cnts>0 then 1 else 0 end as has_long_shift
    ,coalesce(round(t3.t7_avg_task_time_rate,4),null) as t7_avg_task_time_rate --员工工序工时合格率t7
    ,coalesce(round(t3.t30_avg_task_time_rate,4),null) as t30_avg_task_time_rate --员工工序工时合格率t30
    ,coalesce(round(t4.t30_avg_mismatch_ratio,4),null) as t30_avg_mismatch_ratio --员工工序未按sop执行率
    -- ,coalesce(round(t4.t30_sum_task_cnts,4),0) as t30_sum_task_cnts --员工工序执行数量
    ,coalesce(round(t5.t30_avg_check_order_rate,4),null) as t30_avg_check_order_rate --员工盘点执行率

    --其他惩处
    ,coalesce(t6.else_punish_cnts,0) as t30_else_punish_cnts
    -- ,case when coalesce(t2.t30_work_shift_hours,0) = 0 then null
    --     else coalesce(t6.else_punish_cnts,0) / coalesce(t2.t30_work_shift_hours,0) end as else_punish_rate_100per
    -- ,coalesce(t6.else_punish_value,0) as t30_else_punish_value
    -- ,coalesce(t6.else_punish_value_origin,0) as t30_else_punish_value_origin

    --客诉惩处
    ,coalesce(t7.appeal_punish_cnts,0) as t30_appeal_punish_cnts
    -- ,case when coalesce(t2.t30_work_shift_hours,0) = 0 then null
    --     else coalesce(t7.appeal_punish_cnts,0) / coalesce(t2.t30_work_shift_hours,0) end as appeal_punish_rate_100per
    -- ,coalesce(t7.appeal_punish_value,0) as t30_appeal_punish_value
    -- ,coalesce(t7.appeal_punish_value_origin,0) as t30_appeal_punish_value_origin

    --随机打卡惩处
    ,coalesce(t8.sample_punch_cnts,0) as t30_sample_punch_cnts
    -- ,case when coalesce(t2.t30_work_shift_hours,0) = 0 then null
    --     else coalesce(t8.sample_punch_cnts,0) / coalesce(t2.t30_work_shift_hours,0) end as sample_punch_punish_rate_100per
    -- ,coalesce(t8.sample_punch_punish_value,0) as t30_sample_punch_punish_value
    -- ,coalesce(t8.sample_punch_punish_value_origin,0) as t30_sample_punch_punish_value_origin

    --跨店评价
    ,coalesce(evaluate_cnts,0) as t60_cross_evaluate_cnts
    ,coalesce(high_skill_cnts,0) as t60_cross_high_skill_cnts
    ,coalesce(work_hard_cnts,0) as t60_cross_work_hard_cnts
    ,coalesce(welcome_cnts,0) as t60_cross_welcome_cnts
    ,coalesce(lazy_cnts,0) as t60_cross_lazy_cnts
    ,coalesce(reject_cnts,0) as t60_cross_reject_cnts
    -- 重点工序执行率 
    ,coalesce(round(t10.key_task_qualified_hours_rate,4),null) as t30_key_task_qualified_hours_rate 

from data_shop.pdw_psprod_ps_blf_ehr_pers_vw_view t1
left join cum_attend_info t2
on lpad(t1.emplid,8,'10') = lpad(t2.employee_no,8,'10')
left join task_hour_info t3
on lpad(t1.emplid,8,'10') = lpad(t3.employee_id,8,'10')
left join task_execute_info t4
on lpad(t1.emplid,8,'10') = lpad(t4.staff_code,8,'10')
left join check_order_info t5
on lpad(t1.emplid,8,'10') = lpad(t5.executor,8,'10')
left join else_punish_info t6
on lpad(t1.emplid,8,'10') = lpad(t6.emplid,8,'10')
left join appeal_punish_info t7
on lpad(t1.emplid,8,'10') = lpad(t7.emplid,8,'10')
left join sample_punch_info t8
on lpad(t1.emplid,8,'10') = lpad(t8.emplid,8,'10')
left join cross_eval_info t9
on lpad(t1.emplid,8,'10') = lpad(t9.cross_employee_id,8,'10')
left join key_task_qualified_info t10 
on lpad(t1.emplid,8,'10') = t10.staff_code

left join data_shop.dw_ordering_store_tag_location_ranking_info_v1_view t0
on t0.dt = '${today-1}' and lpad(t1.emplid,8,'10') = lpad(t0.store_manager_no,8,'10')
where t1.dt = '${today-1}'
    and t1.hps_dept_descr_lv1 in ('运营管理部A','运营管理部B')
    and t1.hps_d_jobcode in ('店经理', '门店伙伴', '店员', '社会PT', '学生PT', '见习店经理','店副经理','内部合作经营者','内部合作辅助人','内部合作伙伴','外部合作经营者','外部合作辅助人','外部合作伙伴')
    and t1.hps_d_hr_status = '在职'
