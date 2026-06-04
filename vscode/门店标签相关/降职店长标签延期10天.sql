--降职店长标签延期10天（永久降职和暂时降职都算）
--data_build.dwd_store_mgr_protect_tag_last_ten_da
--门店降职流程
with order_flow_main as(
select
order_id --流程编码(流程信息)
,order_status --流程状态(流程信息)
,initiator_code --发起人编码(流程信息)
,create_time --流程发起时间(流程信息)
,flow_ame --流程名称(流程信息)
,org_code --门店编码(流程信息)
,org_name --门店名称(流程信息)
from data_build.pdw_order_store_211_order_detail_flow_main
where dt = '${today-1}'
and flow_code = '032134' --流程code
),

order_flow_groups as(
select
order_id
,max(typeofdemote) as typeofdemote --申请降职类型
,max(shopCode) as shopCode --value门店编码
,max(shopName) as shopName --label门店名称
,max(whentoendstart) as whentoendstart --降职的开始时间
,max(whentoend) as whentoend --降职的结束时间
,max(agent) as agent --降职期间是否已找好代理店经理
,max(agentwho) as agentwho --降职期间代理店经理
,max(des) as des --降职原因
from(
select --主表单信息
order_id --流程编码
,case when form_name = 'typeofdemote' then get_json_object(get_json_object(form_values,'$.[0]'),'$.value') else null end as typeofdemote --申请降职类型
,case when form_name = 'shopCode' then get_json_object(get_json_object(form_values,'$.[0]'),'$.value') else null end as shopCode --value门店编码
,case when form_name = 'shopCode' then get_json_object(get_json_object(form_values,'$.[0]'),'$.label') else null end as shopName --label门店名称
,case when form_name = 'whentoendstart' then get_json_object(get_json_object(form_values,'$.[0]'),'$.value') else null end as whentoendstart --降职的开始时间
,case when form_name = 'whentoend' then get_json_object(get_json_object(form_values,'$.[0]'),'$.value') else null end as whentoend --降职的结束时间
,case when form_name = 'agent' then get_json_object(get_json_object(form_values,'$.[0]'),'$.value') else null end as agent --降职期间是否已找好代理店经理
,case when form_name = 'agentwho' then get_json_object(get_json_object(form_values,'$.[0]'),'$.value') else null end as agentwho --降职期间代理店经理
,case when form_name = 'des' then get_json_object(get_json_object(form_values,'$.[0]'),'$.value') else null end as des --降职原因
from data_build.pdw_order_store_211_order_detail_flow_form_variable_groups_da
where dt = '${today-1}'
--and order_id = '2110156450344230'
) a
group by
order_id
),

order_flow_taskorders as(
select
order_id
,max(middleground_manage_label) as middleground_manage_label
,max(middleground_mobile) as middleground_mobile
,max(middleground_temporary_manage_label) as middleground_temporary_manage_label
,max(middleground_protect) as middleground_protect
,max(middleground_ontinme) as middleground_ontinme
,max(middleground_give) as middleground_give
,max(middleground_return_protect) as middleground_return_protect
,max(commissar_blocked) as commissar_blocked
from(
select
order_id
,taskorder_node_id
,element
,case when taskorder_node_id = 'UserTask_1tbwabs' and get_json_object(element,'$.name') = 'Storeownertag' then get_json_object(get_json_object(element,'$.values'),'$.value') else null end as middleground_manage_label--中台审核条件(店经理降职前标签)
,case when taskorder_node_id = 'UserTask_1tbwabs' and get_json_object(element,'$.name') = 'protect9' then get_json_object(get_json_object(element,'$.values'),'$.value') else null end as middleground_mobile--中台审核条件(是否需要机动队挂店)
,case when taskorder_node_id = 'UserTask_1tbwabs' and get_json_object(element,'$.name') = 'agenttag' then get_json_object(get_json_object(element,'$.values'),'$.value') else null end as middleground_temporary_manage_label--中台审核条件(代理店经理当前标签)
,case when taskorder_node_id = 'UserTask_1tbwabs' and get_json_object(element,'$.name') = 'protect' then get_json_object(get_json_object(element,'$.values'),'$.value') else null end as middleground_protect--中台审核条件(是否符合降职保护条件)

,case when taskorder_node_id = 'UserTask_0xiz2zo' and get_json_object(element,'$.name') = 'backtostore' then get_json_object(get_json_object(element,'$.values'),'$.value') else null end as middleground_ontinme--中台确认返岗(原店经理是否在降职结束时间如期返岗)
,case when taskorder_node_id = 'UserTask_0xiz2zo' and get_json_object(element,'$.name') = 'backtostore2' then get_json_object(get_json_object(element,'$.values'),'$.value') else null end as middleground_give--中台确认返岗(原店经理是否在降职结束时间次周给班5天及以上)
,case when taskorder_node_id = 'UserTask_0xiz2zo' and get_json_object(element,'$.name') = 'result' then get_json_object(get_json_object(element,'$.values'),'$.value') else null end as middleground_return_protect--中台确认返岗(标签保护是否生效)

,case when taskorder_node_id = 'UserTask_12fej7c' and get_json_object(element,'$.name') = 'blocked' then get_json_object(get_json_object(element,'$.values'),'$.value') else null end as commissar_blocked --政委确认加入晋升黑名单
from(
select
order_id
,taskorder_node_id
,task_orders
,row_number() over(partition by concat(order_id,taskorder_node_id) order by taskorder_create_time desc) as rn
from data_build.pdw_order_store_211_order_detail_flow_task_taskorders
where dt = '${today-1}'
--and order_id = '2110156450344230'
and taskorder_result = 'AGREE'
and taskorder_status = 'FINISHED'
and (taskorder_node_id = 'UserTask_1tbwabs' or taskorder_node_id = 'UserTask_0xiz2zo' or taskorder_node_id = 'UserTask_12fej7c')
) a
lateral view
explode(split(regexp_replace(regexp_replace(task_orders, '\\\\[|\\\\]' , ''), '\\\\}\\\\,\\\\{' , '\\\\}\\\\&\\\\{'), '&')) x1 as element
where rn = 1
) b
group by
order_id
),

demotion_list as(
select
a.order_id as task_order_id
,a.order_status
,a.initiator_code
,a.create_time
,a.flow_ame
,a.org_code
,a.org_name
,b.order_id as task_order_id_b
,b.typeofdemote
,b.shopcode
,b.shopname
,b.whentoendstart
,b.whentoend
,b.agent
,b.agentwho
,b.des
,c.order_id as task_order_id_c
,c.middleground_manage_label
,c.middleground_mobile
,c.middleground_temporary_manage_label
,c.middleground_protect
,c.middleground_ontinme
,c.middleground_give
,c.middleground_return_protect
,c.commissar_blocked
from order_flow_main a
left join order_flow_groups b on a.order_id = b.order_id
left join order_flow_taskorders c on a.order_id = c.order_id
),

-- 架构基础
Structure_Base as
(
    select concat(substr(dt,1,4),'-',substr(dt,5,2),'-',substr(dt,7,2)) as roster_date,
        dept_name,
        dept_code,
        manager_code,
        manager_name,
        p_code,
        shop_sign,
        dept_type,
        hrbp_code,
        hrbp_name
    from data_shop.pdw_opc_shop_ehr_staff_dept_view --组织架构信息
    where dt >= '20240101'
        and dept_type in ('20','30','40','50','60')
),

Store_Structure as
(
    select concat(substr(dt,1,4),'-',substr(dt,5,2),'-',substr(dt,7,2)) as roster_date,
        dept_code,
        split(code_path,'/')[6] as bz_code,
        split(code_path,'/')[5] as zone_code,
        split(code_path,'/')[4] as city_zone_code,
        split(code_path,'/')[3] as bu_code
    from data_shop.pdw_opc_shop_ehr_staff_dept_view --组织架构信息
    where dt >= '20240101'
        and dept_type in ('60')
        and shop_sign=1
),

-- 员工岗位
Staff_Info as
(
    select concat(substr(dt,1,4),'-',substr(dt,5,2),'-',substr(dt,7,2)) as roster_date,
        emplid as staff_code,
        hps_d_jobcode as job
    from data_build.pdw_psprod_ps_blf_ehr_pers_vw_view
    where dt >= '20240101'
),

-- 店基础信息2
Store_Info as
(
    select concat(substr(dt,1,4),'-',substr(dt,5,2),'-',substr(dt,7,2)) as roster_date,
        store_code,
        store_city,
        if(store_status_desc in ('营业','暂停营业'),'已开业',store_status_desc) as store_status_desc,
        cast(to_date(project_handover_time) as string) as handover_date,
        cast(to_date(original_openning_date) as string) as store_opening_date,
        withdraw_date
    from data_smartorder.dw_ordering_store_tag_location_ranking_info_v1
    where dt >= '20240101'
        and operate_type is not null
        and store_type_desc='门店'
),

-- 门店类型
Store_Type as
(
    select store_code,
        store_type
    from data_smartorder.ods_uploads_store_type_information_table
    group by store_code,
        store_type
),

final_list as(
select zz.roster_date,
    zz.store_code,
    zz.store_name,
    if(length(zz.store_mgr_code)=6,concat('10',zz.store_mgr_code),zz.store_mgr_code) as store_mgr_code,
    zz.store_mgr_name,
    zz.job,
    zz.store_city,
    zz.store_type,
    zz.operation_dept as bu,
    if(length(zz.bz_mgr_code)=6,concat('10',zz.bz_mgr_code),zz.bz_mgr_code) as bz_mgr_code,
    zz.bz_mgr_name,
    if(length(zz.zone_mgr_code)=6,concat('10',zz.zone_mgr_code),zz.zone_mgr_code) as zone_mgr_code,
    zz.zone_mgr_name,
    if(length(zz.city_zone_mgr_code)=6,concat('10',zz.city_zone_mgr_code),zz.city_zone_mgr_code) as city_zone_mgr_code,
    zz.city_zone_mgr_name,
    if(length(zz.hrbp_code)=6,concat('10',zz.hrbp_code),zz.hrbp_code) as hrbp_code,
    zz.hrbp_name,
    zz.store_status_desc,
    zz.handover_date,
    zz.store_opening_date,
    zz.withdraw_date,
    case when if(length(zz.store_mgr_code)=6,concat('10',zz.store_mgr_code),zz.store_mgr_code) = lag(if(length(zz.store_mgr_code)=6,concat('10',zz.store_mgr_code),zz.store_mgr_code)) over (order by concat(zz.store_code,zz.roster_date)) then 0 else 1 end as rn
from
(
    select aa.roster_date,
        bb.dept_code as store_code,
        bb.dept_name as store_name,
        if(gg.store_status_desc='停业','',bb.manager_code) as store_mgr_code,
        if(gg.store_status_desc='停业','',bb.manager_name) as store_mgr_name,
        if(gg.store_status_desc='停业','',ii.job) as job,
        gg.store_city,
        if(hh.store_type is null or gg.store_status_desc='停业','',hh.store_type) as store_type,
        if(gg.store_status_desc='停业','',ff.dept_name) as operation_dept,
        if(gg.store_status_desc='停业','',cc.manager_code) as bz_mgr_code,
        if(gg.store_status_desc='停业','',cc.manager_name) as bz_mgr_name,
        if(gg.store_status_desc='停业','',dd.manager_code) as zone_mgr_code,
        if(gg.store_status_desc='停业','',dd.manager_name) as zone_mgr_name,
        if(gg.store_status_desc='停业','',ee.manager_code) as city_zone_mgr_code,
        if(gg.store_status_desc='停业','',ee.manager_name) as city_zone_mgr_name,
        if(gg.store_status_desc='停业','',ff.manager_code) as bu_mgr_code,
        if(gg.store_status_desc='停业','',ff.manager_name) as bu_mgr_name,
        if(gg.store_status_desc='停业','',bb.hrbp_code) as hrbp_code,
        if(gg.store_status_desc='停业','',bb.hrbp_name) as hrbp_name,
        if(gg.store_status_desc='停业','',ff.hrbp_code) as hrbpld_code,
        if(gg.store_status_desc='停业','',ff.hrbp_name) as hrbpld_name,
        gg.store_status_desc,
        gg.handover_date,
        if(gg.store_status_desc='停业','',gg.store_opening_date) as store_opening_date,
        gg.withdraw_date
    from
    Store_Structure aa
    join
    Structure_Base bb
    on aa.roster_date=bb.roster_date
        and aa.dept_code=bb.dept_code
    left outer join
    Structure_Base cc
    on aa.roster_date=cc.roster_date
        and aa.bz_code=cc.dept_code
    left outer join
    Structure_Base dd
    on aa.roster_date=dd.roster_date
        and aa.zone_code=dd.dept_code
    left outer join
    Structure_Base ee
    on aa.roster_date=ee.roster_date
        and aa.city_zone_code=ee.dept_code
    left outer join
    Structure_Base ff
    on aa.roster_date=ff.roster_date
        and aa.bu_code=ff.dept_code
    join
    Store_Info gg
    on aa.roster_date=gg.roster_date
        and aa.dept_code=gg.store_code
    left outer join
    Store_Type hh
    on aa.dept_code=hh.store_code
    left outer join
    Staff_Info ii
    on aa.roster_date=ii.roster_date
        and bb.manager_code=ii.staff_code
    group by aa.roster_date,
        bb.dept_code,
        bb.dept_name,
        if(gg.store_status_desc='停业','',bb.manager_code),
        if(gg.store_status_desc='停业','',bb.manager_name),
        if(gg.store_status_desc='停业','',ii.job),
        gg.store_city,
        if(hh.store_type is null or gg.store_status_desc='停业','',hh.store_type),
        if(gg.store_status_desc='停业','',ff.dept_name),
        if(gg.store_status_desc='停业','',cc.manager_code),
        if(gg.store_status_desc='停业','',cc.manager_name),
        if(gg.store_status_desc='停业','',dd.manager_code),
        if(gg.store_status_desc='停业','',dd.manager_name),
        if(gg.store_status_desc='停业','',ee.manager_code),
        if(gg.store_status_desc='停业','',ee.manager_name),
        if(gg.store_status_desc='停业','',ff.manager_code),
        if(gg.store_status_desc='停业','',ff.manager_name),
        if(gg.store_status_desc='停业','',bb.hrbp_code),
        if(gg.store_status_desc='停业','',bb.hrbp_name),
        if(gg.store_status_desc='停业','',ff.hrbp_code),
        if(gg.store_status_desc='停业','',ff.hrbp_name),
        gg.store_status_desc,
        gg.handover_date,
        if(gg.store_status_desc='停业','',gg.store_opening_date),
        gg.withdraw_date
) zz
where zz.operation_dept<>'运营管理部X'
),

leave_date_list as(
select
store_code
,store_mgr_code
,store_mgr_name
,rn
,max(roster_date) as leave_date
from(
select
roster_date
,store_code
,store_mgr_code
,store_mgr_name
,sum(rn) over(partition by store_code order by roster_date) as rn
from final_list
) a
group by
store_code
,store_mgr_code
,store_mgr_name
,rn
)

