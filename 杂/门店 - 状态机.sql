with sign_project as
(

	select 
	t1.flag_code
	,t1.project_id
	,t1.project_name
	,t1.city_name
	,t1.store_code
	,t1.store_name
	,t1.project_status_updated_time --as `签约`
	,t1.business_type
	,t1.is_delete
	,t2.cancel_sign_state
	,case when t2.cancel_sign_state <>'900' and t2.is_store_closed <> '800' and t2.is_delete = '0' then 1
		else 0 end is_keep_project

	from app_store_construction_project_pipeline_indicators_ha_v1 t1
	left join dim_store_construction_project_info t2 on t1.flag_code = t2.flag_code and t2.dt = '20220929'
	where t1.project_status_group = '状态' --'状态'/'阶段'/'阶段-状态'
	and substring_index(t1.project_status_name,' ',1) = '10' --已签约归档
	--and t1.project_status_updated_time > '1990-01-01 00:00:00.0'
	--and t1.business_type = '便利店'
	and t1.dt = '20220929' and t1.hr = '21'

),

open_project_info as
(
	select
	t.*
	from
	(
		select
		*
		,row_number() over(partition by flag_number order by store_id desc) r_n
		from dwa_store_construction_project_signed_opening_schedure
		where dt = '20220929'
	) t
	where t.r_n = 1
),

internal_closure_pipeline as --子嘉维护
(
	select
	flag_code
	,tag
	,additional_info
	,'1' is_delete
	from ods_uploads_internal_closure_pipeline

),

internal_closure_history as --qc维护，线下表
(
	select
	flag_code
	,tag
	,additional_info
	from ods_uploads_internal_closure_history

),

contract_status_info as --合同状态
(
	select
	t.*
	from
	(
	select
	    t.contract_id
	    ,t.flag_code
	    ,t.project_id
	    ,t.shop_code
	    ,case when get_json_object(t.content,'$.audit.mainStatus.name') = 'Start' and get_json_object(t.content,'$.audit.developAuditStatus.name') = 'Start'
	            and get_json_object(t.content,'$.audit.developAcceptedCount') = 0 and (get_json_object(t.content,'$.main.projectCancelState.code') <> 'cancelDone' or get_json_object(t.content,'$.main.projectCancelState.code') is null)
	            and (get_json_object(t.content,'$.main.pauseStatus.name') <> 'Pause' or get_json_object(t.content,'$.main.pauseStatus.name') is null) then '已创建'
	         when get_json_object(t.content,'$.audit.mainStatus.name') = 'Start' and (get_json_object(t.content,'$.audit.developAuditStatus.name') <> 'Start' or get_json_object(t.content,'$.audit.developAuditStatus.name') is null)
	            and (get_json_object(t.content,'$.audit.financialAuditStatus.name') <> 'Start' or get_json_object(t.content,'$.audit.financialAuditStatus.name') is null)
	            and (get_json_object(t.content,'$.main.projectCancelState.code') <> 'cancelDone' or get_json_object(t.content,'$.main.projectCancelState.code') is null)
	            and (get_json_object(t.content,'$.main.pauseStatus.name') <> 'Pause' or get_json_object(t.content,'$.main.pauseStatus.name') is null) then '未生效'
	         when get_json_object(t.content,'$.audit.mainStatus.name') = 'Finished' and get_json_object(t.content,'$.audit.developAcceptedCount') > 0  and get_json_object(t.content,'$.audit.financialAcceptedCount') > 0
	            and (get_json_object(t.content,'$.main.projectCancelState.code') <> 'cancelDone' or get_json_object(t.content,'$.main.projectCancelState.code') is null)
	            and (get_json_object(t.content,'$.main.pauseStatus.name') <> 'Pause' or get_json_object(t.content,'$.main.pauseStatus.name') is null) then '已生效'
	         when (get_json_object(t.content,'$.main.projectCancelState.code') <> 'cancelDone' or get_json_object(t.content,'$.main.projectCancelState.code') is null)
	            and get_json_object(t.content,'$.main.pauseStatus.name') = 'Pause' then '已暂停'
	         when get_json_object(t.content,'$.main.projectCancelState.code') = 'cancelDone' then '已解约'
	         else null end as contract_status
	    ,row_number() over(partition by t.flag_code order by t.update_time desc) r_n
	from        
	    (
	        select
	        contract_id
	        ,content
	        ,create_time
	        ,update_time
	    	,get_json_object(content,'$.main.flagCode') as flag_code
	    	,get_json_object(content,'$.main.projectId') as project_id
	    	,get_json_object(content,'$.main.shopCode') as shop_code
	        ,row_number() over(partition by contract_id order by main_version desc) as r_n
	        from data_build.dm_copy_pdw_opc_flag_contract_snapshot_view
	        where dt='20220929'
	    ) t
	    where t.r_n = 1
	) t
	where t.r_n = 1

),

