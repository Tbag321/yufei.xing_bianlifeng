select 
 t1.order_id
 ,t1.taskorder_id
 ,t1.taskorder_node_id
 ,t1.taskorder_status
 ,t1.taskorder_result
 ,taskorder_handler
 ,t1.taskorder_create_time
 ,t1.taskorder_deadline_time
 ,t1.rn
 ,get_json_object(x2.formVariables,'$.name') as taskop_name
 ,regexp_replace(get_json_object(x2.formVariables,'$.values.label'),'^\\\[\"|"\\\]$','') as taskop_values
 from (
 select 
 order_id
 ,taskorder_id
 ,taskorder_node_id
 ,taskorder_status
 ,task_orders
 ,taskorder_result
 ,taskorder_oplogs
 ,get_json_object(get_json_object(task_orders,'$.handler'),'$.[0].code') as taskorder_handler
 ,get_json_object(task_orders,'$.createTime')as taskorder_create_time
 ,get_json_object(task_orders,'$.deadLineTime')as taskorder_deadline_time
 ,row_number()over(partition by (order_id) order by taskorder_create_time desc) as rn --取最新分区的order
 from pdw_order_store_211_order_detail_flow_task_taskorders
 where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
 and taskorder_node_id = 'UserTask_08jfekk')t1
 lateral view explode(hivemall.json_split(t1.taskorder_oplogs)) x as taskorder_oplogs
 lateral view outer explode(hivemall.json_split(get_json_object(x.taskorder_oplogs,'$.variableGroups'))) x1 as variableGroups
 lateral view outer explode(hivemall.json_split(get_json_object(x1.variableGroups,'$.formVariables'))) x2 as formVariables
 
 where taskop_name in ('rentStartDate','rentEndDate'
 ,'LastTotal','NewTotal'
 ,'OldAverage','newRentAverage'
 ,'neOtherAverage','NewAverage'
 ,'IncreaseInBusinessTerm1'
 ,'IncreaseInBusinessTerm2')
 and order_id in ("2110131186520846"
,"2110130137792847"
,"2110129010131434"
,"2110124584858187"
,"2110130685427681"
,"2110128962583198"
,"2110131546954471"
,"2110130196746750"
,"2110130772712854"
,"2110126008478735"
,"2110131574266928"
,"2110131841350353"
,"2110132104382474"
,"2110132193687559"
,"2110130707170615"
,"2110131655650452"
,"2110132059274091"
,"2110132722983188"
,"2110132539544742"
,"2110132590692581"
,"2110132631486757"
,"2110132522125455"
,"2110131118257500"
,"2110132486791261"
,"2110132632468386"
,"2110132539327786"
,"2110132269916369"
,"2110133593800193"
,"2110133509864416")

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
add jar hdfs://wormpexdata/user/wstats/udf/brickhouse-0.7.1-SNAPSHOT.jar;
CREATE TEMPORARY FUNCTION json_split AS 'brickhouse.udf.json.JsonSplitUDF';


with 211_order as 
(--211工单：触发任务
 select
 order_id as order_id
 ,flowName as flow_name
 ,substring_index(flowName,'-',1) as task_name
 ,case when substring(flowName,-10,2) = "FL" then substring_index(flowName,'-',-1)
 else substring_index(flowName,'-',-2) end as flag_code
 ,to_date(create_date) as create_date
 ,order_status as order_status
 from
 (select
 order_id
 ,get_json_object(data,'$.flowName') as flowName
 ,create_time as create_date
 ,get_json_object(data,'$.orderStatus') as order_status
 ,dt
 from pdw_order_store_211_order_detail_flow_main
 where 
 dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
 and get_json_object(data,'$.flowCode') = '029768'
 and get_json_object(data,'$.orderStatus') != 'SUSPEND'
 ) t1
),

flow_task_info as (
 select 
 t1.order_id
 ,t1.taskorder_id
 ,t1.taskorder_node_id
 ,t1.taskorder_status
 ,t1.taskorder_result
 ,taskorder_handler
 ,t1.taskorder_create_time
 ,t1.taskorder_deadline_time
 ,t1.rn
 ,get_json_object(x2.formVariables,'$.name') as taskop_name
 ,get_json_object(x2.formVariables,'$.values.label') as taskop_values

 from (
 select 
 order_id
 ,taskorder_id
 ,taskorder_node_id
 ,taskorder_status
 ,task_orders
 ,taskorder_result
 ,taskorder_oplogs
 ,get_json_object(get_json_object(task_orders,'$.handler'),'$.[0].code') as taskorder_handler
 ,get_json_object(task_orders,'$.createTime')as taskorder_create_time
 ,get_json_object(task_orders,'$.deadLineTime')as taskorder_deadline_time
 ,row_number()over(partition by (order_id,taskorder_node_id) order by taskorder_create_time desc) as rn --取最新分区的order
 from pdw_order_store_211_order_detail_flow_task_taskorders
 where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
 and taskorder_node_id in (
 'UserTask_0101l6o' --甲方材料要求
 ,'UserTask_1rt4vkt'--资质是否符合要求
 ,'UserTask_0g1lp5i'--项目负责人判断是否需要重新提供材料
 ,'UserTask_18p1z1q'--开发谈判进展反馈
 ,'UserTask_09nemga'--开发总参审批
 ,'UserTask_0szx5sv'--降租幅度反馈
 ,'UserTask_1mgb0p3'--中台审核归档已完成
 )
 ) t1
 lateral view explode(hivemall.json_split(t1.taskorder_oplogs)) x as taskorder_oplogs
 lateral view outer explode(hivemall.json_split(get_json_object(x.taskorder_oplogs,'$.variableGroups'))) x1 as variableGroups
 lateral view outer explode(hivemall.json_split(get_json_object(x1.variableGroups,'$.formVariables'))) x2 as formVariables
),


user_info as 
(
 select 
 t1.order_id
 ,get_json_object(get_json_object(t1.task_orders,'$.handler'),'$.[0].code') as taskorder_handler
 ,t11.name as dev_user_id
 ,case when t13.zname = '郑刚' then t11.zname else t12.zname end as manager_user_name -- `大区姓名`
 ,case when t13.zname = '郑刚' then t12.zname else t13.zname end as director_user_name -- `总监姓名`
 from pdw_order_store_211_order_detail_flow_task_taskorders t1
 left join pdw_opc_flag_flag_user t11 on t1.taskorder_handler = array(t11.user_no) and t11.dt = date_format(date_sub(current_date(),1),'yyyyMMdd') and t11.is_delete != 1 
 left join pdw_opc_flag_flag_user t12 on t11.parent_id = t12.id and t12.dt = date_format(date_sub(current_date(),1),'yyyyMMdd') and t12.is_delete != 1 
 left join pdw_opc_flag_flag_user t13 on t12.parent_id = t13.id and t13.dt = date_format(date_sub(current_date(),1),'yyyyMMdd') and t13.is_delete != 1 
 where t1.dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
 and taskorder_node_id = 'UserTask_0101l6o' --甲方材料要求

)