select
t0.roster_date,
t0.store_code,
t0.store_name,
t0.store_mgr_code,
t0.store_mgr_name,
t0.job,
t0.store_city,
t0.store_status_desc
,t1.leave_date --离店日期
,t1.store_mgr_code as mgr_code--离店人
,t1.store_mgr_name as mgr_name --离店人姓名
,case when t1.leave_date <= t0.roster_date then datediff(t0.roster_date,t1.leave_date) else null end as leave_days --离店时长
,t2.will_score --意愿度得分
,case when t3.performance_score is null then t2.performance_score else t3.performance_score end as performance_score --个人能力总分 --如果当天没有得分，可能是城市总接店，分数取离店前最后一天结果(下同)
,case when t3.store_score is null then t2.store_score else t3.store_score end as store_score --门店质量总分
,case when t3.manage_score is null then t2.manage_score else t3.manage_score end as manage_score --团队管理总分
,case when t3.work_level_score is null then t2.work_level_score else t3.work_level_score end as work_level_score --运营难度得分
,t4.task_order_id
,if(length(t4.initiator_code)=6,concat('10',t4.initiator_code),t4.initiator_code) as initiator_code
,t4.shopcode
,t4.typeofdemote
,t2.will_score * 0.3 + case when t3.performance_score is null then t2.performance_score else t3.performance_score end * 0.2 + case when t3.store_score is null then t2.store_score else t3.store_score end * 0.3 
+ case when t3.manage_score is null then t2.manage_score else t3.manage_score end * 0.2 + case when t3.work_level_score is null then t2.work_level_score else t3.work_level_score end as total_score
,case when 
t2.will_score * 0.3 + case when t3.performance_score is null then t2.performance_score else t3.performance_score end * 0.2 + case when t3.store_score is null then t2.store_score else t3.store_score end * 0.3 
+ case when t3.manage_score is null then t2.manage_score else t3.manage_score end * 0.2 + case when t3.work_level_score is null then t2.work_level_score else t3.work_level_score end >= 4.5 then '钻石'
when t2.will_score * 0.3 + case when t3.performance_score is null then t2.performance_score else t3.performance_score end * 0.2 + case when t3.store_score is null then t2.store_score else t3.store_score end * 0.3 
+ case when t3.manage_score is null then t2.manage_score else t3.manage_score end * 0.2 + case when t3.work_level_score is null then t2.work_level_score else t3.work_level_score end >= 3.8 then '金牌'
when t2.will_score * 0.3 + case when t3.performance_score is null then t2.performance_score else t3.performance_score end * 0.2 + case when t3.store_score is null then t2.store_score else t3.store_score end * 0.3 
+ case when t3.manage_score is null then t2.manage_score else t3.manage_score end * 0.2 + case when t3.work_level_score is null then t2.work_level_score else t3.work_level_score end >= 3 then '银牌'
when t2.will_score * 0.3 + case when t3.performance_score is null then t2.performance_score else t3.performance_score end * 0.2 + case when t3.store_score is null then t2.store_score else t3.store_score end * 0.3 
+ case when t3.manage_score is null then t2.manage_score else t3.manage_score end * 0.2 + case when t3.work_level_score is null then t2.work_level_score else t3.work_level_score end >= 2 then '铜牌'
when t2.will_score * 0.3 + case when t3.performance_score is null then t2.performance_score else t3.performance_score end * 0.2 + case when t3.store_score is null then t2.store_score else t3.store_score end * 0.3 
+ case when t3.manage_score is null then t2.manage_score else t3.manage_score end * 0.2 + case when t3.work_level_score is null then t2.work_level_score else t3.work_level_score end < 2 then '需努力' else null
end as protect_tag
from final_list t0
left join leave_date_list t1 on t0.store_code = t1.store_code
left join data_build.dwd_all_manager_tag_v1_di t2 on t1.leave_date = from_unixtime(unix_timestamp(t2.dt,'yyyyMMdd'),'yyyy-MM-dd') and t0.store_code = t2.store_code and t1.store_mgr_code = t2.employee_id
and t2.dt >= '20240101' --意愿度取离店前最后一天的结果
left join data_build.dwd_all_manager_tag_v1_di t3 on t0.roster_date = from_unixtime(unix_timestamp(t3.dt,'yyyyMMdd'),'yyyy-MM-dd') and t0.store_code = t3.store_code
and t3.dt >= '20240101'
left join demotion_list t4 on t0.store_code = t4.shopcode and t1.store_mgr_code = if(length(t4.initiator_code)=6,concat('10',t4.initiator_code),t4.initiator_code) and t1.leave_date between 
substr(t4.create_time,1,10) and date_add(substr(t4.whentoendstart,1,10),7) --需要和降职流程匹配，因为时间无法准确匹配，按照离店时间在降职流程发起后到流程中反馈降职开始时间+7天之间判断
where case when t1.leave_date <= t0.roster_date then datediff(t0.roster_date,t1.leave_date) else null end between '0' and '10'
and t4.task_order_id is not null --只取发过降职流程任务的数据
and t4.order_status in ('PROCESSING','FINISHED')
and t1.leave_date >= '2024-05-01' --离店日期就是最后工作日，因取数周期问题，从5月1号开始取
and t2.will_score is not null --T-1底表还没刷新得分的先不展示

******************************************************************************************************************************************************************************************

--店长标签日级别表(包含机动队店长，取消第一周豁免) --data_build.dwd_all_manager_tag_v1_di
with 
location_type_list as (
select 
t2.store_code
,max(case when location_type in ('办公+其他','写字楼','办公+居民','居民+办公') then '办公' 
when location_type in ('居民+其他','居民+其它','住宅') then '居民' 
when location_type = '混合' then '其他'
else location_type end) as location_type
from default.dm_site_selection_project_feature_info_di t2 

where t2.dt <= '20221114'
group by t2.store_code
),
work_day_list as(
select
date_key
,is_working_day
,is_holiday
from default.dim_date_ya_v2
where date_key >= '${TODAY-30}'
and date_key <= '${TODAY-1}'
group by
date_key
,is_working_day
,is_holiday
),
staff_list as
(
select
     t1.dt
     ,from_unixtime(unix_timestamp(t1.dt,'yyyyMMdd'),'yyyy-MM-dd') as new_dt
     ,hps_dept_code_lv5 as store_code
     ,if(length(t1.emplid)=6,concat('10',t1.emplid),t1.emplid) as employee_id
     ,hps_d_hr_status
     ,hps_d_jobcode
    from data_build.pdw_psprod_ps_blf_ehr_pers_vw_view t1
    where t1.dt >= '${today-30}' 
    and t1.dt <= '${today-1}' 
    and hps_d_jobcode in ('店经理','储备店经理','见习店经理','门店伙伴','社会PT','学生PT','防疫伙伴','店副经理','内部合作经营者','内部合作辅助人','内部合作伙伴','外部合作经营者','外部合作辅助人','外部合作伙伴')
    and hps_d_hr_status = '在职'
),

staff_list_v3 as -- 用于计算sop
(
select
     t1.dt
     ,from_unixtime(unix_timestamp(t1.dt,'yyyyMMdd'),'yyyy-MM-dd') as new_dt
     ,hps_dept_code_lv5 as store_code
     ,if(length(t1.emplid)=6,concat('10',t1.emplid),t1.emplid) as employee_id
     ,hps_d_hr_status
     ,hps_d_jobcode
    from data_build.pdw_psprod_ps_blf_ehr_pers_vw_view t1
    where t1.dt >= '${today-30}' 
    and hps_d_jobcode in ('店经理','储备店经理','见习店经理','门店伙伴','社会PT','学生PT','防疫伙伴','店副经理','内部合作经营者','内部合作辅助人','内部合作伙伴','外部合作经营者','外部合作辅助人','外部合作伙伴')
    and hps_d_hr_status = '在职'
),

-- 计算周期
base_manager_info as(
select store_code,
employee_id,
name,
store_name,
city_name,
difficulty_level_new,
entry_date,
entry_days,
change_date0,
cal_days_0,
change_date,
cal_days,
start_cdate,
cal_dyas_14,
change_date_14,
b_manager_date,
b_manager_days,
work_dt
from data_build.dwd_store_construction_manager_base_info_vi_v1_di
where dt ='${today-1}' 
),

attend_shift_info0_tmp as 
( --排班工时底表
 select
 if(length(employee_no)<8,concat('10',employee_no),employee_no) as staff_code
 ,employee_no as emplid
 ,month(work_shift_date) as mon_of_attend_date
 ,date_sub(next_day(work_shift_date,'mon'),7) as roster_week
 ,date_format(work_shift_date, 'yyyy-MM-dd') as attend_date
 ,sum(work_shift_hours) as work_shift_hours
 ,sum(attendance_work_hours) as attendance_work_hours
 ,sum(arrive_late_count)/2 as arrive_late_hour
 ,sum(leave_early_count)/2 as leave_early_hour
 ,sum(absenteeism_hours) as absenteeism_hour
 ,floor(sum((unix_timestamp(work_shift_start_time) - unix_timestamp(punch_start_time))) / 3600 / 0.5)/2 as early_arrive_hour
 ,floor(sum((unix_timestamp(punch_end_time) - unix_timestamp(work_shift_end_time))) / 3600 / 0.5)/2 as late_leave_hour
 from default.pdw_opc_shop_attendance_report_work_shift
 where dt = '${today-1}'
 and work_shift_date >= '${TODAY-30}'
 and work_shift_date <= '${TODAY-1}'
 and work_shift_type in (1,9,12)
 group by 
 if(length(employee_no)<8,concat('10',employee_no),employee_no) 
 ,employee_no 
 ,month(work_shift_date)
 ,date_sub(next_day(work_shift_date,'mon'),7)
 ,date_format(work_shift_date, 'yyyy-MM-dd')
),

user_list as(
select
if(length(employee_no)<8,concat('10',employee_no),employee_no) as staff_code --员工工号
,employee_no
,1 as joinkey
from default.pdw_opc_shop_attendance_report_work_shift
where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and date_format(work_shift_date, 'yyyy-MM-dd') >= '${TODAY-30}'
and date_format(work_shift_date, 'yyyy-MM-dd') <= '${TODAY-1}'
and work_shift_type in (1,9,12) --考勤班次类型CODE
group by
if(length(employee_no)<8,concat('10',employee_no),employee_no)
,employee_no
,1
),

hoildays_list as (
select
date_key
,day_of_week
,calendar_year
,is_working_day
,holiday_type
,is_work_day
,case when
rn = 1 then date_add(date_key,-7) else null end as before_seven_day
,case when
rn = 1 then date_add(date_key,-6) else null end as before_six_day
,case when
rn = 1 then date_add(date_key,-5) else null end as before_five_day
,case when
rn = 1 then date_add(date_key,-4) else null end as before_four_day
,case when
rn = 1 then date_add(date_key,-3) else null end as before_three_day
,case when
rn = 1 then date_add(date_key,-2) else null end as before_two_day
,case when
rn = 1 then date_add(date_key,-1) else null end as before_one_day
,case when
rn_1 = 1 then date_add(date_key,7) else null end as after_seven_day
,case when
rn_1 = 1 then date_add(date_key,6) else null end as after_six_day
,case when
rn_1 = 1 then date_add(date_key,5) else null end as after_five_day
,case when
rn_1 = 1 then date_add(date_key,4) else null end as after_four_day
,case when
rn_1 = 1 then date_add(date_key,3) else null end as after_three_day
,case when
rn_1 = 1 then date_add(date_key,2) else null end as after_two_day
,case when
rn_1 = 1 then date_add(date_key,1) else null end as after_one_day
from(
select 
date_key
,day_of_week
,calendar_year
,is_working_day
,holiday_type
,case when day_of_week in ('6','7') and holiday_type = '2' then '1' else is_working_day end as is_work_day
,row_number() over(partition by concat(calendar_year,holiday_type) order by date_key) as rn
,row_number() over(partition by concat(calendar_year,holiday_type) order by date_key desc) as rn_1
from data_build.dim_date_ya_v2
) a
where is_work_day = '0'
),

hoildays_days as(
select
distinct cast(date_key as string) as date_key
from hoildays_list
union all
select
distinct cast(before_seven_day as string) as date_key
from hoildays_list
union all
select
distinct cast(before_six_day as string) as date_key
from hoildays_list
union all
select
distinct cast(before_five_day as string) as date_key
from hoildays_list
union all
select
distinct cast(before_four_day as string) as date_key
from hoildays_list
union all
select
distinct cast(before_three_day as string) as date_key
from hoildays_list
union all
select
distinct cast(before_two_day as string) as date_key
from hoildays_list
union all
select
distinct cast(before_one_day as string) as date_key
from hoildays_list
union all
select
distinct cast(after_seven_day as string) as date_key
from hoildays_list
union all
select
distinct cast(after_six_day as string) as date_key
from hoildays_list
union all
select
distinct cast(after_five_day as string) as date_key
from hoildays_list
union all
select
distinct cast(after_four_day as string) as date_key
from hoildays_list
union all
select
distinct cast(after_three_day as string) as date_key
from hoildays_list
union all
select
distinct cast(after_two_day as string) as date_key
from hoildays_list
union all
select
distinct cast(after_one_day as string) as date_key
from hoildays_list
),

date_list as(
select
distinct
a.date_key
,case when b.date_key is null then '1' else '0' end as is_work_day --假期及前后7天都是'0'
,1 as joinkey
from data_build.dim_date_ya_v2 a
left join hoildays_days b on a.date_key = b.date_key and b.date_key is not null
where a.date_key >= '${TODAY-30}'
and a.date_key <= '${TODAY-1}'
),

user_date_list as(
select
a.staff_code
,a.employee_no
,b.date_key
,is_work_day
from user_list a
cross join date_list b on a.joinkey = b.joinkey
),

attend_shift_info0 as(
select
a.staff_code as auxiliary_staff_code
,a.date_key as auxiliary_date_key
,case when is_work_day = 0 and b.staff_code is null then a.staff_code else b.staff_code end as staff_code --只有符合假期填充工时才填充员工编号
,case when is_work_day = 0 and b.emplid is null then a.employee_no else b.emplid end as emplid --只有符合假期填充工时才填充员工编号
,b.mon_of_attend_date
,b.roster_week
,case when is_work_day = 0 and b.attend_date is null then a.date_key else b.attend_date end as attend_date --只有符合假期填充工时才填充出勤日期
,b.work_shift_hours
,b.attendance_work_hours
,b.arrive_late_hour
,b.leave_early_hour
,b.absenteeism_hour
,b.early_arrive_hour
,b.late_leave_hour
,is_work_day
,case when is_work_day = 0 and b.work_shift_hours is null then 11.5 else 0 end as hoildays_hour --假期填充工时(每天11.5小时)
from user_date_list a
left join attend_shift_info0_tmp b on a.date_key = b.attend_date and a.staff_code = b.staff_code
where case when is_work_day = 0 and b.staff_code is null then a.staff_code else b.staff_code end is not null),

attend_shift_detail as (
--出勤工时底表
 select distinct
 emplid
 ,staff_code
 ,attend_date
 ,work_shift_hours
 ,hoildays_hour --假期填充工时
 ,case when work_shift_hours >= 4 then 1 else 0 end as is_over_10 -- 改为4小时20231128
 ,case when date_format(t1.attend_date,'yyyyMMdd') >= date_format(t2.change_date,'yyyyMMdd') then 1 else 0 end as is_start
 ,case when date_format(t1.attend_date,'yyyyMMdd') >= date_format(t2.change_date,'yyyyMMdd') then t1.work_shift_hours end work_shift_hours_after_change
 ,case when date_format(t1.attend_date,'yyyyMMdd') >= date_format(t2.change_date,'yyyyMMdd') then hoildays_hour end work_shift_hours_after_change_hoildays --假期填充工时
 ,roster_week
 ,mon_of_attend_date
 ,attendance_work_hours
 ,change_date0
 ,change_date
 ,cal_days_0
 ,cal_days
 ,coalesce(arrive_late_hour,0) as arrive_late_hour
 ,coalesce(leave_early_hour,0) as leave_early_hour
 ,coalesce(absenteeism_hour,0) as absenteeism_hour
 ,coalesce(arrive_late_hour,0) + coalesce(leave_early_hour,0) + coalesce(absenteeism_hour,0) as ab_attend_hour
 ----延长打卡时间不超过4小时
 ,case when early_arrive_hour >= 0 and early_arrive_hour <= 4 then early_arrive_hour else 0 end as early_arrive_hour
 ,case when late_leave_hour >= 0 and late_leave_hour <= 4 then late_leave_hour else 0 end as late_leave_hour
 ,t3.is_working_day
 ,t3.is_holiday -- 是否法定节假日，周末不是法定节假日
 from attend_shift_info0 t1
 left join base_manager_info t2 on t1.staff_code = t2.employee_id
 left join work_day_list t3
    on t1.attend_date = t3.date_key),
    
t30_attend_info as ( --part2.实际出勤    
select --增加条件hoildays_hour = 0代表没有享受假期填充工时，即按正常出勤天统计 
 t1.staff_code
 ,t1.emplid
-- ,t1.mon_of_attend_date
 ,change_date
 ,change_date0
 ,cal_days_0
 ,cal_days
 ,count(distinct case when is_over_10 = 1 and hoildays_hour = 0 then t1.attend_date end) as work_day_attend_cnts -- 总超过4小时的出勤天数
 ,sum(case when hoildays_hour = 0 then t1.is_working_day end) as work_day_cnts -- 工作日天数
 ,count(distinct case when t1.is_working_day = '0' and is_over_10 = 1 and hoildays_hour = 0 then t1.attend_date end) as holiday_attend_cnts -- 节假日出勤天数
 ,sum(case when t1.is_working_day = '0' and hoildays_hour = 0 then 1 else 0 end) as holiday_day_cnts -- 节假日天数
 ,count(distinct case when t1.is_holiday = '1' and is_over_10 = 1 and hoildays_hour = 0 then t1.attend_date end) as holiday_2_attend_cnts -- 法定节假日出勤天数
 ,sum(t1.work_shift_hours) + sum(hoildays_hour) as work_shift_hours --增加假期填充工时
 ,sum(t1.attendance_work_hours) as attendance_work_hours
 ,sum(work_shift_hours_after_change) + sum(hoildays_hour) as work_shift_hours_after_change --t30出勤工时 --增加假期填充工时
 --,sum(case when date_format(t1.attend_date,'yyyyMMdd') >= date_format(t2.hps_hire_dt,'yyyyMMdd') then t1.attendance_work_hours end) as attendance_work_hours_after_entry
 ,sum(t1.arrive_late_hour) as arrive_late_hour
 ,sum(t1.leave_early_hour) as leave_early_hour
 ,sum(t1.absenteeism_hour) as absenteeism_hour
 ,sum(t1.ab_attend_hour) as ab_attend_hour
 ,sum(t1.early_arrive_hour) as early_arrive_hour
 ,sum(t1.late_leave_hour) as late_leave_hour
 ,count(distinct case when t1.arrive_late_hour>0 or t1.leave_early_hour >0 then t1.attend_date end) as t30_leave_arrive_cnts
 from attend_shift_detail t1

 group by t1.staff_code
 ,t1.emplid
 -- ,t1.mon_of_attend_date
 ,change_date
 ,change_date0
 ,cal_days_0
 ,cal_days
 ),
