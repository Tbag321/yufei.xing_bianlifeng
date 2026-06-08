########################################################################################################################################################################
------------------------------------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------------------------------------
########################################################################################################################################################################
--25年春节给班情况
with date_list as(
select distinct
roster_date
,'1' as joinkey
from data_smartorder.dw_roster_give_roster_detail_snapshot_da t0
where t0.roster_date between '2025-01-13' and '2025-02-23'
and t0.dt='${today-1}'
)

,store_list as(
select distinct
store_code
,'1' as joinkey
from data_smartorder.dw_roster_give_roster_detail_snapshot_da t0
where t0.roster_date between '2025-01-13' and '2025-02-23'
and t0.dt='${today-1}'
)

,date_store_list as(
select
roster_date
,store_code
from date_list a
left join store_list b on a.joinkey = b.joinkey
)

,blacklist as (
    select distinct 
    employee_no
    ,lpad(employee_no,8,'10') as staff_code
from data_shop.pdw_idss_ipes_admin_employee_blacklist_view -- 全量黑名单表
where dt = '${today-1}' 
    and valid_status=1 
    and start_date <= '${TODAY}'
    and end_date >= '${TODAY}'
)

,vacation_list as(
select
lpad(staff_no,8,'10') as staff_code
,third_workflow_id
,date_add(substr(vacation_start_time,1,10),mid_date) as vacation_day
from data_smartorder.dm_copy_pdw_opc_shop_attendance_original_vacation_view t0
lateral view posexplode(
 split(space(datediff(substr(vacation_end_time,1,10),substr(vacation_start_time,1,10))),'')
 ) t1 as mid_date,val
where t0.dt = '${today-1}'
--and t0.reason = '春节返乡假'
and t0.status = '2' --数据状态 0初始,1待审批,2已同意,3已拒绝,4已转交,5取消
)

--销假明细
,revoke_vacation_list as(
select
lpad(employee_no,8,'10') as staff_code
,vacation_workflow_no
,date_add(from_unixtime(unix_timestamp(start_time), 'yyyy-MM-dd'),mid_date) as revoke_vacation_day
from data_smartorder.dm_copy_pdw_opc_shop_attendance_revoke_vacation_view t0
lateral view posexplode(
 split(space(datediff(from_unixtime(unix_timestamp(end_time), 'yyyy-MM-dd'),from_unixtime(unix_timestamp(start_time), 'yyyy-MM-dd'))),'')
 ) t1 as mid_date,val
where t0.dt = '${today-1}'
and t0.workflow_status = '2' --2已同意
)

,merge_vacation_list as( --最终请假日期
select
t1.staff_code --员工编号
,t1.third_workflow_id
,t1.vacation_day --请假日期
,t2.vacation_workflow_no
,t2.revoke_vacation_day
from vacation_list t1
left join revoke_vacation_list t2 on t1.third_workflow_id = t2.vacation_workflow_no and t1.staff_code = t2.staff_code and t1.vacation_day = t2.revoke_vacation_day
where t2.vacation_workflow_no is null
)

--商圈对应关系
,district_info as(
SELECT
store_code
,district_code
from data_build.dwd_store_construction_full_capacity_perdict
where dt = '${today-2}'
)

,give_list as(
select 
t0.target_date as week
,t0.roster_date
,t0.employee_id
,t0.employee_name
,t0.protect_tag
,t0.job
,t0.store_city
,t0.store_code
,t0.store_name
,t3.district_code
,t0.givetype
,case 
when substring(t0.store_name,1,1)='区' then '机动队'
when t0.job in('店经理','储备店经理','见习店经理') then '店长'
when t0.job in('店副经理') then '店副'
else '店员'
end as position
,case
 ---完全标准班型
 when t0.start_time=6 and t0.end_time=22 then '白班'
 when t0.start_time=18 and t0.end_time=32 then '夜班'
 when t0.start_time=6 and t0.end_time=32 then '全班'
 ---重合区间区分
 when t0.start_time<=10 and t0.end_time-start_time>=21 then '全班'
 ---其他区间标签
 when t0.end_time<=24 or t0.start_time<=6 then '白班'
 when t0.end_time>24 then '夜班'
 else 0 end as label
 ,case
 when t0.start_time=6 and t0.end_time=32 then '全班'
 when t0.start_time<=10 and t0.end_time-t0.start_time>=21 then '全班'
 when t0.end_time-t0.start_time >= 8 then '长班'
 when t0.end_time-t0.start_time >= 4 and t0.end_time-t0.start_time < 8 then '短班1'
 when t0.end_time-t0.start_time < 4 then '短班'
 end as label_time
 ,case when t5.staff_code is not null then '1' else '0' end as is_vacation
 --,case when t2.employee_no is not null then '1' else '0' end as is_revoke_vacation
 ,case when t5.staff_code is not null then '0' else '1' end as is_effective
 ,case when t4.staff_code is not null then '1' else '0' end as black
from data_smartorder.dw_roster_give_roster_detail_snapshot_da t0
--left join vacation_list t1 on lpad(t0.employee_id,8,'10') = lpad(t1.staff_no,8,'10') and t0.roster_date = t1.vacation_day
--left join revoke_vacation_list t2 on lpad(t0.employee_id,8,'10') = lpad(t2.employee_no,8,'10') and t0.roster_date = t2.revoke_vacation_day
left join merge_vacation_list t5 on lpad(t0.employee_id,8,'10') = t5.staff_code and t0.roster_date = t5.vacation_day
left join district_info t3 on t0.store_code=t3.store_code
left join blacklist t4 on lpad(t0.employee_id,8,'10') = t4.staff_code
where t0.roster_date between '2025-01-13' and '2025-02-23'
and t0.dt='${today-1}'
and t0.givetype<>'全天不开工'
and t0.hps_d_hr_status='在职'
)

,full_list as(
select
store_code
,roster_date
,count(distinct case when label = '全班' then employee_id else null end) as all_day_employee_id
,count(distinct case when label = '白班' then employee_id else null end) as day_employee_id
,count(distinct case when label = '夜班' then employee_id else null end) as night_employee_id
from give_list
where is_effective = '1'
and black = '0'
and position = '机动队'
group by
store_code
,roster_date

union all

select
store_code
,roster_date
,count(distinct case when label = '全班' then employee_id else null end) as all_day_employee_id
,count(distinct case when label = '白班' then employee_id else null end) as day_employee_id
,count(distinct case when label = '夜班' then employee_id else null end) as night_employee_id
from give_list
where is_effective = '1'
and black = '0'
and position <> '机动队'
group by
store_code
,roster_date
)


,all_data as(
select
t0.roster_date
,t0.store_code
,nvl(all_day_employee_id,'0') as all_day_employee_id
,nvl(day_employee_id,'0') as day_employee_id
,nvl(night_employee_id,'0') as night_employee_id
from date_store_list t0
left join full_list t1 on t0.roster_date = t1.roster_date and t0.store_code = t1.store_code
order by t0.roster_date,t0.store_code
limit 1000000
)

,map_all_day as(
select
store_code
,concat_ws(",",collect_list(all_day_employee_id)) as map_all_day_employee_num
from all_data
group by store_code
)

,map_day as(
select
store_code
,concat_ws(",",collect_list(day_employee_id)) as map_day_employee_num
from all_data
group by store_code
)

,map_night as(
select
store_code
,concat_ws(",",collect_list(night_employee_id)) as map_night_employee_num
from all_data
group by store_code
)

,store_base_info as(
select distinct
t0.store_code
,t0.store_name
,COALESCE(case when t1.district_code = '0' then null else t1.district_code end,case t0.store_name
when '区X001北京' then '1000' when '区X002北京' then '1001'
when '区X003北京' then '1002' when '区X004天津' then '1232'
when '区X005天津' then '1231' when '区X006上海' then '1018'
when '区X007南京' then '1101'
when '区X008杭州' then '1094'when '区X009济南' then '1074'
when '区X010宁波' then '6120' when '区X012青岛' then '1080'
when '区X013北京' then '10012' when '区X014北京' then '10013'
when '区X015北京' then '10014' when '区X016北京' then '10015' when '区X017北京' then '10016'
when '区X018天津' then '1230' when '区X019上海' then '1019'
when '区X020南京' then '1100' when '区X021济南' then '1070'
when '区X024北京' then '10018' when '区X027廊坊' then '1880'
when '区X028石家庄' then '1030' when '区X029郑州' then '1210'
when '区X030常州' then '3970' when '区X031宁波' then '6121'
when '区X032苏州' then '1110' when '区X033无锡' then '1182'
when '区X034金华' then '2330' when '区X035温州' then '2320'
when '区X036北京' then '1003' when '区X037北京' then '1004' when '区X038北京' then '1005'
when '区X039北京' then '1006' when '区X040北京' then '1007' when '区X041北京' then '1008'
when '区X042北京' then '1009' when '区X043北京' then '10010'
when '区X044北京' then '10011'when '区X045北京' then '10017'
when '区X046天津' then '1233' when '区X047天津' then '1234'
when '区X048天津' then '1235' when '区X049天津' then '1236' when '区X050天津' then '1237'
when '区X051天津' then '1238' when '区X052天津' then '1239'
when '区X053常州' then '3971' when '区X054杭州' then '1093'
when '区X055杭州' then '1092' when '区X056杭州' then '1091'
when '区X057杭州' then '1090' when '区X058济南' then '1071'
when '区X059济南' then '1072' when '区X060济南' then '1073'
when '区X061南京' then '1102' when '区X062南京' then '1103'
when '区X063南京' then '1104' when '区X064南京' then '1105' when '区X065南京' then '1106'
when '区X066南京' then '1107' when '区X067郑州' then '1211'
when '区X068无锡' then '1181' when '区X069无锡' then '1180'
when '区X070苏州' then '1113' when '区X071苏州' then '1112'
when '区X072青岛' then '1081' when '区X073青岛' then '1082'
when '区X074宁波' then '6123' when '区X075宁波' then '6122'
when '区X076上海' then '1011' when '区X077上海' then '1012' when '区X078上海' then '1013'
when '区X079上海' then '1014' when '区X080上海' then '1015'
when '区X081上海' then '1016' when '区X082上海' then '1017'
when '区X083上海' then '1018' else t3.business_district_id end) as district_code
,case when t2.store_code is not null then '加盟店' else '直营店' end as store_type
from data_smartorder.dw_roster_give_roster_detail_snapshot_da t0
left join (
    select
    store_code
    ,district_code
    from data_build.dwd_store_construction_full_capacity_perdict
    where dt = '${today-2}'
) t1 on t0.store_code = t1.store_code
left join (
    select distinct 
store_code
from data_build.pdw_bach_baseinfo_shop_shop
where dt = '${today-1}'
and self_take_type = '4' --加盟店
) t2 on t0.store_code = t2.store_code
left join data_smartorder.ods_uploads_business_district_qiyang t3 on t0.store_code = t3.store_code
where t0.dt = '${today-1}'
and t0.roster_date between '2025-01-13' and '2025-02-23'
)

select
t0.store_code
,t1.store_name
,t1.district_code
,t1.store_type
,t0.map_all_day_employee_num
,t2.map_day_employee_num
,t3.map_night_employee_num
from map_all_day t0
left join store_base_info t1 on t0.store_code = t1.store_code
left join map_day t2 on t0.store_code = t2.store_code
left join map_night t3 on t0.store_code = t3.store_code
where t1.store_type='直营店'

########################################################################################################################################################################
------------------------------------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------------------------------------
########################################################################################################################################################################
--开闭店
select * from data_build.pdw_idss_mmc_cooperate_shop_open_info_view
where dt = 20241230

with leave_info as(
    select distinct
        t1.man_code as user_job_number
        ,t1.order_status
        ,date_format(create_time,'yyyy-MM-dd') as create_date
        ,date_format(final_leave_date,'yyyy-MM-dd') as leave_date
        ,'1' as is_leaving
    from data_shop.pdw_gis_workday_dimission_order_view t1
    where t1.dt = '${today-1}'
        and (t1.order_status = 'PROCESSING')
            or (date_format(final_leave_date,'yyyyMMdd') > '${today}' and final_leave = 'leave' and t1.order_status = 'FINISHED')    
)

,blacklist as (
    select distinct 
    employee_no
    ,lpad(employee_no,8,'10') as staff_code
from data_shop.pdw_idss_ipes_admin_employee_blacklist_view -- 全量黑名单表
where dt = '${today-1}' 
    and valid_status=1 
    and start_date <= '${TODAY}'
    and end_date >= '${TODAY}'
)

,attendance_days_list as( --过去一周出勤工时
select
lpad(employee_no,8,'10') as staff_code
,sum(attendance_work_hours) as attendance_work_hours
from data_build.pdw_opc_shop_attendance_report_work_shift_view
where dt = '${today-1}'
and work_shift_date between '2024-12-30' and '2025-01-05'
and work_shift_type in (1, 9, 12)
and attendance_work_hours > 0
group by
lpad(employee_no,8,'10')
)

SELECT t.* 
,t1.hps_d_hr_status --当前在职状态
,t1.hps_dept_descr_lv5 --当前架构
,case when t2.user_job_number is not null then 1 else 0 end as is_leaving 
,case when t3.staff_code is not null then 1 else 0 end as is_black 
from (
SELECT * 
,row_number() over(partition by emplid order by dt desc) as rn
from data_build.pdw_psprod_ps_blf_ehr_pers_vw_view
where dt >= 20241201 and dt <= 20250102
and hps_d_hr_status = '在职'
and hps_dept_code_lv5 in ('110000131',
'101000091',
'100000023',
'101000199',
'100005325',
'101000151',
'123000399',
'100000376',
'123000336',
'107000128',
'110000119',
'188000016',
'100001386',
'100005016',
'107000180',
'100075003',
'123000089',
'123000185',
'100005217',
'100005006',
'100001036',
'107000071',
'110000167',
'109000085',
'123000371',
'123000501',
'100005002',
'111000083',
'110000123',
'100000063',
'100036001',
'109000068',
'100000277',
'110000171',
'123000352',
'100001033',
'100000381',
'107000152',
'123000261',
'123001133',
'100000332',
'123000135',
'100002581',
'100000232',
'109000105',
'100000159',
'123000083',
'100001379',
'123000360',
'101001011',
'123000193',
'110000532',
'100000196',
'100000597',
'100005167',
'123000268')
) t
left join data_build.pdw_psprod_ps_blf_ehr_pers_vw_view t1 on t.emplid = t1.emplid and t1.dt = '${today-1}'
left join leave_info t2 on lpad(t.emplid,8,10) = lpad(t2.user_job_number,8,10)
left join blacklist t3 on lpad(t.emplid,8,10) = t3.staff_code
where t.rn = 1

-----------------------------------------------------------------------------------------------------------------------------------------------------------
--春节奖金人员清单
select
t1.staff_code
,t1.staff_name
,t1.city_name
,t1.protect_tag
,t1.protect_tag_detail
,t2.hps_d_jobcode
,t2.hps_sys_name
,t2.hps_dept_code_lv5
,t2.hps_dept_descr_lv5
,case when t3.manager_code is not null and(t2.hps_dept_descr_lv5 not like '%区X%' or t2.hps_dept_descr_lv1 not in ('运营管理部X'))
and t2.hps_d_jobcode not in ('外部合作辅助人','外部合作经营者','外部合作伙伴','内部合作辅助人','内部合作经营者','内部合作伙伴') then '店经理'
when t2.hps_d_jobcode = '店副经理' then '店副经理'
when t4.employee_id is not null and (t2.hps_dept_descr_lv5 like '%区X%' or t2.hps_dept_descr_lv1 in ('运营管理部X')) then'机动队带店店长'
when t5.employee_no is not null and (t2.hps_dept_descr_lv5 like '%区X%' or t2.hps_dept_descr_lv1 in ('运营管理部X')) then t5.relation_type
when t2.hps_dept_descr_lv5 like '%区X%' or t2.hps_dept_descr_lv1 in ('运营管理部X') then '机动队队员'
when t2.hps_d_jobcode not in ('外部合作辅助人','外部合作经营者','外部合作伙伴','内部合作辅助人','内部合作经营者','内部合作伙伴')then'店员'
else '加盟人员' end as post_name
,case when t6.business_district_id is null then t2.hps_dept_descr_lv5 else 
case t6.business_district_id
when '1000'then '区X001北京' when '1001'then '区X002北京' when '1002'then '区X003北京' when '1232'then '区X004天津' when '1231'then '区X005天津'
when '1018'then '区X006上海' when '1101'then '区X007南京' when '1094'then '区X008杭州' when '1074'then '区X009济南' when '6120'then '区X010宁波'
when '1080'then '区X012青岛' when '10012'then '区X013北京' when '10013'then '区X014北京' when '10014'then '区X015北京' when '10015'then '区X016北京'
when '10016'then '区X017北京' when '1230'then '区X018天津' when '1019'then '区X019上海' when '1100'then '区X020南京' when '1070'then '区X021济南'
when '10018'then '区X024北京' when '1880'then '区X027廊坊' when '1030'then '区X028石家庄' when '1210'then '区X029郑州' when '3970'then '区X030常州'
when '6121'then '区X031宁波' when '1110'then '区X032苏州' when '1182'then '区X033无锡' when '2330'then '区X034金华' when '2320'then '区X035温州'
when '1003'then '区X036北京' when '1004'then '区X037北京' when '1005'then '区X038北京' when '1006'then '区X039北京' when '1007'then '区X040北京'
when '1008'then '区X041北京' when '1009'then '区X042北京' when '10010'then '区X043北京' when '10011'then '区X044北京' when '10017'then '区X045北京'
when '1233'then '区X046天津' when '1234'then '区X047天津' when '1235'then '区X048天津' when '1236'then '区X049天津' when '1237'then '区X050天津'
when '1238'then '区X051天津' when '1239'then '区X052天津' when '3971'then '区X053常州' when '1093'then '区X054杭州' when '1092'then '区X055杭州'
when '1091'then '区X056杭州' when '1090'then '区X057杭州' when '1071'then '区X058济南' when '1072'then '区X059济南' when '1073'then '区X060济南'
when '1102'then '区X061南京' when '1103'then '区X062南京' when '1104'then '区X063南京' when '1105'then '区X064南京' when '1106'then '区X065南京'
when '1107'then '区X066南京' when '1211'then '区X067郑州' when '1181'then '区X068无锡' when '1180'then '区X069无锡' when '1113'then '区X070苏州'
when '1112'then '区X071苏州' when '1081'then '区X072青岛' when '1082'then '区X073青岛' when '6123'then '区X074宁波' when '6122'then '区X075宁波'
when '1011'then '区X076上海' when '1012'then '区X077上海' when '1013'then '区X078上海' when '1014'then '区X079上海' when '1015'then '区X080上海'
when '1016'then '区X081上海' when '1017'then '区X082上海' when '1018'then '区X083上海' else null end
end as business_district
from data_shop.dm_shop_staff_protect_tag_v2 t1
left join data_build.pdw_psprod_ps_blf_ehr_pers_vw_view t2 on t1.staff_code=lpad(t2.emplid,8,'10') and t2.dt='${today-1}'--hps_d_jobcodein('店副经理')
--leftjoindata_build.dwd_store_construction_manager_base_info_vi_dit3ont1.staff_code=t3.employee_idandt3.dt='${today-2}'--店长
left join data_build.pdw_opc_shop_ehr_staff_dept_view t3 on t2.hps_dept_code_lv5 = t3.dept_code and lpad(t2.emplid,8,'10')=lpad(t3.manager_code,8,'10') and t3.dt='${today-1}'--店长
left join data_build.dwd_store_construction_district_manager_base_info0_di t4 on t1.staff_code=t4.employee_id and t4.dt='${today-2}'--带店机动队(店经理)
left join(select
 * from(
select
employee_no,
shop_code,
relation_type,
dt,
row_number() over(partition by employee_no order by create_time desc) as rn
from data_smartorder.dm_copy_pdw_opc_roster_motor_shop_relation_view
where dt ='${today-1}'
and delete_ts=0
and end_date>='${TODAY}'
) a
where rn=1
) t5 on t1.staff_code=lpad(t5.employee_no,8,'10')--带店机动队(店长/店副/陪跑店长/陪跑店副)
left join data_smartorder.ods_uploads_business_district_qiyang t6 on t2.hps_dept_code_lv5 = t6.store_code
where t1.dt='${today-1}'

#########################################################################################################################################################################
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------
#########################################################################################################################################################################
--春节期间给班排班出勤统计(计算春节出勤奖金)
begin
    with staff_list as(
    select
    from_unixtime(unix_timestamp(t1.dt,'yyyyMMdd'),'yyyy-MM-dd') as roster_date
    ,t1.*
    ,t2.hps_d_jobcode
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
    --left join data_build.dwd_store_construction_manager_base_info_vi_di t3 on t1.staff_code = t3.employee_id and t3.dt = '${today-2}'  --店长
    left join data_build.pdw_opc_shop_ehr_staff_dept_view t3 on t2.hps_dept_code_lv5 = t3.dept_code and lpad(t2.emplid,8,'10') = lpad(t3.manager_code,8,'10') and t3.dt = t1.dt --店长
    left join data_build.dwd_store_construction_district_manager_base_info0_di t4 on t1.staff_code = t4.employee_id and t4.dt = t1.dt  --带店机动队(店经理)
    left join (select
    * from(
    select
    from_unixtime(unix_timestamp(dt,'yyyyMMdd'),'yyyy-MM-dd') as roster_date,
    employee_no,
    shop_code,
    relation_type,
    dt,
    row_number() over(partition by concat(dt,employee_no) order by create_time desc) as rn
    from data_smartorder.dm_copy_pdw_opc_roster_motor_shop_relation_view
    where dt between '20260209' and '20260303'
    and delete_ts = 0
    and end_date >= date_add(from_unixtime(unix_timestamp(dt,'yyyyMMdd'),'yyyy-MM-dd'),1)
    ) a
    where rn = 1
    ) t5 on t1.staff_code = lpad(t5.employee_no,8,'10') and from_unixtime(unix_timestamp(t1.dt,'yyyyMMdd'),'yyyy-MM-dd') = t5.roster_date --带店机动队(店长/店副/陪跑店长/陪跑店副)
    where t1.dt between '20260209' and '20260303'

    union all

    select
    from_unixtime(unix_timestamp(dt,'yyyyMMdd'),'yyyy-MM-dd') as roster_date
    ,lpad(emplid,8,'10') as staff_code
    ,name as staff_name
    ,hps_d_city as city_name
    ,hps_d_jobcode as position_cn
    ,null as position_class
    ,hps_dept_code_lv5 as store_code
    ,hps_dept_descr_lv5 as store_name
    ,date_format(hps_hire_dt,'yyyyMMdd') as entry_date
    ,null as leave_date
    ,null as job_status
    ,null as hours
    ,null as total_attend_days
    ,null as punish_scl
    ,null as will_score_scl
    ,null as protect_tag
    ,null as protect_tag_detail
    ,dt as valid_dt
    ,null as student_suspect
    ,null as is_manager
    ,null as mature_level
    ,null as emplid
    ,null as is_district
    ,null as is_quality
    ,null as protect_tag_detail_new
    ,null as potential_leave
    ,null as refuse_sec_manager_num
    ,dt
    ,hps_d_jobcode
    ,'店员' as post_name
    from data_build.pdw_psprod_ps_blf_ehr_pers_vw_view
    where dt between '20260209' and '20260303'
    and hps_d_hr_status = '在职'
    and hps_d_jobcode = '预备伙伴'
    )

    ,blacklist as (
        select distinct 
        employee_no
        ,lpad(employee_no,8,'10') as staff_code
    from data_shop.pdw_idss_ipes_admin_employee_blacklist_view -- 全量黑名单表
    where dt = '${today-1}' 
        and valid_status=1 
        and start_date <= '${TODAY}'
        and end_date >= '${TODAY}'
    )

    ,vacation_list as(
    select
    lpad(staff_no,8,'10') as staff_code
    ,third_workflow_id
    ,date_add(substr(vacation_start_time,1,10),mid_date) as vacation_day
    from data_smartorder.dm_copy_pdw_opc_shop_attendance_original_vacation_view t0
    lateral view posexplode(
    split(space(datediff(substr(vacation_end_time,1,10),substr(vacation_start_time,1,10))),'')
    ) t1 as mid_date,val
    where t0.dt = '${today-1}'
    and t0.reason = '春节返乡假' --只看返乡假，其它假期不算请假，应该正常给班
    and t0.status = '2' --数据状态 0初始,1待审批,2已同意,3已拒绝,4已转交,5取消
    )

    --销假明细
    ,revoke_vacation_list as(
    select
    lpad(employee_no,8,'10') as staff_code
    ,vacation_workflow_no
    ,date_add(from_unixtime(unix_timestamp(start_time), 'yyyy-MM-dd'),mid_date) as revoke_vacation_day
    from data_smartorder.dm_copy_pdw_opc_shop_attendance_revoke_vacation_view t0
    lateral view posexplode(
    split(space(datediff(from_unixtime(unix_timestamp(end_time), 'yyyy-MM-dd'),from_unixtime(unix_timestamp(start_time), 'yyyy-MM-dd'))),'')
    ) t1 as mid_date,val
    where t0.dt = '${today-1}'
    and t0.workflow_status = '2' --2已同意
    )

    ,merge_vacation_list as( --最终请假日期
    select
    t1.staff_code --员工编号
    --,t1.third_workflow_id
    ,t1.vacation_day --请假日期
    --,t2.vacation_workflow_no
    --,t2.revoke_vacation_day
    from vacation_list t1
    left join revoke_vacation_list t2 on t1.third_workflow_id = t2.vacation_workflow_no and t1.staff_code = t2.staff_code and t1.vacation_day = t2.revoke_vacation_day
    where t2.vacation_workflow_no is null
    group by
    t1.staff_code --员工编号
    ,t1.vacation_day --请假日期
    )

    ,give_list as(
    select distinct
    t0.target_date as week
    ,t0.roster_date
    ,lpad(t0.employee_id,8,'10') as staff_code
    ,t0.employee_name
    ,t0.protect_tag
    ,t0.job
    ,t0.store_city
    ,t0.store_code
    ,t0.store_name
    ,t0.givetype
    ,case 
    when substring(t0.store_name,1,1)='区' then '机动队'
    when t0.job in('店经理','储备店经理','见习店经理') then '店长'
    when t0.job in('店副经理') then '店副'
    else '店员'
    end as position
    ,case when t5.staff_code is not null then '1' else '0' end as is_vacation
    --,case when t2.employee_no is not null then '1' else '0' end as is_revoke_vacation
    ,case when t5.staff_code is not null then '0' else '1' end as is_effective
    ,case when t4.staff_code is not null then '1' else '0' end as black
    from data_smartorder.dw_roster_give_roster_detail_snapshot_da t0
    left join merge_vacation_list t5 on lpad(t0.employee_id,8,'10') = t5.staff_code and t0.roster_date = t5.vacation_day
    left join blacklist t4 on lpad(t0.employee_id,8,'10') = t4.staff_code
    where t0.roster_date between '2026-02-09' and '2026-03-03'
    and t0.dt='${today-1}'
    and t0.givetype<>'全天不开工'
    and t0.hps_d_hr_status='在职'
    )

    --排班(做去重处理)
    ,shift_raw as ( --是否排班
    select distinct
    lpad(employee_id,8,'10') as staff_code
    --,store_id
    --,store_name
    ,work_date
    --,start_time
    --,end_time
    --,is_night
    from data_build.dw_roster_effect_roster_detail_info_da_view 
    where dt = '${today-1}'
    and store_type_desc = '门店'
    and class_id in ('0','-5')
    and store_type = '0'
    and sale_type <> '全天不营业'
    and roster_source = '成功班表'
    )

    --出勤
    ,attendance_raw as( --是否出勤
    select 
    lpad(employee_no,8,'10') as staff_code
    ,employee_name
    ,work_shift_date
    ,store_code
    ,store_name
    ,attendance_start_time
    ,attendance_end_time
    ,attendance_work_hours --考勤小时数
    ,attendance_night_work_hours --夜班考勤小时数
    ,arrive_late_count --迟到次数
    ,leave_early_count --早退次数
    ,absenteeism_hours --旷工考勤数
    from
    data_shop.pdw_opc_shop_attendance_report_work_shift_view
    where dt = '${today-1}'
    and work_shift_type in (1, 9, 12)
    )

    select
    t1.*
    ,t2.is_vacation --是否请假
    ,t2.is_effective --是否有效
    ,t2.black --是否黑名单
    ,case when t3.staff_code is not null then '1' else '0' end as effect_roster --是否排班
    --,t3.start_time
    --,t3.end_time
    --,t3.is_night
    ,t4.store_code
    ,t4.store_name
    ,t4.attendance_start_time
    ,t4.attendance_end_time
    ,t4.attendance_work_hours
    ,t4.attendance_night_work_hours
    ,t4.arrive_late_count --迟到次数
    ,t4.leave_early_count --早退次数
    ,t4.absenteeism_hours
    from staff_list t1
    left join give_list t2 on t1.staff_code = t2.staff_code and t1.roster_date = t2.roster_date --给班
    left join shift_raw t3 on t1.staff_code = t3.staff_code and t1.roster_date = t3.work_date --排班
    left join attendance_raw t4 on t1.staff_code = t4.staff_code and t1.roster_date = t4.work_shift_date --出勤
end



--离职中
   select distinct
        t1.man_code as user_job_number
        ,t1.order_status
        ,date_format(create_time,'yyyy-MM-dd') as create_date
        ,date_format(final_leave_date,'yyyy-MM-dd') as leave_date
        ,'1' as is_leaving
    from data_shop.pdw_gis_workday_dimission_order_view t1
    where t1.dt = '${today-1}'
        and (t1.order_status = 'PROCESSING')
            or (date_format(final_leave_date,'yyyyMMdd') > t1.dt and final_leave = 'noLeave' and t1.order_status = 'FINISHED')
            or (date_format(final_leave_date,'yyyyMMdd') > t1.dt and final_leave = 'no_leave' and t1.order_status = 'FINISHED')

---------------------------------------------------------------------------------------------------------------------------------------
--失败班次
select
work_date
,sum(all_shift) as all_shift
,sum(failue_shifts) as failue_shifts
from(
select
store_city
,store_code
,week_monday
,work_date
,roster_type
,shift_source
,is_short
,count(1) as all_shift
,sum(case when employee_id is null then 1 else 0 end) as failue_shifts
from
(
select
store_city
,store_id as store_code
,date_sub(next_day(work_date,'mon'),7) as week_monday
,work_date
,roster_source
,employee_id
,is_night
,is_long
,if(end_time-start_time>-4,'至少4小时班次','4小时一下短班') as is_short
,work_hours
,case
when class_id = '0' then '运营班次'
when class_id = '-5' and attr_id='342' then '储备班次'
when class_id = '-5' and attr_id='343' then '新人班次'
when class_id = '-2' then '培训班次'
when class_id = '-5' then '项目班次'
when class_id = '-6' then '外卖班次'
when class_id = '-7' then '物流班次'
else '其他'
end as roster_type
,case when version_source in ('managerchangeroster','manager_dispatch','freeshift') then '店长'
when version_source in ('employeerejectshift') then '员工拒绝'
when version_source in ('staffleave') then '员工离职'
when version_source in ('vocationchange') then '员工请假'
else '其他'
end as shift_source
from data_smartorder.dw_roster_roster_detail_info_da
where dt = 20250223
and store_type_desc = '门店'
and end_time - start_time >= 4
) aa
group by
store_city
,store_code
,week_monday
,work_date
,roster_type
,shift_source
,is_short
) t
where roster_type = '运营班次'
group by
work_date

work_days_original_1 as
(
 select
 t1.dt
 ,t1.staff_code
 ,t1.target_date
 ,from_unixtime(unix_timestamp(t1.dt,'yyyyMMdd'),'yyyy-MM-dd') as new_dt
 ,t2.day_of_week_name
 from data_smartorder.dm_roster_staff_available_di t1



 inner join (
select max(dt) as max_dt
from data_smartorder.dm_roster_staff_available_di
where dt >= '${DATE_SUB2DAY}'
and dt <= '${DATE}'
) tmp
on t1.dt = tmp.max_dt


 left join data_build.dim_date_ya_v2 t2
 on from_unixtime(unix_timestamp(t1.dt,'yyyyMMdd'),'yyyy-MM-dd') = t2.date_key
 where t1.dt >= '${DATE_SUB2DAY}'
    and t1.dt <= '${DATE}'

 and is_available_roster = 1
),


select
* 
,case when t2.is_holiday = '1' then '1' else is_available_roster end as is_available_roster
from data_smartorder.dm_roster_staff_available_di t1
left join data_build.dim_date_ya_v2 t2 on t1.target_date = t2.date_key
where t1.dt = 20250325