select 
 t1.order_id as `任务编码`
 ,t1.flag_code as `插旗编码`
 ,t1.create_date as `任务发起时间`
 ,case when t1.order_status = 'PROCESSING' then '处理中'
 when t1.order_status = 'FINISHED' then '已完成'
 else t1.order_status end as `任务状态`
 ,case when t2.taskorder_status = 'DOING' then '处理中'
 when t2.taskorder_status = 'FINISHED' then '已完成'
 else t2.taskorder_status end as `动作节点状态`
 ,t2.taskorder_deadline_time as `动作到期时间`
 ,case when t2.taskorder_status = 'FINISHED' then '节点已完成'
 when taskorder_deadline_time <= current_timestamp() then '超时'
 else '未超时' end as `动作是否已超时`
 ,case when taskop_name = 'docNeeded' then '甲方是否有材料要求'
 when taskop_name = 'qualify' then '甲方是否认可当前资质'
 when taskop_name = 'lessorThought' then '甲方是否同意降免租'
 when taskop_name = 'opinion' then '用印归档是否已完成'
 else taskop_name end as `反馈字段`
 ,regexp_replace(taskop_values,'^\\\[\"|"\\\]$','') as `反馈内容`
 ,t2.rn as `处理次数`
 ,row_number()over(partition by (flag_code) order by create_date desc) as order_rn 
from 211_order t1
left join flow_task_info t2 on t1.order_id = t2.order_id
left join user_info t3 on t1.order_id = t3.order_id
where ((taskorder_node_id = 'UserTask_0101l6o' and (taskop_name = 'docNeeded' or taskop_name is null))
 or (taskorder_node_id = 'UserTask_1rt4vkt' and (taskop_name = 'qualify' or taskop_name is null))
 or (taskorder_node_id = 'UserTask_18p1z1q' and (taskop_name = 'lessorThought' or taskop_name is null))
 or (taskorder_node_id = 'UserTask_1mgb0p3' and (taskop_name = 'opinion' or taskop_name is null)))
and ((t2.taskorder_status = 'FINISHED' and taskop_name is not null) or t2.taskorder_status = 'DOING')

---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--事件上报及相关调整申请
select * 
from(
select
regexp_replace(task_name,"\n",";") as task_name
,order_status
,create_time
,taskorder_update_time
,get_json_object(get_json_object(get_json_object(get_json_object(data_info,'$.variableGroups[0]'),'$.formVariables[0]'),'$.values[0]'),'$.value') as store_code
,get_json_object(get_json_object(get_json_object(get_json_object(data_info,'$.variableGroups[0]'),'$.formVariables[3]'),'$.values[0]'),'$.label') as eventType
,get_json_object(get_json_object(get_json_object(get_json_object(data_info,'$.variableGroups[0]'),'$.formVariables[4]'),'$.values[0]'),'$.label') as friendType
,get_json_object(get_json_object(get_json_object(get_json_object(data_info,'$.variableGroups[0]'),'$.formVariables[5]'),'$.values[0]'),'$.label') as yiqingtype
,get_json_object(get_json_object(get_json_object(get_json_object(data_info,'$.variableGroups[0]'),'$.formVariables[6]'),'$.values[0]'),'$.label') as businessCentreType
,get_json_object(get_json_object(get_json_object(get_json_object(data_info,'$.variableGroups[0]'),'$.formVariables[7]'),'$.values[0]'),'$.label') as school
,get_json_object(get_json_object(get_json_object(get_json_object(data_info,'$.variableGroups[0]'),'$.formVariables[8]'),'$.values[0]'),'$.label') as buxi
,get_json_object(get_json_object(get_json_object(get_json_object(data_info,'$.variableGroups[0]'),'$.formVariables[9]'),'$.values[0]'),'$.label') as around
,get_json_object(get_json_object(get_json_object(get_json_object(data_info,'$.variableGroups[0]'),'$.formVariables[10]'),'$.values[0]'),'$.label') as noDoType
,get_json_object(get_json_object(get_json_object(get_json_object(data_info,'$.variableGroups[0]'),'$.formVariables[11]'),'$.values[0]'),'$.label') as waterStopReason
,get_json_object(get_json_object(get_json_object(get_json_object(data_info,'$.variableGroups[0]'),'$.formVariables[12]'),'$.values[0]'),'$.label') as powerStopReason
,regexp_replace(get_json_object(get_json_object(get_json_object(get_json_object(data_info,'$.variableGroups[0]'),'$.formVariables[13]'),'$.values[0]'),'$.label'),"\n",";") as detailStopReason
,get_json_object(get_json_object(get_json_object(get_json_object(data_info,'$.variableGroups[0]'),'$.formVariables[14]'),'$.values[0]'),'$.label') as equipment
,regexp_replace(get_json_object(get_json_object(get_json_object(get_json_object(data_info,'$.variableGroups[0]'),'$.formVariables[19]'),'$.values[0]'),'$.value'),"\n",";") as reason
,row_number()over(partition by (order_id) order by taskorder_update_time desc) as rn
from data_smartorder.dm_ordering_report_taskoutput_info_da
where dt = date_format(date_sub(current_date,1),'yyyyMMdd')
--and order_id = '2110135208680930'
and flow_code = '017119') t1
where rn = 1
--and substr(create_time,1,10) between '2023-01-01' and '2023-07-12'
--and store_code = '101000159'
and eventtype in ('商圈变化','竞对相关')

union all

