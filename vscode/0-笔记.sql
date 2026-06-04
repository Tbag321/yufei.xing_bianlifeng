学生PT单独当夜班的门店
学生PT单独当夜班的工时占总学生工时占比
BEGIN --更新入职日期
    with a_list as( --更新入职日期，防止换签导致的入职日期刷新
    select
    dt
    ,emplid
    ,leave_dt
    ,case when leave_dt is null then 0 else 1 end as add_num
    from data_build.pdw_psprod_ps_blf_ehr_pers_vw_view
    where dt >= 20210318
    ),

    b_list as( --更新入职日期，防止换签导致的入职日期刷新
    select
    dt
    ,emplid
    ,leave_dt
    ,sum(add_num) over(partition by emplid order by concat(dt,emplid) desc) as sum_num
    from a_list
    ),

    c_list as( --更新入职日期，防止换签导致的入职日期刷新
    select
    dt
    ,emplid
    ,leave_dt
    ,sum_num
    ,max(leave_dt) over(partition by concat(emplid,sum_num) order by concat(dt,emplid) desc) as final_leave_dt
    from b_list
    ),

    leave_list as( --更新入职日期，防止换签导致的入职日期刷新
    select
    dt
    ,if(length(t1.emplid)=6,concat('10',t1.emplid),t1.emplid) as employee_id
    ,case when final_leave_dt is null then '2035-12-31' else final_leave_dt end as leave_dt
    from c_list t1
    ),

    staff_list_1 as( --更新入职日期，防止换签导致的入职日期刷新
    select
    dt
    ,new_dt
    ,store_code
    ,emplid
    ,employee_id
    ,name
    ,hps_hire_dt
    ,leave_dt
    ,hps_d_hr_status
    ,hps_hire_type
    ,hps_d_jobcode
    ,hps_dept_descr_lv1
    ,hps_d_city
    ,hps_dept_code_lv5
    ,hps_dept_descr_lv5
    ,row_number() over(partition by employee_id order by dt) as rn_1 --按照人*时间排序
    ,dense_rank() over(partition by employee_id order by leave_dt) as rn_2 --第几次在职
    ,min(hps_hire_dt) over(partition by concat(employee_id,dense_rank() over(partition by employee_id order by leave_dt)) order by hps_hire_dt) as hps_hire_date
    ,case when hps_d_hr_status = '离职' then '离职' else 
    datediff(new_dt,min(hps_hire_dt) over(partition by concat(employee_id,dense_rank() over(partition by employee_id order by leave_dt)) order by hps_hire_dt))
    end as hire_date_num
    from
    (
    select
    t1.dt
    ,from_unixtime(unix_timestamp(t1.dt,'yyyyMMdd'),'yyyy-MM-dd') as new_dt
    ,t1.hps_dept_code_lv5 as store_code
    ,t1.emplid
    ,if(length(t1.emplid)=6,concat('10',t1.emplid),t1.emplid) as employee_id
    ,name
    ,t1.hps_hire_dt
    ,t3.leave_dt
    ,case when t3.leave_dt = '2035-12-31' then '在职'
    when t3.leave_dt >= from_unixtime(unix_timestamp(t1.dt,'yyyyMMdd'),'yyyy-MM-dd') then '在职'
    else '离职' end as hps_d_hr_status --在离职状态
    ,t1.hps_hire_type --用工形式
    ,t1.hps_d_jobcode
    ,t1.hps_dept_descr_lv1
    ,t1.hps_d_city
    ,t1.hps_dept_code_lv5
    ,t1.hps_dept_descr_lv5
    from data_build.pdw_psprod_ps_blf_ehr_pers_vw_view t1
    left join leave_list t3 on if(length(t1.emplid)=6,concat('10',t1.emplid),t1.emplid) = t3.employee_id and t1.dt = t3.dt
    where t1.dt >= 20210318
    ) a
    ),

    raw_list as( --更新入职日期，防止换签导致的入职日期刷新
    select
    t.dt
    ,t.new_dt --日期
    ,t.store_code --门店编码
    ,t.emplid
    ,t.employee_id
    ,t.name
    ,t.hps_hire_dt --系统雇佣时间(没用)
    ,t.leave_dt --离职日期
    ,t.hps_d_hr_status --在离职状态
    ,t.hps_hire_type
    ,t.hps_d_jobcode
    ,t.hps_dept_descr_lv1
    ,t.hps_d_city
    ,t.hps_dept_code_lv5
    ,t.hps_dept_descr_lv5
    ,t.rn_1 --按照人*时间维度排序
    ,t.rn_2 --第几次入职
    ,t.hps_hire_date --本次雇佣周期开始日期(真实的入职日期)
    ,t.hire_date_num --本次雇佣周期时长
    from staff_list_1 t
    )

    ,staff_list as(
    select
    t1.dt as record_dt
    ,t1.*
    ,case when t1.student_suspect = '1' and to_date(hps_hire_date) < '2025-05-01' then '疑似学生PT+早入职' else t1.student_suspect end as student_suspect_new
    ,case when t2.hps_d_jobcode = '学生PT' and to_date(hps_hire_date) < '2025-05-01' then '学生PT+早入职' else t2.hps_d_jobcode end as hps_d_jobcode
    ,t2.hps_sys_name
    ,t2.hps_dept_code_lv5
    ,t2.hps_dept_descr_lv5
    ,t7.hps_hire_date --真实入职日期
    ,case when t3.manager_code is not null and (t2.hps_dept_descr_lv5 not like '%区X%' or t2.hps_dept_descr_lv1 not in ('运营管理部X'))
    and t2.hps_d_jobcode not in ('外部合作辅助人','外部合作经营者','外部合作伙伴','内部合作辅助人','内部合作经营者','内部合作伙伴') then '店经理'
    when t2.hps_d_jobcode = '店副经理' then '店副经理'
    when t4.employee_id is not null and (t2.hps_dept_descr_lv5 like '%区X%' or t2.hps_dept_descr_lv1 in ('运营管理部X')) then '机动队带店店长'
    when t5.employee_no is not null and (t2.hps_dept_descr_lv5 like '%区X%' or t2.hps_dept_descr_lv1 in ('运营管理部X'))  then t5.relation_type
    when t2.hps_dept_descr_lv5 like '%区X%' or t2.hps_dept_descr_lv1 in ('运营管理部X') then '机动队队员'
    when t2.hps_d_jobcode not in ('外部合作辅助人','外部合作经营者','外部合作伙伴','内部合作辅助人','内部合作经营者','内部合作伙伴') then '店员'
    else '加盟人员' end as post_name
    from data_shop.dm_shop_staff_protect_tag_v2 t1
    left join data_build.pdw_psprod_ps_blf_ehr_pers_vw_view t2 on t1.staff_code = lpad(t2.emplid,8,'10') and t2.dt = t1.dt --hps_d_jobcode in ('店副经理')
    left join data_build.pdw_opc_shop_ehr_staff_dept_view t3 on t2.hps_dept_code_lv5 = t3.dept_code and lpad(t2.emplid,8,'10') = lpad(t3.manager_code,8,'10') and t3.dt = t1.dt --店长
    left join data_build.dwd_store_construction_district_manager_base_info0_di t4 on t1.staff_code = t4.employee_id
    and t4.dt = '${today-2}'
    left join (select
    * from(
    select 
    employee_no,
    shop_code,
    relation_type,
    dt,
    row_number() over(partition by employee_no order by create_time desc) as rn
    from data_smartorder.dm_copy_pdw_opc_roster_motor_shop_relation_view
    where dt = '${today-1}'
    and delete_ts = 0
    and end_date >= to_date(from_unixtime(unix_timestamp(dt,'yyyyMMdd')))
    ) a
    where rn = 1
    ) t5 on t1.staff_code = lpad(t5.employee_no,8,'10') --带店机动队(店长/店副/陪跑店长/陪跑店副)
    and t1.dt = t5.dt
    left join data_smartorder.ods_uploads_business_district_qiyang t6 on t1.store_code = t6.store_code
    left join raw_list t7 on t1.staff_code = lpad(t7.employee_id,8,'10') and t1.dt = t7.dt
    where t1.dt = '${today-1}'
    )

    select
    store_id
    ,sum(case when t1.is_night = 0 then t1.work_hours else 0 end) as day_work_hours --白班工时
    ,sum(case when t1.is_night = 1 then t1.work_hours else 0 end) as night_work_hours --夜班工时
    ,sum(t1.work_hours) as work_hours --总工时

    ,sum(case when (t2.hps_d_jobcode = '学生PT' and t2.post_name = '店员' and t1.is_night = 0)
    or (t2.hps_d_jobcode = '学生PT+早入职' and t2.post_name = '店员' and t1.is_night = 0) 
    then t1.work_hours else 0 end) as day_work_hours_student_pt --白班学生PT工时

    ,sum(case when (t2.hps_d_jobcode = '学生PT' and t2.post_name = '店员' and t1.is_night = 1)
    or (t2.hps_d_jobcode = '学生PT+早入职' and t2.post_name = '店员' and t1.is_night = 1) 
    then t1.work_hours else 0 end) as night_work_hours_student_pt --夜班学生PT工时

    ,sum(case when (t2.hps_d_jobcode = '学生PT' and t2.post_name = '店员')
    or (t2.hps_d_jobcode = '学生PT+早入职' and t2.post_name = '店员') 
    then t1.work_hours else 0 end) as work_hours_student_pt --学生PT总工时

    from data_build.dw_roster_effect_roster_detail_info_da_view t1
    left join staff_list t2 on t1.employee_id = t2.staff_code
    left join (
    select distinct 
    store_code
    from data_build.pdw_bach_baseinfo_shop_shop
    where dt = '${today-1}'
    and self_take_type = '4' --加盟店
    ) t3 on t1.store_id = t3.store_code
    where t1.dt = '${today}'
    and
    t1.work_date between '2025-08-04' and '2025-08-10' --本周
    and (t1.class_id in ('0') or t1.attr_id = '344')
    and t1.store_type_desc = '门店'
    and t1.store_type = '0'
    and t3.store_code is null --只统计直营店
    group by
    store_id
