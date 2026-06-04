--in/outflow看板中流入流出部分

--日期匹配每周一
with weekday_info as (
    select  
        t1.date_key
        ,date_format(t1.date_key,'yyyyMMdd') as dt_key
        ,date_sub(next_day(t1.date_key,'mon'),7) as date_week
    from data_build.dim_date_ya_v2 t1
    where t1.calendar_year in ('2022','2023','2024','2025')
)

--入职情况：人，店，日期，白夜标签
,entry_detail as (
    select 
        if(length(t1.code)<8,concat('10',t1.code),t1.code) as staff_code
        ,t1.position_name
        ,t1.plan_shop_code
        ,date_format(t2.create_time,'yyyy-MM-dd') as entry_date
        ,date_format(t2.create_time,'yyyyMMdd') as entry_dt
        ,case 
            when final_work_class_tag like '%全天%' then if(final_work_class = 'day','白','夜')
            when final_work_class_tag like '%白%' then '白'
            when final_work_class_tag like '%夜%' then '夜'
        else 'NA' end as final_work_class_tag
    from data_shop.pdw_gis_workday_entry_staff_position_view t1
    left join data_shop.mid_gis_workday_entry_status_change_view t2
    on t1.entry_id = t2.entry_id and t2.entry_state = 1
        and t2.dt = '${today-1}'
    where t1.dt = '${today-1}'
        and t1.position_name in ('店经理', '门店伙伴','店副经理', '店员', '社会PT', '学生PT', '见习店经理')
        and t1.code is not null
        and date_format(t2.create_time,'yyyyMMdd') >= '${today-450}'
)

--入职：店/天/百叶标签维度的人数
,entry_per_store_by_tag as (
    select 
        plan_shop_code
        ,entry_dt
        ,final_work_class_tag
        ,count(distinct staff_code) as entry_cnts
    from entry_detail
    group by plan_shop_code
        ,entry_dt
        ,final_work_class_tag
)

--入职：店天的总/白/夜/未知入职人数拆分为单列
,entry_per_store_final as (
    select 
        t1.plan_shop_code
        ,t1.entry_dt
        ,count(distinct t1.staff_code) as total_entry_cnts
        ,t2.entry_cnts as day_entry_cnts
        ,t3.entry_cnts as night_entry_cnts
        ,t4.entry_cnts as unknown_entry_cnts
    from entry_detail t1
    left join entry_per_store_by_tag t2
    on t1.plan_shop_code = t2.plan_shop_code and t1.entry_dt = t2.entry_dt 
        and t2.final_work_class_tag = '白'
    left join entry_per_store_by_tag t3
    on t1.plan_shop_code = t3.plan_shop_code and t1.entry_dt = t3.entry_dt 
        and t3.final_work_class_tag = '夜'
    left join entry_per_store_by_tag t4
    on t1.plan_shop_code = t4.plan_shop_code and t1.entry_dt = t4.entry_dt 
        and t4.final_work_class_tag = 'NA'
    group by t1.plan_shop_code
        ,t1.entry_dt
        ,t2.entry_cnts
        ,t3.entry_cnts
        ,t4.entry_cnts
)

--出勤标签：每一天根据出勤和给班得出的白夜班标签
,attend_tag_info as (
    select 
        staff_code
        ,emplid
        ,dt
        ,case
            when attend_tag like '%白%' then '白'
            when attend_tag like '%夜%' then '夜'
            when attend_tag like '%全天%' then '夜'
        else 'NA' end as attend_tag
        ,row_number() over(partition by staff_code order by dt desc) as rn
    from (
        select 
            if(length(employee_id)<8,concat('10',employee_id),employee_id) as staff_code
            ,employee_id as emplid
            ,nvl(chuqin_label,geiban_label) as attend_tag
            ,dt
            ,row_number() over(partition by employee_id,dt order by dt desc) as rn
        from data_build.dwd_store_construction_roster_staff_supply_v1_di
        where dt >= '20221127'
            -- and chuqin_label is not null 
    ) tmp
    where rn = 1
)

--保护标签：每一天的保护标签
,protect_info as (
    select 
        staff_code
        ,emplid
        ,dt
        ,protect_tag
    from (
        select 
            t1.staff_code as staff_code
            ,t2.emplid as emplid
            ,coalesce(protect_tag,'待观察') as protect_tag
            ,t1.dt
            ,row_number() over(partition by t1.staff_code,t1.dt order by t1.dt desc) as rn
        from data_shop.dm_shop_staff_protect_tag_v2 t1
        left join data_shop.pdw_psprod_ps_blf_ehr_pers_vw_view t2
        on t2.dt = '${today-1}' and t1.staff_code = IF(LENGTH(t2.emplid)<8,concat('10',t2.emplid),t2.emplid)
        where t1.dt >= '20221127'
            -- and chuqin_label is not null 
    ) tmp
    where rn = 1
)

