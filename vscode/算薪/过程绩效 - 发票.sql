with rent_main as
(
	 select
		 t1.order_id
		 ,get_json_object(t1.data,'$.flagCode') as flag_code
		 ,get_json_object(t1.data,'$.projectId') as project_id
		 ,get_json_object(t1.data,'$.projectName') as project_name
	 from data_build.pdw_order_store_209_order_detail t1
	 where t1.dt = '${today-1}'
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
 	where t1.dt = '${today-1}'
	--and order_id = '2090023639131180'
	and t1.section = 'contract-cost'
),


rent_payment as ( --支付计划
	select
		 t1.order_id
		 ,get_json_object(x1.rent_payment_list,'$.fee.amount') as rent_plan_to_pay
		 ,get_json_object(x1.rent_payment_list,'$.actualFee.amount') as rent_actual_pay
		 ,get_json_object(x1.rent_payment_list,'$.paymentDate') as rent_pay_date
		 ,get_json_object(x1.rent_payment_list,'$.startDate') as rent_start_date
		 ,get_json_object(x1.rent_payment_list,'$.endDate') as rent_end_date
		 ,get_json_object(x1.rent_payment_list,'$.payStatus.name') as rent_pay_status
	from data_build.pdw_order_store_209_order_detail t1
 	lateral view outer explode(hivemall.json_split(get_json_object(t1.data,'$.rentInfo.rentDetailList'))) x1 as rent_payment_list
	where t1.dt = '${today-1}'
 	and t1.section = 'contract-payment'

)


select
		t1.flag_code
		,t1.project_id
		,t1.project_name
		,t1.city_name
		,t1.store_code
		,t1.store_name
		,t1.store_status_blf
		,t2.id                              as store_id
		,t3.upload_user_id --项目当前归属人
		,t6.rent_start_date
		,t6.rent_end_date
		,t6.rent_pay_status
		,t6.rent_pay_date
from dwd_store_construction_project_status_v2_di t1
left join pdw_opc_engineering_engineering_store t2 on t1.flag_code = t2.flag_number and t2.dt >= date_format(date_sub(current_date(),1),'yyyyMMdd')
left join dwd_store_construction_project_upload_info_v1 t3 on t1.flag_code = t3.flag_code and t3.dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
left join rent_main t4 on t1.flag_code = t4.flag_code
left join rent_payment t6 on t4.order_id = t6.order_id and to_date(t6.rent_pay_date) between '2024-06-25' and '2024-07-25' --每次绩效结算时更新
where t1.dt >= date_format(date_sub(current_date(),2),'yyyyMMdd')
and t1.store_status_blf not in ('4实际未签约的生效门店','5非便利店') 