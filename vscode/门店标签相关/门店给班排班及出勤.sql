--bydate 看人员回归情况


with give_raw as ( --是否给班

    select 
        lpad(employee_id,8,'10') as staff_code
        ,max(case when (roster_date = '2024-03-04' and givetype in ('全天可开工','夜晚可开工','白天可开工') and effectiveworkhour>=8) then 1 else null end) as give_20240226
        ,max(case when (roster_date = '2024-03-05' and givetype in ('全天可开工','夜晚可开工','白天可开工') and effectiveworkhour>=8) then 1 else null end) as give_20240227
        ,max(case when (roster_date = '2024-03-06' and givetype in ('全天可开工','夜晚可开工','白天可开工') and effectiveworkhour>=8) then 1 else null end) as give_20240228
        ,max(case when (roster_date = '2024-03-07' and givetype in ('全天可开工','夜晚可开工','白天可开工') and effectiveworkhour>=8) then 1 else null end) as give_20240229
        ,max(case when (roster_date = '2024-03-08' and givetype in ('全天可开工','夜晚可开工','白天可开工') and effectiveworkhour>=8) then 1 else null end) as give_20240301
        ,max(case when (roster_date = '2024-03-09' and givetype in ('全天可开工','夜晚可开工','白天可开工') and effectiveworkhour>=8) then 1 else null end) as give_20240302
        ,max(case when (roster_date = '2024-03-10' and givetype in ('全天可开工','夜晚可开工','白天可开工') and effectiveworkhour>=8) then 1 else null end) as give_20240303
    from data_smartorder.dw_roster_give_roster_detail_snapshot_da
        where dt = '${today-1}'
        group by lpad(employee_id, 8, '10')

),



shift_raw as ( --是否排班

    select
        lpad(employee_id,8,'10') as staff_code
        ,max(case when (work_date = '2024-03-04' and (end_time-start_time)>=8) then 1 else null end) as shift_20240226
        ,max(case when (work_date = '2024-03-05' and (end_time-start_time)>=8) then 1 else null end) as shift_20240227
        ,max(case when (work_date = '2024-03-06' and (end_time-start_time)>=8) then 1 else null end) as shift_20240228
        ,max(case when (work_date = '2024-03-07' and (end_time-start_time)>=8) then 1 else null end) as shift_20240229
        ,max(case when (work_date = '2024-03-08' and (end_time-start_time)>=8) then 1 else null end) as shift_20240301
        ,max(case when (work_date = '2024-03-09' and (end_time-start_time)>=8) then 1 else null end) as shift_20240302
        ,max(case when (work_date = '2024-03-10' and (end_time-start_time)>=8) then 1 else null end) as shift_20240303
            from data_build.dw_roster_effect_roster_detail_info_da_view 
    where dt = '${today-1}'
        and store_type_desc = '门店'
        and class_id in ('0','-5')
        and store_type = '0'
        and sale_type <> '全天不营业'
        and roster_source = '成功班表'
    group by lpad(employee_id, 8, '10')

),



attendance_raw as( --是否出勤

    select 
        lpad(employee_no,8,'10') as staff_code
        ,max(case when (work_shift_date = '2024-02-26' and attendance_work_hours>=7.5) then 1 else null end) as attendance_20240219
        ,max(case when (work_shift_date = '2024-02-27' and attendance_work_hours>=7.5) then 1 else null end) as attendance_20240220
        ,max(case when (work_shift_date = '2024-02-28' and attendance_work_hours>=7.5) then 1 else null end) as attendance_20240221
        ,max(case when (work_shift_date = '2024-02-29' and attendance_work_hours>=7.5) then 1 else null end) as attendance_20240222
        ,max(case when (work_shift_date = '2024-03-01' and attendance_work_hours>=7.5) then 1 else null end) as attendance_20240223
        ,max(case when (work_shift_date = '2024-03-02' and attendance_work_hours>=7.5) then 1 else null end) as attendance_20240224
        ,max(case when (work_shift_date = '2024-03-04' and attendance_work_hours>=7.5) then 1 else null end) as attendance_20240225
    from
        data_shop.pdw_opc_shop_attendance_report_work_shift_view
    where dt = '${today-1}'
        and work_shift_type in (1, 9, 12)
    group by lpad(employee_no, 8, '10')

),



