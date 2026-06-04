--t30提离职率
SET hive.mapjoin.optimized.hashtable=false;
with supply_detail as
(
select 
* 
,from_unixtime(unix_timestamp(dt,'yyyymmdd'),'yyyy-mm-dd') as record_date
from 
data_build.dwd_store_construction_roster_staff_supply_v1_di
where dt >= '20220601'
)


,apply_leave_info as (
    select distinct
        t1.dept_code --门店code
        ,t1.man_code --工号
        ,if(length(t1.man_code)<8,concat('10',t1.man_code),t1.man_code) as staff_code
        ,t1.job --岗位
        ,date_format(create_time,'yyyyMMdd') as apply_dt
        ,date_format(create_time,'yyyy-MM-dd') as apply_date
        ,date_format(date_sub(create_time,1),'yyyyMMdd') as apply_dt_t1
        ,substr(position_class,1,1) as origin_tag
        ,coalesce(substr(position_class,1,1),'新') as new_old_tag
        ,coalesce(t2.protect_tag,'待观察') as protect_tag
        ,case when t3.hps_dept_descr_lv5 like '%区X%' then 1 else 0 end as is_district_staff
        ,t5.chuqin_label as chuqin_label
        ,t4.key_staff_type
        ,t6.protect_tag_detail_new as district_staff_protect_tag
    from data_shop.pdw_gis_workday_dimission_order_view t1
    left join data_shop.dm_shop_staff_protect_tag_v2 t2
    on t2.dt >= '20220630' 
        and date_format(date_sub(create_time,1),'yyyyMMdd') = t2.dt
        and if(length(t1.man_code)<8,concat('10',t1.man_code),t1.man_code) = t2.staff_code
    left join supply_detail t5
    on date_format(date_sub(create_time,1),'yyyy-MM-dd') = t5.record_date
    and if(length(t1.man_code)<8,concat('10',t1.man_code),t1.man_code) = t5.employee_id
    left join data_build.pdw_psprod_ps_blf_ehr_pers_vw_view t3 on if(length(t1.man_code)<8,concat('10',t1.man_code),t1.man_code) = if(length(t3.emplid)<8,concat('10',t3.emplid),t3.emplid) and t3.dt ='${today-1}' 
    left join data_build.dwd_store_construction_roster_staff_supply_v1_di t4 on cast(if(length(t1.man_code)<8,concat('10',t1.man_code),t1.man_code) as string) = cast(t4.employee_id as string) and t1.dt = t4.dt
    left join data_build.dwd_dwd_district_staff_protect_tag_v2_da_di t6 on if(length(t1.man_code)<8,concat('10',t1.man_code),t1.man_code) = t6.staff_code and t1.dt=t6.dt
    where t1.dt = '${today-1}' 
        and t1.job in ('店经理', '门店伙伴', '店员','社会PT','店副经理', '学生PT', '见习店经理')
        and date_format(create_time,'yyyyMMdd') >= '20220701'
        --and final_leave = 'leave'
        and not (date_format(create_time,'yyyyMMdd') = '20251112' and leave_way = '3') --20251112系统bug,批量发送被动离职流程，需要刨除
)



,leave_cnts_info as (
    select 
        apply_dt
        ,'1' as joinkey
        ,count(distinct staff_code) as leave_cnts
        ,count(distinct case when job = '店经理' then staff_code end) as manager_cnts
        ,count(distinct case when job = '店副经理' then staff_code end) as sec_manager_cnts
        ,count(distinct case when is_district_staff = 1 then staff_code end) as district_staff_cnts
        ,count(distinct case when is_district_staff = 1 and new_old_tag = '老' then staff_code end) as old_district_staff_cnts
        ,count(distinct case when is_district_staff = 1 and new_old_tag = '新' then staff_code end) as new_district_staff_cnts
        ,count(distinct case when is_district_staff = 1 and protect_tag in ('应保护','金牌','普通','银牌') then staff_code end) as good_district_staff_cnts--新增了这个
        ,count(distinct case when is_district_staff = 1 and district_staff_protect_tag = 0 then staff_code end) as diamond_district_staff_cnts
        ,count(distinct case when is_district_staff = 1 and protect_tag in ('末位普通','应离职') then staff_code end) as bad_district_staff_cnts
        ,count(distinct case when is_district_staff = 0 and job not in ('店经理','店副经理') then staff_code end) as staff_cnts
        ,count(distinct case when is_district_staff = 0 and job not in ('店经理','店副经理') and new_old_tag = '老' and chuqin_label = '长夜型员工' then staff_code end) as night_staff_cnts
        ,count(distinct case when is_district_staff = 0 and job not in ('店经理','店副经理') and new_old_tag = '老' then staff_code end) as old_staff_cnts
        ,count(distinct case when is_district_staff = 0 and job not in ('店经理','店副经理') and new_old_tag = '新' then staff_code end) as new_staff_cnts
        ,count(distinct case when is_district_staff = 0 and job not in ('店经理','店副经理') and new_old_tag = '老' and protect_tag in ('应保护','金牌') then staff_code end) as old_staff_cnts_1
        ,count(distinct case when is_district_staff = 0 and job not in ('店经理','店副经理') and new_old_tag = '老' and protect_tag in ('普通','银牌') then staff_code end) as old_staff_cnts_2
        ,count(distinct case when is_district_staff = 0 and job not in ('店经理','店副经理') and new_old_tag = '老' and protect_tag in ('末位普通','须努力') then staff_code end) as old_staff_cnts_4
        ,count(distinct case when is_district_staff = 0 and job not in ('店经理','店副经理') and new_old_tag = '老' and protect_tag in ('应离职','不合格') then staff_code end) as old_staff_cnts_5
        ,count(distinct case when is_district_staff = 0 and job not in ('店经理','店副经理') and key_staff_type = 'key_staff' then staff_code end) as key_staff_cnts
    from apply_leave_info t1
    left join data_shop.pdw_idss_ipes_admin_employee_blacklist_view t2
    on t2.dt >= '20220601' and t1.staff_code = lpad(t2.employee_no,8,'10') and t1.apply_dt_t1 = t2.dt and valid_status='1' and start_date<=apply_date and end_date>=apply_date
    where t2.employee_no is null
    group by apply_dt
    ,'1'
)

,ppl_cnts_info as (
    select 
        t1.dt
        ,'1' as joinkey
        ,date_format(date_add(to_date(from_unixtime(unix_timestamp(t1.dt,'yyyyMMdd'))),30),'yyyyMMdd') as dt_add_30_days
        ,count(distinct t1.staff_code) as ppl_cnts
        ,count(distinct case when t1.position_cn = '店经理' then t1.staff_code end) as manager_cnts
        ,count(distinct case when t1.position_cn = '店副经理' then t1.staff_code end) as sec_manager_cnts
        ,count(distinct case when t3.hps_dept_descr_lv5 like '%区X%' then t1.staff_code end) as district_staff_cnts
        ,count(distinct case when t3.hps_dept_descr_lv5 like '%区X%' and substr(t1.position_class,1,1) = '老' then t1.staff_code end) as old_district_staff_cnts
        ,count(distinct case when t3.hps_dept_descr_lv5 like '%区X%' and substr(t1.position_class,1,1) = '新' then t1.staff_code end) as new_district_staff_cnts
        ,count(distinct case when t3.hps_dept_descr_lv5 like '%区X%' and t1.protect_tag in  ('应保护','金牌','普通','银牌') then t1.staff_code end) as good_district_staff_cnts--新增了这个
        ,count(distinct case when t3.hps_dept_descr_lv5 like '%区X%' and t5.protect_tag_detail_new = 0  then t1.staff_code end) as diamond_district_staff_cnts
        ,count(distinct case when t3.hps_dept_descr_lv5 like '%区X%' and t1.protect_tag in ('末位普通','应离职')  then t1.staff_code end) as bad_district_staff_cnts
        ,count(distinct case when t3.hps_dept_descr_lv5 not like '%区X%' and t1.position_cn not in ('店经理','店副经理') then t1.staff_code end) as staff_cnts
        ,count(distinct case when t3.hps_dept_descr_lv5 not like '%区X%' and substr(t1.position_class,1,1) = '老' and t1.position_cn not in ('店经理','店副经理') then t1.staff_code end) as old_staff_cnts
        ,count(distinct case when t3.hps_dept_descr_lv5 not like '%区X%' and substr(t1.position_class,1,1) = '老' and t1.position_cn not in ('店经理','店副经理') and t2.chuqin_label = '长夜型员工' then t1.staff_code end) as night_staff_cnts
        ,count(distinct case when t3.hps_dept_descr_lv5 not like '%区X%' and substr(t1.position_class,1,1) = '新' and t1.position_cn not in ('店经理','店副经理') then t1.staff_code end) as new_staff_cnts
        ,count(distinct case when t3.hps_dept_descr_lv5 not like '%区X%' and substr(t1.position_class,1,1) = '老' and t1.position_cn not in ('店经理','店副经理') and t1.protect_tag in ('应保护','金牌') then t1.staff_code end) as old_staff_cnts_1
        ,count(distinct case when t3.hps_dept_descr_lv5 not like '%区X%' and substr(t1.position_class,1,1) = '老' and t1.position_cn not in ('店经理','店副经理') and t1.protect_tag in ('普通','银牌') then t1.staff_code end) as old_staff_cnts_2
        ,count(distinct case when t3.hps_dept_descr_lv5 not like '%区X%' and substr(t1.position_class,1,1) = '老' and t1.position_cn not in ('店经理','店副经理') and t1.protect_tag in ('末位普通','须努力') then t1.staff_code end) as old_staff_cnts_4
        ,count(distinct case when t3.hps_dept_descr_lv5 not like '%区X%' and substr(t1.position_class,1,1) = '老' and t1.position_cn not in ('店经理','店副经理') and t1.protect_tag in ('应离职','不合格') then t1.staff_code end) as old_staff_cnts_5
        ,count(distinct case when t3.hps_dept_descr_lv5 not like '%区X%' and t1.position_cn not in ('店经理','店副经理') and t4.key_staff_type = 'key_staff' then t1.staff_code end) as key_staff_cnts
    from data_shop.dm_shop_staff_protect_tag_v2 t1
    left join supply_detail t2 on t1.staff_code = t2.employee_id and from_unixtime(unix_timestamp(t1.dt,'yyyymmdd'),'yyyy-mm-dd') = t2.record_date
    left join data_build.pdw_psprod_ps_blf_ehr_pers_vw_view t3 on t1.staff_code = if(length(t3.emplid)<8,concat('10',t3.emplid),t3.emplid) and t3.dt ='${today-1}' 
    left join data_build.dwd_store_construction_roster_staff_supply_v1_di t4 on t1.staff_code = t4.employee_id and t1.dt = t4.dt
    left join data_build.dwd_dwd_district_staff_protect_tag_v2_da_di t5 on t1.staff_code = t5.staff_code  and t1.dt=t5.dt
    where t1.dt >= '20220701'
    and t1.position_cn not in ('内部合作伙伴','内部合作经营者','内部合作辅助人','外部合作伙伴','外部合作经营者','外部合作辅助人')
    group by t1.dt
    ,'1'
)

,prep_info as (
    select 
        t1.dt
        ,t1.dt_add_30_days
        ,t1.ppl_cnts as start_ppl_cnts
        ,t2.ppl_cnts as end_ppl_cnts
        ,t1.manager_cnts as start_manager_cnts
        ,t2.manager_cnts as end_manager_cnts
        ,t1.sec_manager_cnts as start_sec_manager_cnts
        ,t2.sec_manager_cnts as end_sec_manager_cnts
        ,t1.district_staff_cnts as start_district_staff_cnts
        ,t2.district_staff_cnts as end_district_staff_cnts
        ,t1.night_staff_cnts as start_night_staff_cnts
        ,t2.night_staff_cnts as end_night_staff_cnts
        ,t1.old_district_staff_cnts as start_old_district_staff_cnts
        ,t2.old_district_staff_cnts as end_old_district_staff_cnts
        ,t1.new_district_staff_cnts as start_new_district_staff_cnts
        ,t2.new_district_staff_cnts as end_new_district_staff_cnts
        ,t1.good_district_staff_cnts as start_good_district_staff_cnts --新增了这个20240401
        ,t2.good_district_staff_cnts as end_good_district_staff_cnts --新增了这个20240401
        ,t1.diamond_district_staff_cnts as start_diamond_district_staff_cnts
        ,t2.diamond_district_staff_cnts as end_diamond_district_staff_cnts
        ,t1.bad_district_staff_cnts as start_bad_district_staff_cnts
        ,t2.bad_district_staff_cnts as end_bad_district_staff_cnts
        ,t1.staff_cnts as start_staff_cnts
        ,t2.staff_cnts as end_staff_cnts
        ,t1.old_staff_cnts as start_old_staff_cnts
        ,t2.old_staff_cnts as end_old_staff_cnts
        ,t1.new_staff_cnts as start_new_staff_cnts
        ,t2.new_staff_cnts as end_new_staff_cnts

        ,t1.old_staff_cnts_1 as start_old_staff_cnts_1
        ,t2.old_staff_cnts_1 as end_old_staff_cnts_1
        ,t1.old_staff_cnts_2 as start_old_staff_cnts_2
        ,t2.old_staff_cnts_2 as end_old_staff_cnts_2
        ,t1.old_staff_cnts_4 as start_old_staff_cnts_4
        ,t2.old_staff_cnts_4 as end_old_staff_cnts_4
        ,t1.old_staff_cnts_5 as start_old_staff_cnts_5
        ,t2.old_staff_cnts_5 as end_old_staff_cnts_5
        ,t1.key_staff_cnts as start_key_staff_cnts
        ,t2.key_staff_cnts as end_key_staff_cnts

        ,t3.apply_dt
        ,t3.leave_cnts
        ,t3.manager_cnts
        ,t3.sec_manager_cnts
        ,t3.district_staff_cnts
        ,t3.old_district_staff_cnts
        ,t3.new_district_staff_cnts
        ,t3.good_district_staff_cnts --20240401新增
        ,t3.diamond_district_staff_cnts
        ,t3.bad_district_staff_cnts
        ,t3.staff_cnts
        ,t3.old_staff_cnts
        ,t3.night_staff_cnts
        ,t3.new_staff_cnts
        ,t3.old_staff_cnts_1
        ,t3.old_staff_cnts_2
        ,t3.old_staff_cnts_4
        ,t3.old_staff_cnts_5
        ,t3.key_staff_cnts
    from ppl_cnts_info t1
    inner join ppl_cnts_info t2
    on t1.dt_add_30_days = t2.dt and t1.dt_add_30_days <= '${today}'
    left join leave_cnts_info t3
    on t3.apply_dt>=t1.dt and t3.apply_dt<t1.dt_add_30_days and t1.joinkey = t3.joinkey
)