--离职情况
,leave_detail as ( -- 店经理及以下岗位申请离职流程明细
    select 
        staff_code
        ,dept_code
        ,leave_dt
        ,leave_date
        ,attend_tag
    from (
        select 
            if(length(t1.man_code)<8,concat('10',t1.man_code),t1.man_code) as staff_code
            ,dept_code
            ,date_format(t1.final_leave_date,'yyyyMMdd') as leave_dt
            ,date_format(t1.final_leave_date,'yyyy-MM-dd') as leave_date
            ,coalesce(t2.attend_tag,'NA') as attend_tag
            ,t2.dt
            ,row_number() over(partition by t1.man_code,t1.create_time order by t2.dt desc) as rn
        from data_shop.pdw_gis_workday_dimission_order_view t1
        left join attend_tag_info t2
        on date_format(t1.final_leave_date,'yyyyMMdd') >= t2.dt
            and if(length(t1.man_code)<8,concat('10',t1.man_code),t1.man_code) = t2.staff_code
        where t1.dt = '${today-1}'  
            and t1.job in ('店经理', '门店伙伴', '店员','店副经理', '社会PT', '学生PT', '见习店经理')
            and final_leave = 'leave'
            and final_leave_date is not null
            and date_format(final_leave_date,'yyyyMMdd') >= '${today-450}'
            and date_format(final_leave_date,'yyyyMMdd') <= '${today-1}'
    ) tmp
    where rn = 1
)

--离职情况：人，店，日期，白夜标签
,leave_per_store_by_tag as (
    select 
        leave_dt
        ,dept_code
        ,attend_tag
        ,count(distinct staff_code) as leave_cnts
    from leave_detail
    group by 
        leave_dt
        ,dept_code
        ,attend_tag
)

--离职：店天的总/白/夜/未知离职人数拆分为单列
,leave_per_store_final as (
    select 
        t1.dept_code
        ,t1.leave_dt
        ,count(distinct t1.staff_code) as total_leave_cnts
        ,t2.leave_cnts as day_leave_cnts
        ,t3.leave_cnts as night_leave_cnts
        ,t4.leave_cnts as unknown_leave_cnts
    from leave_detail t1
    left join leave_per_store_by_tag t2
    on t1.dept_code = t2.dept_code and t1.leave_dt = t2.leave_dt 
        and t2.attend_tag = '白'
    left join leave_per_store_by_tag t3
    on t1.dept_code = t3.dept_code and t1.leave_dt = t3.leave_dt 
        and t3.attend_tag = '夜'
    left join leave_per_store_by_tag t4
    on t1.dept_code = t4.dept_code and t1.leave_dt = t4.leave_dt 
        and t4.attend_tag = 'NA'
    group by t1.dept_code
        ,t1.leave_dt
        ,t2.leave_cnts
        ,t3.leave_cnts
        ,t4.leave_cnts
)

--不可用情况
,unavailable_detail as (
    select 
        staff_code
        ,tmp.dt
        ,valid_date
        ,dept_code
        ,attend_tag
    from (
        select 
            if(length(t1.man_code)<8,concat('10',t1.man_code),t1.man_code) as staff_code
            ,t1.dt
            ,concat(substr(t1.dt,1,4),'-',substr(t1.dt,5,2),'-',substr(t1.dt,7,2)) as valid_date
            ,t1.dept_code
            ,coalesce(t2.attend_tag,'NA') as attend_tag
            ,t2.dt as t2_dt
            ,row_number() over(partition by t1.man_code,t1.dt order by t2.dt desc) as rn
        from data_shop.pdw_gis_workday_dimission_order_view t1
        left join data_shop.pdw_idss_ipes_admin_employee_blacklist_view t3 on t3.dt = '${today-1}' and t3.employee_no = t1.man_code and t3.start_date >= date_sub(current_date(),450) and t3.valid_status = 1 
        left join attend_tag_info t2
        on t1.dt >= t2.dt
            and if(length(t1.man_code)<8,concat('10',t1.man_code),t1.man_code) = t2.staff_code
        where t1.dt >= '${today-450}'
            and t1.job in ('店经理', '门店伙伴', '店员','店副经理', '社会PT', '学生PT', '见习店经理')
            and ((t1.leave_way = 3 and date_format(t1.create_time,'yyyyMMdd') = t1.dt) --当天发起的强制离职
                    or (t1.leave_way <> 3 and date_format(date_add(final_leave_date,1),'yyyyMMdd') = t1.dt)) --昨天lastday的非强制离职
            and t3.employee_no is null
    ) tmp
    where rn = 1
)