with store_info as (
select
    store_code,
    store_name,
    store_city,
    '1' as key_a

from data_build.dw_gis_store_org_info_view a 
where  store_type = '1'

)
,date_info as (
select
    date_key,
    --date_week,
    '1' as key_b

from data_build.dim_date_ya_v2 a 


)
,uk_info as (
select
    a.store_city,
    a.store_code,
    a.store_name,
    b.date_key

from store_info a
left join date_info b on a.key_a = b.key_b
where b.date_key >= '${TODAY-90}'
and b.date_key <= '${TODAY-1}'
)
,uk_info_all as (
select
    a.store_city,
    a.store_code,
    a.store_name,
    a.date_key,
    '业务自招' as position_demand_supplier_desc
from uk_info a 
union all 
select
    a.store_city,
    a.store_code,
    a.store_name,
    a.date_key,
    '招聘部' as position_demand_supplier_desc
from uk_info a 
)
,dc_info as (
select
    change_date as dt_date,
    if(position_demand_supplier_desc ='招聘部','招聘部','业务自招') as position_demand_supplier_desc,
    position_dept_code,
    sum(delivery_candiddate     ) as delivery_candiddate  ,
    sum(hire_push               ) as hire_push            ,
    sum(wait_for_review         ) as wait_for_review      ,
    sum(wait_theory_train       ) as wait_theory_train    ,
    sum(push_theory_task        ) as push_theory_task     ,
    sum(pass_theory_task        ) as pass_theory_task     ,
    sum(ing_practice_task       ) as ing_practice_task    ,
    sum(pass_practice_task      ) as pass_practice_task   ,
    sum(finish_contracte        ) as finish_contracte     ,
    sum(arrive_store            ) as arrive_store         

from data_gis_h3.app_gis_store_recruit_funel_diff_by_day a 

group by 
    change_date,
    if(position_demand_supplier_desc ='招聘部','招聘部','业务自招'),
    position_dept_code

)
--,recruitor_rank as (
--select
--  from_unixtime(unix_timestamp(dt,'yyyyMMdd'),'yyyy-MM-dd') as dt_date,
--  user_no,
--  user_id,
--  user_dept_type,
--  department_name,
--  old_person,
--  cost_class,
--  dc_class,
--  r_class,
--  rk
--  
--from data_gis_h3.mid_gis_h3_recuitor_level_rank_di a 
--where dt >= '${today-90}'
--)
,user_info as (
select
    user_name,
    user_no,
    split(department_name,'/')[size(split(department_name,'/'))-1] as department_name,
    join_date,
    leave_date,
    user_job_code,
    user_job

from data_gis_h3.mid_gis_h3_user_hr_info_view a 
where dt = '${today-1}'
)
,base_info as (
select
    dt,
    a.dt_date,
    --a.handler_dept,
    
    --if(length(handler) = 6, concat('10', handler) , handler) as handler,
    --u.department_name,
    --if(u.department_name like '%招聘%'
    --    ,if(length(handler) = 6, concat('10', handler) , handler)
    --    ,ur.hps_dept_code_lv5
    --    ) as unit_key,
    --'业务自招' as position_demand_supplier_desc,
    case
        when u.department_name like '%招聘%' then '招聘部'
        else '业务自招'
    end as position_demand_supplier_desc,
    store_code as store_code,
    --if(datediff(a.dt_date,u.join_date) >=15,'old','new') as old_person,
    --count(distinct candidate_id) as cal_user_cnt,
    --count(distinct if(cal_class like '%被%',candidate_id,null))
    --    /count(distinct candidate_id) as beidong_user_rate,
    --count(distinct if(candidate_type='老用户',candidate_id,null))
    --    /count(distinct candidate_id) as old_user_rate,
    --count(distinct if(status ='2',candidate_id,null)) as read_user_cnt,
    --count(distinct if((back_send_time is not null and back_type != 'resume'),candidate_id,null)) as back_user_cnt,
    --count(distinct if(is_qingqiu_wechat =1,candidate_id,null)) as req_info_user_cnt,
    --count(distinct if(is_have_wechat =1,candidate_id,null)) as re_info_user_cnt,
    count(distinct if(flow_order_id is not null,candidate_id,null)) as flow_user_cnt,
    --count(distinct if(flow_order_id is not null and flow_way = 'location',candidate_id,null)) as lcflow_user_cnt,
    count(distinct if(flow_order_id is not null and flow_order_state ='FINISHED',candidate_id,null)) as flowf_user_cnt,
    count(distinct if(recruit_order_id is not null,candidate_id,null)) as dc_user_cnt,
    count(distinct if(is_wish like '有',candidate_id,null)) as wish_user_cnt,
    count(distinct handler) as handler_cnt,
    collect_set(map('test', 'test1'
--        'department_name',ri.department_name,
--                    'dc_class',dc_class,
--                    'r_class',r_class
--                    'rk',ri.rk
                )) as handler_list
from data_gis_h3.mid_gis_h3_cal_convert_base_info_da a 
--left join recruitor_rank ri on if(length(handler) = 6, concat('10', handler) , handler) = ri.user_no
--    and a.dt_date = ri.dt_date
left join user_info u on a.handler = u.user_no
--left join p_user_info ur on a.dt_date = ur.dt_date and if(length(handler) = 6, concat('10', handler) , handler)  = ur.user_no

where dt = '${today-1}'
group by 
    dt,
    a.dt_date,
    store_code,
    case
        when u.department_name like '%招聘%' then '招聘部'
        else '业务自招'
    end
   
)
select
    K.date_key,
    K.store_city,
    K.store_code,
    K.store_name,
    k.position_demand_supplier_desc,
    --a.cal_user_cnt,
    --a.read_user_cnt,
    --a.back_user_cnt,
    --a.req_info_user_cnt,
    --a.re_info_user_cnt,
    a.flow_user_cnt,
    a.flowf_user_cnt,
    a.handler_cnt,
    
    
  --nvl(u.department_name,'-') as department_name,-- like '%中台H3%'
  --nvl(u.user_no,a.position_dept_code) as onwer_id,
  
    d.delivery_candiddate,
    d.hire_push,
    d.wait_for_review, --
    d.wait_theory_train,--安全审核
    d.push_theory_task,
    d.pass_theory_task,

    d.ing_practice_task,
    d.pass_practice_task,
    d.finish_contracte,
    d.arrive_store,
    a.handler_list
    

from uk_info_all k 
left join base_info a on k.store_code = a.store_code and k.date_key = a.dt_date
    and k.position_demand_supplier_desc = a.position_demand_supplier_desc
left join dc_info d on k.store_code = d.position_dept_code
    and k.date_key = d.dt_date
    and k.position_demand_supplier_desc = d.position_demand_supplier_desc








with no_vip_list as(
    select distinct
    t0.user_id
    ,t0.store_code
    from
 data_build.dw_order_sku_v1 t0
 left join data_build.ods_uploads_store_vip t1 on t0.user_id = t1.user_id and t0.store_code = t1.shop_code
WHERE 
 t0.dt = DATE_FORMAT(DATE_SUB(CURRENT_DATE(), 1), 'yyyyMMdd')
 AND t0.store_code IN ('100078005',
'100079012',
'100000696',
'100009001',
'100000276',
'100001382',
'100000685',
'100000235')
 AND t0.store_type = '0'
 AND t0.order_status = 'FINISHED'
 AND t0.sku_quantity > 0
 AND t0.order_date BETWEEN '2024-07-15' and '2024-09-08'
 and t1.user_id is null 
)



    SELECT 
 t0.store_code
 ,t0.store_name
 ,date_sub(next_day(t0.order_date,'mon'),7) AS week
 ,count(distinct case when t1.user_id is not null then t1.user_id else null end) as no_vip_num
 ,SUM(case when t1.user_id is not null then t0.payable_price else 0 end)/7 as no_vip_payable_price
 ,SUM(t0.payable_price)/7 AS all_payable_price
FROM
 data_build.dw_order_sku_v1 t0
 left join no_vip_list t1 on t0.user_id = t1.user_id and t0.store_code = t1.store_code
WHERE 
 t0.dt = DATE_FORMAT(DATE_SUB(CURRENT_DATE(), 1), 'yyyyMMdd')
 AND t0.store_code IN ('100078005',
'100079012',
'100000696',
'100009001',
'100000276',
'100001382',
'100000685',
'100000235')
 AND t0.store_type = '0'
 AND t0.order_status = 'FINISHED'
 AND t0.sku_quantity > 0
 AND t0.order_date BETWEEN '2024-07-15' and '2025-04-09' 
GROUP BY 
 t0.store_code
 ,t0.store_name 
 ,date_sub(next_day(t0.order_date,'mon'),7)

 





with district_gap as(
SELECT
dt
,district_code
,avg(gap_all_district) as gap_all_district
from data_build.dwd_store_construction_store_groups_recruit_gap
where dt >= 20250224
group by
dt
,district_code
)

,store_gap as(
SELECT
dt
,sum(gap_new) as store_gap
from data_build.dwd_store_construction_store_groups_recruit_gap
where dt >= 20250224
group by
dt
)

,day_list as(
select
t1.dt
,t1.store_gap
,t2.gap_all_district
from store_gap t1
left join
(select
dt
,sum(gap_all_district) as gap_all_district
from district_gap
group by
dt) t2
on t1.dt = t2.dt
)

select
date_add(from_unixtime(unix_timestamp(dt, 'yyyyMMdd'),'yyyy-MM-dd'),7 - case when dayofweek(from_unixtime(unix_timestamp(dt, 'yyyyMMdd'),'yyyy-MM-dd')) = 1 then 7 else dayofweek(from_unixtime(unix_timestamp(dt, 'yyyyMMdd'),'yyyy-MM-dd')) - 1 end) as record_week
,avg(store_gap) as store_gap
,avg(gap_all_district) as gap_all_district
from day_list
group by
date_add(from_unixtime(unix_timestamp(dt, 'yyyyMMdd'),'yyyy-MM-dd'),7 - case when dayofweek(from_unixtime(unix_timestamp(dt, 'yyyyMMdd'),'yyyy-MM-dd')) = 1 then 7 else dayofweek(from_unixtime(unix_timestamp(dt, 'yyyyMMdd'),'yyyy-MM-dd')) - 1 end)








with staff_list as(
select
t1.*
,t2.hps_d_jobcode
,case when t3.manager_code is not null and (t2.hps_dept_descr_lv5 not like '%区X%' or t2.hps_dept_descr_lv1 not in ('运营管理部X'))
and t2.hps_d_jobcode not in ('外部合作辅助人','外部合作经营者','外部合作伙伴','内部合作辅助人','内部合作经营者','内部合作伙伴') then '店经理'
when t2.hps_d_jobcode = '店副经理' then '店副经理'
when t4.employee_id is not null and (t2.hps_dept_descr_lv5 like '%区X%' or t2.hps_dept_descr_lv1 in ('运营管理部X')) then '机动队带店店长'
when t5.employee_no is not null and (t2.hps_dept_descr_lv5 like '%区X%' or t2.hps_dept_descr_lv1 in ('运营管理部X'))  then t5.relation_type
when t2.hps_dept_descr_lv5 like '%区X%' or t2.hps_dept_descr_lv1 in ('运营管理部X') then '机动队队员'
when t2.hps_d_jobcode not in ('外部合作辅助人','外部合作经营者','外部合作伙伴','内部合作辅助人','内部合作经营者','内部合作伙伴') then '店员'
else t2.hps_d_jobcode end as post_name
from data_shop.dm_shop_staff_protect_tag_v2 t1
left join data_build.pdw_psprod_ps_blf_ehr_pers_vw_view t2 on t1.staff_code = lpad(t2.emplid,8,'10') and t2.dt = '${today-1}' --hps_d_jobcode in ('店副经理')
--left join data_build.dwd_store_construction_manager_base_info_vi_di t3 on t1.staff_code = t3.employee_id and t3.dt = '${today-2}'  --店长
left join data_build.pdw_opc_shop_ehr_staff_dept_view t3 on t2.hps_dept_code_lv5 = t3.dept_code and lpad(t2.emplid,8,'10') = lpad(t3.manager_code,8,'10') and t3.dt = '${today-1}' --店长
left join data_build.dwd_store_construction_district_manager_base_info0_di t4 on t1.staff_code = t4.employee_id and t4.dt = '${today-2}'  --带店机动队(店经理)
left join (select
* from(
select 
employee_no,
shop_code,
relation_type,
dt,
row_number() over(partition by employee_no order by create_time desc) as rn
from data_smartorder.dm_copy_pdw_opc_roster_motor_shop_relation_view
where dt ='${today-1}'
and delete_ts = 0
and end_date >= '${TODAY}'
) a
where rn = 1
) t5 on t1.staff_code = lpad(t5.employee_no,8,'10') --带店机动队(店长/店副/陪跑店长/陪跑店副)
left join data_smartorder.ods_uploads_business_district_qiyang t6 on t1.store_code = t6.store_code
where t1.dt = '${today-1}'
)

,raw_list as(
select
t1.staff_code
,t1.staff_name
,t1.city_name
,t1.store_code
,t1.store_name
,t1.hours
,t1.protect_tag_detail_new
,t1.post_name
,case when t1.post_name in ('内部合作辅助人','内部合作伙伴','内部合作经营者','外部合作辅助人','外部合作伙伴','外部合作经营者') then min_dt else '20350331' end as end_day
from staff_list t1
left join(
SELECT
lpad(emplid,8,'10') as staff_code
,hps_d_jobcode
,min(dt) as min_dt
from data_build.pdw_psprod_ps_blf_ehr_pers_vw_view
where dt > 20170101
GROUP BY
lpad(emplid,8,'10')
,hps_d_jobcode
) t2 on t1.staff_code = t2.staff_code
and t1.hps_d_jobcode = t2.hps_d_jobcode
)

select
t1.staff_code
,t1.staff_name
,t1.city_name
,t1.store_code
,t1.store_name
,t1.hours
,t1.protect_tag_detail_new
,t1.post_name
,t1.end_day
,sum(coalesce(attendance_work_hours,0)) as attendance_work_hours
,count(distinct work_shift_date) as total_attend_days
from raw_list t1
left join (
select
t1.*
from data_shop.pdw_opc_shop_attendance_report_work_shift_view t1
left join data_build.pdw_psprod_ps_blf_ehr_pers_vw_view t2
on lpad(t1.employee_no,8,'10') = lpad(t2.emplid,8,'10')
and t1.work_shift_date = from_unixtime(unix_timestamp(t2.dt, 'yyyyMMdd'),'yyyy-MM-dd')
and t2.dt > 20160101
where t1.dt = '${today-1}'
and t2.hps_d_jobcode not in ('内部合作辅助人','内部合作伙伴','内部合作经营者','外部合作辅助人','外部合作伙伴','外部合作经营者')
) t2
on t1.staff_code = lpad(t2.employee_no,8,'10')
and t2.work_shift_type in (1,9,12)
and t2.work_shift_date < from_unixtime(unix_timestamp(t1.end_day, 'yyyyMMdd'),'yyyy-MM-dd')
and attendance_work_hours > 0
group by
t1.staff_code
,t1.staff_name
,t1.city_name
,t1.store_code
,t1.store_name
,t1.hours
,t1.protect_tag_detail_new
,t1.post_name
,t1.end_day





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

staff_list as( --更新入职日期，防止换签导致的入职日期刷新
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
from staff_list t
)

,staff_list_1 as(
select * from raw_list
where to_date(hps_hire_date) = new_dt
and to_date(hps_hire_date) between '2023-01-30' and '2025-01-30'
)

,attendance_list as(
select
t1.new_dt
,lpad(t1.emplid,8,'10') as staff_code
,t1.name
,t1.hps_d_hr_status
,t1.hps_d_jobcode
,t1.hps_hire_date
,max(work_shift_date) as max_work_shift_date --最后一天出勤日期
,sum(coalesce(attendance_work_hours,0)) as attendance_work_hours
,count(distinct work_shift_date) as total_attend_days
from staff_list_1 t1
left join data_shop.pdw_opc_shop_attendance_report_work_shift_view t2
on lpad(t1.emplid,8,'10') = lpad(t2.employee_no,8,'10')
and t2.work_shift_type in (1,9,12)
and t2.work_shift_date >= to_date(t1.hps_hire_date)
and t2.attendance_work_hours > 0
and t2.dt = '${today-1}'
group by
t1.new_dt
,lpad(t1.emplid,8,'10')
,t1.name
,t1.hps_d_hr_status
,t1.hps_d_jobcode
,t1.hps_hire_date
)

select
t1.*
,COALESCE(t2.protect_tag_detail,t3.protect_tag_detail) as protect_tag_detail
from attendance_list t1
left join(
select
from_unixtime(unix_timestamp(dt, 'yyyyMMdd'),'yyyy-MM-dd') as record_date
,staff_code
,COALESCE(protect_tag_detail_new,protect_tag_detail) as protect_tag_detail
from data_shop.dm_shop_staff_protect_tag_v2
where dt > 20160101
) t2
on t1.staff_code = t2.staff_code
and t1.max_work_shift_date = t2.record_date
left join(
select
from_unixtime(unix_timestamp(dt, 'yyyyMMdd'),'yyyy-MM-dd') as record_date
,staff_code
,COALESCE(protect_tag_detail_new,protect_tag_detail) as protect_tag_detail
from data_shop.dm_shop_staff_protect_tag_v2
where dt > 20160101
) t3
on t1.staff_code = t3.staff_code
and t1.max_work_shift_date = date_add(t3.record_date,1)

------------------------------------------------------------------------------------------------------------------------------------
--被加盟人员情况
with number_data as(
SELECT t1.*
,case when t1.manager_code != lag(t1.manager_code,1,null) over (partition by t1.dept_code order by t1.dt)
or lag(t1.manager_code,1,null) over(partition by t1.dept_code order by t1.dt) is null
OR (
            COALESCE(t2.hps_d_jobcode, 'NULL_VALUE') != 
            COALESCE(LAG(t2.hps_d_jobcode, 1, NULL) OVER (PARTITION BY t1.dept_code ORDER BY t1.dt), 'NULL_VALUE')
          )
then 1
else 0
end as change_flag
,case when t1.manager_code != lag(t1.manager_code,1,null) over (partition by t1.dept_code order by t1.dt desc)
or lag(t1.manager_code,1,null) over(partition by t1.dept_code order by t1.dt desc) is null
OR (
            COALESCE(t2.hps_d_jobcode, 'NULL_VALUE') != 
            COALESCE(LAG(t2.hps_d_jobcode, 1, NULL) OVER (PARTITION BY t1.dept_code ORDER BY t1.dt DESC), 'NULL_VALUE')
          )
then 1
else 0
end as change_flag_desc
,t2.hps_d_jobcode
,t2.hps_dept_descr_lv5
,t2.hps_dept_descr_lv1
from data_build.pdw_opc_shop_ehr_staff_dept_view t1
left join data_build.pdw_psprod_ps_blf_ehr_pers_vw_view t2 on t1.manager_code = t2.emplid and t1.dt = t2.dt
where t1.dt > 20170101
and dept_code in ('100001051',
'123000238')
)

,grouped_data AS (
SELECT 
dt,
dept_code,
manager_code,
dept_name,
manager_name,
hps_d_jobcode,
hps_dept_descr_lv5,
hps_dept_descr_lv1,
-- 计算店长连续任职的分组ID
SUM(change_flag) OVER (PARTITION BY dept_code ORDER BY dt) AS manager_group_id,
SUM(change_flag_desc) OVER (PARTITION BY dept_code ORDER BY dt) AS manager_group_id_desc
FROM number_data
)

select * from
(
SELECT 
dt,
dept_code,
manager_code,
dept_name,
manager_name,
hps_d_jobcode,
hps_dept_descr_lv5,
hps_dept_descr_lv1,
-- 对每个店长连续任职的组内按日期排序编号
ROW_NUMBER() OVER (PARTITION BY dept_code, manager_group_id ORDER BY dt) AS manager_sequence,
ROW_NUMBER() OVER (PARTITION BY dept_code, manager_group_id_desc ORDER BY dt) AS manager_sequence_desc
FROM grouped_data
) a
where manager_sequence = '1' or manager_sequence_desc = '1'








with base_store_info as(
select distinct
t1.store_code
,t1.store_status_blf
from data_build.dwd_store_construction_project_status_v2_di t1
where t1.dt = '${today-2}'
and t1.store_status_blf in ('1正常保留-已开业门店')
)

,main_list as(
SELECT * 
from data_build.pdw_order_store_211_order_detail_flow_main
where dt = date_format(date_sub(current_date,1),'yyyyMMdd')
and flow_code = '031412' --流程code
)

,result_list as(
select
substr(t1.create_time,1,10) as compute_period
,t1.order_id
,t1.order_status
,t1.flow_ame
,regexp_extract(t1.flow_ame,'\\(([^)]+)\\)',1) AS staff_code
,t1.create_time
,t2.form_values
,get_json_object(t2.form_values,'$[0].label') as result
,row_number() over(partition by concat(substr(t1.create_time,1,10),regexp_extract(t1.flow_ame,'\\(([^)]+)\\)',1)) order by t1.create_time desc) as rn
from main_list t1
left join data_build.pdw_order_store_211_order_detail_flow_form_variable_groups_da t2
on t1.order_id = t2.order_id
and t2.dt = date_format(date_sub(current_date,1),'yyyyMMdd')
and t2.form_name = 'accept'
)

,result_list_1 as(
select
compute_period
,lpad(staff_code,8,10) as staff_code
,case when order_status = 'FINISHED' and result is null then '放弃' else result end as result
from result_list
where compute_period >= '2025-04-25'
)

,refuse_list as(
select
t1.staff_code
,sum(case when t1.result = '放弃' then 1 else 0 end) as refuse_num
from result_list_1 t1
left join(
select distinct
staff_code
from result_list_1
where result = '愿意接受'
) t2 on t1.staff_code = t2.staff_code
where t2.staff_code is null
group by
t1.staff_code
)

,staff_list as(
select
t1.*
,t2.hps_d_jobcode
,case when t3.manager_code is not null and (t2.hps_dept_descr_lv5 not like '%区X%' or t2.hps_dept_descr_lv1 not in ('运营管理部X'))
and t2.hps_d_jobcode not in ('外部合作辅助人','外部合作经营者','外部合作伙伴','内部合作辅助人','内部合作经营者','内部合作伙伴') then '店经理'
when t2.hps_d_jobcode = '店副经理' then '店副经理'
when t4.employee_id is not null and (t2.hps_dept_descr_lv5 like '%区X%' or t2.hps_dept_descr_lv1 in ('运营管理部X')) then '机动队带店店长'
when t5.employee_no is not null and (t2.hps_dept_descr_lv5 like '%区X%' or t2.hps_dept_descr_lv1 in ('运营管理部X'))  then t5.relation_type
when t2.hps_dept_descr_lv5 like '%区X%' or t2.hps_dept_descr_lv1 in ('运营管理部X') then '机动队队员'
when t2.hps_d_jobcode not in ('外部合作辅助人','外部合作经营者','外部合作伙伴','内部合作辅助人','内部合作经营者','内部合作伙伴') then '店员'
else t2.hps_d_jobcode end as post_name
,t6.business_district_id
,nvl(t7.refuse_num,0) as refuse_num
,t2.hps_dept_descr_lv1
,t2.hps_dept_descr_lv5
,case when t2.hps_dept_descr_lv1 in ('运营管理部X') then 1 else 0 end as is_district_new
from data_shop.dm_shop_staff_protect_tag_v2 t1
left join data_build.pdw_psprod_ps_blf_ehr_pers_vw_view t2 on t1.staff_code = lpad(t2.emplid,8,'10') and t2.dt = '${today-1}' --hps_d_jobcode in ('店副经理')
left join data_build.pdw_opc_shop_ehr_staff_dept_view t3 on t2.hps_dept_code_lv5 = t3.dept_code and lpad(t2.emplid,8,'10') = lpad(t3.manager_code,8,'10') and t3.dt = '${today-1}' --店长
left join data_build.dwd_store_construction_district_manager_base_info0_di t4 on t1.staff_code = t4.employee_id and t4.dt = '${today-2}'  --带店机动队(店经理)
left join (select
* from(
select 
employee_no,
shop_code,
relation_type,
dt,
row_number() over(partition by employee_no order by create_time desc) as rn
from data_smartorder.dm_copy_pdw_opc_roster_motor_shop_relation_view
where dt ='${today-1}'
and delete_ts = 0
and end_date >= '${TODAY}'
) a
where rn = 1
) t5 on t1.staff_code = lpad(t5.employee_no,8,'10') --带店机动队(店长/店副/陪跑店长/陪跑店副)
left join data_smartorder.ods_uploads_business_district_qiyang t6 on t1.store_code = t6.store_code
left join refuse_list t7 on t1.staff_code = t7.staff_code
where t1.dt = '${today-1}'
)

,district_num as(
select
store_name
,hps_dept_descr_lv5
,sum(is_district_new) as district_num
from staff_list
group by
store_name
,hps_dept_descr_lv5
)

,payable_price as(
select
t.store_code
,sum(t.payable_price)/count(distinct order_date) as payable_price --折后销售额
from data_build.dw_order_sku_v1 t
where t.dt = '${today-1}'
and t.store_type = '0'
and t.order_status = 'FINISHED'
and t.sku_class_code not in ('86','50')
and t.sku_quantity > 0
and order_date between '2025-05-01' and '2025-05-31'
group by
t.store_code
)

select
t1.store_code
,t2.dept_name
,t2.manager_code
,t2.manager_name
,t3.post_name
,t3.protect_tag_detail_new
,case when t4.store_code is not null then '加盟店' else '直营店' end as store_type
,t5.business_district_id
,case t5.business_district_id
when '1000'then '区X001北京' when '1001'then '区X002北京' when '1002'then '区X003北京' when '1232'then '区X004天津' when '1231'then '区X005天津'
when '1018'then '区X006上海' when '1101'then '区X007南京' when '1094'then '区X008杭州' when '1074'then '区X009济南' when '6120'then '区X010宁波'
when '1080'then '区X012青岛' when '10012'then '区X013北京' when '10013'then '区X014北京' when '10014'then '区X015北京' when '10015'then '区X016北京'
when '10016'then '区X017北京' when '1230'then '区X018天津' when '1019'then '区X019上海' when '1100'then '区X020南京' when '1070'then '区X021济南'
when '10018'then '区X024北京' when '1880'then '区X027廊坊' when '1030'then '区X028石家庄' when '1210'then '区X029郑州' when '3970'then '区X030常州'
when '6121'then '区X031宁波' when '1110'then '区X032苏州' when '1182'then '区X033无锡' when '2330'then '区X034金华' when '2320'then '区X035温州'
when '1003'then '区X036北京' when '1004'then '区X037北京' when '1005'then '区X038北京' when '1006'then '区X039北京' when '1007'then '区X040北京'
when '1008'then '区X041北京' when '1009'then '区X042北京' when '10010'then '区X043北京' when '10011'then '区X044北京' when '10017'then '区X045北京'
when '1233'then '区X046天津' when '1234'then '区X047天津' when '1235'then '区X048天津' when '1236'then '区X049天津' when '1237'then '区X050天津'
when '1238'then '区X051天津' when '1239'then '区X052天津' when '3971'then '区X053常州' when '1093'then '区X054杭州' when '1092'then '区X055杭州'
when '1091'then '区X056杭州' when '1090'then '区X057杭州' when '1071'then '区X058济南' when '1072'then '区X059济南' when '1073'then '区X060济南'
when '1102'then '区X061南京' when '1103'then '区X062南京' when '1104'then '区X063南京' when '1105'then '区X064南京' when '1106'then '区X065南京'
when '1107'then '区X066南京' when '1211'then '区X067郑州' when '1181'then '区X068无锡' when '1180'then '区X069无锡' when '1113'then '区X070苏州'
when '1112'then '区X071苏州' when '1081'then '区X072青岛' when '1082'then '区X073青岛' when '6123'then '区X074宁波' when '6122'then '区X075宁波'
when '1011'then '区X076上海' when '1012'then '区X077上海' when '1013'then '区X078上海' when '1014'then '区X079上海' when '1015'then '区X080上海'
when '1016'then '区X081上海' when '1017'then '区X082上海' when '1018'then '区X083上海' else null end as business_district
,t6.gap_store_new
,t7.good_staff_num
,t7.normal_staff_mun
,t7.refuse_staff_mun
,t8.district_num --机动队人数
,t6.gap_all_district
,t6.reward_level_district
,t6.lack_rate
,t9.gap_new
,t10.payable_price
from base_store_info t1
left join data_build.pdw_opc_shop_ehr_staff_dept_view t2 on t1.store_code = t2.dept_code and t2.dt = '${today-1}'
left join staff_list t3 on t2.manager_code = t3.emplid
left join (
select distinct 
store_code
from data_build.pdw_bach_baseinfo_shop_shop
where dt = '${today-1}'
and self_take_type = '4' --加盟店
) t4 on t1.store_code = t4.store_code
left join data_smartorder.ods_uploads_business_district_qiyang t5 on t1.store_code = t5.store_code
left join(
    SELECT
district_code
,gap_all_district
,reward_level_district
,sum(gap_all_district)/sum(hc_all_district) as lack_rate
,sum(gap_new) as gap_store_new
from data_build.dwd_store_construction_store_groups_recruit_gap
where dt = '${today-1}'
GROUP BY
district_code
,gap_all_district
,reward_level_district
) t6 on t5.business_district_id = t6.district_code
left join(
    select
store_code
,sum(case when post_name = '店员' and protect_tag_detail = '1' then 1 else 0 end) as good_staff_num
,sum(case when post_name = '店员' and protect_tag_detail = '2' then 1 else 0 end) as normal_staff_mun
,sum(case when post_name = '店员' and (protect_tag_detail = '1' or protect_tag_detail = '2') and refuse_num > 2 then 1 else 0 end) as refuse_staff_mun
from staff_list
group by
store_code
) t7 on t1.store_code = t7.store_code
left join district_num t8 on t5.business_district_id = t8.store_name
left join data_build.dwd_store_construction_store_groups_recruit_gap t9 on t1.store_code = t9.store_code and t9.dt = '${today-1}'
left join payable_price t10 on t1.store_code = t10.store_code


*********************************************************************************************************************************************************************************

*********************************************************************************************************************************************************************************

*********************************************************************************************************************************************************************************
--1.统计下周班表的门店hc，看3个人及以上HC门店，第三个人是不是半天班，如果是半天班就没办法被压缩了，如果是全天班就认为可以压缩
--2.店长默认6*11.5小时，店副默认5*11.5小时，然后统计除店长店副外的剩余运营工时，小于150就是没意义了...........







with weekday_info as (  
    select  
        t1.date_key
		,date_format(t1.date_key,'yyyyMMdd') as dt_key
        ,date_sub(next_day(t1.date_key,'mon'),7) as date_week
    from data_build.dim_date_ya_v2 t1
    where t1.calendar_year in ('2025','2024')
)

select 
    t1.code
    ,if(length(t1.code)<8,concat('10',t1.code),t1.code) as staff_code
    ,t1.position_name
    ,case 
        when t1.position_name = '学生PT' then '学生PT'
        when t1.position_name = '店经理' then '店经理'
        when t1.position_name = '社会PT' then '店员'
        when t1.position_name in ('门店伙伴','店员','见习店经理') then 
            if(round(datediff(date_format(t2.create_time,'yyyy-MM-dd'),t3.resume_birth_date)/365,0) <= 22,'疑似学生PT','店员')
    end as position_tag
    ,date_format(t2.create_time,'yyyy-MM-dd') as entry_date
    ,date_format(t2.create_time,'yyyyMMdd') as entry_dt
    ,case 
        when final_work_class_tag like '%全天%' then if(final_work_class = 'day','白','夜')
        when final_work_class_tag like '%白%' then '白'
        when final_work_class_tag like '%夜%' then '夜'
    else 'NA' end as final_work_class_tag
    ,t1.plan_shop_code
    ,final_work_class
    ,if(length(t4.leave_dt)>2,'离职','在职') as job_status
    ,date_format(t4.leave_dt,'yyyy-MM-dd') as leave_date
    ,if(length(t4.leave_dt)<2 or t4.leave_dt is null
        ,datediff('${TODAY-1}',date_format(t2.create_time,'yyyy-MM-dd'))
        ,datediff(date_format(t4.leave_dt,'yyyy-MM-dd'),date_format(t2.create_time,'yyyy-MM-dd'))) as diff_days
    ,t0.date_week
from data_shop.pdw_gis_workday_entry_staff_position_view t1
left join data_shop.mid_gis_workday_entry_status_change_view t2
on t1.entry_id = t2.entry_id and t2.entry_state = 1
    and t2.dt = '${today-1}'
left join data_shop.dw_gis_hire_recruit_detail_v1_di_view t3
on t1.entry_id = t3.order_third_entry_id and t3.dt = '${today-1}'
-- left join data_sec_dw.pdw_psprod_ps_blf_ehr_pers_vw_view t0
-- on t1.code = t0.emplid and t0.dt = '${today-1}'
-- left join data_shop.dw_gis_hire_recruit_detail_v1_di_view t3
-- on t0.hps_sys_name = t3.entry_user_id and t3.dt = '${today-1}'
left join data_sec_dw.pdw_psprod_ps_blf_ehr_pers_vw_view t4
on t1.code = t4.emplid and t4.dt = '${today-1}'
left join weekday_info t0
on date_format(t2.create_time,'yyyy-MM-dd') = t0.date_key
where t1.dt = '${today-1}'
    and t1.position_name in ('店经理', '门店伙伴', '店员', '社会PT', '学生PT', '见习店经理')
    and t1.code is not null
    and date_format(t2.create_time,'yyyyMMdd') >= '20230501'


--原：
--7天在职
case when datediff('${TODAY-1}',entry_date)>=7 then (case when (diff_days >= 7 and job_status = '在职') or (diff_days > 7 and job_status = '离职') then 1 else 0 end) end
--7天留存率
(case when datediff('${TODAY-1}',entry_date)>=7 then sum(case when (diff_days >= 7 and job_status = '在职') or (diff_days > 7 and job_status = '离职') then 1 else 0 end) end)/count(1)

--14天在职
case when datediff('${TODAY-1}',entry_date)>=14 then (case when (diff_days >= 14 and job_status = '在职') or (diff_days > 14 and job_status = '离职') then 1 else 0 end) end
--14天留存率
(case when datediff('${TODAY-1}',entry_date)>=14 then sum(case when (diff_days >= 14 and job_status = '在职') or (diff_days > 14 and job_status = '离职') then 1 else 0 end) end)/count(1)

--21天在职
case when datediff('${TODAY-1}',entry_date)>=21 then (case when (diff_days >= 21 and job_status = '在职') or (diff_days > 21 and job_status = '离职') then 1 else 0 end) end
--21天留存率
(case when datediff('${TODAY-1}',entry_date)>=21 then sum(case when (diff_days >= 21 and job_status = '在职') or (diff_days > 21 and job_status = '离职') then 1 else 0 end) end)/count(1)	

--28天在职
case when datediff('${TODAY-1}',entry_date)>=28 then (case when (diff_days >= 28 and job_status = '在职') or (diff_days > 28 and job_status = '离职') then 1 else 0 end) end	
--28天留存率
(case when datediff('${TODAY-1}',entry_date)>=28 then sum(case when (diff_days >= 28 and job_status = '在职') or (diff_days > 28 and job_status = '离职') then 1 else 0 end) end)/count(1)




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
,t7.hps_hire_date --真是入职日期
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
and t4.dt = date_format(date_sub(to_date(from_unixtime(unix_timestamp(t1.dt,'yyyyMMdd'))),1),'yyyyMMdd')  --带店机动队(店经理)
and t4.dt > '${today-1}'
left join (select
* from(
select 
employee_no,
shop_code,
relation_type,
dt,
row_number() over(partition by employee_no order by create_time desc) as rn
from data_smartorder.dm_copy_pdw_opc_roster_motor_shop_relation_view
where dt > '${today}'
and delete_ts = 0
and end_date >= to_date(from_unixtime(unix_timestamp(dt,'yyyyMMdd')))
) a
where rn = 1
) t5 on t1.staff_code = lpad(t5.employee_no,8,'10') --带店机动队(店长/店副/陪跑店长/陪跑店副)
and t1.dt = t5.dt
left join data_smartorder.ods_uploads_business_district_qiyang t6 on t1.store_code = t6.store_code
left join raw_list t7 on t1.staff_code = lpad(t7.employee_id,8,'10') and t1.dt = t7.dt
where t1.dt > '${today}'
)

