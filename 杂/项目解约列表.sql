with project_list as (
 select t1.flag_code 
 ,t1.project_name 
 ,t1.city_name 
 ,t1.store_code 
 ,t1.store_name 
 ,t1.project_id 
 ,t1.project_status_updated_time 
 from data_build.app_store_construction_project_pipeline_indicators_ha_v1 t1 
 where t1.project_status_updated_time > '1990-01-01 00:00:00.0' 
 and t1.project_status_group = '状态' 
 and t1.dt = '${today-1}'
 and t1.hr >=20 
 and t1.is_delete = 0 
 and t1.business_type = '便利店' 
 and substring_index(t1.project_status_name,' ',1) = '10' 
)

select *
from (
 select 
 t2.flag_code as `插旗编码`
 ,t2.project_name as `项目名称`
 ,t2.city_name as `城市`
 ,t2.store_code as `门店编码`
 ,t2.store_name as `门店名称`
 ,create_time as `创建时间` 
 ,flow_order_id as `解约主线任务工作流单号`
 ,case when t1.cancel_state = 'suspend' then '解约中止'
 when t1.cancel_state = 'doing' then '解约中'
 when t1.cancel_state = 'done' then '解约完成'
 end as `解约状态`
 ,case when cancel_type = 1 then '先谈后撤' 
 when cancel_type = 2 then '先撤后谈' 
 when cancel_type = 3 then '谈判同时撤店'
 when cancel_type = 0 then null
 end as `解约类型`
 ,cancel_method as `解约方式`
 ,rent_reduction_ratio as `降租保留比例`
 ,withdraw_shop_date as `完成撤店时间`
 ,case when cancel_source = 1 then '甲方违约'
 when cancel_source = 2 then '乙方违约'
 when cancel_source = 3 then '到期不续'
 when cancel_source = 4 then '法务评估无责解约'
 when cancel_source = 99 then '其他'
 when cancel_source = 0 then null
 end as `发起来源`
 ,other_cancel_source as `其他发起来源`
 ,case when revoke_reason = 1 then '门店降免租保留'
 when revoke_reason = 2 then '门店策略保留'
 when revoke_reason = 99 then '其他'
 when revoke_reason = 0 then null
 end as `撤销备注`
 ,row_number()over(partition by flag_code order by create_time desc) as rn
 from data_build.pdw_opc_flag_project_cancel_sign_view t1
 left join project_list t2 on t1.project_id = t2.project_id 
 where t1.dt >= 20230201
 and t2.flag_code is not null
)t1
where t1.rn = 1