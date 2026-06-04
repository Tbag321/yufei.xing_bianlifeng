with e as(
SELECT
business_id as e_id
,max(get_json_object(data,'$.manualCountJobVO.collectSubmitTime')) as max_collectSubmitTime
,max(get_json_object(data,'$.manualCountJobVO.latestReceiveTime')) as max_latestReceiveTime
from pdw_opc_flag_business_info
where dt = 20220126
GROUP BY business_id),
d as(
select
task_id as d_id
,max(audit_submit_time) as max_audit_submit_time
,max(uncountable_hour) as uncountable_hour
from data_build.dwd_store_construction_info_stat_audit_info_v1
where dt = 20220126
GROUP BY task_id)
select
t1.business_id
,t1.version
,get_json_object(t1.data,'$.manualCountJobVO.cityName') AS `城市`
,get_json_object(t1.data,'$.manualCountJobVO.projectName') AS `统计对象名称`
,get_json_object(t1.data,'$.manualCountJobVO.statPointName') AS `统计点名称`
,get_json_object(t1.data,'$.manualCountJobVO.statBeginTime') AS `开始时间`
,get_json_object(t1.data,'$.manualCountJobVO.statEndTime') AS `结束时间`
,get_json_object(t1.data,'$.manualCountJobVO.applicantId') AS `人工计数申请人`
,get_json_object(t1.data,'$.manualCountJobVO.status') AS `状态`
,get_json_object(t1.data,'$.manualCountJobVO.counterId') AS `统计员`
,get_json_object(t1.data,'$.manualCountJobVO.counterName') AS `统计员姓名`
,get_json_object(t1.data,'$.manualCountJobVO.submitTime') AS `统计员提交时间`
,get_json_object(t1.data,'$.manualCountJobVO.collectSubmitTime') AS `采集提交时间`
,get_json_object(t1.data,'$.manualCountJobVO.expectFeedbackTime')
,get_json_object(t1.data,'$.manualCountJobVO.latestReceiveTime') AS `最新收卡时间`
,get_json_object(t1.data,'$.manualCountJobVO.latestMatchTime') AS `最新匹配时间`
,get_json_object(t1.data,'$.manualCountJobVO.isReceiveCard') AS `是否收卡`
,get_json_object(t1.data,'$.manualCountJobVO.isMatch') AS `是否匹配`
,get_json_object(t1.data,'$.manualCountJobVO.auditProcess')
,get_json_object(t1.data,'$.manualCountJobVO.taskDetailId')
,get_json_object(t1.data,'$.manualCountJobVO.dataVersion')
,get_json_object(t1.data,'$.manualCountJobVO.auditorId')
,get_json_object(t1.data,'$.manualCountJobVO.auditorName')
,get_json_object(t1.data,'$.manualCountJobVO.counterRemark')
,get_json_object(t1.data,'$.manualCountJobVO.auditorRemark')
,get_json_object(t1.data,'$.manualCountJobVO.cancelId') AS `取消员`
,get_json_object(t1.data,'$.manualCountJobVO.cancelName') AS `取消员姓名`
,get_json_object(t1.data,'$.manualCountJobVO.cancelRemark') AS `取消统计原因`
,get_json_object(t1.data,'$.manualCountJobVO.cancelTime') AS `取消时间`
,case
when row_number()over(partition by business_id order by version desc) = 1 then '最后一次提交' else '非最后一次提交' end
,row_number()over(partition by business_id order by get_json_object(data,'$.manualCountJobVO.collectSubmitTime') desc) 
,t2.audit_process AS `审核进度`
,t2.manual_job_audit_status AS `审核状态`
,t3.flag_code AS `项目插旗编码`
,t3.package_status AS `总需求状态`
,t3.subject_status AS `科目状态`
,t3.project_type AS `项目类型`
,t3.element_flag_type AS `旗标类型`
,t4.max_collectSubmitTime AS `采集最晚提交时间`
,t4.max_latestReceiveTime AS `最晚收卡时间`
,t5.max_audit_submit_time AS `最晚抽审时间`
,t5.uncountable_hour AS `不可用时长`
from default.pdw_opc_flag_business_info t1
left join pdw_opc_flag_stat_jobs t2 on t1.business_id = t2.id and t2.dt = 20220126
left join data_build.dwd_store_construction_measure_task_v1 t3 on t1.business_id = t3.atom_task_id and t3.dt = 20220126
left join e t4 on t1.business_id = t4.e_id
left join d t5 on t1.business_id = t5.d_id
where t1.dt = 20220126
and to_date(get_json_object(t1.data,'$.manualCountJobVO.statBeginTime')) between '2022-01-01' and '2022-01-25'