--事件上报及相关调整申请
select * 
from(
select
task_name
,order_status
,create_time
,taskorder_update_time
,get_json_object(get_json_object(get_json_object(get_json_object(data_info,'$.variableGroups[0]'),'$.formVariables[0]'),'$.values[0]'),'$.value') as store_code
,get_json_object(get_json_object(get_json_object(get_json_object(data_info,'$.variableGroups[0]'),'$.formVariables[3]'),'$.values[0]'),'$.label') as eventType
,get_json_object(get_json_object(get_json_object(get_json_object(data_info,'$.variableGroups[0]'),'$.formVariables[4]'),'$.values[0]'),'$.label') as friendType
,get_json_object(get_json_object(get_json_object(get_json_object(data_info,'$.variableGroups[0]'),'$.formVariables[5]'),'$.values[0]'),'$.label') as yiqingtype
,get_json_object(get_json_object(get_json_object(get_json_object(data_info,'$.variableGroups[0]'),'$.formVariables[6]'),'$.values[0]'),'$.label') as businessCentreType
,get_json_object(get_json_object(get_json_object(get_json_object(data_info,'$.variableGroups[0]'),'$.formVariables[7]'),'$.values[0]'),'$.label') as school
,get_json_object(get_json_object(get_json_object(get_json_object(data_info,'$.variableGroups[0]'),'$.formVariables[8]'),'$.values[0]'),'$.label') as buxi
,get_json_object(get_json_object(get_json_object(get_json_object(data_info,'$.variableGroups[0]'),'$.formVariables[9]'),'$.values[0]'),'$.label') as around
,get_json_object(get_json_object(get_json_object(get_json_object(data_info,'$.variableGroups[0]'),'$.formVariables[10]'),'$.values[0]'),'$.label') as noDoType
,get_json_object(get_json_object(get_json_object(get_json_object(data_info,'$.variableGroups[0]'),'$.formVariables[11]'),'$.values[0]'),'$.label') as waterStopReason
,get_json_object(get_json_object(get_json_object(get_json_object(data_info,'$.variableGroups[0]'),'$.formVariables[12]'),'$.values[0]'),'$.label') as powerStopReason
,regexp_replace(get_json_object(get_json_object(get_json_object(get_json_object(data_info,'$.variableGroups[0]'),'$.formVariables[13]'),'$.values[0]'),'$.label'),"\n",";") as detailStopReason
,get_json_object(get_json_object(get_json_object(get_json_object(data_info,'$.variableGroups[0]'),'$.formVariables[14]'),'$.values[0]'),'$.label') as equipment
,regexp_replace(get_json_object(get_json_object(get_json_object(get_json_object(data_info,'$.variableGroups[0]'),'$.formVariables[19]'),'$.values[0]'),'$.value'),"\n",";") as reason
,row_number()over(partition by (order_id) order by taskorder_update_time desc) as rn
from data_smartorder.dm_ordering_report_taskoutput_info_da
where dt = date_format(date_sub(current_date,1),'yyyyMMdd')
--and order_id = '2110135208680930'
and flow_code = '017119') t1
where rn = 1
and substr(create_time,1,10) between '2022-01-01' and '2022-12-31'
--and store_code = '101000159'
and eventtype in ('商圈变化','设备设施损坏','竞对相关','停水','停电','不可抗因素','疫情相关')

union all

--事件上报及相关调整申请
select * 
from(
select
task_name
,order_status
,create_time
,taskorder_update_time
,get_json_object(get_json_object(get_json_object(get_json_object(data_info,'$.variableGroups[0]'),'$.formVariables[0]'),'$.values[0]'),'$.value') as store_code
,get_json_object(get_json_object(get_json_object(get_json_object(data_info,'$.variableGroups[0]'),'$.formVariables[3]'),'$.values[0]'),'$.label') as eventType
,get_json_object(get_json_object(get_json_object(get_json_object(data_info,'$.variableGroups[0]'),'$.formVariables[4]'),'$.values[0]'),'$.label') as friendType
,get_json_object(get_json_object(get_json_object(get_json_object(data_info,'$.variableGroups[0]'),'$.formVariables[5]'),'$.values[0]'),'$.label') as yiqingtype
,get_json_object(get_json_object(get_json_object(get_json_object(data_info,'$.variableGroups[0]'),'$.formVariables[6]'),'$.values[0]'),'$.label') as businessCentreType
,get_json_object(get_json_object(get_json_object(get_json_object(data_info,'$.variableGroups[0]'),'$.formVariables[7]'),'$.values[0]'),'$.label') as school
,get_json_object(get_json_object(get_json_object(get_json_object(data_info,'$.variableGroups[0]'),'$.formVariables[8]'),'$.values[0]'),'$.label') as buxi
,get_json_object(get_json_object(get_json_object(get_json_object(data_info,'$.variableGroups[0]'),'$.formVariables[9]'),'$.values[0]'),'$.label') as around
,get_json_object(get_json_object(get_json_object(get_json_object(data_info,'$.variableGroups[0]'),'$.formVariables[10]'),'$.values[0]'),'$.label') as noDoType
,get_json_object(get_json_object(get_json_object(get_json_object(data_info,'$.variableGroups[0]'),'$.formVariables[11]'),'$.values[0]'),'$.label') as waterStopReason
,get_json_object(get_json_object(get_json_object(get_json_object(data_info,'$.variableGroups[0]'),'$.formVariables[12]'),'$.values[0]'),'$.label') as powerStopReason
,regexp_replace(get_json_object(get_json_object(get_json_object(get_json_object(data_info,'$.variableGroups[0]'),'$.formVariables[13]'),'$.values[0]'),'$.label'),"\n",";") as detailStopReason
,get_json_object(get_json_object(get_json_object(get_json_object(data_info,'$.variableGroups[0]'),'$.formVariables[14]'),'$.values[0]'),'$.label') as equipment
,regexp_replace(get_json_object(get_json_object(get_json_object(get_json_object(data_info,'$.variableGroups[0]'),'$.formVariables[19]'),'$.values[0]'),'$.value'),"\n",";") as reason
,row_number()over(partition by (order_id) order by taskorder_update_time desc) as rn
from data_smartorder.dm_ordering_report_taskoutput_info_da
where dt = date_format(date_sub(current_date,1),'yyyyMMdd')
--and order_id = '2110135208680930'
and flow_code = '017119') t1
where rn = 1
and substr(create_time,1,10) between '2021-01-01' and '2021-12-31'
--and store_code = '101000159'
and eventtype in ('商圈变化','设备设施损坏','竞对相关','停水','停电','不可抗因素','疫情相关')

union all

