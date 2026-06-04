with project_data as (
select a.project_name,
b.name as city_name,
a.flag_code,
a.id as project_id
from data_build.pdw_opc_flag_project_upload_info a
left join pdw_opc_flag_city_info b
on a.city_id = b.id and b.dt='${today-1}'
where a.dt='${today-1}'
),

project_distance_delay_data as (--项目维度
select
 project_id,
 task_id,
 version,
 work_flow_id,
 initiator as delay_apply_name, --发起人
 init_time as delay_apply_time, --大于>申请日期
 delay_days as delay_days, --延期天数
 delay_reason as delay_reason, --延期原因，是个list
 remark as delay_remark, --延期备注
 row_number()over(PARTITION BY project_id ORDER BY init_time DESC) as r_n
 from pdw_opc_flag_task_delay_ha --项目+任务+类型维度
 where dt='${today}'
 and hr ='05'--好像有的小时会漏数据
 and state ='20' --工作流申请状态，0初始化 10申请中 20已申请
 and business_type ='3' --1门前客流 2腹地商圈 3滚轮测距 4竞争店铺
),

poi_distance_detail as ( --刨去task表'REBUT'状态的所有项目后,加入日志表中所有'REBUT'数据,目的为加入老项目曾经'REBUT'丢失的数据
select
 cast(a.task_id as string) task_id,
 a.start_point,
 a.start_poi,
 a.end_point,
 a.end_poi,
 a.start_point_type,
 a.end_point_type,
 a.state,
 get_json_object(a.measure_info,'$.canMeasure') canMeasure,
 get_json_object(a.measure_info,'$.submitUserId') submitUserId,
 get_json_object(a.measure_info,'$.submitUserName') submitUserName,
 if(length(get_json_object(a.measure_info,'$.submitTime'))<=17,concat(get_json_object(a.measure_info,'$.submitTime'),':00'),get_json_object(a.measure_info,'$.submitTime')) submitTime,
 get_json_object(a.measure_info,'$.submitRemark') submitRemark,
 get_json_object(a.measure_info,'$.auditUserId') auditUserId,
 get_json_object(a.measure_info,'$.auditUserName') auditUserName,
 if(length(get_json_object(a.measure_info,'$.auditTime'))<=17,concat(get_json_object(a.measure_info,'$.auditTime'),':00'),get_json_object(a.measure_info,'$.auditTime')) auditTime,
 get_json_object(a.measure_info,'$.auditRemark') auditRemark,
 get_json_object(a.measure_info,'$.actualDistance') actualDistance,
 '1' is_detail_new,
 get_json_object(a.measure_info,'$.measureVideoUrls') measureVideoUrls,
 b.name noMeasureReason,
 get_json_object(a.measure_info,'$.submitCount') submitCount,
 get_json_object(a.measure_info,'$.auditCount') auditCount
from pdw_opc_flag_poi_distance_detail a
left join pdw_bach_baseinfo_goblin_dict b
on get_json_object(a.measure_info,'$.noMeasureReason')=b.value
and b.type='flag_no_measure_reason'
and b.dt='${today-1}'
where a.dt='${today-1}' and a.state<>'REBUT'

union all

select
 get_json_object(a.content,'$.poiDistanceDetail.taskId') task_id,
 get_json_object(a.content,'$.poiDistanceDetail.startPoint') start_point,
 get_json_object(a.content,'$.poiDistanceDetail.startPoi') start_poi,
 get_json_object(a.content,'$.poiDistanceDetail.endPoint') end_point,
 get_json_object(a.content,'$.poiDistanceDetail.endPoi') end_poi,
 get_json_object(a.content,'$.poiDistanceDetail.startPointType.name') start_point_type,
 get_json_object(a.content,'$.poiDistanceDetail.endPointType.name') end_point_type,
 get_json_object(a.content,'$.poiDistanceDetail.state.name') state,
 get_json_object(a.content,'$.poiDistanceDetail.measureInfo.canMeasure'),
 get_json_object(a.content,'$.poiDistanceDetail.measureInfo.submitUserId'),
 get_json_object(a.content,'$.poiDistanceDetail.measureInfo.submitUserName'),
 if(length(get_json_object(a.content,'$.poiDistanceDetail.measureInfo.submitTime'))<=17,concat(get_json_object(a.content,'$.poiDistanceDetail.measureInfo.submitTime'),':00'),get_json_object(a.content,'$.poiDistanceDetail.measureInfo.submitTime')),
 get_json_object(a.content,'$.poiDistanceDetail.measureInfo.submitRemark'),
 get_json_object(a.content,'$.poiDistanceDetail.measureInfo.auditUserId'),
 get_json_object(a.content,'$.poiDistanceDetail.measureInfo.auditUserName'),
 if(length(get_json_object(a.content,'$.poiDistanceDetail.measureInfo.auditTime'))<=17,concat(get_json_object(a.content,'$.poiDistanceDetail.measureInfo.auditTime'),':00'),get_json_object(a.content,'$.poiDistanceDetail.measureInfo.auditTime')),
 get_json_object(a.content,'$.poiDistanceDetail.measureInfo.auditRemark'),
 get_json_object(a.content,'$.poiDistanceDetail.measureInfo.actualDistance'),
 '1' is_detail_new,
 get_json_object(a.content,'$.poiDistanceDetail.measureInfo.measureVideoUrls'),
 b.name,
 get_json_object(a.content,'$.poiDistanceDetail.measureInfo.submitCount'),
 get_json_object(a.content,'$.poiDistanceDetail.measureInfo.auditCount')
from pdw_opc_flag_business_log a
left join pdw_bach_baseinfo_goblin_dict b
on get_json_object(a.content,'$.poiDistanceDetail.measureInfo.noMeasureReason')=b.value
and b.type='flag_no_measure_reason'
and b.dt='${today-1}'
where a.dt='${today-1}'
and a.biz_type='distance_info'
and get_json_object(a.content,'$.poiDistanceDetail.state.name')='REBUT'
),

