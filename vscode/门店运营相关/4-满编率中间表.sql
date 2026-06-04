#
# --------------------------------------
# DATE: 2020-02-05
# DEV:
# DESC:
# PRODUCT_WIKI:
# DEV_WIKI:https://wiki.corp.bianlifeng.com/pages/viewpage.action?pageId=615156086
# --------------------------------------
source ${ETC}/format_date.cnf


TABLE_NAME="data_build.dwd_store_construction_full_capacity_perdict"
UNIQ_KEY='store_code'
CHECK_DATA_SQL="
    select
        '数据条数必须大于0', assert_true(count(1)>0), count(1),
        '唯一键唯一', assert_true(count(1)=sum(m)), sum(m)
    from (
        select ${UNIQ_KEY},count(1)m
        from ${TABLE_NAME}
        where dt='${DATE}'
        group by ${UNIQ_KEY}
    ) t;
"

##JOB入口函数
function dwd_store_construction_full_capacity_perdict_run {
    #主体计算函数
    calculate
}

#清理hdfs文件
function rebuild_hdfs {
    rebuild_hdfs_dir "${HDFS_DIR}"
}

#JOB业务计算函数
function calculate {
--   ${HIVE} -e << EOF "
        set hive.cli.errors.ignore=false;

with person_tag as
(
    select
         t0.store_code
        ,t0.staff_code
        ,if(length(staff_code) = 6, concat('10', staff_code) , staff_code) as user_no
        ,protect_tag
        ,if(protect_tag in ('应离职','末位普通') and position_cn not in ('店经理','见习店经理') or t1.employee_no is not null,'1','0') as is_leave
        ,if(protect_tag in ('应离职') ,'1','0') as is_leave_2
        ,if(protect_tag in ('应离职','末位普通') ,'1','0') as is_leave_3
    from data_build.dm_shop_staff_protect_tag_v2_view t0
    left join data_build.ods_uploads_pre_dimission t1 on t0.staff_code=t1.employee_no
    where t0.dt='${DATE}'
),
project_tag_person as
(
    select
         store_code
        ,count(distinct staff_code) as staffs
        ,count(distinct case when position_cn in ('店经理','见习店经理') then staff_code end) as managers
    from data_build.dm_shop_staff_protect_tag_v2_view
    where dt='${DATE}'
    and job_status=1
    and protect_tag not in ('应离职','末位普通')
    group by
        store_code
),

dimission_apply as---离职流程
(
    select initiator_code as user_no
    from data_build.dm_ordering_report_taskoutput_info_da_view
    where dt = '${DATE}'
     and flow_code = '016564'
     and to_date(create_time)>='${FDATE_SUB90DAY}'
     and order_status in ('FINISHED','PROCESSING')
    group by initiator_code

    union all

    select staff_no as staff_code
    from data_build.pdw_opc_shop_ehr_dimission_apply_view
    where dt = '${DATE}'
     and approve_status in (1,2)
     and to_date(create_time)>='${FDATE_SUB90DAY}'---20220502
    group by staff_no
),


 opening_days as (
    select
     store_code
    ,count(distinct c_date ) as opening_days
    from
      (
   select
   t1.sale_date as c_date
   ,t1.shop_code as store_code
   from default.pdw_idss_mmc_cooperate_shop_open_info t1
   left join data_build.dwd_store_construction_roster_store_demand_v1_di t2 on t1.shop_code = t2.store_id and t2.dt = '${DATE}'
   where t1.dt= '${DATE}'
   and weekofyear(t1.sale_date) = t2.max_week_of_year
   and t1.sale_date >= '${FDATE_SUB30DAY}'
   and t1.shop_type=0
   and t1.shop_state=1
   and t1.bach_business_time<>'全天不营业'
      ) t
      group by store_code
      ),

  hc_raw as(
    select
    store_code
    ,store_type
    ,hc_count
    ,store_epidemic_hc
    ,hc_all
    from(
         select
         dt,
         date_sub(date_add(from_unixtime(unix_timestamp(t1.dt,'yyyyMMdd'),'yyyy-MM-dd'),7 - case when dayofweek(from_unixtime(unix_timestamp(t1.dt,'yyyyMMdd'),'yyyy-MM-dd')) = 1 
         then 7 else dayofweek(from_unixtime(unix_timestamp(t1.dt,'yyyyMMdd'),'yyyy-MM-dd')) - 1 end),6) as new_dt, --取dt所在周的周一
         t1.store_code,
         t1.store_type,
         t1.start_date
         ,sum(t1.store_mgr_hc)+sum(t1.store_staff_hc) as hc_count
         ,sum(t1.store_epidemic_hc) as store_epidemic_hc
         ,sum(t1.store_mgr_hc)+sum(t1.store_staff_hc)+sum(t1.store_epidemic_hc) as hc_all
         from data_build.app_roster_report_measurement_hc_di_view t1
         where t1.dt='${DATE}'
         group by
           dt,
         date_sub(date_add(from_unixtime(unix_timestamp(t1.dt,'yyyyMMdd'),'yyyy-MM-dd'),7 - case when dayofweek(from_unixtime(unix_timestamp(t1.dt,'yyyyMMdd'),'yyyy-MM-dd')) = 1 
         then 7 else dayofweek(from_unixtime(unix_timestamp(t1.dt,'yyyyMMdd'),'yyyy-MM-dd')) - 1 end),6),
         t1.store_code,
         t1.store_type,
         t1.start_date
    ) t1
  where datediff(start_date,new_dt) = 14
  ),

  ddang as (  select
   store_code
   ,record_date
   ,type
   ,from_unixtime(unix_timestamp(dt,'yyyyMMdd'),'yyyy-MM-dd') as new_dt
   from data_smartorder.app_roster_report_last_30days_empty_store_list_di
   where dt = '${DATE}'
  ),

  mm as
  (
      select
      t1.store_code
      ,t1.record_date
      ,t1.type
      ,t1.new_dt
      ,t2.day_of_week_name
      from ddang t1
      left join dim_date_ya_v2 t2
      on t1.new_dt = t2.date_key

  ),

  ddang_list as
  (
  select
  store_code
   ,record_date
   ,type
  from mm
  where day_of_week_name in ('星期一','星期二','星期三')
  and record_date <= next_day(new_dt,'sun')
  and record_date >= date_sub(next_day(new_dt,'sun'),6)
  union

  select store_code
   ,record_date
   ,type
  from mm
  where day_of_week_name not in ('星期一','星期二','星期三')
  and record_date >= next_day(new_dt,'mon')
  and record_date <= date_add(next_day(new_dt,'mon'),6)
  ),

  is_upgrade_q6 as
  (
      select distinct
      store_code
      ,empty_days
      ,case when tt.empty_days>3 then 1 else 0 end as is_upgrade_paiban_pre
      from
      (
      select
              store_code
              ,count(distinct record_date)  as empty_days
          from ddang_list
          group by  store_code
      ) tt
      ),

  hc_base_1 as
  (
  select
  t3.store_code as store_code
  ,t3.hc_count as hc_all -- 旧版本
  ,t1.opening_days as opening_days -- 新版本
  ,t1.total_label_sd2  as suiban_v0
  ,t1.total_label_sd1 as duanban_v0
  ,t1.total_label_md as zhongban_v0
  ,t1.total_label_ld as changban_v0
  ,t1.total_label_sn1 as duanye_v0
  ,t1.total_label_sn1 + t1.total_label_mn + t1.total_label_ln + t1.total_label_sn2 as yeban_v0
  ,case when t1.total_label_sd2 >= 0.75 and total_label_sd1 >= 0.75 then round((3*total_label_sd2 + 6*total_label_sd1)/9,1)
  else 0 end as duan_pin_sui
  from
  hc_raw t3
  left join data_build.dwd_store_construction_roster_store_demand_v1_di t1 on t3.store_code = t1.store_id and t1.dt = '${DATE}'
  ),

  hc_base_2 as
  (
  select
  store_code as store_code
  ,hc_all as hc_all
  ,opening_days as opening_days
  ,case when duan_pin_sui >= 0.9 then if(suiban_v0 >=1,suiban_v0 -1,0)
  else suiban_v0 end as suiban_v1
  ,case when duan_pin_sui >= 0.9 then if(duanban_v0 >=1,duanban_v0 -1,0)
  else duanban_v0 end as duanban_v1
  ,case when duan_pin_sui >= 0.9 then zhongban_v0 + duan_pin_sui
  else zhongban_v0 end as zhongban_v1
  ,changban_v0 as changban_v1
  ,yeban_v0 as yeban_v1
  from hc_base_1
  ),

  hc_base_3 as
  (
  select
  store_code as store_code
  ,hc_all as hc_all
  ,opening_days as opening_days
  ,case when suiban_v1 >= 0.75 and zhongban_v1 >= 0.75 then round((3*suiban_v1 + 9*zhongban_v1)/12,1)
  else 0 end as zhong_pin_sui
  ,suiban_v1 as suiban_v1
  ,duanban_v1 as duanban_v1
  ,zhongban_v1 as zhongban_v1
  ,changban_v1 as changban_v1
  ,yeban_v1 as yeban_v1
  from hc_base_2
  ),

  hc_base_4 as
  (
  select
  store_code as store_code
  ,hc_all as hc_all
  ,opening_days as opening_days
  ,case when zhong_pin_sui >= 0.9 then if(suiban_v1 >=1,suiban_v1 -1,0)
  else suiban_v1 end as suiban_v2
  ,case when zhong_pin_sui >= 0.9 then if(zhongban_v1 >=1,zhongban_v1 -1,0)
  else zhongban_v1 end as zhongban_v2
  ,case when zhong_pin_sui >= 0.9 then changban_v1 + zhong_pin_sui
  else changban_v1 end as changban_v2
  ,duanban_v1 as duanban_v2
  ,yeban_v1 as yeban_v2
  from hc_base_3
  ),

  hc_base_5 as
  (
  select
  store_code as store_code
  ,hc_all as hc_all
  ,opening_days as opening_days
  ,opening_days*(3*suiban_v2 + 9*zhongban_v2) as zhong_sui_time
  ,opening_days*12*changban_v2 as changban_time
  ,opening_days*6*duanban_v2 as duanban_time
  ,opening_days*12*yeban_v2 as yeban_time
  ,opening_days*6*duanban_v2 +opening_days*12*changban_v2+opening_days*(3*suiban_v2 + 9*zhongban_v2) as baiban_time
  ,if(round((duanban_v2+changban_v2+zhongban_v2)*opening_days/6,1)>=round(duanban_v2+changban_v2+zhongban_v2,1),
      round((duanban_v2+changban_v2+zhongban_v2)*opening_days/6,1),round(duanban_v2+changban_v2+zhongban_v2,1)) as day_hc_count
  ,round((opening_days*6*duanban_v2 +opening_days*12*changban_v2+opening_days*(3*suiban_v2 + 9*zhongban_v2))/72,0) as day_fulfill_count
  from hc_base_4
  ),

  hc_base_6 as
  (
  select
  store_code as store_code
  , 0 as is_bonus_hc
  ,hc_all as hc_all
  ,opening_days as opening_days
  ,zhong_sui_time as zhong_sui_time
  ,changban_time as changban_time
  ,duanban_time as duanban_time
  ,yeban_time as yeban_time
  ,baiban_time as baiban_time
  ,day_hc_count as day_hc_count
  ,day_fulfill_count as day_fulfill_count
  ,case when opening_days is null then 0
  else if(day_hc_count- day_fulfill_count >=0.5 or (day_fulfill_count=2 and round(duanban_time/baiban_time,1)>=0.3),1,0) end as is_extra_hc
  ,case when opening_days is null then round(hc_all,0)
  when day_hc_count in ('1.4','1.5','1.6') then 2
  when day_hc_count in ('2.4','2.5','2.6') then 3
  when day_hc_count in ('3.4','3.5','3.6') then 4
  else if(day_hc_count- day_fulfill_count >=0.5,day_fulfill_count+1,day_fulfill_count) end as hc_day
  ,case when opening_days is null then 0
  else if(round(yeban_time/72,0)<=1,round(yeban_time/66,0),round(yeban_time/72,0)) end as hc_night
  ,case when opening_days is null then round(hc_all,0)
  else if( day_hc_count- day_fulfill_count >=0.5,day_fulfill_count+1,day_fulfill_count) +
    if(round(yeban_time/72,0)<=1,round(yeban_time/66,0),round(yeban_time/72,0)) end as hc_new
  from hc_base_5
  ),

  hc_base_7 as
  (
  select
  t1.store_code as store_code
  ,t1.is_bonus_hc
  ,t1.opening_days as opening_days
  ,t1.yeban_time as yeban_time
  ,t1.baiban_time as baiban_time
  ,t1.day_hc_count as day_hc_count
  ,t1.day_fulfill_count as day_fulfill_count
  ,t1.hc_all as hc_all
  ,t1.is_extra_hc as is_extra_hc
  ,case when t2.duanban_v0*t2.opening_days >=4 then 1 else 0 end as hc_short_day
  ,case when t2.duanye_v0*t2.opening_days >=4 then 1 else 0 end as hc_short_night
  ,case when t1.hc_all = 0 then 0
   when t1.hc_day is null then round(t1.hc_all,0) else t1.hc_day + t1.is_bonus_hc end as hc_day
  ,case when t1.hc_all = 0 then 0
  when t1.hc_night is null then 0 else t1.hc_night end as hc_night
  ,case when t1.hc_all = 0 then 0
  when t1.hc_new is null then round(t1.hc_all,0) else t1.hc_new + t1.is_bonus_hc end as hc_new
  from hc_base_6 t1
  left join hc_base_1 t2 on t1.store_code = t2.store_code
  ),

  6week_demand_1 as(  
  select
 distinct roster_id
,store_id as store_code
,work_date
,start_time
,end_time
,(end_time - start_time) as work_hours
,is_night
,weekofyear(work_date) as week_of_year
,weekofyear(work_date) - weekofyear(from_unixtime(unix_timestamp(t1.dt,'yyyyMMdd'),'yyyy-MM-dd')) as week_diff
,year(work_date) as year_of_work
,t1.dt
,from_unixtime(unix_timestamp(t1.dt,'yyyyMMdd'),'yyyy-MM-dd') as new_dt
 from data_build.dw_roster_effect_roster_detail_info_da_view t1
    where t1.dt = '${DATE_ADD1DAY}'
    and store_type_desc = '门店'
and class_id in ('0')
and store_type = '0'
and sale_type <> '全天不营业'
and work_date >= date_sub(next_day('${FDATE_SUB0DAY}','mon'),7)
and work_date <= date_add(next_day('${FDATE_SUB0DAY}','mon'),34) --未来4周
),

6week_demand_2 as
(
select
store_code
,week_of_year
,week_diff
,count(distinct case when work_hours >=4 and is_night = 0 then roster_id end) as roster_count_day
,sum(case when is_night = 0 then work_hours end) as roster_hours_day
,count(distinct case when work_hours >=4 and is_night = 1 then roster_id end) as roster_count_night
,sum(case when is_night = 1 then work_hours end) as roster_hours_night
from 6week_demand_1
group by
store_code
,week_of_year
,week_diff
),

6week_demand_3 as
(
select
store_code
,sum(case when week_diff in(0) then roster_count_day end) as roster_count_day_0week
,sum(case when week_diff in(1) then roster_count_day end) as roster_count_day_1week
,sum(case when week_diff in(2) then roster_count_day end) as roster_count_day_2week
,sum(case when week_diff in(3) then roster_count_day end) as roster_count_day_3week
,sum(case when week_diff in(4) then roster_count_day end) as roster_count_day_4week
,sum(case when week_diff in(5) then roster_count_day end) as roster_count_day_5week
,sum(case when week_diff in(0) then roster_hours_day end) as roster_hours_day_0week
,sum(case when week_diff in(1) then roster_hours_day end) as roster_hours_day_1week
,sum(case when week_diff in(2) then roster_hours_day end) as roster_hours_day_2week
,sum(case when week_diff in(3) then roster_hours_day end) as roster_hours_day_3week
,sum(case when week_diff in(4) then roster_hours_day end) as roster_hours_day_4week
,sum(case when week_diff in(5) then roster_hours_day end) as roster_hours_day_5week
,sum(case when week_diff in(0) then roster_count_night end) as roster_count_night_0week
,sum(case when week_diff in(1) then roster_count_night end) as roster_count_night_1week
,sum(case when week_diff in(2) then roster_count_night end) as roster_count_night_2week
,sum(case when week_diff in(3) then roster_count_night end) as roster_count_night_3week
,sum(case when week_diff in(4) then roster_count_night end) as roster_count_night_4week
,sum(case when week_diff in(5) then roster_count_night end) as roster_count_night_5week
,sum(case when week_diff in(0) then roster_hours_night end) as roster_hours_night_0week
,sum(case when week_diff in(1) then roster_hours_night end) as roster_hours_night_1week
,sum(case when week_diff in(2) then roster_hours_night end) as roster_hours_night_2week
,sum(case when week_diff in(3) then roster_hours_night end) as roster_hours_night_3week
,sum(case when week_diff in(4) then roster_hours_night end) as roster_hours_night_4week
,sum(case when week_diff in(5) then roster_hours_night end) as roster_hours_night_5week
,sum(case when week_diff in(0,1) then roster_count_day end)/2 as roster_count_day_avg_1week
,sum(case when week_diff in(2,3) then roster_count_day end)/2 as roster_count_day_avg_3week
,sum(case when week_diff in(4,5) then roster_count_day end)/2 as roster_count_day_avg_5week
,sum(case when week_diff in(0,1) then roster_hours_day end)/2 as roster_hours_day_avg_1week
,sum(case when week_diff in(2,3) then roster_hours_day end)/2 as roster_hours_day_avg_3week
,sum(case when week_diff in(4,5) then roster_hours_day end)/2 as roster_hours_day_avg_5week
,sum(case when week_diff in(0,1) then roster_count_night end)/2 as roster_count_night_avg_1week
,sum(case when week_diff in(2,3) then roster_count_night end)/2 as roster_count_night_avg_3week
,sum(case when week_diff in(4,5) then roster_count_night end)/2 as roster_count_night_avg_5week
,sum(case when week_diff in(0,1) then roster_hours_night end)/2 as roster_hours_night_avg_1week
,sum(case when week_diff in(2,3) then roster_hours_night end)/2 as roster_hours_night_avg_3week
,sum(case when week_diff in(4,5) then roster_hours_night end)/2 as roster_hours_night_avg_5week
from 6week_demand_2
group by store_code
),

6week_demand_4 as
(
select
store_code
,roster_count_day_0week+roster_count_night_0week  as roster_count_0week
,roster_count_day_1week+roster_count_night_1week  as roster_count_1week
,roster_count_day_2week+roster_count_night_2week  as roster_count_2week
,roster_count_day_3week+roster_count_night_3week  as roster_count_3week
,roster_count_day_4week+roster_count_night_4week  as roster_count_4week
,roster_count_day_5week+roster_count_night_5week  as roster_count_5week
,roster_hours_day_0week+roster_hours_night_0week  as roster_hours_0week
,roster_hours_day_1week+roster_hours_night_1week  as roster_hours_1week
,roster_hours_day_2week+roster_hours_night_2week  as roster_hours_2week
,roster_hours_day_3week+roster_hours_night_3week  as roster_hours_3week
,roster_hours_day_4week+roster_hours_night_4week  as roster_hours_4week
,roster_hours_day_5week+roster_hours_night_5week  as roster_hours_5week
,case when (roster_count_day_avg_5week - roster_count_day_avg_1week >= 12 or roster_hours_day_avg_5week - roster_hours_day_avg_1week >= 144) then 2
when (roster_count_day_avg_5week - roster_count_day_avg_1week >= 6  or roster_hours_day_avg_5week - roster_hours_day_avg_1week >= 72) then 1
when (roster_count_day_avg_3week - roster_count_day_avg_1week >=9  and roster_count_day_avg_5week - roster_count_day_avg_1week >=9) or ( roster_count_day_avg_3week - roster_hours_day_avg_1week >=108 and roster_hours_day_avg_5week - roster_hours_day_avg_1week >=108 ) then 2
when (roster_count_day_avg_3week - roster_count_day_avg_1week >=4  and roster_count_day_avg_5week - roster_count_day_avg_1week >=4) or (roster_count_day_avg_3week - roster_hours_day_avg_1week >=48 and roster_hours_day_avg_5week - roster_hours_day_avg_1week >=48 ) then 1
when (roster_count_day_avg_3week - roster_count_day_avg_1week >6  or roster_hours_day_avg_3week - roster_hours_day_avg_1week >84) then 1
when (roster_count_day_avg_5week - roster_count_day_avg_3week >6  or roster_hours_day_avg_5week - roster_hours_day_avg_3week >84) then 1
else 0 end as gap_bonus_day
,case when (roster_count_night_avg_5week - roster_count_night_avg_1week >= 12 or roster_hours_night_avg_5week - roster_hours_night_avg_1week >= 144) then 2
when (roster_count_night_avg_5week - roster_count_night_avg_1week >= 6  or roster_hours_night_avg_5week - roster_hours_night_avg_1week >= 72) then 1
when (roster_count_night_avg_3week - roster_count_night_avg_1week >=9  and roster_count_night_avg_5week - roster_count_night_avg_1week >=9) or ( roster_count_night_avg_3week - roster_hours_night_avg_1week >=108 and roster_hours_night_avg_5week - roster_hours_night_avg_1week >=108 ) then 2
when (roster_count_night_avg_3week - roster_count_night_avg_1week >=4  and roster_count_night_avg_5week - roster_count_night_avg_1week >=4) or (roster_count_night_avg_3week - roster_hours_night_avg_1week >=48 and roster_hours_night_avg_5week - roster_hours_night_avg_1week >=48 ) then 1
when (roster_count_night_avg_3week - roster_count_night_avg_1week >=7  or roster_hours_night_avg_3week - roster_hours_night_avg_1week >84) then 1
when (roster_count_night_avg_5week - roster_count_night_avg_3week >=7  or roster_hours_night_avg_5week - roster_hours_night_avg_3week >84) then 1
else 0 end as gap_bonus_night
from 6week_demand_3
),

  is_manager_count as
  (
  select
  t1.store_code
  ,if(length(t1.current_manager_code) = 6, concat('10', t1.current_manager_code) , t1.current_manager_code) as current_manager_code
  ,t1.current_manager_position
  ,case when t1.structure_status <> '3.3' then 1
  when t1.structure_status ='3.3' then 0
  end as is_manager_count 
  from data_shop.dwa_shop_store_structure_condition_di t1
 inner join (
 select max(dt) as max_dt
 from data_shop.dwa_shop_store_structure_condition_di
 where dt >= '${DATE_SUB2DAY}'
 and dt <= '${DATE}'
 ) tmp on t1.dt = tmp.max_dt

 where t1.dt >= '${DATE_SUB2DAY}'
 and t1.dt <= '${DATE}'
  and t1.store_status < 3
  ),

  entry_detail as
  (
  select
   if(length(t1.code)<8,concat('10',t1.code),t1.code) as staff_code
   ,t1.position_name
   ,t1.plan_shop_code
   ,date_format(t2.create_time,'yyyy-MM-dd') as entry_date
   ,date_format(t2.create_time,'yyyyMMdd') as entry_dt
   ,case
       when t1.final_work_class_tag like '%全天%' then '全天型员工'
       when t1.final_work_class_tag like '%白%' then '长白型员工'
       when t1.final_work_class_tag like '%夜%' then '长夜型员工'
       else 'NA' end as staff_tag
   ,final_work_class_tag
   from data_gis_h3.mid_gis_workday_entry_staff_position_da t1
   left join data_shop.mid_gis_workday_entry_status_change_view t2
   on t1.entry_id = t2.entry_id and t2.entry_state = 1
   and t2.dt = '${DATE}'
   left join data_build.dwd_store_construction_roster_staff_supply_v1_di t3 on if(length(t1.code)<8,concat('10',t1.code),t1.code) = t3.employee_id
   and t3.dt= '${DATE}'
   where t1.dt = '${DATE}'
   and t1.position_name in ('店经理','门店伙伴','店副经理','店员','社会PT','学生PT','见习店经理','内部合作经营者','内部合作辅助人','内部合作伙伴','外部合作经营者','外部合作辅助人','外部合作伙伴')
   and t1.code is not null
   and t3.employee_id is null
   and date_format(t2.create_time,'yyyyMMdd') >= '${DATE_SUB3DAY}'
  ),

  entry_sum as
  (
  select
  plan_shop_code as store_code
  ,count(case when staff_tag = '全天型员工' then staff_code end) as entry_quantian_count
  ,count(case when staff_tag = '长白型员工' then staff_code end) as entry_changbai_count
  ,count(case when staff_tag = '长夜型员工' then staff_code end) as entry_changye_count
  ,count(case when staff_tag is not null then staff_code end) as entry_fte_new
  from entry_detail
  group by plan_shop_code
  ),

  supply_base_1 as
  (
  select
  distinct
  t1.employee_id as employee_id
  ,t1.hps_d_jobcode as hps_d_jobcode
  ,case when t2.is_manager_count = 1 then '长白型员工'
   when t1.hps_d_jobcode = '店副经理' then '长夜型员工' else t1.geiban_label end as geiban_label
  ,case
   when t1.is_di = 'blacklist' then 'blacklist'
   when t2.is_manager_count = 1 then 0
   when t4.position_cn = '学生PT' then 1 
   else 0 end as is_di --20250724修改这里，重新算is_di,用于计算gap_new_withoutlow(剔除学生PT后的gap),20250814去掉夜班的疑似学生,20250819去掉所有疑似学生
  ,t1.is_manager as is_manager
  ,t1.give_days_final as give_days_final
  ,t1.is_leave_21 as is_leave_21
  ,t1.store_code as store_code
  ,t3.miss_probability as miss_probability
  ,t3.level as miss_level
  ,case when t1.is_leave_21 = 1 then 0
  when t1.is_leave_manager_21 = 1 then 0
  when t1.hps_d_jobcode = '店副经理' and t1.is_di <> 'blacklist' and t1.potential_leave <> '1' then 1 --0910新增店副的两个限制条件(非黑名单，非因未给班而判断为有离职风险的人员)
  when t2.is_manager_count = 1 then 1
  when t2.is_manager_count = 0 then 0
  when t1.geiban_label = '短白1型' then 0.5
  when t1.available_days >= 5 then 1
  when t1.available_days >= 3 then 0.5
  else 0 end as supply_count
  ,case when t3.level = '高' then 0
  when t1.is_leave_21 = 1 then 0
  when t1.is_leave_manager_21 = 1 then 0
  when t1.hps_d_jobcode = '店副经理' and t1.is_di <> 'blacklist' and t1.potential_leave <> '1' then 1 --0910新增店副的两个限制条件(非黑名单，非因未给班而判断为有离职风险的人员)
  when t2.is_manager_count = 1 then 1
  when t2.is_manager_count = 0 then 0
  when t1.geiban_label = '短白1型' then 0.5
  when t1.available_days >= 5 then 1
  when t1.available_days >= 3 then 0.5
  else 0 end as supply_count_miss
  from data_build.dwd_store_construction_roster_staff_supply_v1_di t1
  left join is_manager_count t2 on t1.employee_id = t2.current_manager_code
  left join data_promotion.dm_ai_clerk_miss_predict_v1_di t3 on t1.employee_id = t3.staff_code and t3.dt = '${DATE}'
  left join 
  (select
  t1.staff_code
  ,case when t1.student_suspect = '1' and from_unixtime(unix_timestamp(entry_date, 'yyyyMMdd'), 'yyyy-MM-dd') < '2025-06-01' then '疑似学生PT+早入职' else t1.student_suspect end as student_suspect
  ,position_cn
  from data_shop.dm_shop_staff_protect_tag_v2 t1
  where t1.dt = '${DATE}') t4 on t4.staff_code = t1.employee_id
  inner join (
 select max(dt) as max_dt
 from data_build.dwd_store_construction_roster_staff_supply_v1_di
 where dt >= '${DATE_SUB2DAY}'
 and dt <= '${DATE}'
 ) tmp on t1.dt = tmp.max_dt
 where t1.dt >= '${DATE_SUB2DAY}'
 and t1.dt <= '${DATE}'
  ),

  supply_base_1_2 as
  (
  select
  store_code
  ,sum(case when geiban_label = '中白型员工' then supply_count end) as zhongbai_count
  ,sum(case when geiban_label = '短白1型' then supply_count end) as duanbai_count
  ,sum(case when geiban_label = '全天型员工' then supply_count end) as quantian_count
  ,sum(case when geiban_label = '长白型员工' then supply_count end) as changbai_count
  ,sum(case when geiban_label = '长夜型员工' then supply_count end) as changye_count
  ,sum(supply_count) as fte_new
  ,sum(supply_count_miss) as fte_new_miss
  ,sum(case when (is_di = 0 or is_di is null) and geiban_label = '中白型员工' then supply_count end) as zhongbai_count_withoutlow
  ,sum(case when (is_di = 0 or is_di is null) and geiban_label = '短白1型' then supply_count end) as duanbai_count_withoutlow
  ,sum(case when (is_di = 0 or is_di is null) and geiban_label = '全天型员工' then supply_count end) as quantian_count_withoutlow
  ,sum(case when (is_di = 0 or is_di is null) and geiban_label = '长白型员工' then supply_count end) as changbai_count_withoutlow
  ,sum(case when (is_di = 0 or is_di is null) and geiban_label = '长夜型员工' then supply_count end) as changye_count_withoutlow
  ,sum(case when (is_di = 0 or is_di is null) then supply_count end) as fte_new_withoutlow
  ,sum(case when (is_di = 0 or is_di is null) then supply_count_miss end) as fte_new_withoutlow_miss
  from supply_base_1
  group by store_code
  ),

  supply_base_2 as
  (
  select
  t1.store_code
  ,nvl(t1.zhongbai_count,0) as zhongbai_count
  ,nvl(t1.duanbai_count,0) as duanbai_count
  ,nvl(t1.quantian_count,0) + nvl(t2.entry_quantian_count,0) as quantian_count
  ,nvl(t1.changbai_count,0) + nvl(t2.entry_changbai_count,0) as changbai_count
  ,nvl(t1.changye_count,0) + nvl(t2.entry_changye_count,0) as changye_count
  ,nvl(t1.fte_new,0) + nvl(t2.entry_fte_new,0) as fte_new
  ,nvl(t1.fte_new_miss,0) + nvl(t2.entry_fte_new,0) as fte_new_miss
  ,nvl(t1.zhongbai_count_withoutlow,0) as zhongbai_count_withoutlow
  ,nvl(t1.duanbai_count_withoutlow,0) as duanbai_count_withoutlow
  ,nvl(t1.quantian_count_withoutlow,0) + nvl(t2.entry_quantian_count,0) as quantian_count_withoutlow
  ,nvl(t1.changbai_count_withoutlow,0) + nvl(t2.entry_changbai_count,0) as changbai_count_withoutlow
  ,nvl(t1.changye_count_withoutlow,0) + nvl(t2.entry_changye_count,0) as changye_count_withoutlow
  ,nvl(t1.fte_new_withoutlow,0)+nvl(t2.entry_fte_new,0) as fte_new_withoutlow
  ,nvl(t1.fte_new_withoutlow_miss,0)+nvl(t2.entry_fte_new,0) as fte_new_withoutlow_miss
  from supply_base_1_2 t1
  left join entry_sum t2 on t1.store_code = t2.store_code
  ),

  supply_base_3 as
  (
  select
  t2.store_code
  ,t2.hc_day
  ,t2.hc_night
  ,t2.hc_new
  ,t2.is_bonus_hc
  ,t2.is_extra_hc
  ,t2.hc_short_day
  ,t2.hc_short_night
  ,case
  when nvl(t1.changye_count,0)>= t2.hc_night then nvl(t1.changye_count,0)
  when nvl(t1.zhongbai_count,0)  + nvl(t1.changbai_count,0) + nvl(t1.duanbai_count,0) >= t2.hc_day then if(nvl(t1.changye_count,0) + nvl(t1.quantian_count,0) >= t2.hc_night,t2.hc_night,nvl(t1.changye_count,0) + nvl(t1.quantian_count,0))
  when nvl(t1.zhongbai_count,0)  + nvl(t1.changbai_count,0) + nvl(t1.duanbai_count,0) + nvl(t1.quantian_count,0) >= t2.hc_day-t2.hc_short_day
  then if(nvl(t1.changye_count,0) + nvl(t1.zhongbai_count,0)  + nvl(t1.changbai_count,0) + nvl(t1.duanbai_count,0) + nvl(t1.quantian_count,0) - t2.hc_day >= t2.hc_night,t2.hc_night,
   if(t2.hc_short_day>0,nvl(t1.changye_count,0) + nvl(t1.zhongbai_count,0)  + nvl(t1.changbai_count,0) + nvl(t1.duanbai_count,0) + nvl(t1.quantian_count,0) - (t2.hc_day-t2.hc_short_day),
  nvl(t1.changye_count,0) + nvl(t1.zhongbai_count,0)  + nvl(t1.changbai_count,0) + nvl(t1.duanbai_count,0) + nvl(t1.quantian_count,0) - t2.hc_day))
  when nvl(t1.changye_count,0) = 0 and t2.hc_night > 0 and nvl(t1.quantian_count,0) >=1 and nvl(t1.zhongbai_count,0) + nvl(t1.changbai_count,0) + nvl(t1.duanbai_count,0) + nvl(t1.quantian_count,0) >= 2 then 1
  else nvl(t1.changye_count,0) end as fte_night
  ,case
  when nvl(t1.changye_count,0) >= t2.hc_night then nvl(t1.zhongbai_count,0) + nvl(t1.quantian_count,0) + nvl(t1.changbai_count,0) + nvl(t1.duanbai_count,0)
  when nvl(t1.zhongbai_count,0)  + nvl(t1.changbai_count,0) + nvl(t1.duanbai_count,0) >= t2.hc_day then if(nvl(t1.changye_count,0) + nvl(t1.quantian_count,0) >= t2.hc_night,nvl(t1.changye_count,0) + nvl(t1.quantian_count,0) - t2.hc_night +nvl(t1.zhongbai_count,0)  + nvl(t1.changbai_count,0) + nvl(t1.duanbai_count,0),nvl(t1.zhongbai_count,0)  + nvl(t1.changbai_count,0) + nvl(t1.duanbai_count,0))
  when nvl(t1.zhongbai_count,0)  + nvl(t1.changbai_count,0) + nvl(t1.duanbai_count,0) + nvl(t1.quantian_count,0) >= t2.hc_day - t2.hc_short_day
  then if(nvl(t1.changye_count,0) + nvl(t1.zhongbai_count,0)  + nvl(t1.changbai_count,0) + nvl(t1.duanbai_count,0) + nvl(t1.quantian_count,0) - t2.hc_day >= t2.hc_night,
  nvl(t1.changye_count,0) + nvl(t1.zhongbai_count,0)  + nvl(t1.changbai_count,0) + nvl(t1.duanbai_count,0) + nvl(t1.quantian_count,0) - t2.hc_night,
   if(t2.hc_short_day>0,t2.hc_day-t2.hc_short_day,
  t2.hc_day))
  when nvl(t1.changye_count,0) = 0 and t2.hc_night > 0 and nvl(t1.quantian_count,0) >=1 and nvl(t1.zhongbai_count,0) + nvl(t1.changbai_count,0) + nvl(t1.duanbai_count,0) + nvl(t1.quantian_count,0) >= 2 then nvl(t1.zhongbai_count,0)  + nvl(t1.changbai_count,0) + nvl(t1.duanbai_count,0) + nvl(t1.quantian_count,0) -1
  else nvl(t1.zhongbai_count,0)  + nvl(t1.changbai_count,0) + nvl(t1.duanbai_count,0) + nvl(t1.quantian_count,0)
  end as fte_day
  ,nvl(t1.fte_new,0) as fte_new
  ,nvl(t1.fte_new_miss,0) as fte_new_miss
  ,case
  when nvl(t1.changye_count_withoutlow,0)>= t2.hc_night then nvl(t1.changye_count_withoutlow,0)
  when nvl(t1.zhongbai_count_withoutlow,0)  + nvl(t1.changbai_count_withoutlow,0) + nvl(t1.duanbai_count_withoutlow,0) >= t2.hc_day then if(nvl(t1.changye_count_withoutlow,0) + nvl(t1.quantian_count_withoutlow,0) >= t2.hc_night,t2.hc_night,nvl(t1.changye_count_withoutlow,0) + nvl(t1.quantian_count_withoutlow,0))
  when nvl(t1.zhongbai_count_withoutlow,0)  + nvl(t1.changbai_count_withoutlow,0) + nvl(t1.duanbai_count_withoutlow,0) + nvl(t1.quantian_count_withoutlow,0) > t2.hc_day
  then if(nvl(t1.changye_count_withoutlow,0) + nvl(t1.zhongbai_count_withoutlow,0)  + nvl(t1.changbai_count_withoutlow,0) + nvl(t1.duanbai_count_withoutlow,0) + nvl(t1.quantian_count_withoutlow,0) - t2.hc_day >= t2.hc_night,t2.hc_night,nvl(t1.changye_count_withoutlow,0) + nvl(t1.zhongbai_count_withoutlow,0)  + nvl(t1.changbai_count_withoutlow,0) + nvl(t1.duanbai_count_withoutlow,0) + nvl(t1.quantian_count_withoutlow,0) - t2.hc_day)
  when nvl(t1.changye_count_withoutlow,0) = 0 and t2.hc_night > 0 and nvl(t1.quantian_count_withoutlow,0) >=1 and nvl(t1.zhongbai_count_withoutlow,0) + nvl(t1.changbai_count_withoutlow,0) + nvl(t1.duanbai_count_withoutlow,0) + nvl(t1.quantian_count_withoutlow,0) >= 2 then 1
  else nvl(t1.changye_count_withoutlow,0) end as fte_night_withoutlow
  ,case
  when nvl(t1.changye_count_withoutlow,0) >= t2.hc_night then nvl(t1.zhongbai_count_withoutlow,0) + nvl(t1.quantian_count_withoutlow,0) + nvl(t1.changbai_count_withoutlow,0) + nvl(t1.duanbai_count_withoutlow,0)
  when nvl(t1.zhongbai_count_withoutlow,0)  + nvl(t1.changbai_count_withoutlow,0) + nvl(t1.duanbai_count_withoutlow,0) >= t2.hc_day then if(nvl(t1.changye_count_withoutlow,0) + nvl(t1.quantian_count_withoutlow,0) >= t2.hc_night,nvl(t1.changye_count_withoutlow,0) + nvl(t1.quantian_count_withoutlow,0) - t2.hc_night +nvl(t1.zhongbai_count_withoutlow,0)  + nvl(t1.changbai_count_withoutlow,0) + nvl(t1.duanbai_count_withoutlow,0),nvl(t1.zhongbai_count_withoutlow,0)  + nvl(t1.changbai_count_withoutlow,0) + nvl(t1.duanbai_count_withoutlow,0))
  when nvl(t1.zhongbai_count_withoutlow,0)  + nvl(t1.changbai_count_withoutlow,0) + nvl(t1.duanbai_count_withoutlow,0) + nvl(t1.quantian_count_withoutlow,0) > t2.hc_day
  then if(nvl(t1.changye_count_withoutlow,0) + nvl(t1.zhongbai_count_withoutlow,0)  + nvl(t1.changbai_count_withoutlow,0) + nvl(t1.duanbai_count_withoutlow,0) + nvl(t1.quantian_count_withoutlow,0) - t2.hc_day >= t2.hc_night,nvl(t1.changye_count_withoutlow,0) + nvl(t1.zhongbai_count_withoutlow,0)  + nvl(t1.changbai_count_withoutlow,0) + nvl(t1.duanbai_count_withoutlow,0) + nvl(t1.quantian_count_withoutlow,0) - t2.hc_night,t2.hc_day)
  when nvl(t1.changye_count_withoutlow,0) = 0 and t2.hc_night > 0 and nvl(t1.quantian_count_withoutlow,0) >=1 and nvl(t1.zhongbai_count_withoutlow,0) + nvl(t1.changbai_count_withoutlow,0) + nvl(t1.duanbai_count_withoutlow,0) + nvl(t1.quantian_count_withoutlow,0) >= 2 then nvl(t1.zhongbai_count_withoutlow,0)  + nvl(t1.changbai_count_withoutlow,0) + nvl(t1.duanbai_count_withoutlow,0) + nvl(t1.quantian_count_withoutlow,0) -1
  else nvl(t1.zhongbai_count_withoutlow,0)  + nvl(t1.changbai_count_withoutlow,0) + nvl(t1.duanbai_count_withoutlow,0) + nvl(t1.quantian_count_withoutlow,0) end as fte_day_withoutlow
  ,nvl(t1.fte_new_withoutlow,0) as fte_new_withoutlow
  ,nvl(t1.fte_new_withoutlow_miss,0) as fte_new_withoutlow_miss
  from hc_base_7 t2
  left join supply_base_2 t1 on t1.store_code = t2.store_code
  ),

  supply_base_4 as
  (
  select
  store_code
  ,hc_day
  ,hc_night
  ,hc_new
  ,hc_short_day
  ,hc_short_night
  ,if(round(hc_night-fte_night,0)>=0,round(hc_night-fte_night,0),0) as gap_night
  ,if(round(hc_day-fte_day,0)>=0,round(hc_day-fte_day,0),0) as gap_day
  ,if(round(hc_night-fte_night,0)>=0,round(hc_night-fte_night,0),0) + if(round(hc_day-fte_day,0)>=0,round(hc_day-fte_day,0),0) as gap_new
  ,is_extra_hc
  ,fte_day as fte_day
  ,fte_night as fte_night
  ,fte_new as fte_new
  ,nvl(fte_night/hc_night,1) as full_capacity_night
  ,nvl(fte_day/hc_day,1) as full_capacity_day
  ,nvl(fte_new/hc_new,1) as full_capacity_new
  ,fte_day_withoutlow as fte_day_withoutlow
  ,fte_night_withoutlow as fte_night_withoutlow
  ,fte_new_withoutlow as fte_new_withoutlow
  ,fte_new_miss as fte_new_miss
  ,fte_new_withoutlow_miss as fte_new_withoutlow_miss
  ,if(round(hc_night-fte_night_withoutlow,0)>=0,round(hc_night-fte_night_withoutlow,0),0) as gap_night_withoutlow
  ,if(round(hc_day-fte_day_withoutlow,0)>=0,round(hc_day-fte_day_withoutlow,0),0) as gap_day_withoutlow
  ,if(round(hc_night-fte_night_withoutlow,0)>=0,round(hc_night-fte_night_withoutlow,0),0) + if(round(hc_day-fte_day_withoutlow,0)>=0,round(hc_day-fte_day_withoutlow,0),0) as gap_new_withoutlow
  ,nvl(fte_night_withoutlow/hc_night,1) as full_capacity_night_withoutlow
  ,nvl(fte_day_withoutlow/hc_day,1) as full_capacity_day_withoutlow
  ,nvl(fte_new_withoutlow/hc_new,1) as full_capacity_new_withoutlow

  from supply_base_3
  ),

   group_full_capacity as (  select
  t1.a_store_code
  ,count(distinct case when t4.max_week_of_year is not null then t1.b_store_code end) as group_count
  ,sum(case when t4.max_week_of_year is not null then t2.fte_day end )/ sum(case when t4.max_week_of_year is not null then t2.hc_day end) as full_capacity_day_g
  ,sum(case when t4.max_week_of_year is not null then t2.fte_new end )/ sum(case when t4.max_week_of_year is not null then t2.hc_new end) as full_capacity_new_g

  from data_gis_h3.mid_order_external_same_city_store_riding_distance_type_zero_do_business_union_all_view t1
  left join supply_base_4 t2 on t2.store_code  = t1.b_store_code
  left join data_build.dwd_store_construction_roster_store_demand_v1_di t3 on t1.a_store_code = t3.store_id and t3.dt = '${DATE}'
  left join data_build.dwd_store_construction_roster_store_demand_v1_di t4 on t1.b_store_code = t4.store_id and t4.dt = '${DATE}'
  where t1.dt = '${DATE}'
  and t3.max_week_of_year is not null
  and t1.distince<=3000
  and t1.distince>1
  group by
  t1.a_store_code
  ),

  group_level_new as
  (
  select
  t1.*
  ,case when t1.gap_day >=1 and t1.hc_short_day =1 then 1 else 0 end as gap_short_day
  ,case when t1.gap_night >=1 and t1.hc_short_night =1 then 1 else 0 end as gap_short_night
  ,case
          when (t1.full_capacity_day>=1 and t1.gap_day<=0) or (t1.gap_day<=0 )then 'Q1'
          when t1.full_capacity_day<0.8 and t1.fte_day<=1 and t3.is_upgrade_paiban_pre = 1 then 'Q6'
          when t1.hc_day >= 3 and t1.gap_day = 1 and t1.hc_short_day =1 and t1.gap_new = 1 then 'Q3'
          when t1.full_capacity_day<0.8 and t1.fte_day<=1  then 'Q5'
          when t1.full_capacity_day<0.6 and t2.group_count<=3 and t3.is_upgrade_paiban_pre = 1 then 'Q6'
          when t1.full_capacity_day<0.6 and t2.group_count<=3 then 'Q5'
          when t1.full_capacity_day>=0.8 and t1.full_capacity_day<1 then 'Q2'
          when t1.full_capacity_day>=0.6 and t1.full_capacity_day<0.8 and nvl(t2.full_capacity_day_g,t1.full_capacity_day)>=0.6 then 'Q3'
          when t1.full_capacity_day>=0.4 and t1.full_capacity_day<0.6 and nvl(t2.full_capacity_day_g,t1.full_capacity_day)>=0.6 then 'Q4'
          when t1.full_capacity_day>=0.6 and t1.full_capacity_day<0.8 and nvl(t2.full_capacity_day_g,t1.full_capacity_day)>=0.4 and nvl(t2.full_capacity_day_g,t1.full_capacity_day)<0.6 then 'Q4'
          when t1.full_capacity_day>=0.6 and t1.full_capacity_day<0.8 and nvl(t2.full_capacity_day_g,t1.full_capacity_day)<0.4 and t3.is_upgrade_paiban_pre = 1 then 'Q6'
          when t1.full_capacity_day>=0.6 and t1.full_capacity_day<0.8 and nvl(t2.full_capacity_day_g,t1.full_capacity_day)<0.4 then 'Q5'
          when t1.full_capacity_day>=0.4 and t1.full_capacity_day<0.6 and nvl(t2.full_capacity_day_g,t1.full_capacity_day)<0.6 and t3.is_upgrade_paiban_pre = 1 then 'Q6'
          when t1.full_capacity_day>=0.4 and t1.full_capacity_day<0.6 and nvl(t2.full_capacity_day_g,t1.full_capacity_day)<0.6 then 'Q5'
          when t1.full_capacity_day<0.4 and t3.is_upgrade_paiban_pre = 1 then 'Q6'
          when t1.full_capacity_day<0.4 then 'Q5'
          when (t1.full_capacity_day>=1 and t1.gap_day>0) then 'Q2' -- 0915新增
       else '' end  as group_level

       ,case
          when (t1.full_capacity_new>=1 and t1.gap_new<=0) or (t1.gap_day<=0 )then 'Q1'
          when t1.full_capacity_new<0.8 and t1.fte_new<=1 and t3.is_upgrade_paiban_pre = 1 then 'Q6'
          when t1.full_capacity_new<0.8 and t1.fte_new<=1  then 'Q5'
          when t1.full_capacity_new<0.6 and t2.group_count<=3 and t3.is_upgrade_paiban_pre = 1 then 'Q6'
          when t1.full_capacity_new<0.6 and t2.group_count<=3 then 'Q5'
          when t1.full_capacity_new>=0.8 and t1.full_capacity_new<1 then 'Q2'
          when t1.full_capacity_new>=0.6 and t1.full_capacity_new<0.8 and nvl(t2.full_capacity_new_g,t1.full_capacity_new)>=0.6 then 'Q3'
          when t1.full_capacity_new>=0.4 and t1.full_capacity_new<0.6 and nvl(t2.full_capacity_new_g,t1.full_capacity_new)>=0.6 then 'Q4'
          when t1.full_capacity_new>=0.6 and t1.full_capacity_new<0.8 and nvl(t2.full_capacity_new_g,t1.full_capacity_new)>=0.4 and nvl(t2.full_capacity_new_g,t1.full_capacity_new)<0.6 then 'Q4'
          when t1.full_capacity_new>=0.6 and t1.full_capacity_new<0.8 and nvl(t2.full_capacity_new_g,t1.full_capacity_new)<0.4 and t3.is_upgrade_paiban_pre = 1 then 'Q6'
          when t1.full_capacity_new>=0.6 and t1.full_capacity_new<0.8 and nvl(t2.full_capacity_new_g,t1.full_capacity_new)<0.4 then 'Q5'
          when t1.full_capacity_new>=0.4 and t1.full_capacity_new<0.6 and nvl(t2.full_capacity_new_g,t1.full_capacity_new)<0.6 and t3.is_upgrade_paiban_pre = 1 then 'Q6'
          when t1.full_capacity_new>=0.4 and t1.full_capacity_new<0.6 and nvl(t2.full_capacity_new_g,t1.full_capacity_new)<0.6 then 'Q5'
          when t1.full_capacity_new<0.4 and t3.is_upgrade_paiban_pre = 1 then 'Q6'
          when t1.full_capacity_new<0.4 then 'Q5'
          when (t1.full_capacity_new>=1 and t1.gap_new>0) then 'Q2' -- 0915新增
       else '' end  as group_level_new

    ,case when (t1.fte_day -1)/hc_day <= 0.4 then 1 else 0 end as is_borderline_v0
  from supply_base_4 t1
  left join group_full_capacity t2 on t1.store_code = t2.a_store_code
  left join is_upgrade_q6 t3 on t1.store_code = t3.store_code
  ),


  7day_candidate as
  (
  select
  t2.store_code
  ,sum(t2.delivery_candiddate)  as delivery_candiddate
  ,sum(t2.arrive_store) as arrive_store
  from data_gis_h3.mid_gis_h3_store_recruit_level_da t2
  where t2.dt =  '${DATE_SUB1DAY}'
  and t2.date_key >= '${FDATE_SUB15DAY}'
  group by
  t2.store_code
  ),
  noarrive_days_list as(
  select
  t2.store_code
  ,count(distinct case when t2.arrive_store = 0 then t2.date_key end) as noarrive_days

  from data_gis_h3.mid_gis_h3_store_recruit_level_da t2
  where t2.dt =  '${DATE_SUB1DAY}'
  and t2.date_key >= '${FDATE_SUB14DAY}'
  group by
  t2.store_code
  ),
  store_group_level_list as (
  select
  t1.store_code as store_code,
  t1.store_name as store_name,
  t1.city_name as city_name,
  t1.stores_g as stores_g,
  t1.gap_new as gap_new,
  t2.group_level as group_level,
  t1.reward_level as reward_level
  ,t1.reward_level_night as reward_level_night
  ,from_unixtime(unix_timestamp(t1.dt,'yyyymmdd'),'yyyy-mm-dd') as record_date
  from data_build.dwd_store_construction_store_groups_recruit_gap t1
  left join data_build.dwd_store_construction_full_capacity_perdict t2 on t1.store_code = t2.store_code and t1.dt = t2.dt
  where from_unixtime(unix_timestamp(t1.dt,'yyyymmdd'),'yyyy-mm-dd') >= '${FDATE_SUB30DAY}'
  ),

  kc_days as
  (
  select
   store_code
   ,nvl(count(distinct case when record_date >= date_sub(current_date(),31) then record_date else null end),0) as kc_30
   from data_smartorder.app_roster_report_last_30days_empty_store_list_di
   where dt = '${DATE}'
   and type = '空窗'
   and record_date >= '${FDATE_SUB30DAY}'
   group by store_code
   ),

  longterm_base_1 as
  (
  select
  t1.store_code as store_code,
  t3.delivery_candiddate as delivery_candiddate,
  t3.arrive_store as arrive_store,
  case when t4.kc_30 is not null then t4.kc_30 else 0 end as kc_30,
  count(distinct case when t2.group_level in ('Q1') and t2.record_date between date_sub(current_date(),31) and  date_sub(current_date(),1) then t2.record_date end) as Q1_days_month,
  count(distinct case when t2.group_level in ('Q1') and t2.record_date between date_sub(current_date(),14)  and date_sub(current_date(),1) then t2.record_date end) as Q1_days_2week,
  count(distinct case when t2.group_level in ('Q1')  and t2.record_date between date_sub(current_date(),8)  and date_sub(current_date(),1) then t2.record_date end) as Q1_days_1week,
  count(distinct case when t2.group_level in ('Q5','Q6') and t2.record_date between date_sub(current_date(),31)  and  date_sub(current_date(),1) then t2.record_date end) as Q56_days_month,
  count(distinct case when t2.group_level in ('Q5','Q6')  and t2.record_date between date_sub(current_date(),14)  and  date_sub(current_date(),1) then t2.record_date end) as Q56_days_2week,
  count(distinct case when t2.reward_level in ('P3','P4','P5','P6','P7','P8') and t2.record_date between date_sub(current_date(),31)  and  date_sub(current_date(),1) then t2.record_date end) as P3_days_month,
  count(distinct case when t2.gap_new >=1 and t2.record_date between date_sub(current_date(),14) and  date_sub(current_date(),1) then t2.record_date end) as P3_days_2week,
  count(distinct case when t2.reward_level_night in ('P2','P3','P4','P5','P6','P7','P8') and t2.record_date between date_sub(current_date(),31)  and  date_sub(current_date(),1) then t2.record_date end) as highp_nights_month,
  count(distinct case when t2.reward_level_night in ('P2','P3','P4','P5','P6','P7','P8')  and t2.record_date between date_sub(current_date(),14) and  date_sub(current_date(),1) then t2.record_date end) as highp_nights_2week,
  count(distinct case when t2.reward_level in ('P0','P1') and t2.record_date between date_sub(current_date(),31)  and  date_sub(current_date(),1) then t2.record_date end) as P1_days_month,
  count(distinct case when t2.reward_level in ('P0','P1')  and t2.record_date between date_sub(current_date(),14) and  date_sub(current_date(),1) then t2.record_date end) as P1_days_2week
  from data_build.dwd_store_construction_store_groups_recruit_gap t1
  left join store_group_level_list t2 on t1.store_code = t2.store_code
  left join 7day_candidate t3  on t1.store_code = t3.store_code
  left join kc_days t4 on t1.store_code = t4.store_code
  where t1.dt = '${DATE_SUB1DAY}'
  group by
  t1.store_code,
  t3.delivery_candiddate,
  t3.arrive_store,
  t4.kc_30
  ),

   empty_days_raw as
(
select
work_date work_date
,store_id store_id
,store_name store_name
,store_province store_province
,min(start_time) as start_time
,max(end_time) as end_time
,is_night is_night
,max(nobody_hours) as nobody_hours
from
data_build.dw_roster_effect_roster_detail_info_da_view
where dt = '${DATE}'
and nobody_hours >= 4
and work_date between '${FDATE_SUB7DAY}' and '${FDATE_SUB1DAY}'
and class_id = '0'
and store_type = '0'
and sale_type <> '全天不营业'
group by
work_date
,store_id
,store_name
,store_province
,is_night
),

empty_days_lastweek as
(
select
store_id as store_code
,count(distinct case when nobody_hours >= 4 and is_night = 1 then work_date end ) as night_empty_days
,count(distinct case when nobody_hours >= 4 and is_night = 0 then work_date end ) as day_empty_days
from empty_days_raw
group by
store_id
),

  longterm_base_2 as
  (
  select
  t1.store_code
  ,case when t1.Q1_days_month >= 24 or t1.Q1_days_2week >= 12 then 1 else 0 end as is_longterm_q1
  ,case when t1.Q56_days_month >= 22 or t1.Q56_days_2week >= 10 then 1 else 0 end as is_longterm_q56
  ,case when t1.kc_30 > 4 then 0 else 1 end as is_kc_under_4
    ,case when t1.P3_days_2week >=14 and t1.arrive_store = 0 then 1
  else 0 end as is_update_p4
  ,case when t1.highp_nights_2week >=12 or nvl(t2.night_empty_days,0) >1 then 1
  else 0 end as is_update_night
  from longterm_base_1 t1
  left join empty_days_lastweek t2 on t1.store_code = t2.store_code
  ),

  group_candidtate_transfer as
  (
  select
  t1.a_store_code
  ,count(distinct case when t4.max_week_of_year is not null then t1.b_store_code end) as group_count
  ,sum(case when t4.max_week_of_year is not null then t2.delivery_candiddate end )  as delivery_candiddate
  ,sum(case when t4.max_week_of_year is not null then t2.arrive_store end) as arrive_store

  from data_gis_h3.mid_order_external_same_city_store_riding_distance_type_zero_do_business_union_all_view t1
  left join data_gis_h3.mid_gis_h3_store_recruit_level_da t2 on t2.store_code  = t1.b_store_code and t2.dt = '${DATE_SUB1DAY}'
  left join data_build.dwd_store_construction_roster_store_demand_v1_di t3 on t1.a_store_code = t3.store_id and t3.dt = '${DATE}'
  left join data_build.dwd_store_construction_roster_store_demand_v1_di t4 on t1.b_store_code = t4.store_id and t4.dt = '${DATE}'
  where t1.dt = '${DATE}'
  and t3.max_week_of_year is not null
  and t1.distince<=3000
  and t1.distince>1
  and t2.date_key >= '${FDATE_SUB90DAY}'
  group by
  t1.a_store_code
  ),

  shop_candidate_transfer as
  (
  select
  t1.store_code
  ,sum(t2.delivery_candiddate)  as delivery_candiddate
  ,sum(t2.arrive_store) as arrive_store
  ,case when t3.group_count is not null then t3.group_count else 0 end as group_count
  ,case when t3.delivery_candiddate is not null then t3.delivery_candiddate else 0 end as group_candidate
  ,case when t3.arrive_store is not null then t3.arrive_store else 0 end as group_arrive
  from data_build.dwd_store_construction_store_groups_recruit_gap t1
  left join data_gis_h3.mid_gis_h3_store_recruit_level_da t2 on t1.store_code = t2.store_code and t2.dt = '${DATE_SUB1DAY}'
  left join group_candidtate_transfer t3 on t1.store_code = t3.a_store_code
  where t1.group_level is not null
  and t1.dt =  '${DATE_SUB1DAY}'
  and t2.date_key >= '${FDATE_SUB90DAY}'
  group by
  t1.store_code
  ,t3.group_count
  ,t3.delivery_candiddate
  ,t3.arrive_store
  ),

  shop_difficulty_level_base as
  (
  select
  t1.store_code
  ,case when t1.group_count = 0 then nvl(t1.arrive_store/t1.delivery_candiddate,0.12)
  else 0.3*nvl(t1.arrive_store/t1.delivery_candiddate,0.12) + 0.7*nvl(t1.group_arrive/t1.group_candidate,0.12)
  end as transfer_rate
  ,case when t1.group_count = 0 then t1.delivery_candiddate
  else 0.5*t1.delivery_candiddate + 0.5* t1.group_candidate/t1.group_count
  end as delivery_candidate_count
  from shop_candidate_transfer t1
  ),

  shop_difficulty_level_regular as
  (
  select
  t.store_code
  ,concat('D',round(0.5*t.transfer_rate_level+ 0.5*t.delivery_candidate_level,0)) as difficulty_level
  from(
  select
  t1.store_code
  ,case when t1.transfer_rate <=0.05 then 5
  when t1.transfer_rate <=0.075 then 4
  when t1.transfer_rate <=0.10 then 3
  when t1.transfer_rate <=0.15 then 2
  else 1 end as transfer_rate_level
  ,case when t1.delivery_candidate_count <=10 then 5
  when t1.delivery_candidate_count <=15 then 4
  when t1.delivery_candidate_count <=25 then 3
  when t1.delivery_candidate_count <=40 then 2
  else 1 end as delivery_candidate_level
  from shop_difficulty_level_base t1
  )t
  )
  ,cv_7days as
 (
 select
t2.store_code
,t2.date_key
,sum(t2.delivery_candiddate) as deliver_cv_today
from  data_gis_h3.mid_gis_h3_store_recruit_level_da t2
inner join (
select max(dt) as max_dt
from data_gis_h3.mid_gis_h3_store_recruit_level_da
where dt >= '${DATE}'
and dt <= 20250331
) tmp
on t2.dt = tmp.max_dt
where t2.date_key >= date_sub(from_unixtime(unix_timestamp(t2.dt,'yyyymmdd'),'yyyy-mm-dd'),15)
group by t2.store_code
,t2.date_key
)

,gap_14days  as
(
select t1.store_code
,date_add(from_unixtime(unix_timestamp(t1.dt,'yyyymmdd'),'yyyy-mm-dd'),1)  as record_date
,case when t1.gap_new -t1.gap_short_day = 0 then 1
when t1.gap_new is null then 1
when t2.deliver_cv_today >=1 then 1
else 0 end as deliver_cv_today
,t1.gap_new as gap_new
from data_build.dwd_store_construction_store_groups_recruit_gap t1
left join cv_7days t2 on date_add(from_unixtime(unix_timestamp(t1.dt,'yyyymmdd'),'yyyy-mm-dd'),1)  = t2.date_key and t1.store_code = t2.store_code
where t1.dt >= '${DATE_SUB15DAY}'
and t1.dt < '${DATE}'
)
   ,no_cv_days as
 (
 select
  store_code
  ,record_date
 ,row_number()over(partition by store_code order by record_date desc) as rn
from gap_14days
where deliver_cv_today =1
)

  ,gap_isnotnull_days as
 (
 select
  store_code
  ,record_date
 ,row_number()over(partition by store_code order by record_date asc) as rn
from gap_14days
where gap_new is not null
)

  ,shop_difficulty_level_v2  as
(
select
t1.store_code
,t1.is_longterm_q56
,t1.is_update_p4
,case when nvl(datediff(date_sub(current_date(),1),t4.record_date),15) < nvl(datediff(date_sub(current_date(),1),t2.record_date),15) then nvl(datediff(date_sub(current_date(),1),t4.record_date),15)
else nvl(datediff(date_sub(current_date(),1),t2.record_date),15) end as no_cv_days
,nvl(t3.noarrive_days,14) as noarrive_days
from longterm_base_2 t1
left join no_cv_days t2 on t1.store_code=  t2.store_code and t2.rn = 1
left join gap_isnotnull_days t4 on t1.store_code = t4.store_code and t4.rn = 1
left join noarrive_days_list t3 on t1.store_code=  t3.store_code
)
  ,shop_difficulty_level  as
(
select
t1.store_code
,no_cv_days
,case when t1.no_cv_days = 0 then 'D1'
when t1.no_cv_days < 2 then 'D2'
when t1.no_cv_days < 3 then 'D3'
when t1.no_cv_days < 5 then 'D4'
when t1.no_cv_days < 7 then 'D5'
when t1.no_cv_days < 9 then 'D6'
when t1.no_cv_days < 11 then 'D7'
when t1.no_cv_days < 13 then 'D8'
when t1.no_cv_days >= 14 and t1.noarrive_days = 14 then 'D9'
else 'D2'
end as difficulty_level
from shop_difficulty_level_v2 t1

)
  ,is_high_sale as
  (
  select
   t.store_code
   ,t.store_name
   ,t.avg_amount_21h2
   ,t.avg_amount_2022
   ,t2.final_level
  ,case when t.store_code in ('100000060',
  '100000357','100000231','100005197','100000229','100001202',
  '100001185','100079020','100000025',
  '100001007','100000520','100000059','100000298','101001025',
  '100000085','101000186','100000076','101000132','100001078',
  '101000178','100000665','100003002','100001093',
  '100000525','100000250','100002592','100000236','100000093','100000318',
  '100002513','100005373','100000307','100077008','100000280',
  '100005375','100000221','100002003','100000278','101000220','100079022',
  '100000183','123000077','100000282','100000027','110000132','101000205') then '1'
   else '0' end as is_potential
   ,case
   when nvl(t.avg_amount_21h2,0) >= 12000 or nvl(t.avg_amount_2022,0) >= 10000  then '1' else '0' end as is_highsale
  ,case when  t2.final_level in ('V1','V2','V3','V4') then '1' else '0' end as is_vip
  from
  (
  select
   store_code
   ,store_name
   ,avg(case when sale_date >= '2021-06-01' and sale_date <= '2021-12-31' and payable_price_lessthan_450_for_roster >= 2000 then payable_price_lessthan_450_for_roster else null end) as avg_amount_21h2
   ,avg(case when sale_date >= '2022-01-01' and sale_date <= '2022-12-31' and payable_price_lessthan_450_for_roster >= 2000 then payable_price_lessthan_450_for_roster else null end) as avg_amount_2022
  from data_smartorder.dm_ordering_suggestion_reference_data_store_amt_for_roster_da t
  where dt = '${DATE}'
   and sale_date >= '2021-06-01'
   and store_type = '0'
   and order_cnt_store >= 20 --正常营业店日
   and holiday_type in (1,2) --剔除节假日
  group by store_code,store_name
  )t
  left join data_smartorder.app_ordering_information_system_order_detail_store_sku_da_48_1161_view t2
  on t.store_code = t2.store_code and t2.dt = '${DATE}'
  ),
  after_spring_candidate as
  (
    select
    t2.store_code
    ,sum(t2.delivery_candiddate)  as delivery_candiddate_after
    ,sum(t2.arrive_store)  as arrive_store_after
    from data_gis_h3.mid_gis_h3_store_recruit_level_da t2
    where t2.dt =  '${DATE_SUB1DAY}'

    and t2.date_key >= '2023-01-28'
    group by
    t2.store_code)
 ,reward_level_90days as

  (select *
  ,date_add(from_unixtime(unix_timestamp(dt,'yyyymmdd'),'yyyy-mm-dd'),2) as record_date
  from  data_build.dwd_store_construction_store_groups_recruit_gap
  where date_add(from_unixtime(unix_timestamp(dt,'yyyymmdd'),'yyyy-mm-dd'),1)>= '${FDATE_SUB90DAY}'
  ),
 is_manager_90days as
 (
  select
  store_code as store_code
  ,date_add(from_unixtime(unix_timestamp(dt,'yyyymmdd'),'yyyy-mm-dd'),1) as record_date
  ,case when  structure_status >= 3 then 0 else 1 end as is_has_manager
 from  data_shop.dwa_shop_store_structure_condition_di
  where from_unixtime(unix_timestamp(dt,'yyyymmdd'),'yyyy-mm-dd') >= '${FDATE_SUB90DAY}'
  and store_status < 3
),
manager_90days_count as
(
select
store_code as store_code
,count(distinct case when is_has_manager  = 0 then record_date end) as no_manager_days
from is_manager_90days
group by store_code
),
  t_level_90days as
  (
select
 shop_id  as store_code
 ,alarm_start_date as record_date
 ,final_level_modify as t_level
 ,substr(final_level_modify,2,1) as final_t_level
from data_shop.dwd_ic_new_import_store_level_da_view
where dt = '${DATE_SUB2DAY}'
 and alarm_start_date >= '${FDATE_SUB90DAY}'
 ),
 store_highp_days as --门店名单
  (
  select
  t1.store_code as store_code
  ,count(distinct case when t1.gap_new >=1 then t1.dt end)  as has_gap_days
  ,count(distinct case when t1.gap_new >=1 and from_unixtime(unix_timestamp(t1.dt,'yyyymmdd'),'yyyy-mm-dd')>='${FDATE_SUB30DAY}' then t1.dt end) as has_gap_30days
  ,count(distinct case when t1.reward_level in ('P2','P3','P4','P5','P6','P7','P8') or t1.reward_level_night  in ('P2','P3','P4','P5','P6','P7','P8') then t1.dt end)  as high_level_days
  from data_build.dwd_store_construction_store_groups_recruit_gap t1
  left join data_build.dwd_store_construction_store_groups_recruit_gap t2 on t1.store_code = t2.store_code and t2.dt = '${DATE_SUB1DAY}'
  left join t_level_90days t7 on t1.store_code = t7.store_code and t7.record_date = date_add(from_unixtime(unix_timestamp(t1.dt,'yyyymmdd'),'yyyy-mm-dd'),1)
  left join is_manager_90days t6 on t1.store_code = t6.store_code and t6.record_date = date_add(from_unixtime(unix_timestamp(t1.dt,'yyyymmdd'),'yyyy-mm-dd'),1)

  where from_unixtime(unix_timestamp(t1.dt,'yyyymmdd'),'yyyy-mm-dd') >= '${FDATE_SUB90DAY}'
  and t2.reward_level is not null
  and t6.is_has_manager = 1
  group by t1.store_code
  ),

group_highp_days as
 (
  select
  t1.a_store_code as store_code
  ,t3.has_gap_days as has_gap_days
  ,t3.high_level_days as high_level_days
  ,t3.has_gap_30days as has_gap_30days
  ,count(distinct t1.b_store_code) as group_count
  ,sum(t2.has_gap_days) as has_gap_days_group
  ,sum(t2.high_level_days) as high_level_days_group
  from data_gis_h3.mid_order_external_same_city_store_riding_distance_type_zero_do_business_union_all_view t1
  left join store_highp_days t2 on t2.store_code  = t1.b_store_code
  left join store_highp_days t3 on t3.store_code = t1.a_store_code
  where t1.dt = '${DATE_SUB2DAY}'
  and t3.store_code is not null
  and t2.store_code is not null
  and t1.distince<=1500
  group by
  t1.a_store_code
  ,t3.has_gap_days
  ,t3.high_level_days
  ,t3.has_gap_30days
  ),
  group_candidtate_transfer_new as
  (
  select
  t1.a_store_code as store_code
  ,count(distinct t1.b_store_code) as group_count
  ,sum(t2.delivery_candiddate)  as delivery_cv_all
  ,sum(t2.arrive_store) as arrive_store_all
  ,sum(case when t4.gap_new >=1 then t2.delivery_candiddate end )  as delivery_cv_gap
  ,sum(case when t4.reward_level in ('P2','P3','P4','P5','P6','P7','P8') or t4.reward_level_night  in ('P2','P3','P4','P5','P6','P7','P8') then t2.delivery_candiddate end )  as delivery_cv_highp

  from data_gis_h3.mid_order_external_same_city_store_riding_distance_type_zero_do_business_union_all_view t1
  left join data_gis_h3.mid_gis_h3_store_recruit_level_da t2 on t2.store_code  = t1.b_store_code and t2.dt = 20250331
  left join data_build.dwd_store_construction_store_groups_recruit_gap t3 on t1.a_store_code = t3.store_code and t3.dt = '${DATE_SUB1DAY}'
  left join data_build.dwd_store_construction_store_groups_recruit_gap t5 on t1.b_store_code = t5.store_code and t5.dt = '${DATE_SUB1DAY}'

  left join reward_level_90days t4 on t1.b_store_code = t4.store_code and t4.record_date= t2.date_key
  left join t_level_90days t7 on t1.b_store_code = t7.store_code and t7.record_date = t2.date_key
  left join is_manager_90days t6 on t1.b_store_code = t6.store_code and t6.record_date = t2.date_key
  where t1.dt = '${DATE_SUB2DAY}'
  and t3.reward_level is not null
  and t5.reward_level is not null
  and t6.is_has_manager = 1
  and t1.distince<=1500
  and t2.date_key >= '${FDATE_SUB90DAY}'
  group by
  t1.a_store_code
  )

  ,new_difficulty_level_raw  as
  (
  select
  t1.store_code
  ,t4.has_gap_days as has_gap_days
  ,t4.has_gap_30days as has_gap_30days
  ,t4.high_level_days as high_level_days
  ,t4.high_level_days_group as group_high_level_days
  ,t4.has_gap_days_group as group_has_gap_days
  ,t4.group_count as group_count
  ,sum(t2.delivery_candiddate) as delivery_cv_all
  ,sum(t2.arrive_store) as arrive_store_all
  ,sum(case when t5.gap_new >=1 then t2.delivery_candiddate end ) as delivery_cv_gap
  ,sum(case when t5.reward_level in ('P2','P3','P4','P5','P6','P7','P8') or t5.reward_level_night  in ('P2','P3','P4','P5','P6','P7','P8') then t2.delivery_candiddate end )  as delivery_cv_highp
  ,t3.delivery_cv_all as group_delivery_cv_all
  ,t3.arrive_store_all as group_arrive_store_all
  ,t3.delivery_cv_gap as group_delivery_cv_gap
  ,t3.delivery_cv_highp as group_delivery_cv_highp
  ,t10.no_manager_days as no_manager_days
  from data_build.dwd_store_construction_store_groups_recruit_gap t1
  left join data_gis_h3.mid_gis_h3_store_recruit_level_da t2 on t1.store_code = t2.store_code and t2.dt = '${DATE}'
  left join reward_level_90days t5 on t1.store_code = t5.store_code and t5.record_date = t2.date_key
  left join group_candidtate_transfer_new t3 on t1.store_code = t3.store_code
  left join group_highp_days t4 on t1.store_code = t4.store_code
  left join t_level_90days t7 on t1.store_code = t7.store_code and t7.record_date = t2.date_key
  left join is_manager_90days t6 on t1.store_code = t6.store_code and t6.record_date = t2.date_key
  left join manager_90days_count t10 on t1.store_code = t10.store_code
  where t1.reward_level is not null
  and t6.is_has_manager = 1
  and t1.dt = '${DATE_SUB1DAY}'
  and t2.date_key >= '${FDATE_SUB90DAY}'
  group by
  t1.store_code
  ,t4.has_gap_days
  ,t4.high_level_days
  ,t4.has_gap_days_group
  ,t4.high_level_days_group
  ,t4.group_count
  ,t3.delivery_cv_all
  ,t3.arrive_store_all
  ,t3.delivery_cv_gap
  ,t3.delivery_cv_highp
  ,t10.no_manager_days
  ,t4.has_gap_30days
  )
  ,new_difficulty_level_output as
  (
    select
    store_code
    ,no_manager_days
    ,has_gap_days
    ,has_gap_30days
    ,high_level_days
    ,group_high_level_days
    ,group_has_gap_days
    ,group_count
    ,delivery_cv_all
    ,arrive_store_all
    ,delivery_cv_gap
    ,delivery_cv_highp
    ,group_delivery_cv_all
    ,group_arrive_store_all
    ,group_delivery_cv_gap
    ,group_delivery_cv_highp
    ,case when no_manager_days >= 30 then 'D2.5'
    when high_level_days >=36 and arrive_store_all <=3 and has_gap_30days>=15 then 'D4'
    when high_level_days >= 45 then 'D3'
    when (delivery_cv_all-delivery_cv_gap)/(90-has_gap_days) >=0.22 and has_gap_days<= 60 then 'D1'
 when has_gap_days- high_level_days >=20 and (delivery_cv_gap-delivery_cv_highp)/(has_gap_days-high_level_days) >=0.5 then 'D1'
 else 'D2' end as difficulty_level_new
    from new_difficulty_level_raw
    )
  ,priority_level_new as
  (
  select
  t1.*
  ,t2.is_kc_under_4 as is_kc_under_4
  ,t2.is_update_p4 as is_update_p4
  ,t2.is_update_night as is_update_night
  ,t3.is_highsale as is_highsale
  ,t3.is_vip as is_vip
  ,t3.is_potential as is_potential
  ,t7.difficulty_level_new as difficulty_level_new
  ,nvl(t4.difficulty_level,'D2') as difficulty_level
  ,nvl(t5.delivery_candiddate_after,0) as delivery_candiddate_after
  ,nvl(t5.arrive_store_after,0) as arrive_store_after
  ,case when t2.is_longterm_q1 = 1 or t2.is_longterm_q56 = 1 then 1 else 0 end as is_longterm
  ,case when t1.group_level  = 'Q1' and t2.is_longterm_q1 = 1 then 'Q1L'
  when t1.group_level = 'Q5' and t2.is_longterm_q56 = 1 and  (t3.is_highsale = 1 or t3.is_vip = 1 or t3.is_potential = 1 ) then 'Q5LH'
  when t1.group_level = 'Q6' and t2.is_longterm_q56 = 1 and  (t3.is_highsale = 1 or t3.is_vip = 1 or t3.is_potential = 1 ) then 'Q6LH'
  when t1.group_level = 'Q5' and t2.is_longterm_q56 = 1 then 'Q5L'
  when t1.group_level = 'Q6' and t2.is_longterm_q56 = 1 then 'Q6L'
  when t1.group_level = 'Q5' and (t2.is_longterm_q56 = 0 or t2.is_longterm_q56 is null) then 'Q4'
  when t1.group_level = 'Q6' and  (t2.is_longterm_q56 = 0 or t2.is_longterm_q56 is null)  then 'Q4'
  else t1.group_level end as priority_level
  ,case when t1.group_level_new  = 'Q1' and t2.is_longterm_q1 = 1 then 'Q1L'
  when t1.group_level_new = 'Q5' and t2.is_longterm_q56 = 1 and (t3.is_highsale = 1 or t3.is_vip = 1 or t3.is_potential = 1 ) then 'Q5LH'
  when t1.group_level_new = 'Q6' and t2.is_longterm_q56 = 1 and (t3.is_highsale = 1 or t3.is_vip = 1 or t3.is_potential = 1 ) then 'Q6LH'
  when t1.group_level_new = 'Q5' and t2.is_longterm_q56 = 1 then 'Q5L'
  when t1.group_level_new = 'Q6' and t2.is_longterm_q56 = 1 then 'Q6L'
  when t1.group_level_new = 'Q5' and (t2.is_longterm_q56 = 0 or t2.is_longterm_q56 is null) then 'Q4'
  when t1.group_level_new = 'Q6' and  (t2.is_longterm_q56 = 0 or t2.is_longterm_q56 is null)  then 'Q4'
  else t1.group_level_new end as priority_level_new
  ,nvl(t6.roster_count_1week,0) as roster_count_1week
  ,nvl(t6.roster_count_2week,0) as roster_count_2week
  ,nvl(t6.roster_count_3week,0) as roster_count_3week
  ,nvl(t6.roster_count_4week,0) as roster_count_4week
  ,nvl(t6.roster_count_5week,0) as roster_count_5week
  ,nvl(t6.gap_bonus_day,0) as gap_bonus_day
  ,nvl(t6.gap_bonus_night,0) as gap_bonus_night
  ,nvl(t6.gap_bonus_day,0)+nvl(t6.gap_bonus_night,0) as gap_bonus_new
  ,nvl(t4.no_cv_days,0) as no_cv_days

  from
  group_level_new t1
  left join new_difficulty_level_output t7 on t1.store_code = t7.store_code
  left join longterm_base_2 t2 on t1.store_code = t2.store_code
  left join is_high_sale t3 on t1.store_code = t3.store_code
  left join shop_difficulty_level t4 on t1.store_code = t4.store_code
  left join after_spring_candidate t5 on t1.store_code = t5.store_code
  left join 6week_demand_4 t6 on t1.store_code = t6.store_code
  ),

hc_base_roster as
(select store_id as store_code
,total_label_ld*opening_days as ld_count
,total_label_md*opening_days as md_count
,total_label_sd1*opening_days as sd1_count
,total_label_sd2*opening_days as sd2_count
,total_label_ln*opening_days as ln_count
,total_label_mn*opening_days as mn_count
,total_label_sn1*opening_days as sn1_count
,total_label_sn2*opening_days as sn2_count
,total_label_ld*opening_days + total_label_md*opening_days +total_label_sd1*opening_days as day_count
,round((total_label_ld*opening_days + total_label_md*opening_days +total_label_sd1*opening_days)/6,1) as hc_day
,total_label_ln*opening_days + total_label_mn*opening_days +total_label_sn1*opening_days as night_count
,round((total_label_ln*opening_days + total_label_mn*opening_days +total_label_sn1*opening_days)/6,1) as hc_night
,round(round((total_label_ln*opening_days + total_label_mn*opening_days +total_label_sn1*opening_days)/6,1) + round((total_label_ld*opening_days + total_label_md*opening_days +total_label_sd1*opening_days)/6,1),1) as hc_new

from data_build.dwd_store_construction_roster_store_demand_v1_di
where dt ='${DATE}'
),

  supply_base_roster as
  (
  select
  t2.store_code
  ,t2.hc_day
  ,t2.hc_night
  ,t2.hc_new
  ,case
  when nvl(t1.changye_count,0)>= t2.hc_night then nvl(t1.changye_count,0)
  when nvl(t1.zhongbai_count,0)  + nvl(t1.changbai_count,0) + nvl(t1.duanbai_count,0) >= t2.hc_day then if(nvl(t1.changye_count,0) + nvl(t1.quantian_count,0) >= t2.hc_night,t2.hc_night,nvl(t1.changye_count,0) + nvl(t1.quantian_count,0))
  when nvl(t1.zhongbai_count,0)  + nvl(t1.changbai_count,0) + nvl(t1.duanbai_count,0) + nvl(t1.quantian_count,0) > t2.hc_day
  then if(nvl(t1.changye_count,0) + nvl(t1.zhongbai_count,0)  + nvl(t1.changbai_count,0) + nvl(t1.duanbai_count,0) + nvl(t1.quantian_count,0) - t2.hc_day >= t2.hc_night,t2.hc_night,nvl(t1.changye_count,0) + nvl(t1.zhongbai_count,0)  + nvl(t1.changbai_count,0) + nvl(t1.duanbai_count,0) + nvl(t1.quantian_count,0) - t2.hc_day)
  when nvl(t1.changye_count,0) = 0 and t2.hc_night > 0 and nvl(t1.quantian_count,0) >=1 and nvl(t1.zhongbai_count,0) + nvl(t1.changbai_count,0) + nvl(t1.duanbai_count,0) + nvl(t1.quantian_count,0) >= 2 then 1
  else nvl(t1.changye_count,0) end as fte_night
  ,case
  when nvl(t1.changye_count,0) >= t2.hc_night then nvl(t1.zhongbai_count,0) + nvl(t1.quantian_count,0) + nvl(t1.changbai_count,0) + nvl(t1.duanbai_count,0)
  when nvl(t1.zhongbai_count,0)  + nvl(t1.changbai_count,0) + nvl(t1.duanbai_count,0) >= t2.hc_day then if(nvl(t1.changye_count,0) + nvl(t1.quantian_count,0) >= t2.hc_night,nvl(t1.changye_count,0) + nvl(t1.quantian_count,0) - t2.hc_night +nvl(t1.zhongbai_count,0)  + nvl(t1.changbai_count,0) + nvl(t1.duanbai_count,0),nvl(t1.zhongbai_count,0)  + nvl(t1.changbai_count,0) + nvl(t1.duanbai_count,0))
  when nvl(t1.zhongbai_count,0)  + nvl(t1.changbai_count,0) + nvl(t1.duanbai_count,0) + nvl(t1.quantian_count,0) > t2.hc_day
  then if(nvl(t1.changye_count,0) + nvl(t1.zhongbai_count,0)  + nvl(t1.changbai_count,0) + nvl(t1.duanbai_count,0) + nvl(t1.quantian_count,0) - t2.hc_day >= t2.hc_night,nvl(t1.changye_count,0) + nvl(t1.zhongbai_count,0)  + nvl(t1.changbai_count,0) + nvl(t1.duanbai_count,0) + nvl(t1.quantian_count,0) - t2.hc_night,t2.hc_day)
  when nvl(t1.changye_count,0) = 0 and t2.hc_night > 0 and nvl(t1.quantian_count,0) >=1 and nvl(t1.zhongbai_count,0) + nvl(t1.changbai_count,0) + nvl(t1.duanbai_count,0) + nvl(t1.quantian_count,0) >= 2 then nvl(t1.zhongbai_count,0)  + nvl(t1.changbai_count,0) + nvl(t1.duanbai_count,0) + nvl(t1.quantian_count,0) -1
  else nvl(t1.zhongbai_count,0)  + nvl(t1.changbai_count,0) + nvl(t1.duanbai_count,0) + nvl(t1.quantian_count,0) end as fte_day
  ,nvl(t1.fte_new,0) as fte_new

  from hc_base_roster t2
  left join supply_base_2 t1 on t1.store_code = t2.store_code
  ),

supply_base_roster_output as
(
select
store_code
,hc_day
,hc_night
,hc_new
,fte_new
,case when fte_day in (0.5,1.5,2.5,3.5,4.5,5.5,6.5,7.5,8.5,9.5,10.5) then fte_day
else round(fte_day,0) end as fte_day
,case when fte_day in (0.5,1.5,2.5,3.5,4.5,5.5,6.5,7.5,8.5,9.5,10.5) then fte_new-fte_day
else fte_new - round(fte_day,0) end as fte_night
from supply_base_roster
),

gap_roster_raw as
(
  select
    store_code
  ,hc_day
  ,hc_night
  ,hc_new
  ,round(hc_night-fte_night,1) as gap_night
  ,round(hc_day-fte_day,1) as gap_day
  ,if(round(hc_night-fte_night,1)>=0,round(hc_night-fte_night,1),0)+if(round(hc_day-fte_day,1)>=0,round(hc_day-fte_day,1),0) as gap_new
  ,round(fte_day,1) as fte_day
  ,round(fte_night,1) as fte_night
  ,round(fte_new,1) as fte_new
  ,nvl(fte_night/hc_night,1) as full_capacity_night
  ,nvl(fte_day/hc_day,1) as full_capacity_day
  ,nvl(fte_new/hc_new,1) as full_capacity_new
  from supply_base_roster_output
  ),

city_raw as
(
     select
        a_store_city
        ,case when a_store_city in ('北京市', '上海市', '南京市', '天津市','青岛市', '郑州市') then 5000 else 3000 end as city_distance
    from  data_build.dm_order_external_same_city_store_riding_distance_type_zero_do_business_union_all_view
    where dt = '${DATE}'
    group by a_store_city
    ),

distance_raw as
(
     select
   t1.a_store_code
        ,t1.a_store_city
        ,t1.b_store_code
        ,t1.distince
        ,t2.gap_new as a_gap_new
        ,t2.gap_day  as a_gap_day
        ,t2.gap_night  as a_gap_night
        ,t2.hc_day
,t2.hc_night
,t2.hc_new
,t2.fte_day
,t2.fte_night
,t2.fte_new
,t3.gap_day as b_gap_day
,t3.gap_night as b_gap_night
,t3.gap_new as b_gap_new
,row_number()over(partition by t1.a_store_code order by t3.gap_new desc) as rn
    from  data_build.dm_order_external_same_city_store_riding_distance_type_zero_do_business_union_all_view t1
    left join gap_roster_raw t2 on t1.a_store_code = t2.store_code
    left join gap_roster_raw t3 on t1.b_store_code = t3.store_code
    left join city_raw t4 on t1.a_store_city = t4.a_store_city
    where
    t1.dt= '${DATE}'
    and t1.distince<=t4.city_distance
    and t1.distince>1
    and t2.store_code is not null
    and t3.store_code is not null
    ),

group_type_1 as
(select
t2.store_code as store_code
,t2.gap_new as a_gap_new
,t3.a_store_city as store_city
,nvl(t3.b_gap_new,'-') as b_gap_new
,t2.gap_day  as a_gap_day
,t2.gap_night  as a_gap_night
,nvl(t3.b_gap_day,'-') as b_gap_day
,nvl(t3.b_gap_night,'-') as b_gap_night
,t2.hc_day
,t2.hc_night
,t2.hc_new
,t2.fte_day
,t2.fte_night
,t2.fte_new
,nvl(t3.distince,'-') as ab_distance
,case when t2.gap_day >0.6 or t2.gap_day = '-' then 5
when t2.gap_day >= 0.5 then 3
when  t2.gap_day >=0.3 then 2
when t2.gap_day>= 0.1 then 1
when t2.gap_day = 0 then 0
when t2.gap_day >= -0.2 then -1
when t2.gap_day >= -0.4 then -2
when t2.gap_day >= -0.6 then -3
when t2.gap_day < -0.6 then -5 else '0' end as a_gap_day_type
,case when t2.gap_night >0.6 or t2.gap_night = '-' then 5
when t2.gap_night >= 0.5 then 3
when  t2.gap_night >=0.3 then 2
when t2.gap_night>= 0.1 then 1
when t2.gap_night = 0 then 0
when t2.gap_night >= -0.2 then -1
when t2.gap_night >= -0.4 then -2
when t2.gap_night >= -0.6 then -3
when t2.gap_night < -0.6 then -5 else '0' end as a_gap_night_type
,case when t3.b_gap_day >0.6 or t3.b_gap_day is null then 5
when t3.b_gap_day >= 0.5 then 3
when  t3.b_gap_day >=0.3 then 2
when t3.b_gap_day>= 0.1 then 1
when t3.b_gap_day = 0 then 0
when t3.b_gap_day >= -0.2 then -1
when t3.b_gap_day >= -0.4 then -2
when t3.b_gap_day >= -0.6 then -3
when t3.b_gap_day < -0.6 then -5 else '0' end as b_gap_day_type
,case when t3.b_gap_night >0.6 or t3.b_gap_night is null then 5
when t3.b_gap_night >= 0.5 then 3
when t3.b_gap_night >=0.3 then 2
when t3.b_gap_night>= 0.1 then 1
when t3.b_gap_night = 0 then 0
when t3.b_gap_night >= -0.2 then -1
when t3.b_gap_night >= -0.4 then -2
when t3.b_gap_night >= -0.6 then -3
when t3.b_gap_night < -0.6 then -5 else '0' end as b_gap_night_type
from gap_roster_raw t2
left join distance_raw t3 on t2.store_code = t3.a_store_code and t3.rn =1

),

group_type_output as
(
  select
*
,case when a_gap_day_type = 5 and b_gap_day_type >=3  then 4
when a_gap_day_type = 5 then 3
when a_gap_day_type = 3 and b_gap_day_type >=3 then 3
when a_gap_day_type = 3 and b_gap_day_type >='-1' then 2
when a_gap_day_type = 3 then 1
when a_gap_day_type =2 and b_gap_day_type >=0 then 2
when a_gap_day_type =2 then 1
when a_gap_day_type =1 and b_gap_day_type >=1 then 2
when a_gap_day_type =1 then 1
when a_gap_day_type =0 then 1
else 0 end as day_group_type
,case when a_gap_night_type = 5 and b_gap_night_type >=3 then 4
when a_gap_night_type = 5 then 3
when a_gap_night_type = 3 and b_gap_night_type >=3 then 3
when a_gap_night_type = 3 and b_gap_night_type >=1 then 2
when a_gap_night_type = 3 and b_gap_night_type >='-1' then 1
when a_gap_night_type = 3 then 0
when a_gap_night_type =2 and b_gap_night_type >=2 then 2
when a_gap_night_type =2 and b_gap_night_type >=0 then 1
when a_gap_night_type =2 then 0
when a_gap_night_type =1 and b_gap_night_type >=1 then 1
when a_gap_night_type =0 and b_gap_night_type >=2 then 1
else 0 end as night_group_type
,case
when a_gap_day_type = 5 then '缺整数人'
when a_gap_day_type = 3 then '缺3班次'
when a_gap_day_type = 2 then '缺2班次'
when a_gap_day_type = 1 then '缺1班次'
when a_gap_day_type = 0 then '刚好'
when a_gap_day_type = '-1' then '富裕1班次'
when a_gap_day_type = -2 then '富裕2班次'
when a_gap_day_type = -3 then '富裕3班次'
when a_gap_day_type = -5 then '富裕整数人'
when a_gap_day_type = '-' then '孤岛店'
else '-' end as a_gap_day_type_chinese
,case
when a_gap_night_type = 5 then '缺整数人'
when a_gap_night_type = 3 then '缺3班次'
when a_gap_night_type = 2 then '缺2班次'
when a_gap_night_type = 1 then '缺1班次'
when a_gap_night_type = 0 then '刚好'
when a_gap_night_type = '-1' then '富裕1班次'
when a_gap_night_type = -2 then '富裕2班次'
when a_gap_night_type = -3 then '富裕3班次'
when a_gap_night_type = -5 then '富裕整数人'
when a_gap_night_type = '-' then '孤岛店'
else '-' end as a_gap_night_type_chinese
,case
when b_gap_day_type = 5 then '缺整数人'
when b_gap_day_type = 3 then '缺3班次'
when b_gap_day_type = 2 then '缺2班次'
when b_gap_day_type = 1 then '缺1班次'
when b_gap_day_type = 0 then '刚好'
when b_gap_day_type = '-1' then '富裕1班次'
when b_gap_day_type = -2 then '富裕2班次'
when b_gap_day_type = -3 then '富裕3班次'
when b_gap_day_type = -5 then '富裕整数人'
when b_gap_day_type = '-' then '孤岛店'
else '-' end as b_gap_day_type_chinese
,case
when b_gap_night_type = 5 then '缺整数人'
when b_gap_night_type = 3 then '缺3班次'
when b_gap_night_type = 2 then '缺2班次'
when b_gap_night_type = 1 then '缺1班次'
when b_gap_night_type = 0 then '刚好'
when b_gap_night_type = '-1' then '富裕1班次'
when b_gap_night_type = -2 then '富裕2班次'
when b_gap_night_type = -3 then '富裕3班次'
when b_gap_night_type = -5 then '富裕整数人'
when b_gap_night_type = '-' then '孤岛店'
else '-' end as b_gap_night_type_chinese
from group_type_1
)

,district_hc_new as
(
select
t2.business_district_id as district_code
,count(distinct t1.store_code )as store_count
,round(sum(case when t1.day_group_type in (1,2,3,5) then t1.a_gap_day_type else 0 end)/5,0) as roster_hc_day
,round(sum(case when t1.night_group_type in (1,2,3,5) then t1.a_gap_night_type else 0 end)/5,0) as roster_hc_night

,round(sum(case when t1.day_group_type in (1,2,3,5) then t1.a_gap_day_type else 0 end)/5,0)
+ round(sum(case when t1.night_group_type in (1,2,3,5) then t1.a_gap_night_type else 0 end)/5,0) as roster_hc_all
from group_type_output t1
left join data_smartorder.ods_uploads_business_district_qiyang t2 on t1.store_code = t2.store_code
group by t2.business_district_id
)

,district_hc_short as
(
select
t2.business_district_id as district_code
,sum(case when t3.gap_day >=1 then t3.hc_short_day else 0 end)
+ sum(case when t3.gap_night >=1 then t3.hc_short_night else 0 end) as roster_short_all
from priority_level_new t3
left join data_smartorder.ods_uploads_business_district_qiyang t2 on t3.store_code = t2.store_code
group by t2.business_district_id
)

,district_hc as
(
select
t1.district_code as district_code
,nvl(t1.roster_hc_all,0)+nvl(t2.roster_short_all,0) as roster_hc_all
,t1.roster_hc_day as roster_hc_day
,t1.roster_hc_night as roster_hc_night
from district_hc t1
left join district_hc_short t2 on t1.district_code = t2.district_code
)

,fail_roster_detail as
(
select
work_date work_date
,roster_id roster_id
,store_id store_id
,t1.store_name store_name
,store_city store_city
,store_province store_province
,start_time as start_time
,end_time as end_time
,is_night is_night
,work_hours work_hours
,t2.business_district_id as district_code
,t3.day_of_week_name
from
data_build.dw_roster_effect_roster_detail_info_da_view t1
left join data_smartorder.ods_uploads_business_district_qiyang t2 on t1.store_id = t2.store_code
left join dim_date_ya_v2 t3 on from_unixtime(unix_timestamp(t1.dt,'yyyyMMdd'),'yyyy-MM-dd') = t3.date_key
where t1.dt =  '${DATE_ADD1DAY}'
and roster_source = '失败班表'
and work_date between date_sub(next_day('${FDATE_ADD1DAY}','mon'),7) and date_sub(next_day('${FDATE_ADD1DAY}','mon'),1)
and class_id = '0'
and store_type = '0'
and sale_type <> '全天不营业'
and work_hours >= 4
and t3.day_of_week_name in ('星期一','星期二','星期三')

union

select
work_date work_date
,roster_id roster_id
,store_id store_id
,t1.store_name store_name
,store_city store_city
,store_province store_province
,start_time as start_time
,end_time as end_time
,is_night is_night
,work_hours work_hours
,t2.business_district_id as district_code
,t3.day_of_week_name
from
data_build.dw_roster_effect_roster_detail_info_da_view t1
left join data_smartorder.ods_uploads_business_district_qiyang t2 on t1.store_id = t2.store_code
left join dim_date_ya_v2 t3 on from_unixtime(unix_timestamp(t1.dt,'yyyyMMdd'),'yyyy-MM-dd') = t3.date_key

where t1.dt =  '${DATE_ADD1DAY}'
and roster_source = '失败班表'
and work_date between next_day('${FDATE_ADD1DAY}','mon') and date_add(next_day('${FDATE_ADD1DAY}','mon'),6)
and class_id = '0'
and store_type = '0'
and sale_type <> '全天不营业'
and work_hours >= 4
and t3.day_of_week_name not in ('星期一','星期二','星期三')
)

,success_roster_detail as
(
select
work_date work_date
,roster_id roster_id
,store_id store_id
,t1.store_name store_name
,store_city store_city
,store_province store_province
,start_time as start_time
,end_time as end_time
,is_night is_night
,work_hours work_hours
,employee_id as employee_id
,t3.day_of_week_name
from
data_build.dw_roster_effect_roster_detail_info_da_view t1
left join dim_date_ya_v2 t3 on from_unixtime(unix_timestamp(t1.dt,'yyyyMMdd'),'yyyy-MM-dd') = t3.date_key
where t1.dt =  '${DATE_ADD1DAY}'
and roster_source = '成功班表'
and work_date between date_sub(next_day('${FDATE_ADD1DAY}','mon'),7) and date_sub(next_day('${FDATE_ADD1DAY}','mon'),1)
and class_id = '0'
and store_type = '0'
and sale_type <> '全天不营业'
and work_hours >= 4
and t3.day_of_week_name in ('星期一','星期二','星期三')

union

select
work_date work_date
,roster_id roster_id
,store_id store_id
,t1.store_name store_name
,store_city store_city
,store_province store_province
,start_time as start_time
,end_time as end_time
,is_night is_night
,work_hours work_hours
,employee_id as employee_id

,t3.day_of_week_name
from
data_build.dw_roster_effect_roster_detail_info_da_view t1

left join dim_date_ya_v2 t3 on from_unixtime(unix_timestamp(t1.dt,'yyyyMMdd'),'yyyy-MM-dd') = t3.date_key

where t1.dt =  '${DATE_ADD1DAY}'
and roster_source = '成功班表'
and work_date between next_day('${FDATE_ADD1DAY}','mon') and date_add(next_day('${FDATE_ADD1DAY}','mon'),6)
and class_id = '0'
and store_type = '0'
and sale_type <> '全天不营业'
and work_hours >= 4
and t3.day_of_week_name not in ('星期一','星期二','星期三')
)
,success_roster_count as
(
select
employee_id
,count(distinct roster_id) as roster_count
from success_roster_detail
group by employee_id
)

,fail_roster_hc as
(
select district_code as district_code
,round(count(distinct roster_id)/6,0) as fail_roster_count_all
,round(count(distinct case when is_night = 1 then roster_id end)/6,0) as fail_roster_count_night
,round(count(distinct case when is_night = 0 then roster_id end)/6,0) as fail_roster_count_day
from fail_roster_detail
group by district_code
)

,flexible_onjob_detail as  --20240514 added
(
select
t1.emplid
,t1.name
,t1.hps_d_jobcode
,t1.hps_hire_type
,t1.hps_hire_dt
,t1.hps_sys_name
,t1.hps_dept_code_lv5
,t1.hps_dept_descr_lv5
,case t1.hps_dept_descr_lv5
when '区X001北京' then '1000' when '区X002北京' then '1001'
when '区X003北京' then '1002' when '区X004天津' then '1232'
when '区X005天津' then '1231' when '区X006上海' then '1018'
when '区X007南京' then '1101'
when '区X008杭州' then '1094'when '区X009济南' then '1074'
when '区X010宁波' then '6120' when '区X012青岛' then '1080'
when '区X013北京' then '10012' when '区X014北京' then '10013'
when '区X015北京' then '10014' when '区X016北京' then '10015' when '区X017北京' then '10016'
when '区X018天津' then '1230' when '区X019上海' then '1019'
when '区X020南京' then '1100' when '区X021济南' then '1070'
when '区X024北京' then '10018' when '区X027廊坊' then '1880'
when '区X028石家庄' then '1030' when '区X029郑州' then '1210'
when '区X030常州' then '3970' when '区X031宁波' then '6121'
when '区X032苏州' then '1110' when '区X033无锡' then '1182'
when '区X034金华' then '2330' when '区X035温州' then '2320'
when '区X036北京' then '1003' when '区X037北京' then '1004' when '区X038北京' then '1005'
when '区X039北京' then '1006' when '区X040北京' then '1007' when '区X041北京' then '1008'
when '区X042北京' then '1009' when '区X043北京' then '10010'
when '区X044北京' then '10011'when '区X045北京' then '10017'
when '区X046天津' then '1233' when '区X047天津' then '1234'
when '区X048天津' then '1235' when '区X049天津' then '1236' when '区X050天津' then '1237'
when '区X051天津' then '1238' when '区X052天津' then '1239'
when '区X053常州' then '3971' when '区X054杭州' then '1093'
when '区X055杭州' then '1092' when '区X056杭州' then '1091'
when '区X057杭州' then '1090' when '区X058济南' then '1071'
when '区X059济南' then '1072' when '区X060济南' then '1073'
when '区X061南京' then '1102' when '区X062南京' then '1103'
when '区X063南京' then '1104' when '区X064南京' then '1105' when '区X065南京' then '1106'
when '区X066南京' then '1107' when '区X067郑州' then '1211'
when '区X068无锡' then '1181' when '区X069无锡' then '1180'
when '区X070苏州' then '1113' when '区X071苏州' then '1112'
when '区X072青岛' then '1081' when '区X073青岛' then '1082'
when '区X074宁波' then '6123' when '区X075宁波' then '6122'
when '区X076上海' then '1011' when '区X077上海' then '1012' when '区X078上海' then '1013'
when '区X079上海' then '1014' when '区X080上海' then '1015'
when '区X081上海' then '1016' when '区X082上海' then '1017'
when '区X083上海' then '1018' else t1.hps_dept_descr_lv5 end as district_code
,t2.geiban_label
,t2.is_di
,t2.is_leave_21
,case when t2.is_leave_21 = 1 then 0
  when t2.is_leave_manager_21 = 1 then 0
  when t2.geiban_label = '短白1型' then 0.5
  when t2.available_days >= 5 then 1
  when t2.available_days >= 3 then 0.5
  else 0 end as supply_count
from data_build.pdw_psprod_ps_blf_ehr_pers_vw_view t1
left join data_build.dwd_store_construction_roster_staff_supply_v1_di t2
    on t1.emplid = t2.employee_id and t1.dt = t2.dt
where t1.dt = '${DATE}'
and t1.hps_dept_descr_lv5 like '%区X%'
and t1.hps_d_hr_status ='在职'
)


,district_fte_base_1 as 

  (
  select
    district_code  
  ,sum(case when (is_di = 0 or is_di is null) and geiban_label = '中白型员工' then supply_count end) as zhongbai_count_withoutlow
  ,sum(case when (is_di = 0 or is_di is null) and geiban_label = '短白1型' then supply_count end) as duanbai_count_withoutlow
  ,sum(case when (is_di = 0 or is_di is null) and geiban_label = '全天型员工' then supply_count end) as quantian_count_withoutlow
  ,sum(case when (is_di = 0 or is_di is null) and geiban_label = '长白型员工' then supply_count end) as changbai_count_withoutlow
  ,sum(case when (is_di = 0 or is_di is null) and geiban_label = '长夜型员工' then supply_count end) as changye_count_withoutlow
  ,sum(case when (is_di = 0 or is_di is null) then supply_count end) as fte_new_withoutlow
  from flexible_onjob_detail
  group by district_code
  )

  ,district_fte_base_3 as
  (select


  t2.district_code
  ,t2.roster_hc_day
  ,t2.roster_hc_night
  ,t2.roster_hc_all
  ,case
  when nvl(t1.changye_count_withoutlow,0)>= t2.roster_hc_night then nvl(t1.changye_count_withoutlow,0)
  when nvl(t1.zhongbai_count_withoutlow,0)  + nvl(t1.changbai_count_withoutlow,0) + nvl(t1.duanbai_count_withoutlow,0) >= t2.roster_hc_day then if(nvl(t1.changye_count_withoutlow,0) + nvl(t1.quantian_count_withoutlow,0) >= t2.roster_hc_night,t2.roster_hc_night,nvl(t1.changye_count_withoutlow,0) + nvl(t1.quantian_count_withoutlow,0))
  when nvl(t1.zhongbai_count_withoutlow,0)  + nvl(t1.changbai_count_withoutlow,0) + nvl(t1.duanbai_count_withoutlow,0) + nvl(t1.quantian_count_withoutlow,0) > t2.roster_hc_day
  then if(nvl(t1.changye_count_withoutlow,0) + nvl(t1.zhongbai_count_withoutlow,0)  + nvl(t1.changbai_count_withoutlow,0) + nvl(t1.duanbai_count_withoutlow,0) + nvl(t1.quantian_count_withoutlow,0) - t2.roster_hc_day >= t2.roster_hc_night,t2.roster_hc_night,nvl(t1.changye_count_withoutlow,0) + nvl(t1.zhongbai_count_withoutlow,0)  + nvl(t1.changbai_count_withoutlow,0) + nvl(t1.duanbai_count_withoutlow,0) + nvl(t1.quantian_count_withoutlow,0) - t2.roster_hc_day)
  when nvl(t1.changye_count_withoutlow,0) = 0 and t2.roster_hc_night > 0 and nvl(t1.quantian_count_withoutlow,0) >=1 and nvl(t1.zhongbai_count_withoutlow,0) + nvl(t1.changbai_count_withoutlow,0) + nvl(t1.duanbai_count_withoutlow,0) + nvl(t1.quantian_count_withoutlow,0) >= 2 then 1
  else nvl(t1.changye_count_withoutlow,0) end as fte_night
  ,case
  when nvl(t1.changye_count_withoutlow,0) >= t2.roster_hc_night then nvl(t1.zhongbai_count_withoutlow,0) + nvl(t1.quantian_count_withoutlow,0) + nvl(t1.changbai_count_withoutlow,0) + nvl(t1.duanbai_count_withoutlow,0)
  when nvl(t1.zhongbai_count_withoutlow,0)  + nvl(t1.changbai_count_withoutlow,0) + nvl(t1.duanbai_count_withoutlow,0) >= t2.roster_hc_day then if(nvl(t1.changye_count_withoutlow,0) + nvl(t1.quantian_count_withoutlow,0) >= t2.roster_hc_night,nvl(t1.changye_count_withoutlow,0) + nvl(t1.quantian_count_withoutlow,0) - t2.roster_hc_night +nvl(t1.zhongbai_count_withoutlow,0)  + nvl(t1.changbai_count_withoutlow,0) + nvl(t1.duanbai_count_withoutlow,0),nvl(t1.zhongbai_count_withoutlow,0)  + nvl(t1.changbai_count_withoutlow,0) + nvl(t1.duanbai_count_withoutlow,0))
  when nvl(t1.zhongbai_count_withoutlow,0)  + nvl(t1.changbai_count_withoutlow,0) + nvl(t1.duanbai_count_withoutlow,0) + nvl(t1.quantian_count_withoutlow,0) > t2.roster_hc_day
  then if(nvl(t1.changye_count_withoutlow,0) + nvl(t1.zhongbai_count_withoutlow,0)  + nvl(t1.changbai_count_withoutlow,0) + nvl(t1.duanbai_count_withoutlow,0) + nvl(t1.quantian_count_withoutlow,0) - t2.roster_hc_day >= t2.roster_hc_night,nvl(t1.changye_count_withoutlow,0) + nvl(t1.zhongbai_count_withoutlow,0)  + nvl(t1.changbai_count_withoutlow,0) + nvl(t1.duanbai_count_withoutlow,0) + nvl(t1.quantian_count_withoutlow,0) - t2.roster_hc_night,t2.roster_hc_day)
  when nvl(t1.changye_count_withoutlow,0) = 0 and t2.roster_hc_night > 0 and nvl(t1.quantian_count_withoutlow,0) >=1 and nvl(t1.zhongbai_count_withoutlow,0) + nvl(t1.changbai_count_withoutlow,0) + nvl(t1.duanbai_count_withoutlow,0) + nvl(t1.quantian_count_withoutlow,0) >= 2 then nvl(t1.zhongbai_count_withoutlow,0)  + nvl(t1.changbai_count_withoutlow,0) + nvl(t1.duanbai_count_withoutlow,0) + nvl(t1.quantian_count_withoutlow,0) -1
  else nvl(t1.zhongbai_count_withoutlow,0)  + nvl(t1.changbai_count_withoutlow,0) + nvl(t1.duanbai_count_withoutlow,0) + nvl(t1.quantian_count_withoutlow,0) end as fte_day
  ,nvl(t1.fte_new_withoutlow,0) as fte_new
  from district_hc_new t2
  left join district_fte_base_1 t1 on t1.district_code = t2.district_code
  )



,flexible_onjob_count as
(select
district_code
,fte_new as flexible_count
,fte_day as flexible_count_day
,fte_night as flexible_count_night

from  district_fte_base_3
)

,distirct_replace_count as
(select
t2.business_district_id as district_code
,count(distinct t1.store_id )as store_count
,count(distinct t3.employee_id ) as employee_count
,count(distinct case when t3.is_manager = 0 then t3.employee_id end) as staff_count
,round(sum(case when t3.protect_tag in ('应离职','末位普通') and t3.is_di <> 'blacklist' then t4.roster_count end)/6,0)  as replace_count

from data_build.dwd_store_construction_roster_store_demand_v1_di t1
left join data_smartorder.ods_uploads_business_district_qiyang t2 on t1.store_id = t2.store_code
left join data_build.dwd_store_construction_roster_staff_supply_v1_di t3 on t1.store_id  = t3.store_code and t3.dt = '${DATE}'
left join success_roster_count t4 on t3.employee_id = t4.employee_id
where t1.dt = '${DATE}'
group by t2.business_district_id
)

,district_reward_level_original as --20240513 change
(
select
t1.district_code as district_code
,t1.roster_hc_all as hc_all_district
,t1.roster_hc_night as hc_night_district
,t1.roster_hc_day as hc_day_district
,nvl(t2.flexible_count,0) as flexible_count
,nvl(t2.flexible_count_day,0) as flexible_count_day
,nvl(t2.flexible_count_night,0) as flexible_count_night

,case when nvl(t2.flexible_count_day,0) -t1.roster_hc_day-nvl(t3.fail_roster_count_day,0) >= 0 then -(nvl(t2.flexible_count_day,0) -t1.roster_hc_day-nvl(t3.fail_roster_count_day,0))
when nvl(t2.flexible_count_day,0) -t1.roster_hc_day >= 0  then if(nvl(t3.fail_roster_count_day,0)>5,5,greatest(nvl(t3.fail_roster_count_day,0)-1,0))
else greatest(t1.roster_hc_day -nvl(t2.flexible_count_day,0),if(nvl(t3.fail_roster_count_day,0)>5,5,greatest(nvl(t3.fail_roster_count_day,0)-1,0))) end as gap_all_district_day_original
,case when nvl(t2.flexible_count_night,0) -t1.roster_hc_night-nvl(t3.fail_roster_count_night,0) >= 0 then -(nvl(t2.flexible_count_night,0) -t1.roster_hc_night-nvl(t3.fail_roster_count_night,0))
when nvl(t2.flexible_count_night,0) -t1.roster_hc_night >= 0  then if(nvl(t3.fail_roster_count_night,0)>5,5,greatest(nvl(t3.fail_roster_count_night,0)-1,0))
else greatest(t1.roster_hc_night -nvl(t2.flexible_count_night,0),if(nvl(t3.fail_roster_count_night,0)>5,5,greatest(nvl(t3.fail_roster_count_night,0)-1,0))) end as gap_all_district_night_original

from district_hc_new t1
left join flexible_onjob_count t2 on t1.district_code = t2.district_code
left join fail_roster_hc t3 on t1.district_code = t3.district_code
)

,district_reward_level_3 as
(
select
t1.district_code
,t1.hc_all_district
,t1.hc_night_district
,t1.hc_day_district
,t1.flexible_count
,t1.flexible_count_day
,t1.flexible_count_night
,t1.gap_all_district_day_original as gap_all_district_day
,t1.gap_all_district_night_original as gap_all_district_night
,t1.gap_all_district_day_original + t1.gap_all_district_night_original + nvl(t2.replace_count,0) as gap_all_district

from district_reward_level_original t1
left join distirct_replace_count t2 on t1.district_code = t2.district_code

)



,district_reward_level as
(
select
district_code
,hc_all_district
,hc_night_district
,hc_day_district
,flexible_count
,flexible_count_day
,flexible_count_night
,gap_all_district_day
,gap_all_district_night
,gap_all_district
,case when gap_all_district <= 1 then 'P1'
when gap_all_district >= 5 then 'P5'
when gap_all_district >= 10 then 'P7' else 'P3' end as reward_level_district
,case when gap_all_district_night <= 1 then 'P1'
when gap_all_district_night >= 5 then 'P5'
when gap_all_district_night >= 10 then 'P7' else 'P3' end as reward_level_night_district

from district_reward_level_3
)





,priority_level_raw as (
    select
  store_code as store_code
  ,nvl(difficulty_level,'D2') as difficulty_level
  ,difficulty_level_new as difficulty_level_new
  ,group_level as group_level
  ,priority_level as priority_level
    ,case when priority_level = 'Q1L' and is_kc_under_4 = 1 and gap_night = 0 and difficulty_level in ('D1','D2','D3') then 'P0'
  when gap_day = 0 then 'P1'
  when gap_day = 1 and gap_short_day = 1 and difficulty_level in ('D1','D2','D3') then 'P1'
  when gap_day = 1 and gap_short_day = 1 and difficulty_level in ('D4','D5','D6') then 'P2'
  when gap_day = 1 and gap_short_day = 1 and difficulty_level in ('D7','D8','D9') then 'P3'
  when priority_level = 'Q1L' then 'P1'
  when priority_level in ('Q1','Q2') then 'P1'
  when priority_level = 'Q3' and difficulty_level in ('D1','D2','D3') then 'P1'
  when priority_level = 'Q4' and difficulty_level in ('D1','D2','D3') then 'P1'
  when priority_level in('Q5LH','Q6LH') and difficulty_level in ('D9') then 'P8'
   when priority_level in('Q6LH') and difficulty_level in ('D8') then 'P8'
   when priority_level in('Q6L') and difficulty_level in ('D9') then 'P7'
   when priority_level in('Q6LH') and difficulty_level in ('D7') then 'P7'
   when priority_level in('Q5LH') and difficulty_level in ('D8')  then 'P7'

  when priority_level = 'Q5L' and difficulty_level in ('D9')  then 'P6'
    when priority_level = 'Q6L' and difficulty_level in ('D8')  then 'P6'
  when priority_level in('Q6LH') and difficulty_level in ('D6')  then 'P6'
  when priority_level in('Q6L','Q5LH') and difficulty_level in ('D7')  then 'P6'

  when priority_level = 'Q4' and difficulty_level in ('D9')  then 'P5'
  when priority_level = 'Q5L' and difficulty_level in ('D7','D8')  then 'P5'
  when priority_level in('Q6L','Q5LH') and difficulty_level in ('D6')  then 'P5'
  when priority_level = 'Q4' and difficulty_level in ('D8')  then 'P4'
  when priority_level = 'Q5L' and difficulty_level in ('D6')  then 'P4'
   when priority_level in('Q6LH') and difficulty_level in ('D4')  then 'P4'
   when priority_level in('Q6L','Q5LH') and difficulty_level in ('D5')  then 'P4'

  when priority_level = 'Q6LH' and difficulty_level in ('D1','D2','D3')  then 'P3'
  when priority_level = 'Q5LH' and difficulty_level in ('D1','D2','D3','D4')  then 'P3'
  when priority_level = 'Q6L' and difficulty_level in ('D4')  then 'P3'
  when priority_level = 'Q5L' and difficulty_level in ('D4','D5')  then 'P3'
  when priority_level = 'Q4' and difficulty_level in ('D6','D7')  then 'P3'
 when priority_level = 'Q3' and difficulty_level in ('D7','D8','D9')  then 'P3'

  when priority_level = 'Q3' and difficulty_level in ('D4','D5','D6')  then 'P2'
  when priority_level = 'Q4' and difficulty_level in ('D4','D5')  then 'P2'
  when priority_level in('Q5L','Q6L') and difficulty_level in ('D1','D2','D3')  then 'P2'
  else 'P1' end as reward_level

    ,case when gap_night =0 then 'P1'
  when gap_night >1 and difficulty_level in ('D9') then 'P8'
  when gap_night = 1 and difficulty_level in ('D1','D2','D3') then 'P2'
   when gap_night = 1 and difficulty_level in ('D4','D5','D6') then 'P3'
    when gap_night = 1 and difficulty_level in ('D7') then 'P4'
    when gap_night = 1 and difficulty_level in ('D8') then 'P5'
    when gap_night = 1 and difficulty_level in ('D9') then 'P6'
  when gap_night = 2 and difficulty_level in ('D1','D2','D3') then 'P2'
  when gap_night = 2 and difficulty_level in ('D4','D5') then 'P3'
  when gap_night = 2 and difficulty_level in ('D6') then 'P5'
  when gap_night = 2 and difficulty_level in ('D7') then 'P6'
  when gap_night = 2 and difficulty_level in ('D8') then 'P7'
  when gap_night >=3 and difficulty_level in ('D1','D2','D3') then 'P3'
  when gap_night  >=3 and difficulty_level in ('D4','D5') then 'P4'
   when gap_night  >=3 and difficulty_level in ('D6') then 'P6'
    when gap_night  >=3 and difficulty_level in ('D7') then 'P7'
     when gap_night >=3 and difficulty_level in ('D8') then 'P8'
  else 'P1' end as reward_level_night
  ,is_highsale as is_highsale
  ,is_vip as is_vip
  ,is_potential as is_potential
  ,is_longterm as is_longterm
  ,case when priority_level = 'Q1L' and is_borderline_v0 = 1 then 1
  when priority_level in('Q1','Q2','Q3') and is_borderline_v0 = 1 then 1
  when priority_level = 'Q4' and difficulty_level in ('D1','D2','D3') and is_borderline_v0 = 1 then 1
  else 0 end as is_borderline
  ,nvl(hc_day,0) as hc_day
  ,nvl(hc_night,0) as hc_night
  ,nvl(hc_new,0) as hc_new
  ,nvl(fte_day,0) as fte_day
  ,nvl(fte_night,0) as fte_night
  ,nvl(fte_new,0) as fte_new
  ,nvl(gap_day,0) as gap_day
  ,nvl(gap_night,0) as gap_night
  ,nvl(gap_new,0) as gap_new
  ,gap_bonus_day as gap_bonus_day
  ,gap_bonus_night as gap_bonus_night
  ,gap_bonus_new as gap_bonus_new
  ,roster_count_1week as roster_count_1week
  ,roster_count_2week as roster_count_2week
  ,roster_count_3week as roster_count_3week
  ,roster_count_4week as roster_count_4week
  ,roster_count_5week as roster_count_5week
  ,nvl(gap_short_day,0) as gap_short_day
  ,nvl(gap_short_night,0) as gap_short_night
  ,nvl(full_capacity_day,1) as full_capacity_day
  ,nvl(full_capacity_night,1) as full_capacity_night
  ,nvl(full_capacity_new,1) as full_capacity_new
  ,nvl(fte_day_withoutlow,0) as fte_day_withoutlow
  ,nvl(fte_night_withoutlow,0) as fte_night_withoutlow
  ,nvl(fte_new_withoutlow,0) as fte_new_withoutlow
  ,nvl(gap_day_withoutlow,0) as gap_day_withoutlow
  ,nvl(gap_night_withoutlow,0) as gap_night_withoutlow
  ,nvl(gap_new_withoutlow,0) as gap_new_withoutlow
  ,nvl(full_capacity_day_withoutlow,1) as full_capacity_day_withoutlow
  ,nvl(full_capacity_night_withoutlow,1) as full_capacity_night_withoutlow
  ,nvl(full_capacity_new_withoutlow,1) as full_capacity_new_withoutlow
  ,is_extra_hc as is_extra_hc
  ,priority_level_new as priority_level_new
  ,fte_new_miss as fte_new_miss
  ,fte_new_withoutlow_miss as fte_new_withoutlow_miss
  ,nvl(hc_short_day,0) as hc_short_day
  ,nvl(hc_short_night,0) as hc_short_night
  from priority_level_new
  ),

priority_level_output as
(
select
t1.store_code
,t1.difficulty_level
,t1.difficulty_level_new
  ,t1.group_level as group_level
  ,t1.priority_level as priority_level
  ,t1.is_highsale as is_highsale
  ,t1.is_vip as is_vip
  ,t1.is_potential as is_potential
  ,t1.is_longterm as is_longterm
  ,t1.is_borderline as is_borderline
  ,t1.hc_day as hc_day
  ,t1.hc_night as hc_night
  ,t1.hc_new as hc_new
  ,t1.fte_day as fte_day
  ,t1.fte_night as fte_night
  ,t1.fte_new as fte_new
  ,t1.gap_bonus_day as gap_bonus_day
  ,t1.gap_bonus_night as gap_bonus_night
  ,t1.gap_bonus_new as gap_bonus_new
  ,t1.roster_count_1week as roster_count_1week
  ,t1.roster_count_2week as roster_count_2week
  ,t1.roster_count_3week as roster_count_3week
  ,t1.roster_count_4week as roster_count_4week
  ,t1.roster_count_5week as roster_count_5week
  ,t1.gap_short_day as gap_short_day
  ,t1.gap_short_night as gap_short_night
  ,t1.full_capacity_day as full_capacity_day
  ,t1.full_capacity_night as full_capacity_night
  ,t1.full_capacity_new as full_capacity_new
  ,t1.fte_day_withoutlow as fte_day_withoutlow
  ,t1.fte_night_withoutlow as fte_night_withoutlow
  ,t1.fte_new_withoutlow as fte_new_withoutlow
  ,t1.gap_day_withoutlow as gap_day_withoutlow
  ,t1.gap_night_withoutlow as gap_night_withoutlow
  ,t1.gap_new_withoutlow as gap_new_withoutlow
  ,t1.full_capacity_day_withoutlow as full_capacity_day_withoutlow
  ,t1.full_capacity_night_withoutlow as full_capacity_night_withoutlow
  ,t1.full_capacity_new_withoutlow as full_capacity_new_withoutlow
  ,t1.is_extra_hc as is_extra_hc
  ,t1.priority_level_new as priority_level_new
  ,t1.fte_new_miss as fte_new_miss
  ,t1.fte_new_withoutlow_miss as fte_new_withoutlow_miss
,case when t2.day_group_type >= 3 then if(t1.gap_day>=1,t1.gap_day,1) else t1.gap_day end as gap_day
,case when t2.night_group_type >= 3 then if(t1.gap_night>=1,t1.gap_night,1) else t1.gap_night end as gap_night
,case when t2.day_group_type >= 3 and t2.night_group_type >= 3 then if(t1.gap_day>=1,t1.gap_day,1)+if(t1.gap_night>=1,t1.gap_night,1)
      when t2.day_group_type >= 3 then if(t1.gap_day>=1,t1.gap_day,1)+t1.gap_night
      when t2.night_group_type >=3 then if(t1.gap_night>=1,t1.gap_night,1) +t1.gap_day
      else t1.gap_new end as gap_new
,case when t1.reward_level = 'P8' then 'P8'
when t1.reward_level = 'P7' then 'P7'
when t2.day_group_type = 4 then concat('P',substr(substr(t1.reward_level,2,1)+1,1,1))
else t1.reward_level end as reward_level

,case when t1.reward_level_night = 'P8' then 'P8'
 when t1.reward_level_night = 'P7' then 'P7'
when t2.night_group_type = 4 then concat('P',substr(substr(t1.reward_level_night,2,1)+1,1,1))
when t2.night_group_type = 3 then concat('P',if(substr(substr(t1.reward_level_night,2,1),1,1)=1,2,substr(substr(t1.reward_level_night,2,1),1,1)))
else t1.reward_level_night end as reward_level_night
,t1.reward_level as reward_level_retention
,t1.reward_level_night as reward_level_night_retention
,t2.day_group_type as  group_type_day
,t2.night_group_type as group_type_night
,t2.a_gap_day_type as roster_gap_day
,t2.a_gap_night_type as roster_gap_night
,nvl(t4.district_code,0) as district_code
,case when nvl(t4.gap_all_district,0) <= 0 then nvl(t4.hc_all_district,0)
else nvl(t4.flexible_count,0)+nvl(t4.gap_all_district,0) end as hc_all_district
,nvl(t4.hc_night_district,0) as hc_night_district
,nvl(t4.hc_day_district,0) as hc_day_district
,nvl(t4.gap_all_district,0) as gap_all_district
,nvl(t4.gap_all_district_day,0) as gap_day_district
,nvl(t4.gap_all_district_night,0) as gap_night_district
,case when t4.gap_all_district <= 0 then 'P1'
when (t4.hc_all_district-t4.gap_all_district)/t4.hc_all_district >= 0.9 then 'P1'
when (t4.hc_all_district-t4.gap_all_district)/t4.hc_all_district >= 0.5 then 'P2'
when (t4.hc_all_district-t4.gap_all_district)/t4.hc_all_district >= 0.25 then 'P3'
when (t4.hc_all_district-t4.gap_all_district)/t4.hc_all_district >= 0 then 'P5'
else 'P1' end as reward_level_district
,t1.hc_short_day as hc_short_day
  ,t1.hc_short_night as hc_short_night
from priority_level_raw t1
left join group_type_output t2 on t1.store_code = t2.store_code
left join data_smartorder.ods_uploads_business_district_qiyang t3 on t1.store_code = t3.store_code
left join district_reward_level t4 on t3.business_district_id = t4.district_code

)


insert overwrite table ${TABLE_NAME} partition (dt='$DATE')

    select
         distinct
         t3.store_code
        ,0 as b_hc--理想运营HC
        ,0 as a_hc--最低开业HC
        ,0 as store_epidemic_hc
        ,0 as fte_all---全量未剔除
        ,0 as fte_all_ne---全量剔除测温
        ,0 as fte---全量剔除应离职末位普通
        ,0 as fte_ne--剔除应离职末位普通&测温
        ,0 as b_gap
        ,0 as b_full_capacity_perdict_future--不含测温满编率
        ,0 as full_capacity_perdict_future_all---含测温满编率
        ,0 as full_capacity_all---含应离职末位普通的FTE
        ,0 as store_type
        ,0 as fte_nopipe
        ,0 as full_capacity_nopipe---剔除应离职末位普通含测温 不含pipeline
        ,0 as fte_allocation--剔除应离职FTE，含pipeline
        ,0 as full_capacity_allocation-----剔除应离职，含pipeline
        ,0 as fte_all_allocation
        ,0 as full_capacity_all_allocation
        ,difficulty_level as difficulty_level
        ,group_level as group_level
        ,priority_level as priority_level
        ,reward_level as reward_level
        ,reward_level_night as reward_level_night
        ,is_highsale as is_highsale
,is_longterm as is_longterm
,is_borderline as is_borderline
,hc_day as hc_day
,hc_night as hc_night
,hc_new as hc_new
,fte_day as fte_day
,fte_night as fte_night
,fte_new as fte_new
,gap_day_withoutlow
,gap_night_withoutlow
,gap_new_withoutlow
,full_capacity_day as full_capacity_day
,full_capacity_night as full_capacity_night
,full_capacity_new as full_capacity_new
,fte_day_withoutlow as fte_day_withoutlow
,fte_night_withoutlow as fte_night_withoutlow
,fte_new_withoutlow as fte_new_withoutlow
,gap_day
,gap_night
,gap_new
,full_capacity_day_withoutlow as full_capacity_day_withoutlow
,full_capacity_night_withoutlow as full_capacity_night_withoutlow
,full_capacity_new_withoutlow as full_capacity_new_withoutlow
,is_extra_hc as is_extra_hc
,priority_level_new as priority_level_new
,fte_new_miss as fte_new_miss_2
,fte_new_withoutlow_miss as fte_new_withoutlow_miss_2
,gap_bonus_day as gap_bonus_day
,gap_bonus_night as gap_bonus_night
,gap_bonus_new as gap_bonus_new
,roster_count_1week as roster_count_1week
 ,roster_count_2week as roster_count_2week
 ,roster_count_3week as roster_count_3week
 ,roster_count_4week as roster_count_4week
 ,roster_count_5week as roster_count_5week
 ,gap_short_day as gap_short_day
 ,gap_short_night as gap_short_night
,is_vip as is_vip
  ,is_potential as is_potential
,difficulty_level_new as difficulty_level_new
,group_type_day as group_type_day
,group_type_night as group_type_night
,roster_gap_day as roster_gap_day
,roster_gap_night as roster_gap_night
,reward_level_retention as reward_level_retention
,reward_level_night_retention as reward_level_night_retention
,t3.district_code as district_code
,hc_all_district as hc_all_district
,hc_night_district as hc_night_district
,hc_day_district as hc_day_district
,gap_all_district as gap_all_district
,gap_day_district as gap_day_district
,gap_night_district as gap_night_district
,reward_level_district as reward_level_district
,reward_level_district as reward_level_night_district
,case when gap_all_district > 0 then gap_all_district
when t4.replace_count + gap_all_district >0 then 1
else 0 end as gap_with_replace_district
,hc_short_day as hc_short_day
,hc_short_night as hc_short_night
,t4.replace_count as replace_count
    from priority_level_output t3
    left join distirct_replace_count t4 on t3.district_code = t4.district_code
        ;
        -- 验证数据
        ${CHECK_DATA_SQL};

        "
EOF
}