select
lpad(t1.employee_no,8,'10') as staff_code
,t1.employee_name
,t1.work_shift_date
,t1.store_code --出勤门店
,t1.store_name
,nvl(t8.staff_num,0) as staff_num --架构下人数
,nvl(t8.student_num,0) as student_num --学生人数
,nvl(t8.student_suspect_num,0) as student_suspect_num --疑似学生人数
,case t4.business_district_id
when '1000'then '区X001北京' when '1001'then '区X002北京' when '1002'then '区X003北京' when '1232'then '区X004天津' when '1231'then '区X005天津'
when '1018'then '区X006上海' when '1101'then '区X007南京' when '1094'then '区X008杭州' when '1074'then '区X009济南' when '6120'then '区X010宁波'
when '1080'then '区X012青岛' when '10012'then '区X013北京' when '10013'then '区X014北京' when '10014'then '区X015北京' when '10015'then '区X016北京'
when '10016'then '区X017北京' when '1230'then '区X018天津' when '1019'then '区X019上海' when '1100'then '区X020南京' when '1070'then '区X021济南'
when '10018'then '区X024北京' when '1880'then '区X027廊坊' when '1030'then '区X028石家庄' when '1210'then '区X029郑州' when '3970'then '区X030常州'
when '6121'then '区X031宁波' when '1110'then '区X032苏州' when '1182'then '区X033无锡' when '2330'then '区X034金华' when '2320'then '区X035温州'
when '1003'then '区X036北京' when '1004'then '区X037北京' when '1005'then '区X038北京' when '1006'then '区X039北京' when '1007'then '区X040北京'
when '1008'then '区X041北京' when '1009'then '区X042北京' when '10010'then '区X043北京' when '10011'then '区X044北京' when '10017'then '区X045北京'
when '1233'then '区X046天津' when '1234'then '区X047天津' when '1235'then '区X048天津' when '1236'then '区X049天津' when '1237'then '区X050天津'
when '1238'then '区X051天津' when '1239'then '区X052天津' when '3971'then '区X053常州' when '1093'then '区X054杭州' when '1092'then '区X055杭州'
when '1091'then '区X056杭州' when '1090'then '区X057杭州' when '1071'then '区X058济南' when '1072'then '区X059济南' when '1073'then '区X060济南'
when '1102'then '区X061南京' when '1103'then '区X062南京' when '1104'then '区X063南京' when '1105'then '区X064南京' when '1106'then '区X065南京'
when '1107'then '区X066南京' when '1211'then '区X067郑州' when '1181'then '区X068无锡' when '1180'then '区X069无锡' when '1113'then '区X070苏州'
when '1112'then '区X071苏州' when '1081'then '区X072青岛' when '1082'then '区X073青岛' when '6123'then '区X074宁波' when '6122'then '区X075宁波'
when '1011'then '区X076上海' when '1012'then '区X077上海' when '1013'then '区X078上海' when '1014'then '区X079上海' when '1015'then '区X080上海'
when '1016'then '区X081上海' when '1017'then '区X082上海' when '1018'then '区X083上海' else t1.store_name end as store_business_district
,case when t3.store_code is not null then '加盟店' else '直营店' end as store_type
,COALESCE(t2.store_code,t7.store_code) as t2_store_code --原架构
,COALESCE(t2.store_name,t7.store_name) as t2_store_name
,case when t5.business_district_id is null then COALESCE(t2.hps_dept_descr_lv5,t7.hps_dept_descr_lv5) else 
case t5.business_district_id
when '1000'then '区X001北京' when '1001'then '区X002北京' when '1002'then '区X003北京' when '1232'then '区X004天津' when '1231'then '区X005天津'
when '1018'then '区X006上海' when '1101'then '区X007南京' when '1094'then '区X008杭州' when '1074'then '区X009济南' when '6120'then '区X010宁波'
when '1080'then '区X012青岛' when '10012'then '区X013北京' when '10013'then '区X014北京' when '10014'then '区X015北京' when '10015'then '区X016北京'
when '10016'then '区X017北京' when '1230'then '区X018天津' when '1019'then '区X019上海' when '1100'then '区X020南京' when '1070'then '区X021济南'
when '10018'then '区X024北京' when '1880'then '区X027廊坊' when '1030'then '区X028石家庄' when '1210'then '区X029郑州' when '3970'then '区X030常州'
when '6121'then '区X031宁波' when '1110'then '区X032苏州' when '1182'then '区X033无锡' when '2330'then '区X034金华' when '2320'then '区X035温州'
when '1003'then '区X036北京' when '1004'then '区X037北京' when '1005'then '区X038北京' when '1006'then '区X039北京' when '1007'then '区X040北京'
when '1008'then '区X041北京' when '1009'then '区X042北京' when '10010'then '区X043北京' when '10011'then '区X044北京' when '10017'then '区X045北京'
when '1233'then '区X046天津' when '1234'then '区X047天津' when '1235'then '区X048天津' when '1236'then '区X049天津' when '1237'then '区X050天津'
when '1238'then '区X051天津' when '1239'then '区X052天津' when '3971'then '区X053常州' when '1093'then '区X054杭州' when '1092'then '区X055杭州'
when '1091'then '区X056杭州' when '1090'then '区X057杭州' when '1071'then '区X058济南' when '1072'then '区X059济南' when '1073'then '区X060济南'
when '1102'then '区X061南京' when '1103'then '区X062南京' when '1104'then '区X063南京' when '1105'then '区X064南京' when '1106'then '区X065南京'
when '1107'then '区X066南京' when '1211'then '区X067郑州' when '1181'then '区X068无锡' when '1180'then '区X069无锡' when '1113'then '区X070苏州'
when '1112'then '区X071苏州' when '1081'then '区X072青岛' when '1082'then '区X073青岛' when '6123'then '区X074宁波' when '6122'then '区X075宁波'
when '1011'then '区X076上海' when '1012'then '区X077上海' when '1013'then '区X078上海' when '1014'then '区X079上海' when '1015'then '区X080上海'
when '1016'then '区X081上海' when '1017'then '区X082上海' when '1018'then '区X083上海' else t2.store_name end
end as staff_business_district
,COALESCE(t2.hps_d_jobcode,t7.hps_d_jobcode) as hps_d_jobcode
,COALESCE(t2.post_name,t7.post_name) as post_name
,COALESCE(t2.student_suspect_new,t7.student_suspect_new) as student_suspect_new
,case when t1.store_code = COALESCE(t2.store_code,t7.store_code) then '本店' else '非本店' end as is_base_stroe
,sum(t1.attendance_work_hours) as attendance_work_hours --出勤工时
from data_build.pdw_opc_shop_attendance_report_work_shift_view t1

left join staff_list t2 on lpad(t1.employee_no,8,'10') = t2.staff_code and t1.work_shift_date = to_date(from_unixtime(unix_timestamp(t2.dt,'yyyyMMdd')))

left join staff_list t7 on lpad(t1.employee_no,8,'10') = t7.staff_code and t1.work_shift_date = date_add(to_date(from_unixtime(unix_timestamp(t7.dt,'yyyyMMdd'))),1)

left join (
select distinct 
store_code
from data_build.pdw_bach_baseinfo_shop_shop
where dt = date_format(date_sub(current_date,1),'yyyyMMdd')
and self_take_type = '4' --加盟店
) t3 on t1.store_code = t3.store_code

left join data_smartorder.ods_uploads_business_district_qiyang t4 on t1.store_code = t4.store_code --门店区域

left join data_smartorder.ods_uploads_business_district_qiyang t5 on COALESCE(t2.hps_dept_code_lv5,t7.hps_dept_code_lv5) = t5.store_code --员工区域

left join data_build.dim_store_info t6 on t1.store_code = t6.store_code and t6.dt = date_format(date_sub(current_date,1),'yyyyMMdd')

left join(
select
record_dt
,store_code
,count(staff_code) as staff_num --门店架构下人数
,count(case when hps_d_jobcode in ('学生PT') and to_date(hps_hire_date) >= '2025-05-01' then staff_code else null end) as student_num --学生人数
,count(case when post_name in ('店员') and student_suspect = '1' and to_date(hps_hire_date) >= '2025-05-01' then staff_code else null end) as student_suspect_num --疑似学生人数
from staff_list
group by
record_dt
,store_code
) t8 on t1.work_shift_date = to_date(from_unixtime(unix_timestamp(t8.record_dt,'yyyyMMdd'))) and t1.store_code = t8.store_code

where t1.dt = date_format(date_sub(current_date,1),'yyyyMMdd')
and work_shift_date > '${TODAY+1}'
and work_shift_type in (1) --普通
and attendance_work_hours > 0
and t6.store_type = '0'

group by
lpad(t1.employee_no,8,'10')
,t1.employee_name
,t1.work_shift_date
,t1.store_code --出勤门店
,t1.store_name
,nvl(t8.staff_num,0)
,nvl(t8.student_num,0)
,nvl(t8.student_suspect_num,0)
,case t4.business_district_id
when '1000'then '区X001北京' when '1001'then '区X002北京' when '1002'then '区X003北京' when '1232'then '区X004天津' when '1231'then '区X005天津'
when '1018'then '区X006上海' when '1101'then '区X007南京' when '1094'then '区X008杭州' when '1074'then '区X009济南' when '6120'then '区X010宁波'
when '1080'then '区X012青岛' when '10012'then '区X013北京' when '10013'then '区X014北京' when '10014'then '区X015北京' when '10015'then '区X016北京'
when '10016'then '区X017北京' when '1230'then '区X018天津' when '1019'then '区X019上海' when '1100'then '区X020南京' when '1070'then '区X021济南'
when '10018'then '区X024北京' when '1880'then '区X027廊坊' when '1030'then '区X028石家庄' when '1210'then '区X029郑州' when '3970'then '区X030常州'
when '6121'then '区X031宁波' when '1110'then '区X032苏州' when '1182'then '区X033无锡' when '2330'then '区X034金华' when '2320'then '区X035温州'
when '1003'then '区X036北京' when '1004'then '区X037北京' when '1005'then '区X038北京' when '1006'then '区X039北京' when '1007'then '区X040北京'
when '1008'then '区X041北京' when '1009'then '区X042北京' when '10010'then '区X043北京' when '10011'then '区X044北京' when '10017'then '区X045北京'
when '1233'then '区X046天津' when '1234'then '区X047天津' when '1235'then '区X048天津' when '1236'then '区X049天津' when '1237'then '区X050天津'
when '1238'then '区X051天津' when '1239'then '区X052天津' when '3971'then '区X053常州' when '1093'then '区X054杭州' when '1092'then '区X055杭州'
when '1091'then '区X056杭州' when '1090'then '区X057杭州' when '1071'then '区X058济南' when '1072'then '区X059济南' when '1073'then '区X060济南'
when '1102'then '区X061南京' when '1103'then '区X062南京' when '1104'then '区X063南京' when '1105'then '区X064南京' when '1106'then '区X065南京'
when '1107'then '区X066南京' when '1211'then '区X067郑州' when '1181'then '区X068无锡' when '1180'then '区X069无锡' when '1113'then '区X070苏州'
when '1112'then '区X071苏州' when '1081'then '区X072青岛' when '1082'then '区X073青岛' when '6123'then '区X074宁波' when '6122'then '区X075宁波'
when '1011'then '区X076上海' when '1012'then '区X077上海' when '1013'then '区X078上海' when '1014'then '区X079上海' when '1015'then '区X080上海'
when '1016'then '区X081上海' when '1017'then '区X082上海' when '1018'then '区X083上海' else t1.store_name end
,case when t3.store_code is not null then '加盟店' else '直营店' end
,COALESCE(t2.store_code,t7.store_code)
,COALESCE(t2.store_name,t7.store_name)
,case when t5.business_district_id is null then COALESCE(t2.hps_dept_descr_lv5,t7.hps_dept_descr_lv5) else 
case t5.business_district_id
when '1000'then '区X001北京' when '1001'then '区X002北京' when '1002'then '区X003北京' when '1232'then '区X004天津' when '1231'then '区X005天津'
when '1018'then '区X006上海' when '1101'then '区X007南京' when '1094'then '区X008杭州' when '1074'then '区X009济南' when '6120'then '区X010宁波'
when '1080'then '区X012青岛' when '10012'then '区X013北京' when '10013'then '区X014北京' when '10014'then '区X015北京' when '10015'then '区X016北京'
when '10016'then '区X017北京' when '1230'then '区X018天津' when '1019'then '区X019上海' when '1100'then '区X020南京' when '1070'then '区X021济南'
when '10018'then '区X024北京' when '1880'then '区X027廊坊' when '1030'then '区X028石家庄' when '1210'then '区X029郑州' when '3970'then '区X030常州'
when '6121'then '区X031宁波' when '1110'then '区X032苏州' when '1182'then '区X033无锡' when '2330'then '区X034金华' when '2320'then '区X035温州'
when '1003'then '区X036北京' when '1004'then '区X037北京' when '1005'then '区X038北京' when '1006'then '区X039北京' when '1007'then '区X040北京'
when '1008'then '区X041北京' when '1009'then '区X042北京' when '10010'then '区X043北京' when '10011'then '区X044北京' when '10017'then '区X045北京'
when '1233'then '区X046天津' when '1234'then '区X047天津' when '1235'then '区X048天津' when '1236'then '区X049天津' when '1237'then '区X050天津'
when '1238'then '区X051天津' when '1239'then '区X052天津' when '3971'then '区X053常州' when '1093'then '区X054杭州' when '1092'then '区X055杭州'
when '1091'then '区X056杭州' when '1090'then '区X057杭州' when '1071'then '区X058济南' when '1072'then '区X059济南' when '1073'then '区X060济南'
when '1102'then '区X061南京' when '1103'then '区X062南京' when '1104'then '区X063南京' when '1105'then '区X064南京' when '1106'then '区X065南京'
when '1107'then '区X066南京' when '1211'then '区X067郑州' when '1181'then '区X068无锡' when '1180'then '区X069无锡' when '1113'then '区X070苏州'
when '1112'then '区X071苏州' when '1081'then '区X072青岛' when '1082'then '区X073青岛' when '6123'then '区X074宁波' when '6122'then '区X075宁波'
when '1011'then '区X076上海' when '1012'then '区X077上海' when '1013'then '区X078上海' when '1014'then '区X079上海' when '1015'then '区X080上海'
when '1016'then '区X081上海' when '1017'then '区X082上海' when '1018'then '区X083上海' else t2.store_name end
end
,COALESCE(t2.hps_d_jobcode,t7.hps_d_jobcode)
,COALESCE(t2.post_name,t7.post_name)
,COALESCE(t2.student_suspect_new,t7.student_suspect_new)
,case when t1.store_code = COALESCE(t2.store_code,t7.store_code) then '本店' else '非本店' end



















--下周学生PT工时占比
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
case when dayofweek(from_unixtime(unix_timestamp(t1.dt, 'yyyyMMdd'), 'yyyy-MM-dd')) in ('2','3') --周一周二
then date_sub(next_day(current_date,'mon'),7) --本周一
else next_day(current_date,'mon') end --下周一
as week_date
,t1.store_id
,case when t3.store_code is not null then '加盟店' else '直营店' end as store_type
,t1.employee_id
,t2.staff_name
,t2.student_suspect_new
,t2.hps_d_jobcode
,t2.post_name
,sum(t1.work_hours) as work_hours
from data_build.dw_roster_effect_roster_detail_info_da_view t1
left join staff_list t2 on t1.employee_id = t2.staff_code
left join (
select distinct 
store_code
from data_build.pdw_bach_baseinfo_shop_shop
where dt = date_format(date_sub(current_date,1),'yyyyMMdd')
and self_take_type = '4' --加盟店
) t3 on t1.store_id = t3.store_code

left join data_smartorder.ods_uploads_business_district_qiyang t4 on t1.store_code = t4.store_code --门店区域

where t1.dt = '${today}'
and
case when dayofweek(from_unixtime(unix_timestamp(t1.dt, 'yyyyMMdd'), 'yyyy-MM-dd')) in ('2','3') --周一周二
then t1.work_date between date_sub(next_day(current_date,'mon'),7) and date_sub(next_day(current_date,'mon'),1) --本周
else t1.work_date between next_day(current_date,'mon') and date_add(next_day(current_date,'mon'),6) --下周
end
and (t1.class_id in ('0') or t1.attr_id = '344')
and t1.store_type_desc = '门店'
and t1.store_type = '0'
group by
case when dayofweek(from_unixtime(unix_timestamp(t1.dt, 'yyyyMMdd'), 'yyyy-MM-dd')) in ('2','3') --周一周二
then date_sub(next_day(current_date,'mon'),7) --本周一
else next_day(current_date,'mon') end --下周一
,t1.store_id
,case when t3.store_code is not null then '加盟店' else '直营店' end
,t1.employee_id
,t2.staff_name
,t2.student_suspect_new
,t2.hps_d_jobcode
,t2.post_name

--根据出勤统计学生工时占比
with staff_list as(
select
t1.dt as record_dt
,t1.*
,hps_d_jobcode
,t2.hps_sys_name
,t2.hps_dept_code_lv5
,t2.hps_dept_descr_lv5
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
and t4.dt = 20250725
left join (select
* from(
select 
employee_no,
shop_code,
relation_type,
dt,
row_number() over(partition by employee_no order by create_time desc) as rn
from data_smartorder.dm_copy_pdw_opc_roster_motor_shop_relation_view
where dt = '20250725'
and delete_ts = 0
and end_date >= to_date(from_unixtime(unix_timestamp(dt,'yyyyMMdd')))
) a
where rn = 1
) t5 on t1.staff_code = lpad(t5.employee_no,8,'10') --带店机动队(店长/店副/陪跑店长/陪跑店副)
and t1.dt = t5.dt
left join data_smartorder.ods_uploads_business_district_qiyang t6 on t1.store_code = t6.store_code
where t1.dt = '20250725'
)

select
lpad(t1.employee_no,8,'10') as staff_code
,t1.employee_name
,t1.work_shift_date
,t1.store_code --出勤门店
,t1.store_name
,nvl(t8.staff_num,0) as staff_num --架构下人数
,nvl(t8.student_num,0) as student_num --学生人数
,nvl(t8.student_suspect_num,0) as student_suspect_num --疑似学生人数
,case t4.business_district_id
when '1000'then '区X001北京' when '1001'then '区X002北京' when '1002'then '区X003北京' when '1232'then '区X004天津' when '1231'then '区X005天津'
when '1018'then '区X006上海' when '1101'then '区X007南京' when '1094'then '区X008杭州' when '1074'then '区X009济南' when '6120'then '区X010宁波'
when '1080'then '区X012青岛' when '10012'then '区X013北京' when '10013'then '区X014北京' when '10014'then '区X015北京' when '10015'then '区X016北京'
when '10016'then '区X017北京' when '1230'then '区X018天津' when '1019'then '区X019上海' when '1100'then '区X020南京' when '1070'then '区X021济南'
when '10018'then '区X024北京' when '1880'then '区X027廊坊' when '1030'then '区X028石家庄' when '1210'then '区X029郑州' when '3970'then '区X030常州'
when '6121'then '区X031宁波' when '1110'then '区X032苏州' when '1182'then '区X033无锡' when '2330'then '区X034金华' when '2320'then '区X035温州'
when '1003'then '区X036北京' when '1004'then '区X037北京' when '1005'then '区X038北京' when '1006'then '区X039北京' when '1007'then '区X040北京'
when '1008'then '区X041北京' when '1009'then '区X042北京' when '10010'then '区X043北京' when '10011'then '区X044北京' when '10017'then '区X045北京'
when '1233'then '区X046天津' when '1234'then '区X047天津' when '1235'then '区X048天津' when '1236'then '区X049天津' when '1237'then '区X050天津'
when '1238'then '区X051天津' when '1239'then '区X052天津' when '3971'then '区X053常州' when '1093'then '区X054杭州' when '1092'then '区X055杭州'
when '1091'then '区X056杭州' when '1090'then '区X057杭州' when '1071'then '区X058济南' when '1072'then '区X059济南' when '1073'then '区X060济南'
when '1102'then '区X061南京' when '1103'then '区X062南京' when '1104'then '区X063南京' when '1105'then '区X064南京' when '1106'then '区X065南京'
when '1107'then '区X066南京' when '1211'then '区X067郑州' when '1181'then '区X068无锡' when '1180'then '区X069无锡' when '1113'then '区X070苏州'
when '1112'then '区X071苏州' when '1081'then '区X072青岛' when '1082'then '区X073青岛' when '6123'then '区X074宁波' when '6122'then '区X075宁波'
when '1011'then '区X076上海' when '1012'then '区X077上海' when '1013'then '区X078上海' when '1014'then '区X079上海' when '1015'then '区X080上海'
when '1016'then '区X081上海' when '1017'then '区X082上海' when '1018'then '区X083上海' else t1.store_name end as store_business_district
,case when t3.store_code is not null then '加盟店' else '直营店' end as store_type
,COALESCE(t2.store_code,t7.store_code) as t2_store_code --原架构
,COALESCE(t2.store_name,t7.store_name) as t2_store_name
,case when t5.business_district_id is null then COALESCE(t2.hps_dept_descr_lv5,t7.hps_dept_descr_lv5) else 
case t5.business_district_id
when '1000'then '区X001北京' when '1001'then '区X002北京' when '1002'then '区X003北京' when '1232'then '区X004天津' when '1231'then '区X005天津'
when '1018'then '区X006上海' when '1101'then '区X007南京' when '1094'then '区X008杭州' when '1074'then '区X009济南' when '6120'then '区X010宁波'
when '1080'then '区X012青岛' when '10012'then '区X013北京' when '10013'then '区X014北京' when '10014'then '区X015北京' when '10015'then '区X016北京'
when '10016'then '区X017北京' when '1230'then '区X018天津' when '1019'then '区X019上海' when '1100'then '区X020南京' when '1070'then '区X021济南'
when '10018'then '区X024北京' when '1880'then '区X027廊坊' when '1030'then '区X028石家庄' when '1210'then '区X029郑州' when '3970'then '区X030常州'
when '6121'then '区X031宁波' when '1110'then '区X032苏州' when '1182'then '区X033无锡' when '2330'then '区X034金华' when '2320'then '区X035温州'
when '1003'then '区X036北京' when '1004'then '区X037北京' when '1005'then '区X038北京' when '1006'then '区X039北京' when '1007'then '区X040北京'
when '1008'then '区X041北京' when '1009'then '区X042北京' when '10010'then '区X043北京' when '10011'then '区X044北京' when '10017'then '区X045北京'
when '1233'then '区X046天津' when '1234'then '区X047天津' when '1235'then '区X048天津' when '1236'then '区X049天津' when '1237'then '区X050天津'
when '1238'then '区X051天津' when '1239'then '区X052天津' when '3971'then '区X053常州' when '1093'then '区X054杭州' when '1092'then '区X055杭州'
when '1091'then '区X056杭州' when '1090'then '区X057杭州' when '1071'then '区X058济南' when '1072'then '区X059济南' when '1073'then '区X060济南'
when '1102'then '区X061南京' when '1103'then '区X062南京' when '1104'then '区X063南京' when '1105'then '区X064南京' when '1106'then '区X065南京'
when '1107'then '区X066南京' when '1211'then '区X067郑州' when '1181'then '区X068无锡' when '1180'then '区X069无锡' when '1113'then '区X070苏州'
when '1112'then '区X071苏州' when '1081'then '区X072青岛' when '1082'then '区X073青岛' when '6123'then '区X074宁波' when '6122'then '区X075宁波'
when '1011'then '区X076上海' when '1012'then '区X077上海' when '1013'then '区X078上海' when '1014'then '区X079上海' when '1015'then '区X080上海'
when '1016'then '区X081上海' when '1017'then '区X082上海' when '1018'then '区X083上海' else t2.store_name end
end as staff_business_district
,COALESCE(t2.hps_d_jobcode,t7.hps_d_jobcode) as hps_d_jobcode
,COALESCE(t2.post_name,t7.post_name) as post_name
,COALESCE(t2.student_suspect,t7.student_suspect) as student_suspect
,case when t1.store_code = COALESCE(t2.store_code,t7.store_code) then '本店' else '非本店' end as is_base_stroe
,sum(t1.attendance_work_hours) as attendance_work_hours --出勤工时
from data_build.pdw_opc_shop_attendance_report_work_shift_view t1

left join staff_list t2 on lpad(t1.employee_no,8,'10') = t2.staff_code and t1.work_shift_date = to_date(from_unixtime(unix_timestamp(t2.dt,'yyyyMMdd')))

left join staff_list t7 on lpad(t1.employee_no,8,'10') = t7.staff_code and t1.work_shift_date = date_add(to_date(from_unixtime(unix_timestamp(t7.dt,'yyyyMMdd'))),1)

left join (
select distinct 
store_code
from data_build.pdw_bach_baseinfo_shop_shop
where dt = date_format(date_sub(current_date,1),'yyyyMMdd')
and self_take_type = '4' --加盟店
) t3 on t1.store_code = t3.store_code

left join data_smartorder.ods_uploads_business_district_qiyang t4 on t1.store_code = t4.store_code --门店区域

left join data_smartorder.ods_uploads_business_district_qiyang t5 on COALESCE(t2.hps_dept_code_lv5,t7.hps_dept_code_lv5) = t5.store_code --员工区域

left join data_build.dim_store_info t6 on t1.store_code = t6.store_code and t6.dt = date_format(date_sub(current_date,1),'yyyyMMdd')

left join(
select
record_dt
,store_code
,count(staff_code) as staff_num --门店架构下人数
,count(case when hps_d_jobcode in ('学生PT') then staff_code else null end) as student_num --学生人数
,count(case when post_name in ('店员') and student_suspect = '1' then staff_code else null end) as student_suspect_num --疑似学生人数
from staff_list
group by
record_dt
,store_code
) t8 on t1.work_shift_date = to_date(from_unixtime(unix_timestamp(t8.record_dt,'yyyyMMdd'))) and t1.store_code = t8.store_code

where t1.dt = date_format(date_sub(current_date,1),'yyyyMMdd')
and work_shift_date = '2025-07-25'
and work_shift_type in (1) --普通
and attendance_work_hours > 0
and t6.store_type = '0'

group by
lpad(t1.employee_no,8,'10')
,t1.employee_name
,t1.work_shift_date
,t1.store_code --出勤门店
,t1.store_name
,nvl(t8.staff_num,0)
,nvl(t8.student_num,0)
,nvl(t8.student_suspect_num,0)
,case t4.business_district_id
when '1000'then '区X001北京' when '1001'then '区X002北京' when '1002'then '区X003北京' when '1232'then '区X004天津' when '1231'then '区X005天津'
when '1018'then '区X006上海' when '1101'then '区X007南京' when '1094'then '区X008杭州' when '1074'then '区X009济南' when '6120'then '区X010宁波'
when '1080'then '区X012青岛' when '10012'then '区X013北京' when '10013'then '区X014北京' when '10014'then '区X015北京' when '10015'then '区X016北京'
when '10016'then '区X017北京' when '1230'then '区X018天津' when '1019'then '区X019上海' when '1100'then '区X020南京' when '1070'then '区X021济南'
when '10018'then '区X024北京' when '1880'then '区X027廊坊' when '1030'then '区X028石家庄' when '1210'then '区X029郑州' when '3970'then '区X030常州'
when '6121'then '区X031宁波' when '1110'then '区X032苏州' when '1182'then '区X033无锡' when '2330'then '区X034金华' when '2320'then '区X035温州'
when '1003'then '区X036北京' when '1004'then '区X037北京' when '1005'then '区X038北京' when '1006'then '区X039北京' when '1007'then '区X040北京'
when '1008'then '区X041北京' when '1009'then '区X042北京' when '10010'then '区X043北京' when '10011'then '区X044北京' when '10017'then '区X045北京'
when '1233'then '区X046天津' when '1234'then '区X047天津' when '1235'then '区X048天津' when '1236'then '区X049天津' when '1237'then '区X050天津'
when '1238'then '区X051天津' when '1239'then '区X052天津' when '3971'then '区X053常州' when '1093'then '区X054杭州' when '1092'then '区X055杭州'
when '1091'then '区X056杭州' when '1090'then '区X057杭州' when '1071'then '区X058济南' when '1072'then '区X059济南' when '1073'then '区X060济南'
when '1102'then '区X061南京' when '1103'then '区X062南京' when '1104'then '区X063南京' when '1105'then '区X064南京' when '1106'then '区X065南京'
when '1107'then '区X066南京' when '1211'then '区X067郑州' when '1181'then '区X068无锡' when '1180'then '区X069无锡' when '1113'then '区X070苏州'
when '1112'then '区X071苏州' when '1081'then '区X072青岛' when '1082'then '区X073青岛' when '6123'then '区X074宁波' when '6122'then '区X075宁波'
when '1011'then '区X076上海' when '1012'then '区X077上海' when '1013'then '区X078上海' when '1014'then '区X079上海' when '1015'then '区X080上海'
when '1016'then '区X081上海' when '1017'then '区X082上海' when '1018'then '区X083上海' else t1.store_name end
,case when t3.store_code is not null then '加盟店' else '直营店' end
,COALESCE(t2.store_code,t7.store_code)
,COALESCE(t2.store_name,t7.store_name)
,case when t5.business_district_id is null then COALESCE(t2.hps_dept_descr_lv5,t7.hps_dept_descr_lv5) else 
case t5.business_district_id
when '1000'then '区X001北京' when '1001'then '区X002北京' when '1002'then '区X003北京' when '1232'then '区X004天津' when '1231'then '区X005天津'
when '1018'then '区X006上海' when '1101'then '区X007南京' when '1094'then '区X008杭州' when '1074'then '区X009济南' when '6120'then '区X010宁波'
when '1080'then '区X012青岛' when '10012'then '区X013北京' when '10013'then '区X014北京' when '10014'then '区X015北京' when '10015'then '区X016北京'
when '10016'then '区X017北京' when '1230'then '区X018天津' when '1019'then '区X019上海' when '1100'then '区X020南京' when '1070'then '区X021济南'
when '10018'then '区X024北京' when '1880'then '区X027廊坊' when '1030'then '区X028石家庄' when '1210'then '区X029郑州' when '3970'then '区X030常州'
when '6121'then '区X031宁波' when '1110'then '区X032苏州' when '1182'then '区X033无锡' when '2330'then '区X034金华' when '2320'then '区X035温州'
when '1003'then '区X036北京' when '1004'then '区X037北京' when '1005'then '区X038北京' when '1006'then '区X039北京' when '1007'then '区X040北京'
when '1008'then '区X041北京' when '1009'then '区X042北京' when '10010'then '区X043北京' when '10011'then '区X044北京' when '10017'then '区X045北京'
when '1233'then '区X046天津' when '1234'then '区X047天津' when '1235'then '区X048天津' when '1236'then '区X049天津' when '1237'then '区X050天津'
when '1238'then '区X051天津' when '1239'then '区X052天津' when '3971'then '区X053常州' when '1093'then '区X054杭州' when '1092'then '区X055杭州'
when '1091'then '区X056杭州' when '1090'then '区X057杭州' when '1071'then '区X058济南' when '1072'then '区X059济南' when '1073'then '区X060济南'
when '1102'then '区X061南京' when '1103'then '区X062南京' when '1104'then '区X063南京' when '1105'then '区X064南京' when '1106'then '区X065南京'
when '1107'then '区X066南京' when '1211'then '区X067郑州' when '1181'then '区X068无锡' when '1180'then '区X069无锡' when '1113'then '区X070苏州'
when '1112'then '区X071苏州' when '1081'then '区X072青岛' when '1082'then '区X073青岛' when '6123'then '区X074宁波' when '6122'then '区X075宁波'
when '1011'then '区X076上海' when '1012'then '区X077上海' when '1013'then '区X078上海' when '1014'then '区X079上海' when '1015'then '区X080上海'
when '1016'then '区X081上海' when '1017'then '区X082上海' when '1018'then '区X083上海' else t2.store_name end
end
,COALESCE(t2.hps_d_jobcode,t7.hps_d_jobcode)
,COALESCE(t2.post_name,t7.post_name)
,COALESCE(t2.student_suspect,t7.student_suspect)
,case when t1.store_code = COALESCE(t2.store_code,t7.store_code) then '本店' else '非本店' end








--以门店为中心找周围3公里内直营店
SELECT 
t1.*
,t2.gap_new --有gap代表是直营店
,t2.gap_new_withoutlow
from data_gis_h3.mid_order_external_same_city_store_riding_distance_type_zero_do_business_union_all_view t1
left join data_build.dwd_store_construction_store_groups_recruit_gap t2 on t1.b_store_code = t2.store_code and t2.dt = '${today-1}'
where t1.dt = '${today-1}'
and a_store_code = 100001203
and t1.distince <= '3000'
and t2.gap_new is not null

--门店日商，FF日商
select
trunc(order_date,'MM') as month
,store_code
,store_name

--售卖日
,count(distinct order_date) as sale_num --全部售卖日

--折后销售额 按照到店/外卖拆分
,sum(payable_price)/count(distinct order_date) as payable_price --全部销售额

--折后销售额 按照商品拆分
,sum(case when sku_class_code in ('03','05','06') then payable_price else 0 end )/count(distinct order_date) as payable_price_ff --日配制作类销售额

from data_build.dw_order_sku_promotion_v1 a
where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and order_date between '2025-07-01' and '2025-07-30'
and store_type = '0'
and pay_status = 'PAY_SUCCESS'
--and a.store_code = '100000696'
group by
trunc(order_date,'MM')
,store_code
,store_name


22岁以下放开，前几年数据，截止到8月底和截止到9月中旬的离职率
口径：提离职率
8月15-8月31号入职的22岁以下，看7天/14天/21天的离职率
22岁以下(学生PT，其它)和22岁以上
需要和当年7月份入职的做对比(7月1号到7月31号)
看过去3年

SELECT
emplid
,name
,hps_d_jobcode
,hps_hire_dt
,leave_dt
from data_build.pdw_psprod_ps_blf_ehr_pers_vw_view
where dt between '20220701' and '20220915' 
and hps_hire_dt between '2022-07-01' and '2022-08-31'

union all

SELECT
emplid
,name
,hps_d_jobcode
,hps_hire_dt
,leave_dt
from data_build.pdw_psprod_ps_blf_ehr_pers_vw_view
where dt between '20230701' and '20230915' 
and hps_hire_dt between '2023-07-01' and '2023-08-31'

union all

SELECT
emplid
,name
,hps_d_jobcode
,hps_hire_dt
,leave_dt
from data_build.pdw_psprod_ps_blf_ehr_pers_vw_view
where dt between '20240701' and '20240915' 
and hps_hire_dt between '2024-07-01' and '2024-08-31'

发薪后一批试验转加盟门店的提离职情况

新人入职顶替已提离职员工的案例
--0804-0810提离职员工的门店
--0811-0817这些门店进新人