distance_data as (
 select
 a.id --主键
 ,a.city_id --城市id
 ,h.name city_name
 ,a.apply_user_id --申请人
 ,a.apply_time --申请时间
 ,a.biz_type --业务类型
 ,a.biz_id --当biz_type='project'时即为'project_id'，后续业务会加入统计点数据
 ,a.biz_object_name --业务数据名称
 ,a.state task_state--任务状态
 ,a.actual_feedback_time --实际反馈时间
 ,a.expect_feedback_time --承诺反馈时间
 ,a.calc_feedback_rule --计算承诺反馈时间规则类型
 --,a.content --内容
 ,a.create_time --创建时间
 ,a.update_time --更新时间
 ,b.canMeasure --是否需要测距
 ,b.actualDistance--到店实距
 ,b.submitUserId --提交人id
 ,b.submitUserName --提交人
 ,b.submitTime --提交日期
 ,b.auditUserId --审核人id
 ,b.auditUserName --审核人
 ,b.auditCount --审核次数
 ,b.auditTime --审核时间
 ,b.submitRemark --提交备注
 ,b.auditRemark --审核备注
 ,b.noMeasureReason --无需测距原因
 ,b.end_poi --目标旗标编号
 ,b.end_point --目标旗标名称
 ,b.end_point_type
 ,b.start_poi --旗标编号
 ,g.name start_poi_name--旗标名称
 ,b.start_point --统计点编号
 ,f.name start_point_name--统计点名称
 ,b.start_point_type
 ,b.state audit_state--审核状态 ACCEPT已通过 INIT待提交 REBUT已驳回 SUBMIT已提交
 ,d.delay_apply_time --延期申请时间
 ,d.delay_days --延期天数
 ,d.delay_reason --延期原因
 ,d.delay_remark --延期备注
 from pdw_opc_flag_poi_distance_task a
 left join poi_distance_detail b on a.id = b.task_id
 --left join business_log c on c.task_id = a.id --c.biz_id = b.id
 left join project_distance_delay_data d on a.id = d.task_id
 --left join pdw_bach_baseinfo_goblin_dict e on e.type ='flag_no_measure_reason' and e.value = c.noMeasureReason and e.dt ='${today-1}'
 left join pdw_opc_flag_stat_point_info f on b.start_point = f.flag_code and b.start_point_type ='STAT_POINT' and f.dt ='${today-1}'
 left join pdw_opc_flag_poi_info g on g.code = b.end_poi and g.dt = '${today-1}'
 left join pdw_opc_flag_city_info h on a.city_id = h.id and h.dt='${today-1}'
 where a.biz_type ='PROJECT'
 and a.dt ='${today-1}'
 --and a.id > '18046' --新系统倒数老系统最后一条数据 select min(id) from pdw_opc_flag_poi_distance_task where dt='20210429' and apply_user_id<>'',倒过来的老数该字段都是空的
)


select
t1.city_name
,t1.biz_id --项目ID
,t5.project_name --项目名称
,t5.flag_code --项目旗标编号
,t1.id --任务id
,t1.end_poi--目标旗标编号
,t1.end_point --目标旗标名称
,t1.start_poi --旗标编号
,t1.start_poi_name --旗标名称
,t1.start_point --统计点编号
,t1.start_point_name --统计点名称
,t3.type_name --旗标类型
,t4.name --要素类型
,t1.apply_time --规划申请时间
,case when t1.canMeasure = '是' then '是'
 else '无需测距' end can_measure --是否需要测距
,t1.noMeasureReason --无需测距原因
,t1.actualDistance --人工测距
,t1.submitUserName --提交人
,t1.submitUserId --提交人id
,t1.submitTime --提交时间
,case when t6.department_name like '%信息部%' then '信息部'
 when t6.department_name like '%开发部%' then '开发部'
 else null end submitUsertype --提交人归属
,t1.auditUserName --审核人
,t1.auditUserId --审核人id
,t1.auditCount --审核次数
,t1.auditTime --审核时间
,t1.audit_state --审核状态
,t1.submitRemark --提交备注
,t1.auditRemark --审核备注
,t1.delay_apply_time --延期申请时间
,t1.delay_days --延期天数
,t1.delay_reason --延期原因
,t1.delay_remark --延期备注
from distance_data t1
left join
(
 select
 *,if(type_id=3,'flag_facilities_type',if(type_id=4,'flag_traffic_type','')) type
 ,if(type_id=3,nvl(hivemall.json_split(get_json_object(data,'$.roomType'))[0],get_json_object(data,'$.roomType')),if(type_id=4,get_json_object(data,'$.flagType'),'')) relate_value
 from data_build.pdw_opc_flag_flag_poi 
 where dt = '${today-1}'
) t3 on t3.code = t1.start_poi --这里是旗标编号,不是end_poi,因为目前都是门店或竞对
left join pdw_bach_baseinfo_goblin_dict t4 on t4.type in ('flag_facilities_type', 'flag_traffic_type') and t3.type = t4.type and t3.relate_value = t4.value and t4.dt ='${today-1}'
left join project_data t5 on t1.biz_id = t5.project_id
left join dim_user_hr t6 on t1.submitUserId = t6.user_name and t6.dt ='${today-1}'
where --t1.flag_code is not null and 
to_date(t1.submitTime) >= trunc('${TODAY}','MM')
order by t5.flag_code,t1.submitTime desc