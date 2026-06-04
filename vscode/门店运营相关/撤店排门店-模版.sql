
-- 人--这是第一段代码
select 
    emplid
    ,t1.name
    ,t1.hps_sys_name
    ,t1.hps_dept_code_lv5
    ,t1.hps_d_jobcode
    ,coalesce(t2.chuqin_label,t2.geiban_label) as label
from 
    data_shop.pdw_psprod_ps_blf_ehr_pers_vw_view t1 
left join 
    data_build.dwd_store_construction_roster_staff_supply_v1_di t2 on lpad(t1.emplid,8,'10') = t2.employee_id
    and t2.dt = '${today-1}'
where 
    t1.dt = '${today-1}'
    and t1.hps_d_hr_status in ('在职')
    and t1.hps_dept_descr_lv1 in ('运营管理部A','运营管理部B')
    and t1.hps_d_jobcode in ( '门店伙伴', '店员', '社会PT', '学生PT','店经理','店副经理') --加盟店的时候，这里的岗位不限制，店长店副也都统计进去
    and t1.hps_dept_code_lv5 in ('123000013')--后面就换这个门店



-- 白斑匹配·--这是第2段代码
with store_distance as (
 select

     t1.a_store_code as from_store_code
     ,t1.a_store_name as from_store_name
     ,t1.a_store_city as from_store_city 
     ,t1.b_store_code as to_store_code
     ,t1.b_store_name as to_store_name
     ,t1.b_store_city as to_store_city 
     ,t1.distince as distance 
     ,t3.hc_new as to_store_hc
     ,t3.gap_new as to_store_gap_all
     ,t3.gap_day as to_store_gap_day
     ,t3.gap_night as to_store_gap_night
     ,t4.gap_new as from_store_gap_all
     ,row_number()over(partition by t1.a_store_code order by t1.distince asc) as rn

 from 
    data_smartorder.dm_order_external_same_city_store_riding_distance_type_zero_do_business_union_all t1
 --left join data_build.dwd_store_construction_store_groups_recruit_gap t2 on t2.store_code = t1.a_store_code and t2.dt ='${today-1}'
 left join 
    data_build.dwd_store_construction_store_groups_recruit_gap t3 on t3.store_code = t1.b_store_code and t3.dt = '${today-1}'
left join 
    data_build.dwd_store_construction_store_groups_recruit_gap t4 on t4.store_code = t1.a_store_code and t4.dt = '${today-1}'
 
 where
    t1.dt = '${today-1}'
    and t3.store_code is not null
    and t1.a_store_city = t1.b_store_city 
    and (t3.gap_day >=2 or (t3.gap_short_day=0 and t3.gap_day =1))
    and t3.gap_day >=1
    and t1.distince>1
    and t1.a_store_code in ('123000013')--后面就换这个门店
)


select 
a.* 
from store_distance a 
where a.rn <= 4



-- 夜班匹配--这是第3段代码

with store_distance as (
 select
     t1.a_store_code as from_store_code
     ,t1.a_store_name as from_store_name
     ,t1.a_store_city as from_store_city 
     ,t1.b_store_code as to_store_code
     ,t1.b_store_name as to_store_name
     ,t1.b_store_city as to_store_city 
     ,t1.distince as distance 
     ,t3.hc_new as to_store_hc
     ,t3.gap_new as to_store_gap_all
     ,t3.gap_day as to_store_gap_day
     ,t3.gap_night as to_store_gap_night
     ,t4.gap_new as from_store_gap_all
    ,row_number()over(partition by t1.a_store_code order by t1.distince asc) as rn

 from
    data_smartorder.dm_order_external_same_city_store_riding_distance_type_zero_do_business_union_all t1
 --left join data_build.dwd_store_construction_store_groups_recruit_gap t2 on t2.store_code = t1.a_store_code and t2.dt ='${today-1}'
 left join
    data_build.dwd_store_construction_store_groups_recruit_gap t3 on t3.store_code = t1.b_store_code and t3.dt = '${today-1}'
left join 
    data_build.dwd_store_construction_store_groups_recruit_gap t4 on t4.store_code = t1.a_store_code and t4.dt = '${today-1}'
 
 where 
    t1.dt = '${today-1}'
    and t3.store_code is not null
and t1.a_store_city = t1.b_store_city 
and (t3.gap_night >=2 or (t3.gap_short_night=0 and t3.gap_night =1))
and t3.gap_night >=1
and t1.distince>1
and t1.a_store_code in ('123000013')--后面就换这个门店


)


select 
a.* 
from store_distance a 
where a.rn <= 4

========================================================================================================================================

--给门店找人
--给歌华找人(是找夜班代码，而且不是加盟店)