select 
    t1.dt
    ,t1.dt_add_30_days
    ,(start_ppl_cnts+end_ppl_cnts)/2 as ppl_cnts
    ,(start_manager_cnts+end_manager_cnts)/2 as manager_cnts
    ,(start_sec_manager_cnts+end_sec_manager_cnts)/2 as sec_manager_cnts
    ,(start_old_district_staff_cnts+end_old_district_staff_cnts)/2 as old_district_staff_cnts
    ,(start_new_district_staff_cnts+end_new_district_staff_cnts)/2 as new_district_staff_cnts
    ,(start_good_district_staff_cnts+end_good_district_staff_cnts)/2 as good_district_staff_cnts --20240401新增
    ,(start_district_staff_cnts+end_district_staff_cnts)/2 as district_staff_cnts
    ,(start_diamond_district_staff_cnts+end_diamond_district_staff_cnts)/2 as diamond_district_staff_cnts
    ,(start_bad_district_staff_cnts+end_bad_district_staff_cnts)/2 as bad_district_staff_cnts

    ,(start_staff_cnts+end_staff_cnts)/2 as staff_cnts
    ,(start_night_staff_cnts+end_night_staff_cnts)/2 as night_staff_cnts

    ,(start_old_staff_cnts+end_old_staff_cnts)/2 as old_staff_cnts
    ,(start_new_staff_cnts+end_new_staff_cnts)/2 as new_staff_cnts

    ,(start_old_staff_cnts_1+end_old_staff_cnts_1)/2 as old_staff_cnts_1
    ,(start_old_staff_cnts_2+end_old_staff_cnts_2)/2 as old_staff_cnts_2
    ,(start_old_staff_cnts_4+end_old_staff_cnts_4)/2 as old_staff_cnts_4
    ,(start_old_staff_cnts_5+end_old_staff_cnts_5)/2 as old_staff_cnts_5
    ,(start_key_staff_cnts+end_key_staff_cnts)/2 as key_staff_cnts

    ,sum(leave_cnts) as leave_cnts
    ,sum(manager_cnts) as leave_manager_cnts
    ,sum(sec_manager_cnts) as leave_sec_manager_cnts
    ,sum(district_staff_cnts) as leave_district_staff_cnts
    ,sum(old_district_staff_cnts) as leave_old_district_staff_cnts
    ,sum(new_district_staff_cnts) as leave_new_district_staff_cnts
    ,sum(good_district_staff_cnts) as leave_good_district_staff_cnts --20240401新增
    ,sum(diamond_district_staff_cnts) as leave_diamond_district_staff_cnts
    ,sum(bad_district_staff_cnts) as leave_bad_district_staff_cnts
    ,sum(staff_cnts) as leave_staff_cnts
    ,sum(night_staff_cnts) as leave_night_staff_cnts
    ,sum(old_staff_cnts) as leave_old_staff_cnts
    ,sum(new_staff_cnts) as leave_new_staff_cnts

    ,sum(old_staff_cnts_1) as leave_old_staff_cnts_1
    ,sum(old_staff_cnts_2) as leave_old_staff_cnts_2
    ,sum(old_staff_cnts_4) as leave_old_staff_cnts_4
    ,sum(old_staff_cnts_5) as leave_old_staff_cnts_5
    ,sum(key_staff_cnts) as leave_key_staff_cnts

from prep_info t1
group by t1.dt
    ,t1.dt_add_30_days
    ,t1.start_ppl_cnts
    ,t1.end_ppl_cnts
    ,t1.start_manager_cnts
    ,t1.end_manager_cnts
    ,t1.start_sec_manager_cnts
    ,t1.end_sec_manager_cnts
    ,t1.start_district_staff_cnts
    ,t1.end_district_staff_cnts
    ,t1.start_old_district_staff_cnts
    ,t1.start_new_district_staff_cnts
    ,t1.end_old_district_staff_cnts
    ,t1.end_new_district_staff_cnts
    ,t1.start_good_district_staff_cnts --20240401新增
    ,t1.end_good_district_staff_cnts --20240401新增
    ,t1.start_diamond_district_staff_cnts
    ,t1.end_diamond_district_staff_cnts
    ,t1.start_bad_district_staff_cnts
    ,t1.end_bad_district_staff_cnts
    ,t1.start_staff_cnts
    ,t1.end_staff_cnts
    ,t1.start_night_staff_cnts
    ,t1.end_night_staff_cnts
    ,t1.start_old_staff_cnts
    ,t1.end_old_staff_cnts
    ,t1.start_new_staff_cnts
    ,t1.end_new_staff_cnts
    ,t1.start_old_staff_cnts_1
    ,t1.end_old_staff_cnts_1
    ,t1.start_old_staff_cnts_2
    ,t1.end_old_staff_cnts_2
    ,t1.start_old_staff_cnts_4
    ,t1.end_old_staff_cnts_4
    ,t1.start_old_staff_cnts_5
    ,t1.end_old_staff_cnts_5
    ,t1.start_key_staff_cnts
    ,t1.end_key_staff_cnts


*************************************************************************************************************************************************************************
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------
*************************************************************************************************************************************************************************
--T30提离职率_主动提离职_剔除撤店
--【看板】T30提离职率（剔除撤店+主动提交离职）


with supply_detail as
(
select 
* 
,from_unixtime(unix_timestamp(dt,'yyyymmdd'),'yyyy-mm-dd') as record_date
from 
data_build.dwd_store_construction_roster_staff_supply_v1_di
where dt >= '20230601'
)


,apply_leave_info as (
    select distinct
        t1.dept_code --门店code
        ,t1.man_code --工号
        ,if(length(t1.man_code)<8,concat('10',t1.man_code),t1.man_code) as staff_code
        ,t1.work_city_name --一会儿删掉给陈欢用的
        ,t1.job --岗位
        ,date_format(create_time,'yyyyMMdd') as apply_dt
        ,date_format(create_time,'yyyy-MM-dd') as apply_date
        ,date_format(date_sub(create_time,1),'yyyyMMdd') as apply_dt_t1
        ,substr(position_class,1,1) as origin_tag
        ,coalesce(substr(position_class,1,1),'新') as new_old_tag
        ,coalesce(t2.protect_tag,'待观察') as protect_tag
        ,case when t3.hps_dept_descr_lv5 like '%区X%' then 1 else 0 end as is_district_staff
        ,t5.chuqin_label as chuqin_label
        ,t4.key_staff_type
    from data_shop.pdw_gis_workday_dimission_order_view t1
    left join data_shop.dm_shop_staff_protect_tag_v2 t2
    on t2.dt >= '20230601' 
        and date_format(date_sub(create_time,1),'yyyyMMdd') = t2.dt
        and if(length(t1.man_code)<8,concat('10',t1.man_code),t1.man_code) = t2.staff_code
    left join supply_detail t5
    on date_format(date_sub(create_time,1),'yyyy-MM-dd') = t5.record_date
    and if(length(t1.man_code)<8,concat('10',t1.man_code),t1.man_code) = t5.employee_id
    left join data_build.pdw_psprod_ps_blf_ehr_pers_vw_view t3 on if(length(t1.man_code)<8,concat('10',t1.man_code),t1.man_code) = if(length(t3.emplid)<8,concat('10',t3.emplid),t3.emplid) and t3.dt ='${today-1}' 
    left join data_build.dwd_store_construction_roster_staff_supply_v1_di t4 on if(length(t1.man_code)<8,concat('10',t1.man_code),t1.man_code) = t4.employee_id and t1.dt =t4.dt
    where t1.dt = '${today-1}' 
        and t1.job in ('店经理', '门店伙伴', '店员','社会PT','店副经理', '学生PT', '见习店经理')
        and date_format(create_time,'yyyyMMdd') >= '20230601'
        and leave_way = 1
        --and final_leave = 'leave'
)

--撤店部分信息

