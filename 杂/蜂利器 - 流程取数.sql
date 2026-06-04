--蜂利器流程相关需求代码模板
--延旭增加内容1）当主表单多个时的取数方法；2）取节点内容优化。
with a as (
 select order_id,
 flow_ame
 /*根据实际需求增加其他所需字段*/
 from default.pdw_order_store_211_order_detail_flow_main--主表单信息
 where dt='${today -1}'
 and flow_code='/*流程编码*/'
),--提取该流程下的所有order_id
 
b1 as (
 select order_id,
 seq,--延旭：当主表单可以添加组件时，必须取seq，才可以获取所有组件的数据
 form_name,
 get_json_object(values_group,'$.label') as value1--延旭：需要注意，如果取的是接口形式的人员或门店信息，可能会用lable来选择要ID还是UID还是中文
 from default.pdw_order_store_211_order_detail_flow_form_variable_groups_di--主表单外部信息（根据蜂利器流程流程主体配置）
 lateral view explode(hivemall.json_split(form_values)) reviews as values_group
 where form_name in('/*主表单信息1*/','/*主表单信息2*/','/*主表单信息3*/','/*...*/')
),--提取主表单信息
 
b2 as (
 select order_id,
 seq,--延旭：当主表单可以添加组件时，必须取seq，才可以获取所有组件的数据
 max(case when form_name = '/*主表单信息1*/' then value1 end) form1,
 max(case when form_name = '/*主表单信息2*/' then value1 end) form2,
 max(case when form_name = '/*主表单信息3*/' then value1 end) form3,
 max(case when form_name = '/*...*/' then value1 end) form
 from b1
 group by order_id,
 seq--延旭：当主表单可以添加组件时，必须取seq，才可以获取所有组件的数据
 
),--行转列，以order_id为维度进行聚合，将同一order_id的全部信息整合为一行
 
b22 as (select t1.order_id
 ,t1.seq
 ,t2.applyUser
 /*延旭：这里拼接下面left join中获取实际主表单主体的内容，同时可以直接取b2表中seq对应的其他表单内容，根据需要添加字段*/
 from b2 t1
 left join (select b2.order_id,b2.applyUser/*延旭：这里获取实际主表单主体的内容，根据需要添加字段*/
 from b2
 where applyUser is not null
 group by b2.order_id,b2.applyUser/*延旭：这里获取实际主表单主体的内容，根据需要添加字段*/
 ) t2 on t1.order_id=t2.order_id
),--延旭：组件主表单的主体内容在用b2取数时，只有seq=1的有数据，其他的取数据需要进行补全
c as (
 select order_id,
 parent_order_id
 /*根据实际需求增加其他所需字段*/
 from default.pdw_order_store_211_order_detail_flow_main
 where dt='${today -1}'
 and flow_code in ('/*子流程1*/','/*子流程2*/','/*...*/')
),--提取子流程主表单信息(如有)
-----------------------------------------------------------以下注释的大块部分为鹏举版本取节点内容
/*
task as (
 select bb.*
 from (
 select order_id
 from a
 --from c
 --当天该需求存在子流程时from c
 )aa--限制order_id在本需求的flow_code下，减少数据量
 left join (
 select order_id,
 get_json_object(task_orders,'$.opLogs') opLogs
 from default.pdw_order_store_211_order_detail_flow_task_taskorders
 where dt='${today-1}'
 )bb
 on aa.order_id=bb.order_id
),--提取任务的每个节点的信息
 
task1 as (
 select *
 from(
 select order_id,
 get_json_object(oplog,'$.operateType') operateType,
 get_json_object(oplog,'$.variableGroups') variableGroups
 from task
 lateral view explode(hivemall.json_split(opLogs)) reviews as oplog
 )
 --where operateType='APPROVE'
 --如需求要求限定只要最终处理完成的结构则可以使用此筛选条件，如果需求需要未完成的任务当前状态则不能使用
),
 
task_rank as (
 select *
 from (
 select *,
 rank() over(partition by taskorder_node_id, order_id order by handlertime desc) rank_id
 from task1
 )aa
 where rank_id=1
),--使用窗口函数以节点和任务分组，按处理时间降序排序，取出rank_id为1的行则是最后处理的节点，防止有驳回等因素造成一个order有多个相同节点
 
task2 as (
 select order_id,
 taskorder_node_id,
 operateType,
 get_json_object(groups,'$.formVariables') formvariables
 from task_rank
 lateral view explode(hivemall.json_split(variableGroups)) reviews as groups
),
 
task3 as (
 select order_id,
 taskorder_node_id,
 operateType,
 get_json_object(variables,'$.name') name,
 get_json_object(variables,'$.values') value2
 from task2
 lateral view explode(hivemall.json_split(formVariables)) reviews as variables
),
 
task4 as (
 select order_id,
 taskorder_node_id,
 operateType,
 name,
 get_json_object(value1,'$.label') value
 from task3
 lateral view explode(hivemall.json_split(value2)) reviews as value1
),--每个任务的value值至此全部提取成功
 
task5 as (
 select order_id,
 operateType,
 max(case when taskorder_node_id = '节点1' and name = '节点信息1' then value end) node_value1,
 max(case when taskorder_node_id = '节点1' and name = '节点信息2' then value end) node_value2,
 max(case when taskorder_node_id = '节点2' and name = '节点信息3' then value end) node_value3,
 max(case when taskorder_node_id = '节点2' and name = '节点信息4' then value end) node_value4,
 max(case when taskorder_node_id = '节点n' and name = '节点信息n' then value end) node_valuen
 from task4
 group by order_id,
 operateType
),--行转列，以order_id分组整合为一行
*/
--延旭：节点内容无多表单的情况用以下版本task5
task5 as (
 select s2.order_id,v2.operate_time,v2.node_value1,v2.node_value2
 from default.pdw_order_store_211_order_detail_flow_task_taskorders s2
 inner join b22 b2 on s2.order_id=b2.order_id--节点均来自流程订单，故先关联，减少总数，提高后面的排序速度
 inner join (
 select order_id,taskorder_id,operate_time
 ,rank() over(partition by order_id order by operate_time desc) as ranking--对处理结果按时间降序排序
 ,MAX(case when formvariable_name='节点信息1' then formvariable_value else null end) as node_value1
 
 ,MAX(case when formvariable_name='节点信息2' then formvariable_value else null end) as node_value2
 
 from default.pdw_order_store_211_order_detail_flow_task_taskorders_oplogs_variablegroups t
 where dt='${today-1}'
 and formvariable_name in ('节点信息1','节点信息2')
 and operate_type='APPROVE'
 --如需求要求限定只要最终处理完成的结构则可以使用此筛选条件，如果需求需要未完成的任务当前状态则不能使用
 group by order_id,operate_time,taskorder_id
 )v2
 on v2.order_id=s2.order_id and v2.taskorder_id=s2.taskorder_id
 where s2.dt='${today-1}'
 and s2.taskorder_node_id='节点1'
 and v2.ranking='1'--获取最后一次处理的结果
 group by s2.order_id,v2.operate_time,v2.node_value1,v2.node_value2
 ),