END;



学生PT单独当夜班的门店
学生PT单独当夜班的工时占总学生工时占比
以上门店落表，但凡在表中门店夜班P等级需要到P5
--data_shop.dwd_difficulty_night_store_list_da
BEGIN --更新入职日期
    with a_list as( --更新入职日期，防止换签导致的入职日期刷新
    select
    dt
    ,emplid
    ,leave_dt
    ,case when leave_dt is null then 0 else 1 end as add_num
    from data_build.pdw_psprod_ps_blf_ehr_pers_vw_view
    where dt >= 20210318
    ),

    b_list as( --更新入职日期，防止换签导致的入职日期刷新
    select
    dt
    ,emplid
    ,leave_dt
    ,sum(add_num) over(partition by emplid order by concat(dt,emplid) desc) as sum_num
    from a_list
    ),

    c_list as( --更新入职日期，防止换签导致的入职日期刷新
    select
    dt
    ,emplid
    ,leave_dt
    ,sum_num
    ,max(leave_dt) over(partition by concat(emplid,sum_num) order by concat(dt,emplid) desc) as final_leave_dt
    from b_list
    ),

    leave_list as( --更新入职日期，防止换签导致的入职日期刷新
    select
    dt
    ,if(length(t1.emplid)=6,concat('10',t1.emplid),t1.emplid) as employee_id
    ,case when final_leave_dt is null then '2035-12-31' else final_leave_dt end as leave_dt
    from c_list t1
    ),

    staff_list_1 as( --更新入职日期，防止换签导致的入职日期刷新
    select
    dt
    ,new_dt
    ,store_code
    ,emplid
    ,employee_id
    ,name
    ,hps_hire_dt
    ,leave_dt
    ,hps_d_hr_status
    ,hps_hire_type
    ,hps_d_jobcode
    ,hps_dept_descr_lv1
    ,hps_d_city
    ,hps_dept_code_lv5
    ,hps_dept_descr_lv5
    ,row_number() over(partition by employee_id order by dt) as rn_1 --按照人*时间排序
    ,dense_rank() over(partition by employee_id order by leave_dt) as rn_2 --第几次在职
    ,min(hps_hire_dt) over(partition by concat(employee_id,dense_rank() over(partition by employee_id order by leave_dt)) order by hps_hire_dt) as hps_hire_date
    ,case when hps_d_hr_status = '离职' then '离职' else 
    datediff(new_dt,min(hps_hire_dt) over(partition by concat(employee_id,dense_rank() over(partition by employee_id order by leave_dt)) order by hps_hire_dt))
    end as hire_date_num
    from
    (
    select
    t1.dt
    ,from_unixtime(unix_timestamp(t1.dt,'yyyyMMdd'),'yyyy-MM-dd') as new_dt
    ,t1.hps_dept_code_lv5 as store_code
    ,t1.emplid
    ,if(length(t1.emplid)=6,concat('10',t1.emplid),t1.emplid) as employee_id
    ,name
    ,t1.hps_hire_dt
    ,t3.leave_dt
    ,case when t3.leave_dt = '2035-12-31' then '在职'
    when t3.leave_dt >= from_unixtime(unix_timestamp(t1.dt,'yyyyMMdd'),'yyyy-MM-dd') then '在职'
    else '离职' end as hps_d_hr_status --在离职状态
    ,t1.hps_hire_type --用工形式
    ,t1.hps_d_jobcode
    ,t1.hps_dept_descr_lv1
    ,t1.hps_d_city
    ,t1.hps_dept_code_lv5
    ,t1.hps_dept_descr_lv5
    from data_build.pdw_psprod_ps_blf_ehr_pers_vw_view t1
    left join leave_list t3 on if(length(t1.emplid)=6,concat('10',t1.emplid),t1.emplid) = t3.employee_id and t1.dt = t3.dt
    where t1.dt >= 20210318
    ) a
    ),

    raw_list as( --更新入职日期，防止换签导致的入职日期刷新
    select
    t.dt
    ,t.new_dt --日期
    ,t.store_code --门店编码
    ,t.emplid
    ,t.employee_id
    ,t.name
    ,t.hps_hire_dt --系统雇佣时间(没用)
    ,t.leave_dt --离职日期
    ,t.hps_d_hr_status --在离职状态
    ,t.hps_hire_type
    ,t.hps_d_jobcode
    ,t.hps_dept_descr_lv1
    ,t.hps_d_city
    ,t.hps_dept_code_lv5
    ,t.hps_dept_descr_lv5
    ,t.rn_1 --按照人*时间维度排序
    ,t.rn_2 --第几次入职
    ,t.hps_hire_date --本次雇佣周期开始日期(真实的入职日期)
    ,t.hire_date_num --本次雇佣周期时长
    from staff_list_1 t
    )

    ,staff_list as(
    select
    t1.dt as record_dt
    ,t1.*
    ,case when t1.student_suspect = '1' and to_date(hps_hire_date) < '2025-05-01' then '疑似学生PT+早入职' else t1.student_suspect end as student_suspect_new
    ,case when t2.hps_d_jobcode = '学生PT' and to_date(hps_hire_date) < '2025-05-01' then '学生PT+早入职' else t2.hps_d_jobcode end as hps_d_jobcode
    ,t2.hps_sys_name
    ,t2.hps_dept_code_lv5
    ,t2.hps_dept_descr_lv5
    ,t7.hps_hire_date --真实入职日期
    ,case when t3.manager_code is not null and (t2.hps_dept_descr_lv5 not like '%区X%' or t2.hps_dept_descr_lv1 not in ('运营管理部X'))
    and t2.hps_d_jobcode not in ('外部合作辅助人','外部合作经营者','外部合作伙伴','内部合作辅助人','内部合作经营者','内部合作伙伴') then '店经理'
    when t2.hps_d_jobcode = '店副经理' then '店副经理'
    when t4.employee_id is not null and (t2.hps_dept_descr_lv5 like '%区X%' or t2.hps_dept_descr_lv1 in ('运营管理部X')) then '机动队带店店长'
    when t5.employee_no is not null and (t2.hps_dept_descr_lv5 like '%区X%' or t2.hps_dept_descr_lv1 in ('运营管理部X'))  then t5.relation_type
    when t2.hps_dept_descr_lv5 like '%区X%' or t2.hps_dept_descr_lv1 in ('运营管理部X') then '机动队队员'
    when t2.hps_d_jobcode not in ('外部合作辅助人','外部合作经营者','外部合作伙伴','内部合作辅助人','内部合作经营者','内部合作伙伴') then '店员'
    else '加盟人员' end as post_name
    from data_shop.dm_shop_staff_protect_tag_v2 t1
    left join data_build.pdw_psprod_ps_blf_ehr_pers_vw_view t2 on t1.staff_code = lpad(t2.emplid,8,'10') and t2.dt = t1.dt --hps_d_jobcode in ('店副经理')
    left join data_build.pdw_opc_shop_ehr_staff_dept_view t3 on t2.hps_dept_code_lv5 = t3.dept_code and lpad(t2.emplid,8,'10') = lpad(t3.manager_code,8,'10') and t3.dt = t1.dt --店长
    left join data_build.dwd_store_construction_district_manager_base_info0_di t4 on t1.staff_code = t4.employee_id
    and t4.dt = '${today-2}'
    left join (select
    * from(
    select 
    employee_no,
    shop_code,
    relation_type,
    dt,
    row_number() over(partition by employee_no order by create_time desc) as rn
    from data_smartorder.dm_copy_pdw_opc_roster_motor_shop_relation_view
    where dt = '${today-1}'
    and delete_ts = 0
    and end_date >= to_date(from_unixtime(unix_timestamp(dt,'yyyyMMdd')))
    ) a
    where rn = 1
    ) t5 on t1.staff_code = lpad(t5.employee_no,8,'10') --带店机动队(店长/店副/陪跑店长/陪跑店副)
    and t1.dt = t5.dt
    left join data_smartorder.ods_uploads_business_district_qiyang t6 on t1.store_code = t6.store_code
    left join raw_list t7 on t1.staff_code = lpad(t7.employee_id,8,'10') and t1.dt = t7.dt
    where t1.dt = '${today-1}'
    )

    ,raw_list_1 as(
    select
    case when dayofweek(from_unixtime(unix_timestamp(t1.dt, 'yyyyMMdd'), 'yyyy-MM-dd')) in ('2','3','4') --周一周二周三
    then date_sub(next_day(from_unixtime(unix_timestamp(t1.dt, 'yyyyMMdd'), 'yyyy-MM-dd'),'mon'),7) --本周一
    else next_day(from_unixtime(unix_timestamp(t1.dt, 'yyyyMMdd'), 'yyyy-MM-dd'),'mon') end --下周一
    as week_date

    ,store_id
    ,sum(case when t1.is_night = 0 then t1.work_hours else 0 end) as day_work_hours --白班工时
    ,sum(case when t1.is_night = 1 then t1.work_hours else 0 end) as night_work_hours --夜班工时
    ,sum(t1.work_hours) as work_hours --总工时

    ,sum(case when (t2.hps_d_jobcode = '学生PT' and t2.post_name = '店员' and t1.is_night = 0)
    or (t2.hps_d_jobcode = '学生PT+早入职' and t2.post_name = '店员' and t1.is_night = 0) 
    then t1.work_hours else 0 end) as day_work_hours_student_pt --白班学生PT工时

    ,sum(case when (t2.hps_d_jobcode = '学生PT' and t2.post_name = '店员' and t1.is_night = 1)
    or (t2.hps_d_jobcode = '学生PT+早入职' and t2.post_name = '店员' and t1.is_night = 1) 
    then t1.work_hours else 0 end) as night_work_hours_student_pt --夜班学生PT工时

    ,sum(case when (t2.hps_d_jobcode = '学生PT' and t2.post_name = '店员')
    or (t2.hps_d_jobcode = '学生PT+早入职' and t2.post_name = '店员') 
    then t1.work_hours else 0 end) as work_hours_student_pt --学生PT总工时

    from data_build.dw_roster_effect_roster_detail_info_da_view t1
    left join staff_list t2 on t1.employee_id = t2.staff_code
    left join (
    select distinct 
    store_code
    from data_build.pdw_bach_baseinfo_shop_shop
    where dt = '${today-1}'
    and self_take_type = '4' --加盟店
    ) t3 on t1.store_id = t3.store_code
    where t1.dt = '${today}'
    and
    case when dayofweek(from_unixtime(unix_timestamp(t1.dt, 'yyyyMMdd'), 'yyyy-MM-dd')) in ('2','3','4') --周一周二周三
    then t1.work_date between date_sub(next_day(from_unixtime(unix_timestamp(t1.dt, 'yyyyMMdd'), 'yyyy-MM-dd'),'mon'),7) and date_sub(next_day(from_unixtime(unix_timestamp(t1.dt, 'yyyyMMdd'), 'yyyy-MM-dd'),'mon'),1) --本周
    else t1.work_date between next_day(from_unixtime(unix_timestamp(t1.dt, 'yyyyMMdd'), 'yyyy-MM-dd'),'mon') and date_add(next_day(from_unixtime(unix_timestamp(t1.dt, 'yyyyMMdd'), 'yyyy-MM-dd'),'mon'),6) --下周
    end
    and (t1.class_id in ('0') or t1.attr_id = '344')
    and t1.store_type_desc = '门店'
    and t1.store_type = '0'
    and t3.store_code is null --只统计直营店
    group by
    case when dayofweek(from_unixtime(unix_timestamp(t1.dt, 'yyyyMMdd'), 'yyyy-MM-dd')) in ('2','3','4') --周一周二周三
    then date_sub(next_day(from_unixtime(unix_timestamp(t1.dt, 'yyyyMMdd'), 'yyyy-MM-dd'),'mon'),7) --本周一
    else next_day(from_unixtime(unix_timestamp(t1.dt, 'yyyyMMdd'), 'yyyy-MM-dd'),'mon') end
    ,store_id
    )

    select
    t0.week_date
    ,t0.store_id
    ,t1.store_name
    ,t1.city_name
    ,t0.night_work_hours --门店夜班工时
    ,t0.night_work_hours_student_pt --门店学生PT夜班工时
    ,t1.hc_night --夜班hc
    ,t1.gap_night --夜班gap去低
    ,t1.gap_night_withoutlow --夜班gap实际
    ,t1.reward_level_night --夜班P等级
    ,case when t1.hc_night > 0 and hc_night = gap_night_withoutlow and nvl(t0.night_work_hours_student_pt,0)/nvl(t0.night_work_hours,0) > 0.4 and gap_night > 0 then '夜班学生占比高+无夜班'
    when t1.hc_night > 0 and hc_night = gap_night_withoutlow and substr(t1.reward_level_night,2,1) > 4 then '无夜班'
    when nvl(t0.night_work_hours_student_pt,0)/nvl(t0.night_work_hours,0) > 0.4 and gap_night > 0 then '夜班学生占比高'
    else '非攻坚' end as store_type
    from raw_list_1 t0
    left join data_build.dwd_store_construction_store_groups_recruit_gap t1 on t0.store_id = t1.store_code and t1.dt = '${today-1}'
