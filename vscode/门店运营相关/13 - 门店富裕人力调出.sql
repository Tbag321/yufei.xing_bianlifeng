

-- 调出富裕人力到附近门店

-- STEP 1 查询有富裕人力的门店与里面富裕的新人 --[[COMMENT]]后面代码需要加上不是架构负责人

WITH store_info AS (
    SELECT
        DISTINCT t1.store_code,
        (CASE WHEN t1.fte_day - 1 >= t1.hc_day THEN t1.fte_day - t1.hc_day ELSE NULL END) AS extra_supply_day
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
        COALESCE(t3.geiban_label,t3.chuqin_label) AS label,
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
        AND t2.extra_supply_day IS NOT NULL
        AND T1.PROTECT_TAG = '待观察' --根据情况考虑是否删除
        AND t5.hps_d_jobcode IN ('门店伙伴', '店员', '社会PT')
        and substr(COALESCE(t3.geiban_label,t3.chuqin_label),2,1) = '白'
    GROUP BY
        t1.staff_code, t1.staff_name, t1.protect_tag_detail, t1.protect_tag, t2.store_code, COALESCE(t3.geiban_label,t3.chuqin_label), t5.hps_d_jobcode,t5.hps_sys_name,t5.hps_hire_dt
),

prep_info AS (
    SELECT *,
        ROW_NUMBER() OVER (PARTITION BY store_code ORDER BY t90_work_hours ASC) AS rn
    FROM
        staff_info
)

select
	t1.staff_code
	,t1.staff_name
	,t1.hps_sys_name
	,t1.store_code
	,t1.position
	,t1.label
	,t2.extra_supply_day
	,t1.protect_tag_detail
	,t1.t90_work_hours
	,t1.hps_hire_dt

from prep_info t1
JOIN store_info t2 ON t1.store_code = t2.store_code
WHERE
    t1.rn <= t2.extra_supply_day;




--STEP 2 调去附近有白班缺口门店

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
    data_gis_h3.mid_order_external_same_city_store_riding_distance_type_zero_do_business_union_all_view t1
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
    and t1.distince <= 10000
    and t1.a_store_code in ('100000591'
)--用step1门店复制到这里
)


select 
a.* 
from store_distance a 
where a.rn <= 5




--STEP 3 找到冗余的夜班人员

WITH store_info AS (
    SELECT
        DISTINCT t1.store_code,
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
        COALESCE(t3.geiban_label,t3.chuqin_label) AS label,
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
        AND T1.PROTECT_TAG = '待观察' --根据情况考虑是否删除
        AND t5.hps_d_jobcode IN ('门店伙伴', '店员', '社会PT')
        and substr(COALESCE(t3.geiban_label,t3.chuqin_label),2,1) = '夜'
    GROUP BY
        t1.staff_code, t1.staff_name, t1.protect_tag_detail, t1.protect_tag, t2.store_code, COALESCE(t3.geiban_label,t3.chuqin_label), t5.hps_d_jobcode,t5.hps_sys_name,t5.hps_hire_dt
),

prep_info AS (
    SELECT *,
        ROW_NUMBER() OVER (PARTITION BY store_code ORDER BY t90_work_hours ASC) AS rn
    FROM
        staff_info
)

select
    t1.staff_code
    ,t1.staff_name
    ,t1.hps_sys_name
    ,t1.store_code
    ,t1.position
    ,t1.label
    ,t2.extra_supply_night
    ,t1.protect_tag_detail
    ,t1.t90_work_hours
    ,t1.hps_hire_dt

from prep_info t1
JOIN store_info t2 ON t1.store_code = t2.store_code
WHERE
    t1.rn <= t2.extra_supply_night;






--STEP 4 调去附近有夜班缺口门店


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
    data_gis_h3.mid_order_external_same_city_store_riding_distance_type_zero_do_business_union_all_view t1
 --left join data_build.dwd_store_construction_store_groups_recruit_gap t2 on t2.store_code = t1.a_store_code and t2.dt ='${today-1}'
 left join 
    data_build.dwd_store_construction_store_groups_recruit_gap t3 on t3.store_code = t1.b_store_code and t3.dt = '${today-1}'
left join 
    data_build.dwd_store_construction_store_groups_recruit_gap t4 on t4.store_code = t1.a_store_code and t4.dt = '${today-1}'
 
 where
    t1.dt = '${today-1}'
    and t3.store_code is not null
    and t1.a_store_city = t1.b_store_city 
    and t3.gap_night >=1
    and (t3.hc_new-t3.fte_new)>=1
    and t1.distince>1
    and t1.distince <= 15000
    and t1.a_store_code in ('100001532')--用step3门店复制到这里
)


select 
a.* 
from store_distance a 
where a.rn <= 5



--STEP 5 找到冗余的全天班人员

WITH store_info AS (
    SELECT
        DISTINCT t1.store_code,
        (CASE WHEN fte_day + fte_night - 1 >= hc_day + hc_night then fte_day + fte_night - hc_day - hc_night ELSE NULL END) AS extra_supply
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
        COALESCE(t3.geiban_label,t3.chuqin_label) AS label,
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
        AND t2.extra_supply IS NOT NULL
        AND T1.PROTECT_TAG = '待观察' --根据情况考虑是否删除
        AND t5.hps_d_jobcode IN ('门店伙伴', '店员', '社会PT')
        and substr(COALESCE(t3.geiban_label,t3.chuqin_label),1,2) = '全天'
    GROUP BY
        t1.staff_code, t1.staff_name, t1.protect_tag_detail, t1.protect_tag, t2.store_code, COALESCE(t3.geiban_label,t3.chuqin_label), t5.hps_d_jobcode,t5.hps_sys_name,t5.hps_hire_dt
),