--现存门店sku_class_name=牛奶、乳饮料，近三年销售趋势，top20品的销售趋势(当前TOP20和历史每个月的TOP20)
--大分类销售
begin
    select
    trunc(t0.order_date,'MM') as month
    ,t0.sku_class_name
    ,count(distinct t0.store_code) as store_num
    ,count(distinct t0.sku_code) as sku_num
    ,sum(sku_quantity) as sku_quantity
    ,sum(payable_price) as payable_price
    from data_build.dw_order_sku_v1 t0
    join (
    select distinct
    t1.store_code
    ,t1.store_status_blf
    from data_build.dwd_store_construction_project_status_v2_di t1
    where t1.dt = '${today-2}'
    and t1.store_status_blf in ('1正常保留-已开业门店')
    ) t1 on t0.store_code = t1.store_code
    where t0.dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
    and t0.store_type = '0'
    and t0.order_status = 'FINISHED'
    --and t0.sku_class_name = '牛奶、乳饮料'
    and t0.sku_division_name in ('牛奶','酸奶')
    and t0.sku_quantity > 0
    and t0.order_date between '2023-01-01' and '2025-08-20'
    group BY
    trunc(t0.order_date,'MM')
    ,t0.sku_class_name

    --前20品销售
    with raw_list as(
    select
    sku_code
    ,sku_name
    ,count(distinct t0.store_code) as store_num
    ,sum(sku_quantity) as sku_quantity
    ,sum(payable_price) as payable_price
    from data_build.dw_order_sku_v1 t0
    join (
    select distinct
    t1.store_code
    ,t1.store_status_blf
    from data_build.dwd_store_construction_project_status_v2_di t1
    where t1.dt = '${today-2}'
    and t1.store_status_blf in ('1正常保留-已开业门店')
    ) t1 on t0.store_code = t1.store_code
    where t0.dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
    and t0.store_type = '0'
    and t0.order_status = 'FINISHED'
    --and t0.sku_class_name = '牛奶、乳饮料'
    and t0.sku_division_name in ('牛奶','酸奶')
    and t0.sku_quantity > 0
    and t0.order_date between '2025-07-01' and '2025-08-20'
    group BY
    sku_code
    ,sku_name
    )

    ,row_num as(
    select
    sku_code
    ,sku_name
    ,sku_quantity/store_num
    ,payable_price/store_num
    ,ROW_NUMBER() OVER(order by sku_quantity/store_num desc) as sku_quantity_row
    ,ROW_NUMBER() OVER(order by payable_price/store_num desc) as payable_price_row
    from raw_list
    )

    select
    trunc(t0.order_date,'MM') as month
    ,t0.sku_class_name
    ,count(distinct t0.store_code) as store_num
    ,sum(sku_quantity) as sku_quantity
    ,sum(payable_price) as payable_price
    from data_build.dw_order_sku_v1 t0
    join (
    select distinct
    t1.store_code
    ,t1.store_status_blf
    from data_build.dwd_store_construction_project_status_v2_di t1
    where t1.dt = '${today-2}'
    and t1.store_status_blf in ('1正常保留-已开业门店')
    ) t1 on t0.store_code = t1.store_code
    join row_num t3 on t0.sku_code = t3.sku_code
    where t0.dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
    and t0.store_type = '0'
    and t0.order_status = 'FINISHED'
    --and t0.sku_class_name = '牛奶、乳饮料'
    and t0.sku_division_name in ('牛奶','酸奶')
    and t3.payable_price_row <= 10 --销售排名前20的品
    and t0.sku_quantity > 0
    and t0.order_date between '2023-01-01' and '2025-08-20'
    group BY
    trunc(t0.order_date,'MM')
    ,t0.sku_class_name

    --每月top20
    with raw_list as(
    select
    trunc(order_date,'MM') as month
    ,sku_code
    ,sku_name
    ,count(distinct t0.store_code) as store_num
    ,sum(sku_quantity) as sku_quantity
    ,sum(payable_price) as payable_price
    from data_build.dw_order_sku_v1 t0
    join (
    select distinct
    t1.store_code
    ,t1.store_status_blf
    from data_build.dwd_store_construction_project_status_v2_di t1
    where t1.dt = '${today-2}'
    and t1.store_status_blf in ('1正常保留-已开业门店')
    ) t1 on t0.store_code = t1.store_code
    where t0.dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
    and t0.store_type = '0'
    and t0.order_status = 'FINISHED'
    and t0.sku_class_name = '牛奶、乳饮料'
    and t0.sku_quantity > 0
    and t0.order_date between '2023-01-01' and '2025-08-20'
    group BY
    trunc(order_date,'MM')
    ,sku_code
    ,sku_name
    )

    ,row_num as(
    select
    month
    ,sku_code
    ,sku_name
    ,payable_price/store_num
    ,ROW_NUMBER() OVER(partition by month order by payable_price/store_num desc) as payable_price_row
    from raw_list
    )

    select
    trunc(t0.order_date,'MM') as month
    ,t0.sku_class_name
    ,count(distinct t0.sku_code) as sku_num
    ,count(distinct t0.store_code) as store_num
    ,sum(sku_quantity) as sku_quantity
    ,sum(payable_price) as payable_price
    from data_build.dw_order_sku_v1 t0
    join (
    select distinct
    t1.store_code
    ,t1.store_status_blf
    from data_build.dwd_store_construction_project_status_v2_di t1
    where t1.dt = '${today-2}'
    and t1.store_status_blf in ('1正常保留-已开业门店')
    ) t1 on t0.store_code = t1.store_code
    join row_num t3 on t0.sku_code = t3.sku_code and trunc(t0.order_date,'MM') = t3.month
    where t0.dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
    and t0.store_type = '0'
    and t0.order_status = 'FINISHED'
    and t0.sku_class_name = '牛奶、乳饮料'
    and t3.payable_price_row <= 20 --销售排名前20的品
    and t0.sku_quantity > 0
    and t0.order_date between '2023-01-01' and '2025-08-20'
    group BY
    trunc(t0.order_date,'MM')
    ,t0.sku_class_name
end

--店副晋升意愿次数统计
begin
    with order_flow_main as(
    select
    order_id
    ,lpad(SUBSTRING_INDEX(SUBSTRING_INDEX(flow_ame, '(', -1), ')', 1),8,'10') as staff_code
    ,SUBSTRING(flow_ame, LENGTH(flow_ame) - 7, 8) as record_date
    ,create_time
    ,order_status
    from data_build.pdw_order_store_211_order_detail_flow_main
    where dt = '${today-1}'
    and flow_code = '032042' --流程code
    and TO_DATE(create_time) >= '2025-03-21' --从3月21号起开始统计拒绝次数
    )

    ,promotion_wish_result as(
    SELECT
    t0.order_id
    ,t0.staff_code
    ,t0.record_date
    ,t0.create_time
    ,t0.order_status
    ,case when t1.form_name = 'toStoreCode' then get_json_object(get_json_object(t1.form_values,'$.[0]'),'$.value') else null end as toStoreCode
    ,case when t2.accept = '1' then '接受' when t2.accept = '0' then '拒绝' else t2.accept end as accept
    ,t2.reason
    ,t2.shopCode
    ,row_number() over(partition by concat(t0.staff_code,case when t1.form_name = 'toStoreCode' then get_json_object(get_json_object(t1.form_values,'$.[0]'),'$.value') else null end) order by t0.create_time desc) as rm
    --人*店维度按照接收晋升意愿时间降序排序
    from order_flow_main t0
    left join data_build.pdw_order_store_211_order_detail_flow_form_variable_groups_da t1 on t0.order_id = t1.order_id
    and t1.dt = '${today-1}'
    and t1.form_name in ('toStoreCode') 
    left join(
    select
    order_id
    ,max(case when form_name = 'accept' then get_json_object(get_json_object(form_values,'$.[0]'),'$.value') else null end) as accept
    ,max(case when form_name = 'refuseReasonType' then get_json_object(get_json_object(form_values,'$.[0]'),'$.value') else null end) as reason
    ,max(case when form_name = 'shopCode' then get_json_object(get_json_object(form_values,'$.[0]'),'$.value') else null end) as shopCode
    from data_build.pdw_order_store_211_order_detail_flow_form_variable_groups_da
    where dt = '${today-1}'
    and form_name in ('accept','refuseReasonType','shopCode')
    group by
    order_id
    ) t2 on t1.order_id = t2.order_id
    )

    select
    substr(create_time,1,10) as compute_period
    ,count(distinct order_id) as `发起总量`
    ,count(distinct case when order_status = 'FINISHED' then order_id else null end) as `审批完成数量`
    ,count(distinct case when order_status = 'FINISHED' and accept = '接受' then order_id else null end) as `候选人接受数量`
    ,count(distinct case when order_status = 'FINISHED' and accept = '接受' then order_id else null end)/count(distinct case when order_status = 'FINISHED' then order_id else null end) as `接受率`
    from promotion_wish_result
    group by
    substr(create_time,1,10)
end

--staff_list(修正入职日期)
begin
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
end

--店长晋升流程明细
begin
    with main_list as( --历史流程统计
    SELECT * 
    from data_build.pdw_order_store_211_order_detail_flow_main
    where dt = '${today-1}'
    and flow_code = '031412' --晋升/接店意愿沟通
    --and order_id = '2110190404594840'
    )

    ,result_list as(
    select
    substr(t1.create_time,1,10) as compute_period --流程发起日期
    ,t1.order_id --流程编码
    ,t1.order_status --流程状态
    ,t1.flow_ame --流程名称
    ,SUBSTRING(t1.flow_ame, LOCATE('(', t1.flow_ame) + 1, LOCATE(')', t1.flow_ame) - LOCATE('(', t1.flow_ame) - 1) AS staff_code --员工编码
    ,t1.create_time --创建时间
    ,max(case when t2.form_name in ('accept') then nvl(get_json_object(t2.form_values,'$[0].label'),'未处理') else null end) as result --意愿
    ,max(case when t2.form_name in ('refuseReasonType') then get_json_object(t2.form_values,'$[0].label') else null end) as reason --原因
    ,row_number() over(partition by concat(substr(t1.create_time,1,10),regexp_extract(t1.flow_ame,'\\(([^)]+)\\)',1)) order by t1.create_time desc) as rn
    from main_list t1
    left join data_build.pdw_order_store_211_order_detail_flow_form_variable_groups_da t2
    on t1.order_id = t2.order_id
    and t2.dt = '${today-1}'
    and t2.form_name in ('accept','refuseReasonType')
    group by
    substr(t1.create_time,1,10)
    ,t1.order_id
    ,t1.order_status
    ,t1.flow_ame
    ,SUBSTRING(t1.flow_ame, LOCATE('(', t1.flow_ame) + 1, LOCATE(')', t1.flow_ame) - LOCATE('(', t1.flow_ame) - 1)
    ,t1.create_time
    )
end

--店副晋升流程明细
begin
    with order_flow_main as(
    select
    order_id
    ,lpad(SUBSTRING_INDEX(SUBSTRING_INDEX(flow_ame, '(', -1), ')', 1),8,'10') as staff_code
    ,SUBSTRING(flow_ame, LENGTH(flow_ame) - 7, 8) as record_date
    ,create_time
    ,order_status
    from data_build.pdw_order_store_211_order_detail_flow_main
    where dt = '${today-1}'
    and flow_code = '032042' --流程code
    and TO_DATE(create_time) >= '2025-03-21' --从3月21号起开始统计拒绝次数
    )

    ,promotion_wish_result as(
    SELECT
    t0.order_id
    ,t0.staff_code
    ,t0.record_date
    ,t0.create_time
    ,t0.order_status
    ,case when t2.accept = '1' then '接受' when t2.accept = '0' then '拒绝' else t2.accept end as accept
    ,t2.reason
    ,t2.shopCode
    from order_flow_main t0
    left join(
    select
    order_id
    ,max(case when form_name = 'accept' then get_json_object(get_json_object(form_values,'$.[0]'),'$.value') else null end) as accept
    ,max(case when form_name = 'refuseReasonType' then get_json_object(get_json_object(form_values,'$.[0]'),'$.value') else null end) as reason
    ,max(case when form_name = 'shopCode' then get_json_object(get_json_object(form_values,'$.[0]'),'$.value') else null end) as shopCode
    from data_build.pdw_order_store_211_order_detail_flow_form_variable_groups_da
    where dt = '${today-1}'
    and form_name in ('accept','refuseReasonType','shopCode')
    group by
    order_id
    ) t2 on t0.order_id = t2.order_id
    )
end

--门店证照信息
begin
    with project_list as (
    select
            t1.flag_code
            ,t1.project_id
            ,t1.project_name
            ,t1.city_name
            ,t1.store_code
            ,t1.store_name
            ,t1.store_status_blf
            ,t2.id                              as store_id
            ,t2.license_name
            ,t2.main_body_company               as operator_main_body_name
        from data_build.dwd_store_construction_project_status_v2_di t1
        left join data_build.pdw_opc_engineering_engineering_store t2 on t1.flag_code = t2.flag_number and t2.dt >= date_format(date_sub(current_date(),1),'yyyyMMdd')
        where t1.dt >= date_format(date_sub(current_date(),2),'yyyyMMdd')
        and t1.store_status_blf not in ('4实际未签约的生效门店','5非便利店')
    ),


    license_info as (
        select 
            store_id
            ,id
            ,to_date(create_time)																as create_date
            ,type_code
            ,case when element_code = 'checkDate' then element_value end              			as checkDate	--发证日期
            ,case when element_code = 'owner' then element_value end                  			as owner	--法人
            ,case when element_code = 'validStartDate' then element_value end         			as validStartDate --证照有效期起
            ,case when element_code = 'validEndDate' then element_value end         			as validEndDate --证照有效期止
            ,case when element_code = 'picture' then element_value end                			as picture --证照图片正本
            ,case when element_code = 'licenseCode' then element_value end                      as licenseCode --证照编号
            ,row_number()over(partition by (store_id,type_code) order by  create_time desc) 	as rn
        from data_build.dwd_store_construction_project_license_detail_v1
        where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
        and type_code in (1,2,4,6)
    ),

    other_max_date as (
        select 
            store_id
            ,type_code
            ,max(create_date) as max_date
        from license_info
        where type_code <> 4
        group by store_id
            ,type_code
    ),

    business_license_max_date as (
        select 
            store_id
            ,type_code
            ,max(create_date) as max_date
        from license_info
        where type_code = 4
        group by store_id
            ,type_code
    ),

    result_set as (
        select 
            t1.flag_code
            ,t1.project_id
            ,t1.project_name
            ,t1.city_name
            ,t1.store_code
            ,t1.store_name
            ,t1.store_status_blf
            ,t1.store_id
            ,t1.license_name
            ,t1.operator_main_body_name
            --营业执照
            ,case when t3.type_code = 4 then t3.owner end							as business_license_owner--营业执照：法人
            ,case when t3.type_code = 4 then t3.validStartDate end 					as business_license_validStartDate--营业执照：证照有效期起
            ,case when t3.type_code = 4 then t3.picture end 						as business_license_picture--营业执照：照片
            --食品经营许可证
            ,case when t4.type_code = 1 then t4.validStartDate end 					as food_buisness_license_validStartDate--食品经营许可证：证照有效起日
            ,case when t4.type_code = 1 then t4.validEndDate end 					as food_buisness_license_validEndDate--食品经营许可证：证照有效止日
            ,case when t4.type_code = 1 then t4.picture end 						as food_buisness_license_picture--食品经营许可证：照片
            --烟草
            ,case when t4.type_code = 2 then t4.validStartDate end 					as tobacco_validStartDate--烟草：证照有效起日
            ,case when t4.type_code = 2 then t4.validEndDate end 					as tobacco_validEndDate--烟草：证照有效止日
            ,case when t4.type_code = 2 then t4.picture end 						as tobacco_picture--烟草：照片
            --二类医疗
            ,case when t4.type_code = 6 then t4.validStartDate end 					as medical_validStartDate--二类医疗：证照有效起日
            ,case when t4.type_code = 6 then t4.picture end 						as medical_picture--二类医疗：照片
            ,case when t4.type_code = 6 then t4.licenseCode end                     as medical_licenseCode--二类医疗：备案号
        from project_list t1
        left join other_max_date t2 on t1.store_id = t2.store_id 
        left join business_license_max_date t5 on t1.store_id = t5.store_id
        left join license_info t3 on t1.store_id = t3.store_id
            and t5.max_date = t3.create_date
            and t3.type_code = 4
        left join license_info t4 on t1.store_id = t4.store_id and t2.max_date = t4.create_date and t4.type_code <> 4
        where (t3.owner is not null 
            or t3.validStartDate is not null 
            or t3.picture is not null)
        or (t4.validStartDate is not null
            or t4.validEndDate is not null 
            or t4.picture is not null)
    )

    select 
        t1.flag_code
        ,t1.project_id
        ,t1.project_name
        ,t1.city_name
        ,t1.store_code
        ,t1.store_name
        ,t1.store_status_blf
        ,t1.store_id
        ,t1.license_name
        ,t1.operator_main_body_name
        ,datediff(max(food_buisness_license_validEndDate),current_date()) as food_buisness_license_date_cnt
        ,datediff(max(tobacco_validEndDate),current_date()) as tobacco_date_cnt
        ,max(business_license_owner) as business_license_owner
        ,max(business_license_validStartDate) as business_license_validStartDate
        ,max(business_license_picture) as business_license_picture
        ,max(food_buisness_license_validStartDate) as food_buisness_license_validStartDate
        ,max(food_buisness_license_validEndDate) as food_buisness_license_validEndDate
        ,max(food_buisness_license_picture) as food_buisness_license_picture
        ,max(tobacco_validStartDate) as tobacco_validStartDate
        ,max(tobacco_validEndDate) as tobacco_validEndDate
        ,max(tobacco_picture) as tobacco_picture
        ,max(medical_validStartDate) as medical_validStartDate
        ,max(medical_picture) as medical_picture
        ,max(medical_licenseCode) as medical_licenseCode
        ,t3.area_name
    ,1 as is_view
    from result_set t1
    left join data_build.pdw_opc_engineering_engineering_store t2 on t1.store_code = t2.shop_code and t2.dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
    left join data_build.dim_area_info_v2 t3 on t2.area_code = t3.area_code and t3.dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
    group by t1.flag_code
        ,t1.project_id
        ,t1.project_name 
        ,t1.city_name
        ,t1.store_code
        ,t1.store_name
        ,t1.store_status_blf
        ,t1.store_id
        ,t1.license_name
        ,t1.operator_main_body_name
        ,t3.area_name
    ,1
end

--失败班次率统计
begin
    select
    work_date
    ,count(case when is_franchise_store = 0 then roster_id else null end) as roster_num --非加盟店总班次数
    ,count(case when is_franchise_store = 0 and roster_source = '失败班表' then roster_id else null end) as fail_roster_num --非加盟店失败班次数
    ,count(case when is_franchise_store = 0 and roster_source = '失败班表' then roster_id else null end)/count(case when is_franchise_store = 0 then roster_id else null end) as fail_roster_rat
    from data_smartorder.dw_roster_effect_roster_detail_info_da_view a
    left join data_smartorder.dw_ordering_store_tag_location_ranking_info_v1 b on a.store_id = b.store_code and b.dt = '${today-1}'
    where a.dt = replace(current_date(),"-","")
    and work_date >= date_sub(next_day(current_date(),'mon'),455)
    and work_date <= date_add(next_day(current_date(),'mon'),41)
    and a.store_type_desc = '门店'
    and a.end_time - a.start_time >= 4
    and a.class_id = 0 --运营班次
    group by
    work_date
end

--门店交接流程判断是否允许二次晋升
begin
    --落表data_build.dwd_store_handover_automated_judgment_da
    --降职流程中选择永久降职的员工
    --门店降职流程
    with order_flow_main_demotion as(
    select
    order_id --流程编码(流程信息)
    ,order_status --流程状态(流程信息)
    ,if(length(initiator_code)=6,concat('10',initiator_code),initiator_code) as initiator_code --发起人编码(流程信息)
    ,create_time --流程发起时间(流程信息)
    ,flow_ame --流程名称(流程信息)
    ,org_code --门店编码(流程信息)
    ,org_name --门店名称(流程信息)
    from data_build.pdw_order_store_211_order_detail_flow_main
    where dt = date_format(date_sub(current_date,1),'yyyyMMdd')
    and flow_code = '032134' --流程code
    and order_status = 'FINISHED' --流程必须结束，证明暂时/永久降职生效
    ),

    order_flow_groups_demotion as(
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
    where dt = date_format(date_sub(current_date,1),'yyyyMMdd')
    --and order_id = '2110156450344230'
    ) a
    group by
    order_id
    ),

    demotion_fainl as(
    select
    a.initiator_code,
    a.order_status,
    a.create_time,
    b.typeofdemote
    ,row_number() over(partition by a.initiator_code order by a.create_time desc) as rn
    from order_flow_main_demotion a
    left join order_flow_groups_demotion b on a.order_id = b.order_id
    )

    --门店交接申请流程
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
    where dt = '${today-1}'
    and flow_code = '017270' --流程code
    --and order_status in ('PROCESSING','FINISHED')
    and order_status = 'FINISHED' --流程必须结束，证明交接完成
    ),

    order_flow_groups as(
    select
    order_id
    ,max(now_mgr) as now_mgr
    ,max(shop_name) as shop_name
    ,max(remark) as remark
    ,max(remarkdes) as remarkdes
    ,max(thisweektag) as thisweektag
    ,max(changeto) as changeto
    from(
    select
    order_id
    ,case when form_name = 'shopOwnerCnName' then get_json_object(get_json_object(form_values,'$.[0]'),'$.value') else null end as now_mgr --现任店经理
    ,case when form_name = 'shopName' then get_json_object(get_json_object(form_values,'$.[0]'),'$.label') else null end as shop_name --交接门店
    ,case when form_name = 'remark' then get_json_object(get_json_object(form_values,'$.[0]'),'$.label') else null end as remark --交接原因
    ,case when form_name = 'remarkdes' then get_json_object(get_json_object(form_values,'$.[0]'),'$.label') else null end as remarkdes --原因描述
    ,case when form_name = 'thisweektag' then get_json_object(get_json_object(form_values,'$.[0]'),'$.label') else null end as thisweektag --现任店经理标签
    ,case when form_name = 'changeto' then get_json_object(get_json_object(form_values,'$.[0]'),'$.label') else null end as changeto --现任店经理去向
    ,case when form_name = 'whychange' then get_json_object(get_json_object(form_values,'$.[0]'),'$.label') else null end as whychange --现任店经理汰换/主动离职/降职原因
    from data_build.pdw_order_store_211_order_detail_flow_form_variable_groups_da
    where dt = '${today-1}'
    and form_name in ('shopOwnerCnName','shopName','remark','remarkdes','thisweektag','changeto','whychange')
    --and order_id = '2110157213089599'
    ) a
    group by order_id
    )

    ,order_flow_taskorders as(
    select
    order_id
    ,max(second_change) as second_change
    from(
    select
    order_id
    ,taskorder_node_id
    ,element
    ,case when taskorder_node_id = 'UserTask_0601fr9' and get_json_object(element,'$.name') = 'secondchange' then get_json_object(get_json_object(element,'$.values'),'$.value') else null end as second_change --中台审核(是否允许现任店长后续再次接店)
    from(
    select
    order_id
    ,taskorder_node_id
    ,task_orders
    ,row_number() over(partition by concat(order_id,taskorder_node_id) order by taskorder_create_time desc) as rn
    from data_build.pdw_order_store_211_order_detail_flow_task_taskorders
    where dt = date_format(date_sub(current_date,1),'yyyyMMdd')
    --and order_id = '2110157929325986'
    and taskorder_result = 'AGREE'
    and taskorder_status = 'FINISHED'
    and (taskorder_node_id = 'UserTask_0601fr9')
    ) a
    lateral view
    explode(split(regexp_replace(regexp_replace(task_orders, '\\\\[|\\\\]' , ''), '\\\\}\\\\,\\\\{' , '\\\\}\\\\&\\\\{'), '&')) x1 as element
    where rn = 1
    ) b
    group by
    order_id
    )

    select
    a.order_id
    ,a.create_date
    ,a.order_status
    ,a.initiator_code
    ,a.flow_ame
    ,a.org_code
    ,a.org_name
    ,b.now_mgr
    ,b.shop_name
    ,b.remark
    ,b.remarkdes
    ,b.thisweektag
    ,b.changeto
    ,case when reverse(substr(reverse(b.now_mgr),0,instr(reverse(b.now_mgr),'-')-1)) <> ''
    then lpad(reverse(substr(reverse(b.now_mgr),0,instr(reverse(b.now_mgr),'-')-1)),8,'10') else regexp_replace(b.now_mgr, '[^一-龥]', '') end as staff_code
    ,e.is_district
    ,c.second_change
    ,d.typeofdemote --降职类型
    ,case when d.typeofdemote = '永久降职' then '禁止现任店长二次晋升'
    when e.is_district = '1' then '现任店经理为机动队队员，不在此处做二次晋升判断'
    when b.remark = '门店有店长出勤，但命中汰换' then '禁止现任店长二次晋升'
    when b.remark in ('门店原店长个人原因主动离职','门店原店长个人原因主动降职','门店转合作经营，交接门店给加盟主','门店撤店释放优质店长','原店经理降职结束，根据降职保护规则重新接回门店','其他')
    and b.thisweektag in ('金牌及以上','银牌','优质银牌','金牌','钻石','应保护','普通银牌','待观察','无','银牌普通') then '允许现任店长二次晋升'
    when b.remark in ('门店原店长个人原因主动离职','门店原店长个人原因主动降职','门店转合作经营，交接门店给加盟主','门店撤店释放优质店长','原店经理降职结束，根据降职保护规则重新接回门店','其他')
    and b.thisweektag in ('铜牌','铜牌以下','应离职') then '禁止现任店长二次晋升'
    when b.remark = '城市总/战区/机动队带店' then '现任店经理为机动队队员，不在此处做二次晋升判断'
    when b.thisweektag in ('金牌及以上','银牌','优质银牌','金牌','钻石','应保护','普通银牌','待观察','无','银牌普通') then '允许现任店长二次晋升'
    when b.thisweektag in ('铜牌','铜牌以下','应离职') then '禁止现任店长二次晋升'
    else null end as comments
    from order_flow_main_handover a
    left join order_flow_groups_handover b on a.order_id = b.order_id
    left join order_flow_taskorders_handover c on a.order_id = c.order_id
    left join demotion_fainl d on case when reverse(substr(reverse(b.now_mgr),0,instr(reverse(b.now_mgr),'-')-1)) <> ''
    then lpad(reverse(substr(reverse(b.now_mgr),0,instr(reverse(b.now_mgr),'-')-1)),8,'10') else regexp_replace(b.now_mgr, '[^一-龥]', '') end = d.initiator_code and d.rn = 1
    left join data_shop.dm_shop_staff_protect_tag_v2 e on case when reverse(substr(reverse(b.now_mgr),0,instr(reverse(b.now_mgr),'-')-1)) <> ''
    then lpad(reverse(substr(reverse(b.now_mgr),0,instr(reverse(b.now_mgr),'-')-1)),8,'10') else regexp_replace(b.now_mgr, '[^一-龥]', '') end = e.staff_code and e.dt = date_format(a.create_date,'yyyyMMdd')
    and e.dt > 20161231
end

--门店降职流程
begin
    with order_flow_main as(
    select
    order_id --流程编码(流程信息)
    ,order_status --流程状态(流程信息)
    ,if(length(initiator_code)=6,concat('10',initiator_code),initiator_code) as initiator_code --发起人编码(流程信息)
    ,create_time --流程发起时间(流程信息)
    ,flow_ame --流程名称(流程信息)
    ,org_code --门店编码(流程信息)
    ,org_name --门店名称(流程信息)
    from data_build.pdw_order_store_211_order_detail_flow_main
    where dt = date_format(date_sub(current_date,1),'yyyyMMdd')
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
    where dt = date_format(date_sub(current_date,1),'yyyyMMdd')
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
    ,max(middleground_shifouquebian) as middleground_shifouquebian
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
    ,case when taskorder_node_id = 'UserTask_1tbwabs' and get_json_object(element,'$.name') = 'shifouquebian' then get_json_object(get_json_object(element,'$.values'),'$.value') else null end as middleground_shifouquebian--中台审核条件(是否需要加入店长缺编清单)

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
    where dt = date_format(date_sub(current_date,1),'yyyyMMdd')
    --and order_id = '2110156450344230'
    and taskorder_result = 'AGREE'
    and taskorder_status = 'FINISHED'
    and (taskorder_node_id = 'UserTask_1tbwabs' or taskorder_node_id = 'UserTask_0xiz2zo' or taskorder_node_id = 'UserTask_12fej7c')
    ) a
    lateral view
    explode(split(regexp_replace(regexp_replace(task_orders, '\\[|\\]' , ''), '\\}\\,\\{' , '\\}\\&\\{'), '&')) x1 as element
    where rn = 1
    ) b
    group by
    order_id
    )

    select
    a.*
    ,b.*
    ,c.*
    from order_flow_main a
    left join order_flow_groups b on a.order_id = b.order_id
    left join order_flow_taskorders c on a.order_id = c.order_id
end

--总店长人数，店副人数，机动队人数看板
begin
    with staff_list as(
    select
    t1.*
    ,t2.hps_d_jobcode
    ,case when t3.manager_code is not null and (t2.hps_dept_descr_lv5 not like '%区X%' or t2.hps_dept_descr_lv1 not in ('运营管理部X'))
    and t2.hps_d_jobcode not in ('外部合作辅助人','外部合作经营者','外部合作伙伴','内部合作辅助人','内部合作经营者','内部合作伙伴') then '店经理'
    when t2.hps_d_jobcode = '店副经理' then '店副经理'
    when t2.hps_dept_descr_lv5 like '%区X%' or t2.hps_dept_descr_lv1 in ('运营管理部X') then '机动队队员'
    when t2.hps_d_jobcode not in ('外部合作辅助人','外部合作经营者','外部合作伙伴','内部合作辅助人','内部合作经营者','内部合作伙伴') then '店员'
    else t2.hps_d_jobcode end as post_name
    from data_shop.dm_shop_staff_protect_tag_v2 t1
    left join data_build.pdw_psprod_ps_blf_ehr_pers_vw_view t2 on t1.staff_code = lpad(t2.emplid,8,'10') and t2.dt > '20231231' and t2.dt = t1.dt --hps_d_jobcode in ('店副经理')
    left join data_build.pdw_opc_shop_ehr_staff_dept_view t3 on t2.hps_dept_code_lv5 = t3.dept_code and lpad(t2.emplid,8,'10') = lpad(t3.manager_code,8,'10') and t3.dt > '20231231' and t3.dt = t1.dt --店长
    where t1.dt > '20231231'
    )

    select
    t1.dt
    ,t1.store_num
    ,t2.manager_num
    ,t2.vic_manager_num
    ,t2.district_num
    from(
    SELECT
    dt
    ,count(1) as store_num
    from data_build.dwd_store_construction_store_groups_recruit_gap
    where dt > '20231231'
    GROUP BY
    dt
    ) t1
    left join
    (
    select
    dt
    ,count(case when post_name = '店经理' then staff_code else null end) as manager_num
    ,count(case when post_name = '店副经理' then staff_code else null end) as vic_manager_num
    ,count(case when post_name in ('机动队带店店长','机动队队员') then staff_code else null end) as district_num
    from staff_list
    group by
    dt
    ) t2 on t1.dt = t2.dt
end

--员工出勤率统计
begin
    with staff_list as(
    select
    t1.staff_code
    ,t1.staff_name
    ,t1.city_name
    ,from_unixtime(unix_timestamp(t1.dt,'yyyyMMdd'),'yyyy-MM-dd') as record_date
    ,t2.hps_d_jobcode
    ,case when t3.manager_code is not null and (t2.hps_dept_descr_lv5 not like '%区X%' or t2.hps_dept_descr_lv1 not in ('运营管理部X'))
    and t2.hps_d_jobcode not in ('外部合作辅助人','外部合作经营者','外部合作伙伴','内部合作辅助人','内部合作经营者','内部合作伙伴') then '店经理'
    when t2.hps_d_jobcode = '店副经理' then '店副经理'
    when t2.hps_dept_descr_lv5 like '%区X%' or t2.hps_dept_descr_lv1 in ('运营管理部X') then '机动队队员'
    when t2.hps_d_jobcode not in ('外部合作辅助人','外部合作经营者','外部合作伙伴','内部合作辅助人','内部合作经营者','内部合作伙伴') then '店员'
    else t2.hps_d_jobcode end as post_name
    from data_shop.dm_shop_staff_protect_tag_v2 t1
    left join data_build.pdw_psprod_ps_blf_ehr_pers_vw_view t2 on t1.staff_code = lpad(t2.emplid,8,'10') and t2.dt > '20231231' and t2.dt = t1.dt --hps_d_jobcode in ('店副经理')
    left join data_build.pdw_opc_shop_ehr_staff_dept_view t3 on t2.hps_dept_code_lv5 = t3.dept_code and lpad(t2.emplid,8,'10') = lpad(t3.manager_code,8,'10') and t3.dt > '20231231' and t3.dt = t1.dt --店长
    where t1.dt > '20231231'
    )

    ,raw_list as(
    select
    t1.*
    ,t2.attendance_work_hours
    from staff_list t1
    left join(
    select
    lpad(employee_no,8,10) as staff_code
    ,work_shift_date
    ,sum(attendance_work_hours) as attendance_work_hours
    from data_shop.pdw_opc_shop_attendance_report_work_shift_view
    where dt = 20251014
    group by
    lpad(employee_no,8,10)
    ,work_shift_date
    ) t2 on t1.staff_code = t2.staff_code and t1.record_date = t2.work_shift_date
    )

    select
    record_date
    ,post_name
    ,count(1) as staff_num
    ,count(case when attendance_work_hours > 0 then staff_code else null end) as attendance_staff_num
    from raw_list
    where city_name = '北京'
    and record_date between '2025-01-01' and '2025-03-15'
    group by
    record_date
    ,post_name
end

