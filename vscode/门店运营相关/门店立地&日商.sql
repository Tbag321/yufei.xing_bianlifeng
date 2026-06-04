select 
	t1.store_code
	,t1.location_type
	,t2.record_week
	,t2.val_day
	,t2.is_working_day
from data_build.dm_site_selection_project_feature_info_di t1
left join data_build.app_app_sale_by_category_workday_or_notworkday_v1_da t2 on t1.store_code = t2.store_code 
	and bool = '日商' 
	and record_week >= '2024-03-01'
	and t2.dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
where t1.dt = 20221114
and record_week in (date_sub(current_date, dayofweek(current_date) - 1),
date_sub(date_sub(current_date, dayofweek(current_date) - 1), 7),
date_sub(date_sub(current_date, dayofweek(current_date) - 1), 14),
date_sub(date_sub(current_date, dayofweek(current_date) - 1), 21))
and t1.store_code in ('100000569',
'100003620',
'100073001',
'100000282',
'100001570',
'100000085',
'100000287',
'100000561',
'123000109',
'100000226')