staff_base as(

    select
        lpad(t1.emplid,8,'10') as staff_code
        ,t1.hps_d_hr_status
        ,t1.hps_d_jobcode
        ,t3.protect_tag
        ,lpad(t4.manager_code,8,'10') 
        ,t1.dt
        from data_build.pdw_psprod_ps_blf_ehr_pers_vw_view t1
        left join data_shop.dm_shop_staff_protect_tag_v2 t3 on
             lpad(t1.emplid,8,'10') = t3.staff_code 
             and t3.dt = '2023-01-16'
        left join data_build.pdw_opc_shop_ehr_staff_dept_view t4 on
             lpad(t1.emplid,8,'10')  = lpad(t4.manager_code,8,'10') and t1.dt = t4.dt
    where t1.dt= '20230116'
    and hps_d_jobcode in ('店经理','储备店经理','见习店经理','门店伙伴','社会PT','学生PT','防疫伙伴','店副经理')
    and hps_d_hr_status = '在职'

),

first_shift_date as (

        SELECT 
            staff_code,
            MIN(shift_date) AS shift_date
        FROM 
            shift_raw
        WHERE 
            shift_date IS NOT NULL
        GROUP BY 
            staff_code

)


    select 

    t1.staff_code
    ,t1.hps_d_hr_status
    ,t1.hps_d_jobcode
    ,t1.protect_tag
    ,t2.give_20230128
    ,t2.give_20230129
    ,t2.give_20230130
    ,t2.give_20230131
    ,t2.give_20230201
    ,t2.give_20230202
    ,t2.give_20230203
    ,t2.give_20230204
    ,t2.give_20230205
    ,t2.give_20230206
    ,t2.give_20230207
    ,t2.give_20230208
    ,t2.give_20230209
    ,t3.shift_20230128
    ,t3.shift_20230129
    ,t3.shift_20230130
    ,t3.shift_20230131
    ,t3.shift_20230201
    ,t3.shift_20230202
    ,t3.shift_20230203
    ,t3.shift_20230204
    ,t3.shift_20230205
    ,t3.shift_20230206
    ,t3.shift_20230207
    ,t3.shift_20230208
    ,t3.shift_20230209
    ,t4.attendance_20230128
    ,t4.attendance_20230129
    ,t4.attendance_20230130
    ,t4.attendance_20230131
    ,t4.attendance_20230201
    ,t4.attendance_20230202
    ,t4.attendance_20230203
    ,t4.attendance_20230204
    ,t4.attendance_20230205
    ,t4.attendance_20230206
    ,t4.attendance_20230207
    ,t4.attendance_20230208
    ,t4.attendance_20230209
    CASE 
        WHEN t3.shift_date = t4.attendance_date THEN 'Attended' 
        ELSE 'Did Not Attend' 
    END AS attendance_first_shift

first_shift_date 


FROM 
    staff_base t1
LEFT JOIN 
    give_raw t2 ON t1.staff_code = t2.staff_code
LEFT JOIN 


from staff_base t1
left join give_raw t2 on
    t1.staff_code = t2.staff_code
left join shift_raw t3 on
    t1.staff_code = t3.staff_code    
left join attendance_raw t4 on
    t1.staff_code = t4.staff_code
------------------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------------------
--机动队利用率数据(周维度)
select 
date_sub(next_day(work_shift_date,'mon'),7) as record_week
,hps_dept_descr_lv5
--,is_night
,count(distinct case when is_special = 1 and attendance_work_hours > 0 then concat(employee_no,work_shift_date) end ) as is_special_cnt
,count(distinct case when is_general = 1 and attendance_work_hours > 0  then concat(employee_no,work_shift_date) end ) as is_general_cnt
,count(distinct concat(employee_no,work_shift_date) ) as all_cnt
,count(distinct case when is_special = 1 and attendance_work_hours > 0  then concat(employee_no,work_shift_date) end )/count(distinct concat(employee_no,work_shift_date) ) as special_rate
,count(distinct case when is_general = 1 and attendance_work_hours > 0  then concat(employee_no,work_shift_date) end )/count(distinct concat(employee_no,work_shift_date) ) as general_rate
from (
select
a.*
,case when a.work_shift_second_desc in ('上货支援','普通','临时店长班次','储备班次','困难店整改','复业工时','撤店工时','效期整改班次','新店建店','机动队支援加盟店班次','机动队效期检查','机动队月盘','远程支援','陈列工时')
then 1 else 0 end as is_special
,case when a.work_shift_second_desc in ('上货支援','普通','专项整改','临时店长班次','储备班次','困难店整改','复业工时','撤店工时','效期整改班次','新店建店','机动队支援加盟店班次','机动队效期检查','机动队月盘','远程支援','陈列工时')
or a.day_manager_info = 1 or a.night_manager_info = 1 or a.roster_peace_info = 1  then  1 else 0 end as is_general
from data_smartorder.dm_roster_tmp_use_ratio a
where a.dt = '${DATE}'
and a.hps_dept_descr_lv1 = '运营管理部X'
and a.work_shift_second_desc not in ('机动队新人班次','机动队岗前培训班次','岗前培训班次')
and is_franchise_store = 0
) a
where work_shift_date between '2026-04-21' and '2026-04-21'
group by
date_sub(next_day(work_shift_date,'mon'),7)
,hps_dept_descr_lv5