--2026年春节员工给班情况统计
--保护标签表的人员准确岗位(店经理/店副/店员/机动队)
--data_shop.dwd_spring_festival_2026_staff_give_info_da
begin
    with staff_list as(
    select
    t1.*
    ,t2.hps_d_jobcode
    ,t2.hps_sys_name
    ,case when t3.manager_code is not null and (t2.hps_dept_descr_lv5 not like '%区X%' or t2.hps_dept_descr_lv1 not in ('运营管理部X'))
    and t2.hps_d_jobcode not in ('外部合作辅助人','外部合作经营者','外部合作伙伴','内部合作辅助人','内部合作经营者','内部合作伙伴') then '店经理'
    when t2.hps_d_jobcode = '店副经理' then '店副经理'
    when t4.employee_id is not null and (t2.hps_dept_descr_lv5 like '%区X%' or t2.hps_dept_descr_lv1 in ('运营管理部X')) then '机动队带店店长'
    when t5.employee_no is not null and (t2.hps_dept_descr_lv5 like '%区X%' or t2.hps_dept_descr_lv1 in ('运营管理部X'))  then t5.relation_type
    when t2.hps_dept_descr_lv5 like '%区X%' or t2.hps_dept_descr_lv1 in ('运营管理部X') then '机动队队员'
    when t2.hps_d_jobcode not in ('外部合作辅助人','外部合作经营者','外部合作伙伴','内部合作辅助人','内部合作经营者','内部合作伙伴') then '店员'
    else '加盟人员' end as post_name
    from data_shop.dm_shop_staff_protect_tag_v2 t1
    left join data_build.pdw_psprod_ps_blf_ehr_pers_vw_view t2 on t1.staff_code = lpad(t2.emplid,8,'10') and t2.dt = '${today-1}' --hps_d_jobcode in ('店副经理')
    left join data_build.pdw_opc_shop_ehr_staff_dept_view t3 on t2.hps_dept_code_lv5 = t3.dept_code and lpad(t2.emplid,8,'10') = lpad(t3.manager_code,8,'10') and t3.dt = '${today-1}' --店长
    left join data_build.dwd_store_construction_district_manager_base_info0_di t4 on t1.staff_code = t4.employee_id and t4.dt = '${today-2}'  --带店机动队(店经理)
    left join (select
    * from(
    select 
    employee_no,
    shop_code,
    relation_type,
    dt,
    row_number() over(partition by employee_no order by create_time desc) as rn
    from data_smartorder.dm_copy_pdw_opc_roster_motor_shop_relation_view
    where dt ='${today-1}'
    and delete_ts = 0
    and end_date >= '${TODAY}'
    and end_date <= '${TODAY + 6}'
    ) a
    where rn = 1
    ) t5 on t1.staff_code = lpad(t5.employee_no,8,'10') --带店机动队(店长/店副/陪跑店长/陪跑店副)
    where t1.dt = '${today-1}'
    )

    --25年春节给班情况
    ,date_list as(
    select distinct
    roster_date
    ,'1' as joinkey
    from data_smartorder.dw_roster_give_roster_detail_snapshot_da t0
    where t0.roster_date between '2026-01-26' and '2026-03-15'
    and t0.dt='${today-1}'
    )

    ,staff_list_1 as(
    select distinct
    staff_code
    ,'1' as joinkey
    from staff_list
    )

    ,date_staff_list as(
    select
    roster_date
    ,staff_code
    from date_list a
    left join staff_list_1 b on a.joinkey = b.joinkey
    )

    ,blacklist as (
        select distinct 
        employee_no
        ,lpad(employee_no,8,'10') as staff_code
    from data_shop.pdw_idss_ipes_admin_employee_blacklist_view -- 全量黑名单表
    where dt = '${today-1}' 
        and valid_status=1 
        and start_date <= '${TODAY}'
        and end_date >= '${TODAY}'
    )

    ,vacation_list as(
    select
    lpad(staff_no,8,'10') as staff_code
    ,third_workflow_id
    ,date_add(substr(vacation_start_time,1,10),mid_date) as vacation_day
    from data_smartorder.dm_copy_pdw_opc_shop_attendance_original_vacation_view t0
    lateral view posexplode(
    split(space(datediff(substr(vacation_end_time,1,10),substr(vacation_start_time,1,10))),'')
    ) t1 as mid_date,val
    where t0.dt = '${today-1}'
    --and t0.reason = '春节返乡假'
    and t0.status = '2' --数据状态 0初始,1待审批,2已同意,3已拒绝,4已转交,5取消
    )

    --销假明细
    ,revoke_vacation_list as(
    select
    lpad(employee_no,8,'10') as staff_code
    ,vacation_workflow_no
    ,date_add(from_unixtime(unix_timestamp(start_time), 'yyyy-MM-dd'),mid_date) as revoke_vacation_day
    from data_smartorder.dm_copy_pdw_opc_shop_attendance_revoke_vacation_view t0
    lateral view posexplode(
    split(space(datediff(from_unixtime(unix_timestamp(end_time), 'yyyy-MM-dd'),from_unixtime(unix_timestamp(start_time), 'yyyy-MM-dd'))),'')
    ) t1 as mid_date,val
    where t0.dt = '${today-1}'
    and t0.workflow_status = '2' --2已同意
    )

    ,merge_vacation_list as( --最终请假日期
    select
    t1.staff_code --员工编号
    ,t1.third_workflow_id
    ,t1.vacation_day --请假日期
    ,t2.vacation_workflow_no
    ,t2.revoke_vacation_day
    from vacation_list t1
    left join revoke_vacation_list t2 on t1.third_workflow_id = t2.vacation_workflow_no and t1.staff_code = t2.staff_code and t1.vacation_day = t2.revoke_vacation_day
    where t2.vacation_workflow_no is null
    )

    --如果请假当天时间在19:00以后，证明员工当天能上白班，所以不算当天请假；如果请假结束当天时间在19:00之前，证明员工当天能上夜班，所以不算当天请假
    ,merge_vacation_list_1 as( --最终请假日期_1
    select
    t1.staff_code --员工编号
    ,t1.third_workflow_id
    ,t1.vacation_day --请假日期
    ,t1.vacation_workflow_no
    ,t1.revoke_vacation_day
    ,t2.vacation_start_time
    ,t2.vacation_end_time
    ,case when t1.vacation_day = substr(t2.vacation_start_time,1,10) and substr(vacation_start_time,12,8) >= '19:00:00' then 1 
    when t1.vacation_day = substr(t2.vacation_end_time,1,10) and substr(vacation_end_time,12,8) <= '07:00:00' then 1
    else 0 end as start_time_delete --能上白班
    ,case when t1.vacation_day = substr(t2.vacation_end_time,1,10) and substr(vacation_end_time,12,8) <= '19:00:00' then 1 else 0 end end_time_delete --能上夜班
    from merge_vacation_list t1
    left join data_smartorder.dm_copy_pdw_opc_shop_attendance_original_vacation_view t2 on t1.third_workflow_id = t2.third_workflow_id and t2.dt = '${today-1}'
    )

    ,merge_vacation_list_2 as( --最终请假日期_2
    select
    staff_code --员工编号
    ,vacation_day --请假日期
    ,min(start_time_delete) as start_time_delete
    ,min(end_time_delete) as end_time_delete
    from merge_vacation_list_1
    group by
    staff_code --员工编号
    ,vacation_day --请假日期
    --where start_time_delete <> 1 and end_time_delete <> 1
    )

    ,give_list as(
    select 
    t0.target_date as week
    ,t0.roster_date
    ,t0.employee_id
    ,t0.employee_name
    ,t0.protect_tag
    ,t0.job
    ,t0.store_city
    ,t0.store_code
    ,t0.store_name
    ,t0.givetype
    ,case 
    when substring(t0.store_name,1,1)='区' then '机动队'
    when t0.job in('店经理','储备店经理','见习店经理') then '店长'
    when t0.job in('店副经理') then '店副'
    else '店员'
    end as position
    ,case
    ---完全标准班型
    when t0.start_time=6 and t0.end_time=22 then '白班'
    when t0.start_time=18 and t0.end_time=32 then '夜班'
    when t0.start_time=6 and t0.end_time=32 then '全班'
    ---重合区间区分
    when t0.start_time<=10 and t0.end_time-start_time>=21 then '全班'
    ---其他区间标签
    when t0.end_time<=24 or t0.start_time<=6 then '白班'
    when t0.end_time>24 then '夜班'
    else 0 end as label
    ,case
    when t0.start_time=6 and t0.end_time=32 then '全班'
    when t0.start_time<=10 and t0.end_time-t0.start_time>=21 then '全班'
    when t0.end_time-t0.start_time >= 8 then '长班'
    when t0.end_time-t0.start_time >= 4 and t0.end_time-t0.start_time < 8 then '短班1'
    when t0.end_time-t0.start_time < 4 then '短班'
    end as label_time
    ,t5.start_time_delete
    ,t5.end_time_delete
    ,case when t5.staff_code is not null then '1' else '0' end as is_vacation --当天是否请假，无论几点开始/结束
    ,case when t5.staff_code is null then '1' 
    when t5.staff_code is not null and start_time_delete = '1' and (case
    ---完全标准班型
    when t0.start_time=6 and t0.end_time=22 then '白班'
    when t0.start_time=18 and t0.end_time=32 then '夜班'
    when t0.start_time=6 and t0.end_time=32 then '全班'
    ---重合区间区分
    when t0.start_time<=10 and t0.end_time-start_time>=21 then '全班'
    ---其他区间标签
    when t0.end_time<=24 or t0.start_time<=6 then '白班'
    when t0.end_time>24 then '夜班'
    else 0 end) in ('全班','白班') then '1' --当天请假，请假时间在19点以后，且当天给班是白班/全天班，则当天可出勤
    when t5.staff_code is not null and end_time_delete = '1' and (case
    ---完全标准班型
    when t0.start_time=6 and t0.end_time=22 then '白班'
    when t0.start_time=18 and t0.end_time=32 then '夜班'
    when t0.start_time=6 and t0.end_time=32 then '全班'
    ---重合区间区分
    when t0.start_time<=10 and t0.end_time-start_time>=21 then '全班'
    ---其他区间标签
    when t0.end_time<=24 or t0.start_time<=6 then '白班'
    when t0.end_time>24 then '夜班'
    else 0 end) in ('全班','夜班') then '1' --当天请假，请假时间在19点以前，且当天给班是夜班/全天班，则当天可出勤   
    else '0' end as is_effective
    from data_smartorder.dw_roster_give_roster_detail_snapshot_da t0
    left join merge_vacation_list_2 t5 on lpad(t0.employee_id,8,'10') = t5.staff_code and t0.roster_date = t5.vacation_day
    where t0.roster_date between '2026-01-26' and '2026-03-15'
    and t0.dt='${today-1}'
    and t0.givetype<>'全天不开工'
    and t0.hps_d_hr_status='在职'
    )

    ,raw_list as(
    select
    t0.roster_date
    ,t0.staff_code
    ,t1.staff_name
    ,t1.hps_sys_name
    ,t1.city_name
    ,t1.store_code
    ,t1.store_name
    ,t1.protect_tag
    ,t1.post_name
    ,t2.label
    ,nvl(t2.is_vacation,0) as is_vacation
    ,nvl(t2.is_effective,0) as is_effective
    ,case when t3.staff_code is not null then '1' else '0' end as black
    ,t4.bach_business_time
    from date_staff_list t0
    left join staff_list t1 on t0.staff_code = t1.staff_code
    left join give_list t2 on t0.roster_date = t2.roster_date and t0.staff_code = t2.employee_id
    left join blacklist t3 on t0.staff_code = t3.staff_code
    left join(
    select
    record_date,
    store_code
    ,bach_business_time
    from data_smartorder.dw_ordering_report_store_business_status_da
    where dt = '${today-1}'
    and all_day_type = night_type
    ) t4 on t0.roster_date = t4.record_date and t1.store_code = t4.store_code
    )

    ,week_days_info as(
    select
    staff_code
    ,count(distinct case when record_week between '2026-01-26' and '2026-03-15' and week_give_days >= 5 then record_week else null end) as seven_week_give
    ,count(distinct case when record_week between '2026-02-02' and '2026-03-15' and week_give_days >= 5 then record_week else null end) as six_week_give
    from (
    select
    date_add(next_day(roster_date, 'MO'), -7) as record_week
    ,staff_code
    ,count(distinct case when is_effective = '1' then roster_date else null end) as week_give_days
    from raw_list
    group by
    date_add(next_day(roster_date, 'MO'), -7)
    ,staff_code
    ) a
    group by
    staff_code
    )

    ,give_days_info as(
    select
    staff_code
    ,staff_name
    ,hps_sys_name
    ,city_name
    ,store_code
    ,store_name
    ,protect_tag
    ,black
    ,case when post_name in ('ASSIST_MANAGER','ASSIST_VICE_MANAGER','SHOP_MANAGER','VICE_MANAGER','机动队带店店长','机动队队员') then '机动队' else post_name end as post_name
    ,count(distinct case when is_effective = '1' then roster_date else null end) as give_days
    ,count(distinct case when roster_date in ('2026-02-13','2026-02-14','2026-02-15','2026-02-16','2026-02-22','2026-02-23','2026-02-24','2026-02-25','2026-02-26','2026-02-27') 
    and is_effective = '1' then roster_date else null end) as important_give_days
    ,count(distinct case when roster_date in ('2026-02-14','2026-02-15','2026-02-23','2026-02-24')
    and is_effective = '1' then roster_date else null end) as have_to_give_days
    ,count(distinct case when roster_date between '2026-02-28' and '2026-03-15' and is_effective = '1' then roster_date else null end) as last_sixteen_give_days
    from raw_list
    group by
    staff_code
    ,staff_name
    ,hps_sys_name
    ,city_name
    ,store_code
    ,store_name
    ,protect_tag
    ,case when post_name in ('ASSIST_MANAGER','ASSIST_VICE_MANAGER','SHOP_MANAGER','VICE_MANAGER','机动队带店店长','机动队队员') then '机动队' else post_name end
    ,black
    )

    ,raw_list_1 as(
    select
    t0.*
    ,t1.seven_week_give
    ,t1.six_week_give
    from give_days_info t0
    left join week_days_info t1 on t0.staff_code = t1.staff_code
    )

    select
    staff_code
    ,staff_name
    ,hps_sys_name
    ,city_name
    ,store_code
    ,store_name
    ,post_name
    ,give_days
    ,seven_week_give
    ,important_give_days
    ,have_to_give_days
    ,six_week_give
    ,last_sixteen_give_days
    ,case when post_name = '加盟人员' then '加盟人员'
    when black = '1' then '黑名单'
    when post_name = '店员' and seven_week_give >= 5 then '合格'
    when post_name in ('店经理','店副经理') and important_give_days >= 8 and have_to_give_days = 4 and six_week_give >= 4 then '合格'
    when post_name = '机动队' and important_give_days >=8 and have_to_give_days = 4 and last_sixteen_give_days >= 14 then '合格'
    else '不合格' end as spring_festival_2026_result
    ,case when seven_week_give = '7' then '给班质量高' else '给班质量不高' end as give_quality
    from raw_list_1
end

--员工是否有被排过班
begin
    SELECT
    lpad(employee_no,8,10) as staff_code
    ,shift_date as work_date
    ,shift_store_code as store_code
    ,'班次超时拒绝' as result
    from dm_copy_pdw_opc_roster_plan_shift_affirm_history_view
    where dt = 20260310
    and shift_date BETWEEN '2026-02-09' and '2026-03-08'
    and affirm_result = '2'

    UNION all

    select
    lpad(employee_id,8,'10') as staff_code
    ,cast(work_date as date) as work_date
    ,store_id as store_code
    ,'成功班表' as result
    from data_build.dw_roster_effect_roster_detail_info_da_view 
    where dt = 20260310
    and store_type_desc = '门店'
    and (class_id in ('0','-5') or attr_id = '344')
    and store_type = '0'
    and roster_source = '成功班表'
    and work_date BETWEEN '2026-02-09' and '2026-03-08'
end

--2026不同时间下的春节给班情况
begin
    with staff_list as(
    select
    t1.*
    ,t2.hps_d_jobcode
    ,case when t3.manager_code is not null and (t2.hps_dept_descr_lv5 not like '%区X%' or t2.hps_dept_descr_lv1 not in ('运营管理部X'))
    and t2.hps_d_jobcode not in ('外部合作辅助人','外部合作经营者','外部合作伙伴','内部合作辅助人','内部合作经营者','内部合作伙伴') then '店经理'
    when t2.hps_d_jobcode = '店副经理' then '店副经理'
    when t4.employee_id is not null and (t2.hps_dept_descr_lv5 like '%区X%' or t2.hps_dept_descr_lv1 in ('运营管理部X')) then '机动队带店店长'
    when t5.employee_no is not null and (t2.hps_dept_descr_lv5 like '%区X%' or t2.hps_dept_descr_lv1 in ('运营管理部X'))  then t5.relation_type
    when t2.hps_dept_descr_lv5 like '%区X%' or t2.hps_dept_descr_lv1 in ('运营管理部X') then '机动队队员'
    when t2.hps_d_jobcode not in ('外部合作辅助人','外部合作经营者','外部合作伙伴','内部合作辅助人','内部合作经营者','内部合作伙伴') then '店员'
    else '加盟人员' end as post_name
    from data_shop.dm_shop_staff_protect_tag_v2 t1
    left join data_build.pdw_psprod_ps_blf_ehr_pers_vw_view t2 on t1.staff_code = lpad(t2.emplid,8,'10') and t2.dt = '${today-1}' --hps_d_jobcode in ('店副经理')
    --left join data_build.dwd_store_construction_manager_base_info_vi_di t3 on t1.staff_code = t3.employee_id and t3.dt = '${today-2}'  --店长
    left join data_build.pdw_opc_shop_ehr_staff_dept_view t3 on t2.hps_dept_code_lv5 = t3.dept_code and lpad(t2.emplid,8,'10') = lpad(t3.manager_code,8,'10') and t3.dt = '${today-1}' --店长
    left join data_build.dwd_store_construction_district_manager_base_info0_di t4 on t1.staff_code = t4.employee_id and t4.dt = '${today-2}'  --带店机动队(店经理)
    left join (select
    * from(
    select 
    employee_no,
    shop_code,
    relation_type,
    dt,
    row_number() over(partition by employee_no order by create_time desc) as rn
    from data_smartorder.dm_copy_pdw_opc_roster_motor_shop_relation_view
    where dt ='${today-1}'
    and delete_ts = 0
    and end_date >= '${TODAY}'
    ) a
    where rn = 1
    ) t5 on t1.staff_code = lpad(t5.employee_no,8,'10') --带店机动队(店长/店副/陪跑店长/陪跑店副)
    where t1.dt = '${today-1}'
    )

    --25年春节给班情况
    ,date_list as(
    select distinct
    roster_date
    ,'1' as joinkey
    from data_smartorder.dw_roster_give_roster_detail_snapshot_da t0
    where t0.roster_date between '2026-02-09' and '2026-03-08'
    and t0.dt='${today-1}'
    )

    ,staff_1_list as(
    select distinct
    staff_code
    ,staff_name
    ,city_name
    ,post_name
    ,'1' as joinkey
    from staff_list
    )

    ,date_staff_list as(
    select
    roster_date
    ,staff_code
    ,staff_name
    ,city_name
    ,post_name
    from date_list a
    left join staff_1_list b on a.joinkey = b.joinkey
    )

    ,blacklist as (
        select distinct 
        employee_no
        ,lpad(employee_no,8,'10') as staff_code
    from data_shop.pdw_idss_ipes_admin_employee_blacklist_view -- 全量黑名单表
    where dt = '${today-1}' 
        and valid_status=1 
        and start_date <= '${TODAY}'
        and end_date >= '${TODAY}'
    )

    ,vacation_list as(
    select
    lpad(staff_no,8,'10') as staff_code
    ,third_workflow_id
    ,date_add(substr(vacation_start_time,1,10),mid_date) as vacation_day
    from data_smartorder.dm_copy_pdw_opc_shop_attendance_original_vacation_view t0
    lateral view posexplode(
    split(space(datediff(substr(vacation_end_time,1,10),substr(vacation_start_time,1,10))),'')
    ) t1 as mid_date,val
    where t0.dt = '20260311'
    and create_time <= '${TODAY}'
    --and t0.reason = '春节返乡假'
    and t0.status = '2' --数据状态 0初始,1待审批,2已同意,3已拒绝,4已转交,5取消
    )

    --销假明细
    ,revoke_vacation_list as(
    select
    lpad(employee_no,8,'10') as staff_code
    ,vacation_workflow_no
    ,date_add(from_unixtime(unix_timestamp(start_time), 'yyyy-MM-dd'),mid_date) as revoke_vacation_day
    from data_smartorder.dm_copy_pdw_opc_shop_attendance_revoke_vacation_view t0
    lateral view posexplode(
    split(space(datediff(from_unixtime(unix_timestamp(end_time), 'yyyy-MM-dd'),from_unixtime(unix_timestamp(start_time), 'yyyy-MM-dd'))),'')
    ) t1 as mid_date,val
    where t0.dt = '20260311'
    and create_time <= '${TODAY}'
    and t0.workflow_status = '2' --2已同意
    )

    ,merge_vacation_list as( --最终请假日期
    select
    t1.staff_code --员工编号
    ,t1.third_workflow_id
    ,t1.vacation_day --请假日期
    ,t2.vacation_workflow_no
    ,t2.revoke_vacation_day
    from vacation_list t1
    left join revoke_vacation_list t2 on t1.third_workflow_id = t2.vacation_workflow_no and t1.staff_code = t2.staff_code and t1.vacation_day = t2.revoke_vacation_day
    where t2.vacation_workflow_no is null
    )

    --商圈对应关系
    ,district_info as(
    SELECT
    store_code
    ,district_code
    from data_build.dwd_store_construction_full_capacity_perdict
    where dt = '${today-2}'
    )

    ,give_list as(
    select 
    t0.target_date as week
    ,t0.roster_date
    ,t0.employee_id
    ,t0.employee_name
    ,t0.protect_tag
    ,t0.job
    ,t0.store_city
    ,t0.store_code
    ,t0.store_name
    ,t3.district_code
    ,case 
    when substring(t0.store_name,1,1)='区' then '机动队'
    when t0.job in('店经理','储备店经理','见习店经理') then '店长'
    when t0.job in('店副经理') then '店副'
    else '店员'
    end as position
    ,case when t5.staff_code is not null then '1' else '0' end as is_vacation
    ,case when t5.staff_code is not null then '0' else '1' end as is_effective
    ,case when t4.staff_code is not null then '1' else '0' end as black
    from data_smartorder.dw_roster_give_roster_detail_snapshot_da t0
    left join merge_vacation_list t5 on lpad(t0.employee_id,8,'10') = t5.staff_code and t0.roster_date = t5.vacation_day
    left join district_info t3 on t0.store_code=t3.store_code
    left join blacklist t4 on lpad(t0.employee_id,8,'10') = t4.staff_code
    where t0.roster_date between '2026-02-09' and '2026-03-08'
    and t0.dt='${today-1}'
    and t0.givetype<>'全天不开工'
    and t0.hps_d_hr_status='在职'
    group by
    t0.target_date
    ,t0.roster_date
    ,t0.employee_id
    ,t0.employee_name
    ,t0.protect_tag
    ,t0.job
    ,t0.store_city
    ,t0.store_code
    ,t0.store_name
    ,t3.district_code
    ,case 
    when substring(t0.store_name,1,1)='区' then '机动队'
    when t0.job in('店经理','储备店经理','见习店经理') then '店长'
    when t0.job in('店副经理') then '店副'
    else '店员'
    end
    ,case when t5.staff_code is not null then '1' else '0' end
    ,case when t5.staff_code is not null then '0' else '1' end
    ,case when t4.staff_code is not null then '1' else '0' end
    )

    select
    t0.roster_date
    ,t0.staff_code
    ,t0.staff_name
    ,t0.city_name
    ,t0.post_name
    ,t1.is_vacation
    ,t1.is_effective
    ,t1.black
    from date_staff_list t0
    left join give_list t1 on t0.roster_date = t1.roster_date and t0.staff_code = t1.employee_id
end

--data_build.dwd_work_hours_pt_di(统计学生PT+疑似学生PT的店员工时占比)
--下周学生PT工时占比
begin
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
    case when dayofweek(from_unixtime(unix_timestamp(t1.dt, 'yyyyMMdd'), 'yyyy-MM-dd')) in ('2','3') --周一周二
    then date_sub(next_day(from_unixtime(unix_timestamp(t1.dt, 'yyyyMMdd'), 'yyyy-MM-dd'),'mon'),7) --本周一
    else next_day(from_unixtime(unix_timestamp(t1.dt, 'yyyyMMdd'), 'yyyy-MM-dd'),'mon') end --下周一
    as week_date

    ,suspected_pt
    ,student_pt

    ,sum(t1.work_hours) as work_hours

    ,sum(case when (t2.student_suspect_new = '1' and t2.post_name = '店员')
    or (t2.hps_d_jobcode = '学生PT' and t2.post_name = '店员')
    or (t2.student_suspect_new = '疑似学生PT+早入职' and t2.post_name = '店员')
    or (t2.hps_d_jobcode = '学生PT+早入职' and t2.post_name = '店员') 
    then t1.work_hours else 0 end) as work_hours_pt --全部学生+意思学生

    ,sum(case when (t2.hps_d_jobcode = '学生PT' and t2.post_name = '店员')
    or (t2.hps_d_jobcode = '学生PT+早入职' and t2.post_name = '店员') 
    then t1.work_hours else 0 end) as work_hours_student_pt --全部学生

    ,sum(case when (t2.student_suspect_new = '1' and t2.post_name = '店员')
    or (t2.student_suspect_new = '疑似学生PT+早入职' and t2.post_name = '店员')
    then t1.work_hours else 0 end) as work_hours_suspected_pt --全部疑似学生

    from data_build.dw_roster_effect_roster_detail_info_da_view t1
    left join staff_list t2 on t1.employee_id = t2.staff_code
    left join (
    select distinct 
    store_code
    from data_build.pdw_bach_baseinfo_shop_shop
    where dt = '${today-1}'
    and self_take_type = '4' --加盟店
    ) t3 on t1.store_id = t3.store_code
    left join(
    select
    record_dt
    ,dt
    ,count(case when (student_suspect_new = '1' and post_name = '店员')
    or (student_suspect_new = '疑似学生PT+早入职' and post_name = '店员')
    then staff_code else null end) as suspected_PT
    ,count(case when (hps_d_jobcode = '学生PT' and post_name = '店员')
    or (hps_d_jobcode = '学生PT+早入职' and post_name = '店员') 
    then staff_code else null end) as student_PT
    from staff_list
    group by
    record_dt
    ,dt
    ) t4 on from_unixtime(unix_timestamp(t1.dt, 'yyyyMMdd'), 'yyyy-MM-dd') = date_add(from_unixtime(unix_timestamp(t4.dt, 'yyyyMMdd'), 'yyyy-MM-dd'),1)
    where t1.dt = '${today}'
    and
    case when dayofweek(from_unixtime(unix_timestamp(t1.dt, 'yyyyMMdd'), 'yyyy-MM-dd')) in ('2','3') --周一周二
    then t1.work_date between date_sub(next_day(from_unixtime(unix_timestamp(t1.dt, 'yyyyMMdd'), 'yyyy-MM-dd'),'mon'),7) and date_sub(next_day(from_unixtime(unix_timestamp(t1.dt, 'yyyyMMdd'), 'yyyy-MM-dd'),'mon'),1) --本周
    else t1.work_date between next_day(from_unixtime(unix_timestamp(t1.dt, 'yyyyMMdd'), 'yyyy-MM-dd'),'mon') and date_add(next_day(from_unixtime(unix_timestamp(t1.dt, 'yyyyMMdd'), 'yyyy-MM-dd'),'mon'),6) --下周
    end
    and (t1.class_id in ('0') or t1.attr_id = '344')
    and t1.store_type_desc = '门店'
    and t1.store_type = '0'
    and t3.store_code is null --只统计直营店
    group by
    case when dayofweek(from_unixtime(unix_timestamp(t1.dt, 'yyyyMMdd'), 'yyyy-MM-dd')) in ('2','3') --周一周二
    then date_sub(next_day(from_unixtime(unix_timestamp(t1.dt, 'yyyyMMdd'), 'yyyy-MM-dd'),'mon'),7) --本周一
    else next_day(from_unixtime(unix_timestamp(t1.dt, 'yyyyMMdd'), 'yyyy-MM-dd'),'mon') end --下周一
    ,suspected_PT
    ,student_PT
end

--2026春节人力预测
--回溯2025年排班
begin
    with base_0 as
    (
    select
    t1.roster_id
    ,t1.store_id
    ,t1.employee_id
    ,t1.work_date
    ,t1.start_time
    ,t1.end_time
    ,t1.is_night
    ,weekofyear(t1.work_date) as week_of_year
    ,year(t1.work_date) as year_of_work
    ,t2.holidays
    ,t1.dt
    ,date_sub(from_unixtime(unix_timestamp(t1.dt,'yyyyMMdd'),'yyyy-MM-dd'),1) as new_dt
    from data_build.dw_roster_effect_roster_detail_info_da_view t1
    left join (
    select
    weekofyear(date_key) as week_of_year
    ,year(date_key) as year_of_week
    ,sum(is_holiday) as holidays --当周节假日天数
    from data_build.dim_date_ya_v2
    group by
    weekofyear(date_key)
    ,year(date_key)
    ) t2 on weekofyear(t1.work_date) = t2.week_of_year and year(t1.work_date) = t2.year_of_week
    where t1.dt = '20251101'
    and t1.store_type_desc = '门店'
    and (t1.class_id in ('0') or t1.attr_id = '344') --20250702新增attr_id = '344'远程支援班次类型
    and t1.store_type = '0'
    and t1.work_date between '2025-01-13' and '2025-03-02'
    ),
    base_1 as
    (
    select
    roster_id
    ,store_id
    ,employee_id
    ,work_date
    ,start_time
    ,end_time
    ,is_night
    ,t1.week_of_year
    ,year_of_work
    ,holidays
    ,dt
    ,new_dt
    ,day_of_week_name
    from base_0 t1
    left join data_build.dim_date_ya_v2 t2
    on new_dt = t2.date_key

    ),

    base as
    (
    select
    t.roster_id
    ,t.store_id
    ,t.employee_id
    ,t.work_date
    ,t.start_time
    ,t.end_time
    ,t.is_night
    ,(t.end_time - t.start_time) as work_hours
    ,t.week_of_year
    ,t.year_of_work
    ,holidays
    ,dt
    ,new_dt
    ,day_of_week_name
    from base_1 t
    ),

    base_list as
    (
    select
    roster_id
    ,week_of_year
    ,work_date
    ,store_id
    ,employee_id
    ,work_hours
    ,start_time
    ,end_time
    ,case when start_time is null then ''
    when is_night=1 then '夜班'
    when is_night=0 then '白班'
    end as work_shift_label_1
    ,case when work_hours>=10 then '长班_10h'
    -- when work_hours>=10 then '长班_10_12h'
    when work_hours>=8 then '长班_8_10h'
    when work_hours<8 and work_hours>=4 then '短班_4-8H'
    when work_hours<4 then '短班_<4H'
    end as work_shift_label_2
    from base
    ),

    -- 单店by天班型明细
    base_final as
    (
    select
    store_id
    ,work_date
    ,employee_id
    ,work_shift_label_1
    ,work_shift_label_2
    ,week_of_year
    ,case when work_shift_label_1='白班' and work_shift_label_2='长班_10h' then '长白班'
    when work_shift_label_1='白班' and work_shift_label_2='长班_8_10h' then '中白班'
    when work_shift_label_1='白班' and work_shift_label_2='短班_4-8H' then '短白班1'
    when work_shift_label_1='白班' and work_shift_label_2='短班_<4H' then '短白班2'

    when work_shift_label_1='夜班' and work_shift_label_2='长班_10h' then '长夜班'
    when work_shift_label_1='夜班' and work_shift_label_2='长班_8_10h' then '中夜班'
    when work_shift_label_1='夜班' and work_shift_label_2='短班_4-8H' then '短夜班1'
    when work_shift_label_1='夜班' and work_shift_label_2='短班_<4H' then '短夜班2'
    else null end as label
    ,count(work_date) as workdays
    from base_list
    group by store_id
    ,work_date
    ,employee_id
    ,work_shift_label_1
    ,work_shift_label_2
    ,week_of_year
    ,case when work_shift_label_1='白班' and work_shift_label_2='长班_10h' then '长白班'
    when work_shift_label_1='白班' and work_shift_label_2='长班_8_10h' then '中白班'
    when work_shift_label_1='白班' and work_shift_label_2='短班_4-8H' then '短白班1'
    when work_shift_label_1='白班' and work_shift_label_2='短班_<4H' then '短白班2'

    when work_shift_label_1='夜班' and work_shift_label_2='长班_10h' then '长夜班'
    when work_shift_label_1='夜班' and work_shift_label_2='长班_8_10h' then '中夜班'
    when work_shift_label_1='夜班' and work_shift_label_2='短班_4-8H' then '短夜班1'
    when work_shift_label_1='夜班' and work_shift_label_2='短班_<4H' then '短夜班2'
    else null end
    ),
    final as
    (

    -- 单店by天班型分布

    select
    store_id
    ,week_of_year
    ,work_date
    ,label
    ,count(label) as label_no
    from base_final
    group by store_id
    ,week_of_year
    ,work_date
    ,label
    ),
    final_week_list as
    (
    select
    store_id
    ,week_of_year
    ,work_date
    ,label
    ,sum(label_no) as total_label_no

    from final
    group by
    store_id
    ,week_of_year
    ,work_date
    ,label
    ),

    final_label_no1 as
    (
    select
    store_id
    ,t1.week_of_year
    ,work_date
    ,max(case when label = '长白班' then total_label_no else 0 end) as total_label_ld
    ,max(case when label = '中白班' then total_label_no else 0 end) as total_label_md
    ,max(case when label = '短白班1' then total_label_no else 0 end) as total_label_sd1
    ,max(case when label = '短白班2' then total_label_no else 0 end) as total_label_sd2
    ,max(case when label = '长夜班' then total_label_no else 0 end) as total_label_ln
    ,max(case when label = '中夜班' then total_label_no else 0 end) as total_label_mn
    ,max(case when label = '短夜班1' then total_label_no else 0 end) as total_label_sn1
    ,max(case when label = '短夜班2' then total_label_no else 0 end) as total_label_sn2

    from final_week_list t1
    group by store_id
    ,t1.week_of_year
    ,work_date
    ),

    final_label_no3 as
    (
    select
    t1.store_id
    ,work_date
    ,sum(total_label_ld) as total_label_ld
    ,sum(total_label_md) as total_label_md
    ,sum(total_label_sd1) as total_label_sd1
    ,sum(total_label_sd2) as total_label_sd2
    ,sum(total_label_ln) as total_label_ln
    ,sum(total_label_mn) as total_label_mn
    ,sum(total_label_sn1) as total_label_sn1
    ,sum(total_label_sn2) as total_label_sn2
    from final_label_no1 t1
    group by t1.store_id
    ,work_date
    )

    ,dwd_store_construction_roster_store_demand_v1_di as(
    select distinct
    t1.store_id
    ,work_date
    ,t1.total_label_ld as total_label_ld
    ,t1.total_label_md as total_label_md
    ,t1.total_label_sd1 as total_label_sd1
    ,t1.total_label_sd2 as total_label_sd2
    ,t1.total_label_ln as total_label_ln
    ,t1.total_label_mn as total_label_mn
    ,t1.total_label_sn1 as total_label_sn1
    ,t1.total_label_sn2 as total_label_sn2
    from final_label_no3 t1
    )

    ,hc_raw as(
    select
    dt
    ,from_unixtime(unix_timestamp(dt,'yyyyMMdd'),'yyyy-MM-dd') as record_date
    ,store_code
    ,store_type
    ,hc_count
    ,store_epidemic_hc
    ,hc_all
    from(
    select
    dt,
    date_sub(date_add(from_unixtime(unix_timestamp(t1.dt,'yyyyMMdd'),'yyyy-MM-dd'),7 - case when dayofweek(from_unixtime(unix_timestamp(t1.dt,'yyyyMMdd'),'yyyy-MM-dd')) = 1 
    then 7 else dayofweek(from_unixtime(unix_timestamp(t1.dt,'yyyyMMdd'),'yyyy-MM-dd')) - 1 end),6) as new_dt, --取dt所在周的周一
    t1.store_code,
    t1.store_type,
    t1.start_date
    ,sum(t1.store_mgr_hc)+sum(t1.store_staff_hc) as hc_count
    ,sum(t1.store_epidemic_hc) as store_epidemic_hc
    ,sum(t1.store_mgr_hc)+sum(t1.store_staff_hc)+sum(t1.store_epidemic_hc) as hc_all
    from data_build.app_roster_report_measurement_hc_di_view t1
    where t1.dt between '20250113' and '20250302'
    group by
    dt,
    date_sub(date_add(from_unixtime(unix_timestamp(t1.dt,'yyyyMMdd'),'yyyy-MM-dd'),7 - case when dayofweek(from_unixtime(unix_timestamp(t1.dt,'yyyyMMdd'),'yyyy-MM-dd')) = 1 
    then 7 else dayofweek(from_unixtime(unix_timestamp(t1.dt,'yyyyMMdd'),'yyyy-MM-dd')) - 1 end),6),
    t1.store_code,
    t1.store_type,
    t1.start_date
    ) t1
    where datediff(start_date,new_dt) = 14
    ),

    hc_base_1 as
    (
    select
    t3.dt
    ,t3.record_date
    ,t3.store_code as store_code
    ,t3.hc_count as hc_all -- 旧版本
    ,t1.total_label_sd2  as suiban_v0
    ,t1.total_label_sd1 as duanban_v0
    ,t1.total_label_md as zhongban_v0
    ,t1.total_label_ld as changban_v0
    ,t1.total_label_sn1 as duanye_v0
    ,t1.total_label_sn1 + t1.total_label_mn + t1.total_label_ln + t1.total_label_sn2 as yeban_v0
    ,case when t1.total_label_sd2 >= 0.75 and total_label_sd1 >= 0.75 then round((3*total_label_sd2 + 6*total_label_sd1)/9,1)
    else 0 end as duan_pin_sui
    from
    hc_raw t3
    left join dwd_store_construction_roster_store_demand_v1_di t1 on t3.store_code = t1.store_id and t1.work_date = t3.record_date
    ),

    hc_base_2 as
    (
    select
    dt
    ,record_date
    ,store_code as store_code
    ,hc_all as hc_all
    ,case when duan_pin_sui >= 0.9 then if(suiban_v0 >=1,suiban_v0 -1,0)
    else suiban_v0 end as suiban_v1
    ,case when duan_pin_sui >= 0.9 then if(duanban_v0 >=1,duanban_v0 -1,0)
    else duanban_v0 end as duanban_v1
    ,case when duan_pin_sui >= 0.9 then zhongban_v0 + duan_pin_sui
    else zhongban_v0 end as zhongban_v1
    ,changban_v0 as changban_v1
    ,yeban_v0 as yeban_v1
    from hc_base_1
    ),

    hc_base_3 as
    (
    select
    dt
    ,record_date
    ,store_code as store_code
    ,hc_all as hc_all
    ,case when suiban_v1 >= 0.75 and zhongban_v1 >= 0.75 then round((3*suiban_v1 + 9*zhongban_v1)/12,1)
    else 0 end as zhong_pin_sui
    ,suiban_v1 as suiban_v1
    ,duanban_v1 as duanban_v1
    ,zhongban_v1 as zhongban_v1
    ,changban_v1 as changban_v1
    ,yeban_v1 as yeban_v1
    from hc_base_2
    ),

    hc_base_4 as
    (
    select
    dt
    ,record_date
    ,store_code as store_code
    ,hc_all as hc_all
    ,'1' as opening_days
    ,case when zhong_pin_sui >= 0.9 then if(suiban_v1 >=1,suiban_v1 -1,0)
    else suiban_v1 end as suiban_v2
    ,case when zhong_pin_sui >= 0.9 then if(zhongban_v1 >=1,zhongban_v1 -1,0)
    else zhongban_v1 end as zhongban_v2
    ,case when zhong_pin_sui >= 0.9 then changban_v1 + zhong_pin_sui
    else changban_v1 end as changban_v2
    ,duanban_v1 as duanban_v2
    ,yeban_v1 as yeban_v2
    from hc_base_3
    ),

    hc_base_5 as
    (
    select
    dt
    ,record_date
    ,store_code as store_code
    ,hc_all as hc_all
    ,opening_days as opening_days
    ,opening_days*(3*suiban_v2 + 9*zhongban_v2) as zhong_sui_time
    ,opening_days*12*changban_v2 as changban_time
    ,opening_days*6*duanban_v2 as duanban_time
    ,opening_days*12*yeban_v2 as yeban_time
    ,opening_days*6*duanban_v2 +opening_days*12*changban_v2+opening_days*(3*suiban_v2 + 9*zhongban_v2) as baiban_time
    ,if(round((duanban_v2+changban_v2+zhongban_v2)*opening_days/1,1)>=round(duanban_v2+changban_v2+zhongban_v2,1),
    round((duanban_v2+changban_v2+zhongban_v2)*opening_days/1,1),round(duanban_v2+changban_v2+zhongban_v2,1)) as day_hc_count
    ,round((opening_days*6*duanban_v2 +opening_days*12*changban_v2+opening_days*(3*suiban_v2 + 9*zhongban_v2))/12,0) as day_fulfill_count
    from hc_base_4
    )

    select
    dt
    ,record_date
    ,store_code as store_code
    , 0 as is_bonus_hc
    ,hc_all as hc_all
    ,opening_days as opening_days
    ,zhong_sui_time as zhong_sui_time
    ,changban_time as changban_time
    ,duanban_time as duanban_time
    ,yeban_time as yeban_time
    ,baiban_time as baiban_time
    ,day_hc_count as day_hc_count
    ,day_fulfill_count as day_fulfill_count
    ,case when opening_days is null then 0
    else if(day_hc_count- day_fulfill_count >=0.5 or (day_fulfill_count=2 and round(duanban_time/baiban_time,1)>=0.3),1,0) end as is_extra_hc
    ,case when opening_days is null then round(hc_all,0)
    when day_hc_count in ('1.4','1.5','1.6') then 2
    when day_hc_count in ('2.4','2.5','2.6') then 3
    when day_hc_count in ('3.4','3.5','3.6') then 4
    else if(day_hc_count- day_fulfill_count >=0.5,day_fulfill_count+1,day_fulfill_count) end as hc_day
    ,case when opening_days is null then 0
    else if(round(yeban_time/12,0)<=1,round(yeban_time/11,0),round(yeban_time/12,0)) end as hc_night
    ,case when opening_days is null then round(hc_all,0)
    else if( day_hc_count- day_fulfill_count >=0.5,day_fulfill_count+1,day_fulfill_count) +
    if(round(yeban_time/12,0)<=1,round(yeban_time/11,0),round(yeban_time/12,0)) end as hc_new
    from hc_base_5
