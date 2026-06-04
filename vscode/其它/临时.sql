def read_sql(client, sql):
    data, columns = client.execute(sql, columnar=True, with_column_types=True)
    df = pd.DataFrame(
        {re.sub(r'\W', '_', col[0]): d
         for d, col in zip(data, columns)})
    return df
your_sql = '''
     SELECT root_code,
 count(1) as total_cnt,/*总面数-展示*/ 

 count(if(correct_0=1,1,null)) as qual_cnt_0, 
 count(if(chenlie_miss_higconfi_0=1,1,null)) as miss_higconfid_cnt_0, 
 count(if(chenlie_miss_lowconfi_0=1,1,null)) as miss_lowconfid_cnt_0, 
 count(if(stock_miss_0=1,1,null)) as stock_miss_cnt_0, 
 qual_cnt_0+miss_higconfid_cnt_0+miss_lowconfid_cnt_0+stock_miss_cnt_0 AS operation_cnt_0, 
 if(operation_cnt_0=0,NULL,qual_cnt_0/operation_cnt_0) AS qual_rate_0,

 count(if(correct_1=1,1,null)) as qual_cnt_1, 
 count(if(chenlie_miss_higconfi_1=1,1,null)) as miss_higconfid_cnt_1, 
 count(if(chenlie_miss_lowconfi_1=1,1,null)) as miss_lowconfid_cnt_1, 
 count(if(stock_miss_1=1,1,null)) as stock_miss_cnt_1, 
 qual_cnt_1+miss_higconfid_cnt_1+miss_lowconfid_cnt_1+stock_miss_cnt_1 AS operation_cnt_1, 
 if(operation_cnt_1=0,NULL,qual_cnt_1/operation_cnt_1) AS qual_rate_1,

 count(if(correct_2=1,1,null)) as qual_cnt_2, 
 count(if(chenlie_miss_higconfi_2=1,1,null)) as miss_higconfid_cnt_2, 
 count(if(chenlie_miss_lowconfi_2=1,1,null)) as miss_lowconfid_cnt_2,
 count(if(stock_miss_2=1,1,null)) as stock_miss_cnt_2, 
 qual_cnt_2+miss_higconfid_cnt_2+miss_lowconfid_cnt_2+stock_miss_cnt_2 AS operation_cnt_2, 
 if(operation_cnt_2=0,NULL,qual_cnt_2/operation_cnt_2) AS qual_rate_2,

 count(if(correct_3=1,1,null)) as qual_cnt_3, 
 count(if(chenlie_miss_higconfi_3=1,1,null)) as miss_higconfid_cnt_3, 
 count(if(chenlie_miss_lowconfi_3=1,1,null)) as miss_lowconfid_cnt_3, 
 count(if(stock_miss_3=1,1,null)) as stock_miss_cnt_3, 
 qual_cnt_3+miss_higconfid_cnt_3+miss_lowconfid_cnt_3 AS operation_cnt_3, 
 if(operation_cnt_3=0,NULL,qual_cnt_3/operation_cnt_3) AS qual_rate_3


 FROM dt_materialized_chenlie_sku_detail_all 
 WHERE 1=1 
 AND statistic_date = toDate(yesterday()) 
 and statistic_date>=toDate(yesterday()) 
 AND toInt64(shelfid)>0 
 group by root_code;
    '''
client = Client.from_url(
        "clickhouse://shop_carplay_rw:645E28CF-F865-4452-8FBD-7E7540CD0487@rw-carplay-w-clickhouse.vip.blibee.com/db_shop_carplay"
    )
df = read_sql(client, your_sql)