--事件上报及相关调整申请
select * 
from(
select
task_name
,order_status
,create_time
,taskorder_update_time
,get_json_object(get_json_object(get_json_object(get_json_object(data_info,'$.variableGroups[0]'),'$.formVariables[0]'),'$.values[0]'),'$.value') as store_code
,get_json_object(get_json_object(get_json_object(get_json_object(data_info,'$.variableGroups[0]'),'$.formVariables[3]'),'$.values[0]'),'$.label') as eventType
,get_json_object(get_json_object(get_json_object(get_json_object(data_info,'$.variableGroups[0]'),'$.formVariables[4]'),'$.values[0]'),'$.label') as friendType
,get_json_object(get_json_object(get_json_object(get_json_object(data_info,'$.variableGroups[0]'),'$.formVariables[5]'),'$.values[0]'),'$.label') as yiqingtype
,get_json_object(get_json_object(get_json_object(get_json_object(data_info,'$.variableGroups[0]'),'$.formVariables[6]'),'$.values[0]'),'$.label') as businessCentreType
,get_json_object(get_json_object(get_json_object(get_json_object(data_info,'$.variableGroups[0]'),'$.formVariables[7]'),'$.values[0]'),'$.label') as school
,get_json_object(get_json_object(get_json_object(get_json_object(data_info,'$.variableGroups[0]'),'$.formVariables[8]'),'$.values[0]'),'$.label') as buxi
,get_json_object(get_json_object(get_json_object(get_json_object(data_info,'$.variableGroups[0]'),'$.formVariables[9]'),'$.values[0]'),'$.label') as around
,get_json_object(get_json_object(get_json_object(get_json_object(data_info,'$.variableGroups[0]'),'$.formVariables[10]'),'$.values[0]'),'$.label') as noDoType
,get_json_object(get_json_object(get_json_object(get_json_object(data_info,'$.variableGroups[0]'),'$.formVariables[11]'),'$.values[0]'),'$.label') as waterStopReason
,get_json_object(get_json_object(get_json_object(get_json_object(data_info,'$.variableGroups[0]'),'$.formVariables[12]'),'$.values[0]'),'$.label') as powerStopReason
,regexp_replace(get_json_object(get_json_object(get_json_object(get_json_object(data_info,'$.variableGroups[0]'),'$.formVariables[13]'),'$.values[0]'),'$.label'),"\n",";") as detailStopReason
,get_json_object(get_json_object(get_json_object(get_json_object(data_info,'$.variableGroups[0]'),'$.formVariables[14]'),'$.values[0]'),'$.label') as equipment
,regexp_replace(get_json_object(get_json_object(get_json_object(get_json_object(data_info,'$.variableGroups[0]'),'$.formVariables[19]'),'$.values[0]'),'$.value'),"\n",";") as reason
,row_number()over(partition by (order_id) order by taskorder_update_time desc) as rn
from data_smartorder.dm_ordering_report_taskoutput_info_da
where dt = date_format(date_sub(current_date,1),'yyyyMMdd')
--and order_id = '2110135208680930'
and flow_code = '017119') t1
where rn = 1
and substr(create_time,1,10) between '2020-01-01' and '2020-12-31'
--and store_code = '101000159'
and eventtype in ('商圈变化','设备设施损坏','竞对相关','停水','停电','不可抗因素','疫情相关')

union all

--事件上报及相关调整申请
select * 
from(
select
task_name
,order_status
,create_time
,taskorder_update_time
,get_json_object(get_json_object(get_json_object(get_json_object(data_info,'$.variableGroups[0]'),'$.formVariables[0]'),'$.values[0]'),'$.value') as store_code
,get_json_object(get_json_object(get_json_object(get_json_object(data_info,'$.variableGroups[0]'),'$.formVariables[3]'),'$.values[0]'),'$.label') as eventType
,get_json_object(get_json_object(get_json_object(get_json_object(data_info,'$.variableGroups[0]'),'$.formVariables[4]'),'$.values[0]'),'$.label') as friendType
,get_json_object(get_json_object(get_json_object(get_json_object(data_info,'$.variableGroups[0]'),'$.formVariables[5]'),'$.values[0]'),'$.label') as yiqingtype
,get_json_object(get_json_object(get_json_object(get_json_object(data_info,'$.variableGroups[0]'),'$.formVariables[6]'),'$.values[0]'),'$.label') as businessCentreType
,get_json_object(get_json_object(get_json_object(get_json_object(data_info,'$.variableGroups[0]'),'$.formVariables[7]'),'$.values[0]'),'$.label') as school
,get_json_object(get_json_object(get_json_object(get_json_object(data_info,'$.variableGroups[0]'),'$.formVariables[8]'),'$.values[0]'),'$.label') as buxi
,get_json_object(get_json_object(get_json_object(get_json_object(data_info,'$.variableGroups[0]'),'$.formVariables[9]'),'$.values[0]'),'$.label') as around
,get_json_object(get_json_object(get_json_object(get_json_object(data_info,'$.variableGroups[0]'),'$.formVariables[10]'),'$.values[0]'),'$.label') as noDoType
,get_json_object(get_json_object(get_json_object(get_json_object(data_info,'$.variableGroups[0]'),'$.formVariables[11]'),'$.values[0]'),'$.label') as waterStopReason
,get_json_object(get_json_object(get_json_object(get_json_object(data_info,'$.variableGroups[0]'),'$.formVariables[12]'),'$.values[0]'),'$.label') as powerStopReason
,regexp_replace(get_json_object(get_json_object(get_json_object(get_json_object(data_info,'$.variableGroups[0]'),'$.formVariables[13]'),'$.values[0]'),'$.label'),"\n",";") as detailStopReason
,get_json_object(get_json_object(get_json_object(get_json_object(data_info,'$.variableGroups[0]'),'$.formVariables[14]'),'$.values[0]'),'$.label') as equipment
,regexp_replace(get_json_object(get_json_object(get_json_object(get_json_object(data_info,'$.variableGroups[0]'),'$.formVariables[19]'),'$.values[0]'),'$.value'),"\n",";") as reason
,row_number()over(partition by (order_id) order by taskorder_update_time desc) as rn
from data_smartorder.dm_ordering_report_taskoutput_info_da
where dt = date_format(date_sub(current_date,1),'yyyyMMdd')
--and order_id = '2110135208680930'
and flow_code = '017119') t1
where rn = 1
and substr(create_time,1,10) between '2019-01-01' and '2019-12-31'
--and store_code = '101000159'
and eventtype in ('商圈变化','设备设施损坏','竞对相关','停水','停电','不可抗因素','疫情相关')

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--单店查上报流程
select * 
from(
select
task_name
,order_status
,create_time
,taskorder_update_time
,get_json_object(get_json_object(get_json_object(get_json_object(data_info,'$.variableGroups[0]'),'$.formVariables[0]'),'$.values[0]'),'$.value') as store_code
,get_json_object(get_json_object(get_json_object(get_json_object(data_info,'$.variableGroups[0]'),'$.formVariables[3]'),'$.values[0]'),'$.label') as eventType
,get_json_object(get_json_object(get_json_object(get_json_object(data_info,'$.variableGroups[0]'),'$.formVariables[4]'),'$.values[0]'),'$.label') as friendType
,get_json_object(get_json_object(get_json_object(get_json_object(data_info,'$.variableGroups[0]'),'$.formVariables[5]'),'$.values[0]'),'$.label') as yiqingtype
,get_json_object(get_json_object(get_json_object(get_json_object(data_info,'$.variableGroups[0]'),'$.formVariables[6]'),'$.values[0]'),'$.label') as businessCentreType
,get_json_object(get_json_object(get_json_object(get_json_object(data_info,'$.variableGroups[0]'),'$.formVariables[7]'),'$.values[0]'),'$.label') as school
,get_json_object(get_json_object(get_json_object(get_json_object(data_info,'$.variableGroups[0]'),'$.formVariables[8]'),'$.values[0]'),'$.label') as buxi
,get_json_object(get_json_object(get_json_object(get_json_object(data_info,'$.variableGroups[0]'),'$.formVariables[9]'),'$.values[0]'),'$.label') as around
,get_json_object(get_json_object(get_json_object(get_json_object(data_info,'$.variableGroups[0]'),'$.formVariables[10]'),'$.values[0]'),'$.label') as noDoType
,get_json_object(get_json_object(get_json_object(get_json_object(data_info,'$.variableGroups[0]'),'$.formVariables[11]'),'$.values[0]'),'$.label') as waterStopReason
,get_json_object(get_json_object(get_json_object(get_json_object(data_info,'$.variableGroups[0]'),'$.formVariables[12]'),'$.values[0]'),'$.label') as powerStopReason
,regexp_replace(get_json_object(get_json_object(get_json_object(get_json_object(data_info,'$.variableGroups[0]'),'$.formVariables[13]'),'$.values[0]'),'$.label'),"\n",";") as detailStopReason
,get_json_object(get_json_object(get_json_object(get_json_object(data_info,'$.variableGroups[0]'),'$.formVariables[14]'),'$.values[0]'),'$.label') as equipment
,regexp_replace(get_json_object(get_json_object(get_json_object(get_json_object(data_info,'$.variableGroups[0]'),'$.formVariables[19]'),'$.values[0]'),'$.value'),"\n",";") as reason
,row_number()over(partition by (order_id) order by taskorder_update_time desc) as rn
from data_smartorder.dm_ordering_report_taskoutput_info_da
where dt = 20230517
--and order_id = '2110135208680930'
and flow_code = '017119') t1
where rn = 1
and substr(create_time,1,10) between '2019-01-01' and '2019-12-31'
--and store_code = '101000159'
and eventtype = '商圈变化'

