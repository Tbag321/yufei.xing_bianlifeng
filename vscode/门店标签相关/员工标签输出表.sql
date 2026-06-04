# --------------------------------------
# DATE: 2024-05-20
# OUT:  data_shop.dm_shop_staff_protect_tag_v2
# DEV:  hanzhi.cao
# DESC: 门店员工t30保护标签表v2
# --------------------------------------

###参数设置：日期参数，表名，唯一键
source ${ETC}/format_date.cnf
TABLE_NAME="data_shop.dm_shop_staff_protect_tag_v2"
UNIQ_KEY="staff_code"


###JOB入口函数：计算，校验
function dm_shop_staff_protect_tag_v2_run {
     calculate && do_check
}


##计算模块
function calculate {
$HIVE << EOF

${HIVE_SETTINGS};
set mapreduce.job.queuename=dw;
set hive.exec.parallel=true;

with latest_ehr_infra as ( --每人最新的花名册记录
    select
        IF(LENGTH(t1.emplid)<8,concat('10',t1.emplid),t1.emplid) AS staff_code
        ,t1.emplid
        ,t1.name as staff_name
        ,t1.hps_d_city as city_name
        ,t1.hps_d_jobcode as position_cn

,case when date_format(t1.hps_hire_dt, 'yyyyMMdd') < '${DATE_SUB31DAY}'
then if(t1.hps_dept_descr_lv5 like '%区X%' or t1.hps_dept_descr_lv1 in ('运营管理部X'),'老机动队',
if(t2.manager_code is not null,'老架构负责人',
if(t1.hps_d_jobcode = '店副经理','老店副经理','老店员')))
else if(t1.hps_dept_descr_lv5 like '%区X%' or t1.hps_dept_descr_lv1 in ('运营管理部X'),'新机动队',
if(t2.manager_code is not null,'新架构负责人',
if(t1.hps_d_jobcode = '店副经理','新店副经理','新店员')))
end as position_class --0628更新职位逻辑

        ,t1.hps_dept_code_lv5 as store_code
        ,case t1.hps_dept_descr_lv5 
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
when '区X083上海' then '1018' else t1.hps_dept_descr_lv5 end as store_name
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
    left join --判断是否是架构负责人
(select
dt
,dept_code
,if(length(manager_code)=6,concat('10',manager_code),manager_code) as manager_code
from data_shop.pdw_opc_shop_ehr_staff_dept_view
where dt >= 20210318
group by
dt
,dept_code
,if(length(manager_code)=6,concat('10',manager_code),manager_code)
) t2 on t1.dt = t2.dt and if(length(t1.emplid)=6,concat('10',t1.emplid),t1.emplid) = t2.manager_code and t1.hps_dept_code_lv5 = t2.dept_code
    where t1.dt = '${DATE}'
        and t1.hps_dept_descr_lv1 in ('运营管理部A','运营管理部B','运营管理部X')
        and t1.hps_d_jobcode in ('店经理', '门店伙伴', '店员', '社会PT', '学生PT', '见习店经理','店副经理','内部合作经营者','内部合作辅助人','内部合作伙伴','外部合作经营者','外部合作辅助人','外部合作伙伴')
        and t1.hps_d_hr_status = '在职'
group by
IF(LENGTH(t1.emplid)<8,concat('10',t1.emplid),t1.emplid)
        ,t1.emplid
        ,t1.name
        ,t1.hps_d_city
        ,t1.hps_d_jobcode

,case when date_format(t1.hps_hire_dt, 'yyyyMMdd') < '${DATE_SUB31DAY}'
then if(t1.hps_dept_descr_lv5 like '%区X%' or t1.hps_dept_descr_lv1 in ('运营管理部X'),'老机动队',
if(t2.manager_code is not null,'老架构负责人',
if(t1.hps_d_jobcode = '店副经理','老店副经理','老店员')))
else if(t1.hps_dept_descr_lv5 like '%区X%' or t1.hps_dept_descr_lv1 in ('运营管理部X'),'新机动队',
if(t2.manager_code is not null,'新架构负责人',
if(t1.hps_d_jobcode = '店副经理','新店副经理','新店员')))
end --0628更新职位逻辑

        ,t1.hps_dept_code_lv5
        ,case t1.hps_dept_descr_lv5 
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
when '区X083上海' then '1018' else t1.hps_dept_descr_lv5 end
        ,date_format(t1.hps_hire_dt,'yyyyMMdd')
        ,date_format(t1.leave_dt,'yyyyMMdd')
        ,case t1.hps_d_hr_status
            when '在职' then 1 else 0
        end
        ,case when t1.hps_dept_descr_lv1 in ('运营管理部X') then 1 else 0 end
        ,null
        ,null
        ,null
        ,null
)

,store_groups_recruit_gap as(
--门店运营-O/I店群人力缺口
select
a.record_date
,a.store_code_v1
,a.district_code
,a.reward_level_district --区域招聘等级
,a.reward_level --招聘激励等级
,a.reward_level_night --夜班激励等级
,a.district_superfluity --商圈冗余
,a.superfluity --商圈&门店冗余
from(
select
from_unixtime(unix_timestamp(dt,'yyyyMMdd'),'yyyy-MM-dd') as record_date
,store_code as store_code_v1
,district_code
,reward_level_district --区域招聘等级
,reward_level --招聘激励等级
,reward_level_night --夜班激励等级
,case when reward_level_district in ('P1') then 1 else 0 end as district_superfluity --商圈冗余
,case when reward_level_district in ('P1') and reward_level in ('P0','P1') and reward_level_night in ('P0','P1') then 1 else 0 end as superfluity --商圈&门店冗余
,row_number() over(partition by store_code order by dt desc) as rn
from data_build.dwd_store_construction_store_groups_recruit_gap
where dt >= '${DATE_SUB30DAY}'
) a
where a.rn = 1
)

,groups_recruit_gap as(
--商圈运营-O/I店群人力缺口
select
record_date
,district_code
,reward_level_district --区域招聘等级
,district_superfluity --商圈冗余
from(
select
a.record_date
,a.district_code
,a.reward_level_district --区域招聘等级
,a.district_superfluity --商圈冗余
,row_number() over(partition by district_code order by a.record_date desc) as rn
from store_groups_recruit_gap a
) a
where rn =1
)

,no_punch as ( --下班未打卡记录
    select
        employee_no
        ,work_shift_date
        ,'下班未打卡' as mark
    from default.pdw_opc_shop_attendance_report_work_shift a
    where dt = '${DATE}'
        and date_format(work_shift_date, 'yyyyMMdd') <= '${DATE_SUB1DAY}'
        and date_format(work_shift_date, 'yyyyMMdd') >= date_format(date_sub(current_date,96),'yyyyMMdd') --'${DATE_SUB95DAY}'
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
        and date_format(a.work_shift_date, 'yyyyMMdd') >= date_format(date_sub(current_date,96),'yyyyMMdd') --'${DATE_SUB95DAY}'
        and a.work_shift_type in (1,9,12)
        and work_shift_second_desc <> '撤店工时' --20241204新增，避免撤店不能打卡造成的旷工误判
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
        and date_format(create_date, 'yyyyMMdd') >= date_format(date_sub(current_date,96),'yyyyMMdd') --'${DATE_SUB95DAY}'
        and is_exemption_eliminate = 0
        and penalty_roster_hours >= 0.5
)

,att_ab_info as (
    select
        staff_code_v1
        ,count(distinct
            case when
                date_format(work_shift_date,'yyyyMMdd') >= '${DATE_SUB6DAY}'
                and date_format(work_shift_date,'yyyyMMdd') <= '${DATE_SUB1DAY}'
                and absenteeism_hours >0
            then date_format(work_shift_date,'yyyyMMdd') end) as t6_abs --t6旷工天数
        ,count(distinct
            case when
                date_format(work_shift_date,'yyyyMMdd') >= '${DATE_SUB7DAY}'
                and date_format(work_shift_date,'yyyyMMdd') <= '${DATE_SUB1DAY}'
                and absenteeism_hours >0
            then date_format(work_shift_date,'yyyyMMdd') end) as t7_abs --t7旷工天数
        ,count(distinct
            case when
                date_format(work_shift_date,'yyyyMMdd') >= '${DATE_SUB28DAY}'
                and date_format(work_shift_date,'yyyyMMdd') <= '${DATE_SUB1DAY}'
                and absenteeism_hours >0
            then date_format(work_shift_date,'yyyyMMdd') end) as t28_abs --t28旷工天数
        ,count(distinct
            case when
                date_format(work_shift_date,'yyyyMMdd') >= '${DATE_SUB30DAY}'
                and date_format(work_shift_date,'yyyyMMdd') <= '${DATE_SUB1DAY}'
                and absenteeism_hours >0
            then date_format(work_shift_date,'yyyyMMdd') end) as t30_abs --t30旷工天数
        ,count(distinct
            case when
                date_format(work_shift_date,'yyyyMMdd') >= date_format(date_sub(current_date,86),'yyyyMMdd') --'${DATE_SUB85DAY}'
                and date_format(work_shift_date,'yyyyMMdd') <= '${DATE_SUB1DAY}'
                and absenteeism_hours >0
            then date_format(work_shift_date,'yyyyMMdd') end) as t85_abs --t85旷工天数
        ,count(distinct
            case when
                date_format(work_shift_date,'yyyyMMdd') >= '${DATE_SUB90DAY}'
                and date_format(work_shift_date,'yyyyMMdd') <= '${DATE_SUB1DAY}'
                and absenteeism_hours >0
            then date_format(work_shift_date,'yyyyMMdd') end) as t90_abs --t90旷工天数
        ,count(distinct
            case when
                date_format(work_shift_date,'yyyyMMdd') >= date_format(date_sub(current_date,96),'yyyyMMdd') --'${DATE_SUB95DAY}'
                and date_format(work_shift_date,'yyyyMMdd') <= '${DATE_SUB1DAY}'
                and absenteeism_hours >0
            then date_format(work_shift_date,'yyyyMMdd') end) as t95_abs --t95旷工天数
        ,count(distinct
            case when
                date_format(work_shift_date,'yyyyMMdd') >= date_format(date_sub(current_date,26),'yyyyMMdd') --'${DATE_SUB25DAY}'
                and date_format(work_shift_date,'yyyyMMdd') <= '${DATE_SUB1DAY}'
                and (arrive_late_count >0
                    or leave_early_count >0 or vac_punish_count >0)
            then date_format(work_shift_date,'yyyyMMdd') end) as t25_all_att --t25违规请假/迟到/早退天数
        ,count(distinct
            case when
                date_format(work_shift_date,'yyyyMMdd') >= date_format(date_sub(current_date,27),'yyyyMMdd') --'${DATE_SUB26DAY}'
                and date_format(work_shift_date,'yyyyMMdd') <= '${DATE_SUB1DAY}'
                and (arrive_late_count >0
                    or leave_early_count >0 or vac_punish_count >0)
            then date_format(work_shift_date,'yyyyMMdd') end) as t26_all_att --t26违规请假/迟到/早退天数
        ,count(distinct
            case when
                date_format(work_shift_date,'yyyyMMdd') >= date_format(date_sub(current_date,28),'yyyyMMdd') --'${DATE_SUB27DAY}'
                and date_format(work_shift_date,'yyyyMMdd') <= '${DATE_SUB1DAY}'
                and (arrive_late_count >0
                    or leave_early_count >0 or vac_punish_count >0)
            then date_format(work_shift_date,'yyyyMMdd') end) as t27_all_att --t27违规请假/迟到/早退天数
        ,count(distinct
            case when
                date_format(work_shift_date,'yyyyMMdd') >= date_format(date_sub(current_date,29),'yyyyMMdd') --'${DATE_SUB28DAY}'
                and date_format(work_shift_date,'yyyyMMdd') <= '${DATE_SUB1DAY}'
                and (arrive_late_count >0
                    or leave_early_count >0 or vac_punish_count >0)
            then date_format(work_shift_date,'yyyyMMdd') end) as t28_all_att --t28违规请假/迟到/早退天数
    from (
        select
            staff_code as staff_code_v1
            ,date_format(work_shift_date,'yyyy-MM-dd') as work_shift_date
            ,sum(coalesce(arrive_late_count,0)) as arrive_late_count
            ,sum(coalesce(leave_early_count,0)) as leave_early_count
            ,sum(coalesce(absenteeism_hours,0)) as absenteeism_hours
            ,sum(coalesce(vac_punish_count,0)) as vac_punish_count
        from attendance_info
        group by staff_code,date_format(work_shift_date,'yyyy-MM-dd')
    ) tmp
    group by staff_code_v1
),

should_leave_info as(
select
staff_code_v1 as staff_code
        ,"应离职" as protect_tag
        ,5 as protect_tag_detail
from(
select
a.staff_code_v1
,a.t6_abs
,a.t7_abs
,a.t28_abs
,a.t30_abs
,a.t85_abs
,a.t90_abs
,a.t95_abs
,a.t25_all_att
,a.t26_all_att
,a.t27_all_att
,a.t28_all_att
,a.emplid
,a.staff_name
,a.city_name
,a.position_cn
,a.position_class
,a.store_code
,a.store_name
,a.entry_date
,a.leave_date
,a.job_status
,a.is_district
,a.hours
,a.total_attend_days
,a.punish_scl
,a.will_score_scl
,a.store_type
,a.record_date
,a.district_code
,a.reward_level_district
,a.reward_level
,a.reward_level_night
,a.district_superfluity
,a.superfluity
      --店经理
,case when a.position_class in ('新架构负责人','老架构负责人') and a.t7_abs >= 2 then 1
      when a.position_class in ('新架构负责人','老架构负责人') and a.t30_abs >= 2 then 1
      when a.position_class in ('新架构负责人','老架构负责人') and a.t85_abs >= 3 and a.t95_abs >= 3 then 1
      when a.position_class in ('新架构负责人','老架构负责人') and a.t28_all_att >= 9 and a.t27_all_att >= 8 and a.t26_all_att >= 7 and a.t25_all_att >= 6 then 1
      --冗余机动队
      when a.position_class in ('新机动队','老机动队') and district_superfluity = '1' and a.t7_abs >= 1 then 1
      when a.position_class in ('新机动队','老机动队') and district_superfluity = '1' and a.t28_abs >= 2 then 1
      when a.position_class in ('新机动队','老机动队') and district_superfluity = '1' and a.t90_abs >= 3 then 1
      when a.position_class in ('新机动队','老机动队') and district_superfluity = '1' and a.t28_all_att >= 6 and a.t27_all_att >= 5 and a.t26_all_att >= 4 and a.t25_all_att >= 3 then 1
      --非冗余机动队
      when a.position_class in ('新机动队','老机动队') and district_superfluity <> '1' and a.t7_abs >= 1 and a.t6_abs >= 1 then 1
      when a.position_class in ('新机动队','老机动队') and district_superfluity <> '1' and a.t28_abs >= 2 then 1
      when a.position_class in ('新机动队','老机动队') and district_superfluity <> '1' and a.t90_abs >= 3 then 1
      when a.position_class in ('新机动队','老机动队') and district_superfluity <> '1' and a.t28_all_att >= 9 and a.t27_all_att >= 8 and a.t26_all_att >= 7 and a.t25_all_att >= 6 then 1
      --冗余店副/店员
      when a.position_class in ('新店副经理','老店副经理','新店员','老店员') and superfluity = '1' and a.t7_abs >= 1 then 1
      when a.position_class in ('新店副经理','老店副经理','新店员','老店员') and superfluity = '1' and a.t28_abs >= 2 then 1
      when a.position_class in ('新店副经理','老店副经理','新店员','老店员') and superfluity = '1' and a.t90_abs >= 3 then 1
      when a.position_class in ('新店副经理','老店副经理','新店员','老店员') and superfluity = '1' and a.t28_all_att >= 6
      and a.t27_all_att >= 5 and a.t26_all_att >= 4 and a.t25_all_att >= 3 then 1
      --非冗余店副/店员
      when a.position_class in ('新店副经理','老店副经理','新店员','老店员') and superfluity = 0 and a.t7_abs >= 1 and a.t6_abs >= 1 then 1
      when a.position_class in ('新店副经理','老店副经理','新店员','老店员') and superfluity = 0 and a.t28_abs >= 2 then 1
      when a.position_class in ('新店副经理','老店副经理','新店员','老店员') and superfluity = 0 and a.t90_abs >= 3 then 1
      when a.position_class in ('新店副经理','老店副经理','新店员','老店员') and superfluity = 0 and a.t28_all_att >= 9
      and a.t27_all_att >= 8 and a.t26_all_att >= 7 and a.t25_all_att >= 6 then 1
      else 0 end as should_leave
from(
select
tmp.*
,t1.*
,case when t4.store_code is null then '自营门店' else '加盟门店' end as store_type
,coalesce(t2.record_date,t3.record_date) as record_date
,t2.store_code_v1
,coalesce(t2.district_code,t3.district_code) as district_code
,coalesce(t2.reward_level_district,t3.reward_level_district) as reward_level_district
,t2.reward_level
,t2.reward_level_night
,coalesce(t2.district_superfluity,t3.district_superfluity,'1') as district_superfluity --如果是null则取1代表加盟店商圈冗余
,coalesce(t2.superfluity,'1') as superfluity --如果是null则取1代表加盟店门店冗余
    from att_ab_info tmp
    left join latest_ehr_infra t1
    on tmp.staff_code_v1 = t1.staff_code
    left join store_groups_recruit_gap t2
    on t1.store_code = t2.store_code_v1
    left join groups_recruit_gap t3
    on t1.store_name = t3.district_code
    left join data_build.pdw_bach_baseinfo_shop_shop t4
on t1.store_code = t4.store_code and t4.dt = '${DATE}' and t4.self_take_type = '4' --加盟店
) a
) b
where should_leave = '1'
)

,name_bd_match as (
    select
        IF(LENGTH(t1.emplid)<8,concat('10',t1.emplid),t1.emplid) AS staff_code --8位
        ,case
            when floor(datediff('${FDATE_SUB0DAY}',t2.resume_birth_date)/365) is null then '无年龄信息'
            when floor(datediff('${FDATE_SUB0DAY}',t2.resume_birth_date)/365) <= 22 then '疑似学生'
            else '非学生' end as position_tag
    from data_sec_dw.pdw_psprod_ps_blf_ehr_pers_vw t1
    left join data_gis_h3.dw_gis_hire_recruit_detail_v1_di t2
    on t2.dt = '${DATE_SUB1DAY}' and length(t2.entry_user_id) >2 and t1.hps_sys_name = t2.entry_user_id
    where t1.dt = '${DATE}'
        and t1.hps_dept_descr_lv1 in ('运营管理部A','运营管理部B','运营管理部X')
        and t1.hps_d_jobcode in ('店经理', '门店伙伴', '店员', '店副经理','社会PT', '学生PT', '见习店经理','内部合作经营者','内部合作辅助人','内部合作伙伴','外部合作经营者','外部合作辅助人','外部合作伙伴')
        and t1.hps_d_hr_status = '在职'
    group by
            IF(LENGTH(t1.emplid)<8,concat('10',t1.emplid),t1.emplid)
        ,case
            when floor(datediff('${FDATE_SUB0DAY}',t2.resume_birth_date)/365) is null then '无年龄信息'
            when floor(datediff('${FDATE_SUB0DAY}',t2.resume_birth_date)/365) <= 22 then '疑似学生'
            else '非学生' end
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

agree_list as( --晋升店副同意记录
SELECT
emplid
,flow_order_id
from data_shop.dwd_data_shop_sec_manager_tranfer_wage_match_view
where dt = '${DATE_SUB0DAY}'
and flow_order_status = 'FINISHED'
and flow_order_result = '1'
group by
emplid
,flow_order_id
)

,refuse_list as( --晋升店副拒绝激励
SELECT
t.emplid
,t.flow_order_id
from data_shop.dwd_data_shop_sec_manager_tranfer_wage_match_view t
left join agree_list t1 on t.flow_order_id = t1.flow_order_id
where t.dt = '${DATE_SUB0DAY}'
and t.flow_order_status = 'FINISHED'
and t.flow_order_result = '0'
and t1.flow_order_id is null
group by
t.emplid
,t.flow_order_id
)

,agree_num_list as( --同意数量
select
emplid
,count(distinct flow_order_id) as agree_num
from agree_list
group by
emplid
)

,refuse_num_list as(  --拒绝数量
select
emplid
,count(distinct flow_order_id) as refuse_num
from refuse_list
group by
emplid
)

,refuse_sec_manager_tranfer_data as(
SELECT 
    COALESCE(t1.emplid, t2.emplid) AS emplid, -- 合并姓名字段
    COALESCE(t1.agree_num, 0) AS agree_count, -- 如果左侧表没有数据，则默认同意次数为0
    COALESCE(t2.refuse_num, 0) AS disagree_count -- 如果中间表没有数据，则默认拒绝次数为0
FROM 
    agree_num_list t1
FULL OUTER JOIN 
    refuse_num_list t2
ON 
    t1.emplid = t2.emplid -- 根据姓名字段进行连接
)

,final_list as (
    select
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
        (case 
        --when t15.staff_code is not null and position_cn in ('门店伙伴','学生PT') and is_district = '0' then '铜牌' --20250722新增，学生PT冗余，部分降铜牌
        when t12.employ_no is not null and t12.protect_tag_detail = 2 then '普通' --员工标签异常反馈流程(032225)
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
                  when '6' then '普通'
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
            when '钻石' then '应保护'
            when '应保护' then '应保护'
            when '金牌' then '应保护'
            when '普通' then '普通'
            when '银牌' then '普通'
            when '优质银牌' then '普通'
            when '待观察' then '待观察'
            when '末位普通' then '末位普通'
            when '铜牌' then '末位普通'
            when '应离职' then '应离职'
            when '须努力' then '应离职'
        end as protect_tag
        ,case
        (case 
        --when t15.staff_code is not null and position_cn in ('门店伙伴','学生PT') and is_district = '0' then '铜牌' --20250722新增，学生PT冗余，部分降铜牌
        when t12.employ_no is not null and t12.protect_tag_detail = 2 then '普通' --员工标签异常反馈流程(032225)
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
                  when '6' then '普通'
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
            when '钻石' then '1'
            when '应保护' then '1'
            when '金牌' then '1'
            when '普通' then '2'
            when '银牌' then '2'
            when '优质银牌' then '2'
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
        ,case
        (case 
        --when t15.staff_code is not null and position_cn in ('门店伙伴','学生PT') and is_district = '0' then '铜牌' --20250722新增，学生PT冗余，部分降铜牌
        when t12.employ_no is not null and t12.protect_tag_detail = 2 then '普通' --员工标签异常反馈流程(032225)
        when t12.employ_no is not null and t12.protect_tag_detail = 4 then '末位普通' --员工标签异常反馈流程(032225)
        when t10.staff_code is not null and t10.protect_tag_detail = 2 then '普通'
        when t10.staff_code is not null and t10.protect_tag_detail = 1 then '应保护'
        when t7.staff_code is not null then '应离职' --政委输出的应离职list
            else coalesce(t3.protect_tag --出勤违规应离职
                ,if(t11.employee_id is not null --如果是店长，按照店长标签输出
                  ,(case t11.code 
                  when '0' then '钻石'
                  when '1' then '应保护'
                  when '2' then '普通'
                  when '3' then '待观察'
                  when '4' then '末位普通'
                  when '5' then '应离职'
                  when '6' then '优质银牌'
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
            when '钻石' then '0'
            when '应保护' then '1'
            when '金牌' then '1'
            when '普通' then '2'
            when '银牌' then '2'
            when '待观察' then '3'
            when '末位普通' then '4'
            when '铜牌' then '4'
            when '应离职' then '5'
            when '须努力' then '5'
            when '优质银牌' then '6'
        end as protect_tag_detail_new
    ,case when t13.staff_code is not null then '1' else '0' end as potential_leave
    ,COALESCE(t14.disagree_count,0) as refuse_sec_manager_num --历史拒绝晋升店副次数
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
    on t1.staff_code = t11.employee_id and from_unixtime(unix_timestamp(t11.dt,'yyyyMMdd'),'yyyy-MM-dd') = CASE 
         WHEN DAYOFWEEK('${FDATE_SUB0DAY}') = 2 THEN date_sub('${FDATE_SUB0DAY}',7) ELSE date_sub(next_day('${FDATE_SUB0DAY}','mon'),7) end
    left join data_build.dwd_staff_abnormal_label_list_da t12 on t1.staff_code = t12.employ_no and t12.dt = '${DATE}'
    and t12.cut_off_date >= '${FDATE_SUB0DAY}' --保护标签生效30天
    left join data_build.dwd_staff_give_potential_leave_da t13 on t1.staff_code = t13.staff_code and t13.dt = '${DATE_SUB1DAY}' and cast(t13.days_num as int) > 6 --到最后给班日连续7天及以上未给班
    left join refuse_sec_manager_tranfer_data t14 on t1.staff_code = t14.emplid
    left join data_shop.ods_uploads_ods_uploads_student_bronze_medal_details_v1 t15 on t1.staff_code = t15.staff_code
    group by
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
        ,t8.attendance_work_hours
        ,t8.total_attend_days
        ,t1.punish_scl
        ,t1.will_score_scl
        ,case
        (case 
        --when t15.staff_code is not null and position_cn in ('门店伙伴','学生PT') and is_district = '0' then '铜牌' --20250722新增，学生PT冗余，部分降铜牌
        when t12.employ_no is not null and t12.protect_tag_detail = 2 then '普通' --员工标签异常反馈流程(032225)
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
                  when '6' then '普通'
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
            when '钻石' then '应保护'
            when '应保护' then '应保护'
            when '金牌' then '应保护'
            when '普通' then '普通'
            when '银牌' then '普通'
            when '优质银牌' then '普通'
            when '待观察' then '待观察'
            when '末位普通' then '末位普通'
            when '铜牌' then '末位普通'
            when '应离职' then '应离职'
            when '须努力' then '应离职'
        end
        ,case
        (case 
        --when t15.staff_code is not null and position_cn in ('门店伙伴','学生PT') and is_district = '0' then '铜牌' --20250722新增，学生PT冗余，部分降铜牌
        when t12.employ_no is not null and t12.protect_tag_detail = 2 then '普通' --员工标签异常反馈流程(032225)
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
                  when '6' then '普通'
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
            when '钻石' then '1'
            when '应保护' then '1'
            when '金牌' then '1'
            when '普通' then '2'
            when '银牌' then '2'
            when '优质银牌' then '2'
            when '待观察' then '3'
            when '末位普通' then '4'
            when '铜牌' then '4'
            when '应离职' then '5'
            when '须努力' then '5'
        end
        ,'${DATE_SUB0DAY}'
        ,case when t1.position_cn <> '店经理' and t1.position_cn <> '学生PT'
            and t4.position_tag = '疑似学生' and t6.staff_code is null then 1 else 0 end
        ,case when t9.store_manager_no is not null then '1' else '0'
        end
        ,case when t8.attendance_work_hours < 60 then '1-[0,60)'
            when t8.attendance_work_hours < 200 then '2-[60,200)'
            when t8.attendance_work_hours < 600 then '3-[200,600)'
            else '4-[600,+)'
        end
        ,t1.emplid
        ,t1.is_district
        ,case
        (case 
        --when t15.staff_code is not null and position_cn in ('门店伙伴','学生PT') and is_district = '0' then '铜牌' --20250722新增，学生PT冗余，部分降铜牌
        when t12.employ_no is not null and t12.protect_tag_detail = 2 then '普通' --员工标签异常反馈流程(032225)
        when t12.employ_no is not null and t12.protect_tag_detail = 4 then '末位普通' --员工标签异常反馈流程(032225)
        when t10.staff_code is not null and t10.protect_tag_detail = 2 then '普通'
        when t10.staff_code is not null and t10.protect_tag_detail = 1 then '应保护'
        when t7.staff_code is not null then '应离职' --政委输出的应离职list
            else coalesce(t3.protect_tag --出勤违规应离职
                ,if(t11.employee_id is not null --如果是店长，按照店长标签输出
                  ,(case t11.code 
                  when '0' then '钻石'
                  when '1' then '应保护'
                  when '2' then '普通'
                  when '3' then '待观察'
                  when '4' then '末位普通'
                  when '5' then '应离职'
                  when '6' then '优质银牌'
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
            when '钻石' then '0'
            when '应保护' then '1'
            when '金牌' then '1'
            when '普通' then '2'
            when '银牌' then '2'
            when '待观察' then '3'
            when '末位普通' then '4'
            when '铜牌' then '4'
            when '应离职' then '5'
            when '须努力' then '5'
            when '优质银牌' then '6'
        end
    ,case when t13.staff_code is not null then '1' else '0' end
    ,COALESCE(t14.disagree_count,0)
            )
          

insert overwrite table ${TABLE_NAME} partition(dt='$DATE')

            select 
            t1.staff_code
        ,t1.staff_name
        ,t1.city_name
        ,case when t1.student_suspect = 1 and t2.staff_code is not null and t2.suspect_result = '已确认为门店伙伴' then '门店伙伴' 
        when t1.student_suspect = 1 and t2.staff_code is not null and t2.suspect_result = '已确认为学生PT' then '学生PT' else t1.position_cn
        end as position_cn
        ,t1.position_class
        ,t1.store_code
        ,t1.store_name
        ,t1.entry_date
        ,t1.leave_date
        ,t1.job_status
        ,t1.hours
        ,t1.total_attend_days
        ,t1.punish_scl
        ,t1.will_score_scl
        ,t1.protect_tag
        ,t1.protect_tag_detail
        ,t1.valid_dt
        ,case when t1.student_suspect = 1 and t2.staff_code is not null then 0 else t1.student_suspect end as student_suspect
        ,t1.is_manager
        ,t1.mature_level
        ,t1.emplid
        ,t1.is_district
        ,case when t1.protect_tag_detail = 2 and t3.protect_tag_raw <= 4.4 then 1 when t1.protect_tag_detail = 1 then 1 else 0 end as is_quality
        ,t1.protect_tag_detail_new
        ,t1.potential_leave
        ,refuse_sec_manager_num

            from final_list t1 
            left join data_shop.ods_uploads_suspect_result_v2 t2 on t1.staff_code = t2.staff_code
            left join protect_tag_raw_mon t3 on t1.staff_code = t3.staff_code


union all





            select 
            staff_code
        ,staff_name
        ,city_name
        ,'门店伙伴' as position_cn
        ,position_class
        ,store_code
        ,store_name
        ,entry_date
        ,leave_date
        ,job_status
        ,hours
        ,total_attend_days
        ,punish_scl
        ,will_score_scl
        ,'应保护' as protect_tag
        ,'1' as protect_tag_detail
        ,valid_dt
        ,student_suspect
        ,is_manager
        ,mature_level
        ,emplid
        ,is_district
        ,'1' as is_quality
        ,protect_tag_detail_new
        ,potential_leave
        ,refuse_sec_manager_num

            from data_shop.dm_shop_staff_protect_tag_v2 
            where dt = 20220424
            and staff_code = '11143517'




;

EOF
}


##校验模块，展示数据条数
function do_check {
    $HIVE -e "

    select
        sum(origin_num)>0,concat('数据条数必须大于0！','总条数：',sum(origin_num)),
        count(1)=sum(origin_num),concat('唯一键唯一！','重复条数：',sum(origin_num)-count(1))
    from
        (select
            ${UNIQ_KEY},
            count(1) as origin_num--求和后为总数据条数
        from ${TABLE_NAME}
        where dt = '${DATE}'
        group by ${UNIQ_KEY}
        ) as t--去重

    " | $PYTHON $CHECK
    # 解决check脚本执行错误无法捕捉的问题
    if [ "0 0" != "${PIPESTATUS[*]}" ]; then return 127; fi
}