contract_cancel_status as --用印归档状态
(
	select
	a.project_id
	,a.contract_kind
	,a.file_status
	,a.seal_use_date
	,a.file_date
	from
	(
		select
		project_id
		,case 
		    when contract_kind = 'propertyAgreement' then '物业协议'
		    when contract_kind = 'brokerageAgreement' then '居间协议'
		    when contract_kind = 'supplementaryAgreement' then '补充协议'
		    when contract_kind = 'electricityIncreaseAgreement' then '电量增容协议'
		    when contract_kind = 'cancelAgree' then '解约协议'
		    when contract_kind = 'tras' then '转让协议'
		    when contract_kind = 'separateContract' then '分租合同'
		    when contract_kind = 'freerent' then '减免租补充协议'
		    else contract_kind end as contract_kind
		-- ,apply_source as `申请来源`
		-- ,case 
		--         when stamp_type = '1' then '我方'
		--         when stamp_type = '2' then '对方'
		--         else stamp_type
		--     end as `盖章类型`
		-- ,seal_kind_name as `用印类型`
		,seal_use_date
		,file_date
		-- ,party_first_sign_date as `甲方签约日期`
		-- ,party_secord_sign_date as `我方签约日期`
		,contract_file_code-- as `合同归档编号`
		-- ,contract_file_name as `合同名称`
		,case
		        when status = '100' then '待开发处理'
		        when status = '110' then '待开发处理'
		        when status = '130' then '待开发处理'
		        when status = '300' then '待法务用印组处理'
		        when status = '400' then '待法务用印组处理'
		        when status = '500' then '待法务归档组处理'
		        when status = '540' then '待法务归档组处理'
		        when status = '600' then '用印归档已完成'
		        when status = '700' then '待开发确认用印'
		        when status = '800' then '待开发确认归档资料'
		        when status = '900' then '用印归档已终止'
		        else status end as file_status
		-- ,status_show as `展示状态`
		,row_number() over(partition by project_id order by contract_file_code desc) r_n
		from pdw_opc_flag_seal_apply_info t2
		where dt='20220929'
		and contract_kind = 'cancelAgree'
		and status = '600'
	) a
	where a.r_n = 1

),

store_status_bach_info as --店务清单
(
	/*营业时间测算时会选取【门店状态】为启用、【营业状态】为营业、待营业、暂停营业门店。
	待营业在本次测算周期的门店会正常测算，暂停营业最终营业时间为全天不营业。*/
	select 
	 store_code
	 ,store_name
	 ,store_city
	 ,to_date(original_openning_date) open_date
	 ,store_status
	from dw_ordering_store_tag_location_ranking_info_v1_view t
	where dt= date_format(date_sub(current_date,1),'yyyyMMdd')
	and store_status <> '3' -- 营业状态非停业（营业状态值：营业、待营业、暂停营业、停业）
	and store_cvs_status = '1' -- 门店状态为启用（门店状态值：启用、停用）
	and store_type = '0' -- 门店
	-- and to_date(original_openning_date) <= 测算周期

),

sleeping_store_info as --休眠门店
(
	select
	t.*
	,case when sleeping_start_time > current_date() then 0
		when sleeping_finish_time > current_date() or sleeping_finish_time is null or sleeping_finish_time = '' then 1
		else 0 end is_sleeping
	from
	(
	select
	order_id
	,version
	,create_time
	,update_time
	,l1_category_id
	,l1_category_name
	,l2_category_id
	,l2_category_name
	,start_time
	,end_time
	,notice
	,status
	,get_json_object(hivemall.json_split(extension)[0],'$.value') sleeping_start_time
	,get_json_object(hivemall.json_split(extension)[1],'$.value') sleeping_finish_time
	,get_json_object(x1.store_values,'$.key') store_code
	,row_number() over(partition by get_json_object(x1.store_values,'$.key') order by create_time desc) r_n
	from data_smartorder.dm_ordering_information_system_order_detail
	lateral view explode(hivemall.json_split(selection_p_o_list)) x as selection_p_o
	lateral view outer explode(hivemall.json_split(get_json_object(x.selection_p_o,'$.values'))) x1 as store_values
	where dt = '20220929'
	and l2_category_name in ('冬眠门店') --'紧急闭店'
	and get_json_object(x.selection_p_o,'$.name') = 'shop'
	) t
	where t.r_n = 1

)