end

--每日净增人数
begin
    --当天入职
    select
    hps_hire_dt
    ,count(emplid) as emplid_num
    from data_build.pdw_psprod_ps_blf_ehr_pers_vw_view
    where dt = 20251110
    and hps_d_jobcode in ('店经理','储备店经理','见习店经理','门店伙伴','店副经理','社会PT','学生PT','防疫伙伴')
    group by
    hps_hire_dt

    --当天离职
    select
    leave_dt
    ,count(emplid) as emplid_num
    from data_build.pdw_psprod_ps_blf_ehr_pers_vw_view
    where dt = 20251110
    and hps_d_jobcode in ('店经理','储备店经理','见习店经理','门店伙伴','店副经理','社会PT','学生PT','防疫伙伴')
    group by
    leave_dt

    --拉黑
    select
    hps_hire_dt
    ,count(case when t1.employee_no is not null and leave_dt is null then emplid else null end) as emplid_num
    from data_build.pdw_psprod_ps_blf_ehr_pers_vw_view t
    left join data_shop.pdw_idss_ipes_admin_employee_blacklist_view t1 on lpad(t.emplid,8,10) = lpad(t1.employee_no,8,10) and t.dt = t1.dt and valid_status = 1
    where t.dt = 20251110
    and hps_d_jobcode in ('店经理','储备店经理','见习店经理','门店伙伴','店副经理','社会PT','学生PT','防疫伙伴')
    group by
    hps_hire_dt
end

--每日城市门店和机动队gap
begin
    with gap_all_district as(
    select
    city_name
    ,district_code
    ,sum(gap_all_district) as gap_all_district
    from(
    select
    district_code
    ,city_name
    ,avg(gap_all_district) as gap_all_district
    from data_build.dwd_store_construction_store_groups_recruit_gap
    where dt = date_format(date_sub(current_date,1),'yyyyMMdd')
    group by
    district_code
    ,city_name
    ) a
    group by
    city_name
    ,district_code
    )
    
    ,store_num_list as(
    SELECT
    t1.district_code
    ,t2.operation_x
    ,count(1) as store_num
    from data_build.dwd_store_construction_store_groups_recruit_gap t1
    LEFT JOIN data_smartorder.ods_uploads_operation_x_business_district_qiyang t2 on t1.district_code = t2.business_district_id
    where dt = date_format(date_sub(current_date,1),'yyyyMMdd')
    GROUP BY
    t1.district_code
    ,t2.operation_x
    )
    

    select
    t1.city_name
    ,t1.district_code
    ,t3.operation_x
    ,t3.store_num
    ,t2.gap_all_district
    ,sum(gap_new) as gap_new
    from data_build.dwd_store_construction_store_groups_recruit_gap t1
    left join gap_all_district t2 on t1.city_name = t2.city_name and t1.district_code = t2.district_code
    left join store_num_list t3 on t1.district_code = t3.district_code
    where dt = date_format(date_sub(current_date,1),'yyyyMMdd')
    group by
    t1.city_name
    ,t1.district_code
    ,t3.operation_x
    ,t3.store_num
    ,t2.gap_all_district
end

--调拨表
data_smartorder.ai_roster_store_staff_transfer_analysis_di

--人维度的给班和排班情况
--保护标签表的人员准确岗位(店经理/店副/店员/机动队)
--data_build.dwd_spring_festival_2025_give_info_da
--全量有排班需求的店日清单
begin
    with staff_list as(
    select
    t1.*
    ,t2.hps_d_jobcode
    ,t2.hps_sys_name
    ,coalesce(t4.store_code,t3.dept_code) as store_code_1
    ,coalesce(t4.store_name,t3.dept_name) as store_name_1
    ,case when t3.manager_code is not null and (t2.hps_dept_descr_lv5 not like '%区X%' or t2.hps_dept_descr_lv1 not in ('运营管理部X'))
    and t2.hps_d_jobcode not in ('外部合作辅助人','外部合作经营者','外部合作伙伴','内部合作辅助人','内部合作经营者','内部合作伙伴') then '店经理'
    when t2.hps_d_jobcode = '店副经理' then '店副经理'
    when t2.hps_dept_descr_lv5 like '%区X%' or t2.hps_dept_descr_lv1 in ('运营管理部X') then '机动队'
    when t2.hps_d_jobcode not in ('外部合作辅助人','外部合作经营者','外部合作伙伴','内部合作辅助人','内部合作经营者','内部合作伙伴') then '店员'
    else '加盟人员' end as post_name
    from data_shop.dm_shop_staff_protect_tag_v2 t1
    left join data_build.pdw_psprod_ps_blf_ehr_pers_vw_view t2 on t1.staff_code = lpad(t2.emplid,8,'10') and t2.dt = '${today-1}' --hps_d_jobcode in ('店副经理')
    --left join data_build.dwd_store_construction_manager_base_info_vi_di t3 on t1.staff_code = t3.employee_id and t3.dt = '${today-2}'  --店长
    left join data_build.pdw_opc_shop_ehr_staff_dept_view t3 on t2.hps_dept_code_lv5 = t3.dept_code and lpad(t2.emplid,8,'10') = lpad(t3.manager_code,8,'10') and t3.dt = '${today-1}' --店长
    left join data_build.dwd_store_construction_district_manager_base_info0_di t4 on t1.staff_code = t4.employee_id and t4.dt = '${today-2}'  --带店机动队(店经理)
    left join (select
    * from(
    select 
    employee_no,
    shop_code,
    relation_type,
    dt,
    row_number() over(partition by employee_no order by create_time desc) as rn
    from data_smartorder.dm_copy_pdw_opc_roster_motor_shop_relation_view
    where dt ='${today-1}'
    and delete_ts = 0
    and end_date >= '${TODAY}'
    ) a
    where rn = 1
    ) t5 on t1.staff_code = lpad(t5.employee_no,8,'10') --带店机动队(店长/店副/陪跑店长/陪跑店副)
    left join data_smartorder.ods_uploads_business_district_qiyang t6 on t1.store_code = t6.store_code
    where t1.dt = '${today-1}'
    )

    select
    t1.work_date
    ,t1.store_id
    ,t1.store_name
    ,case t4.business_district_id
    when '1000'then '区X001北京' when '1001'then '区X002北京' when '1002'then '区X003北京' when '1232'then '区X004天津' when '1231'then '区X005天津'
    when '1018'then '区X006上海' when '1101'then '区X007南京' when '1094'then '区X008杭州' when '1074'then '区X009济南' when '6120'then '区X010宁波'
    when '1080'then '区X012青岛' when '10012'then '区X013北京' when '10013'then '区X014北京' when '10014'then '区X015北京' when '10015'then '区X016北京'
    when '10016'then '区X017北京' when '1230'then '区X018天津' when '1019'then '区X019上海' when '1100'then '区X020南京' when '1070'then '区X021济南'
    when '10018'then '区X024北京' when '1880'then '区X027廊坊' when '1030'then '区X028石家庄' when '1210'then '区X029郑州' when '3970'then '区X030常州'
    when '6121'then '区X031宁波' when '1110'then '区X032苏州' when '1182'then '区X033无锡' when '2330'then '区X034金华' when '2320'then '区X035温州'
    when '1003'then '区X036北京' when '1004'then '区X037北京' when '1005'then '区X038北京' when '1006'then '区X039北京' when '1007'then '区X040北京'
    when '1008'then '区X041北京' when '1009'then '区X042北京' when '10010'then '区X043北京' when '10011'then '区X044北京' when '10017'then '区X045北京'
    when '1233'then '区X046天津' when '1234'then '区X047天津' when '1235'then '区X048天津' when '1236'then '区X049天津' when '1237'then '区X050天津'
    when '1238'then '区X051天津' when '1239'then '区X052天津' when '3971'then '区X053常州' when '1093'then '区X054杭州' when '1092'then '区X055杭州'
    when '1091'then '区X056杭州' when '1090'then '区X057杭州' when '1071'then '区X058济南' when '1072'then '区X059济南' when '1073'then '区X060济南'
    when '1102'then '区X061南京' when '1103'then '区X062南京' when '1104'then '区X063南京' when '1105'then '区X064南京' when '1106'then '区X065南京'
    when '1107'then '区X066南京' when '1211'then '区X067郑州' when '1181'then '区X068无锡' when '1180'then '区X069无锡' when '1113'then '区X070苏州'
    when '1112'then '区X071苏州' when '1081'then '区X072青岛' when '1082'then '区X073青岛' when '6123'then '区X074宁波' when '6122'then '区X075宁波'
    when '1011'then '区X076上海' when '1012'then '区X077上海' when '1013'then '区X078上海' when '1014'then '区X079上海' when '1015'then '区X080上海'
    when '1016'then '区X081上海' when '1017'then '区X082上海' when '1018'then '区X083上海' else null end as business_district_id
    ,case when t5.store_code is not null then '加盟店' else '非加盟店' end as store_type
    --,case when t3.store_code is not null then '撤店' else '非撤店' end as store_type_close
    ,'非撤店' as store_type_close
    ,count(t1.roster_source) as roster_num --需有班次数
    ,count(case when t1.roster_source = '成功班表' then t1.store_id else null end) as success_roster --成功班次数
    ,count(case when t1.roster_source = '失败班表' then t1.store_id else null end) as fail_roster --失败班次数
    ,count(distinct case when t1.roster_source = '成功班表' then t1.employee_id else null end) as success_employee_num --成功班次人数
    ,count(case when t1.roster_source = '失败班表' then t1.store_id else null end) as fail_employee_num --失败班次需要人数
    ,count(distinct case when t1.nobody_hours > '0' then t1.is_night else null end) as nobody_empoyee_num --断档班次需要人数(默认白班一人，夜班一人)

    ,count(distinct case when t7.post_name in ('店经理') then t1.employee_id else null end) as manager_num
    ,count(distinct case when t7.post_name in ('店副经理') then t1.employee_id else null end) as vic_manager_num
    ,count(distinct case when t7.post_name in ('机动队') then t1.employee_id else null end) as district_num 
    ,count(distinct case when t7.post_name in ('店员') then t1.employee_id else null end) as staff_num
    ,count(distinct case when t7.post_name in ('加盟人员') then t1.employee_id else null end) as partner_num

    from data_smartorder.dw_roster_roster_detail_info_ha t1
    INNER JOIN (SELECT
    max(dt) as dt
    ,max(hr) as hr
    from data_smartorder.dw_roster_roster_detail_info_ha
    where dt < '${today}' and dt > '${today-2}') t2 on t1.dt = t2.dt and t1.hr = t2.hr
    inner join (select
    t.store_code 
    from data_build.dw_order_sku_v1 t
    where t.dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
    and t.store_type = '0'
    and t.order_status = 'FINISHED'
    and t.sku_class_code not in ('86','50')
    and t.sku_quantity > 0
    and t.order_date between '2026-01-01' and '2026-01-05'
    group by t.store_code) t6 on t1.store_id = t6.store_code --需要限定现在还在营业的门店
    left join data_build.ods_uploads_164_pipeline t3 on t1.store_id = t3.store_code
    left join data_smartorder.ods_uploads_business_district_qiyang t4 on t1.store_id = t4.store_code
    left join (
    select distinct 
    store_code
    from data_build.pdw_bach_baseinfo_shop_shop
    where dt = '${today-1}'
    and self_take_type = '4' --加盟店
    ) t5 on t1.store_id = t5.store_code
    left join staff_list t7 on t1.employee_id = t7.staff_code
    where t1.work_date between '2026-01-26' and '2026-03-15'
    and t1.store_type = 0
    and class_id = 0
    --and sale_type not in ('全天不营业')
    group by
    t1.work_date
    ,t1.store_id
    ,t1.store_name
    ,case t4.business_district_id
    when '1000'then '区X001北京' when '1001'then '区X002北京' when '1002'then '区X003北京' when '1232'then '区X004天津' when '1231'then '区X005天津'
    when '1018'then '区X006上海' when '1101'then '区X007南京' when '1094'then '区X008杭州' when '1074'then '区X009济南' when '6120'then '区X010宁波'
    when '1080'then '区X012青岛' when '10012'then '区X013北京' when '10013'then '区X014北京' when '10014'then '区X015北京' when '10015'then '区X016北京'
    when '10016'then '区X017北京' when '1230'then '区X018天津' when '1019'then '区X019上海' when '1100'then '区X020南京' when '1070'then '区X021济南'
    when '10018'then '区X024北京' when '1880'then '区X027廊坊' when '1030'then '区X028石家庄' when '1210'then '区X029郑州' when '3970'then '区X030常州'
    when '6121'then '区X031宁波' when '1110'then '区X032苏州' when '1182'then '区X033无锡' when '2330'then '区X034金华' when '2320'then '区X035温州'
    when '1003'then '区X036北京' when '1004'then '区X037北京' when '1005'then '区X038北京' when '1006'then '区X039北京' when '1007'then '区X040北京'
    when '1008'then '区X041北京' when '1009'then '区X042北京' when '10010'then '区X043北京' when '10011'then '区X044北京' when '10017'then '区X045北京'
    when '1233'then '区X046天津' when '1234'then '区X047天津' when '1235'then '区X048天津' when '1236'then '区X049天津' when '1237'then '区X050天津'
    when '1238'then '区X051天津' when '1239'then '区X052天津' when '3971'then '区X053常州' when '1093'then '区X054杭州' when '1092'then '区X055杭州'
    when '1091'then '区X056杭州' when '1090'then '区X057杭州' when '1071'then '区X058济南' when '1072'then '区X059济南' when '1073'then '区X060济南'
    when '1102'then '区X061南京' when '1103'then '区X062南京' when '1104'then '区X063南京' when '1105'then '区X064南京' when '1106'then '区X065南京'
    when '1107'then '区X066南京' when '1211'then '区X067郑州' when '1181'then '区X068无锡' when '1180'then '区X069无锡' when '1113'then '区X070苏州'
    when '1112'then '区X071苏州' when '1081'then '区X072青岛' when '1082'then '区X073青岛' when '6123'then '区X074宁波' when '6122'then '区X075宁波'
    when '1011'then '区X076上海' when '1012'then '区X077上海' when '1013'then '区X078上海' when '1014'then '区X079上海' when '1015'then '区X080上海'
    when '1016'then '区X081上海' when '1017'then '区X082上海' when '1018'then '区X083上海' else null end
    ,case when t5.store_code is not null then '加盟店' else '非加盟店' end
    --,case when t3.store_code is not null then '撤店' else '非撤店' end
    ,'非撤店'
end

--员工维度给班
begin
    with staff_list as(
    select
    t1.*
    ,t2.hps_d_jobcode
    ,t2.hps_sys_name
    ,coalesce(t4.store_code,t3.dept_code) as store_code_1
    ,coalesce(t4.store_name,t3.dept_name) as store_name_1
    ,case when t3.manager_code is not null and (t2.hps_dept_descr_lv5 not like '%区X%' or t2.hps_dept_descr_lv1 not in ('运营管理部X'))
    and t2.hps_d_jobcode not in ('外部合作辅助人','外部合作经营者','外部合作伙伴','内部合作辅助人','内部合作经营者','内部合作伙伴') then '店经理'
    when t2.hps_d_jobcode = '店副经理' then '店副经理'
    when t4.employee_id is not null and (t2.hps_dept_descr_lv5 like '%区X%' or t2.hps_dept_descr_lv1 in ('运营管理部X')) then '机动队带店店长'
    when t5.employee_no is not null and (t2.hps_dept_descr_lv5 like '%区X%' or t2.hps_dept_descr_lv1 in ('运营管理部X'))  then t5.relation_type
    when t2.hps_dept_descr_lv5 like '%区X%' or t2.hps_dept_descr_lv1 in ('运营管理部X') then '机动队队员'
    when t2.hps_d_jobcode not in ('外部合作辅助人','外部合作经营者','外部合作伙伴','内部合作辅助人','内部合作经营者','内部合作伙伴') then '店员'
    else '加盟人员' end as post_name
    from data_shop.dm_shop_staff_protect_tag_v2 t1
    left join data_build.pdw_psprod_ps_blf_ehr_pers_vw_view t2 on t1.staff_code = lpad(t2.emplid,8,'10') and t2.dt = '${today-1}' --hps_d_jobcode in ('店副经理')
    --left join data_build.dwd_store_construction_manager_base_info_vi_di t3 on t1.staff_code = t3.employee_id and t3.dt = '${today-2}'  --店长
    left join data_build.pdw_opc_shop_ehr_staff_dept_view t3 on t2.hps_dept_code_lv5 = t3.dept_code and lpad(t2.emplid,8,'10') = lpad(t3.manager_code,8,'10') and t3.dt = '${today-1}' --店长
    left join data_build.dwd_store_construction_district_manager_base_info0_di t4 on t1.staff_code = t4.employee_id and t4.dt = '${today-2}'  --带店机动队(店经理)
    left join (select
    * from(
    select 
    employee_no,
    shop_code,
    relation_type,
    dt,
    row_number() over(partition by employee_no order by create_time desc) as rn
    from data_smartorder.dm_copy_pdw_opc_roster_motor_shop_relation_view
    where dt ='${today-1}'
    and delete_ts = 0
    and end_date >= '${TODAY}'
    ) a
    where rn = 1
    ) t5 on t1.staff_code = lpad(t5.employee_no,8,'10') --带店机动队(店长/店副/陪跑店长/陪跑店副)
    left join data_smartorder.ods_uploads_business_district_qiyang t6 on t1.store_code = t6.store_code
    where t1.dt = '${today-1}'
    )

    --26年春节给班情况
    ,date_list as(
    select distinct
    roster_date
    ,'1' as joinkey
    from data_smartorder.dw_roster_give_roster_detail_snapshot_da t0
    where t0.roster_date between '2026-01-26' and '2026-03-15'
    and t0.dt='${today-1}'
    )

    ,store_list as(
    select distinct
    store_code
    ,'1' as joinkey
    from data_smartorder.dw_roster_give_roster_detail_snapshot_da t0
    where t0.roster_date between '2026-01-26' and '2026-03-15'
    and t0.dt='${today-1}'
    )

    ,date_store_list as(
    select
    roster_date
    ,store_code
    from date_list a
    left join store_list b on a.joinkey = b.joinkey
    )

    ,blacklist as (
        select distinct 
        employee_no
        ,lpad(employee_no,8,'10') as staff_code
    from data_shop.pdw_idss_ipes_admin_employee_blacklist_view -- 全量黑名单表
    where dt = '${today-1}' 
        and valid_status=1 
        and start_date <= '${TODAY}'
        and end_date >= '${TODAY}'
    )

    ,vacation_list as(
    select
    lpad(staff_no,8,'10') as staff_code
    ,third_workflow_id
    ,date_add(substr(vacation_start_time,1,10),mid_date) as vacation_day
    from data_smartorder.dm_copy_pdw_opc_shop_attendance_original_vacation_view t0
    lateral view posexplode(
    split(space(datediff(substr(vacation_end_time,1,10),substr(vacation_start_time,1,10))),'')
    ) t1 as mid_date,val
    where t0.dt = '${today-1}'
    --and t0.reason = '春节返乡假'
    and t0.status = '2' --数据状态 0初始,1待审批,2已同意,3已拒绝,4已转交,5取消
    )

    --销假明细
    ,revoke_vacation_list as(
    select
    lpad(employee_no,8,'10') as staff_code
    ,vacation_workflow_no
    ,date_add(from_unixtime(unix_timestamp(start_time), 'yyyy-MM-dd'),mid_date) as revoke_vacation_day
    from data_smartorder.dm_copy_pdw_opc_shop_attendance_revoke_vacation_view t0
    lateral view posexplode(
    split(space(datediff(from_unixtime(unix_timestamp(end_time), 'yyyy-MM-dd'),from_unixtime(unix_timestamp(start_time), 'yyyy-MM-dd'))),'')
    ) t1 as mid_date,val
    where t0.dt = '${today-1}'
    and t0.workflow_status = '2' --2已同意
    )

    ,merge_vacation_list as( --最终请假日期
    select
    t1.staff_code --员工编号
    ,t1.third_workflow_id
    ,t1.vacation_day --请假日期
    ,t2.vacation_workflow_no
    ,t2.revoke_vacation_day
    from vacation_list t1
    left join revoke_vacation_list t2 on t1.third_workflow_id = t2.vacation_workflow_no and t1.staff_code = t2.staff_code and t1.vacation_day = t2.revoke_vacation_day
    where t2.vacation_workflow_no is null
    )

    ,give_list as(
    select 
    t0.target_date as week --给班周
    ,t0.roster_date --日期
    ,t0.employee_id --员工编码
    ,t0.employee_name --员工名字
    ,t0.protect_tag --保护标签
    ,t0.store_city --城市
    ,t0.store_code --门店编码
    ,t0.store_name --门店名称
    ,t1.post_name --员工岗位
    ,t0.givetype --给班类型
    ,case
    ---完全标准班型
    when t0.start_time=6 and t0.end_time=22 then '白班'
    when t0.start_time=18 and t0.end_time=32 then '夜班'
    when t0.start_time=6 and t0.end_time=32 then '全班'
    ---重合区间区分
    when t0.start_time<=10 and t0.end_time-start_time>=21 then '全班'
    ---其他区间标签
    when t0.end_time<=24 or t0.start_time<=6 then '白班'
    when t0.end_time>24 then '夜班'
    else 0 end as label --班次白夜
    ,case
    when t0.start_time=6 and t0.end_time=32 then '全班'
    when t0.start_time<=10 and t0.end_time-t0.start_time>=21 then '全班'
    when t0.end_time-t0.start_time >= 8 then '长班'
    when t0.end_time-t0.start_time >= 4 and t0.end_time-t0.start_time < 8 then '短班1'
    when t0.end_time-t0.start_time < 4 then '短班'
    end as label_time --班次时长
    ,case when t5.staff_code is not null then '1' else '0' end as is_vacation --是否请假
    ,case when t5.staff_code is not null then '0' else '1' end as is_effective --是否有效
    ,case when t4.staff_code is not null then '1' else '0' end as black --是否黑名单
    from data_smartorder.dw_roster_give_roster_detail_snapshot_da t0
    left join merge_vacation_list t5 on lpad(t0.employee_id,8,'10') = t5.staff_code and t0.roster_date = t5.vacation_day
    left join blacklist t4 on lpad(t0.employee_id,8,'10') = t4.staff_code
    left join staff_list t1 on lpad(t0.employee_id,8,'10') = t1.staff_code  
    where t0.roster_date between '2026-01-26' and '2026-03-15'
    and t0.dt='${today-1}'
    and t0.givetype<>'全天不开工'
    and t0.hps_d_hr_status='在职'
    )

    ,roster_detail as(
    SELECT
    t1.store_id
    ,t1.work_date
    ,t1.start_time
    ,t1.end_time
    ,t1.employee_id
    ,t1.is_night
    ,t1.roster_source
    ,t1.work_hours
    ,t1.staff_name
    ,t3.post_name
    ,t1.store_name
    ,case t4.business_district_id
    when '1000'then '区X001北京' when '1001'then '区X002北京' when '1002'then '区X003北京' when '1232'then '区X004天津' when '1231'then '区X005天津'
    when '1018'then '区X006上海' when '1101'then '区X007南京' when '1094'then '区X008杭州' when '1074'then '区X009济南' when '6120'then '区X010宁波'
    when '1080'then '区X012青岛' when '10012'then '区X013北京' when '10013'then '区X014北京' when '10014'then '区X015北京' when '10015'then '区X016北京'
    when '10016'then '区X017北京' when '1230'then '区X018天津' when '1019'then '区X019上海' when '1100'then '区X020南京' when '1070'then '区X021济南'
    when '10018'then '区X024北京' when '1880'then '区X027廊坊' when '1030'then '区X028石家庄' when '1210'then '区X029郑州' when '3970'then '区X030常州'
    when '6121'then '区X031宁波' when '1110'then '区X032苏州' when '1182'then '区X033无锡' when '2330'then '区X034金华' when '2320'then '区X035温州'
    when '1003'then '区X036北京' when '1004'then '区X037北京' when '1005'then '区X038北京' when '1006'then '区X039北京' when '1007'then '区X040北京'
    when '1008'then '区X041北京' when '1009'then '区X042北京' when '10010'then '区X043北京' when '10011'then '区X044北京' when '10017'then '区X045北京'
    when '1233'then '区X046天津' when '1234'then '区X047天津' when '1235'then '区X048天津' when '1236'then '区X049天津' when '1237'then '区X050天津'
    when '1238'then '区X051天津' when '1239'then '区X052天津' when '3971'then '区X053常州' when '1093'then '区X054杭州' when '1092'then '区X055杭州'
    when '1091'then '区X056杭州' when '1090'then '区X057杭州' when '1071'then '区X058济南' when '1072'then '区X059济南' when '1073'then '区X060济南'
    when '1102'then '区X061南京' when '1103'then '区X062南京' when '1104'then '区X063南京' when '1105'then '区X064南京' when '1106'then '区X065南京'
    when '1107'then '区X066南京' when '1211'then '区X067郑州' when '1181'then '区X068无锡' when '1180'then '区X069无锡' when '1113'then '区X070苏州'
    when '1112'then '区X071苏州' when '1081'then '区X072青岛' when '1082'then '区X073青岛' when '6123'then '区X074宁波' when '6122'then '区X075宁波'
    when '1011'then '区X076上海' when '1012'then '区X077上海' when '1013'then '区X078上海' when '1014'then '区X079上海' when '1015'then '区X080上海'
    when '1016'then '区X081上海' when '1017'then '区X082上海' when '1018'then '区X083上海' else null end as business_district_id
    ,case when t5.store_code is not null then '加盟店' else '非加盟店' end as store_type
    ,t1.store_city
    ,t1.sale_type
    ,t1.nobody_hours
    ,t1.dt
    ,t1.hr
    from data_smartorder.dw_roster_roster_detail_info_ha t1
    INNER JOIN (SELECT
    max(dt) as dt
    ,max(hr) as hr
    from data_smartorder.dw_roster_roster_detail_info_ha
    where dt < '${today}' and dt > '${today-2}') t2 on t1.dt = t2.dt and t1.hr = t2.hr
    left join staff_list t3 on t1.employee_id = t3.staff_code
    left join data_smartorder.ods_uploads_business_district_qiyang t4 on t1.store_id = t4.store_code
    left join (
    select distinct 
    store_code
    from data_build.pdw_bach_baseinfo_shop_shop
    where dt = '${today-1}'
    and self_take_type = '4' --加盟店
    ) t5 on t1.store_id = t5.store_code
    where t1.work_date between '2026-01-26' and '2026-03-15'
    )
    select
    t1.*
    ,t2.start_time
    ,t2.end_time
    ,t2.store_id
    ,t2.store_name
    ,t2.store_city
    ,COALESCE(case t3.business_district_id
    when '1000'then '区X001北京' when '1001'then '区X002北京' when '1002'then '区X003北京' when '1232'then '区X004天津' when '1231'then '区X005天津'
    when '1018'then '区X006上海' when '1101'then '区X007南京' when '1094'then '区X008杭州' when '1074'then '区X009济南' when '6120'then '区X010宁波'
    when '1080'then '区X012青岛' when '10012'then '区X013北京' when '10013'then '区X014北京' when '10014'then '区X015北京' when '10015'then '区X016北京'
    when '10016'then '区X017北京' when '1230'then '区X018天津' when '1019'then '区X019上海' when '1100'then '区X020南京' when '1070'then '区X021济南'
    when '10018'then '区X024北京' when '1880'then '区X027廊坊' when '1030'then '区X028石家庄' when '1210'then '区X029郑州' when '3970'then '区X030常州'
    when '6121'then '区X031宁波' when '1110'then '区X032苏州' when '1182'then '区X033无锡' when '2330'then '区X034金华' when '2320'then '区X035温州'
    when '1003'then '区X036北京' when '1004'then '区X037北京' when '1005'then '区X038北京' when '1006'then '区X039北京' when '1007'then '区X040北京'
    when '1008'then '区X041北京' when '1009'then '区X042北京' when '10010'then '区X043北京' when '10011'then '区X044北京' when '10017'then '区X045北京'
    when '1233'then '区X046天津' when '1234'then '区X047天津' when '1235'then '区X048天津' when '1236'then '区X049天津' when '1237'then '区X050天津'
    when '1238'then '区X051天津' when '1239'then '区X052天津' when '3971'then '区X053常州' when '1093'then '区X054杭州' when '1092'then '区X055杭州'
    when '1091'then '区X056杭州' when '1090'then '区X057杭州' when '1071'then '区X058济南' when '1072'then '区X059济南' when '1073'then '区X060济南'
    when '1102'then '区X061南京' when '1103'then '区X062南京' when '1104'then '区X063南京' when '1105'then '区X064南京' when '1106'then '区X065南京'
    when '1107'then '区X066南京' when '1211'then '区X067郑州' when '1181'then '区X068无锡' when '1180'then '区X069无锡' when '1113'then '区X070苏州'
    when '1112'then '区X071苏州' when '1081'then '区X072青岛' when '1082'then '区X073青岛' when '6123'then '区X074宁波' when '6122'then '区X075宁波'
    when '1011'then '区X076上海' when '1012'then '区X077上海' when '1013'then '区X078上海' when '1014'then '区X079上海' when '1015'then '区X080上海'
    when '1016'then '区X081上海' when '1017'then '区X082上海' when '1018'then '区X083上海' else null end,t1.store_name) as business_district_id
    from give_list t1
    left join roster_detail t2 on t1.roster_date = t2.work_date and t1.employee_id = t2.employee_id
    left join data_smartorder.ods_uploads_business_district_qiyang t3 on t1.store_code = t3.store_code
end