--不可用情况：人，店，日期，白夜标签
,unavailable_per_store_by_tag as (
    select 
        dt
        ,dept_code
        ,attend_tag
        ,count(distinct staff_code) as unavailable_cnts
    from unavailable_detail
    group by 
        dt
        ,dept_code
        ,attend_tag
)

--不可用：店天的总/白/夜/未知离职人数拆分为单列
,unavailable_per_store_final as (
    select 
        t1.dept_code
        ,t1.dt
        ,count(distinct t1.staff_code) as total_unavailable_cnts
        ,t2.unavailable_cnts as day_unavailable_cnts
        ,t3.unavailable_cnts as night_unavailable_cnts
        ,t4.unavailable_cnts as unknown_unavailable_cnts
    from unavailable_detail t1
    left join unavailable_per_store_by_tag t2
    on t1.dept_code = t2.dept_code and t1.dt = t2.dt 
        and t2.attend_tag = '白'
    left join unavailable_per_store_by_tag t3
    on t1.dept_code = t3.dept_code and t1.dt = t3.dt 
        and t3.attend_tag = '夜'
    left join unavailable_per_store_by_tag t4
    on t1.dept_code = t4.dept_code and t1.dt = t4.dt 
        and t4.attend_tag = 'NA'
    group by t1.dept_code
        ,t1.dt
        ,t2.unavailable_cnts
        ,t3.unavailable_cnts
        ,t4.unavailable_cnts
)


--不可用情况
,blacklist_detail as (
    select 
       staff_code
        ,dt
        ,valid_date
        ,dept_code
        ,attend_tag
    from (select distinct 
if(length(t1.employee_no)<8,concat('10',t1.employee_no),t1.employee_no) as staff_code 
,t1.start_date as valid_date
,date_format(t1.start_date,'yyyyMMdd') as dt 
,t2.hps_dept_code_lv5 as dept_code 
,coalesce(t3.attend_tag,'NA') as attend_tag
,row_number() over(partition by t1.employee_no,t1.start_date order by t1.start_date asc) as rn
from data_shop.pdw_idss_ipes_admin_employee_blacklist_view t1
left join data_shop.pdw_psprod_ps_blf_ehr_pers_vw_view t2 on t1.employee_no = t2.emplid and t2.dt = '${today-1}' 
left join attend_tag_info t3 on if(length(t1.employee_no)<8,concat('10',t1.employee_no),t1.employee_no) = t3.staff_code and t3.rn = 1 
left join unavailable_detail t4 on if(length(t1.employee_no)<8,concat('10',t1.employee_no),t1.employee_no) = t4.staff_code 
where t1.dt = '${today-1}' 
and t1.valid_status  = 1 
and t1.start_date >= date_sub(current_date(),450)
and t2.hps_d_jobcode in ('店经理', '门店伙伴','店副经理', '店员', '社会PT', '学生PT', '见习店经理')
and t4.staff_code is null ) tmp 
        where rn = 1

)

--不可用情况：人，店，日期，白夜标签
,blacklist_per_store_by_tag as (
    select 
        dt
        ,dept_code
        ,attend_tag
        ,count(distinct staff_code) as unavailable_cnts
    from blacklist_detail
    group by 
        dt
        ,dept_code
        ,attend_tag
)

--不可用：店天的总/白/夜/未知离职人数拆分为单列
,blacklist_per_store_final as (
    select 
        t1.dept_code
        ,t1.dt
        ,count(distinct t1.staff_code) as total_unavailable_cnts
        ,t2.unavailable_cnts as day_unavailable_cnts
        ,t3.unavailable_cnts as night_unavailable_cnts
        ,t4.unavailable_cnts as unknown_unavailable_cnts
    from blacklist_detail t1
    left join blacklist_per_store_by_tag t2
    on t1.dept_code = t2.dept_code and t1.dt = t2.dt 
        and t2.attend_tag = '白'
    left join blacklist_per_store_by_tag t3
    on t1.dept_code = t3.dept_code and t1.dt = t3.dt 
        and t3.attend_tag = '夜'
    left join blacklist_per_store_by_tag t4
    on t1.dept_code = t4.dept_code and t1.dt = t4.dt 
        and t4.attend_tag = 'NA'
    group by t1.dept_code
        ,t1.dt
        ,t2.unavailable_cnts
        ,t3.unavailable_cnts
        ,t4.unavailable_cnts
)