select * from data_smartorder.dm_ordering_report_taskoutput_info_da
where dt = date_format(date_sub(current_date,1),'yyyyMMdd')
and flow_code = '017119'
and (get_json_object(get_json_object(get_json_object(get_json_object(data_info,'$.variableGroups[0]'),'$.formVariables[0]'),'$.values[0]'),'$.value') = '110000373'
or store_code = '110000373')

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--上会日商和hurdle申请流程监控
--数仓落表--data_build.app_meeting_daydale_monitor_v2_da
with a_b_c_d_list as(
select
order_id--任务编号
,flow_ame--任务名称
,flow_name--任务名称
,flag_code--旗标编号
,project_name--项目名称
,city--城市
,create_time--创建时间
,order_status--流程状态
,taskorder_id--节点id
,taskorder_name--节点名称
,taskorder_status--节点状态
,taskorder_result--节点处理动作
,view.taskorder_assignee as taskorder_assignee--节点处理人
,taskorder_create_time--节点创建时间
,taskorder_deadline_time--节点到期时间
,taskorder_update_time--节点实际处理时间
from
(SELECT
t.order_id
,t.flow_ame
,translate(t.flow_ame,'+','&') as flow_name
,split(translate(t.flow_ame,'+','&'),'&')[1] as flag_code
,split(translate(t.flow_ame,'+','&'),'&')[2] as project_name
,substring_index(t.flow_ame,'+',1) as city
,t.create_time
,t.order_status
,a.taskorder_id
,case
when taskorder_node_id = 'xxRippleApplyTask' then '开发员申请日商和hurdle'
when taskorder_node_id = 'chiefApprove' then '大区审批'
when taskorder_node_id = 'engineerConditionConfirm' then '新址会工程条件审核'
when taskorder_node_id = 'UserTask_18aovo4' then '信息部节点'
when taskorder_node_id = 'CallActivity_0yyq2p8' then '自动概算'
when taskorder_node_id = 'daySaleConfirm' then '上会预估日商计算'
when taskorder_node_id = 'UserTask_08jizxo' then '星标店铺判断'
when taskorder_node_id = 'daySaleCheck' then '上会日商预估审核'
when taskorder_node_id = 'UserTask_1xgqgx7' then '上会日商预估二审'
when taskorder_node_id = 'hurdleConfirm' then '上会hurdle确认'
when taskorder_node_id = 'UserTask_0f9i9a4' then '人工确认是否继续重试'
when taskorder_node_id = 'CallActivity_1ubo6e0' then '通知上会结果'
when taskorder_node_id = 'UserTask_0gnkvus' then '复盘流程'
else null end as taskorder_name
,taskorder_status
,a.taskorder_result
,a.taskorder_assignee
,a.taskorder_create_time
,a.taskorder_deadline_time
,case when a.taskorder_status in ('DOING','NEW_ORDER') then '' else a.taskorder_update_time end as taskorder_update_time
from data_build.pdw_order_store_211_order_detail_flow_main t
LEFT JOIN data_build.pdw_order_store_211_order_detail_flow_task_taskorders a on a.dt = date_format(date_sub(current_date,1),'yyyyMMdd') and a.order_id = t.order_id
where t.dt = date_format(date_sub(current_date,1),'yyyyMMdd')
and t.flow_code = '019579'
) a
lateral view explode(taskorder_assignee) view as taskorder_assignee
),