*****************************************************************************************************************************************************************************
with  order_store_211_order_detail_flow_main as
(
   select order_id,
           get_json_object(data,'$.parentFlowOrderId') as parent_order_id,
           get_json_object(data,'$.flowName') as flow_ame,
           get_json_object(data,'$.flowCode') as flow_code,
           get_json_object(data,'$.flowVersion') as flow_version,
           get_json_object(data,'$.driverFlowId') as driver_flow_id,
           get_json_object(data,'$.businessCode') as business_code,
           get_json_object(get_json_object(data,'$.initiator'),'$.code') as initiator_code,
           get_json_object(data,'$.orgCode') as org_code,
           get_json_object(data,'$.orgName') as org_name,
           get_json_object(data,'$.cityCode') as city_code,
           get_json_object(data,'$.followers') as followers,
           get_json_object(data,'$.imGroupCode') as im_group_code,
           get_json_object(data,'$.orderStatus') as order_status,
           get_json_object(data,'$.remark') as remark,
           get_json_object(data,'$.wsId') as ws_id,
           get_json_object(data,'$.createTime') as create_time,
           get_json_object(data,'$.updateTime') as update_time,
           data,
           dt
        from default.pdw_order_store_211_order_detail_hi t1
        where dt = '${DATE}' and hr='${HOUR}'
            and section='flow-main'
            and get_json_object(data,'$.flowCode')='${FLOW_CODE}'

),
exploded AS (
    SELECT 
        t1.order_id,
        t1.dt,
        x.variable_group
    FROM (
        SELECT 
            order_id,
            dt,
            get_json_object(data, '$.variableGroups') AS variable_groups
        FROM data_build.pdw_order_store_211_order_detail_hi_view t1
        WHERE dt = '${DATE}' AND hr = '${HOUR}' AND section = 'flow-form'
    ) t1
    LATERAL VIEW explode(split(regexp_replace(variable_groups, '\\[|\\]', ''), '\\},\\{')) x AS variable_group
),
formVariablesExploded AS (
    SELECT 
        order_id,
        dt,
        get_json_object(variable_group, '$.row_id') AS row_id,
        get_json_object(variable_group, '$.seq') AS seq,
        x1.formVariable
    FROM exploded
    LATERAL VIEW explode(split(regexp_replace(get_json_object(variable_group, '$.formVariables'), '\\[|\\]', ''), '\\},\\{')) x1 AS formVariable
),
order_store_211_order_detail_flow_form_variable_groups_di as(
SELECT DISTINCT 
    order_id,
    row_id AS index,
    get_json_object(formVariable, '$.name') AS form_name,
    get_json_object(formVariable, '$.values') AS form_values,
    seq,
    dt
FROM formVariablesExploded
),
order_store_211_order_detail_flow_task_taskorders as
(

    select distinct
    t1.order_id,
           get_json_object(x.taskOrders,'$.taskOrderId') as taskorder_id,
           get_json_object(x.taskOrders,'$.activityTaskOrderId') as activity_taskorder_id,
           get_json_object(x.taskOrders,'$.taskNodeId') as taskorder_node_id,
           hivemall.json_split(get_json_object(get_json_object(x.taskOrders,'$.handler'),'$.[].code')) as taskorder_handler,
           hivemall.json_split(get_json_object( get_json_object(x.taskOrders,'$.assignee'),'$.[].code')) as taskorder_assignee,
           get_json_object(x.taskOrders,'$.taskStatus') as taskorder_status,
           get_json_object(x.taskOrders,'$.taskResult') as taskorder_result,
           get_json_object(x.taskOrders,'$.opLogs')     as taskorder_oplogs,
           get_json_object(x.taskOrders,'$.groupCode')  as taskorder_group_code,
           get_json_object(x.taskOrders,'$.createTime') as taskorder_create_time,
           get_json_object(x.taskOrders,'$.updateTime') as taskorder_update_time,
           get_json_object(x.taskOrders,'$.deadLineTime') as taskorder_deadLineTime,
           get_json_object(x.taskOrders,'$.index') as index,
           x.taskOrders,
           dt
    from (
          select order_id,
                 get_json_object(data,'$.taskOrders') as taskOrders,
                 create_date,
                 update_time,
                 dt
              from default.pdw_order_store_211_order_detail_hi t1
              where dt = '${DATE}' and hr='${HOUR}'
                  and section='flow-task'
          ) t1
          lateral view explode(hivemall.json_split(t1.taskOrders)) x as taskOrders

),
 flow_form_info as