--挽回情况
,redeem_detail as (
    select  
        staff_code
        ,tmp.dt
        ,valid_date
        ,dept_code
        ,attend_tag
    from (
        select 
            if(length(t1.man_code)<8,concat('10',t1.man_code),t1.man_code) as staff_code
            ,t1.dt
            ,concat(substr(t1.dt,1,4),'-',substr(t1.dt,5,2),'-',substr(t1.dt,7,2)) as valid_date
            ,t1.dept_code
            ,coalesce(t2.attend_tag,'NA') as attend_tag
            ,t2.dt as t2_dt
            ,row_number() over(partition by t1.man_code,t1.dt order by t2.dt desc) as rn
        from data_shop.pdw_gis_workday_dimission_order_view t1
        left join attend_tag_info t2
        on t1.dt >= t2.dt
            and if(length(t1.man_code)<8,concat('10',t1.man_code),t1.man_code) = t2.staff_code
        where t1.dt >= '${today-450}'
            and t1.job in ('店经理', '门店伙伴', '店员','店副经理', '社会PT', '学生PT', '见习店经理')
            and (t1.order_status = 'FINISHED' and date_format(coalesce(data_update_time,update_time),'yyyyMMdd') = t1.dt
                    and t1.final_leave = 'noLeave') --昨天完成且确定不离职的
    ) tmp
    where rn = 1
)

--挽回情况：人，店，日期，白夜标签
,redeem_per_store_by_tag as (
    select 
        dt
        ,dept_code
        ,attend_tag
        ,count(distinct staff_code) as redeem_cnts
    from redeem_detail
    group by 
        dt
        ,dept_code
        ,attend_tag
)

--挽回：店天的总/白/夜/未知离职人数拆分为单列
,redeem_per_store_final as (
    select 
        t1.dept_code
        ,t1.dt
        ,count(distinct t1.staff_code) as total_redeem_cnts
        ,t2.redeem_cnts as day_redeem_cnts
        ,t3.redeem_cnts as night_redeem_cnts
        ,t4.redeem_cnts as unknown_redeem_cnts
    from redeem_detail t1
    left join redeem_per_store_by_tag t2
    on t1.dept_code = t2.dept_code and t1.dt = t2.dt 
        and t2.attend_tag = '白'
    left join redeem_per_store_by_tag t3
    on t1.dept_code = t3.dept_code and t1.dt = t3.dt 
        and t3.attend_tag = '夜'
    left join redeem_per_store_by_tag t4
    on t1.dept_code = t4.dept_code and t1.dt = t4.dt 
        and t4.attend_tag = 'NA'
    group by t1.dept_code
        ,t1.dt
        ,t2.redeem_cnts
        ,t3.redeem_cnts
        ,t4.redeem_cnts
)