v_name as(
select
b.order_id--任务编号
,b.flow_ame--任务名称
,b.flow_name--任务名称
,b.flag_code--旗标编号
,b.project_name--项目名称
,b.city--城市
,b.create_time--创建时间
,b.order_status--流程状态
,b.taskorder_id--节点id
,b.taskorder_name--节点名称
,b.taskorder_status--节点状态
,b.taskorder_result--节点处理动作
,b.taskorder_assignee as taskorder_assignee--节点处理人
,b.taskorder_create_time--节点创建时间
,b.taskorder_deadline_time--节点到期时间
,b.taskorder_update_time--节点实际处理时间
,c.zname--处理人中文名
from a_b_c_d_list b
left join data_build.pdw_opc_flag_flag_user c on b.taskorder_assignee = c.user_no and c.dt = date_format(date_sub(current_date,1),'yyyyMMdd')
),

--每个流程等待时长/完成时长
max_time as (
SELECT
order_id
,(max(unix_timestamp(taskorder_create_time))-min(unix_timestamp(taskorder_create_time)))*1.0000/3600 as max_time
from(
SELECT
order_id
,case when taskorder_status in ('DOING','NEW_ORDER') then current_timestamp() else taskorder_create_time end as taskorder_create_time
from data_build.pdw_order_store_211_order_detail_flow_task_taskorders
where dt = date_format(date_sub(current_date,1),'yyyyMMdd')
) a
GROUP BY
order_id),

meeting_result as (
select
a.order_id
--,a.dt
,COLLECT_SET(case when form_name = 'circleType' then get_json_object(get_json_object(form_values,'$.[0]'),'$.value') else null end) as circleType
,COLLECT_SET(case when form_name = 'shopGradeForecast' then get_json_object(get_json_object(form_values,'$.[0]'),'$.label') else null end) as shopGradeForecast
,COLLECT_SET(case when form_name = 'circleFlowCount' then get_json_object(get_json_object(form_values,'$.[0]'),'$.label') else null end) as circleFlowCount
,COLLECT_SET(case when form_name = 'importantCircleType' then get_json_object(get_json_object(form_values,'$.[0]'),'$.value') else null end) as importantCircleType
,COLLECT_SET(case when form_name = 'daySaleParam' then get_json_object(get_json_object(form_values,'$.[0]'),'$.value') else null end) as daySaleParam
,COLLECT_SET(case when form_name = 'daySaleByAI' then get_json_object(get_json_object(form_values,'$.[0]'),'$.value') else null end) as daySaleByAI
,COLLECT_SET(case when form_name = 'elementDaySaleLevel' then get_json_object(get_json_object(form_values,'$.[0]'),'$.label') else null end) as elementDaySaleLevel
,COLLECT_SET(case when form_name = 'modelDaySaleLevel' then get_json_object(get_json_object(form_values,'$.[0]'),'$.label') else null end) as modelDaySaleLevel
,COLLECT_SET(case when form_name = 'avgDaySale' then get_json_object(get_json_object(form_values,'$.[0]'),'$.value') else null end) as avgDaySale
,COLLECT_SET(case when form_name = 'elementHurdle' then get_json_object(get_json_object(form_values,'$.[0]'),'$.value') else null end) as elementHurdle
,COLLECT_SET(case when form_name = 'meetingResultSource' then get_json_object(get_json_object(form_values,'$.[0]'),'$.label') else null end) as meetingResultSource
,COLLECT_SET(case when form_name = 'commentNew' then get_json_object(get_json_object(form_values,'$.[0]'),'$.value') else null end) as commentNew
from data_build.pdw_order_store_211_order_detail_flow_form_variable_groups_da a
--join max_dt t on a.order_id = t.order_id and a.dt = t.dt
where a.dt = date_format(date_sub(current_date,1),'yyyyMMdd')
--and a.order_id = '2110141527085739'
group by
a.order_id
--,a.dt
)

select
a.order_id--任务编号
,flow_ame--任务名称
,flow_name--任务名称
,flag_code--旗标编号
,project_name--项目名称
,city--城市
,create_time--流程创建时间
,case 
when order_status = 'FINISHED' then '已完成'
when order_status = 'PROCESSING' then '进行中'
when order_status = 'SUSPEND' then '已终止'
else order_status end as order_status--订单状态
,taskorder_id--节点id
,taskorder_name--节点名称
,case
when taskorder_status = 'FINISHED' then '已完成'
when taskorder_status = 'DOING' then '进行中'
when taskorder_status = 'NEW_ORDER' then '新订单'
else taskorder_status end as taskorder_status--节点状态
,case
when taskorder_status = 'DOING' then null
when taskorder_result = 'ACCEPT' then '通过'
when taskorder_result = 'AGREE' then '通过'
when taskorder_result = 'REBUT' then '驳回'
when taskorder_result = 'REJECT' then '拒绝'
when taskorder_result = 'REVOKE' then '撤销'
when taskorder_result = 'INIT' then '初始化'
else taskorder_result end as taskorder_result--节点处理结果
,taskorder_create_time--节点创建时间
,taskorder_deadline_time--节点截止时间
,case
when taskorder_status in ('DOING','NEW_ORDER') then null else taskorder_update_time end as taskorder_update_time--节点处理时间
,t1.max_time--流程处理时长
,concat_ws(',',collect_set(cast(zname as string))) as zname--处理人中文名
,dense_rank () over(partition by (flag_code) order by (create_time)) as rn--申请次数
,case when circleType[0] = '' then circleType[1] else circleType[0] end as circleType--商圈类型
,t.shopGradeForecast[0] as shopGradeForecast--店铺质量评估
,t.circleFlowCount[0] as circleFlowCount--商圈容量
,t.importantCircleType[0] as importantCircleType--重点商圈分类
,t.daySaleParam[0] as daySaleParam--规划预估日商
,t.daySaleByai[0] as daySaleByai--模型预估日商
,t.elementDaySaleLevel[0] as elementDaySaleLevel--规划日商档位
,t.modelDaySaleLevel[0] as modelDaySaleLevel--模型日商档位
,t.avgDaySale[0] as avgDaySale--预估日商
,t.elementHurdle[0] as elementHurdle--Hurdle
,t.meetingResultSource[0] as meetingResultSource--决策方式
,commentNew[0] as commentNew--上会结果描述
,case
when taskorder_update_time = '' then (unix_timestamp()-unix_timestamp(taskorder_create_time))*1.0000/3600
else (unix_timestamp(taskorder_update_time)-unix_timestamp(taskorder_create_time))*1.0000/3600 end as taskorder_handler_time--节点等待/处理时长
,case when 
case when taskorder_update_time = '' then unix_timestamp() else unix_timestamp(taskorder_create_time) end
 > taskorder_deadline_time then '超时' else '未超时' end as time_out_or_not