--新算法
--20260323调整机动队利用率算法
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
--is_night,
count(distinct case when is_special = 1 then concat(employee_no,work_shift_date) end ) as is_special_cnt,
count(distinct case when is_general = 1 then concat(employee_no,work_shift_date)  end ) as is_general_cnt
from district_use_raw_list
group by
work_shift_date,
business_district_id
--is_night
)

,hps_dept_descr_lv5_attendance as(--每个商圈实际员工
SELECT
from_unixtime(unix_timestamp(t.dt,'yyyymmdd'),'yyyy-mm-dd') as record_date
,t.hps_dept_code_lv5	
,t.hps_dept_descr_lv5
,t1.business_district_id
,count(1) as employee_num
from data_build.pdw_psprod_ps_blf_ehr_pers_vw_view t
LEFT JOIN data_smartorder.ods_uploads_operation_x_business_district_qiyang t1 on t.hps_dept_descr_lv5 = t1.operation_x
LEFT JOIN (select distinct
from_unixtime(unix_timestamp(dt,'yyyymmdd'),'yyyy-mm-dd') as record_date
,employee_no
,lpad(employee_no,8,'10') as staff_code
from data_shop.pdw_idss_ipes_admin_employee_blacklist_view -- 全量黑名单表
where dt >= '${today-90}' 
and valid_status=1 
and start_date <= from_unixtime(unix_timestamp(dt,'yyyymmdd'),'yyyy-mm-dd')
and end_date >= from_unixtime(unix_timestamp(dt,'yyyymmdd'),'yyyy-mm-dd')) t2 on lpad(t.emplid,8,'10') = t2.staff_code and from_unixtime(unix_timestamp(t.dt,'yyyymmdd'),'yyyy-mm-dd') = t2.record_date
where dt >= '${today-90}'
and hps_d_hr_status = '在职'
and hps_dept_descr_lv1 = '运营管理部X'
and t2.staff_code is null
GROUP BY
from_unixtime(unix_timestamp(t.dt,'yyyymmdd'),'yyyy-mm-dd')
,hps_dept_code_lv5	
,hps_dept_descr_lv5
,t1.business_district_id
)

,final_district_use as(
select
a.work_shift_date,
a.business_district_id,
--a.is_night,
a.is_special_cnt,
a.is_general_cnt,
b.employee_num,
nvl(a.is_special_cnt/b.employee_num,1) as special_rate,
nvl(a.is_general_cnt/b.employee_num,1) as general_rate
from district_attendance a
left join hps_dept_descr_lv5_attendance b on a.work_shift_date = b.record_date and a.business_district_id = b.hps_dept_descr_lv5 
--and a.is_night = b.is_night
)

select
business_district_id
,avg(special_rate) as special_rate
,avg(general_rate) as general_rate
from final_district_use
where work_shift_date between '2026-04-08' and '2026-04-15' --灵活变动
group by
business_district_id
------------------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------------------
--不同岗位/班次类型出勤明细
WITH store_info as(
SELECT
t1.store_code
,t1.district_code
,t2.store_city
,case when t3.store_code is not null then '加盟店' else '直营店' end as store_type
from data_build.dwd_store_construction_full_capacity_perdict t1
LEFT JOIN data_build.dim_store_info t2 on t1.dt = t2.dt and t1.store_code = t2.store_code
left join (select distinct 
store_code
from data_build.pdw_bach_baseinfo_shop_shop
where dt = '20241019'
and self_take_type = '4') t3 on t1.store_code = t3.store_code --加盟店
where t1.dt = 20241019)

SELECT
t1.* 
,case when substr(t1.dept_name,1,2) = '区X' then '机动队' when t1.position in ('门店伙伴','学生PT','预备伙伴') then '店员' else t1.position end as position_cn
,case when t2.employee_id is not null then '机动队带店' else null end as district_manager
,t3.district_code
,t3.store_city
,t3.store_type
from data_shop.pdw_opc_shop_attendance_report_work_shift_view t1
LEFT JOIN data_build.dwd_store_construction_district_manager_base_info0_di t2 on t2.dt = 20241019 and lpad(t1.employee_no,8,'10') = lpad(t2.employee_id,8,'10')
left join store_info t3 on t1.store_code = t3.store_code
where t1.dt = 20241020
and t1.work_shift_date BETWEEN '2024-10-14' and '2024-10-20'
and t1.attendance_work_hours > '0'
and t1.work_shift_type in (1, 9, 12)
