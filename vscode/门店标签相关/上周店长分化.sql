-- 上周分化
with jiameng_list as (
select distinct 
store_code
from data_build.pdw_bach_baseinfo_shop_shop
where dt = '${today-1}'
and self_take_type = '4' --加盟店
),
project_list as (
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
,chedian_list as (
select 

store_code

from (
select 
t2.flag_code 
,t2.project_name 
,t2.city_name 
,t2.store_code as store_code
,t2.store_name 
,create_time 
,flow_order_id 
,case when t1.cancel_state = 'suspend' then '解约中止'
when t1.cancel_state = 'doing' then '解约中'
when t1.cancel_state = 'done' then '解约完成'
end as cancel_state
,case when cancel_type = 1 then '先谈后撤' 
when cancel_type = 2 then '先撤后谈' 
when cancel_type = 3 then '谈判同时撤店'
when cancel_type = 0 then null
end as cancel_type
,cancel_method 
,rent_reduction_ratio 
,withdraw_shop_date 
,case when cancel_source = 1 then '甲方违约'
when cancel_source = 2 then '乙方违约'
when cancel_source = 3 then '到期不续'
when cancel_source = 4 then '法务评估无责解约'
when cancel_source = 99 then '其他'
when cancel_source = 0 then null
end as cancel_source
,other_cancel_source 
,case when revoke_reason = 1 then '门店降免租保留'
when revoke_reason = 2 then '门店策略保留'
when revoke_reason = 99 then '其他'
when revoke_reason = 0 then null
end as revoke_reason
,row_number()over(partition by flag_code order by create_time desc,update_time desc) as rn
from data_build.pdw_opc_flag_project_cancel_sign_view t1
left join project_list t2 on t1.project_id = t2.project_id 
where t1.dt >= 20230201
and t2.flag_code is not null
) t1
where t1.rn = 1
and cancel_state not in ('解约中止')
)

select distinct
t1.employee_id
,t1.name
,t1.store_code
,t1.code
,t1.class
,t2.hps_d_hr_status
,t3.protect_tag as protect_tag_new
,case when t4.staff_code is not null then 1 else 0 end as is_taihuan
,t8.protect_tag as `店员开工表现`
,t5.final_rank as `上周日维度标签`
,t5.total_score as `上周得分`
,t6.final_rank as `本周日维度标签`
,t6.total_score as `本周得分`
,t7.class as `上上周标签`
,t6.will_score as `本周意愿度`
,t6.performance_score as `本周个人能力`
,t6.store_score as `本周门店质量`
,t6.manage_score as `本周团队管理`
,t4.type as `汰换原因`
,t5.will_score as `上周意愿度`
,t5.performance_score as `上周个人能力`
,t5.store_score as `上周门店质量`
,t5.manage_score as `上周团队管理`
,case when t9.store_code is not null then 1
when t10.store_code is not null then 1
else 0 end as `是否撤店/加盟`
from data_build.ods_uploads_manager_tag_4 t1 
left join data_build.pdw_psprod_ps_blf_ehr_pers_vw_view t2 on t1.employee_id = if(length(t2.emplid)=6,concat('10',t2.emplid),t2.emplid) and t2.dt = '${today-1}' 
left join data_build.dwd_store_construction_manager_tag_weekly_di t3 on t1.employee_id= t3.employee_id and t3.dt = '${today-1}' 
left join data_shop.ods_uploads_eliminate_manager t4 on t1.employee_id = t4.staff_code 
left join data_build.dwd_manager_tag_v1_di t5 on t1.employee_id = t5.employee_id and t5.dt = '${today-8}' 
left join data_build.dwd_manager_tag_v1_di t6 on t1.employee_id = t6.employee_id and t6.dt = '${today-1}' 
left join data_build.ods_uploads_manager_tag_4 t7 on t1.employee_id= t7.employee_id and t7.dt = '${today-15}' 
left join data_shop.dm_shop_staff_protect_tag_v2 t8 on t1.employee_id=t8.staff_code  and t8.dt = '${today-1}'
left join jiameng_list t9 on t1.store_code = t9.store_code 
left join chedian_list t10 on t1.store_code = t10.store_code 
where t1.dt = '${today-8}'

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- 上周分化（0219周代码）
with jiameng_list as (
select distinct 
store_code
from default.pdw_bach_baseinfo_shop_shop
where dt = '${today-1}'
and self_take_type = '4' --加盟店
),
project_list as (
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
,chedian_list as (
select 
store_code
from (
select 
t2.flag_code 
,t2.project_name 
,t2.city_name 
,t2.store_code as store_code
,t2.store_name 
,create_time 
,flow_order_id 
,case when t1.cancel_state = 'suspend' then '解约中止'
when t1.cancel_state = 'doing' then '解约中'
when t1.cancel_state = 'done' then '解约完成'
end as cancel_state
,case when cancel_type = 1 then '先谈后撤' 
when cancel_type = 2 then '先撤后谈' 
when cancel_type = 3 then '谈判同时撤店'
when cancel_type = 0 then null
end as cancel_type
,cancel_method 
,rent_reduction_ratio 
,withdraw_shop_date 
,case when cancel_source = 1 then '甲方违约'
when cancel_source = 2 then '乙方违约'
when cancel_source = 3 then '到期不续'
when cancel_source = 4 then '法务评估无责解约'
when cancel_source = 99 then '其他'
when cancel_source = 0 then null
end as cancel_source
,other_cancel_source 
,case when revoke_reason = 1 then '门店降免租保留'
when revoke_reason = 2 then '门店策略保留'
when revoke_reason = 99 then '其他'
when revoke_reason = 0 then null
end as revoke_reason
,row_number()over(partition by flag_code order by create_time desc,update_time desc) as rn
from data_build.pdw_opc_flag_project_cancel_sign_view t1
left join project_list t2 on t1.project_id = t2.project_id 
where t1.dt >= 20230201
and t2.flag_code is not null
) t1
where t1.rn = 1
and cancel_state not in ('解约中止')
)

select distinct
t1.employee_id
,t1.name
,t1.store_code
,t1.code
,t1.class
,t2.hps_d_hr_status
,t3.protect_tag as protect_tag_new
,case when t4.staff_code is not null then 1 else 0 end as is_taihuan
,t8.protect_tag as `店员开工表现`
,t5.final_rank as `上周日维度标签`
,t5.total_score as `上周得分`
,t6.final_rank as `本周日维度标签`
,t6.total_score as `本周得分`
,t7.class as `上上周标签`
,t6.will_score as `本周意愿度`
,t6.performance_score as `本周个人能力`
,t6.store_score as `本周门店质量`
,t6.manage_score as `本周团队管理`
,t4.type as `汰换原因`
,t5.will_score as `上周意愿度`
,t5.performance_score as `上周个人能力`
,t5.store_score as `上周门店质量`
,t5.manage_score as `上周团队管理`
,case when t9.store_code is not null then 1
when t10.store_code is not null then 1
else 0 end as `是否撤店/加盟`
from data_build.ods_uploads_manager_tag_4 t1 
left join data_build.pdw_psprod_ps_blf_ehr_pers_vw_view t2 on t1.employee_id = if(length(t2.emplid)=6,concat('10',t2.emplid),t2.emplid) and t2.dt = '${today-1}' 
left join data_build.dwd_store_construction_manager_tag_weekly_di t3 on t1.employee_id= t3.employee_id and t3.dt = '${today-1}' 
left join data_shop.ods_uploads_eliminate_manager t4 on t1.employee_id = t4.staff_code 
left join data_build.dwd_manager_tag_v1_di t5 on t1.employee_id = t5.employee_id and t5.dt = '${today-15}'--跑0205周 
left join data_build.dwd_manager_tag_v1_di t6 on t1.employee_id = t6.employee_id and t6.dt = '${today-1}' 
left join data_build.ods_uploads_manager_tag_4 t7 on t1.employee_id= t7.employee_id and t7.dt = '${today-22}'--跑0129周 
left join data_shop.dm_shop_staff_protect_tag_v2 t8 on t1.employee_id=t8.staff_code  and t8.dt = '${today-1}'
left join jiameng_list t9 on t1.store_code = t9.store_code 
left join chedian_list t10 on t1.store_code = t10.store_code 
where t1.dt = '${today-15}'--跑0205周

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- 上周分化（0226周代码）
with jiameng_list as (
select distinct 
store_code
from default.pdw_bach_baseinfo_shop_shop
where dt = '${today-1}'
and self_take_type = '4' --加盟店
),
project_list as (
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
,chedian_list as (
select 
store_code
from (
select 
t2.flag_code 
,t2.project_name 
,t2.city_name 
,t2.store_code as store_code
,t2.store_name 
,create_time 
,flow_order_id 
,case when t1.cancel_state = 'suspend' then '解约中止'
when t1.cancel_state = 'doing' then '解约中'
when t1.cancel_state = 'done' then '解约完成'
end as cancel_state
,case when cancel_type = 1 then '先谈后撤' 
when cancel_type = 2 then '先撤后谈' 
when cancel_type = 3 then '谈判同时撤店'
when cancel_type = 0 then null
end as cancel_type
,cancel_method 
,rent_reduction_ratio 
,withdraw_shop_date 
,case when cancel_source = 1 then '甲方违约'
when cancel_source = 2 then '乙方违约'
when cancel_source = 3 then '到期不续'
when cancel_source = 4 then '法务评估无责解约'
when cancel_source = 99 then '其他'
when cancel_source = 0 then null
end as cancel_source
,other_cancel_source 
,case when revoke_reason = 1 then '门店降免租保留'
when revoke_reason = 2 then '门店策略保留'
when revoke_reason = 99 then '其他'
when revoke_reason = 0 then null
end as revoke_reason
,row_number()over(partition by flag_code order by create_time desc,update_time desc) as rn
from data_build.pdw_opc_flag_project_cancel_sign_view t1
left join project_list t2 on t1.project_id = t2.project_id 
where t1.dt >= 20230201
and t2.flag_code is not null
) t1
where t1.rn = 1
and cancel_state not in ('解约中止')
)

select distinct
t1.employee_id
,t1.name
,t1.store_code
,t1.code
,t1.class
,t2.hps_d_hr_status
,t3.protect_tag as protect_tag_new
,case when t4.staff_code is not null then 1 else 0 end as is_taihuan
,t8.protect_tag as `店员开工表现`
,t5.final_rank as `上周日维度标签`
,t5.total_score as `上周得分`
,t6.final_rank as `本周日维度标签`
,t6.total_score as `本周得分`
,t7.class as `上上周标签`
,t6.will_score as `本周意愿度`
,t6.performance_score as `本周个人能力`
,t6.store_score as `本周门店质量`
,t6.manage_score as `本周团队管理`
,t4.type as `汰换原因`
,t5.will_score as `上周意愿度`
,t5.performance_score as `上周个人能力`
,t5.store_score as `上周门店质量`
,t5.manage_score as `上周团队管理`
,case when t9.store_code is not null then 1
when t10.store_code is not null then 1
else 0 end as `是否撤店/加盟`
from data_build.ods_uploads_manager_tag_4 t1 
left join data_build.pdw_psprod_ps_blf_ehr_pers_vw_view t2 on t1.employee_id = if(length(t2.emplid)=6,concat('10',t2.emplid),t2.emplid) and t2.dt = '${today-1}' 
left join data_build.dwd_store_construction_manager_tag_weekly_di t3 on t1.employee_id= t3.employee_id and t3.dt = '${today-1}' 
left join data_shop.ods_uploads_eliminate_manager t4 on t1.employee_id = t4.staff_code 
left join data_build.dwd_manager_tag_v1_di t5 on t1.employee_id = t5.employee_id and t5.dt = '${today-8}'--跑0219周 
left join data_build.dwd_manager_tag_v1_di t6 on t1.employee_id = t6.employee_id and t6.dt = '${today-1}' 
left join data_build.ods_uploads_manager_tag_4 t7 on t1.employee_id= t7.employee_id and t7.dt = '${today-22}'--跑0205周 
left join data_shop.dm_shop_staff_protect_tag_v2 t8 on t1.employee_id=t8.staff_code  and t8.dt = '${today-1}'
left join jiameng_list t9 on t1.store_code = t9.store_code 
left join chedian_list t10 on t1.store_code = t10.store_code 
where t1.dt = '${today-8}'--跑0219周

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- 上周分化（0304周代码）
with jiameng_list as (
select distinct 
store_code
from default.pdw_bach_baseinfo_shop_shop
where dt = '${today-1}'
and self_take_type = '4' --加盟店
),
project_list as (
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
,chedian_list as (
select 
store_code
from (
select 
t2.flag_code 
,t2.project_name 
,t2.city_name 
,t2.store_code as store_code
,t2.store_name 
,create_time 
,flow_order_id 
,case when t1.cancel_state = 'suspend' then '解约中止'
when t1.cancel_state = 'doing' then '解约中'
when t1.cancel_state = 'done' then '解约完成'
end as cancel_state
,case when cancel_type = 1 then '先谈后撤' 
when cancel_type = 2 then '先撤后谈' 
when cancel_type = 3 then '谈判同时撤店'
when cancel_type = 0 then null
end as cancel_type
,cancel_method 
,rent_reduction_ratio 
,withdraw_shop_date 
,case when cancel_source = 1 then '甲方违约'
when cancel_source = 2 then '乙方违约'
when cancel_source = 3 then '到期不续'
when cancel_source = 4 then '法务评估无责解约'
when cancel_source = 99 then '其他'
when cancel_source = 0 then null
end as cancel_source
,other_cancel_source 
,case when revoke_reason = 1 then '门店降免租保留'
when revoke_reason = 2 then '门店策略保留'
when revoke_reason = 99 then '其他'
when revoke_reason = 0 then null
end as revoke_reason
,row_number()over(partition by flag_code order by create_time desc,update_time desc) as rn
from data_build.pdw_opc_flag_project_cancel_sign_view t1
left join project_list t2 on t1.project_id = t2.project_id 
where t1.dt >= 20230201
and t2.flag_code is not null
) t1
where t1.rn = 1
and cancel_state not in ('解约中止')
)

select distinct
t1.employee_id
,t1.name
,t1.store_code
,t1.code
,t1.class
,t2.hps_d_hr_status
,t3.protect_tag as protect_tag_new
,case when t4.staff_code is not null then 1 else 0 end as is_taihuan
,t8.protect_tag as `店员开工表现`
,t5.final_rank as `上周日维度标签`
,t5.total_score as `上周得分`
,t6.final_rank as `本周日维度标签`
,t6.total_score as `本周得分`
,t7.class as `上上周标签`
,t6.will_score as `本周意愿度`
,t6.performance_score as `本周个人能力`
,t6.store_score as `本周门店质量`
,t6.manage_score as `本周团队管理`
,t4.type as `汰换原因`
,t5.will_score as `上周意愿度`
,t5.performance_score as `上周个人能力`
,t5.store_score as `上周门店质量`
,t5.manage_score as `上周团队管理`
,case when t9.store_code is not null then 1
when t10.store_code is not null then 1
else 0 end as `是否撤店/加盟`
from data_build.ods_uploads_manager_tag_4 t1 
left join data_build.pdw_psprod_ps_blf_ehr_pers_vw_view t2 on t1.employee_id = if(length(t2.emplid)=6,concat('10',t2.emplid),t2.emplid) and t2.dt = '${today-1}' 
left join data_build.dwd_store_construction_manager_tag_weekly_di t3 on t1.employee_id= t3.employee_id and t3.dt = '${today-1}' 
left join data_shop.ods_uploads_eliminate_manager t4 on t1.employee_id = t4.staff_code 
left join data_build.dwd_manager_tag_v1_di t5 on t1.employee_id = t5.employee_id and t5.dt = '${today-8}'--跑0226周 
left join data_build.dwd_manager_tag_v1_di t6 on t1.employee_id = t6.employee_id and t6.dt = '${today-1}' 
left join data_build.ods_uploads_manager_tag_4 t7 on t1.employee_id= t7.employee_id and t7.dt = '${today-15}'--跑0219周 
left join data_shop.dm_shop_staff_protect_tag_v2 t8 on t1.employee_id=t8.staff_code  and t8.dt = '${today-1}'
left join jiameng_list t9 on t1.store_code = t9.store_code 
left join chedian_list t10 on t1.store_code = t10.store_code 
where t1.dt = '${today-8}'--跑0226周

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- 上周分化（0311周代码）
with jiameng_list as (
select distinct 
store_code
from data_build.pdw_bach_baseinfo_shop_shop
where dt = '${today-1}'
and self_take_type = '4' --加盟店
),
project_list as (
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
,chedian_list as (
select 
store_code
from (
select 
t2.flag_code 
,t2.project_name 
,t2.city_name 
,t2.store_code as store_code
,t2.store_name 
,create_time 
,flow_order_id 
,case when t1.cancel_state = 'suspend' then '解约中止'
when t1.cancel_state = 'doing' then '解约中'
when t1.cancel_state = 'done' then '解约完成'
end as cancel_state
,case when cancel_type = 1 then '先谈后撤' 
when cancel_type = 2 then '先撤后谈' 
when cancel_type = 3 then '谈判同时撤店'
when cancel_type = 0 then null
end as cancel_type
,cancel_method 
,rent_reduction_ratio 
,withdraw_shop_date 
,case when cancel_source = 1 then '甲方违约'
when cancel_source = 2 then '乙方违约'
when cancel_source = 3 then '到期不续'
when cancel_source = 4 then '法务评估无责解约'
when cancel_source = 99 then '其他'
when cancel_source = 0 then null
end as cancel_source
,other_cancel_source 
,case when revoke_reason = 1 then '门店降免租保留'
when revoke_reason = 2 then '门店策略保留'
when revoke_reason = 99 then '其他'
when revoke_reason = 0 then null
end as revoke_reason
,row_number()over(partition by flag_code order by create_time desc,update_time desc) as rn
from data_build.pdw_opc_flag_project_cancel_sign_view t1
left join project_list t2 on t1.project_id = t2.project_id 
where t1.dt >= 20230201
and t2.flag_code is not null
) t1
where t1.rn = 1
and cancel_state not in ('解约中止')
)

select distinct
t1.employee_id
,t1.name
,t1.store_code
,t1.code
,t1.class
,t2.hps_d_hr_status
,t3.protect_tag as protect_tag_new
,case when t4.staff_code is not null then 1 else 0 end as is_taihuan
,t8.protect_tag as `店员开工表现`
,t5.final_rank as `上周日维度标签`
,t5.total_score as `上周得分`
,t6.final_rank as `本周日维度标签`
,t6.total_score as `本周得分`
,t7.class as `上上周标签`
,t6.will_score as `本周意愿度`
,t6.performance_score as `本周个人能力`
,t6.store_score as `本周门店质量`
,t6.manage_score as `本周团队管理`
,t4.type as `汰换原因`
,t5.will_score as `上周意愿度`
,t5.performance_score as `上周个人能力`
,t5.store_score as `上周门店质量`
,t5.manage_score as `上周团队管理`
,case when t9.store_code is not null then 1
when t10.store_code is not null then 1
else 0 end as `是否撤店/加盟`
from data_build.ods_uploads_manager_tag_4 t1 
left join data_build.pdw_psprod_ps_blf_ehr_pers_vw_view t2 on t1.employee_id = if(length(t2.emplid)=6,concat('10',t2.emplid),t2.emplid) and t2.dt = '${today-1}' 
left join data_build.dwd_store_construction_manager_tag_weekly_di t3 on t1.employee_id= t3.employee_id and t3.dt = '${today-1}' 
left join data_shop.ods_uploads_eliminate_manager t4 on t1.employee_id = t4.staff_code 
left join data_build.dwd_manager_tag_v1_di t5 on t1.employee_id = t5.employee_id and t5.dt = '${today-8}'--跑0304周 
left join data_build.dwd_manager_tag_v1_di t6 on t1.employee_id = t6.employee_id and t6.dt = '${today-1}' 
left join data_build.ods_uploads_manager_tag_4 t7 on t1.employee_id= t7.employee_id and t7.dt = '${today-15}'--跑02226周 
left join data_shop.dm_shop_staff_protect_tag_v2 t8 on t1.employee_id=t8.staff_code  and t8.dt = '${today-1}'
left join jiameng_list t9 on t1.store_code = t9.store_code 
left join chedian_list t10 on t1.store_code = t10.store_code 
where t1.dt = '${today-8}'--跑0304周

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- 上周分化（0318周代码）
with jiameng_list as (
select distinct 
store_code
from data_build.pdw_bach_baseinfo_shop_shop
where dt = '${today-1}'
and self_take_type = '4' --加盟店
),
project_list as (
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
,chedian_list as (
select 
store_code
from (
select 
t2.flag_code 
,t2.project_name 
,t2.city_name 
,t2.store_code as store_code
,t2.store_name 
,create_time 
,flow_order_id 
,case when t1.cancel_state = 'suspend' then '解约中止'
when t1.cancel_state = 'doing' then '解约中'
when t1.cancel_state = 'done' then '解约完成'
end as cancel_state
,case when cancel_type = 1 then '先谈后撤' 
when cancel_type = 2 then '先撤后谈' 
when cancel_type = 3 then '谈判同时撤店'
when cancel_type = 0 then null
end as cancel_type
,cancel_method 
,rent_reduction_ratio 
,withdraw_shop_date 
,case when cancel_source = 1 then '甲方违约'
when cancel_source = 2 then '乙方违约'
when cancel_source = 3 then '到期不续'
when cancel_source = 4 then '法务评估无责解约'
when cancel_source = 99 then '其他'
when cancel_source = 0 then null
end as cancel_source
,other_cancel_source 
,case when revoke_reason = 1 then '门店降免租保留'
when revoke_reason = 2 then '门店策略保留'
when revoke_reason = 99 then '其他'
when revoke_reason = 0 then null
end as revoke_reason
,row_number()over(partition by flag_code order by create_time desc,update_time desc) as rn
from data_build.pdw_opc_flag_project_cancel_sign_view t1
left join project_list t2 on t1.project_id = t2.project_id 
where t1.dt >= 20230201
and t2.flag_code is not null
) t1
where t1.rn = 1
and cancel_state not in ('解约中止')
)

select distinct
t1.employee_id
,t1.name
,t1.store_code
,t1.code
,t1.class
,t2.hps_d_hr_status
,t3.protect_tag as protect_tag_new
,case when t4.staff_code is not null then 1 else 0 end as is_taihuan
,t8.protect_tag as `店员开工表现`
,t5.final_rank as `上周日维度标签`
,t5.total_score as `上周得分`
,t6.final_rank as `本周日维度标签`
,t6.total_score as `本周得分`
,t7.class as `上上周标签`
,t6.will_score as `本周意愿度`
,t6.performance_score as `本周个人能力`
,t6.store_score as `本周门店质量`
,t6.manage_score as `本周团队管理`
,t4.type as `汰换原因`
,t5.will_score as `上周意愿度`
,t5.performance_score as `上周个人能力`
,t5.store_score as `上周门店质量`
,t5.manage_score as `上周团队管理`
,case when t9.store_code is not null then 1
when t10.store_code is not null then 1
else 0 end as `是否撤店/加盟`
from data_build.ods_uploads_manager_tag_4 t1 
left join data_build.pdw_psprod_ps_blf_ehr_pers_vw_view t2 on t1.employee_id = if(length(t2.emplid)=6,concat('10',t2.emplid),t2.emplid) and t2.dt = '${today-1}' 
left join data_build.dwd_store_construction_manager_tag_weekly_di t3 on t1.employee_id= t3.employee_id and t3.dt = '${today-1}' 
left join data_shop.ods_uploads_eliminate_manager t4 on t1.employee_id = t4.staff_code 
left join data_build.dwd_manager_tag_v1_di t5 on t1.employee_id = t5.employee_id and t5.dt = '${today-8}'--跑0311周 
left join data_build.dwd_manager_tag_v1_di t6 on t1.employee_id = t6.employee_id and t6.dt = '${today-1}' 
left join data_build.ods_uploads_manager_tag_4 t7 on t1.employee_id= t7.employee_id and t7.dt = '${today-15}'--跑0304周 
left join data_shop.dm_shop_staff_protect_tag_v2 t8 on t1.employee_id=t8.staff_code  and t8.dt = '${today-1}'
left join jiameng_list t9 on t1.store_code = t9.store_code 
left join chedian_list t10 on t1.store_code = t10.store_code 
where t1.dt = '${today-8}'--跑0311周

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- 上周分化(1007周代码)
with jiameng_list as (
select distinct 
store_code
from data_build.pdw_bach_baseinfo_shop_shop
where dt = '${today-1}'
and self_take_type = '4' --加盟店
),
project_list as (
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
,chedian_list as (
select 

store_code

from (
select 
t2.flag_code 
,t2.project_name 
,t2.city_name 
,t2.store_code as store_code
,t2.store_name 
,create_time 
,flow_order_id 
,case when t1.cancel_state = 'suspend' then '解约中止'
when t1.cancel_state = 'doing' then '解约中'
when t1.cancel_state = 'done' then '解约完成'
end as cancel_state
,case when cancel_type = 1 then '先谈后撤' 
when cancel_type = 2 then '先撤后谈' 
when cancel_type = 3 then '谈判同时撤店'
when cancel_type = 0 then null
end as cancel_type
,cancel_method 
,rent_reduction_ratio 
,withdraw_shop_date 
,case when cancel_source = 1 then '甲方违约'
when cancel_source = 2 then '乙方违约'
when cancel_source = 3 then '到期不续'
when cancel_source = 4 then '法务评估无责解约'
when cancel_source = 99 then '其他'
when cancel_source = 0 then null
end as cancel_source
,other_cancel_source 
,case when revoke_reason = 1 then '门店降免租保留'
when revoke_reason = 2 then '门店策略保留'
when revoke_reason = 99 then '其他'
when revoke_reason = 0 then null
end as revoke_reason
,row_number()over(partition by flag_code order by create_time desc,update_time desc) as rn
from data_build.pdw_opc_flag_project_cancel_sign_view t1
left join project_list t2 on t1.project_id = t2.project_id 
where t1.dt >= 20230201
and t2.flag_code is not null
) t1
where t1.rn = 1
and cancel_state not in ('解约中止')
)

select distinct
t1.employee_id
,t1.name
,t1.store_code
,t1.code
,t1.class
,t2.hps_d_hr_status
,t3.protect_tag as protect_tag_new
,case when t4.staff_code is not null then 1 else 0 end as is_taihuan
,t8.protect_tag as `店员开工表现`
,t5.final_rank as `上周日维度标签`
,t5.total_score as `上周得分`
,t6.final_rank as `本周日维度标签`
,t6.total_score as `本周得分`
,t7.class as `上上周标签`
,t6.will_score as `本周意愿度`
,t6.performance_score as `本周个人能力`
,t6.store_score as `本周门店质量`
,t6.manage_score as `本周团队管理`
,t4.type as `汰换原因`
,t5.will_score as `上周意愿度`
,t5.performance_score as `上周个人能力`
,t5.store_score as `上周门店质量`
,t5.manage_score as `上周团队管理`
,case when t9.store_code is not null then 1
when t10.store_code is not null then 1
else 0 end as `是否撤店/加盟`
from data_build.ods_uploads_manager_tag_4 t1 
left join data_build.pdw_psprod_ps_blf_ehr_pers_vw_view t2 on t1.employee_id = if(length(t2.emplid)=6,concat('10',t2.emplid),t2.emplid) and t2.dt = '${today-1}' 
left join data_build.dwd_store_construction_manager_tag_weekly_di t3 on t1.employee_id= t3.employee_id and t3.dt = '${today-1}' 
left join data_shop.ods_uploads_eliminate_manager t4 on t1.employee_id = t4.staff_code 
left join data_build.dwd_manager_tag_v1_di t5 on t1.employee_id = t5.employee_id and t5.dt = '${today-15}' --取上上周 
left join data_build.dwd_manager_tag_v1_di t6 on t1.employee_id = t6.employee_id and t6.dt = '${today-1}' 
left join data_build.ods_uploads_manager_tag_4 t7 on t1.employee_id= t7.employee_id and t7.dt = '${today-21}' --取上上上周 
left join data_shop.dm_shop_staff_protect_tag_v2 t8 on t1.employee_id=t8.staff_code  and t8.dt = '${today-1}'
left join jiameng_list t9 on t1.store_code = t9.store_code 
left join chedian_list t10 on t1.store_code = t10.store_code 
where t1.dt = '${today-15}' --取上上周

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- 上周分化(1014周代码)
with jiameng_list as (
select distinct 
store_code
from data_build.pdw_bach_baseinfo_shop_shop
where dt = '${today-1}'
and self_take_type = '4' --加盟店
),
project_list as (
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
,chedian_list as (
select 

store_code

from (
select 
t2.flag_code 
,t2.project_name 
,t2.city_name 
,t2.store_code as store_code
,t2.store_name 
,create_time 
,flow_order_id 
,case when t1.cancel_state = 'suspend' then '解约中止'
when t1.cancel_state = 'doing' then '解约中'
when t1.cancel_state = 'done' then '解约完成'
end as cancel_state
,case when cancel_type = 1 then '先谈后撤' 
when cancel_type = 2 then '先撤后谈' 
when cancel_type = 3 then '谈判同时撤店'
when cancel_type = 0 then null
end as cancel_type
,cancel_method 
,rent_reduction_ratio 
,withdraw_shop_date 
,case when cancel_source = 1 then '甲方违约'
when cancel_source = 2 then '乙方违约'
when cancel_source = 3 then '到期不续'
when cancel_source = 4 then '法务评估无责解约'
when cancel_source = 99 then '其他'
when cancel_source = 0 then null
end as cancel_source
,other_cancel_source 
,case when revoke_reason = 1 then '门店降免租保留'
when revoke_reason = 2 then '门店策略保留'
when revoke_reason = 99 then '其他'
when revoke_reason = 0 then null
end as revoke_reason
,row_number()over(partition by flag_code order by create_time desc,update_time desc) as rn
from data_build.pdw_opc_flag_project_cancel_sign_view t1
left join project_list t2 on t1.project_id = t2.project_id 
where t1.dt >= 20230201
and t2.flag_code is not null
) t1
where t1.rn = 1
and cancel_state not in ('解约中止')
)

select distinct
t1.employee_id
,t1.name
,t1.store_code
,t1.code
,t1.class
,t2.hps_d_hr_status
,t3.protect_tag as protect_tag_new
,case when t4.staff_code is not null then 1 else 0 end as is_taihuan
,t8.protect_tag as `店员开工表现`
,t5.final_rank as `上周日维度标签`
,t5.total_score as `上周得分`
,t6.final_rank as `本周日维度标签`
,t6.total_score as `本周得分`
,t7.class as `上上周标签`
,t6.will_score as `本周意愿度`
,t6.performance_score as `本周个人能力`
,t6.store_score as `本周门店质量`
,t6.manage_score as `本周团队管理`
,t4.type as `汰换原因`
,t5.will_score as `上周意愿度`
,t5.performance_score as `上周个人能力`
,t5.store_score as `上周门店质量`
,t5.manage_score as `上周团队管理`
,case when t9.store_code is not null then 1
when t10.store_code is not null then 1
else 0 end as `是否撤店/加盟`
from data_build.ods_uploads_manager_tag_4 t1 
left join data_build.pdw_psprod_ps_blf_ehr_pers_vw_view t2 on t1.employee_id = if(length(t2.emplid)=6,concat('10',t2.emplid),t2.emplid) and t2.dt = '${today-1}' 
left join data_build.dwd_store_construction_manager_tag_weekly_di t3 on t1.employee_id= t3.employee_id and t3.dt = '${today-1}' 
left join data_shop.ods_uploads_eliminate_manager t4 on t1.employee_id = t4.staff_code 
left join data_build.dwd_manager_tag_v1_di t5 on t1.employee_id = t5.employee_id and t5.dt = '${today-8}' --取上周 
left join data_build.dwd_manager_tag_v1_di t6 on t1.employee_id = t6.employee_id and t6.dt = '${today-1}' 
left join data_build.ods_uploads_manager_tag_4 t7 on t1.employee_id= t7.employee_id and t7.dt = '${today-21}' --取上上上周 
left join data_shop.dm_shop_staff_protect_tag_v2 t8 on t1.employee_id=t8.staff_code  and t8.dt = '${today-1}'
left join jiameng_list t9 on t1.store_code = t9.store_code 
left join chedian_list t10 on t1.store_code = t10.store_code 
where t1.dt = '${today-8}' --取上周