from v_name a
left join meeting_result t on a.order_id = t.order_id
left join max_time t1 on a.order_id = t1.order_id
group by
a.order_id
,flow_ame
,flow_name
,flag_code
,project_name
,city
,create_time
,order_status
,taskorder_id
,taskorder_name
,taskorder_status
,taskorder_result
,taskorder_create_time
,taskorder_deadline_time
,taskorder_update_time
,t1.max_time
,circleType
,shopGradeForecast
,circleFlowCount
,importantCircleType
,daySaleParam
,daySaleByAI
,elementDaySaleLevel
,modelDaySaleLevel
,avgDaySale
,elementHurdle
,meetingResultSource
,commentNew
order by flag_code,taskorder_update_time,rn
limit 13140

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--租金信息
with rent_main as
(
	 select
		 t1.order_id
		 ,get_json_object(t1.data,'$.flagCode') as flag_code
		 ,get_json_object(t1.data,'$.projectId') as project_id
		 ,get_json_object(t1.data,'$.projectName') as project_name
	 from data_build.pdw_order_store_209_order_detail t1
	 where t1.dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
	 and t1.section = 'contract-main'
	-- and t1.order_id = '2090038376739896'
),

yearRentInfoList as 
(
	select
 		t1.order_id
 		,get_json_object(x1.yearRentInfoList,'$.rentYear') as rentYear
 		,get_json_object(x1.yearRentInfoList,'$.startDate') as start_date
 		,get_json_object(x1.yearRentInfoList,'$.endDate') as end_date
 		,get_json_object(x1.yearRentInfoList,'$.rentFee.amount') as rentFee
 		,get_json_object(x1.yearRentInfoList,'$.dailyRentPerMeter.amount') as dailyRentPerMeter
  	from data_build.pdw_order_store_209_order_detail t1
 	lateral view outer explode(hivemall.json_split(get_json_object(t1.data,'$.yearRentInfoList.yearRentList'))) x1 as yearRentInfoList
 	where t1.dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
	--and order_id = '2090023639131180'
	and t1.section = 'contract-cost'
),

yearRentExcludingTax as 
(
	select
 		t1.order_id
  		,get_json_object(x1.yearRentExcludingTax,'$.rentYear') as rentYear
 		,get_json_object(x1.yearRentExcludingTax,'$.startDate') as start_date
 		,get_json_object(x1.yearRentExcludingTax,'$.endDate') as end_date
 		,get_json_object(x1.yearRentExcludingTax,'$.rentFee.amount') as rentFee
 		,get_json_object(x1.yearRentExcludingTax,'$.dailyRentPerMeter.amount') as dailyRentPerMeter
  	from data_build.pdw_order_store_209_order_detail t1
 	lateral view outer explode(hivemall.json_split(get_json_object(t1.data,'$.yearRentExcludingTax.yearRentList'))) x1 as yearRentExcludingTax
 	where t1.dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
	--and order_id = '2090023639131180'
	and t1.section = 'contract-cost'
),

propertyFeePerMonth as
(	
	select
		t1.order_id
		,get_json_object(t1.data,'$.propertyFeePerMonth.amount') as propertyFeePerMonth
	from data_build.pdw_order_store_209_order_detail t1
	where t1.dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
	--and order_id = '2090133607291561'
	and t1.section = 'contract-cost'
)

select
 t1.order_id 				as `工单号`
 ,t1.flag_code				as `插旗编码`
 ,t1.project_id				as `项目ID`
 ,t1.project_name			as `项目名称`
 ,t2.rentYear				as `租赁年度`
 ,to_date(t2.start_date)	as `租金起日`
 ,to_date(t2.end_date)		as `租金止日`
 ,t2.rentFee				as `年租金`
 ,t2.dailyRentPerMeter		as `每平米租金`
 ,t3.rentFee				as `年租金（不含税）`
 ,t3.dailyRentPerMeter		as `每平米租金（不含税）`
 ,t4.propertyFeePerMonth    as `每月物业费`
from rent_main t1
left join yearRentInfoList t2 on t1.order_id = t2.order_id
left join yearRentExcludingTax t3 on t1.order_id = t3.order_id and t2.rentYear = t3.rentYear
left join propertyFeePerMonth t4 on t1.order_id = t4.order_id
where t1.flag_code in ('DX6-86')

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--获取流程链接
select
a.*
,concat('https://ripple.blibee.com/ripple/pc/CustomDetail/token/',get_json_object(get_json_object(data,'$.shareLinks[0]'),'$.token')) as link
from data_build.pdw_order_store_211_order_detail_flow_main a
where a.dt = date_format(date_sub(current_date,1),'yyyyMMdd')
--and order_id = '2110134323676638'
and a.flow_code = '024011'--续租条件
--and a.flow_code = '023925'--续租合同
--and a.flow_code = '023771'--开发签约特殊事项流程
--and a.flow_code = '031722'--潜在撤店门店降租谈判
--and a.flow_code = '017384'--开发部用印归档
--and a.flow_code = '019063'--撤店流程
--and a.flow_code = '032003'--门店加盟合同签约审批
--and a.flow_code = '020661'--费用付款申请单
--and a.flow_code = '029768'--开发降免租项目跟进

---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--上会日商及hurdle申请明细
with targetHurdle_list as(
SELECT
cast(order_id as string) as order_id
,COLLECT_SET(case when form_name = 'targetHurdle' then get_json_object(get_json_object(form_values,'$.[0]'),'$.value') else null end)[0] as targetHurdle
from data_build.pdw_order_store_211_order_detail_flow_form_variable_groups_da
where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and form_name = 'targetHurdle'
--and order_id = '2110141816094761'
group by order_id),

push_time_list as (
SELECT
order_id
,to_date(max(taskorder_update_time)) as push_time
FROM data_build.app_meeting_daydale_monitor_v2_da
where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
GROUP BY
order_id
)

select
t.*
,t1.targetHurdle
,t2.push_time
from data_build.app_meeting_daydale_monitor_v2_da t
left join targetHurdle_list t1 on t.order_id = t1.order_id
left join push_time_list t2 on t.order_id = t2.order_id
where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')

