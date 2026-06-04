--app_internal_control_roster_refused_da
# --------------------------------------
# DATE: 20220328
# OUT:  app_internal_control_roster_refused_da
# DEV:  yan.li14
# DESC: 员工拒绝相关惩处数据统计-提供薪酬组使用
# NOTE: https://wiki.corp.bianlifeng.com/pages/viewpage.action?pageId=807047111&focusedCommentId=823237215#comment-823237215
# --------------------------------------

source ${ETC}/format_date.cnf
DATABASE="data_smartorder"
export TABLE_NAME="app_internal_control_roster_refused_da"
export NOT_VERIFIED_TABLE_NAME="not_verified_${TABLE_NAME}"
UNIQ_KEY="concat(employee_no,store_code,target_date,start_time,end_time)"
HDFS_DIR="/user/data_smartorder/app/${TABLE_NAME}/dt=${DATE}"

##JOB入口函数
function app_internal_control_roster_refused_da_run {
   rebuild_hdfs_dir $HDFS_DIR &&calculate  && do_check && drop_partition  && add_partition && analyze_table
    #calculate
    ret=$?
    return $ret

}


function calculate {

    --$HIVE -e << EOF "
use data_smartorder;
with tmp_app_internal_control_roster_refused_da_attendance_plan_shift_confirm_20220327 as
(select id,
employee_no, --原始员工id
lpad(employee_no,8,'10') employee_id_8, -- 8位工号
store_code, -- 门店
target_date, -- 排班日期
case when target_date>=current_date() then date_sub(current_date,1) else target_date end target_date_f,
start_time, -- 排班开始时间
end_time,-- 排班结束时间
if((end_time-start_time)>6,end_time - start_time - 0.5,end_time - start_time) AS diff_hours, -- 影响班次时长：大于6时，减0.5 休息工时
old_roster_id,
old_roster_type,
case when confirm_status=5 then '人工核实拒绝' when confirm_status=6 then '系统超时拒绝' end refused_status, -- 拒绝方式  5，6
reject_type, -- 拒绝类型
-- reject_reason,
create_user,
create_time,-- 拒绝时间
dt,
row_number() over(partition by substring(target_date,1,7),employee_no order by target_date asc,id asc) rank_create_flow, -- 惩处发起时间排序
row_number() over(partition by target_date,employee_no order by flow_create_time desc) rank_begin_check_flow, -- 确认流程发起时间排序  倒序
sum(if((end_time-start_time)>6,end_time - start_time - 0.5,end_time - start_time) ) over(partition by target_date,employee_no order by flow_create_time desc) sum_begin_check_flow, -- 应记惩处时长：按班次时长计算，每个排班日期不超过12小时，超过时，按照班次确认任务由近及远的顺序，取前12个小时
-- 惩处系数：请假发起时间若在原班次开始时间的T-3日18点之前，惩处系数为0.5；若在T-3日18点之后，若影响班次时长<4，惩处系数为1，否则为2
concat(date_sub(target_date,3),' 18:00:00') t_3_18_timepoint,
concat(date_sub(target_date,1),' 00:00:00') t_1_0_timepoint,
-- case when substring(flow_create_time,1,19)>= concat(date_sub(to_date(target_date),1),' 00:00:00') then 1 else 0 end is_flow_begin_eliminate,  -- 班次确认任务时间在班次日期前一天0点之后，剔除
case when substring(flow_create_time,1,19)>= concat(date_sub(to_date(target_date),2),' 18:00:00') then 1 else 0 end is_flow_begin_eliminate,  -- 班次确认任务时间在班次日期前2天18点之后，剔除
case when
 substring(create_time,1,19)<= concat(date_sub(to_date(target_date),3),' 18:00:00') then 0.5
 when substring(create_time,1,19)>concat(date_sub(to_date(target_date),3),' 18:00:00')
 and
 if((end_time-start_time)>6,end_time - start_time - 0.5,end_time - start_time) < 4.0
 then 1
 else 2 end penalty_coefficient,flow_create_time,workflow_no,flow_mployee_no
from
-- 同时间段，如果有多次拒绝记录，取最早的一次，不管后面有没有同意。按人 日 班次维度看
(select id, employee_no, store_code, target_date, start_time, end_time, old_roster_id, old_roster_type, confirm_status, reject_type, reject_reason, create_user, create_time, dt,
row_number() over(partition by employee_no,target_date,start_time, end_time order by id asc ) rn,
flow_create_time,workflow_no,flow_mployee_no
from
(
select a.*,b.create_time flow_create_time,b.workflow_no,b.employee_no as flow_mployee_no
from
(select * from data_smartorder.dm_copy_pdw_opc_roster_plan_shift_confirm_history_view t where dt='${DATE}'
and confirm_status in (5,6) )a
left join
(select old_roster_id,create_time,workflow_no,t.employee_no
from dm_copy_pdw_opc_roster_plan_shift_confirm_workflow_view t
lateral view explode (hivemall.json_split(confirm_shift_ids) ) x as old_roster_id
where dt='${DATE}')b
on a.old_roster_id=b.old_roster_id
) t  )t
where rn=1
),

-- 排班数据
tmp_app_internal_control_roster_refused_da_attendance_20220327 as
(select lpad(employee_no,8,'10') employee_id_8,employee_no,
 work_shift_date,
 sum(attendance_work_hours)  attendance_work_hours
 from data_smartorder.dm_copy_pdw_opc_shop_attendance_report_work_shift_view t
 where dt='${DATE}'
and work_shift_date>='2022-02-01'

group by employee_no,
 work_shift_date
),
-- 门店基础信息
store_info as
(select a.*,b.store_city
from
(select * from  data_smartorder.dw_ordering_store_tag_construction_element_info_di t where dt='${DATE_SUB1DAY}' )a
join (select store_code  dim_store_code,store_name,store_city from default.dim_store_info where dt='${DATE}' and store_type=0) b
on a.store_code=b.dim_store_code
),
-- 员工架构
staff_dept as
(select
concat_ws('-',substring(dt,1,4),substring(dt,5,2),substring(dt,7,2)) staff_dept_work_date,
 staff_code employee_id_8,staff_name,
hps_dept_code_lv5 as store_code,hps_dept_descr_lv1
from data_smartorder.dim_roster_store_staff_info_da t
where dt>=20220101

),
base_data as(

select
a.id
,a.employee_no
,a.employee_id_8
,d.staff_name
,d.store_code as dept_store_code
,a.store_code
,b.store_name
,b.store_city
,a.target_date
,a.target_date_f
,a.start_time
,a.end_time
,a.diff_hours
,case when sum_begin_check_flow<=12.0 then diff_hours else if(diff_hours-(sum_begin_check_flow-12)<0,0,diff_hours-(sum_begin_check_flow-12)) end diff_hours_f
,sum_begin_check_flow
,a.old_roster_id
,a.old_roster_type
,a.refused_status
,a.reject_type
,a.create_user
,a.create_time
,a.dt
,case when a.rank_create_flow=2 and target_date<='2023-02-10' then 1 else rank_create_flow end  rank_create_flow
,a.rank_begin_check_flow
,a.t_3_18_timepoint
,a.t_1_0_timepoint
,is_flow_begin_eliminate
,a.penalty_coefficient
,b.element_name_list
,sum(case when  work_shift_date>=date_sub(target_date,6) and work_shift_date<target_date then attendance_work_hours else 0 end) attendance_work_hours -- 剔除条件1 前6日累计工时，不包括当日
,case when case when a.rank_create_flow=2 and target_date<='2023-02-10' then 1 else rank_create_flow end <2 then 1 else 0 end is_exemption -- 每月排序前两条豁免 202302变更 https://be3.cc/sharp/68FV0m
,case when d.store_code=a.store_code then 0 when nvl(is_kindergarten,0) +nvl(is_primary_school,0) +nvl(is_middle_school,0)+nvl(is_university,0)+nvl(is_station,0)>0 then 1 else 0 end is_location_eliminate -- 剔除条件2
,flow_create_time,workflow_no,flow_mployee_no
from
tmp_app_internal_control_roster_refused_da_attendance_plan_shift_confirm_20220327 a
join store_info b
on a.store_code=b.store_code
left join tmp_app_internal_control_roster_refused_da_attendance_20220327 c
on a.employee_id_8=c.employee_id_8
left join staff_dept d
on a.employee_id_8=d.employee_id_8 and a.target_date_f=d.staff_dept_work_date
where d.hps_dept_descr_lv1<>'运营管理部X' or d.hps_dept_descr_lv1 is null
group by
a.id
,a.employee_no
,a.employee_id_8
,a.store_code
,b.store_name
,b.store_city
,a.target_date
,a.target_date_f
,a.start_time
,a.end_time
,a.diff_hours
,case when sum_begin_check_flow<=12.0 then diff_hours else diff_hours-(sum_begin_check_flow-12) end
,sum_begin_check_flow
,a.old_roster_id
,a.old_roster_type
,a.refused_status
,a.reject_type
,a.create_user
,a.create_time
,a.dt
,case when a.rank_create_flow=2 and target_date<='2023-02-10' then 1 else rank_create_flow end
,a.rank_begin_check_flow
,a.t_3_18_timepoint
,a.t_1_0_timepoint
,is_flow_begin_eliminate  -- 班次确认任务时间在班次日期前一天0点之后，剔除
,a.penalty_coefficient
,d.staff_name
,d.store_code
,b.element_name_list,flow_create_time,workflow_no,flow_mployee_no
,case when case when a.rank_create_flow=2 and target_date<='2023-02-10' then 1 else rank_create_flow end <2 then 1 else 0 end  -- 每月排序前两条豁免 202302变更 https://be3.cc/sharp/68FV0m
,case when d.store_code=a.store_code then 0 when nvl(is_kindergarten,0) +nvl(is_primary_school,0) +nvl(is_middle_school,0)+nvl(is_university,0)+nvl(is_station,0)>0 then 1 else 0 end
)
INSERT OVERWRITE TABLE $DATABASE.$NOT_VERIFIED_TABLE_NAME partition(dt = '${DATE}')
select
a.*,
case when attendance_work_hours>60 then 0 else 0 end is_attendance_eliminate, -- pageId=1197212631    202304
is_flow_begin_eliminate +
case when attendance_work_hours>60 then 0 else 0 end -- pageId=1197212631  202304
+ is_location_eliminate + is_exemption as is_exemption_eliminate, -- 是否剔除
case when
case when attendance_work_hours>60 then 0 else 0 end   -- pageId=1197212631  202304
+ is_location_eliminate + is_exemption + is_flow_begin_eliminate
+ 0 = 0
then penalty_coefficient * diff_hours_f else 0  end penalty_roster_hours, -- 最终惩处工时：影响班次时长*惩处系数
substring(a.target_date,1,7) roster_month,
b.hps_hire_dt, -- 入职日期
c.parent_source,-- 拒绝的原始班次的来源
0 is_new_staff_exemption -- 新人豁免
,nvl(shop.is_franchise, 0) as is_franchise
from base_data  a
 left join (
 select staff_code, string(to_date(hps_hire_dt)) hps_hire_dt  from data_smartorder.dim_roster_store_staff_info_da t where dt=date_format(date_sub(current_date,1),'yyyyMMdd')
 ) b
 on string(a.employee_id_8)=string(b.staff_code)
left join
(SELECT parent_old_roster_id,
       parent_source
FROM data_smartorder.dw_roster_trace_shift_da t
WHERE dt='${DATE}' -- and parent_old_roster_id='20423957'
and target_target_date > date_format(date_sub(current_date,365),'yyyy-MM-dd')
group by parent_old_roster_id,parent_source)c
on string(a.old_roster_id)=string(c.parent_old_roster_id)

-- 加盟店信息
      left join (select concat(substr(dt,1,4),'-',substr(dt,5,2),'-',substr(dt,7,2)) as join_date, code as store_code, 1 as is_franchise
              from data_smartorder.dm_copy_ods_bach_baseinfo_shop_shop_view a
              where dt>='20230801'
              and self_take_type in (4,5)) shop
      on a.dept_store_code = shop.store_code
      and a.target_date = shop.join_date

"
;

EOF
if [ $? -ne 0 ] ; then return 127 ; fi

}