--门店维度出勤统计
begin
    with staff_list as(
    select
    t1.*
    ,t2.hps_d_jobcode
    ,case when t3.manager_code is not null and (t2.hps_dept_descr_lv5 not like '%区X%' or t2.hps_dept_descr_lv1 not in ('运营管理部X'))
    and t2.hps_d_jobcode not in ('外部合作辅助人','外部合作经营者','外部合作伙伴','内部合作辅助人','内部合作经营者','内部合作伙伴') then '店经理'
    when t2.hps_d_jobcode = '店副经理' then '店副经理'
    when t4.employee_id is not null and (t2.hps_dept_descr_lv5 like '%区X%' or t2.hps_dept_descr_lv1 in ('运营管理部X')) then '机动队带店店长'
    when t5.employee_no is not null and (t2.hps_dept_descr_lv5 like '%区X%' or t2.hps_dept_descr_lv1 in ('运营管理部X'))  then t5.relation_type
    when t2.hps_dept_descr_lv5 like '%区X%' or t2.hps_dept_descr_lv1 in ('运营管理部X') then '机动队队员'
    when t2.hps_d_jobcode not in ('外部合作辅助人','外部合作经营者','外部合作伙伴','内部合作辅助人','内部合作经营者','内部合作伙伴') then '店员'
    else '加盟人员' end as post_name
    from data_shop.dm_shop_staff_protect_tag_v2 t1
    left join data_build.pdw_psprod_ps_blf_ehr_pers_vw_view t2 on t1.staff_code = lpad(t2.emplid,8,'10') and t2.dt = '${today-1}' --hps_d_jobcode in ('店副经理')
    --left join data_build.dwd_store_construction_manager_base_info_vi_di t3 on t1.staff_code = t3.employee_id and t3.dt = '${today-2}'  --店长
    left join data_build.pdw_opc_shop_ehr_staff_dept_view t3 on t2.hps_dept_code_lv5 = t3.dept_code and lpad(t2.emplid,8,'10') = lpad(t3.manager_code,8,'10') and t3.dt = '${today-1}' --店长
    left join data_build.dwd_store_construction_district_manager_base_info0_di t4 on t1.staff_code = t4.employee_id and t4.dt = '${today-2}'  --带店机动队(店经理)
    left join (select
    * from(
    select 
    employee_no,
    shop_code,
    relation_type,
    dt,
    row_number() over(partition by employee_no order by create_time desc) as rn
    from data_smartorder.dm_copy_pdw_opc_roster_motor_shop_relation_view
    where dt ='${today-1}'
    and delete_ts = 0
    and end_date >= '${TODAY}'
    ) a
    where rn = 1
    ) t5 on t1.staff_code = lpad(t5.employee_no,8,'10') --带店机动队(店长/店副/陪跑店长/陪跑店副)
    where t1.dt = '${today-1}'
    )

    ,roster_detail_list as(
    select
    t1.work_date
    ,t1.store_id
    ,t1.store_name
    ,case t4.business_district_id
    when '1000'then '区X001北京' when '1001'then '区X002北京' when '1002'then '区X003北京' when '1232'then '区X004天津' when '1231'then '区X005天津'
    when '1018'then '区X006上海' when '1101'then '区X007南京' when '1094'then '区X008杭州' when '1074'then '区X009济南' when '6120'then '区X010宁波'
    when '1080'then '区X012青岛' when '10012'then '区X013北京' when '10013'then '区X014北京' when '10014'then '区X015北京' when '10015'then '区X016北京'
    when '10016'then '区X017北京' when '1230'then '区X018天津' when '1019'then '区X019上海' when '1100'then '区X020南京' when '1070'then '区X021济南'
    when '10018'then '区X024北京' when '1880'then '区X027廊坊' when '1030'then '区X028石家庄' when '1210'then '区X029郑州' when '3970'then '区X030常州'
    when '6121'then '区X031宁波' when '1110'then '区X032苏州' when '1182'then '区X033无锡' when '2330'then '区X034金华' when '2320'then '区X035温州'
    when '1003'then '区X036北京' when '1004'then '区X037北京' when '1005'then '区X038北京' when '1006'then '区X039北京' when '1007'then '区X040北京'
    when '1008'then '区X041北京' when '1009'then '区X042北京' when '10010'then '区X043北京' when '10011'then '区X044北京' when '10017'then '区X045北京'
    when '1233'then '区X046天津' when '1234'then '区X047天津' when '1235'then '区X048天津' when '1236'then '区X049天津' when '1237'then '区X050天津'
    when '1238'then '区X051天津' when '1239'then '区X052天津' when '3971'then '区X053常州' when '1093'then '区X054杭州' when '1092'then '区X055杭州'
    when '1091'then '区X056杭州' when '1090'then '区X057杭州' when '1071'then '区X058济南' when '1072'then '区X059济南' when '1073'then '区X060济南'
    when '1102'then '区X061南京' when '1103'then '区X062南京' when '1104'then '区X063南京' when '1105'then '区X064南京' when '1106'then '区X065南京'
    when '1107'then '区X066南京' when '1211'then '区X067郑州' when '1181'then '区X068无锡' when '1180'then '区X069无锡' when '1113'then '区X070苏州'
    when '1112'then '区X071苏州' when '1081'then '区X072青岛' when '1082'then '区X073青岛' when '6123'then '区X074宁波' when '6122'then '区X075宁波'
    when '1011'then '区X076上海' when '1012'then '区X077上海' when '1013'then '区X078上海' when '1014'then '区X079上海' when '1015'then '区X080上海'
    when '1016'then '区X081上海' when '1017'then '区X082上海' when '1018'then '区X083上海' else null end as business_district_id
    ,case when t5.store_code is not null then '加盟店' else '非加盟店' end as store_type
    ,'非撤店' as store_type_close
    ,t1.employee_id
    ,COALESCE(t6.post_name,'机动队队员') as post_name
    from data_smartorder.dw_roster_roster_detail_info_ha t1
    INNER JOIN (SELECT
    max(dt) as dt
    ,max(hr) as hr
    from data_smartorder.dw_roster_roster_detail_info_ha
    where dt < '${today}' and dt > '${today-2}') t2 on t1.dt = t2.dt and t1.hr = t2.hr
    inner join (select
    t.store_code 
    from data_build.dw_order_sku_v1 t
    where t.dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
    and t.store_type = '0'
    and t.order_status = 'FINISHED'
    and t.sku_class_code not in ('86','50')
    and t.sku_quantity > 0
    and t.order_date between '2026-01-01' and '2026-01-05'
    group by t.store_code) t7 on t1.store_id = t7.store_code --需要限定现在还在营业的门店
    left join data_build.ods_uploads_164_pipeline t3 on t1.store_id = t3.store_code
    left join data_smartorder.ods_uploads_business_district_qiyang t4 on t1.store_id = t4.store_code
    left join (
    select distinct 
    store_code
    from data_build.pdw_bach_baseinfo_shop_shop
    where dt = '${today-1}'
    and self_take_type = '4' --加盟店
    ) t5 on t1.store_id = t5.store_code
    left join staff_list t6 on t1.employee_id = t6.staff_code
    where t1.work_date between '2026-02-08' and '2026-03-03'
    and t1.store_type = 0
    )

    select
    store_id
    ,store_name
    ,store_type
    ,store_type_close
    ,count(distinct work_date) as work_date_num
    ,count(case when post_name in ('店经理','店副经理') then work_date else null end) as store_withoutstaff_count
    ,count(case when post_name in ('店员') then work_date else null end) as store_staff_count
    ,count(case when post_name in ('机动队带店店长','VICE_MANAGER','ASSIST_VICE_MANAGER','机动队队员','SHOP_MANAGER','ASSIST_MANAGER') then work_date else null end) as district_count
    ,count(case when post_name in ('加盟人员') then work_date else null end) as join_count
    from roster_detail_list
    group by
    store_id
    ,store_name
    ,store_type
    ,store_type_close
end

--班次拒绝明细
begin
    SELECT
    t1.dt
    ,sum(t1.gap_new) as gap_new
    from data_build.dwd_store_construction_full_capacity_perdict t1
    join data_build.dwd_store_construction_store_groups_recruit_gap t2
    on t1.store_code = t2.store_code and t2.dt = 20260106
    where t1.dt > 20260105
    GROUP BY
    t1.dt

    --拒绝班次
    select * from data_smartorder.dm_copy_pdw_opc_roster_plan_shift_confirm_history_view t where dt='${DATE}'
    and confirm_status in (5,6) )a
    --班次核实结果记录表
    data_smartorder.dm_copy_pdw_opc_roster_plan_shift_affirm_history_view
end

--春节奖金人员清单
begin
    select
    t1.staff_code
    ,t1.staff_name
    ,t1.city_name
    ,t1.protect_tag
    ,t1.protect_tag_detail
    ,t2.hps_d_jobcode
    ,t2.hps_sys_name
    ,t2.hps_dept_code_lv5
    ,t2.hps_dept_descr_lv5
    ,case when t3.manager_code is not null and(t2.hps_dept_descr_lv5 not like '%区X%' or t2.hps_dept_descr_lv1 not in ('运营管理部X'))
    and t2.hps_d_jobcode not in ('外部合作辅助人','外部合作经营者','外部合作伙伴','内部合作辅助人','内部合作经营者','内部合作伙伴') then '店经理'
    when t2.hps_d_jobcode = '店副经理' then '店副经理'
    when t2.hps_dept_descr_lv5 like '%区X%' or t2.hps_dept_descr_lv1 in ('运营管理部X') then '机动队'
    when t2.hps_d_jobcode not in ('外部合作辅助人','外部合作经营者','外部合作伙伴','内部合作辅助人','内部合作经营者','内部合作伙伴')then'店员'
    else '加盟人员' end as post_name
    ,case when t6.business_district_id is null then t2.hps_dept_descr_lv5 else 
    case t6.business_district_id
    when '1000'then '区X001北京' when '1001'then '区X002北京' when '1002'then '区X003北京' when '1232'then '区X004天津' when '1231'then '区X005天津'
    when '1018'then '区X006上海' when '1101'then '区X007南京' when '1094'then '区X008杭州' when '1074'then '区X009济南' when '6120'then '区X010宁波'
    when '1080'then '区X012青岛' when '10012'then '区X013北京' when '10013'then '区X014北京' when '10014'then '区X015北京' when '10015'then '区X016北京'
    when '10016'then '区X017北京' when '1230'then '区X018天津' when '1019'then '区X019上海' when '1100'then '区X020南京' when '1070'then '区X021济南'
    when '10018'then '区X024北京' when '1880'then '区X027廊坊' when '1030'then '区X028石家庄' when '1210'then '区X029郑州' when '3970'then '区X030常州'
    when '6121'then '区X031宁波' when '1110'then '区X032苏州' when '1182'then '区X033无锡' when '2330'then '区X034金华' when '2320'then '区X035温州'
    when '1003'then '区X036北京' when '1004'then '区X037北京' when '1005'then '区X038北京' when '1006'then '区X039北京' when '1007'then '区X040北京'
    when '1008'then '区X041北京' when '1009'then '区X042北京' when '10010'then '区X043北京' when '10011'then '区X044北京' when '10017'then '区X045北京'
    when '1233'then '区X046天津' when '1234'then '区X047天津' when '1235'then '区X048天津' when '1236'then '区X049天津' when '1237'then '区X050天津'
    when '1238'then '区X051天津' when '1239'then '区X052天津' when '3971'then '区X053常州' when '1093'then '区X054杭州' when '1092'then '区X055杭州'
    when '1091'then '区X056杭州' when '1090'then '区X057杭州' when '1071'then '区X058济南' when '1072'then '区X059济南' when '1073'then '区X060济南'
    when '1102'then '区X061南京' when '1103'then '区X062南京' when '1104'then '区X063南京' when '1105'then '区X064南京' when '1106'then '区X065南京'
    when '1107'then '区X066南京' when '1211'then '区X067郑州' when '1181'then '区X068无锡' when '1180'then '区X069无锡' when '1113'then '区X070苏州'
    when '1112'then '区X071苏州' when '1081'then '区X072青岛' when '1082'then '区X073青岛' when '6123'then '区X074宁波' when '6122'then '区X075宁波'
    when '1011'then '区X076上海' when '1012'then '区X077上海' when '1013'then '区X078上海' when '1014'then '区X079上海' when '1015'then '区X080上海'
    when '1016'then '区X081上海' when '1017'then '区X082上海' when '1018'then '区X083上海' else null end
    end as business_district
    from data_shop.dm_shop_staff_protect_tag_v2 t1
    left join data_build.pdw_psprod_ps_blf_ehr_pers_vw_view t2 on t1.staff_code=lpad(t2.emplid,8,'10') and t2.dt='${today-1}'--hps_d_jobcodein('店副经理')
    --leftjoindata_build.dwd_store_construction_manager_base_info_vi_dit3ont1.staff_code=t3.employee_idandt3.dt='${today-2}'--店长
    left join data_build.pdw_opc_shop_ehr_staff_dept_view t3 on t2.hps_dept_code_lv5 = t3.dept_code and lpad(t2.emplid,8,'10')=lpad(t3.manager_code,8,'10') and t3.dt='${today-1}'--店长
    left join data_build.dwd_store_construction_district_manager_base_info0_di t4 on t1.staff_code=t4.employee_id and t4.dt='${today-2}'--带店机动队(店经理)
    left join(select
    * from(
    select
    employee_no,
    shop_code,
    relation_type,
    dt,
    row_number() over(partition by employee_no order by create_time desc) as rn
    from data_smartorder.dm_copy_pdw_opc_roster_motor_shop_relation_view
    where dt ='${today-1}'
    and delete_ts=0
    and end_date>='${TODAY}'
    ) a
    where rn=1
    ) t5 on t1.staff_code=lpad(t5.employee_no,8,'10')--带店机动队(店长/店副/陪跑店长/陪跑店副)
    left join data_smartorder.ods_uploads_business_district_qiyang t6 on t2.hps_dept_code_lv5 = t6.store_code
    where t1.dt='${today-1}'
end

--拒绝班次明细
begin
    select
    t1.work_date
    ,t1.store_id
    ,t1.store_name
    ,case t4.business_district_id
    when '1000'then '区X001北京' when '1001'then '区X002北京' when '1002'then '区X003北京' when '1232'then '区X004天津' when '1231'then '区X005天津'
    when '1018'then '区X006上海' when '1101'then '区X007南京' when '1094'then '区X008杭州' when '1074'then '区X009济南' when '6120'then '区X010宁波'
    when '1080'then '区X012青岛' when '10012'then '区X013北京' when '10013'then '区X014北京' when '10014'then '区X015北京' when '10015'then '区X016北京'
    when '10016'then '区X017北京' when '1230'then '区X018天津' when '1019'then '区X019上海' when '1100'then '区X020南京' when '1070'then '区X021济南'
    when '10018'then '区X024北京' when '1880'then '区X027廊坊' when '1030'then '区X028石家庄' when '1210'then '区X029郑州' when '3970'then '区X030常州'
    when '6121'then '区X031宁波' when '1110'then '区X032苏州' when '1182'then '区X033无锡' when '2330'then '区X034金华' when '2320'then '区X035温州'
    when '1003'then '区X036北京' when '1004'then '区X037北京' when '1005'then '区X038北京' when '1006'then '区X039北京' when '1007'then '区X040北京'
    when '1008'then '区X041北京' when '1009'then '区X042北京' when '10010'then '区X043北京' when '10011'then '区X044北京' when '10017'then '区X045北京'
    when '1233'then '区X046天津' when '1234'then '区X047天津' when '1235'then '区X048天津' when '1236'then '区X049天津' when '1237'then '区X050天津'
    when '1238'then '区X051天津' when '1239'then '区X052天津' when '3971'then '区X053常州' when '1093'then '区X054杭州' when '1092'then '区X055杭州'
    when '1091'then '区X056杭州' when '1090'then '区X057杭州' when '1071'then '区X058济南' when '1072'then '区X059济南' when '1073'then '区X060济南'
    when '1102'then '区X061南京' when '1103'then '区X062南京' when '1104'then '区X063南京' when '1105'then '区X064南京' when '1106'then '区X065南京'
    when '1107'then '区X066南京' when '1211'then '区X067郑州' when '1181'then '区X068无锡' when '1180'then '区X069无锡' when '1113'then '区X070苏州'
    when '1112'then '区X071苏州' when '1081'then '区X072青岛' when '1082'then '区X073青岛' when '6123'then '区X074宁波' when '6122'then '区X075宁波'
    when '1011'then '区X076上海' when '1012'then '区X077上海' when '1013'then '区X078上海' when '1014'then '区X079上海' when '1015'then '区X080上海'
    when '1016'then '区X081上海' when '1017'then '区X082上海' when '1018'then '区X083上海' else null end as business_district_id

    ,case when t5.store_code is not null then '加盟店' else '非加盟店' end as store_type

    ,t7.affirm_result
    from data_smartorder.dw_roster_roster_detail_info_ha t1
    INNER JOIN (SELECT
    max(dt) as dt
    ,max(hr) as hr
    from data_smartorder.dw_roster_roster_detail_info_ha
    where dt < '${today}' and dt > '${today-2}') t2 on t1.dt = t2.dt and t1.hr = t2.hr
    inner join (select
    t.store_code 
    from data_build.dw_order_sku_v1 t
    where t.dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
    and t.store_type = '0'
    and t.order_status = 'FINISHED'
    and t.sku_class_code not in ('86','50')
    and t.sku_quantity > 0
    and t.order_date between '2026-01-01' and '2026-01-05'
    group by t.store_code) t6 on t1.store_id = t6.store_code --需要限定现在还在营业的门店
    left join data_build.ods_uploads_164_pipeline t3 on t1.store_id = t3.store_code
    left join data_smartorder.ods_uploads_business_district_qiyang t4 on t1.store_id = t4.store_code
    left join (
    select distinct 
    store_code
    from data_build.pdw_bach_baseinfo_shop_shop
    where dt = '${today-1}'
    and self_take_type = '4' --加盟店
    ) t5 on t1.store_id = t5.store_code
    left join data_smartorder.dm_copy_pdw_opc_roster_plan_shift_affirm_history_view t7 on t1.roster_id = t7.shift_id and t7.dt = '${today-1}'
    where t1.work_date between '2026-02-02' and '2026-03-08'
    and t1.store_type = 0
    and class_id = 0
    --and sale_type not in ('全天不营业')
end

--门店T值相关
begin
    --月均T值
    select 
    trunc(alarm_start_date,'MM') as record_month
    ,shop_id
    ,avg(substr(t1.final_level_modify,2,1)) AS `当月T值`
    ,avg(t1.unaotu_level) AS `非机器人T`
    ,avg(t1.aotu_level) AS `机器人T`
    ,avg(t1.ddjt_level) AS `定点截图T`
    ,avg(t1.xcjc_level) AS `现场T`
    from data_gis_h3.dwd_ic_new_import_store_level_da_view t1
    where dt = 20260120
    and alarm_start_date >= '2025-03-10' --alarmstartdate来限制日期
    group by
    trunc(alarm_start_date,'MM')
    ,shop_id

    --当月现场检查的T值平均分
    select
    trunc(check_date,'MM') as record_month
    ,store_code
    ,count(1) as check_num
    ,avg(xcjc_level) as xcjc_level
    from (
    select
    t.store_code
    ,t.check_date
    ,t1.xcjc_level
    from data_build.ods_uploads_check_xcjc t
    left join data_gis_h3.dwd_ic_new_import_store_level_da_view t1 on t.store_code = t1.shop_id and t.check_date = t1.alarm_start_date and t1.dt = 20260124
    ) a
    group by
    trunc(check_date,'MM')
    ,store_code
end

--炒菜锅数据
begin
    select
    trunc(order_date,'MM') as month
    ,store_code
    ,store_name
    ,count(distinct order_date) as date_num

    --订单量
    ,count(distinct order_no)/count(distinct order_date) as order_cnt --全部订单量

    --折后销售额 按照到店/外卖拆分
    ,sum(payable_price)/count(distinct order_date) as payable_price --全部销售额

    --折后销售额 按照商品拆分
    ,sum(case when sku_class_code in ('03','05','06') and sku_division_code in ('0301','0304') then payable_price else 0 end)/count(distinct order_date) as payable_price_hotmeal --日配热餐米饭 销售额
    ,sum(case when pay_type in ('CASH') and sku_class_code in ('03','05','06') and sku_division_code in ('0301','0304')
    then payable_price else 0 end)/count(distinct order_date) as payable_price_takeaway --日配热餐米饭外卖销售额
    ,sum(case when pay_type not in ('CASH') and sku_class_code in ('03','05','06') and sku_division_code in ('0301','0304')
    then payable_price else 0 end)/count(distinct order_date) as payable_price_instore --日配热餐米饭到店销售额

    from data_build.dw_order_sku_promotion_v1
    where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
    and order_date between '2025-09-01' and '2026-01-31'
    and store_type = '0'
    and pay_status = 'PAY_SUCCESS'
    and store_code in ('100019002','100025002')
    and sku_class_code not in ('50','86')
    group by
    trunc(order_date,'MM')
    ,store_code
    ,store_name
end

--分品类销售明细
begin
    select
    trunc(t.order_date,'MM') as record_month
    ,t.store_code
    ,t.store_name

    --单量
    ,count(distinct order_no)/count(distinct order_date) as order_num

    --营业日
    ,count(distinct order_date) as sale_days

    --折后销售额
    ,sum(payable_price)/count(distinct order_date) as payable_price --全部销售额

    --折后销售额 按照商品拆分
    ,sum(case when sku_division_code in ('6101','6102') then payable_price else 0 end)/count(distinct order_date) as payable_price_cigarette --香烟销售额
    ,sum(case when sku_class_code in ('01','02','04','08','10','11','13') then payable_price else 0 end)/count(distinct order_date) as payable_price_fresh --风幕日配短保 销售额
    ,sum(case when sku_class_code in ('21') then payable_price else 0 end)/count(distinct order_date) as payable_price_bread --常温日配短保 销售额（面包）
    ,sum(case when sku_class_code in ('12') then payable_price else 0 end)/count(distinct order_date) as payable_price_milk --风幕12乳饮 销售额
    ,sum(case when sku_class_code in ('03','05','06') and sku_division_code in ('0301','0304') then payable_price else 0 end)/count(distinct order_date) as payable_price_hotmeal --日配热餐米饭 销售额
    ,sum(case when sku_class_code in ('03','05','06') and sku_division_code not in ('0301','0304') then payable_price else 0 end)/count(distinct order_date) as payable_price_ff --日配制作类销售额
    ,sum(case when sku_class_code in ('07') then payable_price else 0 end)/count(distinct order_date) as payable_price_coffee --咖啡豆浆自助饮品销售额
    ,sum(case when sku_class_code in ('30','31','32','33','42') then payable_price else 0 end)/count(distinct order_date) as payable_price_drinks --水饮销售额（白酒洋酒饮料冰淇淋等)
    ,sum(case when sku_class_code in ('34','35','36','37','38','40','41') then payable_price else 0 end)/count(distinct order_date) as payable_price_snack --非日配食品销售额（薯片饼干香肠泡面糖巧等）
    
    from 
    data_build.dw_order_sku_promotion_v1 t --订单明细表
    --data_or.dm_copy_dw_order_sku_promotion_v1_view t
    where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
    and store_type = '0'
    and pay_status = 'PAY_SUCCESS'
    and store_code = '100001503'
    and t.sku_class_code not in ('86','50')
    and order_date between '2024-01-01' and '2026-01-31'
    and order_business_type in ('TAKEAWAY','FRESH','FLASH','FLASHFRESHMERGE','TAKEAWAYV5') --外卖
    group by
    trunc(t.order_date,'MM')
    ,t.store_code
    ,t.store_name
end

--夜间销售占比
begin
    select
    trunc(t.order_date,'MM') as record_month
    ,t.store_code
    ,t.store_name

    ,count(distinct order_date) as date_num

    ,sum(payable_price)/count(distinct order_date) as payable_price --全部销售额

    --折后销售额 按照时段拆分
    ,sum(case when hour(order_time) between 18 and 23 then payable_price else 0 end)/count(distinct order_date) as payable_price_18_23 --18:00~23:00销售额
    
    from data_build.dw_order_sku_promotion_v1 t --订单明细表
    where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
    --and order_date between '2017-08-01' and '2023-06-26'
    and store_code = '101000079' --门店编码
    and store_type = '0'
    and pay_status = 'PAY_SUCCESS'
    and sku_class_code not in ('86','50')
    group by 
    trunc(t.order_date,'MM')
    ,t.store_code
    ,t.store_name
end

--员工明细
select
    t1.*
    ,case when t4.staff_code is null then null else 1 end as is_leaving
    ,case when t3.manager_code is not null and (t2.hps_dept_descr_lv5 not like '%区X%' or t2.hps_dept_descr_lv1 not in ('运营管理部X'))
    and t2.hps_d_jobcode not in ('外部合作辅助人','外部合作经营者','外部合作伙伴','内部合作辅助人','内部合作经营者','内部合作伙伴') then '店经理'
    when t2.hps_d_jobcode = '店副经理' then '店副经理'
    when t2.hps_dept_descr_lv5 like '%区X%' or t2.hps_dept_descr_lv1 in ('运营管理部X') then '机动队'
    when t2.hps_d_jobcode not in ('外部合作辅助人','外部合作经营者','外部合作伙伴','内部合作辅助人','内部合作经营者','内部合作伙伴') then '店员'
    else '加盟人员' end as post_name
    ,case when t6.staff_code is null then '0' else '黑名单' end as is_black
    ,case when t5.business_district_id is null then t1.store_name else t5.business_district_id end as district_code
    ,t7.operation_x
    ,case when t8.staff_code is null then 0 else 1 end as is_replce
    from data_shop.dm_shop_staff_protect_tag_v2 t1
    left join data_build.pdw_psprod_ps_blf_ehr_pers_vw_view t2 on t1.staff_code = lpad(t2.emplid,8,'10') and t2.dt = t1.dt --hps_d_jobcode in ('店副经理')
    left join data_build.pdw_opc_shop_ehr_staff_dept_view t3 on t2.hps_dept_code_lv5 = t3.dept_code and lpad(t2.emplid,8,'10') = lpad(t3.manager_code,8,'10') and t3.dt = t1.dt --店长
    left join (
        select distinct
        t1.man_code as user_job_number
        ,lpad(t1.man_code,8,10) as staff_code
        ,t1.order_status
        ,date_format(create_time,'yyyy-MM-dd') as create_date
        ,date_format(final_leave_date,'yyyy-MM-dd') as leave_date
        ,'1' as is_leaving
    from data_shop.pdw_gis_workday_dimission_order_view t1
    where t1.dt = date_format(date_sub(current_date,1),'yyyyMMdd')
        and (t1.order_status = 'PROCESSING')
            or (date_format(final_leave_date,'yyyyMMdd') > t1.dt and final_leave = 'noleave' and t1.order_status = 'FINISHED')
    ) t4 on t1.staff_code = t4.staff_code
    left join data_smartorder.ods_uploads_business_district_qiyang t5 on t1.store_code = t5.store_code
    left join (
        select distinct 
        employee_no
        ,lpad(employee_no,8,'10') as staff_code
    from data_shop.pdw_idss_ipes_admin_employee_blacklist_view -- 全量黑名单表
    where dt = '${today-1}' 
        and valid_status=1 
        and start_date <= '${TODAY}'
        and end_date >= '${TODAY}'
    ) t6 on t1.staff_code = t6.staff_code
    left join data_smartorder.ods_uploads_operation_x_business_district_qiyang t7 
    on case when t5.business_district_id is null then t1.store_name else t5.business_district_id end = t7.business_district_id
    left join (select distinct
    staff_code
    from data_shop.dwd_manager_transfer_blacklist_v1_di
    where dt = '${today-2}') t8 on t1.staff_code = t8.staff_code
    where t1.dt = '${today-1}'

--员工历史岗位
select
    t1.*
    ,from_unixtime(unix_timestamp(t1.dt,'yyyymmdd'),'yyyy-mm-dd') as record_date
    ,case when t4.staff_code is null then null else 1 end as is_leaving
    ,case when t3.manager_code is not null and (t2.hps_dept_descr_lv5 not like '%区X%' or t2.hps_dept_descr_lv1 not in ('运营管理部X'))
    and t2.hps_d_jobcode not in ('外部合作辅助人','外部合作经营者','外部合作伙伴','内部合作辅助人','内部合作经营者','内部合作伙伴') then '店经理'
    when t2.hps_d_jobcode = '店副经理' then '店副经理'
    when t2.hps_dept_descr_lv5 like '%区X%' or t2.hps_dept_descr_lv1 in ('运营管理部X') then '机动队'
    when t2.hps_d_jobcode not in ('外部合作辅助人','外部合作经营者','外部合作伙伴','内部合作辅助人','内部合作经营者','内部合作伙伴') then '店员'
    else '加盟人员' end as post_name
    ,case when t6.staff_code is null then '0' else '黑名单' end as is_black
    ,case when t5.business_district_id is null then t1.store_name else t5.business_district_id end as district_code
    ,t7.operation_x
    ,case when t8.staff_code is null then 0 else 1 end as is_replce
    from data_shop.dm_shop_staff_protect_tag_v2 t1
    left join data_build.pdw_psprod_ps_blf_ehr_pers_vw_view t2 on t1.staff_code = lpad(t2.emplid,8,'10') and t2.dt = t1.dt --hps_d_jobcode in ('店副经理')
    left join data_build.pdw_opc_shop_ehr_staff_dept_view t3 on t2.hps_dept_code_lv5 = t3.dept_code and lpad(t2.emplid,8,'10') = lpad(t3.manager_code,8,'10') and t3.dt = t1.dt --店长
    left join (
        select distinct
        dt
        ,t1.man_code as user_job_number
        ,lpad(t1.man_code,8,10) as staff_code
        ,t1.order_status
        ,date_format(create_time,'yyyy-MM-dd') as create_date
        ,date_format(final_leave_date,'yyyy-MM-dd') as leave_date
        ,'1' as is_leaving
    from data_shop.pdw_gis_workday_dimission_order_view t1
    where t1.dt >= '${today}'
        and (t1.order_status = 'PROCESSING')
            or (date_format(final_leave_date,'yyyyMMdd') > t1.dt and final_leave = 'noleave' and t1.order_status = 'FINISHED')
    ) t4 on t1.staff_code = t4.staff_code and t1.dt = t4.dt
    left join data_smartorder.ods_uploads_business_district_qiyang t5 on t1.store_code = t5.store_code
    left join (
        select distinct
        dt 
        ,employee_no
        ,lpad(employee_no,8,'10') as staff_code
    from data_shop.pdw_idss_ipes_admin_employee_blacklist_view -- 全量黑名单表
    where dt >= '${today}' 
        and valid_status=1 
        and start_date <= from_unixtime(unix_timestamp(dt,'yyyymmdd'),'yyyy-mm-dd')
        and end_date >= from_unixtime(unix_timestamp(dt,'yyyymmdd'),'yyyy-mm-dd')
    ) t6 on t1.staff_code = t6.staff_code and t1.dt = t6.dt
    left join data_smartorder.ods_uploads_operation_x_business_district_qiyang t7 
    on case when t5.business_district_id is null then t1.store_name else t5.business_district_id end = t7.business_district_id
    left join (select distinct
    dt
    ,staff_code
    from data_shop.dwd_manager_transfer_blacklist_v1_di
    where dt >= '${today}') t8 on t1.staff_code = t8.staff_code and t1.dt = t8.dt
    where t1.dt >= '${today}'


--计算机动队广义使用率
-- 如果计算口径变了以下地址也需要修改 https://dmp.corp.bianlifeng.com/dmp/web/DataOutputManagement/Project/Job/Detail?p_id=436&id=2245&p_name=%E6%8E%92%E7%8F%AD%20admin%20%E6%95%B0%E6%8D%AE%E5%AF%BC%E5%85%A5
begin
    with raw_list as(
    select a.*,
    case b.business_district_id
    when '1000'then '区X001北京' when '1001'then '区X002北京' when '1002'then '区X003北京' when '1232'then '区X004天津' when '1231'then '区X005天津'
    when '1018'then '区X006上海' when '1101'then '区X007南京' when '1094'then '区X008杭州' when '1074'then '区X009济南' when '6120'then '区X010宁波'
    when '1080'then '区X012青岛' when '10012'then '区X013北京' when '10013'then '区X014北京' when '10014'then '区X015北京' when '10015'then '区X016北京'
    when '10016'then '区X017北京' when '1230'then '区X018天津' when '1019'then '区X019上海' when '1100'then '区X020南京' when '1070'then '区X021济南'
    when '10018'then '区X024北京' when '1880'then '区X027廊坊' when '1030'then '区X028石家庄' when '1210'then '区X029郑州' when '3970'then '区X030常州'
    when '6121'then '区X031宁波' when '1110'then '区X032苏州' when '1182'then '区X033无锡' when '2330'then '区X034金华' when '2320'then '区X035温州'
    when '1003'then '区X036北京' when '1004'then '区X037北京' when '1005'then '区X038北京' when '1006'then '区X039北京' when '1007'then '区X040北京'
    when '1008'then '区X041北京' when '1009'then '区X042北京' when '10010'then '区X043北京' when '10011'then '区X044北京' when '10017'then '区X045北京'
    when '1233'then '区X046天津' when '1234'then '区X047天津' when '1235'then '区X048天津' when '1236'then '区X049天津' when '1237'then '区X050天津'
    when '1238'then '区X051天津' when '1239'then '区X052天津' when '3971'then '区X053常州' when '1093'then '区X054杭州' when '1092'then '区X055杭州'
    when '1091'then '区X056杭州' when '1090'then '区X057杭州' when '1071'then '区X058济南' when '1072'then '区X059济南' when '1073'then '区X060济南'
    when '1102'then '区X061南京' when '1103'then '区X062南京' when '1104'then '区X063南京' when '1105'then '区X064南京' when '1106'then '区X065南京'
    when '1107'then '区X066南京' when '1211'then '区X067郑州' when '1181'then '区X068无锡' when '1180'then '区X069无锡' when '1113'then '区X070苏州'
    when '1112'then '区X071苏州' when '1081'then '区X072青岛' when '1082'then '区X073青岛' when '6123'then '区X074宁波' when '6122'then '区X075宁波'
    when '1011'then '区X076上海' when '1012'then '区X077上海' when '1013'then '区X078上海' when '1014'then '区X079上海' when '1015'then '区X080上海'
    when '1016'then '区X081上海' when '1017'then '区X082上海' when '1018'then '区X083上海' else null end as business_district_id,
    case when a.work_shift_second_desc in ('上货支援','普通','临时店长班次','储备班次','困难店整改','复业工时','撤店工时','效期整改班次','新店建店','机动队支援加盟店班次','机动队效期检查','机动队月盘','远程支援','陈列工时')
    then 1 else 0 end as is_special,
    case when a.work_shift_second_desc in ('上货支援','普通','专项整改','临时店长班次','储备班次','困难店整改','复业工时','撤店工时','效期整改班次','新店建店','机动队支援加盟店班次','机动队效期检查','机动队月盘','远程支援','陈列工时')
    or a.day_manager_info = 1 or a.night_manager_info = 1 or a.roster_peace_info = 1  then  1 else 0 end as is_general
    from data_smartorder.dm_roster_tmp_use_ratio a
    left join data_smartorder.ods_uploads_business_district_qiyang b on a.store_code = b.store_code
    where a.dt = '${DATE}'
    and a.hps_dept_descr_lv1 = '运营管理部X'
    and a.work_shift_second_desc not in ('机动队新人班次','机动队岗前培训班次','岗前培训班次')
    )

    ,district_attendance as(
    --每个商圈的出勤
    select 
    work_shift_date,
    business_district_id,
    is_night,
    count(distinct case when is_special = 1 then concat(employee_no,work_shift_date) end ) as is_special_cnt,
    count(distinct case when is_general = 1 then concat(employee_no,work_shift_date)  end ) as is_general_cnt
    from raw_list
    group by
    work_shift_date,
    business_district_id,
    is_night
    )

    ,hps_dept_descr_lv5_attendance as(
    --每个商圈实际员工
    select 
    work_shift_date,
    hps_dept_descr_lv5,
    is_night,
    count(distinct concat(employee_no,work_shift_date)) as employee_num 
    from raw_list
    group by
    work_shift_date,
    hps_dept_descr_lv5,
    is_night
    )

    select
    a.work_shift_date,
    a.business_district_id,
    a.is_night,
    a.is_special_cnt,
    a.is_general_cnt,
    b.employee_num,
    nvl(a.is_special_cnt/b.employee_num,1) as special_rate,
    nvl(a.is_general_cnt/b.employee_num,1) as general_rate
    from district_attendance a
    left join hps_dept_descr_lv5_attendance b on a.work_shift_date = b.work_shift_date and a.business_district_id = b.hps_dept_descr_lv5 and a.is_night = b.is_night