---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--门店续租条件审批
--主表单信息
with main_list as
(SELECT
order_id
,COLLECT_SET(case when form_name = 'NewContractInvoiceType' then get_json_object(get_json_object(form_values,'$.[0]'),'$.value') else null end)[0] as NewContractInvoiceType
,COLLECT_SET(case when form_name = 'rentStartDate' then get_json_object(get_json_object(form_values,'$.[0]'),'$.value') else null end)[0] as rentStartDate
,COLLECT_SET(case when form_name = 'NewContractRentNoTax' then get_json_object(get_json_object(form_values,'$.[0]'),'$.value') else null end)[0] as NewContractRentNoTax
,COLLECT_SET(case when form_name = 'NewContractPropertyMgtFee' then get_json_object(get_json_object(form_values,'$.[0]'),'$.value') else null end)[0] as NewContractPropertyMgtFee
from data_build.pdw_order_store_211_order_detail_flow_form_variable_groups_da
where dt = 20230927
--and order_id = '2110138668564644'
and form_name in ('NewContractInvoiceType','rentStartDate','NewContractRentNoTax','NewContractPropertyMgtFee')
group BY order_id)

--获取流程链接
select
a.*
,b.NewContractInvoiceType
,b.rentStartDate
,b.NewContractRentNoTax
,b.NewContractPropertyMgtFee
,concat('https://ripple.blibee.com/ripple/pc/CustomDetail/token/',get_json_object(get_json_object(data,'$.shareLinks[0]'),'$.token')) as link
from data_build.pdw_order_store_211_order_detail_flow_main a
left join main_list b on a.order_id = b.order_id
where a.dt = date_format(date_sub(current_date,1),'yyyyMMdd')
--and order_id = '2110134323676638'
and a.flow_code = '024011'--续租条件

----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--撤店流程链接
select
a.order_id
,flow_ame
,initiator_code
,org_code
,org_name
,create_time
,concat('https://ripple.blibee.com/ripple/pc/CustomDetail/token/',get_json_object(get_json_object(data,'$.shareLinks[0]'),'$.token')) as link
from data_smartorder.dm_copy_pdw_order_store_211_order_detail_flow_main_di_view a
where a.dt > 20170101
--and substr(create_time,1,10) between '2022-08-01' and '2022-08-31'
and order_id = '2110205340239998'
--and a.flow_code = '017050'
group by
a.order_id
,flow_ame
,initiator_code
,org_code
,org_name
,create_time
,concat('https://ripple.blibee.com/ripple/pc/CustomDetail/token/',get_json_object(get_json_object(data,'$.shareLinks[0]'),'$.token'))

================================================================================================================================================================================
================================================================================================================================================
--门店运营异常责任人核实 --尾部店工作状态差(028994)
with order_flow_main as(
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
where dt = date_format(date_sub(current_date,1),'yyyyMMdd')
and flow_code = '028994' --流程code
and flow_ame = '尾部店工作状态差'
and order_status in ('PROCESSING','FINISHED')
),

order_flow_groups as(
select
order_id
,case when form_name = 'finalUsercode' then get_json_object(get_json_object(form_values,'$.[0]'),'$.value') else null end as finalUsercode
from data_build.pdw_order_store_211_order_detail_flow_form_variable_groups_da
where dt = date_format(date_sub(current_date,1),'yyyyMMdd')
and form_name = 'finalUsercode'
--and order_id = '2110160025988320'
)

select
t0.order_id --流程编码(流程信息)
,t0.create_date
,t0.order_status --流程状态(流程信息)
,t0.initiator_code --发起人编码(流程信息)
,t0.create_time --流程发起时间(流程信息)
,t0.flow_ame --流程名称(流程信息)
,t0.org_code --门店编码(流程信息)
,t0.org_name --门店名称(流程信息)
,lpad(t1.finalUsercode,8,10) as finalUsercode --被惩处人
from order_flow_main t0
left join order_flow_groups t1 on t0.order_id = t1.order_id
where t0.create_date >= '2024-05-21'

================================================================================================================================================
--员工标签异常反馈流程(032225)
with order_flow_main as(
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
where dt = date_format(date_sub(current_date,1),'yyyyMMdd')
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
where dt = date_format(date_sub(current_date,1),'yyyyMMdd')
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
where dt = date_format(date_sub(current_date,1),'yyyyMMdd')
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
)

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

==================================================================================================================================================================
--门店交接申请流程
with order_flow_main as(
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
where dt = date_format(date_sub(current_date,1),'yyyyMMdd')
and flow_code = '017270' --流程code
--and order_status in ('PROCESSING','FINISHED')
),

order_flow_groups as(
select
order_id
,max(now_mgr) as now_mgr
,max(shop_name) as shop_name
from(
select
order_id
,case when form_name = 'shopOwnerCnName' then get_json_object(get_json_object(form_values,'$.[0]'),'$.value') else null end as now_mgr
,case when form_name = 'shopName' then get_json_object(get_json_object(form_values,'$.[0]'),'$.label') else null end as shop_name
from data_build.pdw_order_store_211_order_detail_flow_form_variable_groups_da
where dt = date_format(date_sub(current_date,1),'yyyyMMdd')
and form_name in ('shopOwnerCnName','shopName')
--and order_id = '2110157213089599'
) a
group by order_id
),

order_flow_taskorders as(
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
explode(split(regexp_replace(regexp_replace(task_orders, '\\[|\\]' , ''), '\\}\\,\\{' , '\\}\\&\\{'), '&')) x1 as element
where rn = 1
) b
group by
order_id
),

raw_list as(
select
t0.*
,case when reverse(substr(reverse(t1.now_mgr),0,instr(reverse(t1.now_mgr),'-')-1)) <> ''
then lpad(reverse(substr(reverse(t1.now_mgr),0,instr(reverse(t1.now_mgr),'-')-1)),8,'10') else regexp_replace(t1.now_mgr, '[^一-龥]', '') end as now_mgr
,t1.shop_name
,t2.second_change
from order_flow_main t0
left join order_flow_groups t1 on t0.order_id = t1.order_id
left join order_flow_taskorders t2 on t0.order_id = t2.order_id
),

staff_list as(
select
from_unixtime(unix_timestamp(dt,'yyyyMMdd'),'yyyy-MM-dd') as new_dt --日期
,lpad(emplid,8,'10') as emplid --员工编号
,name --员工名称
,hps_dept_descr_lv5 --门店名称
from data_build.pdw_psprod_ps_blf_ehr_pers_vw_view
where dt > 20170101
)

select
t1.*
,t2.*
,case when t2.name is not null then t2.emplid else t1.now_mgr end as staff_code
from raw_list t1
left join staff_list t2 on t1.create_date = t2.new_dt and t1.shop_name = t2.hps_dept_descr_lv5 and t1.now_mgr = t2.name--替换员工中文名字的情况
where t1.order_status = 'FINISHED'
and t2.second_change = '禁止现任店长二次晋升'