##删除输出表分区
function drop_partition {
    $HIVE << EOF
        alter table $DATABASE.$TABLE_NAME drop if exists partition (dt = '${DATE}');
EOF
}

##添加输出表分区
function add_partition {
    $HIVE << EOF
        alter table $DATABASE.$TABLE_NAME add if not exists partition (dt = '${DATE}');
EOF
}

## 加载输出表statistics信息
function analyze_table {
    $HIVE << EOF
        analyze table $DATABASE.$TABLE_NAME partition(dt = '${DATE}') compute statistics;
EOF
}
## 输出表业务逻辑校验
function do_check {
    $HIVE -e "
        SELECT
            COUNT(*) > 0 ,'数据条数大于0',
            count(1)=count(distinct $UNIQ_KEY), '唯一键唯一',
            sum(is_exemption_eliminate)>0, '豁免剔除数据大于0',
            sum(is_exemption)>0, '豁免数据大于0',
            sum(is_location_eliminate)>0, '剔除数据大于0',
            sum(is_exemption_eliminate)>0, '剔除数据大于0',
            sum(is_flow_begin_eliminate)>0, '剔除数据大于0',
            sum(penalty_roster_hours)>0, '最终惩处工时不等于0',
            sum(attendance_work_hours)>0, '班次开始时间前6自然日的工时汇总大于0',
            max(rank_create_flow)>2, '豁免排序大于2',
            sum(sum_begin_check_flow)>0, 'sum over check',
            sum(if(start_time is null,1,0))/sum(1)<0.1, '列空值率小于10%'
        FROM  $DATABASE.$NOT_VERIFIED_TABLE_NAME
       WHERE dt='${DATE}'
    " | $PYTHON $CHECK
    # 解决check脚本执行错误无法捕捉的问题
    if [ "0 0" != "${PIPESTATUS[*]}" ]; then return 127; fi
}
