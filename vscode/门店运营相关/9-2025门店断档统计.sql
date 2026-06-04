with max_time as(
select
max(dt) as dt
,max(hr) as hr
from data_smartorder.dw_roster_roster_detail_info_ha
where dt = '${today}'
)

,cut_off_list as(
select
t.is_night
,t.work_date
,store_id
,store_city
,store_name
,sale_type
,case when class_id='-5' and class_atom_id = 296 then '测温班次' 
when class_id='-5' then '其他支援班次'
when class_id='0' then '运营班次'
else null end as class_type
,version_source
,concat_ws('-',cast(start_time as string),cast(end_time as string)) as start_end_time
,nobody_hours
,nobody_period_list
,modify_time
,backup_ids
,grab_ids
from data_smartorder.dw_roster_roster_detail_info_ha t
join max_time t1 on t.dt = t1.dt and t.hr = t1.hr
where t.work_date between '2025-01-20' and '2025-02-12'
and nobody_hours between '4' and '15'
and case when class_id='-5' and class_atom_id = 296 then '测温班次' 
when class_id='-5' then '其他支援班次'
when class_id='0' then '运营班次'
else null end not in ('其他支援班次')
and class_id not in ('-6')
and concat(sale_type,reason_type) not in ('全天不营业')
and version_source not in ('emergency_closure','planned_closure') --紧急闭店,计划性闭店
and store_type = '0'
)

select
work_date
,is_night
,count(distinct store_id) as store_num
from cut_off_list
group by
work_date
,is_night





    select 
*
    from
        data_shop.pdw_opc_shop_attendance_report_work_shift_view
    where dt = '${today-1}'
    and store_code = '123000032'
    and work_shift_date = '2025-02-07'