(
 select
         flow_name,
         order_status,
         create_time,
         order_id,
         --index,
         --seq,
         max(case when form_name='flagCode' then get_json_object(hivemall.json_split(form_values)[0],'$.value') end) flag_code,
         max(case when form_name='projectId' then get_json_object(hivemall.json_split(form_values)[0],'$.value') end) project_id,
         max(case when form_name='hurdleAmount' then get_json_object(hivemall.json_split(form_values)[0],'$.value') end) hurdleAmount,
         max(case when form_name='daySaleAmount' then get_json_object(hivemall.json_split(form_values)[0],'$.value') end) daySaleAmount,
         max(case when form_name='aiDaySaleAmount' then get_json_object(hivemall.json_split(form_values)[0],'$.value') end) aiDaySaleAmount,
         max(case when form_name='aiHurdleAmount' then get_json_object(hivemall.json_split(form_values)[0],'$.value') end) aiHurdleAmount,
         max(case when form_name='elementDaySaleAmount' then get_json_object(hivemall.json_split(form_values)[0],'$.value') end) elementDaySaleAmount,
         max(case when form_name='elementHurdleAmount' then get_json_object(hivemall.json_split(form_values)[0],'$.value') end) elementHurdleAmount,
         max(case when form_name='keyShop' then get_json_object(hivemall.json_split(form_values)[0],'$.label') end)  keyShop,
         max(case when form_name='shopGradeForecast' then get_json_object(hivemall.json_split(form_values)[0],'$.label') end)  shopGradeForecast,
         max(case when form_name='meetingTimes' then get_json_object(hivemall.json_split(form_values)[0],'$.value') end) meeting_times
 from (
 select a.flow_ame as flow_name,
        a.order_id,
        a.order_status,
        a.create_time,
        b.form_name,
        b.form_values,
        b.index,
        b.seq,
        row_number() over(partition by a.order_id,b.form_name,b.index,b.seq order by b.dt desc) rm
 from  order_store_211_order_detail_flow_main a
 left join  order_store_211_order_detail_flow_form_variable_groups_di b
      on a.order_id=b.order_id
      and b.dt>='${DT_BEGIN}'
 where a.dt='${DATE}'
       and a.flow_code='${FLOW_CODE}'
       --and a.order_id='2110074403975053'
 ) a where rm=1
     group by flow_name,
         order_status,
         create_time,
         --index,
         --seq,
         order_id
),
flow_task_info as
(
select order_id,
       taskorder_node_id,
       taskorder_status,
       taskorder_result,
       taskorder_create_time,
       flow_version,
       max(case when operateType in ('APPROVE','REJECT','REBUT','REVOKE') then handler end) as handler,
       max(case when operateType in ('APPROVE','REJECT','REBUT','REVOKE') then handlerTime end) as handlerTime,
       max(case when operateType='ACCEPT' then handlerTime end) as receive_time,
       max(case when operateType='ACCEPT' then handler end) as ACCEPT_handler,
       max(case when taskop_name = 'planRevoke' then get_json_object(hivemall.json_split(taskop_values)[0],'$.label') end)  as plan_revoke,
       max(case when taskop_name = 'infoFail' then get_json_object(hivemall.json_split(taskop_values)[0],'$.label') end)  as plan_revoke_reason,
       taskorder_handler[0] taskorder_handler,
       index
from
(
    select a.order_id,
           a.taskorder_node_id,
           a.taskorder_status,
           a.taskorder_result,
           a.taskorder_create_time,
           a.flow_version,
           get_json_object(x.taskorder_oplogs,'$.handler') as handler,
           get_json_object(x.taskorder_oplogs,'$.operateType') as operateType,
           get_json_object(x.taskorder_oplogs,'$.handlerTime') as handlerTime,
           get_json_object(x2.formVariables,'$.name') as taskop_name,
           get_json_object(x2.formVariables,'$.values') as taskop_values,
           taskorder_handler,
           index
    from (
    select a.order_id,
           b.taskorder_node_id,
           b.taskorder_status,
           b.taskorder_result,
           b.taskorder_create_time,
           b.taskorder_oplogs,
           a.flow_version,
           b.taskorder_handler,
           b.index
           from order_store_211_order_detail_flow_main a
    left join  order_store_211_order_detail_flow_task_taskorders b
       on a.order_id=b.order_id
       and b.dt='${DATE}'
    where a.dt='${DATE}'
          and a.flow_code='${FLOW_CODE}'
        -- and a.order_id='2110074403975053'
    ) a
    lateral view explode(hivemall.json_split(a.taskorder_oplogs)) x as taskorder_oplogs
    lateral view outer explode(hivemall.json_split(get_json_object(x.taskorder_oplogs,'$.variableGroups'))) x1 as variableGroups
    lateral view outer explode(hivemall.json_split(get_json_object(x1.variableGroups,'$.formVariables'))) x2 as formVariables
) b
group by order_id,
       taskorder_node_id,
       taskorder_status,
       taskorder_result,
       taskorder_create_time,
       flow_version,
       taskorder_handler[0],
       index

)

 select
       document_no,
       document_name,
       project_id,
       flag_code,
       document_time,
       document_status,
       task_node_id,
       task_node_name,
       task_node_status,
       task_node_result,
       task_node_handler,
       task_node_handler_time,
       task_node_receive_time,
       task_node_start_time,
       extended_info,
       case when rank()over(partition by a.flag_code,a.document_status order by a.document_time desc) =1 and document_status = 'FINISHED'  then 1 else 0 end,
       case when row_number()over(partition by a.document_no order by task_node_start_time desc) = 1 and task_node_status = 'FINISHED' then 1 else 0 end,
       case when row_number()over(partition by a.document_no order by task_node_start_time desc) = 1 then 1 else 0 end as is_task_new_code_all_status,
       case when row_number()over(partition by project_id order by document_time desc) = 1 then 1 else 0 end,
       index
        from (
       select a.*,
       rank() over(partition by document_no order by version desc ) as rm
       from (
       select
       document_no,
       document_name,
       project_id,
       flag_code,
       cast(document_time as string) as document_time,
       document_status,
       task_node_id,
       task_node_name,
       task_node_status,
       task_node_result,
       task_node_handler,
       cast(task_node_handler_time as string) as task_node_handler_time,
       cast(task_node_receive_time as string) as task_node_receive_time,
       cast(task_node_start_time as string) as task_node_start_time,
       extended_info,
       cast(is_project_new_task as string) as is_project_new_task,
       cast(is_task_new_node as string) as is_task_new_node,
       '0' as version,
       cast(is_task_new_code_all_status as string) as is_task_new_code_all_status,
       cast(is_project_new_task_all_status as string) as is_project_new_task_all_status,
       index
       from data_build.dwd_store_construction_project_dailysale_hurdle_apply_task_v1
       where dt='${DATE_SUB1DAY}'
       union all
 select  cast(a.order_id as string),
         a.flow_name,
         d.id,
         a.flag_code,
         a.create_time,
         a.order_status,
         b.taskorder_node_id,
         c.node_name,
         b.taskorder_status,
         b.taskorder_result,
         coalesce(b.handler,b.ACCEPT_handler,b.taskorder_handler),
         b.handlerTime,
         b.receive_time,
         b.taskorder_create_time,
         map(
             'hurdle_amount',a.hurdleAmount, --上会Hurdle
             'dailysale_amount',a.daySaleAmount,-- 上会日商
             'ai_dailysale_amount',a.aiDaySaleAmount,--ai日商
             'ai_hurdle_amount',a.aiHurdleAmount,--aihurdle
             'element_dailysale_amount',a.elementDaySaleAmount,--业务版日商
             'element_hurdle_amount',a.elementHurdleAmount, --业务版hurdle
             'is_key_shop',a.keyShop,--是否星标
             'shop_grade_forecast',a.shopGradeForecast, --项目评级
             'meeting_times',a.meeting_times,
             'plan_revoke',b.plan_revoke,
             'plan_revoke_reason',b.plan_revoke_reason
         ),
         case when rank()over(partition by a.flag_code,a.order_status order by a.create_time desc) = 1 and a.order_status = 'FINISHED' then '1' else '0' end as is_project_new_task,
         case when row_number()over(partition by a.order_id order by b.taskorder_create_time desc) =1 and b.taskorder_status = 'FINISHED' then '1' else '0' end as is_task_new_node,
         '1' as version,
         case when row_number()over(partition by a.order_id order by b.taskorder_create_time desc) =1  then '1' else '0' end as is_task_new_code_all_status,
         case when rank()over(partition by d.id order by a.create_time desc) = 1 then '1' else '0' end as is_project_new_task_all_status,
         cast(b.index as int) as index
       from flow_form_info a
       left join flow_task_info b
            on a.order_id=b.order_id
       left join default.pdw_ripple_flow_definition_flow_node_definition c
            on c.dt='$DATE_SUB1DAY'
            and c.flow_version=b.flow_version
            and c.node_id=b.taskorder_node_id
            and c.flow_code='${FLOW_CODE}'
       left join default.pdw_opc_flag_project_upload_info_ha d
            on d.dt='$DATE' and hr='${HOUR}'
            and d.flag_code=upper(a.flag_code)
            ) a) a where rm=1



///////////////////////////////////////////////////////////////////////////////////0523/////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////0523/////////////////////////////////////////////////////////////////////////////////