prep_info AS (
    SELECT *,
        ROW_NUMBER() OVER (PARTITION BY store_code ORDER BY t90_work_hours ASC) AS rn
    FROM
        staff_info
)

select
    t1.staff_code
    ,t1.staff_name
    ,t1.hps_sys_name
    ,t1.store_code
    ,t1.position
    ,t1.label
    ,t2.extra_supply
    ,t1.protect_tag_detail
    ,t1.t90_work_hours
    ,t1.hps_hire_dt

from prep_info t1
JOIN store_info t2 ON t1.store_code = t2.store_code
WHERE
    t1.rn <= t2.extra_supply;


--STEP 6 调去附近有全天班缺口门店


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
    data_gis_h3.mid_order_external_same_city_store_riding_distance_type_zero_do_business_union_all_view t1
 --left join data_build.dwd_store_construction_store_groups_recruit_gap t2 on t2.store_code = t1.a_store_code and t2.dt ='${today-1}'
 left join 
    data_build.dwd_store_construction_store_groups_recruit_gap t3 on t3.store_code = t1.b_store_code and t3.dt = '${today-1}'
left join 
    data_build.dwd_store_construction_store_groups_recruit_gap t4 on t4.store_code = t1.a_store_code and t4.dt = '${today-1}'
 
 where
    t1.dt = '${today-1}'
    and t3.store_code is not null
    and t1.a_store_city = t1.b_store_city 
    and t3.gap_new > 0
    and t1.distince>1
    and t1.distince <= 15000
    and t1.a_store_code in ('100000009')--用step5门店复制到这里
)


select 
a.* 
from store_distance a 
where a.rn <= 5








--判断是否能调去某一个门店

with store_distance as (
 select
     t1.a_store_code as from_store_code
     ,t1.a_store_name as from_store_name
     ,t1.a_store_city as from_store_city 
     ,t1.b_store_code as to_store_code
     ,t1.b_store_name as to_store_name
     ,t1.b_store_city as to_store_city 
     ,t1.distince as distance 
 
 from
    data_gis_h3.mid_order_external_same_city_store_riding_distance_type_zero_do_business_union_all_view t1


 where 
    t1.dt = '${today-1}'
and t1.a_store_city = t1.b_store_city 
and t1.distince>1
and t1.a_store_code in ('100078005')--用step1门店复制到这里








--新进门店员工顶替预拉黑员工
with waitlist_detail as(
select 
employee_no 
,row_number()over(partition by employee_no order by update_time desc) as rn
from data_build.dwd_pdw_idss_ipes_admin_employee_blacklist_waitlist_view 
where dt = '${today-1}' 
and valid = 1
),

waitlist_raw as(
select
t1.employee_no
,t2.name
,t2.hps_dept_code_lv5
,t2.hps_dept_descr_lv5
from waitlist_detail t1
left join data_build.pdw_psprod_ps_blf_ehr_pers_vw_view t2 on t1.employee_no = t2.emplid and t2.dt = '${today-1}'
where t1.rn = 1
),

new_entry_staff as(
select
t1.*
--,t2.*
,case when t2.emplid is null then '新增' else null end as type
from data_build.pdw_psprod_ps_blf_ehr_pers_vw_view t1
left join data_build.pdw_psprod_ps_blf_ehr_pers_vw_view t2 on t2.dt = '${today-2}' and t1.hps_dept_code_lv5 = t2.hps_dept_code_lv5 and t1.emplid = t2.emplid and t2.hps_d_hr_status = '在职'
where t1.dt = '${today-1}'
and t1.hps_d_hr_status = '在职'
)

select
t1.emplid
,t1.name
,t1.hps_dept_code_lv5
,t1.hps_dept_descr_lv5
,t2.employee_no
,t2.name
from new_entry_staff t1
join waitlist_raw t2 on t1.hps_dept_code_lv5 = t2.hps_dept_code_lv5
where t1.type = '新增'


SELECT
dt
,store_code
,store_name
,hc_day
,fte_day
,gap_day_withoutlow
,hc_night
,fte_night
,gap_night_withoutlow
,gap_new_withoutlow
from data_build.dwd_store_construction_store_groups_recruit_gap
where dt >= 20250701
and store_code = '100000150'

--排班流水表
SELECT * from data_smartorder.dw_roster_plan_shift_version_info_da
where dt = 20250707
and staff_code = '11407638'

--周围门店找gap
SELECT 
t1.*
,t2.gap_new
,t2.gap_new_withoutlow
from data_gis_h3.mid_order_external_same_city_store_riding_distance_type_zero_do_business_union_all_view t1
left join data_build.dwd_store_construction_store_groups_recruit_gap t2 on t1.b_store_code = t2.store_code and t2.dt = '${today-1}'
where t1.dt = '${today-1}'
and a_store_code = '100005109'