,raw_list as(
select  
    distinct
    t4.date_key as valid_date
    ,t4.date_week
    ,t1.store_code
    ,case when t5.store_manager_no is not null then '1' else '0' end as has_manager
    ,t1.group_level
    ,t1.is_boderline
    ,t1.difficulty_level
    ,coalesce(t1.priority_level,'撤店pipeline') as priority_level
    ,coalesce(t1.reward_level,'P1') as reward_level_day
    ,coalesce(t1.reward_level_night,'P1') as reward_level_night
    ,t1.is_longterm_q56
    ,t1.is_highsale
    ,t1.fte_all
    ,t1.hc_all
    ,t1.fte_all/hc_all as fte_rate_restrict
    ,t1.full_capacity_all

    ,coalesce(t2.total_entry_cnts,0)            as total_entry_cnts
    ,coalesce(t2.day_entry_cnts,0)              as day_entry_cnts
    ,coalesce(t2.night_entry_cnts,0)            as night_entry_cnts
    ,coalesce(t2.unknown_entry_cnts,0)          as unknown_entry_cnts

    ,coalesce(t3.total_leave_cnts,0)            as total_leave_cnts
    ,coalesce(t3.day_leave_cnts,0)              as day_leave_cnts
    ,coalesce(t3.night_leave_cnts,0)            as night_leave_cnts
    ,coalesce(t3.unknown_leave_cnts,0)          as unknown_leave_cnts

    ,coalesce(t6.total_unavailable_cnts,0)+coalesce(t10.total_unavailable_cnts,0)      as total_unavailable_cnts
    ,coalesce(t6.day_unavailable_cnts,0)+coalesce(t10.day_unavailable_cnts,0)     as day_unavailable_cnts
    ,coalesce(t6.night_unavailable_cnts,0)+coalesce(t10.night_unavailable_cnts,0)      as night_unavailable_cnts
    ,coalesce(t6.unknown_unavailable_cnts,0)+coalesce(t10.unknown_unavailable_cnts,0)    as unknown_unavailable_cnts

    ,coalesce(t8.total_redeem_cnts,0)           as total_redeem_cnts
    ,coalesce(t8.day_redeem_cnts,0)             as day_redeem_cnts
    ,coalesce(t8.night_redeem_cnts,0)           as night_redeem_cnts
    ,coalesce(t8.unknown_redeem_cnts,0)         as unknown_redeem_cnts


    -- ,coalesce(t9.ppl_cnts,0)              as ppl_cnts
    -- ,t7.is_trial
,t1.gap_new
,t1.gap_day
,t1.gap_night
,t9.store_city

    ,coalesce(t6.total_unavailable_cnts,0)      as total_unavailable_leave_cnts
    ,coalesce(t6.day_unavailable_cnts,0)        as day_unavailable_leave_cnts
    ,coalesce(t6.night_unavailable_cnts,0)      as night_unavailable_leave_cnts
    ,coalesce(t6.unknown_unavailable_cnts,0)    as unknown_unavailable_leave_cnts
    ,coalesce(t10.total_unavailable_cnts,0)      as total_unavailable_blacklist_cnts
    ,coalesce(t10.day_unavailable_cnts,0)        as day_unavailable_blacklist_cnts
    ,coalesce(t10.night_unavailable_cnts,0)      as night_unavailable_blacklist_cnts
    ,coalesce(t10.unknown_unavailable_cnts,0)    as unknown_unavailable_blacklist_cnts
from data_build.dwd_store_construction_store_groups_recruit_gap t1
left join weekday_info t4
on date_format(date_add(to_date(from_unixtime(unix_timestamp(t1.dt,'yyyyMMdd'))),1),'yyyyMMdd') = t4.dt_key and t4.dt_key <= '${today-1}'
left join data_shop.dw_ordering_store_tag_location_ranking_info_v1_view t5
on t1.store_code = t5.store_code and t5.dt >= '20221031' and t1.dt = t5.dt
-- left join tag_info t9
-- on t1.store_code = t9.store_code
-- left join data_shop.ods_uploads_p1_trial t7
-- on t1.store_code = t7.store_code

left join entry_per_store_final t2
on t1.store_code = t2.plan_shop_code and date_format(date_add(to_date(from_unixtime(unix_timestamp(t1.dt,'yyyyMMdd'))),1),'yyyyMMdd') = t2.entry_dt
left join leave_per_store_final t3
on t1.store_code = t3.dept_code and date_format(date_add(to_date(from_unixtime(unix_timestamp(t1.dt,'yyyyMMdd'))),1),'yyyyMMdd') = t3.leave_dt
left join unavailable_per_store_final t6
on t1.store_code = t6.dept_code and date_format(date_add(to_date(from_unixtime(unix_timestamp(t1.dt,'yyyyMMdd'))),1),'yyyyMMdd') = t6.dt
left join blacklist_per_store_final t10
on t1.store_code = t10.dept_code and date_format(date_add(to_date(from_unixtime(unix_timestamp(t1.dt,'yyyyMMdd'))),1),'yyyyMMdd') = t10.dt
left join redeem_per_store_final t8
on t1.store_code = t8.dept_code and date_format(date_add(to_date(from_unixtime(unix_timestamp(t1.dt,'yyyyMMdd'))),1),'yyyyMMdd') = t8.dt
left join data_shop.dw_ordering_store_tag_location_ranking_info_v1_view t9
on t9.dt = '${today-1}' and t1.store_code = t9.store_code

where t1.dt >= '${today-950}'
)

select
valid_date
,sum(total_unavailable_cnts) as total_unavailable_cnts
,sum(total_entry_cnts) as total_entry_cnts
from raw_list
group by
valid_date