end

--店副缺编报表，蜂利器报表
--全量保留门店
--落结果表
--data_smartorder.dwd_store_vice_manager_condition_da
begin
    with base_info as(
    select distinct
    t1.store_code
    ,t1.dt
    from data_smartorder.dm_copy_dwd_store_construction_store_groups_recruit_gap_view t1
    where t1.dt >= 20251101
    -- and t1.store_status_blf in ('1正常保留-已开业门店','2正常保留-未开业门店')
    )

    --架构关系：门店对应架构负责人
    ,structure_info as (
    select
    t1.dt
    ,t1.store_code
    ,t1.store_name
    ,t1.store_city
    ,nvl(t2.emplid,0) as store_manager_no
    ,t2.name as store_manager_name -- 店副
    ,t3.protect_tag
    ,t2.hps_d_jobcode as position_cn
    ,t2.hps_d_hr_status
    from data_smartorder.dw_ordering_store_tag_location_ranking_info_v1 t1
    left join data_smartorder.dm_copy_pdw_psprod_ps_blf_ehr_pers_vw_view t2
    on t1.store_code = t2.hps_dept_code_lv5 
    and t2.dt >= '20251101' 
    and t1.dt = t2.dt
    and t2.jobcode= 'NB0129'
    and t2.hps_d_hr_status = '在职'
    left join data_smartorder.dm_copy_dm_shop_staff_protect_tag_v2_view t3
    on IF(LENGTH(t2.emplid)<8,CONCAT('10',t2.emplid),t2.emplid) = t3.staff_code
    and t3.dt >= '20251101' 
    and t1.dt = t3.dt
    where t1.dt>='20251101'
    -- and t1.store_type = 0
    -- and t1.store_status = 1 --门店营业状态 0:待营业 1:营业 2：暂停营业 3：停业
    )

    --进行中or已确定未来会离职的人
    ,leave_info as ( --离职流程中
    select distinct
    t1.dt
    ,t1.man_code as user_job_number
    ,t1.order_status
    ,date_format(create_time,'yyyy-MM-dd') as create_date
    ,date_format(final_leave_date,'yyyy-MM-dd') as leave_date
    ,'1' as is_leaving
    from data_smartorder.dm_copy_pdw_gis_workday_dimission_order_view t1
    where t1.dt >= '20251101'
    and (t1.order_status = 'PROCESSING')
    or (final_leave_date > date_add(from_unixtime(unix_timestamp(t1.dt,'yyyyMMdd'),'yyyy-MM-dd'),1) and final_leave = 'leave' and t1.order_status = 'FINISHED')
    )
    --未来14天可用的天数
    ,give_behave_info_f14_a as (
    select 
    dt
    ,tmp.staff_code
    ,sum(tmp.is_available_roster) as f14_available_days
    from (
    select 
    distinct
    t1.dt
    ,t1.staff_code
    ,t1.target_date
    ,t1.is_available_roster
    from data_smartorder.dm_roster_staff_available_di t1
    where t1.dt >= '20251101'
    and t1.target_date >= date_add(from_unixtime(unix_timestamp(t1.dt,'yyyyMMdd'),'yyyy-MM-dd'),2)
    and t1.target_date <= date_add(from_unixtime(unix_timestamp(t1.dt,'yyyyMMdd'),'yyyy-MM-dd'),15)
    ) tmp
    group by dt,tmp.staff_code
    )

    ,vice_manager_list as( --机动队代店副清单
    select
    * from(
    select 
    employee_no,
    shop_code,
    relation_type,
    dt,
    row_number() over(partition by concat(dt,employee_no) order by create_time desc) as rn
    from data_smartorder.dm_copy_pdw_opc_roster_motor_shop_relation_view
    where dt >='20251101'
    and delete_ts = 0
    and end_date >= from_unixtime(unix_timestamp(dt,'yyyyMMdd'),'yyyy-MM-dd')
    and relation_type = 'VICE_MANAGER'
    and shop_code NOT RLIKE '[\\u4e00-\\u9fff]'
    ) a
    where rn = 1
    )

    ,dwd_store_vice_manager_condition_da as(
    select distinct

    t0.dt
    ,date_add(from_unixtime(unix_timestamp(t0.dt,'yyyymmdd'),'yyyy-mm-dd'),1) as record_date
    ,t0.store_code as store_code
    ,t2.store_name as store_name
    ,t2.store_city as city
    
    --架构是否缺编
    --顺序为汰换,战区,离职,不可用(14天),店员带店，店长带店
    ,case when t2.store_manager_no = '0' then '店副缺编'
    when t5.is_leaving = '1' then '离职流程中'
    when t14.f14_available_days <= '1' then '未来14天可用天数<=1'
    else '店副正常'
    end as type
    ,t12.reward_level as reward_level
    ,case when t10.shop_code is not null then '是' else '否' end as is_district_vice_manager

    from base_info t0
    left join structure_info t2
    on t0.store_code = t2.store_code and t0.dt = t2.dt
    left join leave_info t5
    on if(length(t2.store_manager_no)<8,concat('10',t2.store_manager_no),t2.store_manager_no) = t5.user_job_number and t0.dt = t5.dt
    left join data_smartorder.dm_copy_dwd_store_construction_store_groups_recruit_gap_view t12
    on t12.dt = t0.dt and t0.store_code = t12.store_code and t12.dt >= 20251101
    left join give_behave_info_f14_a t14
    on if(length(t2.store_manager_no)<8,concat('10',t2.store_manager_no),t2.store_manager_no) = t14.staff_code and t0.dt = t14.dt
    left join vice_manager_list t10 on t0.store_code = t10.shop_code and t0.dt = t10.dt
    where t12.reward_level <> '' and case when t2.store_manager_no = '0' then '店副缺编'
    when t5.is_leaving = '1' then '离职流程中'
    when t14.f14_available_days <= '1' then '未来14天可用天数<=1'
    else '店副正常'
    end <> '店副正常')

    ,calendar_raw AS (
    SELECT
    date_key,
    is_working_day,
    date_format(date_key, 'yyyyMMdd') AS dt_str
    FROM data_build.dim_date_ya_v2
    ),

    workday_seq AS (
    SELECT
    date_key,
    is_working_day,
    dt_str,
    SUM(is_working_day) OVER (ORDER BY date_key) AS wd_seq
    FROM calendar_raw
    ),

    date_map AS (
    SELECT
    a.date_key,
    a.dt_str,
    a.is_working_day,
    CASE
    WHEN a.is_working_day = 1 THEN a.dt_str
    ELSE b.dt_str
    END AS effective_dt
    FROM workday_seq a
    LEFT JOIN workday_seq b
    ON b.wd_seq = a.wd_seq
    AND b.is_working_day = 1
    ),

    revenue_stores AS (
    SELECT DISTINCT
    date_format(order_date, 'yyyyMMdd') AS biz_date,
    store_code
    FROM data_build.dw_order_sku_promotion_v1
    WHERE dt = date_format(date_sub(current_date(), 1), 'yyyyMMdd') -- 全量表，取昨天分区
    AND store_type = '0'
    AND pay_status = 'PAY_SUCCESS'
    AND sku_class_code NOT IN ('86', '50')
    )

    ,living_store as( --每天的营业门店数
    SELECT
    m.date_key AS query_date,
    m.effective_dt AS effective_dt,
    CASE
    WHEN m.is_working_day = 1 THEN '工作日'
    ELSE '休息日(回退)'
    END AS date_type,
    rs.store_code
    FROM date_map m
    JOIN revenue_stores rs
    ON rs.biz_date = m.effective_dt
    WHERE m.date_key >= '2025-11-01'
    )

    ,join_list as(
    select distinct
    dt 
    ,store_code
    from data_build.pdw_bach_baseinfo_shop_shop
    where dt >= '20260101'
    and self_take_type = '4' --加盟店
    )

    SELECT
    t0.query_date
    ,t0.store_code
    ,case when t1.store_code is null then '撤店pipeline门店' 
    when t4.store_code is not null then '加盟店'
    else '在营门店' end as store_type
    ,case 
    when t1.store_code is null then '撤店pipeline门店'
    when t4.store_code is not null then '加盟店'
    when t2.is_district_vice_manager = '是' then '机动队挂店副'
    when t2.is_district_vice_manager = '否' then '缺店副'
    else '有店副' end as vice_manager_type
    ,case 
    when t1.store_code is null then '撤店pipeline门店'
    when t4.store_code is not null then '加盟店'
    when t3.store_code is not null then '店长缺编' else '有店长' end as manager_type
    from living_store t0
    left join data_build.dwd_store_construction_store_groups_recruit_gap t1 on t0.store_code = t1.store_code and t0.effective_dt = t1.dt and t1.dt >= 20251101
    left join dwd_store_vice_manager_condition_da t2 on t1.store_code = t2.store_code and t1.dt = t2.dt
    LEFT JOIN data_shop.app_shop_structure_lack_details_di t3 on t1.store_code = t3.store_code and t1.dt = t3.dt
    left join join_list t4 on t0.store_code = t4.store_code and t0.effective_dt = t4.dt
    where t0.query_date >= '2025-01-01'
end




-- t30门店t值
begin
    with opening_days_base as
    (select
    shop_code as store_code
    ,sale_date as new_dt
    from data_build.pdw_idss_mmc_cooperate_shop_open_info_view
    where dt= '${today-1}'
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
    ,new_dt
    from opening_days_base 
    ),
    opening_days3 as 
    (
    select 
    store_code
    ,count(distinct new_dt) as opening_days
    from opening_days_base 
    group by store_code
    ),
    t_byday as 
    (
    select 
    shop_id
    ,alarm_start_date
    ,final_level_modify
    ,substr(final_level_modify,2,1) as final_t_level
    from data_shop.dwd_ic_new_import_store_level_da_view t1 
    where dt = '${today-1}'
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
    and t1.new_dt = t2.alarm_start_date
    group by t1.store_code
    )

    select
    t0.employee_id
    ,t0.name
    ,t0.store_code
    ,t0.store_name
    ,t0.change_date0
    ,t0.change_days --本店架构负责人天数
    ,t0.b_manager_days --成为架构负责人天数
    ,t1.final_t_level --30天t值
    ,case when t2.protect_tag_detail_new = 0 then '砖石'
    when t2.protect_tag_detail_new = 1 then '金牌'
    when t2.protect_tag_detail_new = 2 then '银牌'
    when t2.protect_tag_detail_new = 3 then '待观察'
    when t2.protect_tag_detail_new = 4 then '铜牌'
    when t2.protect_tag_detail_new = 5 then '须努力'
    when t2.protect_tag_detail_new = 6 then '优质银牌'
    else null end as protect_tag_detail_new
    from data_build.dwd_manager_tag_v1_di t0
    left join t_final t1 on t0.store_code = t1.store_code
    left join data_shop.dm_shop_staff_protect_tag_v2 t2 on t0.employee_id = t2.staff_code and t2.dt = 20260407
    where t0.dt = 20260407



    business_district_id
    hps_dept_code_lv5
    hps_dept_descr_lv5

    SELECT * from data_smartorder.ods_uploads_operation_x_business_district_qiyang
    operation_x -- 区X012青岛
    business_district_id -- 1080

    select
    district_code
    ,t3.hps_dept_code_lv5 as district_dept_code
    ,t2.operation_x as dept_name
    from data_build.dwd_store_construction_store_groups_recruit_gap t1
    left join data_smartorder.ods_uploads_operation_x_business_district_qiyang t2 on t1.district_code = t2.business_district_id
    left join (SELECT DISTINCT
    hps_dept_code_lv5
    ,hps_dept_descr_lv5
    from data_build.pdw_psprod_ps_blf_ehr_pers_vw_view
    where dt = '${today-1}') t3 on t2.operation_x = t3.hps_dept_descr_lv5
    where dt = 20260417
end





with
base_0 as
(
select
t1.roster_id
,t1.store_id
,t1.employee_id
,t1.work_date
,t1.start_time
,t1.end_time
,t1.is_night
,weekofyear(t1.work_date) as week_of_year
,year(t1.work_date) as year_of_work
,t2.holidays
,t1.dt
,date_sub(from_unixtime(unix_timestamp(t1.dt,'yyyyMMdd'),'yyyy-MM-dd'),1) as new_dt
from data_build.dw_roster_effect_roster_detail_info_da_view t1
left join (
select
weekofyear(date_key) as week_of_year
,year(date_key) as year_of_week
,sum(is_holiday) as holidays --当周节假日天数
from data_build.dim_date_ya_v2
group by
weekofyear(date_key)
,year(date_key)
) t2 on weekofyear(t1.work_date) = t2.week_of_year and year(t1.work_date) = t2.year_of_week
where t1.dt = '${DATE_ADD1DAY}'
and t1.store_type_desc = '门店'
and (t1.class_id in ('0') or t1.attr_id = '344') --20250702新增attr_id = '344'远程支援班次类型
and t1.store_type = '0'
--and (sale_type <> '全天不营业' or sale_type is null)

union all

select
t1.roster_id
,t1.store_id
,t1.employee_id
,t1.work_date
,t1.start_time
,t1.end_time
,t1.is_night
,weekofyear(t1.work_date) as week_of_year
,year(t1.work_date) as year_of_work
,t2.holidays
,t1.dt
,date_sub(from_unixtime(unix_timestamp(t1.dt,'yyyyMMdd'),'yyyy-MM-dd'),1) as new_dt
from data_build.dw_roster_effect_roster_detail_info_da_view t1
left join (
select
weekofyear(date_key) as week_of_year
,year(date_key) as year_of_week
,sum(is_holiday) as holidays --当周节假日天数
from data_build.dim_date_ya_v2
group by
weekofyear(date_key)
,year(date_key)
) t2 on weekofyear(t1.work_date) = t2.week_of_year and year(t1.work_date) = t2.year_of_week
where t1.dt = '${DATE_ADD1DAY}'
and t1.store_type_desc = '门店'
and store_id = '110000583'
and t1.attr_id = '358' --20251127新增，门店需要一个专门收银岗，如果班表出现358机动队支援班次，则增加1个hc
and t1.store_type = '0'
--and (sale_type <> '全天不营业' or sale_type is null)
),
base_1 as
(
    select
roster_id
,store_id
,employee_id
,work_date
,start_time
,end_time
,is_night
,t1.week_of_year
,year_of_work
,holidays
,dt
,new_dt
,day_of_week_name
    from base_0 t1
    left join data_build.dim_date_ya_v2 t2
    on new_dt = t2.date_key

),
base_2 as
(
    select
    roster_id
    ,store_id
    ,employee_id
    ,work_date
    ,start_time
    ,end_time
    ,is_night
    ,week_of_year
    ,year_of_work
    ,holidays

        from base_1
),

base_list as
(
    select
    roster_id
    ,week_of_year
    ,work_date
    ,store_id
    ,employee_id
    ,(end_time - start_time) as work_hours
    ,start_time
    ,end_time
    ,case when start_time is null then ''
            when is_night=1 then '夜班'
            when is_night=0 then '白班'
        end as work_shift_label_1
    ,case when (end_time - start_time)>=10 then '长班_10h'
    -- when (end_time - start_time)>=10 then '长班_10_12h'
    when (end_time - start_time)>=8 then '长班_8_10h'
            when (end_time - start_time)<8 and (end_time - start_time)>=4 then '短班_4-8H'
            when (end_time - start_time)<4 then '短班_<4H'
        end as work_shift_label_2
    from base_2
),
info_0 as
(select
 sale_date as c_date
 ,weekofyear(sale_date) as week_of_year
 ,shop_code as store_code
 ,from_unixtime(unix_timestamp(t1.dt,'yyyyMMdd'),'yyyy-MM-dd') as new_dt
 ,day_of_week_name
 from data_build.pdw_idss_mmc_cooperate_shop_open_info_view t1
 left join data_build.dim_date_ya_v2 t2
    on from_unixtime(unix_timestamp(t1.dt,'yyyyMMdd'),'yyyy-MM-dd') = t2.date_key
 where t1.dt= '${DATE}'
 and shop_type=0
 and shop_state=1
 and bach_business_time<>'全天不营业'
 ),

 info as
 (
    select
    store_code
    ,c_date
    ,week_of_year

    from info_0
 ),
 store_info as
 (
 select
    store_code
    ,week_of_year
    ,min(c_date) as opening_date_min
    ,max(c_date) as opening_date_max
    ,count(distinct c_date ) as opening_days
    from info
    group by store_code
    ,week_of_year),

-- 单店by天班型明细
base_final as
(
    select
    store_id
    ,work_date
    ,employee_id
    ,work_shift_label_1
    ,work_shift_label_2
    ,week_of_year
    ,case when work_shift_label_1='白班' and work_shift_label_2='长班_10h' then '长白班'
    when work_shift_label_1='白班' and work_shift_label_2='长班_8_10h' then '中白班'
            when work_shift_label_1='白班' and work_shift_label_2='短班_4-8H' then '短白班1'
            when work_shift_label_1='白班' and work_shift_label_2='短班_<4H' then '短白班2'

    when work_shift_label_1='夜班' and work_shift_label_2='长班_10h' then '长夜班'
    when work_shift_label_1='夜班' and work_shift_label_2='长班_8_10h' then '中夜班'
            when work_shift_label_1='夜班' and work_shift_label_2='短班_4-8H' then '短夜班1'
            when work_shift_label_1='夜班' and work_shift_label_2='短班_<4H' then '短夜班2'
        else null end as label
    ,count(work_date) as workdays
    from base_list
    group by store_id
    ,work_date
    ,employee_id
    ,work_shift_label_1
    ,work_shift_label_2
    ,week_of_year
    ,case when work_shift_label_1='白班' and work_shift_label_2='长班_10h' then '长白班'
    when work_shift_label_1='白班' and work_shift_label_2='长班_8_10h' then '中白班'
            when work_shift_label_1='白班' and work_shift_label_2='短班_4-8H' then '短白班1'
            when work_shift_label_1='白班' and work_shift_label_2='短班_<4H' then '短白班2'

    when work_shift_label_1='夜班' and work_shift_label_2='长班_10h' then '长夜班'
    when work_shift_label_1='夜班' and work_shift_label_2='长班_8_10h' then '中夜班'
            when work_shift_label_1='夜班' and work_shift_label_2='短班_4-8H' then '短夜班1'
            when work_shift_label_1='夜班' and work_shift_label_2='短班_<4H' then '短夜班2'
        else null end
),
final as
(

-- 单店by天班型分布

    select
    store_id
    ,week_of_year
    ,work_date
    ,label
    ,count(label) as label_no
    from base_final
    group by store_id
    ,week_of_year
    ,work_date
    ,label
)

select * from final
where work_date between '2025-04-01' and '2025-06-30'



--日商，客单价，店外客流
begin
    with cigarette_order_no as(
    select distinct
    order_no
    ,t.order_date
    ,t.store_code
    from data_build.dw_order_sku_v1 t
    where t.dt = '${today-1}'
    and t.store_type = '0'
    and t.order_status = 'FINISHED'
    and t.sku_class_code not in ('86','50')
    and t.sku_quantity > 0
    and sku_division_code in ('6101','6102')
    and order_date between '2025-01-01' and '2026-05-13'
    and order_date not in ('2025-05-14','2025-05-15','2025-05-16','2025-05-17','2025-05-18','2025-05-19','2025-05-20','2025-05-21','2025-05-22','2025-05-23','2025-05-24','2025-05-25',
    '2025-05-26','2025-05-27','2025-05-28','2025-05-29','2025-05-30','2025-05-31')
    )

    ,sale_list as(
    select
    trunc(t.order_date,'MM') as record_month
    ,t.store_code
    ,count(distinct t.order_date) as date_num --营业日
    ,count(distinct t.order_no)/count(distinct t.order_date) as order_num --日均单量
    ,sum(t.payable_price)/count(distinct t.order_date) as payable_price --日商
    ,sum(t.payable_price)/count(distinct t.order_no) as average_order_value --客单价

    ,count(distinct t1.order_no)/count(distinct t.order_date) as order_num_cigarette --含香烟订单单量
    ,sum(case when t1.order_no is not null then payable_price else 0 end)/count(distinct t1.order_no) as payable_price_cigarette --含香烟订单客单价

    ,count(distinct case when t1.order_no is not null then null else t.order_no end)/count(distinct t.order_date) as order_num_np_cigarette --不含香烟订单单量
    ,sum(case when t1.order_no is null then payable_price else 0 end)/count(distinct case when t1.order_no is not null then null else t.order_no end) as payable_price_np_cigarette --不含香烟订单客单价
    from data_build.dw_order_sku_v1 t
    left join cigarette_order_no t1 on t.store_code = t1.store_code and t.order_date = t1.order_date and t.order_no = t1.order_no
    where t.dt = '${today-1}'
    and t.store_type = '0'
    and t.order_status = 'FINISHED'
    and t.sku_class_code not in ('86','50')
    and t.sku_quantity > 0
    and t.order_date between '2025-01-01' and '2026-05-13'
    and t.order_date not in ('2025-05-14','2025-05-15','2025-05-16','2025-05-17','2025-05-18','2025-05-19','2025-05-20','2025-05-21','2025-05-22','2025-05-23','2025-05-24','2025-05-25',
    '2025-05-26','2025-05-27','2025-05-28','2025-05-29','2025-05-30','2025-05-31')
    group by
    trunc(t.order_date,'MM')
    ,t.store_code
    )

    ,outside_list as(
    select 
    trunc(event_date,'MM') as record_month
    ,store_code
    ,sum(outside_flow_cnt_out)/count(distinct concat(t.store_code,t.event_date)) as outside_flow_cnt_out--店外客流
    from data_smartorder.dm_ordering_report_store_change_info_di t
    where dt between '20250101' and '20260513'
    and dt not in ('20250514','20250515','20250516','20250517','20250518','20250519','20250520','20250521','20250522','20250523','20250524','20250525','20250526','20250527','20250528',
    '20250529','20250530','20250531')
    group by
    trunc(event_date,'MM')
    ,store_code
    )

    select
    t.record_month
    ,t.store_code
    ,t4.store_name
    ,t4.city_name
    ,case when t2.store_code is not null then '直营店'
    when t3.store_code is not null then '加盟店' else '撤店' end as store_type
    ,t.date_num --营业日
    ,t.order_num --总单量
    ,t.payable_price --日商
    ,t.average_order_value --客单价

    ,t.order_num_cigarette --含香烟订单单量
    ,t.payable_price_cigarette --含香烟订单客单价

    ,t.order_num_np_cigarette --不含香烟订单单量
    ,t.payable_price_np_cigarette --不含香烟订单客单价

    ,t1.outside_flow_cnt_out

    from sale_list t
    left join outside_list t1 on t.record_month = t1.record_month and t.store_code = t1.store_code
    left join data_build.dwd_store_construction_store_groups_recruit_gap t2 on t.store_code = t2.store_code and t2.dt = 20260512
    left join (select distinct 
    store_code
    from data_build.pdw_bach_baseinfo_shop_shop
    where dt = 20260512
    and self_take_type = '4' --加盟店
    ) t3 on t.store_code = t3.store_code
    left join data_build.dwd_store_construction_project_status_v2_di t4 on t.store_code = t4.store_code and t4.dt = 20260512
end


--机动队gap(北京天津)
with district_use_raw_list as(
select a.*,
case b.business_district_id
when '1000'then '区X001北京' when '1001'then '区X002北京' when '1002'then '区X003北京' when '1232'then '区X004天津' when '1231'then '区X005天津'
when '1018'then '区X006上海' when '1101'then '区X007南京' when '1094'then '区X008杭州' when '1074'then '区X009济南' when '6120'then '区X010宁波'
when '1080'then '区X012青岛' when '10012'then '区X013北京' when '10013'then '区X014北京' when '10014'then '区X015北京' when '10015'then '区X016北京'
when '10016'then '区X017北京' when '1230'then '区X018天津' when '1019'then '区X019上海' when '1100'then '区X020南京' when '1070'then '区X021济南'
when '10018'then '区X024北京' when '1880'then '区X027廊坊' when '1030'then '区X028石家庄' when '1210'then '区X029郑州' when '3970'then '区X030常州'
when '6121'then '区X031宁波' when '1110'then '区X032苏州' when '1182'then '区X033无锡' when '2330'then '区X034金华' when '2320'then '区X035温州'
when '1003'then '区X036北京' when '1004'then '区X037北京' when '1005'then '区X038北京' when '1006'then '区X039北京' when '1007'then '区X040北京'
when '1008'then '区X041北京' when '1009'then '区X042北京' when '10010'then '区X043北京' when '10011'then '区X044北京' when '10017'then '区X045北京'
when '1233'then '区X046天津' when '1234'then '区X047天津' when '1235'then '区X048天津' when '1236'then '区X049天津' when '1237'then '区X050天津'
when '1238'then '区X051天津' when '1239'then '区X052天津' when '3971'then '区X053常州' when '1093'then '区X054杭州' when '1092'then '区X055杭州'
when '1091'then '区X056杭州' when '1090'then '区X057杭州' when '1071'then '区X058济南' when '1072'then '区X059济南' when '1073'then '区X060济南'
when '1102'then '区X061南京' when '1103'then '区X062南京' when '1104'then '区X063南京' when '1105'then '区X064南京' when '1106'then '区X065南京'
when '1107'then '区X066南京' when '1211'then '区X067郑州' when '1181'then '区X068无锡' when '1180'then '区X069无锡' when '1113'then '区X070苏州'
when '1112'then '区X071苏州' when '1081'then '区X072青岛' when '1082'then '区X073青岛' when '6123'then '区X074宁波' when '6122'then '区X075宁波'
when '1011'then '区X076上海' when '1012'then '区X077上海' when '1013'then '区X078上海' when '1014'then '区X079上海' when '1015'then '区X080上海'
when '1016'then '区X081上海' when '1017'then '区X082上海' when '1018'then '区X083上海' else null end as business_district_id,
case when a.work_shift_second_desc in ('上货支援','普通','临时店长班次','储备班次','困难店整改','复业工时','撤店工时','效期整改班次','新店建店','机动队支援加盟店班次','机动队效期检查','机动队月盘','远程支援','陈列工时')
then 1 else 0 end as is_special,
case when a.work_shift_second_desc in ('上货支援','普通','专项整改','临时店长班次','储备班次','困难店整改','复业工时','撤店工时','效期整改班次','新店建店','机动队支援加盟店班次','机动队效期检查','机动队月盘','远程支援','陈列工时')
or a.day_manager_info = 1 or a.night_manager_info = 1 or a.roster_peace_info = 1  then  1 else 0 end as is_general
from data_smartorder.dm_roster_tmp_use_ratio a
left join data_smartorder.ods_uploads_business_district_qiyang b on a.store_code = b.store_code
where a.dt = '${DATE}'
and a.hps_dept_descr_lv1 = '运营管理部X'
and a.work_shift_second_desc not in ('机动队新人班次','机动队岗前培训班次','岗前培训班次')
)

,district_attendance as(--每个商圈的出勤
select 
work_shift_date,
business_district_id,
count(distinct case when is_special = 1 then concat(employee_no,work_shift_date) end ) as is_special_cnt,
count(distinct case when is_general = 1 then concat(employee_no,work_shift_date)  end ) as is_general_cnt
from district_use_raw_list
group by
work_shift_date,
business_district_id
)

,hps_dept_descr_lv5_attendance as(--每个商圈实际员工
select 
work_shift_date,
hps_dept_descr_lv5,
count(distinct concat(employee_no,work_shift_date)) as employee_num 
from district_use_raw_list
group by
work_shift_date,
hps_dept_descr_lv5
)

,final_district_use as(
select
a.work_shift_date,
a.business_district_id,
a.is_special_cnt,
a.is_general_cnt,
b.employee_num,
nvl(a.is_special_cnt/b.employee_num,1) as special_rate,
nvl(a.is_general_cnt/b.employee_num,1) as general_rate
from district_attendance a
left join hps_dept_descr_lv5_attendance b on a.work_shift_date = b.work_shift_date and a.business_district_id = b.hps_dept_descr_lv5
)

,district_usage_prep_data as (
    select
    business_district_id
    ,case business_district_id
        when '区X001北京' then '1000' when '区X002北京' then '1001'
        when '区X003北京' then '1002' when '区X004天津' then '1232'
        when '区X005天津' then '1231' when '区X006上海' then '1018'
        when '区X007南京' then '1101'
        when '区X008杭州' then '1094'when '区X009济南' then '1074'
        when '区X010宁波' then '6120' when '区X012青岛' then '1080'
        when '区X013北京' then '10012' when '区X014北京' then '10013'
        when '区X015北京' then '10014' when '区X016北京' then '10015'
        when '区X017北京' then '10016'
        when '区X018天津' then '1230' when '区X019上海' then '1019'
        when '区X020南京' then '1100' when '区X021济南' then '1070'
        when '区X024北京' then '10018' when '区X027廊坊' then '1880'
        when '区X028石家庄' then '1030' when '区X029郑州' then '1210'
        when '区X030常州' then '3970' when '区X031宁波' then '6121'
        when '区X032苏州' then '1110' when '区X033无锡' then '1182'
        when '区X034金华' then '2330' when '区X035温州' then '2320'
        when '区X036北京' then '1003' when '区X037北京' then '1004'
        when '区X038北京' then '1005'
        when '区X039北京' then '1006' when '区X040北京' then '1007'
        when '区X041北京' then '1008'
        when '区X042北京' then '1009' when '区X043北京' then '10010'
        when '区X044北京' then '10011'when '区X045北京' then '10017'
        when '区X046天津' then '1233' when '区X047天津' then '1234'
        when '区X048天津' then '1235' when '区X049天津' then '1236'
        when '区X050天津' then '1237'
        when '区X051天津' then '1238' when '区X052天津' then '1239'
        when '区X053常州' then '3971' when '区X054杭州' then '1093'
        when '区X055杭州' then '1092' when '区X056杭州' then '1091'
        when '区X057杭州' then '1090' when '区X058济南' then '1071'
        when '区X059济南' then '1072' when '区X060济南' then '1073'
        when '区X061南京' then '1102' when '区X062南京' then '1103'
        when '区X063南京' then '1104' when '区X064南京' then '1105'
        when '区X065南京' then '1106'
        when '区X066南京' then '1107' when '区X067郑州' then '1211'
        when '区X068无锡' then '1181' when '区X069无锡' then '1180'
        when '区X070苏州' then '1113' when '区X071苏州' then '1112'
        when '区X072青岛' then '1081' when '区X073青岛' then '1082'
        when '区X074宁波' then '6123' when '区X075宁波' then '6122'
        when '区X076上海' then '1011' when '区X077上海' then '1012'
        when '区X078上海' then '1013'
        when '区X079上海' then '1014' when '区X080上海' then '1015'
        when '区X081上海' then '1016' when '区X082上海' then '1017'
        when '区X083上海' then '1018' else business_district_id end as district_code
    
    ,max(is_special_cnt) as max_is_special_cnt

    ,AVG(CASE WHEN work_shift_date BETWEEN date_sub(from_unixtime(unix_timestamp('${DATE}','yyyyMMdd'),'yyyy-MM-dd'),15)  AND date_sub(from_unixtime(unix_timestamp('${DATE}','yyyyMMdd'),'yyyy-MM-dd'),1) THEN special_rate ELSE NULL END) AS special_rate_night_14days
    ,AVG(CASE WHEN work_shift_date BETWEEN date_sub(from_unixtime(unix_timestamp('${DATE}','yyyyMMdd'),'yyyy-MM-dd'),15)  AND date_sub(from_unixtime(unix_timestamp('${DATE}','yyyyMMdd'),'yyyy-MM-dd'),1) THEN general_rate ELSE NULL END) as general_rate_night_14days

from final_district_use
where work_shift_date BETWEEN date_sub(from_unixtime(unix_timestamp('${DATE}','yyyyMMdd'),'yyyy-MM-dd'),15)  AND date_sub(from_unixtime(unix_timestamp('${DATE}','yyyyMMdd'),'yyyy-MM-dd'),1)
group by business_district_id
)

--每个商圈在职的机动队人数(非黑名单非离职中)
,district_staff_num as(
select
hps_d_city
,t4.business_district_id
,count(1) as district_staff_num
from data_build.pdw_psprod_ps_blf_ehr_pers_vw_view t1
left join (
        select distinct 
        employee_no
        ,lpad(employee_no,8,'10') as staff_code
    from data_shop.pdw_idss_ipes_admin_employee_blacklist_view -- 全量黑名单表
    where dt = '${DATE}'
        and valid_status=1 
        and start_date <= from_unixtime(unix_timestamp('${DATE}','yyyymmdd'),'yyyy-mm-dd')
        and end_date >= from_unixtime(unix_timestamp('${DATE}','yyyymmdd'),'yyyy-mm-dd')
    ) t2 on lpad(t1.emplid,8,'10') = t2.staff_code 
left join (
        select distinct
        t1.man_code as user_job_number
        ,lpad(t1.man_code,8,10) as staff_code
        ,t1.order_status
        ,date_format(create_time,'yyyy-MM-dd') as create_date
        ,date_format(final_leave_date,'yyyy-MM-dd') as leave_date
        ,'1' as is_leaving
    from data_shop.pdw_gis_workday_dimission_order_view t1
    where t1.dt = '${DATE}'
        and (t1.order_status = 'PROCESSING')
            or (date_format(final_leave_date,'yyyyMMdd') > t1.dt and final_leave = 'noleave' and t1.order_status = 'FINISHED')
    ) t3 on lpad(t1.emplid,8,'10') = t3.staff_code
left join data_smartorder.ods_uploads_operation_x_business_district_qiyang t4 
on t1.hps_dept_descr_lv5 = t4.operation_x
where t1.dt = '${DATE}'
and t1.hps_dept_descr_lv5 like '%区X%'
and t1.hps_d_hr_status ='在职'
and t2.staff_code is null --非黑名单
and t3.staff_code is null --非离职中
group by
hps_d_city
,t4.business_district_id
)

select
t1.business_district_id
,t1.district_code
,t1.max_is_special_cnt
,t1.special_rate_night_14days
,t1.general_rate_night_14days
,nvl(t2.district_staff_num,0) as district_staff_num
,t1.max_is_special_cnt/6*7*1.05 as need_staff_1
,t1.special_rate_night_14days*nvl(t2.district_staff_num,0)/0.85 as need_staff_2
,round((t1.max_is_special_cnt/6*7*1.05+t1.special_rate_night_14days*nvl(t2.district_staff_num,0)/0.85)/2,0) as need_staff
,if(t1.special_rate_night_14days<0.85,0,if(round((t1.max_is_special_cnt/6*7*1.05+t1.special_rate_night_14days*nvl(t2.district_staff_num,0)/0.85)/2,0)-nvl(t2.district_staff_num,0)<0,0,
round((t1.max_is_special_cnt/6*7*1.05+t1.special_rate_night_14days*nvl(t2.district_staff_num,0)/0.85)/2,0)-nvl(t2.district_staff_num,0))) as gap_all_district
from district_usage_prep_data t1
left join district_staff_num t2 on t1.district_code = t2.business_district_id