--------------------
select
a.flag_code
,a.project_name
,a.city_name
,a.store_code
,a.store_name
,a.business_type
,a.is_delete
,a.is_keep_project
,b.address
,b.used_area
,b.inspector_name
,b.inspector_id
,b.manage_name
,b.developer_name
,b.project_engineer_name
,b.equip_engineer_name
--,to_date(b.sign_date) sign_date --签约日期
,to_date(a.project_status_updated_time) project_status_updated_time
,case when b.sign_status = '已开业' then '4已开业'
when b.sign_status = '待开业' then '3交店未开业'
when b.sign_status = '已完工' then '2完工未交店'
when b.sign_status = '施工中' then '1收房未完工'
when b.sign_status = '待开工' then '1收房未完工'
else '0未收房' end as project_progress_eng
,nvl(b.sign_status,'待收房') sign_status
,to_date(b.rent_start_date) rent_start_date
,b.rent_type_peroid --起租阶段
,b.rent_free_date --免租日期
--收房
,to_date(b.room_expect_time) room_expect_time
,to_date(b.room_real_time) room_real_time
--进场
,to_date(b.enter_expect_time) enter_expect_time
,to_date(b.enter_real_time) enter_real_time
--进场协调会
,to_date(b.coordinate_enter_expect_time) coordinate_enter_expect_time
,to_date(b.coordinate_enter_real_time) coordinate_enter_real_time
--交底
,to_date(b.decorated_expect_time) decorated_expect_time
,to_date(b.decorated_real_time) decorated_real_time
--完工
,to_date(b.finiah_expect_time) finiah_expect_time
,to_date(b.finiah_real_time) finiah_real_time
--保洁
,to_date(b.clean_expect_time) clean_expect_time
,to_date(b.clean_real_time) clean_real_time
--交店
,to_date(b.submit_expect_time) submit_expect_time
,to_date(b.submit_real_time) submit_real_time
--开业
,to_date(b.open_expect_date) open_expect_date
,to_date(b.open_final_date) open_final_date
,to_date(b.open_real_date) open_real_date
,to_date(date_format(b.open_real_date , 'yyyy-MM-01')) open_real_month
,to_date(date_format(b.open_expect_date , 'yyyy-MM-01')) open_expect_month
--状态标签
,c.tag
,c.additional_info
,d.contract_status
,e.file_status
,f.store_status
,g.is_sleeping
,if(b.open_real_date >= date_format(date_add(current_date(),-1),'yyyy-MM-01') and b.open_real_date <= current_date() ,1,0) current_month_open
,if(b.open_real_date >= date_format(add_months(date_add(current_date(),-1),-1),'yyyy-MM-01') and b.open_real_date < date_format(date_add(current_date(),-1),'yyyy-MM-01') ,1,0) last_month_open
,if(b.open_real_date >= date_format(add_months(date_add(current_date(),-1),-2),'yyyy-MM-01') and b.open_real_date < date_format(add_months(date_add(current_date(),-1),-1),'yyyy-MM-01') ,1,0) last_two_month_open
,if(b.open_real_date >= date_format(add_months(date_add(current_date(),-1),-3),'yyyy-MM-01') and b.open_real_date < date_format(add_months(date_add(current_date(),-1),-2),'yyyy-MM-01') ,1,0) last_three_month_open
,if(b.open_expect_date >= current_date() and b.open_expect_date < date_format(add_months(date_add(current_date(),-1),1),'yyyy-MM-01'),1,0) current_month_expect_open
,if(b.open_expect_date >= date_format(add_months(date_add(current_date(),-1),1),'yyyy-MM-01') and b.open_expect_date < date_format(add_months(date_add(current_date(),-1),2),'yyyy-MM-01'),1,0) next_month_expect_open
,if(b.open_expect_date >= date_format(add_months(date_add(current_date(),-1),2),'yyyy-MM-01') and b.open_expect_date < date_format(add_months(date_add(current_date(),-1),3),'yyyy-MM-01'),1,0) next_two_month_expect_open
,if(b.open_expect_date >= date_format(add_months(date_add(current_date(),-1),3),'yyyy-MM-01') and b.open_expect_date < date_format(add_months(date_add(current_date(),-1),4),'yyyy-MM-01'),1,0) next_three_month_expect_open
----------------------
,case when c.is_delete = 1 and a.business_type = '便利店' then '3BLF内部已决策要解约门店'
	when h.additional_info is not null then h.additional_info
	when a.business_type <> '便利店' then '5非便利店'
	when b.sign_status <> '已开业' or b.sign_status is null then '2正常保留-未开业门店'
	when f.store_status is not null then '1正常保留-已开业门店'
	when a.is_delete = 0 and (d.contract_status not in ('已解约') or d.contract_status is null) and e.file_status is null and b.sign_status in ('已开业') then '1正常保留-已开业门店'
	else null end store_status_BLF
,a.cancel_sign_state
from sign_project a
left join open_project_info b on a.flag_code = b.flag_number
left join internal_closure_pipeline c on a.flag_code = c.flag_code
left join contract_status_info d on a.flag_code = d.flag_code
left join contract_cancel_status e on a.project_id = e.project_id
left join store_status_bach_info f on a.store_code = f.store_code
left join sleeping_store_info g on a.store_code = g.store_code
left join internal_closure_history h on a.flag_code = h.flag_code