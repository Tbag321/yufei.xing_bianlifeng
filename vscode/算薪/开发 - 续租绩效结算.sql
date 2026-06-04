--续租条件审批
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
        ,get_json_object(x2.formVariables,'$.name') 		 as taskop_name
        ,regexp_replace(get_json_object(x2.formVariables,'$.values.label'),'^\\\[\"|"\\\]$','')  as taskop_values
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
			   	,row_number()over(partition by (order_id) order by  taskorder_create_time desc) 				as rn --取最新分区的order
			from data_build.pdw_order_store_211_order_detail_flow_task_taskorders
			where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
			and taskorder_node_id = 'UserTask_08jfekk')t1
	lateral view explode(hivemall.json_split(t1.taskorder_oplogs)) x 											as taskorder_oplogs
    lateral view outer explode(hivemall.json_split(get_json_object(x.taskorder_oplogs,'$.variableGroups'))) x1 	as variableGroups
    lateral view outer explode(hivemall.json_split(get_json_object(x1.variableGroups,'$.formVariables'))) x2 	as formVariables
    
    where get_json_object(x2.formVariables,'$.name') in ('rentStartDate','rentEndDate'
    		,'LastTotal','NewTotal'
    		,'OldAverage','newRentAverage'
    		,'neOtherAverage','NewAverage'
    		,'IncreaseInBusinessTerm1'
    		,'IncreaseInBusinessTerm2')
    and order_id in ('2110200296797772',
'2110204375925112',
'2110205886249322',
'2110205822994421',
'2110198424606631',
'2110205423421660',
'2110206418699231',
'2110206879444885',
'2110207479941142',
'2110207713173062',
'2110207777512430',
'2110205761328288',
'2110208298606254',
'2110207958665309',
'2110206454007175',
'2110208765457690',
'2110208931317018'
)

---续租合同 - 郭郭节点
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
        ,get_json_object(x2.formVariables,'$.name')          as taskop_name
        ,regexp_replace(get_json_object(x2.formVariables,'$.values.label'),'^\\\[\"|"\\\]$','')  as taskop_values
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
                ,row_number()over(partition by (order_id) order by  taskorder_create_time desc)                 as rn --取最新分区的order
            from data_build.pdw_order_store_211_order_detail_flow_task_taskorders
            where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
            and taskorder_node_id = 'UserTask_00t49u0')t1
    lateral view explode(hivemall.json_split(t1.taskorder_oplogs)) x                                            as taskorder_oplogs
    lateral view outer explode(hivemall.json_split(get_json_object(x.taskorder_oplogs,'$.variableGroups'))) x1  as variableGroups
    lateral view outer explode(hivemall.json_split(get_json_object(x1.variableGroups,'$.formVariables'))) x2    as formVariables
    
    where get_json_object(x2.formVariables,'$.name') = '22H2Ebitda'
    and order_id in ('2110206312342732',
'2110206893017726',
'2110207373116345',
'2110207421239038',
'2110207709309032',
'2110207757558415',
'2110207775858532',
'2110208203774224',
'2110208702644585',
'2110208789551020',
'2110208799215292',
'2110208843155532',
'2110208863636934',
'2110209090002487',
'2110209148744556',
'2110209427955951',
'2110209744205386'
)