-- 蜂利器超时任务 by 人 豁免一周
user_task_tmp0 as (
 SELECT
 a.order_id,
 a.taskorder_id,
 a.taskorder_node_id,
 a.taskorder_create_time as create_time,
 a.taskorder_update_time as update_time,
 a.taskorder_status,
 a.task_orders,
 a.taskorder_handler,
 date_format(a.taskorder_create_time, 'yyyy-MM-dd') AS create_day,
 a.taskorder_deadline_time as deadline_time,
 IF(a.taskorder_status = 'NEW_ORDER',a.taskorder_assignee,a.taskorder_handler) AS assignee
 --,IF(taskorder_status = 'FINISHED',date_format(taskorder_update_time, 'yyyy-MM-dd'),'yyyy-mm-dd') AS finish_day
 FROM
 data_build.pdw_order_store_211_order_detail_flow_task_taskorders a
 join date_list b on date_format(a.taskorder_deadline_time,'yyyy-MM-dd') = b.date_key and b.is_work_day = '1' --0304过滤掉节假日及前后七天
 WHERE a.dt ='${today-1}'
 and a.taskorder_create_time >= '${TODAY-30}'
 and a.taskorder_create_time <= '${TODAY-1}'
),
user_task_tmp as (
select order_id,
 taskorder_id,
 taskorder_node_id,
create_time,
create_day,
 update_time,
 taskorder_status,
 task_orders,
 taskorder_handler,
 deadline_time,
 assignee[0] as assignee
from user_task_tmp0),

taskorder_list as (
   select 
    dt
    ,new_dt
    ,t1.store_code
    ,t1.employee_id
    ,assignee
    ,if(length(assignee)<8,concat('10',assignee),assignee) as assignee2
    ,order_id
    ,taskorder_status
    ,taskorder_handler
    ,create_time
    ,update_time
    ,t2.deadline_time
    ,case when taskorder_status = 'FINISHED' and unix_timestamp(deadline_time) < unix_timestamp(update_time) and unix_timestamp(deadline_time) > unix_timestamp(create_time)
     and create_day >= date_sub(next_day(new_dt,'mon'),7)
    and create_day < next_day(new_dt,'mon') then 1
   when taskorder_status != 'FINISHED' and day(deadline_time) < day(new_dt) and unix_timestamp(deadline_time) > unix_timestamp(create_time) 
   and create_day >= date_sub(next_day(new_dt,'mon'),7)
    and create_day < next_day(new_dt,'mon') then 1 
   else 0 end as is_delay
   ,case when taskorder_status = 'FINISHED' and unix_timestamp(deadline_time) < unix_timestamp(update_time) and unix_timestamp(deadline_time) > unix_timestamp(create_time) and create_day >= date_sub(next_day(new_dt,'mon'),7)
    and create_day < next_day(new_dt,'mon') then (unix_timestamp(update_time) - unix_timestamp(deadline_time)) / 3600 
   when taskorder_status != 'FINISHED' and unix_timestamp(deadline_time) < unix_timestamp(new_dt) and unix_timestamp(deadline_time) > unix_timestamp(create_time) 
   and create_day >= date_sub(next_day(new_dt,'mon'),7)
    and create_day < next_day(new_dt,'mon') then (unix_timestamp(new_dt) - unix_timestamp(deadline_time)) / 3600 
   else 0 end as delay_hours
   ,case when create_day >= change_date then 1 else 0 end as is_start --改
    from staff_list t1 
    left join user_task_tmp t2 on t1.employee_id = if(length(t2.assignee)<8,concat('10',t2.assignee),t2.assignee)
    left join base_manager_info t3 on t1.employee_id = t3.employee_id
    ),

delay_task_list0 as 
(-- 每天的超时任务数
    select 
    roster_week 
    ,employee_id
    ,new_dt
    ,count(distinct order_id) as delay_task_count 
    ,count(distinct case when is_over24 = 1 then order_id else null end) as delay_task_count_24
    from (
    select 
    dt
    ,new_dt
    ,date_sub(next_day(new_dt,'mon'),7) as roster_week
    ,employee_id
    ,order_id
    ,create_time
    ,update_time
    ,deadline_time
    ,is_delay
    ,taskorder_status
    ,case when delay_hours > 24 then 1 else 0 end as is_over24
    from taskorder_list 
    where is_delay = 1
    and is_start = 1
    ) tt 
    group by roster_week 
    ,employee_id
    ,new_dt
),
delay_task_list as ( --平均每天超时任务数
    select 
    employee_id
    ,avg(delay_task_count) as delay_task_count
    ,avg(delay_task_count_24) as delay_task_count_24
    from delay_task_list0
    group by 
    employee_id)
    
-- 出勤违规base_info
,ab_attend_info as (
 select 
 employee_no
 ,ab_attend_date
 ,month(ab_attend_date) as mon_of_ab_attend
 ,roster_week
 -- ,case when ab_attend_date >= change_date then 1 else 0 end as is_start
 ,sum(arrive_late_cost+leave_early_cost+absenteeism_cost) as attend_ab_cost
 ,sum(if(arrive_late_cost>0,1,0)
 +if(leave_early_cost>0,1,0)
 +if(absenteeism_cost>0,1,0)) as attend_ab_cnts
 ,sum(ab_attend_hours) as ab_attend_hours

 from (
 select
 if(length(t1.employee_no)=6,concat('10',t1.employee_no),t1.employee_no) as employee_no
 ,date_sub(next_day(work_shift_date,'mon'),7) as roster_week
 ,date_format(t1.work_shift_date, 'yyyy-MM-dd') as ab_attend_date
 ,sum(arrive_late_count)*11*4 as arrive_late_cost
 ,sum(leave_early_count)*11*4 as leave_early_cost 
 ,sum(absenteeism_hours)*22*4 as absenteeism_cost
 ,sum(arrive_late_minutes) as arrive_late_minutes
 ,sum(leave_early_minutes) as leave_early_minutes
 ,sum(absenteeism_hours) as absenteeism_hours
 ,sum(arrive_late_minutes/60+leave_early_minutes/60+absenteeism_hours) as ab_attend_hours -- 改为实际小时数
 from default.pdw_opc_shop_attendance_report_work_shift t1
 join date_list t2 on date_format(t1.work_shift_date, 'yyyy-MM-dd') = t2.date_key and t2.is_work_day = '1' --0304过滤掉节假日及前后七天
 where t1.dt = '${today-1}'
 and t1.work_shift_date >= '${TODAY-30}'
 and t1.work_shift_date <= '${TODAY-1}'
 and t1.work_shift_type in (1,9,12)
 and (arrive_late_count > 0 or leave_early_count > 0 or absenteeism_hours >=4)
 group by employee_no
 ,date_sub(next_day(work_shift_date,'mon'),7)
 ,t1.work_shift_date
 ) t0
-- left join base_manager_info t1 on t0.employee_no = t1.employee_id

 group by 
 employee_no
 ,ab_attend_date
 ,month(ab_attend_date)
 ,roster_week
 -- ,case when ab_attend_date >= change_date then 1 else 0 end
)
-- 违规情况低于10分钟 by人
,ab_attend_info_less10 as (
 select 
 employee_no
 ,ab_attend_date
 ,month(ab_attend_date) as mon_of_ab_attend
 ,roster_week
 -- ,case when ab_attend_date >= change_date then 1 else 0 end as is_start
 ,sum(arrive_late_cost+leave_early_cost) as attend_ab_cost
 ,sum(if(arrive_late_cost>0,1,0)
 +if(leave_early_cost>0,1,0)) as attend_ab_cnts
 ,sum(arrive_late_minutes/60+leave_early_minutes/60) as ab_attend_hours

 from (
    -- 迟到/早退10分钟以下的次数，不算旷工
 select
 if(length(t1.employee_no)=6,concat('10',t1.employee_no),t1.employee_no) as employee_no
 ,date_sub(next_day(work_shift_date,'mon'),7) as roster_week
 ,date_format(t1.work_shift_date, 'yyyy-MM-dd') as ab_attend_date
 ,sum(case when arrive_late_minutes <10 then arrive_late_count else 0 end)*11*4 as arrive_late_cost
 ,sum(case when leave_early_minutes <10 then leave_early_count else 0 end)*11*4 as leave_early_cost 
 ,sum(case when arrive_late_minutes <10 then arrive_late_minutes else 0 end) as arrive_late_minutes
 ,sum(case when leave_early_minutes <10 then leave_early_minutes else 0 end) as leave_early_minutes
 from default.pdw_opc_shop_attendance_report_work_shift t1
 where t1.dt = '${today-1}'
 and t1.work_shift_date >= '${TODAY-30}'
 and t1.work_shift_date <= '${TODAY-1}'
 and t1.work_shift_type in (1,9,12)
 and (arrive_late_count > 0 or leave_early_count > 0)
 
 group by employee_no
 ,date_sub(next_day(work_shift_date,'mon'),7)
 ,t1.work_shift_date

) t0

group by 
 employee_no
 ,ab_attend_date
 ,month(ab_attend_date)
 ,roster_week
)
,ab_attend_info2 as (
-- 出勤违规
    select 
    t1.employee_no
   -- ,mon_of_ab_attend
    ,sum(t1.attend_ab_cost) as attend_ab_cost_0
    ,sum(t1.attend_ab_cnts) as ab_attend_count
    ,sum(t1.ab_attend_hours) as ab_attend_hours
    -- ,count(distinct case when t1.ab_attend_hours > 0.5 then t1.ab_attend_date else null end) as ab_attend_count
    ,sum(t2.attend_ab_cost) as attend_ab_cost_less10
    ,sum(t2.attend_ab_cnts) as attend_ab_cnts_less10
    ,sum(t2.ab_attend_hours) as ab_attend_hours_less10
    -- 5次10分钟的迟到或早退不算
    ,sum(t1.attend_ab_cnts)-if(sum(t2.attend_ab_cnts)>=5,5,sum(t2.attend_ab_cnts)) as attend_ab_cnts
    from ab_attend_info t1 
    left join ab_attend_info_less10 t2 on t1.employee_no = t2.employee_no and t1.ab_attend_date = t2.ab_attend_date
    group by t1.employee_no
   -- ,mon_of_ab_attend
),
--员工工序工时合格率 豁免一周
task_hour_info0 as ( 
 select 
 employee_id
 ,avg(qualified_task_time_exclude_free_rate) as t30_avg_task_time_rate --工时合格率
 from (
 select 
 t1.work_date
 ,if(length(t1.employee_id)=6,concat('10',t1.employee_id),t1.employee_id)  as employee_id
 ,qualified_task_time_exclude_free_rate
 ,t1.store_code
 ,case when t1.work_date >= change_date then 1 else 0 end as is_start --改
 from data_shop.app_mmc_store_employee_qualified_task_time_rate_di_v3_view t1
 left join base_manager_info t2 on if(length(t1.employee_id)=6,concat('10',t1.employee_id),t1.employee_id) = t2.employee_id 
 where t1.dt >= '${today-30}'
 -- and t1.dt <= '20230331' 
 and date_format(t1.work_date, 'yyyyMMdd') >= '${today-30}'
 and date_format(t1.work_date, 'yyyyMMdd') <= '${today-1}'
 -- and date_format(t1.work_date, 'yyyyMMdd') <= '20230331'
 ) tmp
 where is_start = 1
 group by employee_id
),
-- 废弃数量及金额 by store 豁免一周
promotion_list as (
select 
store_code	
,start_date
,end_date
,date_add(end_date,7) as end_date_week1
from data_promotion.dm_promotion_daily_app_2023_activity_store_list_di 
where dt= '${today-1}'
-- and start_date >= '2023-05-04'
),
sku_list as (
    select distinct
sku_division_code
,sku_class_code
from default.dim_sku_info 
where dt = '${today-1}'
),
waste_list0 as (
select
  target_date
 ,store_code 
 ,date_sub(next_day(target_date,'mon'),7) as roster_week
 ,t1.sku_division_code
 ,sku_class_code
 ,sum(zonghe_manual_waste_qty) as zonghe_correction_waste_qty --财务口径 废弃数量
 ,sum(zonghe_manual_waste_amount) as zonghe_correction_waste_amount --财务口径 纯录入废弃金额
from data_smartorder.dm_production_os_waste_presum_di t1
left join sku_list t2 on t1.sku_division_code = t2.sku_division_code
where dt >= '${today-30}'
and dt <= '${today-1}'
 and target_date >= '${TODAY-30}'
and target_date <= '${TODAY-1}'
  --and store_code = '100000696'
group by target_date,store_code 
,t1.sku_division_code
,sku_class_code
),
waset_list as (
    select 
    
    store_code
    ,sum(zonghe_correction_waste_qty) as zonghe_correction_waste_qty
    ,sum(zonghe_correction_waste_amount) as zonghe_correction_waste_amount
    from(
    select
    target_date 
    ,t1.store_code 
    ,t1.roster_week
    ,case when t1.target_date >= t2.change_date then 1 else 0 end as is_start_7 --改
    ,case when t1.roster_week >= date_sub(next_day(t3.start_date,'mon'),7) and t1.roster_week <= date_add(next_day(t3.end_date,'mon'),0) then 1 else 0 end as is_promotion
    ,zonghe_correction_waste_qty
    ,zonghe_correction_waste_amount
    from waste_list0 t1 
    left join base_manager_info t2 on t1.store_code = t2.store_code 
    left join promotion_list t3 on t1.store_code =t3.store_code 
    where sku_class_code not in ('30', '31', '32', '33', '34', '35', '36', '37', '38', '39', '40', '41', '42', '43', '44', '61', '64', '65',
 '66', '67', '68', '70', '71', '72', '73', '78', '85', '88', '89')
    ) tt 
    where is_start_7 = 1
    and is_promotion = 0
    group by store_code
),
-- 计算工作日天数
workdays_t30 as (
select
max(date_key) as max_date_key
,count(distinct date_key) as total_days
,count(distinct date_key)-count(distinct case when is_holiday = 1 then date_key else null end) as workdays
from default.dim_date_ya_v2
where date_key >= '${TODAY-30}'
and date_key <= '${TODAY-1}'
),

-- 日商无豁免
sell_price_list as (
select 
-- trunc(order_date,'MM') as record_month
t.store_code 
--,t.store_name
--周中日订单量折前销售额折后销售额
,count(distinct case when b.is_working_day = 1 then t.order_no end)/count(distinct case when b.is_working_day = 1 then order_date end) as zhouzhong_order_cnt --订单量
,sum(case when b.is_working_day = 1 then t.sell_price end)/count(distinct case when b.is_working_day = 1 then order_date end) as zhouzhong_sell_price --折前销售额
,sum(case when b.is_working_day = 1 then t.payable_price end)/count(distinct case when b.is_working_day = 1 then order_date end) as zhouzhong_payable_price --折后销售额
,count(distinct t.order_no)/count(distinct order_date) as quanzhou_order_cnt --订单量
,sum(t.sell_price)/count(distinct order_date) as quanzhou_sell_price --折前销售额
,sum(t.payable_price)/count(distinct order_date) as quanzhou_payable_price --折后销售额
from data_build.dw_order_sku_v1 t
left join work_day_list b on t.order_date = b.date_key 
where t.dt = '${today-1}'
and t.store_type = '0'
and t.order_status = 'FINISHED'
and t.sku_class_code not in ('86','50')
and t.sku_quantity > 0
and t.order_date between '${TODAY-30}' and '${TODAY-1}'
group by 
t.store_code 
--,t.store_name
),
sell_price_list_ripei as (
select 
t.store_code 
 ,t.store_name
--,t.store_name
--周中日订单量折前销售额折后销售额
,count(distinct case when b.is_working_day = 1 then t.order_no end)/count(distinct case when b.is_working_day = 1 then order_date end) as zhouzhong_order_cnt --订单量
,sum(case when b.is_working_day = 1 then t.sell_price end)/count(distinct case when b.is_working_day = 1 then order_date end) as zhouzhong_sell_price --折前销售额
,sum(case when b.is_working_day = 1 then t.payable_price end)/count(distinct case when b.is_working_day = 1 then order_date end) as zhouzhong_payable_price --折后销售额
,count(distinct t.order_no)/count(distinct order_date) as quanzhou_order_cnt --订单量
,sum(t.sell_price)/count(distinct order_date) as quanzhou_sell_price --折前销售额
,sum(t.sell_price) as total_quanzhou_sell_price
,sum(t.payable_price)/count(distinct order_date) as quanzhou_payable_price --折后销售额
from data_build.dw_order_sku_v1 t
left join work_day_list b on t.order_date = b.date_key 
where t.dt = '${today-1}'
and t.store_type = '0'
and t.order_status = 'FINISHED'
and t.sku_class_code not in ('86','50')
and t.sku_quantity > 0
and t.sku_class_code not in ('30', '31', '32', '33', '34', '35', '36', '37', '38', '39', '40', '41', '42', '43', '44', '61', '64', '65',
 '66', '67', '68', '70', '71', '72', '73', '78', '85', '88', '89')
and t.order_date between '${TODAY-30}' and '${TODAY-1}'
group by t.store_code 
,t.store_name
),