,project_list as (
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


,cancel_store as (
select *
from (
 select 
 t2.flag_code 
 ,t2.project_name 
 ,t2.city_name 
 ,t2.store_code 
 ,t2.store_name 
 ,create_time 
 ,flow_order_id 
 ,case when t1.cancel_state = 'suspend' then '解约中止'
 when t1.cancel_state = 'doing' then '解约中'
 when t1.cancel_state = 'done' then '解约完成'
 end 
 ,case when cancel_type = 1 then '先谈后撤' 
 when cancel_type = 2 then '先撤后谈' 
 when cancel_type = 3 then '谈判同时撤店'
 when cancel_type = 0 then null
 end 
 ,cancel_method as `解约方式`
 ,rent_reduction_ratio as `降租保留比例`
 ,withdraw_shop_date as `完成撤店时间`
 ,case when cancel_source = 1 then '甲方违约'
 when cancel_source = 2 then '乙方违约'
 when cancel_source = 3 then '到期不续'
 when cancel_source = 4 then '法务评估无责解约'
 when cancel_source = 99 then '其他'
 when cancel_source = 0 then null
 end 
 ,other_cancel_source as `其他发起来源`
 ,case when revoke_reason = 1 then '门店降免租保留'
 when revoke_reason = 2 then '门店策略保留'
 when revoke_reason = 99 then '其他'
 when revoke_reason = 0 then null
 end 
 ,row_number()over(partition by flag_code order by create_time desc) as rn
 from data_build.pdw_opc_flag_project_cancel_sign_view t1
 left join project_list t2 on t1.project_id = t2.project_id 
 where t1.dt >= 20230201
 and t2.flag_code is not null
)t1
where t1.rn = 1
)


,apply_leave_info_final as (

    select 
        t1.*
        ,(case when t2.store_code is null then '保留门店' else '撤店门店' end) as store_status
    from apply_leave_info t1
    left join cancel_store t2
         on t1.dept_code = t2.store_code
)



,leave_cnts_info as (
    select 
        apply_dt
        ,'1' as joinkey
        ,count(distinct case when store_status <> '撤店门店' then staff_code end) as leave_cnts
        ,count(distinct case when store_status <> '撤店门店' and job = '店经理'  then staff_code end) as manager_cnts
        ,count(distinct case when store_status <> '撤店门店' and job = '店副经理' then staff_code end) as sec_manager_cnts
        ,count(distinct case when is_district_staff = 1 then staff_code end) as district_staff_cnts
        ,count(distinct case when is_district_staff = 1 and new_old_tag = '老' then staff_code end) as old_district_staff_cnts
        ,count(distinct case when is_district_staff = 1 and new_old_tag = '新' then staff_code end) as new_district_staff_cnts
        ,count(distinct case when is_district_staff = 1 and protect_tag in ('应保护','金牌','普通','银牌') then staff_code end) as good_district_staff_cnts--新增了这个
        ,count(distinct case when is_district_staff = 0 and store_status <> '撤店门店'and job not in ('店经理','店副经理') then staff_code end) as staff_cnts
        ,count(distinct case when is_district_staff = 0 and store_status <> '撤店门店'and job not in ('店经理','店副经理') and new_old_tag = '老' and chuqin_label = '长夜型员工' then staff_code end) as night_staff_cnts
        ,count(distinct case when is_district_staff = 0 and store_status <> '撤店门店'and job not in ('店经理','店副经理') and new_old_tag = '老' then staff_code end) as old_staff_cnts
        ,count(distinct case when is_district_staff = 0 and store_status <> '撤店门店'and job not in ('店经理','店副经理') and new_old_tag = '新' then staff_code end) as new_staff_cnts
        ,count(distinct case when is_district_staff = 0 and store_status <> '撤店门店'and job not in ('店经理','店副经理') and new_old_tag = '老' and protect_tag in ('应保护','金牌') then staff_code end) as old_staff_cnts_1
        ,count(distinct case when is_district_staff = 0 and store_status <> '撤店门店'and job not in ('店经理','店副经理') and new_old_tag = '老' and protect_tag in ('普通','银牌') then staff_code end) as old_staff_cnts_2
        ,count(distinct case when is_district_staff = 0 and store_status <> '撤店门店'and job not in ('店经理','店副经理') and new_old_tag = '老' and protect_tag in ('末位普通','须努力') then staff_code end) as old_staff_cnts_4
        ,count(distinct case when is_district_staff = 0 and store_status <> '撤店门店'and job not in ('店经理','店副经理') and new_old_tag = '老' and protect_tag in ('应离职','不合格') then staff_code end) as old_staff_cnts_5
        ,count(distinct case when is_district_staff = 0 and store_status <> '撤店门店'and job not in ('店经理','店副经理') and key_staff_type = 'key_staff' then staff_code end) as key_staff_cnts
    from apply_leave_info_final t1
    left join data_shop.pdw_idss_ipes_admin_employee_blacklist_view t2
        on t2.dt >= '20230601' and t1.staff_code = lpad(t2.employee_no,8,'10') and t1.apply_dt_t1 = t2.dt and valid_status='1' and start_date<=apply_date and end_date>=apply_date
    where t2.employee_no is null
    group by apply_dt
    ,'1'
)


,protect_tag_final as (

    select 
        t1.*
        ,(case when t2.store_code is null then '保留门店' else '撤店门店' end) as store_status
    from data_shop.dm_shop_staff_protect_tag_v2 t1
    left join cancel_store t2
         on t1.store_code = t2.store_code
)


,ppl_cnts_info as (
    select 
        t1.dt
        ,'1' as joinkey
        ,date_format(date_add(to_date(from_unixtime(unix_timestamp(t1.dt,'yyyyMMdd'))),30),'yyyyMMdd') as dt_add_30_days
        ,count(distinct case when t1.store_status <> '撤店门店' then t1.staff_code end ) as ppl_cnts
        ,count(distinct case when t1.store_status <> '撤店门店' and t1.position_cn = '店经理' then t1.staff_code end) as manager_cnts
        ,count(distinct case when t1.store_status <> '撤店门店' and t1.position_cn = '店副经理' then t1.staff_code end) as sec_manager_cnts
        ,count(distinct case when t3.hps_dept_descr_lv5 like '%区X%' then t1.staff_code end) as district_staff_cnts
        ,count(distinct case when t3.hps_dept_descr_lv5 like '%区X%' and substr(t1.position_class,1,1) = '老' then t1.staff_code end) as old_district_staff_cnts
        ,count(distinct case when t3.hps_dept_descr_lv5 like '%区X%' and substr(t1.position_class,1,1) = '新' then t1.staff_code end) as new_district_staff_cnts
        ,count(distinct case when t3.hps_dept_descr_lv5 like '%区X%' and t1.protect_tag in  ('应保护','金牌','普通','银牌') then t1.staff_code end) as good_district_staff_cnts--新增了这个
        ,count(distinct case when t1.store_status <> '撤店门店' and t3.hps_dept_descr_lv5 not like '%区X%' and t1.position_cn not in ('店经理','店副经理') then t1.staff_code end) as staff_cnts
        ,count(distinct case when t1.store_status <> '撤店门店' and t3.hps_dept_descr_lv5 not like '%区X%' and substr(t1.position_class,1,1) = '老' and t1.position_cn not in ('店经理','店副经理') then t1.staff_code end) as old_staff_cnts
        ,count(distinct case when t1.store_status <> '撤店门店' and t3.hps_dept_descr_lv5 not like '%区X%' and substr(t1.position_class,1,1) = '老' and t1.position_cn not in ('店经理','店副经理') and t2.chuqin_label = '长夜型员工' then t1.staff_code end) as night_staff_cnts
        ,count(distinct case when t1.store_status <> '撤店门店' and t3.hps_dept_descr_lv5 not like '%区X%' and substr(t1.position_class,1,1) = '新' and t1.position_cn not in ('店经理','店副经理') then t1.staff_code end) as new_staff_cnts
        ,count(distinct case when t1.store_status <> '撤店门店' and t3.hps_dept_descr_lv5 not like '%区X%' and substr(t1.position_class,1,1) = '老' and t1.position_cn not in ('店经理','店副经理') and t1.protect_tag in ('应保护','金牌') then staff_code end) as old_staff_cnts_1
        ,count(distinct case when t1.store_status <> '撤店门店' and t3.hps_dept_descr_lv5 not like '%区X%' and substr(t1.position_class,1,1) = '老' and t1.position_cn not in ('店经理','店副经理') and t1.protect_tag in ('普通','银牌') then staff_code end) as old_staff_cnts_2
        ,count(distinct case when t1.store_status <> '撤店门店' and t3.hps_dept_descr_lv5 not like '%区X%' and substr(t1.position_class,1,1) = '老' and t1.position_cn not in ('店经理','店副经理') and t1.protect_tag in ('末位普通','须努力') then staff_code end) as old_staff_cnts_4
        ,count(distinct case when t1.store_status <> '撤店门店' and t3.hps_dept_descr_lv5 not like '%区X%' and substr(t1.position_class,1,1) = '老' and t1.position_cn not in ('店经理','店副经理') and t1.protect_tag in ('应离职','不合格') then staff_code end) as old_staff_cnts_5
        ,count(distinct case when t1.store_status <> '撤店门店' and t3.hps_dept_descr_lv5 not like '%区X%' and t1.position_cn not in ('店经理','店副经理') and t4.key_staff_type = 'key_staff' then staff_code end) as key_staff_cnts
    from protect_tag_final t1
    left join supply_detail t2 on t1.staff_code = t2.employee_id and from_unixtime(unix_timestamp(t1.dt,'yyyymmdd'),'yyyy-mm-dd') = t2.record_date
    left join data_build.pdw_psprod_ps_blf_ehr_pers_vw_view t3 on t1.staff_code = if(length(t3.emplid)<8,concat('10',t3.emplid),t3.emplid) and t3.dt ='${today-1}' 
    left join data_build.dwd_store_construction_roster_staff_supply_v1_di t4 on t1.staff_code = t4.employee_id and t4.dt ='${today-1}' 
    where t1.dt >= '20230601'
    group by t1.dt
    ,'1'
)

,prep_info as (
    select 
        t1.dt
        ,t1.dt_add_30_days
        ,t1.ppl_cnts as start_ppl_cnts
        ,t2.ppl_cnts as end_ppl_cnts
        ,t1.manager_cnts as start_manager_cnts
        ,t2.manager_cnts as end_manager_cnts
        ,t1.sec_manager_cnts as start_sec_manager_cnts
        ,t2.sec_manager_cnts as end_sec_manager_cnts
        ,t1.district_staff_cnts as start_district_staff_cnts
        ,t2.district_staff_cnts as end_district_staff_cnts
        ,t1.night_staff_cnts as start_night_staff_cnts
        ,t2.night_staff_cnts as end_night_staff_cnts
        ,t1.old_district_staff_cnts as start_old_district_staff_cnts
        ,t2.old_district_staff_cnts as end_old_district_staff_cnts
        ,t1.new_district_staff_cnts as start_new_district_staff_cnts
        ,t2.new_district_staff_cnts as end_new_district_staff_cnts
        ,t1.good_district_staff_cnts as start_good_district_staff_cnts --新增了这个20240401
        ,t2.good_district_staff_cnts as end_good_district_staff_cnts --新增了这个20240401
        ,t1.staff_cnts as start_staff_cnts
        ,t2.staff_cnts as end_staff_cnts
        ,t1.old_staff_cnts as start_old_staff_cnts
        ,t2.old_staff_cnts as end_old_staff_cnts
        ,t1.new_staff_cnts as start_new_staff_cnts
        ,t2.new_staff_cnts as end_new_staff_cnts

        ,t1.old_staff_cnts_1 as start_old_staff_cnts_1
        ,t2.old_staff_cnts_1 as end_old_staff_cnts_1
        ,t1.old_staff_cnts_2 as start_old_staff_cnts_2
        ,t2.old_staff_cnts_2 as end_old_staff_cnts_2
        ,t1.old_staff_cnts_4 as start_old_staff_cnts_4
        ,t2.old_staff_cnts_4 as end_old_staff_cnts_4
        ,t1.old_staff_cnts_5 as start_old_staff_cnts_5
        ,t2.old_staff_cnts_5 as end_old_staff_cnts_5
        ,t1.key_staff_cnts as start_key_staff_cnts
        ,t2.key_staff_cnts as end_key_staff_cnts

        ,t3.apply_dt
        ,t3.leave_cnts
        ,t3.manager_cnts
        ,t3.sec_manager_cnts
        ,t3.district_staff_cnts
        ,t3.old_district_staff_cnts
        ,t3.new_district_staff_cnts
        ,t3.good_district_staff_cnts --20240401新增
        ,t3.staff_cnts
        ,t3.old_staff_cnts
        ,t3.night_staff_cnts
        ,t3.new_staff_cnts
        ,t3.old_staff_cnts_1
        ,t3.old_staff_cnts_2
        ,t3.old_staff_cnts_4
        ,t3.old_staff_cnts_5
        ,t3.key_staff_cnts
    from ppl_cnts_info t1
    inner join ppl_cnts_info t2
    on t1.dt_add_30_days = t2.dt and t1.dt_add_30_days <= '${today}'
    left join leave_cnts_info t3
    on t3.apply_dt>=t1.dt and t3.apply_dt<t1.dt_add_30_days and t1.joinkey = t3.joinkey
)

select 
    t1.dt
    ,t1.dt_add_30_days
    ,(start_ppl_cnts+end_ppl_cnts)/2 as ppl_cnts
    ,(start_manager_cnts+end_manager_cnts)/2 as manager_cnts
    ,(start_sec_manager_cnts+end_sec_manager_cnts)/2 as sec_manager_cnts
    ,(start_old_district_staff_cnts+end_old_district_staff_cnts)/2 as old_district_staff_cnts
        ,(start_new_district_staff_cnts+end_new_district_staff_cnts)/2 as new_district_staff_cnts
        ,(start_good_district_staff_cnts+end_good_district_staff_cnts)/2 as good_district_staff_cnts --20240401新增

    ,(start_district_staff_cnts+end_district_staff_cnts)/2 as district_staff_cnts

    ,(start_staff_cnts+end_staff_cnts)/2 as staff_cnts
    ,(start_night_staff_cnts+end_night_staff_cnts)/2 as night_staff_cnts

    ,(start_old_staff_cnts+end_old_staff_cnts)/2 as old_staff_cnts
    ,(start_new_staff_cnts+end_new_staff_cnts)/2 as new_staff_cnts

    ,(start_old_staff_cnts_1+end_old_staff_cnts_1)/2 as old_staff_cnts_1
    ,(start_old_staff_cnts_2+end_old_staff_cnts_2)/2 as old_staff_cnts_2
    ,(start_old_staff_cnts_4+end_old_staff_cnts_4)/2 as old_staff_cnts_4
    ,(start_old_staff_cnts_5+end_old_staff_cnts_5)/2 as old_staff_cnts_5
    ,(start_key_staff_cnts+end_key_staff_cnts)/2 as key_staff_cnts

    ,sum(leave_cnts) as leave_cnts
    ,sum(manager_cnts) as leave_manager_cnts
    ,sum(sec_manager_cnts) as leave_sec_manager_cnts
    ,sum(district_staff_cnts) as leave_district_staff_cnts
    ,sum(old_district_staff_cnts) as leave_old_district_staff_cnts
    ,sum(new_district_staff_cnts) as leave_new_district_staff_cnts
    ,sum(good_district_staff_cnts) as leave_good_district_staff_cnts --20240401新增
    ,sum(staff_cnts) as leave_staff_cnts
    ,sum(night_staff_cnts) as leave_night_staff_cnts
    ,sum(old_staff_cnts) as leave_old_staff_cnts
    ,sum(new_staff_cnts) as leave_new_staff_cnts

    ,sum(old_staff_cnts_1) as leave_old_staff_cnts_1
    ,sum(old_staff_cnts_2) as leave_old_staff_cnts_2
    ,sum(old_staff_cnts_4) as leave_old_staff_cnts_4
    ,sum(old_staff_cnts_5) as leave_old_staff_cnts_5
    ,sum(key_staff_cnts) as leave_key_staff_cnts

from prep_info t1
group by t1.dt
    ,t1.dt_add_30_days
    ,t1.start_ppl_cnts
    ,t1.end_ppl_cnts
    ,t1.start_manager_cnts
    ,t1.end_manager_cnts
    ,t1.start_sec_manager_cnts
    ,t1.end_sec_manager_cnts
    ,t1.start_district_staff_cnts
    ,t1.end_district_staff_cnts
    ,t1.start_old_district_staff_cnts
    ,t1.start_new_district_staff_cnts
    ,t1.end_old_district_staff_cnts
    ,t1.end_new_district_staff_cnts
    ,t1.start_good_district_staff_cnts --20240401新增
    ,t1.end_good_district_staff_cnts --20240401新增
    ,t1.start_staff_cnts
    ,t1.end_staff_cnts
    ,t1.start_night_staff_cnts
    ,t1.end_night_staff_cnts
    ,t1.start_old_staff_cnts
    ,t1.end_old_staff_cnts
    ,t1.start_new_staff_cnts
    ,t1.end_new_staff_cnts
    ,t1.start_old_staff_cnts_1
    ,t1.end_old_staff_cnts_1
    ,t1.start_old_staff_cnts_2
    ,t1.end_old_staff_cnts_2
    ,t1.start_old_staff_cnts_4
    ,t1.end_old_staff_cnts_4
    ,t1.start_old_staff_cnts_5
    ,t1.end_old_staff_cnts_5
    ,t1.start_key_staff_cnts
    ,t1.end_key_staff_cnts


















with apply_leave_list as ( -- 店经理及以下岗位申请离职流程明细
    select 
        distinct 
        if(length(user_job_number)<8,concat('10',user_job_number),user_job_number) as staff_code
        ,leave_way_desc as leave_way
        ,leave_reason
        ,work_city as city_name
        ,dimission_category_desc
        ,date_format(date_sub(hr_leave_date,1),'yyyyMMdd') as leave_dt --离职前一天
        ,date_format(hr_leave_date,'yyyy-MM-dd') as leave_date
        ,job_name as position_cn
        ,'店员' as position 
        ,substr(date_format(hr_leave_date,'yyyy-MM-dd'),1,7) as dt_month
        ,is_shop_leader
    from data_shop.app_gis_store_recruit_leave_person_by_day_view
    where dt = '${today-1}' and date_format(hr_leave_date,'yyyy-MM-dd') >= '2022-08-01'
)

,name_bd_match as (    
    select
        distinct
        IF(LENGTH(t1.emplid)<8,concat('10',t1.emplid),t1.emplid) AS staff_code --8位
        ,case 
            when floor(datediff('${TODAY}',t2.resume_birth_date)/365) is null then '无年龄信息'
            when floor(datediff('${TODAY}',t2.resume_birth_date)/365) <= 22 then '疑似学生'
            else '非学生' end as position_tag
    from data_shop.pdw_psprod_ps_blf_ehr_pers_vw_view t1
    left join data_shop.dw_gis_hire_recruit_detail_v1_di_view t2
    on t2.dt = '${today-1}' and length(t2.entry_user_id) >2 and t1.hps_sys_name = t2.entry_user_id
    where t1.dt = '${today-1}'
        and t1.hps_dept_descr_lv1 in ('运营管理部A','运营管理部B')
        and t1.hps_d_jobcode in ('店经理', '门店伙伴', '店员', '社会PT', '学生PT', '见习店经理')
)

,protect_tag_info as ( --最新保护标签
    select 
        staff_code
        ,staff_name
        ,city_name
        ,position_cn
        ,position
        ,protect_tag
        ,entry_date
        ,dt_month
    from (
        select 
            staff_code
            ,staff_name
            ,city_name
            ,position_cn
            ,case when position_cn like '%经理%' then '店长' else '店员' end as position
            ,concat(protect_tag_detail,'-',protect_tag) as protect_tag
            ,entry_date
            ,dt
            ,concat(substr(dt,1,4),'-',substr(dt,5,2)) as dt_month
            ,row_number() over(partition by substr(dt,1,6),staff_code order by dt desc) as rn
        from data_shop.dm_shop_staff_protect_tag_v2
        where dt >= '20220801'
    ) tmp
    where rn=1
)

,protect_tag_info_latest as ( --最新保护标签
    select 
        staff_code
        ,staff_name
        ,city_name
        ,position_cn
        ,position
        ,protect_tag
        ,entry_date
    from (
        select 
            staff_code
            ,staff_name
            ,city_name
            ,position_cn
            ,position
            ,protect_tag
            ,entry_date
            ,dt
            ,row_number() over(partition by staff_code order by dt desc) as rn
        from (
            select 
                staff_code
                ,staff_name
                ,city_name
                ,position_cn
                ,case when position_cn like '%经理%' then '店长' else '店员' end as position
                ,concat(protect_tag_detail,'-',protect_tag) as protect_tag
                ,entry_date
                ,dt
            from data_shop.dm_shop_staff_protect_tag_v2
            where dt >= '20220801'
        ) tmp
    )t0
    where t0.rn=1
)

,t30_hours as (
    select 
        staff_code
        ,work_shift_hours
        ,punish_rate_per_100_hour
        ,dt
        ,concat(substr(dt,1,4),'-',substr(dt,5,2)) as dt_month
    from data_shop.dm_shop_punish_pivot_v1_di
    where dt >= '20220801'
)

,latest_hours_per_month as (
    select 
        staff_code
        ,work_shift_hours
        ,punish_rate_per_100_hour
        ,dt_month
    from (
        select 
            staff_code
            ,work_shift_hours
            ,punish_rate_per_100_hour
            ,dt_month
            ,row_number() over(partition by dt_month,staff_code order by dt desc) as rn
        from t30_hours
    ) tmp
    where rn = 1
)

,give_satisfy_hours as (
    select 
        staff_code
        ,give_satisfy_rate
        ,total_attend_days
        ,dt
        ,concat(substr(dt,1,4),'-',substr(dt,5,2)) as dt_month
    from data_shop.dm_shop_staff_will_v1_di
    where dt >= '20220801'
)

,latest_give_satisfy_per_month as (
    select 
        staff_code
        ,give_satisfy_rate
        ,total_attend_days
        ,dt_month
    from (
        select 
            staff_code
            ,give_satisfy_rate
            ,total_attend_days
            ,dt_month
            ,row_number() over(partition by dt_month,staff_code order by dt desc) as rn
        from give_satisfy_hours
    ) tmp
    where rn = 1
)

,is_leader_info as (
    select distinct
        substr(dt,1,6) as dt_month
        ,store_manager_no
        ,if(length(store_manager_no)<8,concat('10',store_manager_no),store_manager_no) as staff_code
    from data_shop.dw_ordering_store_tag_location_ranking_info_v1_view t1
    where dt >= '20220801'
        -- and substr(dt,7,2) = '01'
        and t1.store_type = 0
)

-- ,uni_hours_info as (
    -- select 
       --  if(length(employee_no)<8,concat('10',employee_no),employee_no) as staff_code
        -- ,t0.position_tag
       --  ,sum(case when (date_format(work_shift_date,'yyyyMMdd') <= '20221201' 
            -- and date_format(work_shift_date,'yyyyMMdd') >= '20221008') --22寒假前
        -- then coalesce(work_shift_hours,0) end) as uni_time_hours_22winter
        -- ,sum(case when (date_format(work_shift_date,'yyyyMMdd') <= '20220601' 
            -- and date_format(work_shift_date,'yyyyMMdd') >= '20220301') --22暑假前
        -- then coalesce(work_shift_hours,0) end) as uni_time_hours_22summer
        -- ,sum(case when (date_format(work_shift_date,'yyyyMMdd') <= '20230601' 
        --     and date_format(work_shift_date,'yyyyMMdd') >= '20230228') --23暑假前
        -- then coalesce(work_shift_hours,0) end) as uni_time_hours_23summer
    -- from default.pdw_opc_shop_attendance_report_work_shift t1
    -- inner join name_bd_match t0
    -- on if(length(employee_no)<8,concat('10',employee_no),employee_no) = t0.staff_code
    -- where dt = '${today-1}' and work_shift_type in (1,9,12)
    -- group by employee_no
        -- ,t0.position_tag
-- )

select 
    t1.staff_code as staff_code
    ,t1.staff_name
    ,t1.city_name as city_name
    ,case when t0.code is not null then '学生PT' 
        when t1.position_cn <> '店经理' and t1.position_cn <> '学生PT' and t00.position_tag = '疑似学生' and t16.staff_code is null
--and (coalesce(t11.uni_time_hours_22winter,0) <100 and coalesce(t11.uni_time_hours_22summer,0) <100)
then '疑似学生PT' 
        else t1.position_cn end as position_cn
    ,t1.position as position
    ,coalesce(t1.protect_tag,t6.protect_tag,'9-无标签') as protect_tag
    ,t1.entry_date
    ,t1.dt_month as dt_month
    ,t2.leave_way
    ,t2.leave_reason
    ,t2.dimission_category_desc
    ,t2.leave_date
    ,t2.leave_dt
    ,coalesce(t3.work_shift_hours,t4.work_shift_hours) as t30_hours
    ,coalesce(t3.punish_rate_per_100_hour,t4.punish_rate_per_100_hour) as punish_rate_per_100_hour
    ,coalesce(t9.give_satisfy_rate,t8.give_satisfy_rate) as give_satisfy_rate
    ,t8.total_attend_days
    ,coalesce(t2.is_shop_leader,(case when t10.staff_code is not null then 1 else 0 end)) as is_shop_leader
from protect_tag_info t1
left join apply_leave_list t2
on t1.staff_code = t2.staff_code and t1.entry_date <= date_format(t2.leave_date,'yyyyMMdd')
left join t30_hours t3
on t1.staff_code = t3.staff_code and t2.leave_dt = t3.dt
left join latest_hours_per_month t4
on t1.staff_code = t4.staff_code and t1.dt_month = t4.dt_month
left join protect_tag_info_latest t6
on t1.staff_code = t6.staff_code
left join latest_give_satisfy_per_month t8
on t1.staff_code = t8.staff_code and t1.dt_month = t8.dt_month
left join give_satisfy_hours t9
on t1.staff_code = t9.staff_code and t2.leave_dt = t9.dt
left join data_shop.ods_uploads_student_pt t0
on t1.staff_code = t0.code
left join name_bd_match t00
on t1.staff_code = t00.staff_code and t00.position_tag = '疑似学生'
left join is_leader_info t10
on t1.staff_code = t10.staff_code and t1.dt_month = t10.dt_month
--left join uni_hours_info t11
--on t1.staff_code = t11.staff_code
left join data_shop.ods_uploads_student_suspect_remove t16
on t1.staff_code = t16.staff_code




















--新人留存率
with weekday_info as (  
    select  
        t1.date_key
		,date_format(t1.date_key,'yyyyMMdd') as dt_key
        ,date_sub(next_day(t1.date_key,'mon'),7) as date_week
    from data_build.dim_date_ya_v2 t1
    where t1.calendar_year in ('2023','2024','2025')
)

select 
    t1.code
    ,if(length(t1.code)<8,concat('10',t1.code),t1.code) as staff_code
    ,t1.position_name
    ,case 
        when t1.position_name = '学生PT' then '学生PT'
        when t1.position_name = '店经理' then '店经理'
        when t1.position_name = '社会PT' then '店员'
        when t1.position_name in ('门店伙伴','店员','见习店经理') then 
            if(round(datediff(date_format(t2.create_time,'yyyy-MM-dd'),t3.resume_birth_date)/365,0) <= 22,'疑似学生PT','店员')
    end as position_tag
    ,case when substr(hire_department_name,1,2) = '区X' then 1 else 0 end as is_district_staff
    ,date_format(t2.create_time,'yyyy-MM-dd') as entry_date
    ,date_format(t2.create_time,'yyyyMMdd') as entry_dt
    ,case 
        when final_work_class_tag like '%全天%' then if(final_work_class = 'day','白','夜')
        when final_work_class_tag like '%白%' then '白'
        when final_work_class_tag like '%夜%' then '夜'
    else 'NA' end as final_work_class_tag
    ,t1.plan_shop_code
    ,final_work_class
    ,if(length(t4.leave_dt)>2,'离职','在职') as job_status
    ,date_format(t4.leave_dt,'yyyy-MM-dd') as leave_date
    ,if(length(t4.leave_dt)<2 or t4.leave_dt is null
        ,datediff('${TODAY-1}',date_format(t2.create_time,'yyyy-MM-dd'))
        ,datediff(date_format(t4.leave_dt,'yyyy-MM-dd'),date_format(t2.create_time,'yyyy-MM-dd'))) as diff_days
    ,t0.date_week
    ,lpad(t5.manager_code,8,'10') as manager_code
    ,case when t6.hps_dept_descr_lv5 like '%区X%' or t6.hps_dept_descr_lv1 in ('运营管理部X') then '机动队'
          when t6.hps_d_jobcode in ('外部合作辅助人','外部合作经营者','外部合作伙伴','内部合作辅助人','内部合作经营者','内部合作伙伴') then '加盟'
          else '店经理' end as post_name
    ,t7.change_days --`成为本店架构负责人天数` 
from data_shop.pdw_gis_workday_entry_staff_position_view t1
left join data_shop.mid_gis_workday_entry_status_change_view t2
on t1.entry_id = t2.entry_id and t2.entry_state = 1
    and t2.dt = '${today-1}'
left join data_shop.dw_gis_hire_recruit_detail_v1_di_view t3
on t1.entry_id = t3.order_third_entry_id and t3.dt = '${today-1}'
left join data_sec_dw.pdw_psprod_ps_blf_ehr_pers_vw_view t4
on t1.code = t4.emplid and t4.dt = '${today-1}'
left join weekday_info t0
on date_format(t2.create_time,'yyyy-MM-dd') = t0.date_key
left join data_build.pdw_opc_shop_ehr_staff_dept_view t5 on t1.plan_shop_code = t5.dept_code and t5.dt = date_format(t2.create_time,'yyyyMMdd')
left join data_build.pdw_psprod_ps_blf_ehr_pers_vw_view t6 on lpad(t5.manager_code,8,'10') = lpad(t6.emplid,8,'10') and t6.dt = date_format(t2.create_time,'yyyyMMdd')
left join data_build.dwd_manager_tag_v1_di t7 on lpad(t5.manager_code,8,'10') = lpad(t7.employee_id,8,10) and t7.dt = date_format(t2.create_time,'yyyyMMdd')
where t1.dt = '${today-1}'
and t1.position_name in ('店经理', '门店伙伴', '店员', '社会PT', '学生PT', '见习店经理')
and t1.code is not null
and date_format(t2.create_time,'yyyyMMdd') >= '20230501'










select
t1.dt as record_dt
,t1.*
,case when t1.student_suspect = '1' and to_date(hps_hire_date) < '2025-05-01' then '疑似学生PT+早入职' else t1.student_suspect end as student_suspect_new
,case when t2.hps_d_jobcode = '学生PT' and to_date(hps_hire_date) < '2025-05-01' then '学生PT+早入职' else t2.hps_d_jobcode end as hps_d_jobcode
,t2.hps_sys_name
,t2.hps_dept_code_lv5
,t2.hps_dept_descr_lv5
,t7.hps_hire_date --真实入职日期
,case when t3.manager_code is not null and (t2.hps_dept_descr_lv5 not like '%区X%' or t2.hps_dept_descr_lv1 not in ('运营管理部X'))
and t2.hps_d_jobcode not in ('外部合作辅助人','外部合作经营者','外部合作伙伴','内部合作辅助人','内部合作经营者','内部合作伙伴') then '店经理'
when t2.hps_d_jobcode = '店副经理' then '店副经理'
when t4.employee_id is not null and (t2.hps_dept_descr_lv5 like '%区X%' or t2.hps_dept_descr_lv1 in ('运营管理部X')) then '机动队带店店长'
when t5.employee_no is not null and (t2.hps_dept_descr_lv5 like '%区X%' or t2.hps_dept_descr_lv1 in ('运营管理部X'))  then t5.relation_type
when t2.hps_dept_descr_lv5 like '%区X%' or t2.hps_dept_descr_lv1 in ('运营管理部X') then '机动队队员'
when t2.hps_d_jobcode not in ('外部合作辅助人','外部合作经营者','外部合作伙伴','内部合作辅助人','内部合作经营者','内部合作伙伴') then '店员'
else '加盟人员' end as post_name
from data_shop.dm_shop_staff_protect_tag_v2 t1
left join data_build.pdw_psprod_ps_blf_ehr_pers_vw_view t2 on t1.staff_code = lpad(t2.emplid,8,'10') and t2.dt = t1.dt --hps_d_jobcode in ('店副经理')
left join data_build.pdw_opc_shop_ehr_staff_dept_view t3 on t2.hps_dept_code_lv5 = t3.dept_code and lpad(t2.emplid,8,'10') = lpad(t3.manager_code,8,'10') and t3.dt = t1.dt --店长
left join data_build.dwd_store_construction_district_manager_base_info0_di t4 on t1.staff_code = t4.employee_id
and t4.dt = '${today-2}'
left join (select
* from(
select 
employee_no,
shop_code,
relation_type,
dt,
row_number() over(partition by employee_no order by create_time desc) as rn
from data_smartorder.dm_copy_pdw_opc_roster_motor_shop_relation_view
where dt = '${today-1}'
and delete_ts = 0
and end_date >= to_date(from_unixtime(unix_timestamp(dt,'yyyyMMdd')))
) a
where rn = 1
) t5 on t1.staff_code = lpad(t5.employee_no,8,'10') --带店机动队(店长/店副/陪跑店长/陪跑店副)
and t1.dt = t5.dt
left join data_smartorder.ods_uploads_business_district_qiyang t6 on t1.store_code = t6.store_code
left join raw_list t7 on t1.staff_code = lpad(t7.employee_id,8,'10') and t1.dt = t7.dt
where t1.dt = '${today-1}'






select
t1.staff_code
,t1.entry_date
,sum(work_shift_hours) as work_shift_hours --排班小时数
,sum(attendance_work_hours) as attendance_work_hours --出勤小时数
,sum(absenteeism_hours) as absenteeism_hours --旷工小时数

,sum(case when store_code = dept_code then work_shift_hours else 0 end) as dept_work_shift_hours --本店排班小时数
,sum(case when store_code = dept_code then attendance_work_hours else 0 end) as dept_attendance_work_hours --本店出勤小时数
,sum(case when store_code = dept_code then absenteeism_hours else 0 end) as dept_absenteeism_hours --本店旷工小时数

,sum(case when store_code <> dept_code then work_shift_hours else 0 end) as other_work_shift_hours --跨店排班小时数
,sum(case when store_code <> dept_code then attendance_work_hours else 0 end) as other_attendance_work_hours --跨店出勤小时数
,sum(case when store_code <> dept_code then absenteeism_hours else 0 end) as other_absenteeism_hours --跨店旷工小时数

from
data_build.ods_uploads_tmp_0821 t1
left join data_shop.pdw_opc_shop_attendance_report_work_shift_view t2
on t1.staff_code = lpad(t2.employee_no,8,10)
and t2.work_shift_date between date_add(t1.entry_date,1) and date_add(t1.entry_date,7)
and t2.dt = 20250825
group by
t1.staff_code
,t1.entry_date




--入职后7天给班情况
select
t1.staff_code
,t1.entry_date
,count(1) as give_days
from
data_build.ods_uploads_tmp_0821 t1
left join data_smartorder.dw_roster_give_roster_detail_snapshot_da t2
on t1.staff_code = lpad(t2.employee_no,8,10)
and t2.roster_date between date_add(t1.entry_date,1) and date_add(t1.entry_date,7)
and t2.dt = 20250825
and t2.givetype in ('全天可开工','夜晚可开工','白天可开工')
group by
t1.staff_code
,t1.entry_date








--机动队t30提离职率(新增归属TL)
with supply_detail as
(
select 
* 
,from_unixtime(unix_timestamp(dt,'yyyymmdd'),'yyyy-mm-dd') as record_date
from 
data_build.dwd_store_construction_roster_staff_supply_v1_di
where dt >= '20220601'
)


,apply_leave_info as (
    select distinct
        t1.dept_code --门店code
        ,t1.man_code --工号
        ,if(length(t1.man_code)<8,concat('10',t1.man_code),t1.man_code) as staff_code
        ,t1.job --岗位
        ,date_format(create_time,'yyyyMMdd') as apply_dt
        ,date_format(create_time,'yyyy-MM-dd') as apply_date
        ,date_format(date_sub(create_time,1),'yyyyMMdd') as apply_dt_t1
        ,substr(position_class,1,1) as origin_tag
        ,coalesce(substr(position_class,1,1),'新') as new_old_tag
        ,coalesce(t2.protect_tag,'待观察') as protect_tag
        ,case when t3.hps_dept_descr_lv5 like '%区X%' then 1 else 0 end as is_district_staff
        ,hps_d_supvs_name --机动队组长
        ,t5.chuqin_label as chuqin_label
        ,t4.key_staff_type
        ,t6.protect_tag_detail_new as district_staff_protect_tag
    from data_shop.pdw_gis_workday_dimission_order_view t1
    left join data_shop.dm_shop_staff_protect_tag_v2 t2
    on t2.dt >= '20220630' 
        and date_format(date_sub(create_time,1),'yyyyMMdd') = t2.dt
        and if(length(t1.man_code)<8,concat('10',t1.man_code),t1.man_code) = t2.staff_code
    left join supply_detail t5
    on date_format(date_sub(create_time,1),'yyyy-MM-dd') = t5.record_date
    and if(length(t1.man_code)<8,concat('10',t1.man_code),t1.man_code) = t5.employee_id
    left join data_build.pdw_psprod_ps_blf_ehr_pers_vw_view t3 on if(length(t1.man_code)<8,concat('10',t1.man_code),t1.man_code) = if(length(t3.emplid)<8,concat('10',t3.emplid),t3.emplid) and t3.dt ='${today-1}' 
    left join data_build.dwd_store_construction_roster_staff_supply_v1_di t4 on if(length(t1.man_code)<8,concat('10',t1.man_code),t1.man_code) = t4.employee_id
    left join data_build.dwd_dwd_district_staff_protect_tag_v2_da_di t6 on if(length(t1.man_code)<8,concat('10',t1.man_code),t1.man_code) = t6.staff_code and t1.dt=t6.dt
    where t1.dt = '${today-1}' 
        and t1.job in ('店经理', '门店伙伴', '店员','社会PT','店副经理', '学生PT', '见习店经理')
        and date_format(create_time,'yyyyMMdd') >= '20220701'
        and t3.hps_dept_descr_lv5 like '%区X%'
        --and final_leave = 'leave'
)



,leave_cnts_info as (
    select 
        apply_dt
        ,hps_d_supvs_name
        ,count(distinct staff_code) as leave_cnts
        ,count(distinct case when job = '店经理' then staff_code end) as manager_cnts
        ,count(distinct case when job = '店副经理' then staff_code end) as sec_manager_cnts
        ,count(distinct case when is_district_staff = 1 then staff_code end) as district_staff_cnts
        ,count(distinct case when is_district_staff = 1 and new_old_tag = '老' then staff_code end) as old_district_staff_cnts
        ,count(distinct case when is_district_staff = 1 and new_old_tag = '新' then staff_code end) as new_district_staff_cnts
        ,count(distinct case when is_district_staff = 1 and protect_tag in ('应保护','金牌','普通','银牌') then staff_code end) as good_district_staff_cnts--新增了这个
        ,count(distinct case when is_district_staff = 1 and district_staff_protect_tag = 0 then staff_code end) as diamond_district_staff_cnts
        ,count(distinct case when is_district_staff = 0 and job not in ('店经理','店副经理') then staff_code end) as staff_cnts
        ,count(distinct case when is_district_staff = 0 and job not in ('店经理','店副经理') and new_old_tag = '老' and chuqin_label = '长夜型员工' then staff_code end) as night_staff_cnts
        ,count(distinct case when is_district_staff = 0 and job not in ('店经理','店副经理') and new_old_tag = '老' then staff_code end) as old_staff_cnts
        ,count(distinct case when is_district_staff = 0 and job not in ('店经理','店副经理') and new_old_tag = '新' then staff_code end) as new_staff_cnts
        ,count(distinct case when is_district_staff = 0 and job not in ('店经理','店副经理') and new_old_tag = '老' and protect_tag in ('应保护','金牌') then staff_code end) as old_staff_cnts_1
        ,count(distinct case when is_district_staff = 0 and job not in ('店经理','店副经理') and new_old_tag = '老' and protect_tag in ('普通','银牌') then staff_code end) as old_staff_cnts_2
        ,count(distinct case when is_district_staff = 0 and job not in ('店经理','店副经理') and new_old_tag = '老' and protect_tag in ('末位普通','须努力') then staff_code end) as old_staff_cnts_4
        ,count(distinct case when is_district_staff = 0 and job not in ('店经理','店副经理') and new_old_tag = '老' and protect_tag in ('应离职','不合格') then staff_code end) as old_staff_cnts_5
        ,count(distinct case when is_district_staff = 0 and job not in ('店经理','店副经理') and key_staff_type = 'key_staff' then staff_code end) as key_staff_cnts
    from apply_leave_info t1
    left join data_shop.pdw_idss_ipes_admin_employee_blacklist_view t2
    on t2.dt >= '20220601' and t1.staff_code = lpad(t2.employee_no,8,'10') and t1.apply_dt_t1 = t2.dt and valid_status='1' and start_date<=apply_date and end_date>=apply_date
    where t2.employee_no is null
    group by apply_dt
    ,hps_d_supvs_name
)

,ppl_cnts_info as (
    select 
        t1.dt
        ,hps_d_supvs_name
        ,date_format(date_add(to_date(from_unixtime(unix_timestamp(t1.dt,'yyyyMMdd'))),30),'yyyyMMdd') as dt_add_30_days
        ,count(distinct t1.staff_code) as ppl_cnts
        ,count(distinct case when t1.position_cn = '店经理' then t1.staff_code end) as manager_cnts
        ,count(distinct case when t1.position_cn = '店副经理' then t1.staff_code end) as sec_manager_cnts
        ,count(distinct case when t3.hps_dept_descr_lv5 like '%区X%' then t1.staff_code end) as district_staff_cnts
        ,count(distinct case when t3.hps_dept_descr_lv5 like '%区X%' and substr(t1.position_class,1,1) = '老' then t1.staff_code end) as old_district_staff_cnts
        ,count(distinct case when t3.hps_dept_descr_lv5 like '%区X%' and substr(t1.position_class,1,1) = '新' then t1.staff_code end) as new_district_staff_cnts
        ,count(distinct case when t3.hps_dept_descr_lv5 like '%区X%' and t1.protect_tag in  ('应保护','金牌','普通','银牌') then t1.staff_code end) as good_district_staff_cnts--新增了这个
        ,count(distinct case when t3.hps_dept_descr_lv5 like '%区X%' and t5.protect_tag_detail_new = 0  then t1.staff_code end) as diamond_district_staff_cnts
        ,count(distinct case when t3.hps_dept_descr_lv5 not like '%区X%' and t1.position_cn not in ('店经理','店副经理') then t1.staff_code end) as staff_cnts
        ,count(distinct case when t3.hps_dept_descr_lv5 not like '%区X%' and substr(t1.position_class,1,1) = '老' and t1.position_cn not in ('店经理','店副经理') then t1.staff_code end) as old_staff_cnts
        ,count(distinct case when t3.hps_dept_descr_lv5 not like '%区X%' and substr(t1.position_class,1,1) = '老' and t1.position_cn not in ('店经理','店副经理') and t2.chuqin_label = '长夜型员工' then t1.staff_code end) as night_staff_cnts
        ,count(distinct case when t3.hps_dept_descr_lv5 not like '%区X%' and substr(t1.position_class,1,1) = '新' and t1.position_cn not in ('店经理','店副经理') then t1.staff_code end) as new_staff_cnts
        ,count(distinct case when t3.hps_dept_descr_lv5 not like '%区X%' and substr(t1.position_class,1,1) = '老' and t1.position_cn not in ('店经理','店副经理') and t1.protect_tag in ('应保护','金牌') then t1.staff_code end) as old_staff_cnts_1
        ,count(distinct case when t3.hps_dept_descr_lv5 not like '%区X%' and substr(t1.position_class,1,1) = '老' and t1.position_cn not in ('店经理','店副经理') and t1.protect_tag in ('普通','银牌') then t1.staff_code end) as old_staff_cnts_2
        ,count(distinct case when t3.hps_dept_descr_lv5 not like '%区X%' and substr(t1.position_class,1,1) = '老' and t1.position_cn not in ('店经理','店副经理') and t1.protect_tag in ('末位普通','须努力') then t1.staff_code end) as old_staff_cnts_4
        ,count(distinct case when t3.hps_dept_descr_lv5 not like '%区X%' and substr(t1.position_class,1,1) = '老' and t1.position_cn not in ('店经理','店副经理') and t1.protect_tag in ('应离职','不合格') then t1.staff_code end) as old_staff_cnts_5
        ,count(distinct case when t3.hps_dept_descr_lv5 not like '%区X%' and t1.position_cn not in ('店经理','店副经理') and t4.key_staff_type = 'key_staff' then t1.staff_code end) as key_staff_cnts
    from data_shop.dm_shop_staff_protect_tag_v2 t1
    left join supply_detail t2 on t1.staff_code = t2.employee_id and from_unixtime(unix_timestamp(t1.dt,'yyyymmdd'),'yyyy-mm-dd') = t2.record_date
    left join data_build.pdw_psprod_ps_blf_ehr_pers_vw_view t3 on t1.staff_code = if(length(t3.emplid)<8,concat('10',t3.emplid),t3.emplid) and t3.dt ='${today-1}' 
    left join data_build.dwd_store_construction_roster_staff_supply_v1_di t4 on t1.staff_code = t4.employee_id
    left join data_build.dwd_dwd_district_staff_protect_tag_v2_da_di t5 on t1.staff_code = t5.staff_code  and t1.dt=t5.dt
    where t1.dt >= '20220701'
    and t3.hps_dept_descr_lv5 like '%区X%'
    group by t1.dt
    ,hps_d_supvs_name
)

,prep_info as (
    select 
        t1.dt
        ,t1.dt_add_30_days
        ,t1.hps_d_supvs_name
        ,t1.ppl_cnts as start_ppl_cnts
        ,t2.ppl_cnts as end_ppl_cnts
        ,t1.manager_cnts as start_manager_cnts
        ,t2.manager_cnts as end_manager_cnts
        ,t1.sec_manager_cnts as start_sec_manager_cnts
        ,t2.sec_manager_cnts as end_sec_manager_cnts
        ,t1.district_staff_cnts as start_district_staff_cnts
        ,t2.district_staff_cnts as end_district_staff_cnts
        ,t1.night_staff_cnts as start_night_staff_cnts
        ,t2.night_staff_cnts as end_night_staff_cnts
        ,t1.old_district_staff_cnts as start_old_district_staff_cnts
        ,t2.old_district_staff_cnts as end_old_district_staff_cnts
        ,t1.new_district_staff_cnts as start_new_district_staff_cnts
        ,t2.new_district_staff_cnts as end_new_district_staff_cnts
        ,t1.good_district_staff_cnts as start_good_district_staff_cnts --新增了这个20240401
        ,t2.good_district_staff_cnts as end_good_district_staff_cnts --新增了这个20240401
        ,t2.diamond_district_staff_cnts as start_diamond_district_staff_cnts
        ,t2.diamond_district_staff_cnts as end_diamond_district_staff_cnts
        ,t1.staff_cnts as start_staff_cnts
        ,t2.staff_cnts as end_staff_cnts
        ,t1.old_staff_cnts as start_old_staff_cnts
        ,t2.old_staff_cnts as end_old_staff_cnts
        ,t1.new_staff_cnts as start_new_staff_cnts
        ,t2.new_staff_cnts as end_new_staff_cnts

        ,t1.old_staff_cnts_1 as start_old_staff_cnts_1
        ,t2.old_staff_cnts_1 as end_old_staff_cnts_1
        ,t1.old_staff_cnts_2 as start_old_staff_cnts_2
        ,t2.old_staff_cnts_2 as end_old_staff_cnts_2
        ,t1.old_staff_cnts_4 as start_old_staff_cnts_4
        ,t2.old_staff_cnts_4 as end_old_staff_cnts_4
        ,t1.old_staff_cnts_5 as start_old_staff_cnts_5
        ,t2.old_staff_cnts_5 as end_old_staff_cnts_5
        ,t1.key_staff_cnts as start_key_staff_cnts
        ,t2.key_staff_cnts as end_key_staff_cnts

        ,t3.apply_dt
        ,t3.leave_cnts
        ,t3.manager_cnts
        ,t3.sec_manager_cnts
        ,t3.district_staff_cnts
        ,t3.old_district_staff_cnts
        ,t3.new_district_staff_cnts
        ,t3.good_district_staff_cnts --20240401新增
        ,t3.diamond_district_staff_cnts
        ,t3.staff_cnts
        ,t3.old_staff_cnts
        ,t3.night_staff_cnts
        ,t3.new_staff_cnts
        ,t3.old_staff_cnts_1
        ,t3.old_staff_cnts_2
        ,t3.old_staff_cnts_4
        ,t3.old_staff_cnts_5
        ,t3.key_staff_cnts
    from ppl_cnts_info t1
    inner join ppl_cnts_info t2
    on t1.dt_add_30_days = t2.dt and t1.dt_add_30_days <= '${today}' and t1.hps_d_supvs_name = t2.hps_d_supvs_name
    left join leave_cnts_info t3
    on t3.apply_dt>=t1.dt and t3.apply_dt<t1.dt_add_30_days and t1.hps_d_supvs_name = t3.hps_d_supvs_name
)

,raw_list as(
select 
    t1.dt
    ,t1.dt_add_30_days
    ,t1.hps_d_supvs_name
    ,(start_ppl_cnts+end_ppl_cnts)/2 as ppl_cnts
    ,(start_manager_cnts+end_manager_cnts)/2 as manager_cnts
    ,(start_sec_manager_cnts+end_sec_manager_cnts)/2 as sec_manager_cnts
    ,(start_old_district_staff_cnts+end_old_district_staff_cnts)/2 as old_district_staff_cnts
    ,(start_new_district_staff_cnts+end_new_district_staff_cnts)/2 as new_district_staff_cnts
    ,(start_good_district_staff_cnts+end_good_district_staff_cnts)/2 as good_district_staff_cnts --20240401新增
    ,(start_district_staff_cnts+end_district_staff_cnts)/2 as district_staff_cnts
    ,(start_diamond_district_staff_cnts+end_diamond_district_staff_cnts)/2 as diamond_district_staff_cnts

    ,(start_staff_cnts+end_staff_cnts)/2 as staff_cnts
    ,(start_night_staff_cnts+end_night_staff_cnts)/2 as night_staff_cnts

    ,(start_old_staff_cnts+end_old_staff_cnts)/2 as old_staff_cnts
    ,(start_new_staff_cnts+end_new_staff_cnts)/2 as new_staff_cnts

    ,(start_old_staff_cnts_1+end_old_staff_cnts_1)/2 as old_staff_cnts_1
    ,(start_old_staff_cnts_2+end_old_staff_cnts_2)/2 as old_staff_cnts_2
    ,(start_old_staff_cnts_4+end_old_staff_cnts_4)/2 as old_staff_cnts_4
    ,(start_old_staff_cnts_5+end_old_staff_cnts_5)/2 as old_staff_cnts_5
    ,(start_key_staff_cnts+end_key_staff_cnts)/2 as key_staff_cnts

    ,sum(leave_cnts) as leave_cnts
    ,sum(manager_cnts) as leave_manager_cnts
    ,sum(sec_manager_cnts) as leave_sec_manager_cnts
    ,sum(district_staff_cnts) as leave_district_staff_cnts
    ,sum(old_district_staff_cnts) as leave_old_district_staff_cnts
    ,sum(new_district_staff_cnts) as leave_new_district_staff_cnts
    ,sum(good_district_staff_cnts) as leave_good_district_staff_cnts --20240401新增
    ,sum(diamond_district_staff_cnts) as leave_diamond_district_staff_cnts
    ,sum(staff_cnts) as leave_staff_cnts
    ,sum(night_staff_cnts) as leave_night_staff_cnts
    ,sum(old_staff_cnts) as leave_old_staff_cnts
    ,sum(new_staff_cnts) as leave_new_staff_cnts

    ,sum(old_staff_cnts_1) as leave_old_staff_cnts_1
    ,sum(old_staff_cnts_2) as leave_old_staff_cnts_2
    ,sum(old_staff_cnts_4) as leave_old_staff_cnts_4
    ,sum(old_staff_cnts_5) as leave_old_staff_cnts_5
    ,sum(key_staff_cnts) as leave_key_staff_cnts

from prep_info t1
group by t1.dt
    ,t1.dt_add_30_days
    ,t1.hps_d_supvs_name
    ,t1.start_ppl_cnts
    ,t1.end_ppl_cnts
    ,t1.start_manager_cnts
    ,t1.end_manager_cnts
    ,t1.start_sec_manager_cnts
    ,t1.end_sec_manager_cnts
    ,t1.start_district_staff_cnts
    ,t1.end_district_staff_cnts
    ,t1.start_old_district_staff_cnts
    ,t1.start_new_district_staff_cnts
    ,t1.end_old_district_staff_cnts
    ,t1.end_new_district_staff_cnts
    ,t1.start_good_district_staff_cnts --20240401新增
    ,t1.end_good_district_staff_cnts --20240401新增
    ,t1.start_diamond_district_staff_cnts
    ,t1.end_diamond_district_staff_cnts
    ,t1.start_staff_cnts
    ,t1.end_staff_cnts
    ,t1.start_night_staff_cnts
    ,t1.end_night_staff_cnts
    ,t1.start_old_staff_cnts
    ,t1.end_old_staff_cnts
    ,t1.start_new_staff_cnts
    ,t1.end_new_staff_cnts
    ,t1.start_old_staff_cnts_1
    ,t1.end_old_staff_cnts_1
    ,t1.start_old_staff_cnts_2
    ,t1.end_old_staff_cnts_2
    ,t1.start_old_staff_cnts_4
    ,t1.end_old_staff_cnts_4
    ,t1.start_old_staff_cnts_5
    ,t1.end_old_staff_cnts_5
    ,t1.start_key_staff_cnts
    ,t1.end_key_staff_cnts
)

,raw_list_1 as(
select
dt
,hps_d_supvs_name
,leave_district_staff_cnts/district_staff_cnts as district_staff_rate
from raw_list
)

,string_intermediate AS(
SELECT
  dt,
  CONCAT_WS(',', COLLECT_SET(CONCAT(hps_d_supvs_name, ':', district_staff_rate))) AS name_value_pairs
FROM raw_list_1
GROUP BY dt
)

-- 然后使用STR_TO_MAP和LATERAL VIEW展开
SELECT
  dt,
  hps_d_supvs_name,
  district_staff_rate
FROM string_intermediate
LATERAL VIEW EXPLODE(STR_TO_MAP(name_value_pairs, ',', ':')) exploded AS hps_d_supvs_name, district_staff_rate




--t30离职率(原报表)
begin
    with supply_detail as
    (
    select 
    * 
    ,from_unixtime(unix_timestamp(dt,'yyyymmdd'),'yyyy-mm-dd') as record_date
    from 
    data_build.dwd_store_construction_roster_staff_supply_v1_di
    where dt >= '20220601'
    )


    ,apply_leave_info as (
        select distinct
            t1.dept_code --门店code
            ,t1.man_code --工号
            ,if(length(t1.man_code)<8,concat('10',t1.man_code),t1.man_code) as staff_code
            ,t1.job --岗位
            ,date_format(create_time,'yyyyMMdd') as apply_dt
            ,date_format(create_time,'yyyy-MM-dd') as apply_date
            ,date_format(date_sub(create_time,1),'yyyyMMdd') as apply_dt_t1
            ,substr(position_class,1,1) as origin_tag
            ,coalesce(substr(position_class,1,1),'新') as new_old_tag
            ,coalesce(t2.protect_tag,'待观察') as protect_tag
            ,case when t3.hps_dept_descr_lv5 like '%区X%' then 1 else 0 end as is_district_staff
            ,t5.chuqin_label as chuqin_label
            ,t4.key_staff_type
            ,t6.protect_tag_detail_new as district_staff_protect_tag
        from data_shop.pdw_gis_workday_dimission_order_view t1
        left join data_shop.dm_shop_staff_protect_tag_v2 t2
        on t2.dt >= '20220630' 
            and date_format(date_sub(create_time,1),'yyyyMMdd') = t2.dt
            and if(length(t1.man_code)<8,concat('10',t1.man_code),t1.man_code) = t2.staff_code
        left join supply_detail t5
        on date_format(date_sub(create_time,1),'yyyy-MM-dd') = t5.record_date
        and if(length(t1.man_code)<8,concat('10',t1.man_code),t1.man_code) = t5.employee_id
        left join data_build.pdw_psprod_ps_blf_ehr_pers_vw_view t3 on if(length(t1.man_code)<8,concat('10',t1.man_code),t1.man_code) = if(length(t3.emplid)<8,concat('10',t3.emplid),t3.emplid) and t3.dt ='${today-1}' 
        left join data_build.dwd_store_construction_roster_staff_supply_v1_di t4 on if(length(t1.man_code)<8,concat('10',t1.man_code),t1.man_code) = t4.employee_id
        left join data_build.dwd_dwd_district_staff_protect_tag_v2_da_di t6 on if(length(t1.man_code)<8,concat('10',t1.man_code),t1.man_code) = t6.staff_code and t1.dt=t6.dt
        where t1.dt = '${today-1}' 
            and t1.job in ('店经理', '门店伙伴', '店员','社会PT','店副经理', '学生PT', '见习店经理')
            and date_format(create_time,'yyyyMMdd') >= '20220701'
            and final_leave = 'leave'
    )



    ,leave_cnts_info as (
        select 
            apply_dt
            ,count(distinct staff_code) as leave_cnts
            ,count(distinct case when job = '店经理' then staff_code end) as manager_cnts
            ,count(distinct case when job = '店副经理' then staff_code end) as sec_manager_cnts
            ,count(distinct case when is_district_staff = 1 then staff_code end) as district_staff_cnts
            ,count(distinct case when is_district_staff = 1 and new_old_tag = '老' then staff_code end) as old_district_staff_cnts
            ,count(distinct case when is_district_staff = 1 and new_old_tag = '新' then staff_code end) as new_district_staff_cnts
            ,count(distinct case when is_district_staff = 1 and protect_tag in ('应保护','金牌','普通','银牌') then staff_code end) as good_district_staff_cnts--新增了这个
            ,count(distinct case when is_district_staff = 1 and district_staff_protect_tag = 0 then staff_code end) as diamond_district_staff_cnts
            ,count(distinct case when is_district_staff = 0 and job not in ('店经理','店副经理') then staff_code end) as staff_cnts
            ,count(distinct case when is_district_staff = 0 and job not in ('店经理','店副经理') and new_old_tag = '老' and chuqin_label = '长夜型员工' then staff_code end) as night_staff_cnts
            ,count(distinct case when is_district_staff = 0 and job not in ('店经理','店副经理') and new_old_tag = '老' then staff_code end) as old_staff_cnts
            ,count(distinct case when is_district_staff = 0 and job not in ('店经理','店副经理') and new_old_tag = '新' then staff_code end) as new_staff_cnts
            ,count(distinct case when is_district_staff = 0 and job not in ('店经理','店副经理') and new_old_tag = '老' and protect_tag in ('应保护','金牌') then staff_code end) as old_staff_cnts_1
            ,count(distinct case when is_district_staff = 0 and job not in ('店经理','店副经理') and new_old_tag = '老' and protect_tag in ('普通','银牌') then staff_code end) as old_staff_cnts_2
            ,count(distinct case when is_district_staff = 0 and job not in ('店经理','店副经理') and new_old_tag = '老' and protect_tag in ('末位普通','须努力') then staff_code end) as old_staff_cnts_4
            ,count(distinct case when is_district_staff = 0 and job not in ('店经理','店副经理') and new_old_tag = '老' and protect_tag in ('应离职','不合格') then staff_code end) as old_staff_cnts_5
            ,count(distinct case when is_district_staff = 0 and job not in ('店经理','店副经理') and key_staff_type = 'key_staff' then staff_code end) as key_staff_cnts
        from apply_leave_info t1
        left join data_shop.pdw_idss_ipes_admin_employee_blacklist_view t2
        on t2.dt >= '20220601' and t1.staff_code = lpad(t2.employee_no,8,'10') and t1.apply_dt_t1 = t2.dt and valid_status='1' and start_date<=apply_date and end_date>=apply_date
        where t2.employee_no is null
        group by apply_dt
    )

    ,ppl_cnts_info as (
        select 
            t1.dt
            ,date_format(date_add(to_date(from_unixtime(unix_timestamp(t1.dt,'yyyyMMdd'))),30),'yyyyMMdd') as dt_add_30_days
            ,count(distinct t1.staff_code) as ppl_cnts
            ,count(distinct case when t1.position_cn = '店经理' then t1.staff_code end) as manager_cnts
            ,count(distinct case when t1.position_cn = '店副经理' then t1.staff_code end) as sec_manager_cnts
            ,count(distinct case when t3.hps_dept_descr_lv5 like '%区X%' then t1.staff_code end) as district_staff_cnts
            ,count(distinct case when t3.hps_dept_descr_lv5 like '%区X%' and substr(t1.position_class,1,1) = '老' then t1.staff_code end) as old_district_staff_cnts
            ,count(distinct case when t3.hps_dept_descr_lv5 like '%区X%' and substr(t1.position_class,1,1) = '新' then t1.staff_code end) as new_district_staff_cnts
            ,count(distinct case when t3.hps_dept_descr_lv5 like '%区X%' and t1.protect_tag in  ('应保护','金牌','普通','银牌') then t1.staff_code end) as good_district_staff_cnts--新增了这个
            ,count(distinct case when t3.hps_dept_descr_lv5 like '%区X%' and t5.protect_tag_detail_new = 0  then t1.staff_code end) as diamond_district_staff_cnts
            ,count(distinct case when t3.hps_dept_descr_lv5 not like '%区X%' and t1.position_cn not in ('店经理','店副经理') then t1.staff_code end) as staff_cnts
            ,count(distinct case when t3.hps_dept_descr_lv5 not like '%区X%' and substr(t1.position_class,1,1) = '老' and t1.position_cn not in ('店经理','店副经理') then t1.staff_code end) as old_staff_cnts
            ,count(distinct case when t3.hps_dept_descr_lv5 not like '%区X%' and substr(t1.position_class,1,1) = '老' and t1.position_cn not in ('店经理','店副经理') and t2.chuqin_label = '长夜型员工' then t1.staff_code end) as night_staff_cnts
            ,count(distinct case when t3.hps_dept_descr_lv5 not like '%区X%' and substr(t1.position_class,1,1) = '新' and t1.position_cn not in ('店经理','店副经理') then t1.staff_code end) as new_staff_cnts
            ,count(distinct case when t3.hps_dept_descr_lv5 not like '%区X%' and substr(t1.position_class,1,1) = '老' and t1.position_cn not in ('店经理','店副经理') and t1.protect_tag in ('应保护','金牌') then t1.staff_code end) as old_staff_cnts_1
            ,count(distinct case when t3.hps_dept_descr_lv5 not like '%区X%' and substr(t1.position_class,1,1) = '老' and t1.position_cn not in ('店经理','店副经理') and t1.protect_tag in ('普通','银牌') then t1.staff_code end) as old_staff_cnts_2
            ,count(distinct case when t3.hps_dept_descr_lv5 not like '%区X%' and substr(t1.position_class,1,1) = '老' and t1.position_cn not in ('店经理','店副经理') and t1.protect_tag in ('末位普通','须努力') then t1.staff_code end) as old_staff_cnts_4
            ,count(distinct case when t3.hps_dept_descr_lv5 not like '%区X%' and substr(t1.position_class,1,1) = '老' and t1.position_cn not in ('店经理','店副经理') and t1.protect_tag in ('应离职','不合格') then t1.staff_code end) as old_staff_cnts_5
            ,count(distinct case when t3.hps_dept_descr_lv5 not like '%区X%' and t1.position_cn not in ('店经理','店副经理') and t4.key_staff_type = 'key_staff' then t1.staff_code end) as key_staff_cnts
        from data_shop.dm_shop_staff_protect_tag_v2 t1
        left join supply_detail t2 on t1.staff_code = t2.employee_id and from_unixtime(unix_timestamp(t1.dt,'yyyymmdd'),'yyyy-mm-dd') = t2.record_date
        left join data_build.pdw_psprod_ps_blf_ehr_pers_vw_view t3 on t1.staff_code = if(length(t3.emplid)<8,concat('10',t3.emplid),t3.emplid) and t3.dt ='${today-1}' 
        left join data_build.dwd_store_construction_roster_staff_supply_v1_di t4 on t1.staff_code = t4.employee_id
        left join data_build.dwd_dwd_district_staff_protect_tag_v2_da_di t5 on t1.staff_code = t5.staff_code  and t1.dt=t5.dt
        where t1.dt >= '20220701'
        group by t1.dt
    )

    ,prep_info as (
        select 
            t1.dt
            ,t1.dt_add_30_days
            ,t1.ppl_cnts as start_ppl_cnts
            ,t2.ppl_cnts as end_ppl_cnts
            ,t1.manager_cnts as start_manager_cnts
            ,t2.manager_cnts as end_manager_cnts
            ,t1.sec_manager_cnts as start_sec_manager_cnts
            ,t2.sec_manager_cnts as end_sec_manager_cnts
            ,t1.district_staff_cnts as start_district_staff_cnts
            ,t2.district_staff_cnts as end_district_staff_cnts
            ,t1.night_staff_cnts as start_night_staff_cnts
            ,t2.night_staff_cnts as end_night_staff_cnts
            ,t1.old_district_staff_cnts as start_old_district_staff_cnts
            ,t2.old_district_staff_cnts as end_old_district_staff_cnts
            ,t1.new_district_staff_cnts as start_new_district_staff_cnts
            ,t2.new_district_staff_cnts as end_new_district_staff_cnts
            ,t1.good_district_staff_cnts as start_good_district_staff_cnts --新增了这个20240401
            ,t2.good_district_staff_cnts as end_good_district_staff_cnts --新增了这个20240401
            ,t2.diamond_district_staff_cnts as start_diamond_district_staff_cnts
            ,t2.diamond_district_staff_cnts as end_diamond_district_staff_cnts
            ,t1.staff_cnts as start_staff_cnts
            ,t2.staff_cnts as end_staff_cnts
            ,t1.old_staff_cnts as start_old_staff_cnts
            ,t2.old_staff_cnts as end_old_staff_cnts
            ,t1.new_staff_cnts as start_new_staff_cnts
            ,t2.new_staff_cnts as end_new_staff_cnts

            ,t1.old_staff_cnts_1 as start_old_staff_cnts_1
            ,t2.old_staff_cnts_1 as end_old_staff_cnts_1
            ,t1.old_staff_cnts_2 as start_old_staff_cnts_2
            ,t2.old_staff_cnts_2 as end_old_staff_cnts_2
            ,t1.old_staff_cnts_4 as start_old_staff_cnts_4
            ,t2.old_staff_cnts_4 as end_old_staff_cnts_4
            ,t1.old_staff_cnts_5 as start_old_staff_cnts_5
            ,t2.old_staff_cnts_5 as end_old_staff_cnts_5
            ,t1.key_staff_cnts as start_key_staff_cnts
            ,t2.key_staff_cnts as end_key_staff_cnts

            ,t3.apply_dt
            ,t3.leave_cnts
            ,t3.manager_cnts
            ,t3.sec_manager_cnts
            ,t3.district_staff_cnts
            ,t3.old_district_staff_cnts
            ,t3.new_district_staff_cnts
            ,t3.good_district_staff_cnts --20240401新增
            ,t3.diamond_district_staff_cnts
            ,t3.staff_cnts
            ,t3.old_staff_cnts
            ,t3.night_staff_cnts
            ,t3.new_staff_cnts
            ,t3.old_staff_cnts_1
            ,t3.old_staff_cnts_2
            ,t3.old_staff_cnts_4
            ,t3.old_staff_cnts_5
            ,t3.key_staff_cnts
        from ppl_cnts_info t1
        inner join ppl_cnts_info t2
        on t1.dt_add_30_days = t2.dt and t1.dt_add_30_days <= '${today}'
        left join leave_cnts_info t3
        on t3.apply_dt>=t1.dt and t3.apply_dt<t1.dt_add_30_days
    )

    select 
        t1.dt
        ,t1.dt_add_30_days
        ,(start_ppl_cnts+end_ppl_cnts)/2 as ppl_cnts
        ,(start_manager_cnts+end_manager_cnts)/2 as manager_cnts
        ,(start_sec_manager_cnts+end_sec_manager_cnts)/2 as sec_manager_cnts
        ,(start_old_district_staff_cnts+end_old_district_staff_cnts)/2 as old_district_staff_cnts
        ,(start_new_district_staff_cnts+end_new_district_staff_cnts)/2 as new_district_staff_cnts
        ,(start_good_district_staff_cnts+end_good_district_staff_cnts)/2 as good_district_staff_cnts --20240401新增
        ,(start_district_staff_cnts+end_district_staff_cnts)/2 as district_staff_cnts
        ,(start_diamond_district_staff_cnts+end_diamond_district_staff_cnts)/2 as diamond_district_staff_cnts

        ,(start_staff_cnts+end_staff_cnts)/2 as staff_cnts
        ,(start_night_staff_cnts+end_night_staff_cnts)/2 as night_staff_cnts

        ,(start_old_staff_cnts+end_old_staff_cnts)/2 as old_staff_cnts
        ,(start_new_staff_cnts+end_new_staff_cnts)/2 as new_staff_cnts

        ,(start_old_staff_cnts_1+end_old_staff_cnts_1)/2 as old_staff_cnts_1
        ,(start_old_staff_cnts_2+end_old_staff_cnts_2)/2 as old_staff_cnts_2
        ,(start_old_staff_cnts_4+end_old_staff_cnts_4)/2 as old_staff_cnts_4
        ,(start_old_staff_cnts_5+end_old_staff_cnts_5)/2 as old_staff_cnts_5
        ,(start_key_staff_cnts+end_key_staff_cnts)/2 as key_staff_cnts

        ,sum(leave_cnts) as leave_cnts
        ,sum(manager_cnts) as leave_manager_cnts
        ,sum(sec_manager_cnts) as leave_sec_manager_cnts
        ,sum(district_staff_cnts) as leave_district_staff_cnts
        ,sum(old_district_staff_cnts) as leave_old_district_staff_cnts
        ,sum(new_district_staff_cnts) as leave_new_district_staff_cnts
        ,sum(good_district_staff_cnts) as leave_good_district_staff_cnts --20240401新增
        ,sum(diamond_district_staff_cnts) as leave_diamond_district_staff_cnts
        ,sum(staff_cnts) as leave_staff_cnts
        ,sum(night_staff_cnts) as leave_night_staff_cnts
        ,sum(old_staff_cnts) as leave_old_staff_cnts
        ,sum(new_staff_cnts) as leave_new_staff_cnts

        ,sum(old_staff_cnts_1) as leave_old_staff_cnts_1
        ,sum(old_staff_cnts_2) as leave_old_staff_cnts_2
        ,sum(old_staff_cnts_4) as leave_old_staff_cnts_4
        ,sum(old_staff_cnts_5) as leave_old_staff_cnts_5
        ,sum(key_staff_cnts) as leave_key_staff_cnts

    from prep_info t1
    group by t1.dt
        ,t1.dt_add_30_days
        ,t1.start_ppl_cnts
        ,t1.end_ppl_cnts
        ,t1.start_manager_cnts
        ,t1.end_manager_cnts
        ,t1.start_sec_manager_cnts
        ,t1.end_sec_manager_cnts
        ,t1.start_district_staff_cnts
        ,t1.end_district_staff_cnts
        ,t1.start_old_district_staff_cnts
        ,t1.start_new_district_staff_cnts
        ,t1.end_old_district_staff_cnts
        ,t1.end_new_district_staff_cnts
        ,t1.start_good_district_staff_cnts --20240401新增
        ,t1.end_good_district_staff_cnts --20240401新增
        ,t1.start_diamond_district_staff_cnts
        ,t1.end_diamond_district_staff_cnts
        ,t1.start_staff_cnts
        ,t1.end_staff_cnts
        ,t1.start_night_staff_cnts
        ,t1.end_night_staff_cnts
        ,t1.start_old_staff_cnts
        ,t1.end_old_staff_cnts
        ,t1.start_new_staff_cnts
        ,t1.end_new_staff_cnts
        ,t1.start_old_staff_cnts_1
        ,t1.end_old_staff_cnts_1
        ,t1.start_old_staff_cnts_2
        ,t1.end_old_staff_cnts_2
        ,t1.start_old_staff_cnts_4
        ,t1.end_old_staff_cnts_4
        ,t1.start_old_staff_cnts_5
        ,t1.end_old_staff_cnts_5
        ,t1.start_key_staff_cnts
        ,t1.end_key_staff_cnts
end

--t30离职率(调整后)
--分子=t30实际离职人数
begin
    with supply_detail as
    (
    select 
    * 
    ,from_unixtime(unix_timestamp(dt,'yyyymmdd'),'yyyy-mm-dd') as record_date
    from 
    data_build.dwd_store_construction_roster_staff_supply_v1_di
    where dt >= '20220601'
    )


    ,apply_leave_info as (
        select distinct
            t1.dept_code --门店code
            ,t1.man_code --工号
            ,if(length(t1.man_code)<8,concat('10',t1.man_code),t1.man_code) as staff_code
            ,t1.job --岗位
            ,date_format(t1.final_leave_date,'yyyyMMdd') as apply_dt --这里把create_time改为final_leave_date
            ,date_format(t1.create_time,'yyyy-MM-dd') as apply_date
            ,date_format(date_sub(t1.final_leave_date,1),'yyyyMMdd') as apply_dt_t1 --这里把create_time改为final_leave_date
            ,substr(position_class,1,1) as origin_tag
            ,coalesce(substr(position_class,1,1),'新') as new_old_tag
            ,coalesce(t2.protect_tag,'待观察') as protect_tag
            ,case when t3.hps_dept_descr_lv5 like '%区X%' then 1 else 0 end as is_district_staff
            ,t5.chuqin_label as chuqin_label
            ,t4.key_staff_type
            ,t6.protect_tag_detail_new as district_staff_protect_tag
        from data_shop.pdw_gis_workday_dimission_order_view t1
        left join data_shop.dm_shop_staff_protect_tag_v2 t2
        on t2.dt >= '20220630' 
            and date_format(date_sub(create_time,1),'yyyyMMdd') = t2.dt
            and if(length(t1.man_code)<8,concat('10',t1.man_code),t1.man_code) = t2.staff_code
        left join supply_detail t5
        on date_format(date_sub(create_time,1),'yyyy-MM-dd') = t5.record_date
        and if(length(t1.man_code)<8,concat('10',t1.man_code),t1.man_code) = t5.employee_id
        left join data_build.pdw_psprod_ps_blf_ehr_pers_vw_view t3 on if(length(t1.man_code)<8,concat('10',t1.man_code),t1.man_code) = if(length(t3.emplid)<8,concat('10',t3.emplid),t3.emplid) and t3.dt ='${today-1}' 
        left join data_build.dwd_store_construction_roster_staff_supply_v1_di t4 on if(length(t1.man_code)<8,concat('10',t1.man_code),t1.man_code) = t4.employee_id and t4.dt = date_format(date_sub(create_time,1),'yyyyMMdd') and t4.dt >= '20220630' 
        left join data_build.dwd_dwd_district_staff_protect_tag_v2_da_di t6 on if(length(t1.man_code)<8,concat('10',t1.man_code),t1.man_code) = t6.staff_code and t6.dt = date_format(date_sub(create_time,1),'yyyyMMdd') and t6.dt >= '20220630' 
        where t1.dt = '${today-1}' 
            and t1.job in ('店经理', '门店伙伴', '店员','社会PT','店副经理', '学生PT', '见习店经理')
            and date_format(create_time,'yyyyMMdd') >= '20220701'
            and final_leave = 'leave'
            and order_status = 'FINISHED' --流程完成才是真正离职
    )



    ,leave_cnts_info as (
        select 
            apply_dt
            ,'1' as joinkey
            ,count(distinct staff_code) as leave_cnts
            ,count(distinct case when job = '店经理' then staff_code end) as manager_cnts
            ,count(distinct case when job = '店副经理' then staff_code end) as sec_manager_cnts
            ,count(distinct case when is_district_staff = 1 then staff_code end) as district_staff_cnts
            ,count(distinct case when is_district_staff = 1 and new_old_tag = '老' then staff_code end) as old_district_staff_cnts
            ,count(distinct case when is_district_staff = 1 and new_old_tag = '新' then staff_code end) as new_district_staff_cnts
            ,count(distinct case when is_district_staff = 1 and protect_tag in ('应保护','金牌','普通','银牌') then staff_code end) as good_district_staff_cnts--新增了这个
            ,count(distinct case when is_district_staff = 1 and district_staff_protect_tag = 0 then staff_code end) as diamond_district_staff_cnts
            ,count(distinct case when is_district_staff = 0 and job not in ('店经理','店副经理') then staff_code end) as staff_cnts
            ,count(distinct case when is_district_staff = 0 and job not in ('店经理','店副经理') and new_old_tag = '老' and chuqin_label = '长夜型员工' then staff_code end) as night_staff_cnts
            ,count(distinct case when is_district_staff = 0 and job not in ('店经理','店副经理') and new_old_tag = '老' then staff_code end) as old_staff_cnts
            ,count(distinct case when is_district_staff = 0 and job not in ('店经理','店副经理') and new_old_tag = '新' then staff_code end) as new_staff_cnts
            ,count(distinct case when is_district_staff = 0 and job not in ('店经理','店副经理') and new_old_tag = '老' and protect_tag in ('应保护','金牌') then staff_code end) as old_staff_cnts_1
            ,count(distinct case when is_district_staff = 0 and job not in ('店经理','店副经理') and new_old_tag = '老' and protect_tag in ('普通','银牌') then staff_code end) as old_staff_cnts_2
            ,count(distinct case when is_district_staff = 0 and job not in ('店经理','店副经理') and new_old_tag = '老' and protect_tag in ('末位普通','须努力') then staff_code end) as old_staff_cnts_4
            ,count(distinct case when is_district_staff = 0 and job not in ('店经理','店副经理') and new_old_tag = '老' and protect_tag in ('应离职','不合格') then staff_code end) as old_staff_cnts_5
            ,count(distinct case when is_district_staff = 0 and job not in ('店经理','店副经理') and key_staff_type = 'key_staff' then staff_code end) as key_staff_cnts
        from apply_leave_info t1
        left join data_shop.pdw_idss_ipes_admin_employee_blacklist_view t2
        on t2.dt >= '20220601' and t1.staff_code = lpad(t2.employee_no,8,'10') and t1.apply_dt_t1 = t2.dt and valid_status='1' and start_date<=apply_date and end_date>=apply_date
        where t2.employee_no is null
        group by apply_dt
    )

    ,ppl_cnts_info as (
        select 
            t1.dt
            ,'1' as joinkey
            ,date_format(date_add(to_date(from_unixtime(unix_timestamp(t1.dt,'yyyyMMdd'))),30),'yyyyMMdd') as dt_add_30_days
            ,count(distinct t1.staff_code) as ppl_cnts
            ,count(distinct case when t1.position_cn = '店经理' then t1.staff_code end) as manager_cnts
            ,count(distinct case when t1.position_cn = '店副经理' then t1.staff_code end) as sec_manager_cnts
            ,count(distinct case when t3.hps_dept_descr_lv5 like '%区X%' then t1.staff_code end) as district_staff_cnts
            ,count(distinct case when t3.hps_dept_descr_lv5 like '%区X%' and substr(t1.position_class,1,1) = '老' then t1.staff_code end) as old_district_staff_cnts
            ,count(distinct case when t3.hps_dept_descr_lv5 like '%区X%' and substr(t1.position_class,1,1) = '新' then t1.staff_code end) as new_district_staff_cnts
            ,count(distinct case when t3.hps_dept_descr_lv5 like '%区X%' and t1.protect_tag in  ('应保护','金牌','普通','银牌') then t1.staff_code end) as good_district_staff_cnts--新增了这个
            ,count(distinct case when t3.hps_dept_descr_lv5 like '%区X%' and t5.protect_tag_detail_new = 0  then t1.staff_code end) as diamond_district_staff_cnts
            ,count(distinct case when t3.hps_dept_descr_lv5 not like '%区X%' and t1.position_cn not in ('店经理','店副经理') then t1.staff_code end) as staff_cnts
            ,count(distinct case when t3.hps_dept_descr_lv5 not like '%区X%' and substr(t1.position_class,1,1) = '老' and t1.position_cn not in ('店经理','店副经理') then t1.staff_code end) as old_staff_cnts
            ,count(distinct case when t3.hps_dept_descr_lv5 not like '%区X%' and substr(t1.position_class,1,1) = '老' and t1.position_cn not in ('店经理','店副经理') and t2.chuqin_label = '长夜型员工' then t1.staff_code end) as night_staff_cnts
            ,count(distinct case when t3.hps_dept_descr_lv5 not like '%区X%' and substr(t1.position_class,1,1) = '新' and t1.position_cn not in ('店经理','店副经理') then t1.staff_code end) as new_staff_cnts
            ,count(distinct case when t3.hps_dept_descr_lv5 not like '%区X%' and substr(t1.position_class,1,1) = '老' and t1.position_cn not in ('店经理','店副经理') and t1.protect_tag in ('应保护','金牌') then t1.staff_code end) as old_staff_cnts_1
            ,count(distinct case when t3.hps_dept_descr_lv5 not like '%区X%' and substr(t1.position_class,1,1) = '老' and t1.position_cn not in ('店经理','店副经理') and t1.protect_tag in ('普通','银牌') then t1.staff_code end) as old_staff_cnts_2
            ,count(distinct case when t3.hps_dept_descr_lv5 not like '%区X%' and substr(t1.position_class,1,1) = '老' and t1.position_cn not in ('店经理','店副经理') and t1.protect_tag in ('末位普通','须努力') then t1.staff_code end) as old_staff_cnts_4
            ,count(distinct case when t3.hps_dept_descr_lv5 not like '%区X%' and substr(t1.position_class,1,1) = '老' and t1.position_cn not in ('店经理','店副经理') and t1.protect_tag in ('应离职','不合格') then t1.staff_code end) as old_staff_cnts_5
            ,count(distinct case when t3.hps_dept_descr_lv5 not like '%区X%' and t1.position_cn not in ('店经理','店副经理') and t4.key_staff_type = 'key_staff' then t1.staff_code end) as key_staff_cnts
        from data_shop.dm_shop_staff_protect_tag_v2 t1
        left join supply_detail t2 on t1.staff_code = t2.employee_id and from_unixtime(unix_timestamp(t1.dt,'yyyymmdd'),'yyyy-mm-dd') = t2.record_date
        left join data_build.pdw_psprod_ps_blf_ehr_pers_vw_view t3 on t1.staff_code = if(length(t3.emplid)<8,concat('10',t3.emplid),t3.emplid) and t3.dt ='${today-1}' 
        left join data_build.dwd_store_construction_roster_staff_supply_v1_di t4 on t1.staff_code = t4.employee_id and t1.dt = t4.dt
        left join data_build.dwd_dwd_district_staff_protect_tag_v2_da_di t5 on t1.staff_code = t5.staff_code  and t1.dt=t5.dt
        where t1.dt >= '20220701'
        and t1.position_cn not in ('内部合作伙伴','内部合作经营者','内部合作辅助人','外部合作伙伴','外部合作经营者','外部合作辅助人')
        group by t1.dt
    )

    ,prep_info as (
        select 
            t1.dt
            ,t1.dt_add_30_days
            ,t1.ppl_cnts as start_ppl_cnts
            ,t2.ppl_cnts as end_ppl_cnts
            ,t1.manager_cnts as start_manager_cnts
            ,t2.manager_cnts as end_manager_cnts
            ,t1.sec_manager_cnts as start_sec_manager_cnts
            ,t2.sec_manager_cnts as end_sec_manager_cnts
            ,t1.district_staff_cnts as start_district_staff_cnts
            ,t2.district_staff_cnts as end_district_staff_cnts
            ,t1.night_staff_cnts as start_night_staff_cnts
            ,t2.night_staff_cnts as end_night_staff_cnts
            ,t1.old_district_staff_cnts as start_old_district_staff_cnts
            ,t2.old_district_staff_cnts as end_old_district_staff_cnts
            ,t1.new_district_staff_cnts as start_new_district_staff_cnts
            ,t2.new_district_staff_cnts as end_new_district_staff_cnts
            ,t1.good_district_staff_cnts as start_good_district_staff_cnts --新增了这个20240401
            ,t2.good_district_staff_cnts as end_good_district_staff_cnts --新增了这个20240401
            ,t2.diamond_district_staff_cnts as start_diamond_district_staff_cnts
            ,t2.diamond_district_staff_cnts as end_diamond_district_staff_cnts
            ,t1.staff_cnts as start_staff_cnts
            ,t2.staff_cnts as end_staff_cnts
            ,t1.old_staff_cnts as start_old_staff_cnts
            ,t2.old_staff_cnts as end_old_staff_cnts
            ,t1.new_staff_cnts as start_new_staff_cnts
            ,t2.new_staff_cnts as end_new_staff_cnts

            ,t1.old_staff_cnts_1 as start_old_staff_cnts_1
            ,t2.old_staff_cnts_1 as end_old_staff_cnts_1
            ,t1.old_staff_cnts_2 as start_old_staff_cnts_2
            ,t2.old_staff_cnts_2 as end_old_staff_cnts_2
            ,t1.old_staff_cnts_4 as start_old_staff_cnts_4
            ,t2.old_staff_cnts_4 as end_old_staff_cnts_4
            ,t1.old_staff_cnts_5 as start_old_staff_cnts_5
            ,t2.old_staff_cnts_5 as end_old_staff_cnts_5
            ,t1.key_staff_cnts as start_key_staff_cnts
            ,t2.key_staff_cnts as end_key_staff_cnts

            ,t3.apply_dt
            ,t3.leave_cnts
            ,t3.manager_cnts
            ,t3.sec_manager_cnts
            ,t3.district_staff_cnts
            ,t3.old_district_staff_cnts
            ,t3.new_district_staff_cnts
            ,t3.good_district_staff_cnts --20240401新增
            ,t3.diamond_district_staff_cnts
            ,t3.staff_cnts
            ,t3.old_staff_cnts
            ,t3.night_staff_cnts
            ,t3.new_staff_cnts
            ,t3.old_staff_cnts_1
            ,t3.old_staff_cnts_2
            ,t3.old_staff_cnts_4
            ,t3.old_staff_cnts_5
            ,t3.key_staff_cnts
        from ppl_cnts_info t1
        inner join ppl_cnts_info t2
        on t1.dt_add_30_days = t2.dt and t1.dt_add_30_days <= '${today}'
        left join leave_cnts_info t3
        on t3.apply_dt>=t1.dt and t3.apply_dt<t1.dt_add_30_days and t1.joinkey = t3.joinkey
    )

    select 
        t1.dt
        ,t1.dt_add_30_days
        ,(start_ppl_cnts+end_ppl_cnts)/2 as ppl_cnts
        ,(start_manager_cnts+end_manager_cnts)/2 as manager_cnts
        ,(start_sec_manager_cnts+end_sec_manager_cnts)/2 as sec_manager_cnts
        ,(start_old_district_staff_cnts+end_old_district_staff_cnts)/2 as old_district_staff_cnts
        ,(start_new_district_staff_cnts+end_new_district_staff_cnts)/2 as new_district_staff_cnts
        ,(start_good_district_staff_cnts+end_good_district_staff_cnts)/2 as good_district_staff_cnts --20240401新增
        ,(start_district_staff_cnts+end_district_staff_cnts)/2 as district_staff_cnts
        ,(start_diamond_district_staff_cnts+end_diamond_district_staff_cnts)/2 as diamond_district_staff_cnts

        ,(start_staff_cnts+end_staff_cnts)/2 as staff_cnts
        ,(start_night_staff_cnts+end_night_staff_cnts)/2 as night_staff_cnts

        ,(start_old_staff_cnts+end_old_staff_cnts)/2 as old_staff_cnts
        ,(start_new_staff_cnts+end_new_staff_cnts)/2 as new_staff_cnts

        ,(start_old_staff_cnts_1+end_old_staff_cnts_1)/2 as old_staff_cnts_1
        ,(start_old_staff_cnts_2+end_old_staff_cnts_2)/2 as old_staff_cnts_2
        ,(start_old_staff_cnts_4+end_old_staff_cnts_4)/2 as old_staff_cnts_4
        ,(start_old_staff_cnts_5+end_old_staff_cnts_5)/2 as old_staff_cnts_5
        ,(start_key_staff_cnts+end_key_staff_cnts)/2 as key_staff_cnts

        ,sum(leave_cnts) as leave_cnts
        ,sum(manager_cnts) as leave_manager_cnts
        ,sum(sec_manager_cnts) as leave_sec_manager_cnts
        ,sum(district_staff_cnts) as leave_district_staff_cnts
        ,sum(old_district_staff_cnts) as leave_old_district_staff_cnts
        ,sum(new_district_staff_cnts) as leave_new_district_staff_cnts
        ,sum(good_district_staff_cnts) as leave_good_district_staff_cnts --20240401新增
        ,sum(diamond_district_staff_cnts) as leave_diamond_district_staff_cnts
        ,sum(staff_cnts) as leave_staff_cnts
        ,sum(night_staff_cnts) as leave_night_staff_cnts
        ,sum(old_staff_cnts) as leave_old_staff_cnts
        ,sum(new_staff_cnts) as leave_new_staff_cnts

        ,sum(old_staff_cnts_1) as leave_old_staff_cnts_1
        ,sum(old_staff_cnts_2) as leave_old_staff_cnts_2
        ,sum(old_staff_cnts_4) as leave_old_staff_cnts_4
        ,sum(old_staff_cnts_5) as leave_old_staff_cnts_5
        ,sum(key_staff_cnts) as leave_key_staff_cnts

    from prep_info t1
    group by t1.dt
        ,t1.dt_add_30_days
        ,t1.start_ppl_cnts
        ,t1.end_ppl_cnts
        ,t1.start_manager_cnts
        ,t1.end_manager_cnts
        ,t1.start_sec_manager_cnts
        ,t1.end_sec_manager_cnts
        ,t1.start_district_staff_cnts
        ,t1.end_district_staff_cnts
        ,t1.start_old_district_staff_cnts
        ,t1.start_new_district_staff_cnts
        ,t1.end_old_district_staff_cnts
        ,t1.end_new_district_staff_cnts
        ,t1.start_good_district_staff_cnts --20240401新增
        ,t1.end_good_district_staff_cnts --20240401新增
        ,t1.start_diamond_district_staff_cnts
        ,t1.end_diamond_district_staff_cnts
        ,t1.start_staff_cnts
        ,t1.end_staff_cnts
        ,t1.start_night_staff_cnts
        ,t1.end_night_staff_cnts
        ,t1.start_old_staff_cnts
        ,t1.end_old_staff_cnts
        ,t1.start_new_staff_cnts
        ,t1.end_new_staff_cnts
        ,t1.start_old_staff_cnts_1
        ,t1.end_old_staff_cnts_1
        ,t1.start_old_staff_cnts_2
        ,t1.end_old_staff_cnts_2
        ,t1.start_old_staff_cnts_4
        ,t1.end_old_staff_cnts_4
        ,t1.start_old_staff_cnts_5
        ,t1.end_old_staff_cnts_5
        ,t1.start_key_staff_cnts
        ,t1.end_key_staff_cnts
end