s as (
 select *
 from default.dim_store_info
 where dt='${today-1}'
 and store_type='20'
),
 
cn as (
 select cn1.*,cn2.user_namecn, cn2.second_dept area_name from (
 select *
 from default.dim_dept_info
 where dt='${today-1}'
 ) cn1
 left join (
 select * from
 --default.dim_user_hr_view_staff_dept 鹏举版本的hr表当前已无法通过申请
 default.dim_user_hr_view_soberhi_staff_info --延旭：这是饮品站架构的hr表
 where dt='${today-1}'
 ) cn2
 --on cn1.manager_id=cn2.user_no
 on cn1.manager_id=case when length(cn2.user_no)=6 then concat('10',cn2.user_no) else cn2.user_no end
),
 
temp as (
 select *
 from s
 left join (
 select deptid,descr,part_deptid_chn,manager_id,user_namecn manager_name,area_name
 from cn
 ) sh
 on s.store_code=sh.deptid
 left join (
 select deptid dept_id,descr descr1,part_deptid_chn part_dept_id_chn
 from cn
 ) p
 on p.dept_id=sh.part_deptid_chn
 left join (
 select deptid dept_id1,descr descr2,part_deptid_chn part_dept_id_chn1,manager_id manager_code,user_namecn
 from cn
 )q
 on q.dept_id1=p.part_dept_id_chn
)
--架构代码块直接调用
 
select a.order_id,
 --...
 b2.form1,
 --...
 c.parent_order_id,
 --...(如有)
 task5.node_value1,
 --...
 temp.store_org_name, --饮品站名称
 temp.descr1, --战区
 temp.manager_id, --战区主管id
 temp.manager_name, --战区主管
 temp.area_name, --大区
 temp.manager_code, --大区负责人id
 temp.user_namecn --大区负责人
from a
left join b2 on a.order_id=b2.order_id
left join c on a.order_id=c.parent_order_id
left join task5 on c.order_id=task5.order_id
left join temp on temp.store_code=c.org_code