-- 折前日商 bystore豁免一周
sales_pdps_list0 as (
    select
 store_city 
 ,t1.store_code 
 ,t1.store_name 
 ,sale_date
 ,substr(sale_date,1,7) as month_of_sale
 ,date_sub(next_day(sale_date,'mon'),7) as roster_week
 ,case when t1.sale_date >= t2.change_date then 1 else 0 end as is_start_7 --改
 ,payable_price_for_roster as sales_pdps
 ,sell_price_for_roster as sales_pdps_b
 -- ,round(avg_t,0) as `T值`
from data_smartorder.dm_ordering_suggestion_reference_data_store_amt_for_roster_da t1
left join base_manager_info t2 on t1.store_code = t2.store_code 
where dt = '${today-1}'
 and sale_date >= '${TODAY-30}'
 and sale_date <=  '${TODAY-1}'
 and store_type = '0'
 and order_cnt_store >= 20 --正常营业店日
 and holiday_type in (1,2) --剔除节假日
),

sales_pdps_list as 
(
    select
 store_city 
 ,store_code 
 ,store_name 
-- ,month_of_sale
 ,round(avg(sales_pdps_b),0) as sales_pdps_b
 ,round(sum(sales_pdps_b),0) as total_sales_pdps_b
 -- ,round(avg_t,0) as `T值`
from sales_pdps_list0
where is_start_7 = 1
group by store_city 
 ,store_code 
 ,store_name 
-- ,month_of_sale
),
-- 废弃对应商圈及日商
waset_location_list as (
    select 
    store_code
    ,waste_rate
    ,location_type
    ,sell_price_rounddown
   ,case when sell_price_rounddown >= 0 and sell_price_rounddown < 1000 then '[0,1000)'
    when sell_price_rounddown >= 1000 and sell_price_rounddown < 2000 then '[1000,2000)'
    when sell_price_rounddown >= 2000 and sell_price_rounddown < 3000 then '[2000,3000)'
    when sell_price_rounddown >= 3000 and sell_price_rounddown < 4000 then '[3000,4000)'
    when sell_price_rounddown >= 4000 and sell_price_rounddown < 5000 then '[4000,5000)'
    when sell_price_rounddown >= 5000 and sell_price_rounddown < 6000 then '[5000,6000)'
    when sell_price_rounddown >= 6000 and sell_price_rounddown < 7000 then '[6000,7000)'
    when sell_price_rounddown >= 7000 and sell_price_rounddown < 8000 then '[7000,8000)'
    when sell_price_rounddown >= 8000 and sell_price_rounddown < 9000 then '[8000,9000)'
    when sell_price_rounddown >= 9000 and sell_price_rounddown < 10000 then '[9000,10000)'
    when sell_price_rounddown >= 10000 and sell_price_rounddown < 11000 then '[10000,11000)'
    when sell_price_rounddown >= 11000 and sell_price_rounddown < 12000 then '[11000,12000)'
    when sell_price_rounddown >= 12000 and sell_price_rounddown < 13000 then '[12000,13000)'
    when sell_price_rounddown >= 13000 and sell_price_rounddown < 14000 then '[13000,14000)'
    when sell_price_rounddown >= 14000 and sell_price_rounddown < 15000 then '[14000,15000)'
    when sell_price_rounddown >= 15000 then '[15000,+)'
    else null end as sell_price_type 
    from (
    select 
    t0.store_code
    ,(t7.zonghe_correction_waste_amount/t2.total_quanzhou_sell_price) as waste_rate --t30废弃率（豁免第1周）
    ,location_type --商圈类型
    ,case when (round(floor(quanzhou_sell_price/1000),0)*1000) > 15000 then 15000
else (round(floor(quanzhou_sell_price/1000),0)*1000) end as sell_price_rounddown -- 日商档位
    from base_manager_info t0 
    left join waset_list t7 on t0.store_code = t7.store_code
    left join sales_pdps_list t6 on t0.store_code = t6.store_code
    left join location_type_list t1 on t0.store_code = t1.store_code
    left join sell_price_list_ripei t2 on t0.store_code = t2.store_code
    ) tt
),
-- 废弃对应商圈日商不同分位值
waset_location_rank as (
    select 
    store_code
    ,waste_rate
    ,location_type
    ,sell_price_rounddown
    ,sell_price_type
    ,round(percent_rank() over (partition by sell_price_type order by waste_rate asc)*100,2) as percent_rank_waste
    ,rank() over (partition by sell_price_type order by waste_rate asc)-1 as rank_waste
    ,count(1) over (partition by sell_price_type) as total_stores
    ,rank() over (partition by sell_price_type order by waste_rate asc)/count(1) over (partition by sell_price_type) as percent_rank_waste2
    from waset_location_list
    where waste_rate is not null 

    union 
    select 
    store_code
    ,waste_rate
    ,location_type
    ,sell_price_rounddown
    ,sell_price_type
    ,null as percent_rank_waste
    ,null as rank_waste
    ,null as total_stores
    ,null as percent_rank_waste2
    from waset_location_list
    where waste_rate is null 
),
-- 废弃得分
waset_location_score as (
    select 
    store_code
    ,waste_rate
    ,location_type
    ,sell_price_rounddown
    ,sell_price_type
    ,percent_rank_waste
    ,rank_waste
    ,total_stores
    ,percent_rank_waste2
    ,case when percent_rank_waste <= 20 then 5 
    when percent_rank_waste <= 50 then 4
    when percent_rank_waste <= 70 then 3
    when percent_rank_waste <= 90 then 2
    when percent_rank_waste > 90 then 1
    when percent_rank_waste is null then 3
    else null end as waste_score
    from waset_location_rank
),

check_order_info as ( --员工盘点执行率 t7改为t30
 select 
executor
 ,avg(check_order_rate) as t30_avg_check_order_rate
 from (
 select 
 if(length(t1.executor)=6,concat('10',t1.executor),t1.executor) as executor
 ,t1.work_date
 ,case when t1.work_date >= change_date then 1 else 0 end as is_start --改
 ,t1.biz_order_id
 ,sum(t1.task_finish_work_num)/sum(task_work_num) as check_order_rate

 from data_shop.dwa_shop_horae_task_operation_checkorder_da t1
 left join base_manager_info t2 on if(length(t1.executor)=6,concat('10',t1.executor),t1.executor) = t2.employee_id
 where t1.dt = '${today-1}' 
 and date_format(t1.work_date,'yyyyMMdd') >= '${today-30}' --最新dt 
 and date_format(t1.work_date,'yyyyMMdd') <= '${today-1}' --最新dt 
 -- and date_format(t1.work_date,'yyyyMMdd') <= '20230331'
 group by t1.executor
 ,t1.work_date
 ,case when t1.work_date >= change_date then 1 else 0 end  --改
 ,t1.biz_order_id
 ) tmp
 where is_start = 1
 group by executor
),
-- 盘点差异率 t7改为t30
check_diff_info as 
( select 
sale_date
,t1.store_code
,cal_days
,case when date_format(t1.sale_date,'yyyyMMdd') >= date_format(t2.change_date,'yyyyMMdd') then 1 else 0 end as is_start --改
,sum(case when t1.document_status = 'FINISHED'  and t1.sku_domain_name = '商品' and sku_class_code not in (84,44) and sku_division_code not in (0503) then abs(quantity) else 0 end ) as stocktaking_inventory_true_numerator--盘点库存准确率-分子
,sum(case when t1.document_status = 'FINISHED'  and t1.sku_domain_name = '商品' and sku_class_code not in (84,44) and sku_division_code not in (0503) then abs(inventory_quantity) else 0 end ) as stocktaking_inventory_true_denominator--盘点库存准确率-分母
from data_smartorder.app_stocktaking_store_day_os_di t1
left join base_manager_info t2 on t1.store_code = t2.store_code
where t1.dt >= '${today-30}' --最新dt
and  t1.dt <= '${today-1}' --最新dt
and sale_date >= '${TODAY-30}'
and sale_date <= '${TODAY-1}'
group by sale_date
,t1.store_code
,cal_days
,case when date_format(t1.sale_date,'yyyyMMdd') >= date_format(t2.change_date,'yyyyMMdd') then 1 else 0 end --改
)
,check_diff_info2 as ( 
    select 
    store_code
    ,sum(stocktaking_inventory_true_numerator) as stocktaking_inventory_true_numerator
    ,sum(stocktaking_inventory_true_denominator) as stocktaking_inventory_true_denominator
    ,sum(stocktaking_inventory_true_numerator)/sum(stocktaking_inventory_true_denominator) as check_diff_per
    from check_diff_info
    where is_start = 1
    group by store_code
),
-- 库存出店执行率
kucun_list0 as(
select 
t1.store_code
,effective_time 
,date_sub(next_day(effective_time,'mon'),7) as roster_week
,case when effective_time >= change_date then 1 else 0 end as is_start --改
,sum(coalesce(real_treatment_quantity,0)) as real_treatment_qty, 
sum(coalesce(inventory_quantity,0)) as should_treatment_qty, 
coalesce(sum(coalesce(real_treatment_quantity,0) )/sum(coalesce(inventory_quantity,0)) ,0 ) as execute_rate, --调拨返仓执行率（库存出店执行率）
sum(case when business_type= 'DISTRIBUTE_TO' then coalesce(inventory_quantity,0) else 0 end ) as dec_allocation_qty, 
sum(case when business_type= 'DISTRIBUTE_TO' then coalesce(real_treatment_quantity,0) else 0 end ) as act_allocation_in_doc_qty, 
coalesce(sum(case when business_type= 'DISTRIBUTE_TO' then coalesce(real_treatment_quantity,0) else 0 end )/sum(case when business_type= 'DISTRIBUTE_TO' then coalesce(inventory_quantity,0) else 0 end ),0) as allocation_rate --调拨执行率
FROM data_md.dm_inv_mgt_store_down_inv_out_treatment_detail_store_sku_v1 t1 
left join base_manager_info t3 on t1.store_code = t3.store_code
WHERE dt = '${today-1}'
AND effective_time >= '${TODAY-30}'
AND effective_time <= '${TODAY-1}'

GROUP BY t1.store_code
,effective_time 
,date_sub(next_day(effective_time,'mon'),7) 
,case when effective_time >= change_date then 1 else 0 end --改
),
kucun_list1 as (
    select 
    store_code
    ,coalesce(sum(coalesce(real_treatment_qty,0) )/sum(coalesce(should_treatment_qty,0)) ,0 ) as execute_rate --调拨返仓执行率（库存出店执行率）
    from kucun_list0
    where is_start = 1
    group by store_code
    
),
-- 现金存缴完成率
cash_finish0 as (
   select 
    task_day
,from_unixtime(unix_timestamp(task_day,'yyyyMMdd'),'yyyy-MM-dd') as task_date
,shop_code
,deposit
,bill_amount
,case when deposit = 0 then 0 when deposit = 1 and to_date(deposit_time) <= '${TODAY-1}' then (bill_amount+deposit_diff_amount) else null end as real_amount
    from default.pdw_inf_pay_bill_report_bank_cash_day_summary 
    where dt = '${today-1}' 
and task_day >= '${today-37}'
and task_day <= '${today-7}'
and remark in ('现金已存款','现金未存款')
),