END;


学生PT本店和跨店的工时占比
BEGIN --更新入职日期
    with a_list as( --更新入职日期，防止换签导致的入职日期刷新
    select
    dt
    ,emplid
    ,leave_dt
    ,case when leave_dt is null then 0 else 1 end as add_num
    from data_build.pdw_psprod_ps_blf_ehr_pers_vw_view
    where dt >= 20210318
    ),

    b_list as( --更新入职日期，防止换签导致的入职日期刷新
    select
    dt
    ,emplid
    ,leave_dt
    ,sum(add_num) over(partition by emplid order by concat(dt,emplid) desc) as sum_num
    from a_list
    ),

    c_list as( --更新入职日期，防止换签导致的入职日期刷新
    select
    dt
    ,emplid
    ,leave_dt
    ,sum_num
    ,max(leave_dt) over(partition by concat(emplid,sum_num) order by concat(dt,emplid) desc) as final_leave_dt
    from b_list
    ),

    leave_list as( --更新入职日期，防止换签导致的入职日期刷新
    select
    dt
    ,if(length(t1.emplid)=6,concat('10',t1.emplid),t1.emplid) as employee_id
    ,case when final_leave_dt is null then '2035-12-31' else final_leave_dt end as leave_dt
    from c_list t1
    ),

    staff_list_1 as( --更新入职日期，防止换签导致的入职日期刷新
    select
    dt
    ,new_dt
    ,store_code
    ,emplid
    ,employee_id
    ,name
    ,hps_hire_dt
    ,leave_dt
    ,hps_d_hr_status
    ,hps_hire_type
    ,hps_d_jobcode
    ,hps_dept_descr_lv1
    ,hps_d_city
    ,hps_dept_code_lv5
    ,hps_dept_descr_lv5
    ,row_number() over(partition by employee_id order by dt) as rn_1 --按照人*时间排序
    ,dense_rank() over(partition by employee_id order by leave_dt) as rn_2 --第几次在职
    ,min(hps_hire_dt) over(partition by concat(employee_id,dense_rank() over(partition by employee_id order by leave_dt)) order by hps_hire_dt) as hps_hire_date
    ,case when hps_d_hr_status = '离职' then '离职' else 
    datediff(new_dt,min(hps_hire_dt) over(partition by concat(employee_id,dense_rank() over(partition by employee_id order by leave_dt)) order by hps_hire_dt))
    end as hire_date_num
    from
    (
    select
    t1.dt
    ,from_unixtime(unix_timestamp(t1.dt,'yyyyMMdd'),'yyyy-MM-dd') as new_dt
    ,t1.hps_dept_code_lv5 as store_code
    ,t1.emplid
    ,if(length(t1.emplid)=6,concat('10',t1.emplid),t1.emplid) as employee_id
    ,name
    ,t1.hps_hire_dt
    ,t3.leave_dt
    ,case when t3.leave_dt = '2035-12-31' then '在职'
    when t3.leave_dt >= from_unixtime(unix_timestamp(t1.dt,'yyyyMMdd'),'yyyy-MM-dd') then '在职'
    else '离职' end as hps_d_hr_status --在离职状态
    ,t1.hps_hire_type --用工形式
    ,t1.hps_d_jobcode
    ,t1.hps_dept_descr_lv1
    ,t1.hps_d_city
    ,t1.hps_dept_code_lv5
    ,t1.hps_dept_descr_lv5
    from data_build.pdw_psprod_ps_blf_ehr_pers_vw_view t1
    left join leave_list t3 on if(length(t1.emplid)=6,concat('10',t1.emplid),t1.emplid) = t3.employee_id and t1.dt = t3.dt
    where t1.dt >= 20210318
    ) a
    ),

    raw_list as( --更新入职日期，防止换签导致的入职日期刷新
    select
    t.dt
    ,t.new_dt --日期
    ,t.store_code --门店编码
    ,t.emplid
    ,t.employee_id
    ,t.name
    ,t.hps_hire_dt --系统雇佣时间(没用)
    ,t.leave_dt --离职日期
    ,t.hps_d_hr_status --在离职状态
    ,t.hps_hire_type
    ,t.hps_d_jobcode
    ,t.hps_dept_descr_lv1
    ,t.hps_d_city
    ,t.hps_dept_code_lv5
    ,t.hps_dept_descr_lv5
    ,t.rn_1 --按照人*时间维度排序
    ,t.rn_2 --第几次入职
    ,t.hps_hire_date --本次雇佣周期开始日期(真实的入职日期)
    ,t.hire_date_num --本次雇佣周期时长
    from staff_list_1 t
    )

    ,staff_list as(
    select
    t1.dt as record_dt
    ,t1.*
    ,case when t1.student_suspect = '1' and to_date(hps_hire_date) < '2025-05-01' then '疑似学生PT+早入职' else t1.student_suspect end as student_suspect_new
    ,case when t2.hps_d_jobcode = '学生PT' and to_date(hps_hire_date) < '2025-05-01' then '学生PT+早入职' else t2.hps_d_jobcode end as hps_d_jobcode
    ,t2.hps_sys_name
    ,t2.hps_dept_code_lv5
    ,t2.hps_dept_descr_lv5
    ,t7.hps_hire_date --真实入职日期
    ,case when t3.manager_code is not null and (t2.hps_dept_descr_lv5 not like '%区X%' or t2.hps_dept_descr_lv1 not in ('运营管理部X'))
    and t2.hps_d_jobcode not in ('外部合作辅助人','外部合作经营者','外部合作伙伴','内部合作辅助人','内部合作经营者','内部合作伙伴') then '店经理'
    when t2.hps_d_jobcode = '店副经理' then '店副经理'
    when t4.employee_id is not null and (t2.hps_dept_descr_lv5 like '%区X%' or t2.hps_dept_descr_lv1 in ('运营管理部X')) then '机动队带店店长'
    when t5.employee_no is not null and (t2.hps_dept_descr_lv5 like '%区X%' or t2.hps_dept_descr_lv1 in ('运营管理部X'))  then t5.relation_type
    when t2.hps_dept_descr_lv5 like '%区X%' or t2.hps_dept_descr_lv1 in ('运营管理部X') then '机动队队员'
    when t2.hps_d_jobcode not in ('外部合作辅助人','外部合作经营者','外部合作伙伴','内部合作辅助人','内部合作经营者','内部合作伙伴') then '店员'
    else '加盟人员' end as post_name
    from data_shop.dm_shop_staff_protect_tag_v2 t1
    left join data_build.pdw_psprod_ps_blf_ehr_pers_vw_view t2 on t1.staff_code = lpad(t2.emplid,8,'10') and t2.dt = t1.dt --hps_d_jobcode in ('店副经理')
    left join data_build.pdw_opc_shop_ehr_staff_dept_view t3 on t2.hps_dept_code_lv5 = t3.dept_code and lpad(t2.emplid,8,'10') = lpad(t3.manager_code,8,'10') and t3.dt = t1.dt --店长
    left join data_build.dwd_store_construction_district_manager_base_info0_di t4 on t1.staff_code = t4.employee_id
    and t4.dt = '${today-2}'
    left join (select
    * from(
    select 
    employee_no,
    shop_code,
    relation_type,
    dt,
    row_number() over(partition by employee_no order by create_time desc) as rn
    from data_smartorder.dm_copy_pdw_opc_roster_motor_shop_relation_view
    where dt = '${today-1}'
    and delete_ts = 0
    and end_date >= to_date(from_unixtime(unix_timestamp(dt,'yyyyMMdd')))
    ) a
    where rn = 1
    ) t5 on t1.staff_code = lpad(t5.employee_no,8,'10') --带店机动队(店长/店副/陪跑店长/陪跑店副)
    and t1.dt = t5.dt
    left join data_smartorder.ods_uploads_business_district_qiyang t6 on t1.store_code = t6.store_code
    left join raw_list t7 on t1.staff_code = lpad(t7.employee_id,8,'10') and t1.dt = t7.dt
    where t1.dt = '${today-1}'
    )

    select
    store_id

    ,sum(t1.work_hours) as work_hours --总工时

    ,sum(case when (t2.hps_d_jobcode = '学生PT' and t2.post_name = '店员' and store_id = t2.store_code)
    or (t2.hps_d_jobcode = '学生PT+早入职' and t2.post_name = '店员' and store_id = t2.store_code) 
    then t1.work_hours else 0 end) as base_work_hours_student_pt --本店学生PT总工时

    ,sum(case when (t2.hps_d_jobcode = '学生PT' and t2.post_name = '店员' and store_id <> t2.store_code)
    or (t2.hps_d_jobcode = '学生PT+早入职' and t2.post_name = '店员' and store_id <> t2.store_code) 
    then t1.work_hours else 0 end) as other_work_hours_student_pt --跨店学生PT总工时

    from data_build.dw_roster_effect_roster_detail_info_da_view t1
    left join staff_list t2 on t1.employee_id = t2.staff_code
    left join (
    select distinct 
    store_code
    from data_build.pdw_bach_baseinfo_shop_shop
    where dt = '${today-1}'
    and self_take_type = '4' --加盟店
    ) t3 on t1.store_id = t3.store_code
    where t1.dt = '${today}'
    and
    t1.work_date between '2025-08-11' and '2025-08-17' 
    and (t1.class_id in ('0') or t1.attr_id = '344')
    and t1.store_type_desc = '门店'
    and t1.store_type = '0'
    and t3.store_code is null --只统计直营店
    group by
    store_id
END;