WITH store_info AS (
 SELECT
 DISTINCT t1.store_code,
 t1.store_name,
 (CASE WHEN t1.fte_night - 1 >= t1.hc_night THEN t1.fte_night - t1.hc_night ELSE NULL END) AS extra_supply_night
 FROM
 data_build.dwd_store_construction_store_groups_recruit_gap t1
 WHERE
 t1.dt = '${today-1}'
),

staff_info AS (
 SELECT
 t1.staff_code,
 t1.staff_name,
 t1.protect_tag_detail,
 t1.protect_tag,
 t2.store_code,
 t2.store_name,
 COALESCE(t3.chuqin_label, t3.geiban_label) AS label,
 SUM(t4.attendance_work_hours) AS t90_work_hours,
 t5.hps_d_jobcode AS position,
 t5.hps_sys_name,
 t5.hps_hire_dt
 FROM
 data_shop.dm_shop_staff_protect_tag_v2 t1
 INNER JOIN store_info t2 ON t1.store_code = t2.store_code
 INNER JOIN data_build.dwd_store_construction_roster_staff_supply_v1_di t3 ON t1.staff_code = t3.employee_id
 AND t3.dt = '${today-1}'
 INNER JOIN data_shop.pdw_opc_shop_attendance_report_work_shift_view t4 ON t1.staff_code = lpad(t4.employee_no, 8, '10')
 AND t4.work_shift_type IN (1, 9, 12)
 AND date_format(t4.work_shift_date, 'yyyyMMdd') >= '${today-90}'
 AND t4.dt = '${today-1}'
 INNER JOIN data_shop.pdw_psprod_ps_blf_ehr_pers_vw_view t5 ON t1.staff_code = lpad(t5.emplid, 8, '10')
 AND t5.dt = '${today-1}'
 WHERE
 t1.dt = '${today-1}'
 AND t2.extra_supply_night IS NOT NULL
 AND t5.hps_d_jobcode IN ('门店伙伴', '店员', '社会PT')
 and COALESCE(t3.chuqin_label, t3.geiban_label) in ('长夜型员工','全天型员工')
 GROUP BY
 t1.staff_code, t1.staff_name, t1.protect_tag_detail, t1.protect_tag, t2.store_code, t2.store_name, COALESCE(t3.chuqin_label, t3.geiban_label), t5.hps_d_jobcode,t5.hps_sys_name,t5.hps_hire_dt
),

prep_info AS (
 SELECT *,
 ROW_NUMBER() OVER (PARTITION BY store_code ORDER BY t90_work_hours ASC) AS rn
 FROM
 staff_info
),


distance as (

 select

 t1.a_store_code as from_store_code
 ,t1.a_store_name as from_store_name
 ,t1.a_store_city as from_store_city 
 ,t1.b_store_code as to_store_code
 ,t1.b_store_name as to_store_name
 ,t1.b_store_city as to_store_city 
 ,t1.distince as distance 
 ,row_number()over(partition by t1.a_store_code order by t1.distince asc) as rn

 from 
 data_build.dm_order_external_same_city_store_riding_distance_type_zero_do_business_union_all_view t1
 --left join data_build.dwd_store_construction_store_groups_recruit_gap t2 on t2.store_code = t1.a_store_code and t2.dt ='${today-1}'

 where
 t1.dt = '${today-1}'
 and t1.a_store_city = t1.b_store_city 
 and t1.a_store_code = '100000668'



)

select
 t1.staff_code
 ,t1.staff_name
 ,t1.hps_sys_name
 ,t1.store_code
 ,t1.store_name
 ,t1.position
 ,t1.label
 ,t2.extra_supply_night
 ,t1.protect_tag_detail
 ,t1.t90_work_hours
 ,t1.hps_hire_dt
 ,t3.distance

from prep_info t1
JOIN store_info t2 ON t1.store_code = t2.store_code
left join distance t3 on t1.store_code = t3.to_store_code
WHERE
 t1.rn <= t2.extra_supply_night
 and t3.distance < 10000


==============================================================================================================================================================
--把门店富裕人力外派
--歌华夜班
--缺夜班的门店
WITH store_info AS (
 SELECT
 DISTINCT t1.store_code,
 t1.store_name
 FROM
 data_build.dwd_store_construction_store_groups_recruit_gap t1
 WHERE
 t1.dt = '20240924' --先用24号的dt，赶上下周国庆假期，gap表25号以后用了下周的排班，暂时不准，在修
 and gap_night > 0 --缺夜班
)

select
t1.store_code --缺夜班的门店
,t1.store_name
,t2.b_store_code --夜班冗余的门店
,t2.distince --距离(单位米)
from store_info t1
left join data_smartorder.dm_order_external_same_city_store_riding_distance_type_zero_do_business_union_all t2 on t1.store_code = t2.a_store_code and t2.dt = '${today-1}'
where t2.b_store_code = '100078005' --歌华大厦店