cash_finish as (
select 
task_day
,task_date
,shop_code
,sum(bill_amount) as bill_amount -- 应缴
,sum(real_amount) as real_amount-- 实缴
from cash_finish0
group by task_day
,task_date
,shop_code
),
cash_finish1 as (
    SELECT
    task_date
    ,shop_code
    ,date_sub(next_day(task_date,'mon'),7) as roster_week
    ,bill_amount
    ,real_amount
    ,real_amount/bill_amount as cash_rate
    ,case when task_date >= change_date0 then 1 else 0 end as is_start
    from cash_finish t1
    left join base_manager_info t2 on t1.shop_code = t2.store_code
),
cash_finish2 as (
    select 
    shop_code
    ,sum(bill_amount) as bill_amount
    ,sum(real_amount) as real_amount
    ,avg(cash_rate) as cash_rate
    from cash_finish1
    where is_start = 1
    group by shop_code
),
-- 发票回收
invoice_list as (
    select 
cost_bearing_department_code as store_code
,id
,should_pay_amount
,verification_amount
,verification_status
,to_date(real_pay_time) as pay_date
,case when to_date(real_pay_time) >= change_date0 then 1 else 0 end as is_start_7

from default.pdw_finance_tax_match_request_info t1
left join base_manager_info t2 on t1.cost_bearing_department_code = t2.store_code 
where t1.dt  = '${today-1}' --
and match_system in ('shop_rent','bach_electric_after','bach_electric_pre','bach_water_pre','bach_water_after') 
and source in ('后付电费','预付电费','后付水费','预付水费','取暖费','商业服务费','物业费','杂项费用','杂项费用公摊水费','制冷/空调费','咨询服务费','资源占用费')
and to_date(real_pay_time) >= '${TODAY-60}'
and to_date(real_pay_time) < '${TODAY-30}'
),
invoice_final_list1 as (
    select 
    store_code
   
    ,sum(should_pay_amount) as should_pay_amount
    ,sum(verification_amount) as verification_amount
    ,count(distinct id) as should_num
    ,count(distinct case when verification_status in ('1','2') then id else null end) as verification_num
    ,sum(verification_amount)/sum(should_pay_amount) as t30_verification_per
    ,count(distinct case when verification_status in ('1','2') then id else null end)/count(distinct id) as t30_verification_num_per
    from invoice_list
    where is_start_7 = 1
    group by store_code
  
),
-- t30门店t值
opening_days_base as
(select
 sale_date as c_date
 ,case when sale_date >= change_date then 1 else 0 end as is_start
 ,case when sale_date >= change_date then 1 else 0 end as is_start_7 --改
 ,weekofyear(sale_date) as week_of_year
 ,date_sub(next_day(sale_date,'mon'),7) as roster_week
 ,shop_code as store_code
 ,from_unixtime(unix_timestamp(t1.dt,'yyyyMMdd'),'yyyy-MM-dd') as new_dt

 from default.pdw_idss_mmc_cooperate_shop_open_info t1
 left join base_manager_info t2 on t1.shop_code = t2.store_code
 -- left join default.dim_date_ya_v2 t2
   -- on from_unixtime(unix_timestamp(t1.dt,'yyyyMMdd'),'yyyy-MM-dd') = t2.date_key
 where t1.dt= '${today-1}'
 and shop_type=0
 and shop_state=1
 and bach_business_time not in ('全天不营业','20:00:00-23:59:59','19:00:00-23:59:59')
 and sale_date >= '${TODAY-30}'
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
 ,case when alarm_start_date >= change_date then 1 else 0 end as is_start_7 --改
 ,final_level_modify
 ,substr(final_level_modify,2,1) as final_t_level
from data_shop.dwd_ic_new_import_store_level_da_view t1 
left join base_manager_info t2 on t1.shop_id = t2.store_code
where dt = '${today-1}'
-- and final_level_modify in ('T5','T6') 
 and alarm_start_date >= '${TODAY-30}'
and alarm_start_date <= '${TODAY-1}'
),
t_final as 
(
select 
t1.store_code
,avg(final_t_level) as final_t_level

from opening_days2 t1 
left join t_byday t2 on t1.store_code = t2.shop_id
and t1.c_date = t2.alarm_start_date
where t2.is_start_7 = 1
group by t1.store_code
),
-- 品控
audit_base as (
select 
shop_code
,audit_begin_time
,score
,result
,to_date(audit_begin_time) as audit_begin_date
,t3.change_date0
,t3.entry_date
,case when to_date(audit_begin_time) >date_add(change_date0,7) then 1 else 0 end as is_change_7
,case when to_date(audit_begin_time) >t3.entry_date then 1 else 0 end as is_entry
from default.pdw_qcs_data_audit_shop_task t1 
left join base_manager_info t3 on t1.shop_code = t3.store_code
where t1.dt = '${today-1}'
),
audit_begin_date_maxlist as (
select 
shop_code 
,max(audit_begin_date) as audit_begin_date_max 
from audit_base
where is_change_7 = 1
and is_entry = 1
and audit_begin_date <= '${TODAY-1}'
and audit_begin_date >= '${TODAY-30}'
group by shop_code
),
audit_final_list as (
select 
t1.shop_code 
,score
,result
,audit_begin_date
from audit_begin_date_maxlist t1
left join audit_base t2 on t1.shop_code = t2.shop_code and t1.audit_begin_date_max  = t2.audit_begin_date 
),
punish_detail as ( --惩处明细
 select
 t1.previous_order_id as order_id
 ,to_date(t1.1st_create_date) as order_create_date
 ,t4.change_date --改
 ,case when to_date(t1.1st_create_date) >= t4.change_date then 1 else 0 end as is_start --改

 ,t4.cal_days
 -- ,t2.occur_time as ab_create_time
 ,t1.chain_status as order_status
 ,case when locate('#', regexp_replace(t1.1st_item_id,'[0-9]','#')) > 0
 then t1.1st_flow_name else t1.1st_item_id end as punish_item
 ,coalesce(t1.3rd_operate_results,t1.2nd_operate_results,t1.1st_operate_results) as operate_results
 ,t1.1st_shop_code as shop_code
 -- ,t3.hps_dept_code_lv5 as dept_code
 ,coalesce(t1.3rd_final_user_name,t1.2nd_final_user_name,t1.1st_final_user_name) as staff_name
 ,coalesce(t1.3rd_final_user_code,t1.2nd_final_user_code,t1.1st_final_user_code) as emplid
 ,lpad(coalesce(t1.3rd_final_user_code,t1.2nd_final_user_code,t1.1st_final_user_code),8,'10') as staff_code
 ,case
 when coalesce(3rd_final_feedback_type,2nd_final_feedback_type,2nd_feedback_type
 ,1st_final_feedback_type,1st_feedback_type) = '工时数量扣减'
 then '工时数量扣减' else '工时工资扣减' end as punish_type
 ,case
 when coalesce(3rd_final_feedback_type,2nd_final_feedback_type
 ,2nd_feedback_type,1st_final_feedback_type,1st_feedback_type) = '工时数量扣减'
 then 20*round(coalesce(3rd_final_feedback_result_value,3rd_feedback_result_value
 ,2nd_final_feedback_result_value,2nd_feedback_result_value
 ,1st_final_feedback_result_value,1st_feedback_result_value),2) 
 else round(coalesce(3rd_final_feedback_result_value,3rd_feedback_result_value
 ,2nd_final_feedback_result_value,2nd_feedback_result_value
 ,1st_final_feedback_result_value,1st_feedback_result_value),2) end as punish_value
 ,case
 when coalesce(3rd_final_feedback_type,2nd_final_feedback_type
 ,2nd_feedback_type,1st_final_feedback_type,1st_feedback_type) = '工时数量扣减'
 then 20*round(coalesce(3rd_feedback_result_value
 ,2nd_final_feedback_result_value,2nd_feedback_result_value
 ,1st_final_feedback_result_value,1st_feedback_result_value),2) 
 else round(coalesce(3rd_feedback_result_value
 ,2nd_final_feedback_result_value,2nd_feedback_result_value
 ,1st_final_feedback_result_value,1st_feedback_result_value),2) end as punish_value_origin
 from data_build.dwd_store_construction_operation_punish_flow_pipeline_v1 t1
 -- left join ab_time_detail t2
 -- on coalesce(t1.next_order_id_2,t1.next_order_id,t1.previous_order_id) = t2.order_id 
 -- left join data_shop.pdw_psprod_ps_blf_ehr_pers_vw_view t3
 -- on t3.dt <= '${today-1}' and date_format(date_sub(to_date(t2.occur_time),1),'yyyyMMdd') = t3.dt
 -- and coalesce(t1.3rd_final_user_code,t1.2nd_final_user_code,t1.1st_final_user_code) = t3.emplid
 left join base_manager_info t4 on t1.1st_shop_code = t4.store_code
 where t1.dt = '${today-1}'
 and date_format(t1.1st_create_date,'yyyyMMdd') >=  '${today-30}'
 and date_format(t1.1st_create_date,'yyyyMMdd') <=  '${today-1}'
 and (case when locate('#', regexp_replace(1st_item_id,'[0-9]','#')) > 0
 then 1st_flow_name else 1st_item_id end) not in ('请假/拒绝班次惩处','超成本工时费用')
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
,appeal_punish_detail as ( --客诉分类调整0524
 select distinct
 t1.emplid
 ,t1.order_create_date
 -- ,t1.ab_create_time
 ,t1.shop_code
 ,t1.cal_days
 -- ,t1.dept_code
 ,t1.order_id
 ,t1.punish_item
 ,t1.punish_type
 ,t1.punish_value
 ,t1.punish_value_origin
 ,t2.abnormal_explain
 ,t2.exemption
 ,case when t2.abnormal_explain in ('客诉-投诉分类: 二级/BZ/变质','客诉-投诉分类: 二级/GQ/过期','客诉-投诉分类: 二级/YW/异物','客诉-投诉分类: 四级/服务问题/服务态度问题','客诉-投诉分类: 四级/服务问题/卫生/环境','客诉-投诉分类: 一级/CT/服务冲突','客诉-投诉分类: 一级/RS/人伤','客诉-投诉分类: 一级/WS/物损') 
 then 1 when t2.abnormal_explain in ('客诉-投诉分类: 三级/口感/口感','客诉-投诉分类: 三级/品质/品质','客诉-投诉分类: 三级/量少/量少','客诉-投诉分类: 三级/配套产品缺失/配套产品缺失','客诉-投诉分类: 三级/商品或包装破损/商品或包装破损','客诉-投诉分类: 三级/失温/失温'
                                    ,'客诉-投诉分类: 四级/服务问题/技能/专业不熟练','客诉-投诉分类: 四级/服务问题/沟通困难','客诉-投诉分类: 四级/购物体验/豆浆稀','客诉-投诉分类: 四级/购物体验/身体不适'
                                    -- ,'客诉-投诉分类: 四级/拣货问题/已下单商品部分缺货（在库）','客诉-投诉分类: 四级/拣货问题/已下单商品全部缺货（在库）'
                ,'客诉-投诉分类: 四级/设备故障问题/豆浆机故障','客诉-投诉分类: 四级/设备故障问题/点餐屏故障','客诉-投诉分类: 四级/退换货问题/店员给错商品','客诉-投诉分类: 四级/退换货问题/门店结错账','客诉-投诉分类: 四级/支付问题/支付金额与宣传不符')
                then 2 else 0 end as appeal_punish_type
                -- 1 为严重客诉 2为普通客诉
 ,case when lpad(t1.emplid,8,'10') = t3.employee_id then 1 else 0 end as is_manager_appeal

 from punish_detail t1
 left join appeal_text_detail t2
 on t1.order_id = t2.order_id
 left join base_manager_info t3 on t1.shop_code = t3.store_code
 where t1.punish_item = '客诉惩处' 
 and t1.operate_results = '运营问题'
 and t1.order_status = 'FINISHED'
 and t1.is_start = 1 
 and t2.abnormal_explain in ('客诉-投诉分类: 二级/BZ/变质','客诉-投诉分类: 二级/GQ/过期','客诉-投诉分类: 二级/YW/异物','客诉-投诉分类: 四级/服务问题/服务态度问题','客诉-投诉分类: 四级/服务问题/卫生/环境','客诉-投诉分类: 一级/CT/服务冲突'
 ,'客诉-投诉分类: 一级/RS/人伤','客诉-投诉分类: 一级/WS/物损',
 '客诉-投诉分类: 三级/口感/口感','客诉-投诉分类: 三级/品质/品质','客诉-投诉分类: 三级/量少/量少','客诉-投诉分类: 三级/配套产品缺失/配套产品缺失','客诉-投诉分类: 三级/商品或包装破损/商品或包装破损','客诉-投诉分类: 三级/失温/失温'
                                    ,'客诉-投诉分类: 四级/服务问题/技能/专业不熟练','客诉-投诉分类: 四级/服务问题/沟通困难','客诉-投诉分类: 四级/购物体验/豆浆稀','客诉-投诉分类: 四级/购物体验/身体不适'
                                    -- ,'客诉-投诉分类: 四级/拣货问题/已下单商品部分缺货（在库）','客诉-投诉分类: 四级/拣货问题/已下单商品全部缺货（在库）' -- 剔除普通客诉2项0601
                ,'客诉-投诉分类: 四级/设备故障问题/豆浆机故障','客诉-投诉分类: 四级/设备故障问题/点餐屏故障','客诉-投诉分类: 四级/退换货问题/店员给错商品','客诉-投诉分类: 四级/退换货问题/门店结错账','客诉-投诉分类: 四级/支付问题/支付金额与宣传不符')
                )
           
,appeal_punish_info1 as ( --客诉final
 select
 shop_code
 ,appeal_punish_type
 ,is_manager_appeal
 ,count(distinct order_id) as appeal_punish_cnts
 ,sum(punish_value) as appeal_punish_value
 ,sum(punish_value_origin) as appeal_punish_value_origin
 from appeal_punish_detail
 -- where date_format(order_create_date,'yyyyMMdd') >= '${today-30}'
 group by shop_code
 ,appeal_punish_type
 ,is_manager_appeal
),
-- 增加店长严重客诉、店长普通客诉、店员严重客诉、店员普通客诉类别0524
appeal_punish_info as ( 
    select 
    shop_code 
    ,max(case when appeal_punish_type = 1 and is_manager_appeal = 1 then appeal_punish_cnts else null end) as appeal_punish_cnts_serious_manager
    ,max(case when appeal_punish_type = 1 and is_manager_appeal = 0 then appeal_punish_cnts else null end) as appeal_punish_cnts_serious_manager0
    ,max(case when appeal_punish_type = 2 and is_manager_appeal = 1 then appeal_punish_cnts else null end) as appeal_punish_cnts_common_manager
    ,max(case when appeal_punish_type = 2 and is_manager_appeal = 0 then appeal_punish_cnts else null end) as appeal_punish_cnts_common_manager0
    from appeal_punish_info1
    group by shop_code
),

-- 本店好店员工时占比
paiban_base0 as 
(
 select 
IF(LENGTH(t1.employee_id)<8,concat('10',t1.employee_id),t1.employee_id) as employee_id
,t1.store_id -- 排班门店
,roster_id
,work_date
,date_sub(next_day(work_date,'mon'),7) roster_week  --周
,start_time
,end_time
,(end_time-start_time) as paiban_hours
,roster_source
,case when t3.employee_id is not null then 1 else 0 end as is_manager
,max(case when work_date = t2.new_dt then t2.store_code else null end) as hps_dept_code_lv5 -- 当天员工所属门店
-- ,case when t2.protect_tag = '待观察' then 1 else 0 end as is_new_staff
from data_build.dw_roster_effect_roster_detail_info_da_view t1 
left join staff_list t2 on IF(LENGTH(t1.employee_id)<8,concat('10',t1.employee_id),t1.employee_id) = t2.employee_id
 left join base_manager_info t3 on IF(LENGTH(t1.employee_id)<8,concat('10',t1.employee_id),t1.employee_id) = t3.employee_id
where t1.dt = '${today-1}'
and work_date >=  '${TODAY-30}'
and work_date <=  '${TODAY-1}'
and t1.store_type_desc = '门店'
and t1.class_id in ('0')
and t1.store_type = '0'
and t1.sale_type <> '全天不营业'
group by 
IF(LENGTH(t1.employee_id)<8,concat('10',t1.employee_id),t1.employee_id)
,t1.store_id -- 排班门店
,roster_id
,work_date
,date_sub(next_day(work_date,'mon'),7) 
,start_time
,end_time
,roster_source
,case when t3.employee_id is not null then 1 else 0 end
),
paiban_base as (
select 
t1.employee_id
,t1.store_id -- 排班门店
,t1.hps_dept_code_lv5
,case when t1.store_id = t1.hps_dept_code_lv5 then 0 else 1 end as is_shift -- 是否由外店员工上班
,roster_id
,t1.work_date
,roster_week  --周
,start_time
,end_time
,paiban_hours
,roster_source
 ,is_manager
-- ,case when t2.protect_tag = '待观察' then 1 else 0 end as is_new_staff
from paiban_base0 t1 
),
cross_attend_info1 as (
    select
    t1.store_id
    ,work_date 
    ,roster_week
    ,case when t1.work_date >= t2.change_date then 1 else 0 end as is_start_14
    ,sum(case when is_shift = 1 then paiban_hours else 0 end ) as work_shift_hours_cross -- 被跨店小时数 -- 除开店长排班
    ,sum(paiban_hours) as work_shift_hours -- 门店总排班小时数 -- 除开店长排班
    from paiban_base t1
    left join base_manager_info t2 on t1.store_id = t2.store_code
     where t1.is_manager = 0 --除开店长
    group by t1.store_id
    ,work_date 
    ,roster_week
    ,case when t1.work_date >= t2.change_date then 1 else 0 end
),
cross_attend_info2 as (
    select 
    store_id as store_code
    
    ,sum(work_shift_hours_cross) as work_shift_hours_cross -- 被跨店小时数
    ,sum(work_shift_hours) as work_shift_hours -- 门店总排班小时数 -- 除开店长排班
    from cross_attend_info1
    where is_start_14 = 1
    group by store_id
    
),
local_attend_info1 as ( --每个人在本店的排班小时和总排班小时
select
    t1.employee_id
    ,work_date 
    ,roster_week
    ,t1.hps_dept_code_lv5 -- 所属门店
     ,is_manager
    ,sum(case when is_shift = 0 then paiban_hours else 0 end ) as work_shift_hours_local -- 在本店排班小时数
    ,sum(paiban_hours) as work_shift_hours -- 总排班小时数
    from paiban_base t1
    group by 
    t1.employee_id
    ,work_date 
    ,roster_week
    ,t1.hps_dept_code_lv5
     ,is_manager
),
-- 是否好员工
staff_protect_base as (
select
t1.dt
    ,from_unixtime(unix_timestamp(t1.dt,'yyyyMMdd'),'yyyy-MM-dd') as new_dt
    ,t1.staff_code
    ,t1.protect_tag
    ,t1.store_code -- 所属门店
    ,case when protect_tag in ('应保护','普通','待观察') then 1 -- 新增待观察新人为好员工占比0524
   else 0 end as is_good
   ,case when protect_tag in ('待观察') then 1 -- 新增待观察新人工时打折为50%
   else 0 end as is_new
    from data_shop.dm_shop_staff_protect_tag_v2 t1 
    where dt <=  '${today-1}'
    and dt >=  '${today-30}'),

staff_protect_list0 as ( --所有员工在本店的排班
    select 
    t1.store_code
    ,t1.staff_code
    ,t1.new_dt
    ,t1.is_good
    ,t1.is_new
    ,t2.work_date 
    ,t2.is_manager
    ,work_shift_hours_local
  ,case when t1.new_dt >= change_date then 1 else 0 end as is_start_14
    from staff_protect_base t1 
    left join local_attend_info1 t2 on t1.staff_code = t2.employee_id and t1.store_code = t2.hps_dept_code_lv5 and t1.new_dt= t2.work_date
    left join base_manager_info t3 on t1.store_code = t3.store_code
),
staff_protect_2 as ( -- 店员的排班总数 除开店长
    select 
    t1.store_code
    ,sum(case when is_good = 1 then work_shift_hours_local else 0 end) as good_staff_work_shift_hours
    ,sum(case when is_new = 1 then work_shift_hours_local else 0 end) as new_staff_work_shift_hours
    ,count(distinct staff_code) as total_staff 
    ,count(distinct case when is_good = 1 then staff_code else null end) as good_staff
    from staff_protect_list0 t1 
    left join cross_attend_info2 t2 on t1.store_code = t2.store_code
    where t1.is_start_14 = 1
    and is_manager = 0 
    group by t1.store_code
),
final_goodlist as(
    select 
    t1.store_code
    ,t2.work_shift_hours -- 门店总排班小时 -- 除开店长
    ,good_staff_work_shift_hours
    ,new_staff_work_shift_hours
    ,(good_staff_work_shift_hours+new_staff_work_shift_hours*0.5)/t2.work_shift_hours as good_er2 -- 新人工时占比*50% + 好员工工时占比 0601 -- 除开店长
    from staff_protect_2 t1 
    left join cross_attend_info2 t2 on t1.store_code = t2.store_code
    ),
-- 门店失败小时数 by store
fail_shift as (
select 
t1.roster_id
,t1.store_id
,t1.work_date
,case when t1.work_date >= t2.change_date then 1 else 0 end as is_start_14
,(end_time-start_time) as paiban_hours
,date_sub(next_day(work_date,'mon'),7) as roster_week
,case when t1.employee_id is null then 1 else 0 end as is_fail
from data_build.dw_roster_effect_roster_detail_info_da_view t1 
left join base_manager_info t2 on t1.store_id = t2.store_code
where dt = '${today-1}'
 and work_date >=  '${TODAY-30}'
 and work_date <=  '${TODAY-1}'
 and t1.store_type_desc = '门店'
and t1.class_id in ('0','-5')
and t1.store_type = '0'
and t1.sale_type <> '全天不营业'
),

fail_list2 as (
    select 
    store_id
    ,sum(case when is_fail = 1 then paiban_hours else 0 end) as fail_hours
    ,count(distinct case when is_fail = 1 then roster_id else null end) as fail_counts
    ,count(distinct roster_id) as total_counts
    ,sum(paiban_hours) as work_shift_hours2
    from fail_shift 
    where is_start_14 = 1
    group by store_id
),
sop_learn_detail as ( --蜂窝学习明细-任务维度聚合
 select 
 title
 ,from_unixtime(unix_timestamp(create_dt,'yyyyMMdd'),'yyyy-MM-dd') as create_date
 ,case when from_unixtime(unix_timestamp(create_dt,'yyyyMMdd'),'yyyy-MM-dd') >= change_date then 1 else 0 end as is_start --改
 ,if(length(emplid)=6,concat('10',emplid),emplid) as emplid
 ,t0.store_code 
 ,count(1) as mission_cnts
 ,sum(finis_percent)/100 as finish_cnts
 from (
 select 
 title
 ,source_name
 ,usercode as emplid
 ,mission_type
 ,sub_mission_type
 ,createtime
 ,date_format(createtime,'yyyyMMdd') as create_dt
 ,class_hour
 ,finis_percent
 ,max(case when date_format(createtime,'yyyyMMdd') = t2.dt then t2.store_code else null end) as store_code
 
 from data_shop.dwa_shop_sop_learn_exam_result_v1 t1
 left join staff_list_v3 t2 on if(length(t1.usercode)=6,concat('10',t1.usercode),t1.usercode)  = t2.employee_id
 where t1.dt = '${today-1}'
 and subplantype = 'clerkSop'
 and date_format(createtime,'yyyyMMdd') >= '${today-30}'
  and date_format(createtime,'yyyyMMdd') <= '${today-1}'
 group by title
 ,source_name
 ,usercode 
 ,mission_type
 ,sub_mission_type
 ,createtime
 ,date_format(createtime,'yyyyMMdd') 
 ,class_hour
 ,finis_percent

 ) t0
 left join base_manager_info t2 on t0.store_code = t2.store_code
 group by 
 title
 ,from_unixtime(unix_timestamp(create_dt,'yyyyMMdd'),'yyyy-MM-dd')
 ,case when from_unixtime(unix_timestamp(create_dt,'yyyyMMdd'),'yyyy-MM-dd') >= change_date then 1 else 0 end --改
 ,emplid
 ,t0.store_code 
),
sop_learn1 as (
    select 
    t1.store_code 
    
    ,count(distinct title) as sop_issue_cnts
    ,count(distinct case when finish_cnts/mission_cnts=1 then title end) as sop_finish_cnts
    ,count(distinct case when finish_cnts/mission_cnts=1 then title end)/count(distinct title) as sop_finish_per
    from sop_learn_detail t1 
    where is_start = 1
    group by t1.store_code 
    
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
),
key_task_qualified_info as ( -- 员工重点工序执行率
select 
lpad(t1.staff_code,8,'10') as staff_code

,sum(qualified_key_task_hours) as qualified_key_task_hours
,sum(key_task_hours) as key_task_hours
,sum(qualified_key_task_hours)/sum(key_task_hours) as key_task_qualified_hours_rate
from data_smartorder.app_mmc_key_task_qualified_rate_di t1 
where t1.dt = '${today-1}'
and t1.work_date <= '${TODAY-1}' 
and t1.work_date >= '${TODAY-30}' 
group by lpad(t1.staff_code,8,'10')),

vacation_situation as(  --员工请假情况统计
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

,internal_control_check as( --内控检查情况
select
order_no
,store_code
,check_date
,employee_uid
,sum(correct_check_num) as correct_check_num --合格数量
,sum(wrong_check_num) as wrong_check_num --不合格数量
,sum(success_check_num) as success_check_num --纠正合格数量
,sum(wrong_serious_check_num) as wrong_serious_check_num --严重不合格数量
from
(select
t0.*
,dense_rank()over(partition by t0.store_code order by t0.check_date desc) as rn
from default.dwd_store_operation_store_live_check_detail_v1 t0
left join data_build.dim_user_hr t1 on t0.employee_uid = t1.user_name and t1.dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
where t0.dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and user_job = '门店稽核') a
where rn = 1
group by
order_no
,store_code
,check_date
,employee_uid
)

,final_list as (
select 
t0.employee_id
,t1.emplid
,t0.name
,t0.store_code
,t0.store_name
,t0.city_name
,t0.difficulty_level_new -- 招聘等级指标
,t19.opening_days
,case when t19.opening_days >= 28 then 1 when t19.opening_days >= 20 then 2 else 0 end as opening_type -- 营业类型 1为7天营业 2为五天营业 0为其他
,t0.entry_date
,if(datediff('${TODAY-1}',t0.entry_date) >=30,30,datediff('${TODAY-1}',t0.entry_date)) as entry_days
,t0.cal_days_0
,t0.change_date0
,datediff('${TODAY-1}',t0.change_date0) as change_days
,t0.start_cdate
,t0.cal_days
,t1.work_shift_hours as work_shift_hours --增加节假日系数，无入职时间影响 t30累计出勤工时 --0226删除节假日系数，用节假日填充11.5h替代
,t1.work_shift_hours_after_change/(t0.cal_days_0/30) as work_shift_hours_2 -- 增加入职本店时间影响 --0226删除节假日系数，用节假日填充11.5h替代
,delay_task_count_24 -- t30日均24h以上超时任务数（豁免第1周） --0304增加节假日及前后七天豁免
,coalesce(t4.ab_attend_hours,0) as ab_attend_hours -- t30出勤违规总时长
,coalesce(t4.ab_attend_count,0) as ab_attend_count-- t30出勤违规次数（超半小时）
,coalesce(t4.attend_ab_cnts,0) as attend_ab_cnts-- t30出勤违规次数
,t0.b_manager_date
,t0.b_manager_days -- 成为架构负责人天数
,t1.early_arrive_hour+t1.late_leave_hour as vo_attendhours -- 需要除以entry_days乘以30 t30超时打卡工时数
,(t1.early_arrive_hour+t1.late_leave_hour)/t0.entry_days * 30 as vo_attendhours_2
,t5.t30_avg_task_time_rate --t30工序工时合格率（豁免第1周）
-- ,t6.sales_pdps_b -- t30折前日商 豁免7天
,round(t7.zonghe_correction_waste_amount/t6.total_sales_pdps_b,2) as waste_rate --t30废弃率（豁免第1周）
-- ,t21.waste_rate as waste_rate2
,t21.location_type -- 商圈类型
,t21.sell_price_rounddown
,t21.sell_price_type -- 日商类型
,t21.percent_rank_waste 
,t21.waste_score -- 废弃得分
,t8.t30_avg_check_order_rate -- t30盘点执行率豁免一周,0524 t7改为t30
,t9.check_diff_per -- t30盘点差异率豁免一周 0524 t7改为t30
,t10.execute_rate -- t30库存出店执行率（豁免第1周）
,t12.t30_verification_num_per -- t30发票回收完成率（最近1月付款发票不纳入考核）
,t11.cash_rate -- t30现金存缴完成率（最近1周现金不纳入考核）
,t13.final_t_level -- t30门店t值（豁免1周
,t14.result -- t30品控结果（豁免第1周）
,nvl(t15.appeal_punish_cnts_serious_manager,0) as appeal_punish_cnts_serious_manager-- t30运营类客诉数量（豁免第1周） -- 店长严重客诉
,nvl(t15.appeal_punish_cnts_serious_manager0,0) as appeal_punish_cnts_serious_manager0 -- 店员严重客诉
,nvl(t15.appeal_punish_cnts_common_manager,0) as appeal_punish_cnts_common_manager -- 店长普通客诉
,nvl(t15.appeal_punish_cnts_common_manager0,0) as appeal_punish_cnts_common_manager0 -- 店员普通客诉
,(nvl(t15.appeal_punish_cnts_serious_manager,0) *3*3 + nvl(t15.appeal_punish_cnts_serious_manager0,0) *1*3 + nvl(t15.appeal_punish_cnts_common_manager,0) *1*3 + nvl(t15.appeal_punish_cnts_common_manager0,0) *1*1) as appeal_punish_base_score -- 客诉分数
,t16.good_er2 -- t30好店员工时占比（豁免第1-2周）
,round(t17.fail_hours/t17.work_shift_hours2,2) as fail_hours_per -- t30失败小时占比（豁免第1-2周）
,round(t17.fail_counts/t17.total_counts,2) as fail_counts_per -- t30失败班次占比（豁免第1-2周）
,t18.sop_finish_per -- t30团队蜂窝SOP学习率（豁免第1周）
,t20.quanzhou_sell_price -- t30折前日商无豁免
,t20.quanzhou_order_cnt -- t30订单量 0601新增
,(nvl(t15.appeal_punish_cnts_serious_manager,0) *3*3 + nvl(t15.appeal_punish_cnts_serious_manager0,0) *1*3 + nvl(t15.appeal_punish_cnts_common_manager,0) *1*3 + nvl(t15.appeal_punish_cnts_common_manager0,0) *1*1)/t20.quanzhou_order_cnt * 1000 as appeal_punish_orderbase_score
,t22.work_level
,t23.workdays
,t23.total_days
,coalesce(t1.work_day_attend_cnts,0) as work_day_attend_cnts
,coalesce(t1.work_day_attend_cnts,0)/t19.opening_days as work_day_per
,coalesce(t1.holiday_day_cnts,0) as holiday_day_cnts
,coalesce(t1.holiday_attend_cnts,0) as holiday_attend_cnts
,t24.key_task_qualified_hours_rate as key_task_qualified_hours_rate
,t25.vacation_number  --请假次数
,t25.vacation_times  --请假总时长
,t26.wrong_serious_check_num  --内控检查严重不合格数量
from base_manager_info t0 
left join t30_attend_info t1 on t0.employee_id = t1.staff_code
-- left join min_manager t3 on t0.employee_id = t3.employee_id
left join delay_task_list t2 on t0.employee_id = t2.employee_id
left join ab_attend_info2 t4 on t0.employee_id = t4.employee_no
left join task_hour_info0 t5 on t0.employee_id = t5.employee_id
left join sales_pdps_list t6 on t0.store_code = t6.store_code
left join waset_list t7 on  t0.store_code = t7.store_code
left join check_order_info t8 on t0.employee_id = t8.executor
left join check_diff_info2 t9 on t0.store_code = t9.store_code
left join kucun_list1 t10 on t0.store_code = t10.store_code
left join cash_finish2 t11 on t0.store_code = t11.shop_code
left join invoice_final_list1 t12 on t0.store_code = t12.store_code
left join t_final t13 on t0.store_code = t13.store_code
left join audit_final_list t14 on t0.store_code = t14.shop_code
left join appeal_punish_info t15 on t0.store_code = t15.shop_code
left join final_goodlist t16 on t0.store_code = t16.store_code
left join fail_list2 t17 on t0.store_code = t17.store_id
left join sop_learn1 t18 on t0.store_code = t18.store_code
left join opening_days3 t19 on t0.store_code = t19.store_code
left join sell_price_list t20 on t0.store_code = t20.store_code
left join waset_location_score t21 on t0.store_code = t21.store_code
left join data_build.dwd_store_construction_roster_store_demand_v1_di t22 on t0.store_code = t22.store_id and t22.dt = '${today-1}' --最新dt 0531才有数
left join workdays_t30 t23 on t0.work_dt = t23.max_date_key
 left join key_task_qualified_info t24 on t0.employee_id = t24.staff_code
 left join vacation_situation t25 on t0.employee_id = t25.leavepeople
 left join internal_control_check t26 on t0.store_code = t26.store_code
),
final_list2 as (
select 
employee_id,
emplid,
name,
store_code,
store_name,
city_name,
difficulty_level_new,
opening_type,
entry_date,
entry_days,
cal_days_0,
change_date0,
change_days,
start_cdate,
cal_days,
work_shift_hours,
coalesce(work_shift_hours_2,work_shift_hours) as work_shift_hours_2,
delay_task_count_24,
ab_attend_hours,
ab_attend_count,
attend_ab_cnts,
b_manager_date,
b_manager_days,
vo_attendhours,
vo_attendhours_2,
t30_avg_task_time_rate,
waste_rate,
location_type,
sell_price_rounddown,
sell_price_type,
percent_rank_waste,
waste_score,
t30_avg_check_order_rate,
check_diff_per,
execute_rate,
t30_verification_num_per,
cash_rate,
final_t_level,
result,
appeal_punish_cnts_serious_manager,
appeal_punish_cnts_serious_manager0,
appeal_punish_cnts_common_manager,
appeal_punish_cnts_common_manager0,
appeal_punish_base_score,
good_er2,
fail_hours_per,
fail_counts_per,
sop_finish_per,
quanzhou_sell_price,
quanzhou_order_cnt,
appeal_punish_orderbase_score,
work_level,
key_task_qualified_hours_rate

-- 意愿度得分
,case when coalesce(work_shift_hours_2,work_shift_hours) >= 300 then 5 
when work_day_per >= 0.9 then 5

when coalesce(work_shift_hours_2,work_shift_hours) >= 280 then 4
when work_day_per >= 0.87 then 4

when coalesce(work_shift_hours_2,work_shift_hours) >= 260 then 3
when work_day_per >= 0.8 then 3
when coalesce(work_shift_hours_2,work_shift_hours) >= 220 then 2
when work_day_per >= 0.63 then 2
when coalesce(work_shift_hours_2,work_shift_hours) < 220 then 1
when work_day_per < 0.63 then 1
else null end as work_shift_score 
-- 出勤工时分 基础指标1
,case when delay_task_count_24 =0 then 5
when delay_task_count_24 <= 1 then 4
when delay_task_count_24 <= 3 then 3
when delay_task_count_24 <= 10 then 2
when delay_task_count_24 > 10 then 1
else 5 end as delay_task_score -- 超时任务分 基础指标2
,case when ab_attend_hours =0 then 0
when attend_ab_cnts <= 1 and ab_attend_hours <=1 then -1
when attend_ab_cnts <= 2 and ab_attend_hours <=2 then -2
when attend_ab_cnts <= 3 and ab_attend_hours <=3 then -3
when attend_ab_cnts <= 5 and ab_attend_hours <=5 then -4
when attend_ab_cnts > 5 or ab_attend_hours > 5 then -5
else 0 end as ab_attend_score -- 出勤违规扣分
-- 0704改出勤违规扣分标准
,case when b_manager_days >= 730 then 1
when b_manager_days >= 365 then 0.5
when b_manager_days < 365 then 0
else 0 end as manager_days_score -- 工龄分 加分
,case when vo_attendhours >= 3 then 0.25
when vo_attendhours < 3 then 0
else 0 end as vo_scores -- 义务工时 加分
-- 个人能力
,case when t30_avg_task_time_rate >= 0.98 then 5
when t30_avg_task_time_rate >= 0.95 then 4
when t30_avg_task_time_rate >= 0.9 then 3
when t30_avg_task_time_rate >= 0.85 then 2
when t30_avg_task_time_rate < 0.85 then 1
else 3 end as task_time_score -- 工序合格分 基础分 -- 改为扣分

,case when t30_avg_check_order_rate = 1 and check_diff_per <= 0.05 then 5
when t30_avg_check_order_rate >= 0.95 and check_diff_per <= 0.065 then 4
when t30_avg_check_order_rate >= 0.85 and check_diff_per <= 0.075 then 3
when t30_avg_check_order_rate >= 0.85 then 2
when t30_avg_check_order_rate < 0.85 then 1
else 3 end as check_score -- 盘点得分 基础分
,case when cash_rate >= 1 then 0 
when cash_rate >= 0.9 then -0.25
when cash_rate < 0.9 then -0.5
else 0 end as cash_score -- 现金存缴 扣分
,case when t30_verification_num_per = 1 then 0
when t30_verification_num_per >= 0.5 then -0.25
when t30_verification_num_per < 0.5 then -0.5
else 0 end as verification_score -- 发票回收 扣分
,case when execute_rate >= 0.9 then 0
when execute_rate >= 0.7 then -0.25
when execute_rate < 0.7 then -0.5
else 0 end as execute_score -- 库存出店 扣分
-- 重点工序执行率扣分
 ,case when key_task_qualified_hours_rate < 0.9 then -1 
 else 0 end as key_task_qualified_hours_rate_score
-- 门店质量
,case when final_t_level  <= 2 then 5 -- 改为1.5
when final_t_level  <= 2.5 then 4 -- 改为2
when final_t_level  <= 3.5 then 3 -- 不动
when final_t_level  <= 4 then 2
when final_t_level  > 4 then 1
else 3 end as t_score -- t档分数 基础分
-- 客诉分数 扣分
,case when appeal_punish_orderbase_score >= 15 then -2
when appeal_punish_orderbase_score >= 6 then -1
when appeal_punish_orderbase_score >= 3 then -0.5
when appeal_punish_orderbase_score < 3 then 0
else 0 end as punish_score
-- 品控得分 加分
,case when result = '00' then 1
when result = '01' then 0.5
when result = '02' then 0
else 0 end as result_score

-- 团队管理
-- 好店员工时占比 基础分
,case when difficulty_level_new in ('D2.5','D3','D4','D5','D6','D7','D8','D9') and good_er2 >= 0.82 then 5
when difficulty_level_new not in ('D2.5','D3','D4','D5','D6','D7','D8','D9') and good_er2 >= 0.92 then 5
when difficulty_level_new in ('D2.5','D3','D4','D5','D6','D7','D8','D9') and good_er2 >= 0.75 then 4
when difficulty_level_new not in ('D2.5','D3','D4','D5','D6','D7','D8','D9') and good_er2 >= 0.85 then 4
when difficulty_level_new in ('D2.5','D3','D4','D5','D6','D7','D8','D9') and good_er2 >= 0.65 then 3
when difficulty_level_new not in ('D2.5','D3','D4','D5','D6','D7','D8','D9') and good_er2 >= 0.75 then 3
when difficulty_level_new in ('D2.5','D3','D4','D5','D6','D7','D8','D9') and good_er2 >= 0.5 then 2
when difficulty_level_new not in ('D2.5','D3','D4','D5','D6','D7','D8','D9') and good_er2 >= 0.6 then 2
when difficulty_level_new in ('D2.5','D3','D4','D5','D6','D7','D8','D9') and good_er2 < 0.5 then 1
when difficulty_level_new not in ('D2.5','D3','D4','D5','D6','D7','D8','D9') and good_er2 < 0.6 then 1
else 3 end as good_score

-- 失败小时占比
,case when difficulty_level_new in ('D2.5','D3','D4','D5','D6','D7','D8','D9') and fail_hours_per >= 0.095 then -1
WHEN difficulty_level_new in ('D2.5','D3','D4','D5','D6','D7','D8','D9') and fail_hours_per >= 0.075 then -0.5
when difficulty_level_new in ('D2.5','D3','D4','D5','D6','D7','D8','D9') and fail_hours_per < 0.095 then 0
when difficulty_level_new not in ('D2.5','D3','D4','D5','D6','D7','D8','D9') and fail_hours_per >= 0.06 then -1
when difficulty_level_new not in ('D2.5','D3','D4','D5','D6','D7','D8','D9') and fail_hours_per >= 0.045 then -0.5
when difficulty_level_new not in ('D2.5','D3','D4','D5','D6','D7','D8','D9') and fail_hours_per < 0.06 then 0
else 0 end as fail_score
-- sop学习率 加分
,case when sop_finish_per >= 0.9 then 1
when sop_finish_per >= 0.8 then 0.5
when sop_finish_per < 0.8 then 0
else 0 end as sop_score 
-- 运营难度得分 
-- 0704改为最高加0.5
,case when work_level >= 6  then 0.5
when work_level <= 2 then -0.5
else 0 end as work_level_score
-- 请假扣分项
,case when vacation_number >= 3 or vacation_times > 72 then -0.5
else 0 end as vacation_score
from final_list
),
score_list as (
select 
t4.*
,(will_score*0.3 + performance_score*0.2 +store_score*0.3 +manage_score*0.2) as total_score_base
,((will_score*0.3 + performance_score*0.2 +store_score*0.3 +manage_score*0.2)+work_level_score) as total_score

from (
select 
t2.*
-- 意愿度总分
,case when (work_shift_score *0.7 + delay_task_score*0.3 + ab_attend_score + manager_days_score + vo_scores + vacation_score) >=5 then 5 
when (work_shift_score *0.7 + delay_task_score*0.3 + ab_attend_score + manager_days_score + vo_scores + vacation_score) <=1 then 1
else (work_shift_score *0.7 + delay_task_score*0.3 + ab_attend_score + manager_days_score + vo_scores + vacation_score) end as will_score
-- 个人能力总分
,case when (task_time_score *0.4 + waste_score *0.3 + check_score*0.3 +cash_score +verification_score +execute_score+key_task_qualified_hours_rate_score) >=5 then 5 -- 盘点占比0.6，废弃占比0.4 
when (task_time_score *0.4 + waste_score *0.3 + check_score*0.3 +cash_score +verification_score +execute_score+key_task_qualified_hours_rate_score) <= 1 then 1
else (task_time_score *0.4 + waste_score *0.3 + check_score*0.3 +cash_score +verification_score +execute_score+key_task_qualified_hours_rate_score) end as performance_score
-- 门店质量总分
,case when (t_score +punish_score +result_score) >= 5 then 5 
when (t_score +punish_score +result_score) <= 1 then 1 
else (t_score +punish_score +result_score) end  as store_score 
-- 团队管理总分
,case when (good_score + fail_score + sop_score) >= 5 then 5 
when (good_score + fail_score + sop_score) <= 1 then 1
else (good_score + fail_score + sop_score) end as manage_score 

from final_list2 t2
) t4
)

select t5.employee_id,
t5.emplid,
t5.name,
t5.store_code,
t5.store_name,
t5.city_name,
t5.difficulty_level_new,
t5.opening_type,
t5.entry_date,
t5.entry_days,
t5.cal_days_0,
t5.change_date0,
t5.change_days,
t5.start_cdate,
t5.cal_days,
t5.work_shift_hours,
t5.work_shift_hours_2,
t5.delay_task_count_24,
t5.ab_attend_hours,
t5.ab_attend_count,
t5.attend_ab_cnts,
t5.b_manager_date,
t5.b_manager_days,
t5.vo_attendhours,
t5.vo_attendhours_2,
t5.t30_avg_task_time_rate,
t5.waste_rate,
t5.location_type,
t5.sell_price_rounddown,
t5.sell_price_type,
t5.percent_rank_waste,
t5.waste_score,
t5.t30_avg_check_order_rate,
t5.check_diff_per,
t5.execute_rate,
t5.t30_verification_num_per,
t5.cash_rate,
t5.final_t_level,
t5.result,
t5.appeal_punish_cnts_serious_manager,
t5.appeal_punish_cnts_serious_manager0,
t5.appeal_punish_cnts_common_manager,
t5.appeal_punish_cnts_common_manager0,
t5.appeal_punish_base_score,
t5.good_er2,
t5.fail_hours_per,
t5.fail_counts_per,
t5.sop_finish_per,
t5.quanzhou_sell_price,
t5.quanzhou_order_cnt,
t5.appeal_punish_orderbase_score,
t5.work_level,
t5.work_shift_score,
t5.delay_task_score,
t5.ab_attend_score,
t5.manager_days_score,
t5.vo_scores,
t5.task_time_score,
t5.check_score,
t5.cash_score,
t5.verification_score,
t5.execute_score,
t5.t_score,
t5.punish_score,
t5.result_score,
t5.good_score,
t5.fail_score,
t5.sop_score,
t5.work_level_score,
t5.will_score,
t5.performance_score,
t5.store_score,
t5.manage_score,
t5.total_score_base,
t5.total_score

,case when t23.staff_code is not null then 1 else 0 end as is_blacklist
,case 
--when change_date >= '${TODAY-1}' then 'F' --改
--when change_days <= 14 then 'F'
when t23.staff_code is not null then 'D'
when total_score is null then 'na' 
when total_score >= 4.5 then 'S' 
when total_score >= 3.8 then 'A' 
when total_score >= 3 then 'B'
when total_score >= 2 then 'C'
when total_score < 2 then 'D'
else null end as final_rank
,t5.key_task_qualified_hours_rate
,t5.key_task_qualified_hours_rate_score
from score_list t5
left join blacklist t23 on t5.employee_id = t23.staff_code

*******************************************************************************************************************************
--门店店经理表(合并合作伙伴店经理+机动队店经理)--data_build.dwd_store_construction_manager_base_info_vi_v1_di
select
store_code,
employee_id,
name,
store_name,
city_name,
difficulty_level_new,
entry_date,
entry_days,
change_date0,
cal_days_0,
change_date,
cal_days,
start_cdate,
cal_dyas_14,
change_date_14,
b_manager_date,
b_manager_days,
from_unixtime(unix_timestamp(dt,'yyyyMMdd'),'yyyy-MM-dd') as work_dt
from data_build.dwd_store_construction_manager_base_info_vi_di
where dt ='${today-1}' 

union all

select
store_code,
employee_id,
name,
store_name,
city_name,
difficulty_level_new,
entry_date,
entry_days,
change_date0,
cal_days_0,
change_date,
cal_days,
start_cdate,
cal_days_14 as cal_dyas_14,
change_date_14,
b_manager_date,
b_manager_days,
from_unixtime(unix_timestamp(dt,'yyyyMMdd'),'yyyy-MM-dd') as work_dt
from data_build.dwd_store_construction_district_manager_base_info0_di
where dt ='${today-1}' 

=============================================================================================================
with latest_ehr_infra as ( --每人最新的花名册记录
    select
        distinct
        IF(LENGTH(t1.emplid)<8,concat('10',t1.emplid),t1.emplid) AS staff_code
        ,t1.emplid
        ,t1.name as staff_name
        ,t1.hps_d_city as city_name
        ,t1.hps_d_jobcode as position_cn
        ,case when date_format(t1.hps_hire_dt, 'yyyyMMdd') < '${DATE_SUB31DAY}'
            then if(t1.hps_d_jobcode in ('店经理'),'老店长','老员工')
            else if(t1.hps_d_jobcode in ('店经理'),'新店长','新员工')
        end as position_class
        ,t1.hps_dept_code_lv5 as store_code
        ,t1.hps_dept_descr_lv5 as store_name
        ,date_format(t1.hps_hire_dt,'yyyyMMdd') as entry_date
        ,date_format(t1.leave_dt,'yyyyMMdd') as leave_date
        ,case t1.hps_d_hr_status
            when '在职' then 1 else 0
        end   as job_status
        ,case when t1.hps_dept_descr_lv1 in ('运营管理部X') then 1 else 0 end as is_district
        ,null as hours
        ,null as total_attend_days
        ,null as punish_scl
        ,null as will_score_scl
    from data_build.pdw_psprod_ps_blf_ehr_pers_vw_view t1
    where t1.dt = '${DATE}'
        and t1.hps_dept_descr_lv1 in ('运营管理部A','运营管理部B','运营管理部X')
        and t1.hps_d_jobcode in ('店经理', '门店伙伴', '店员', '社会PT', '学生PT', '见习店经理','店副经理','内部合作经营者','内部合作辅助人','内部合作伙伴','外部合作经营者','外部合作辅助人','外部合作伙伴')
        and t1.hps_d_hr_status = '在职'
)

,no_punch as ( --下班未打卡记录
    select
        employee_no
        ,work_shift_date
        ,'下班未打卡' as mark
    from default.pdw_opc_shop_attendance_report_work_shift a
    where dt = '${DATE}'
        and date_format(work_shift_date, 'yyyyMMdd') <= '${DATE_SUB1DAY}'
        and date_format(work_shift_date, 'yyyyMMdd') >= '${DATE_SUB28DAY}'
        and work_shift_type in (1,9,12)
        and punch_start_time is not null --上班打卡
        and punch_end_time is null --下班未打卡
)

,attendance_report_work_shift_revision_t30 as ( --考勤表订正
    select
        a.work_shift_id
        ,a.employee_no
        ,a.employee_name
        ,a.store_code
        ,a.store_name
        ,a.dept_code
        ,a.work_shift_date
        ,work_shift_hours
        ,attendance_work_hours
        ,case when b.mark = '下班未打卡'
            and a.work_shift_hours = 0.5 and punch_start_time is null and punch_end_time is null --切班
            then 0 else a.absenteeism_hours end as absenteeism_hours
        ,a.arrive_late_count
        ,a.leave_early_count
        ,a.arrive_late_minutes
        ,a.leave_early_minutes
    from default.pdw_opc_shop_attendance_report_work_shift a
    left join no_punch b
    on a.employee_no = b.employee_no and a.work_shift_date = b.work_shift_date
    where a.dt = '${DATE}'
        and date_format(a.work_shift_date, 'yyyyMMdd') <= '${DATE_SUB1DAY}'
        and date_format(a.work_shift_date, 'yyyyMMdd') >= '${DATE_SUB28DAY}'
        and a.work_shift_type in (1,9,12)
)

---------旷工修正结束------------

,attendance_info as(
    select
        work_shift_id                           -- as `考勤班次ID`
        ,if(length(employee_no) = 6,concat('10',employee_no),employee_no) as staff_code --as `员工工号`
        ,employee_name                          -- as `员工姓名`
        ,store_code                             -- as `门店编码`
        ,store_name                             -- as `门店名称`
        ,dept_code                              -- as `归属部门编码`
        ,date_format(work_shift_date,'yyyy-MM-dd') as work_shift_date           -- as `考勤班次日期`
        ,if(arrive_late_count=0,null,if(arrive_late_minutes<30,null,arrive_late_count)) as arrive_late_count 		-- as `迟到次数`
		,if(leave_early_count=0,null,if(leave_early_minutes<30,null,leave_early_count))	as leave_early_count		-- as `早退次数`
		,if(absenteeism_hours=0,null,if(absenteeism_hours<0.5,null,absenteeism_hours))	as absenteeism_hours		-- as `旷工工时数`
		,null as vac_punish_count  -- as `违规请假工时数`
    from attendance_report_work_shift_revision_t30 a
    where (arrive_late_count > 0 or leave_early_count > 0 or absenteeism_hours >=4)

    UNION ALL

    select
        order_id
        ,if(length(leavepeople)<8,concat('10',leavepeople),leavepeople) as staff_code
        ,leavename as employee_name
        ,roster_shopcode as store_code
        ,roster_shopname as store_name
        ,shopcode as dept_code
        ,date_format(create_date,'yyyy-MM-dd') as vac_apply_date
        ,null as arrive_late_count
        ,null as leave_early_count
        ,null as absenteeism_hours
        ,penalty_roster_hours --最终惩处工时
    from data_smartorder.app_internal_control_vacation_da
    where dt = '${DATE_SUB1DAY}'
        and date_format(create_date, 'yyyyMMdd') <= '${DATE_SUB1DAY}'
        and date_format(create_date, 'yyyyMMdd') >= '${DATE_SUB28DAY}'
        and is_exemption_eliminate = 0
        and penalty_roster_hours >= 0.5
)

,att_ab_info as (
    select
        staff_code
        ,count(distinct
            case when
                date_format(work_shift_date,'yyyyMMdd') >= '${DATE_SUB7DAY}'
                and date_format(work_shift_date,'yyyyMMdd') <= '${DATE_SUB1DAY}'
                and absenteeism_hours >0
            then date_format(work_shift_date,'yyyyMMdd') end) as t7_abs
        ,count(distinct
            case when
                date_format(work_shift_date,'yyyyMMdd') >= '${DATE_SUB28DAY}'
                and date_format(work_shift_date,'yyyyMMdd') <= '${DATE_SUB1DAY}'
                and absenteeism_hours >0
            then date_format(work_shift_date,'yyyyMMdd') end) as t28_abs
        ,count(distinct
            case when
                date_format(work_shift_date,'yyyyMMdd') >= '${DATE_SUB7DAY}'
                and date_format(work_shift_date,'yyyyMMdd') <= '${DATE_SUB1DAY}'
                and arrive_late_count >0
            then date_format(work_shift_date,'yyyyMMdd') end) as t7_late
        ,count(distinct
            case when
                date_format(work_shift_date,'yyyyMMdd') >= '${DATE_SUB7DAY}'
                and date_format(work_shift_date,'yyyyMMdd') <= '${DATE_SUB1DAY}'
                and (arrive_late_count >0 or absenteeism_hours >0
                    or leave_early_count >0 or vac_punish_count >0)
            then date_format(work_shift_date,'yyyyMMdd') end) as t7_all_att
        ,count(distinct
            case when
                date_format(work_shift_date,'yyyyMMdd') >= '${DATE_SUB14DAY}'
                and date_format(work_shift_date,'yyyyMMdd') <= '${DATE_SUB1DAY}'
                and (arrive_late_count >0 or absenteeism_hours >0
                    or leave_early_count >0 or vac_punish_count >0)
            then date_format(work_shift_date,'yyyyMMdd') end) as t14_all_att
        ,count(distinct
            case when
                date_format(work_shift_date,'yyyyMMdd') >= '${DATE_SUB21DAY}'
                and date_format(work_shift_date,'yyyyMMdd') <= '${DATE_SUB1DAY}'
                and (arrive_late_count >0 or absenteeism_hours >0
                    or leave_early_count >0 or vac_punish_count >0)
            then date_format(work_shift_date,'yyyyMMdd') end) as t21_all_att
        ,count(distinct
            case when
                date_format(work_shift_date,'yyyyMMdd') >= '${DATE_SUB28DAY}'
                and date_format(work_shift_date,'yyyyMMdd') <= '${DATE_SUB1DAY}'
                and (arrive_late_count >0 or absenteeism_hours >0
                    or leave_early_count >0 or vac_punish_count >0)
            then date_format(work_shift_date,'yyyyMMdd') end) as t28_all_att
    from (
        select
            staff_code
            ,date_format(work_shift_date,'yyyy-MM-dd') as work_shift_date
            ,sum(coalesce(arrive_late_count,0)) as arrive_late_count
            ,sum(coalesce(leave_early_count,0)) as leave_early_count
            ,sum(coalesce(absenteeism_hours,0)) as absenteeism_hours
            ,sum(coalesce(vac_punish_count,0)) as vac_punish_count
        from attendance_info
        group by staff_code,date_format(work_shift_date,'yyyy-MM-dd')
    ) tmp
    group by staff_code
)

,should_leave_info AS (
    select
        tmp.staff_code
        ,"应离职" as protect_tag
        ,5 as protect_tag_detail
    from (
        select
            staff_code
            ,case
                when t7_abs>=2 then 1
                when t7_late>=3 then 1
                when (case when t7_abs>0 and (t7_all_att-1)>0 then t7_all_att-1 else 0 end)>=1 then 1
                when t7_all_att>=3 then 1
                when t14_all_att>=5 then 1
                when t21_all_att>=5 then 1
                when t28_all_att>=9 then 1
                when t28_abs >= 2 then 1
            else 0 end as should_leave
        from att_ab_info
    ) tmp
    left join latest_ehr_infra t1
    on tmp.staff_code = t1.staff_code
    where should_leave = 1
)

,name_bd_match as (
    select
        distinct
        IF(LENGTH(t1.emplid)<8,concat('10',t1.emplid),t1.emplid) AS staff_code --8位
        ,case
            when floor(datediff('${FDATE_SUB0DAY}',t2.resume_birth_date)/365) is null then '无年龄信息'
            when floor(datediff('${FDATE_SUB0DAY}',t2.resume_birth_date)/365) <= 22 then '疑似学生'
            else '非学生' end as position_tag
    from data_build.pdw_psprod_ps_blf_ehr_pers_vw_view t1
    left join data_shop.dw_gis_hire_recruit_detail_v1_di_view t2
    on t2.dt = '${DATE_SUB1DAY}' and length(t2.entry_user_id) >2 and t1.hps_sys_name = t2.entry_user_id
    where t1.dt = '${DATE}'
        and t1.hps_dept_descr_lv1 in ('运营管理部A','运营管理部B','运营管理部X')
        and t1.hps_d_jobcode in ('店经理', '门店伙伴', '店员', '店副经理','社会PT', '学生PT', '见习店经理','内部合作经营者','内部合作辅助人','内部合作伙伴','外部合作经营者','外部合作辅助人','外部合作伙伴')
        and t1.hps_d_hr_status = '在职'
)

,protect_tag_hist as (
    select
        staff_code
        ,protect_tag
        ,protect_tag_detail
    from (
        select
            staff_code
            ,protect_tag
            ,protect_tag_detail
            ,row_number() over(partition by staff_code order by dt desc) as rn
        from data_shop.dm_shop_staff_protect_tag_v2
        where dt <= '${DATE_SUB1DAY}'
    ) tmp
    where tmp.rn = 1
)

,shift_attend_info as (
    select
        t1.employee_no
        ,lpad(t1.employee_no,8,'10') as staff_code
        ,sum(coalesce(attendance_work_hours,0)) as attendance_work_hours
        ,count(distinct work_shift_date) as total_attend_days
    from data_shop.pdw_opc_shop_attendance_report_work_shift_view t1
    where t1.dt = '${DATE}'
        and t1.work_shift_type in (1,9,12)
    group by
        t1.employee_no
),

protect_tag_raw_mon as (
select 
staff_code
,protect_tag_raw
from data_shop.app_shop_staff_protect_tag_v2_da
where dt = date_format(date_sub(next_day('${FDATE_SUB1DAY}','mon'),7), 'yyyyMMdd')
),

--员工标签异常反馈流程(032225)
order_flow_main as(
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
where dt = '${DATE_SUB1DAY}'
and flow_code = '032225' --流程code
--and order_status in ('PROCESSING','FINISHED')
),

order_flow_groups as(
select
order_id
,max(employ_no) as employ_no --被申请人
,max(apply_type) as apply_type --申请类型
from(
select
order_id
,case when form_name = 'employ_no' then get_json_object(get_json_object(form_values,'$.[0]'),'$.value') else null end as employ_no --被申请人
,case when form_name = 'leibie' then get_json_object(get_json_object(form_values,'$.[0]'),'$.value') else null end as apply_type --申请类型
from data_build.pdw_order_store_211_order_detail_flow_form_variable_groups_da
where dt = '${DATE_SUB1DAY}'
and form_name in ('employ_no','leibie')
--and order_id = '2110159997876589'
) a
group by
order_id
),

order_flow_taskorders as(
select
order_id
,taskorder_node_id
,task_orders
,get_json_object(get_json_object(get_json_object(task_orders,'$.opLogs[1]'),'$.variableGroups[0]'),'$.formVariables.values[0].value') as handling_opinions --处理意见
,row_number() over(partition by concat(order_id,taskorder_node_id) order by taskorder_create_time desc) as rn
from data_build.pdw_order_store_211_order_detail_flow_task_taskorders
where dt = '${DATE_SUB1DAY}'
--and order_id = '2110159997876589'
and taskorder_result = 'AGREE'
and taskorder_status = 'FINISHED'
and taskorder_node_id = 'UserTask_1pg3a9a'
),

raw_list as(
select
t0.order_id --流程编码(流程信息)
,t0.create_date
,t0.order_status --流程状态(流程信息)
,t0.initiator_code --发起人编码(流程信息)
,t0.create_time --流程发起时间(流程信息)
,t0.flow_ame --流程名称(流程信息)
,t0.org_code --门店编码(流程信息)
,t0.org_name --门店名称(流程信息)
,t1.employ_no --被申请人
,t1.apply_type --申请类型
,t2.handling_opinions --处理意见
,row_number() over(partition by t1.employ_no order by t0.create_time desc) as rn --同一个人取最新申请时间
from order_flow_main t0
left join order_flow_groups t1 on t0.order_id = t1.order_id
left join order_flow_taskorders t2 on t0.order_id = t2.order_id
),

abnormal_label_list as(
select
create_date --相当于生效时间
,employ_no --被申请人
,case when apply_type = '1、本店店员是铜牌，但店长认为标签不合理' and handling_opinions = '可以豁免' then '2'
when apply_type = '3、本店或跨店店员标签很好，但实际表现很差，应该被淘汰' and handling_opinions = '可以豁免' then '4'
else null end as protect_tag_detail
,date_add(create_date,30) as cut_off_date --标签生效截止时间
from raw_list
where case when apply_type = '1、本店店员是铜牌，但店长认为标签不合理' and handling_opinions = '可以豁免' then '2'
when apply_type = '3、本店或跨店店员标签很好，但实际表现很差，应该被淘汰' and handling_opinions = '可以豁免' then '4'
else null end is not null
and rn = '1'
)

,final_list as (
    select
    distinct
        t1.staff_code
        ,t1.staff_name
        ,t1.city_name
        ,t1.position_cn
        ,t1.position_class
        ,t1.store_code
        ,t1.store_name
        ,t1.entry_date
        ,t1.leave_date
        ,t1.job_status
        ,t8.attendance_work_hours as hours
        ,t8.total_attend_days
        ,t1.punish_scl
        ,t1.will_score_scl
        ,case
        (case when t12.employ_no is not null and t12.protect_tag_detail = 2 then '银牌' --员工标签异常反馈流程(032225)
        when t12.employ_no is not null and t12.protect_tag_detail = 4 then '铜牌' --员工标签异常反馈流程(032225)
        when t10.staff_code is not null and t10.protect_tag_detail = 2 then '银牌'
        when t10.staff_code is not null and t10.protect_tag_detail = 1 then '金牌'
        when t7.staff_code is not null then '应离职' --政委输出的应离职list
            else coalesce(t3.protect_tag --出勤违规应离职
                ,if(t11.employee_id is not null --如果是店长，按照店长标签输出
                  ,(case t11.code 
                  when '0' then '钻石'
                  when '1' then '金牌'
                  when '2' then '银牌'
                  when '3' then '待观察'
                  when '4' then '铜牌'
                  when '5' then '应离职'
                  end )
                  ,(case t0.protect_tag_detail_auto
                    when '1' then '金牌'
                    when '2' then '银牌'
                    when '4' then '铜牌'
                    when '5' then '应离职' end)) --待观察日更结果
                ,if((t2.protect_tag='待观察' or t2.protect_tag is null)
                    ,if(t5.protect_tag in ('应保护','普通','金牌','银牌'),t5.protect_tag,t2.protect_tag) --当前是待观察但是历史曾作为1/2的人离职
                    ,t2.protect_tag) --每周二上传结果
                ,'待观察')
        end)
            when '钻石' then '钻石'
            when '应保护' then '金牌'
            when '金牌' then '金牌'
            when '普通' then '银牌'
            when '银牌' then '银牌'
            when '待观察' then '待观察'
            when '末位普通' then '铜牌'
            when '铜牌' then '铜牌'
            when '应离职' then '应离职'
            when '须努力' then '应离职'
        end as protect_tag
        ,case
        (case when t12.employ_no is not null and t12.protect_tag_detail = 2 then '普通' --员工标签异常反馈流程(032225)
        when t12.employ_no is not null and t12.protect_tag_detail = 4 then '末位普通' --员工标签异常反馈流程(032225)
        when t10.staff_code is not null and t10.protect_tag_detail = 2 then '普通'
        when t10.staff_code is not null and t10.protect_tag_detail = 1 then '应保护'
        when t7.staff_code is not null then '应离职' --政委输出的应离职list
            else coalesce(t3.protect_tag --出勤违规应离职
                ,if(t11.employee_id is not null --如果是店长，按照店长标签输出
                  ,(case t11.code 
                  when '0' then '应保护'
                  when '1' then '应保护'
                  when '2' then '普通'
                  when '3' then '待观察'
                  when '4' then '末位普通'
                  when '5' then '应离职'
                  end )
                  ,(case t0.protect_tag_detail_auto
                    when '1' then '应保护'
                    when '2' then '普通'
                    when '4' then '末位普通'
                    when '5' then '应离职' end)) --待观察日更结果
                ,if((t2.protect_tag='待观察' or t2.protect_tag is null)
                    ,if(t5.protect_tag in ('应保护','普通','金牌','银牌'),t5.protect_tag,t2.protect_tag) --当前是待观察但是历史曾作为1/2的人离职
                    ,t2.protect_tag) --每周二上传结果
                ,'待观察')
        end)
            when '应保护' then '1'
            when '金牌' then '1'
            when '普通' then '2'
            when '银牌' then '2'
            when '待观察' then '3'
            when '末位普通' then '4'
            when '铜牌' then '4'
            when '应离职' then '5'
            when '须努力' then '5'
        end as protect_tag_detail
        ,'${DATE_SUB0DAY}' as valid_dt
        ,case when t1.position_cn <> '店经理' and t1.position_cn <> '学生PT'
            and t4.position_tag = '疑似学生' and t6.staff_code is null then 1 else 0 end as student_suspect
        ,case when t9.store_manager_no is not null then '1' else '0'
        end as is_manager
        ,case when t8.attendance_work_hours < 60 then '1-[0,60)'
            when t8.attendance_work_hours < 200 then '2-[60,200)'
            when t8.attendance_work_hours < 600 then '3-[200,600)'
            else '4-[600,+)'
        end as mature_level
        ,t1.emplid
        ,t1.is_district
    from latest_ehr_infra t1
    left join data_shop.ods_uploads_protect_tag_0419 t2
    ON t1.staff_code = t2.staff_code
    left join should_leave_info t3
    on t1.staff_code = t3.staff_code
    left join name_bd_match t4
    on t1.staff_code = t4.staff_code and t4.position_tag = '疑似学生'
    left join protect_tag_hist t5
    on t1.staff_code = t5.staff_code
    left join data_shop.ods_uploads_student_suspect_remove t6
    on t1.staff_code = t6.staff_code
    left join data_shop.ods_uploads_should_leave t7
    on t1.staff_code = t7.staff_code
    left join shift_attend_info t8
    on t1.staff_code = t8.staff_code
    left join data_smartorder.dw_ordering_store_tag_location_ranking_info_v1 t9
    on t9.dt = '${DATE}' and t1.emplid = t9.store_manager_no
    left join data_shop.app_shop_staff_new_tag_di t0
    on t1.staff_code = lpad(t0.emplid,8,'10')
        and t0.dt <= '${DATE_SUB1DAY}'
        and t0.dt >=
            date_format(case
                when (pmod(datediff('${FDATE_SUB0DAY}','1900-01-08'),7)+1) in (2,3,4,5,6,7)
                    then date_sub('${FDATE_SUB0DAY}',pmod(datediff('${FDATE_SUB0DAY}','1900-01-08'),7))
                when (pmod(datediff('${FDATE_SUB0DAY}','1900-01-08'),7)+1) in (1)
                    then date_sub('${FDATE_SUB0DAY}',pmod(datediff('${FDATE_SUB0DAY}','1900-01-08'),7)+7)
            end,'yyyyMMdd')
    left join data_shop.ods_uploads_staff_tag_uploadv2 t10
            on t1.staff_code = t10.staff_code
    left join data_build.ods_uploads_manager_tag_4 t11 
    on t1.staff_code = t11.employee_id and from_unixtime(unix_timestamp(t11.dt,'yyyyMMdd'),'yyyy-MM-dd') = date_sub(next_day('${FDATE_SUB0DAY}','mon'),7)
    left join abnormal_label_list t12 on t1.staff_code = t12.employ_no 
    and t12.cut_off_date >= '${FDATE_SUB0DAY}' --保护标签生效30天
            ),

    protect_raw as(
    select
    staff_code
    ,protect_tag
    from final_list
    )

    select
    t0.*
    ,t1.protect_tag
    ,case when t2.employee_id is not null then '店长' else '机动队' end as postition_name
    from data_build.dwd_store_construction_manager_base_info_vi_v1_di t0
    left join protect_raw t1 on t0.employee_id = t1.staff_code
    left join data_build.dwd_store_construction_manager_base_info_vi_di t2 on t0.employee_id = t2.employee_id and t2.dt = '${DATE_SUB1DAY}'
    where t0.dt = '${DATE_SUB1DAY}'

    =======================================================================================================
    SELECT
roster_date as `日期`
,store_code as `门店编码`
,store_name as `门店名称`
,leave_date as `最后工作日`
,mgr_code as `店经理编号`
,mgr_name as `店经理姓名`
,leave_days as `离店天数`
,will_score as `意愿度得分`
,performance_score as `个人能力得分`
,store_score as `门店质量得分`
,manage_score as `团队管理得分`
,work_level_score as `运营难度得分`
,task_order_id as `降职流程编码`
,typeofdemote as `降职类型`
,protect_tag as `保护标签`
from data_build.dwd_store_mgr_protect_tag_last_ten_da
where dt = 20240527

===========================================================================================================================================================
--识别连续4天铜牌加入黑名单
select distinct
mgr_code
from(
SELECT
mgr_code
,date_sub
,count(1) as days
from(
SELECT
roster_date
,store_code
,store_name
,leave_date
,mgr_code
,mgr_name
,leave_days
,will_score
,performance_score
,store_score
,manage_score
,work_level_score
,task_order_id
,typeofdemote
,protect_tag
,date_sub(date_format(roster_date,'yyyy-MM-dd'),cast(leave_days as INT)) as date_sub
from data_build.dwd_store_mgr_protect_tag_last_ten_da
where dt = date_format(date_sub(current_date,2),'yyyyMMdd')
and cast(leave_days as INT) between '1' and '10'
and protect_tag = '铜牌'
) a
group by
mgr_code
,date_sub
) b
where days >= '4' --连续4天铜牌