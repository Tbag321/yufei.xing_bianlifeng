#
# --------------------------------------
# DATE: 2022-11-30
# DEV:
# DESC:
# PRODUCT_WIKI:
# --------------------------------------
source ${ETC}/format_date.cnf


TABLE_NAME="data_build.dwd_store_construction_roster_staff_supply_v1_di"
UNIQ_KEY='employee_id,hps_d_jobcode,hps_d_hr_status,week_of_year,geiban_label,available_days,is_di'
HDFS_DIR="/user/data_build/dwd/${TABLE_NAME}/dt=${DATE}"
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
function dwd_store_construction_roster_staff_supply_v1_di_run {
    #主体计算函数
    calculate
}

#清理hdfs文件
function rebuild_hdfs {
    rebuild_hdfs_dir "${HDFS_DIR}"
}

#JOB业务计算函数
function calculate {
   --${HIVE} -e << EOF "
        set hive.cli.errors.ignore=false;

  
  
with
date_info as
(
    select
         date_key  --日历日期
        ,week_of_year --一年第几周
    from data_build.dim_date_ya_v2
    where date_key>='2022-05-23'---标准班型上线
),
available_list as --上周和本周的可用
(
    select distinct
    if(length(staff_code)=6,concat('10',staff_code),staff_code) as staff_code
    ,target_date --日期
    from data_smartorder.dm_roster_staff_available_di t0 --班表日报
    inner join (
select max(dt) as max_dt
from data_smartorder.dm_roster_staff_available_di
where dt >= '${DATE_SUB2DAY}'
and dt <= '${DATE}'
) tmp
on t0.dt = tmp.max_dt --降级处理

where t0.dt >= '${DATE_SUB2DAY}'
    and t0.dt <= '${DATE}'
and t0.is_available_roster = 1 --是否综合考虑可排班
and t0.target_date  >= date_sub(next_day('${FDATE_SUB0DAY}','mon'),14)
and t0.target_date  <= date_sub(next_day('${FDATE_SUB0DAY}','mon'),1)  -- 上周可用天数

),
label_base_geiban as --给班标签（过去一周+本周）
(
    select
         if(length(employee_id)=6,concat('10',employee_id),employee_id) as employee_id
         ,employee_id as employee_id_original
        ,week_of_year
        ,target_date
        ,label
        ,start_time
        ,end_time
        ,(count(hour)-1)*0.5  as hours
    from
    (
        select
             store_code

            ,employee_id
            ,target_date
           -- ,t2.week_of_year
            ,weekofyear(t1.target_date) as week_of_year
            ,start_time
            ,end_time
            ,hour
            ,case
                ---完全标准班型
                when start_time=6  and end_time=22 then '白班'
                when start_time=18 and end_time=32 then '夜班'
                when start_time=6  and end_time=32 then '全班'

                ---重合区间区分
                when start_time<=10 and  end_time-start_time>=21 then '全班'
               -- when hour>=18 and hour<=22 and end_time>24  then '夜班'
               -- when hour>=18 and hour<=22 and end_time<=24 then '白班'

                ---其他区间标签
                when end_time<=24 or start_time<=6 then '白班'
                when end_time>24 then '夜班'
            else 0 end as label
        from  data_build.dwd_store_construction_give_roster_details_half_hour t1
       -- left join date_info t2 on t1.target_date=t2.date_key
        where dt='${DATE}'
        and target_date>= date_sub(next_day('${FDATE_SUB0DAY}','mon'),14)
        and target_date<= date_sub(next_day('${FDATE_SUB0DAY}','mon'),1)
        and is_give=1
    )t
        group by
             if(length(employee_id)=6,concat('10',employee_id),employee_id)
             ,employee_id
        ,week_of_year
        ,target_date
        ,label
        ,start_time
        ,end_time
),

geibandays_base as --给班情况（过去四周+本周）
(
    select
         if(length(employee_id)=6,concat('10',employee_id),employee_id) as employee_id
        ,week_of_year
        ,target_date
        ,start_time
        ,end_time
        ,(count(hour)-1)*0.5  as hours
    from
    (
        select
             store_code
            ,employee_id
            ,target_date
           -- ,t2.week_of_year
            ,weekofyear(t1.target_date) as week_of_year
            ,start_time
            ,end_time
            ,hour
        from  data_build.dwd_store_construction_give_roster_details_half_hour t1
       -- left join date_info t2 on t1.target_date=t2.date_key
        where dt='${DATE}'
        and target_date>= date_sub(next_day('${FDATE_SUB0DAY}','mon'),35)
        and target_date<= date_sub(next_day('${FDATE_SUB0DAY}','mon'),1)
        and is_give=1
    )t
        group by
             if(length(employee_id)=6,concat('10',employee_id),employee_id)
        ,week_of_year
        ,target_date
        ,start_time
        ,end_time
),
protect_tag_list as --保护标签
(
    select
    staff_code
    ,protect_tag
    ,position_class
    ,position_cn
    --,entry_date
    ,protect_tag_detail
    ,total_attend_days
    ,hours
    ,case when position_cn = '学生PT' then '学生PT' else '非学生PT' end as is_student
    ,from_unixtime(unix_timestamp(entry_date,'yyyymmdd'),'yyyy-mm-dd') as entry_date 
    ,case when protect_tag in ('末位普通','应离职') then 1
    when student_suspect = 1 then 1
    when position_cn = '学生PT' then 1
   else 0 end as is_di
    from data_shop.dm_shop_staff_protect_tag_v2
    where dt='${DATE}'
),
manager_list as --店经理清单
(
    select
    if(length(store_manager_no)=6,concat('10',store_manager_no),store_manager_no) as store_manager_no
    ,store_code
    from data_build.dw_ordering_store_tag_location_ranking_info_v1_view
    where dt='${DATE}'
    and store_status_desc = '营业'
),
employee_list_geiban as
(
    select

        employee_id
        ,employee_id_original
        ,label
        ,t1.target_date
        ,case when t2.target_date is not null then 1 else 0 end as is_available
        ,week_of_year
        ,sum(hours) as hours
        ,case
            when label='全班' then 26
            when label='夜班' then 14
            when label='白班' then 16
         else null end as standard_hours
        ,start_time
        ,end_time
    from label_base_geiban t1
    left join available_list t2 on t1.employee_id = t2.staff_code and t1.target_date  = t2.target_date
    group by

        employee_id
        ,employee_id_original
        ,t1.target_date
        ,case when t2.target_date is not null then 1 else 0 end
        ,week_of_year
        ,label
        ,start_time
        ,end_time
),
base_list_geiban as
(
    select

        ---,t2.department_code
        employee_id
        ,employee_id_original
        ,target_date
        ,week_of_year
        ,case
              when label='全班' then '全班'
              when label='白班' and  hours>=10 then '长白_10h'
              when label='白班' and  hours>=8 then '长白_8_10h'
              when label='夜班' and  hours>=10 then '长夜_10h'
              when label='夜班' and  hours>=8 then '长夜_8_10h'
              when label='白班' and  hours>=4 and hours<8 then '短白1'
              when label='夜班' and  hours>=4 and hours<8 then '短夜1'
              when label='白班' and  hours<4  then '短白2'
              when label='夜班' and  hours<4  then '短夜2'
         end as label
        --,standard_hours
        ,start_time
        ,end_time
        ,hours
        --,case when hours>=standard_hours then 1 else 0 end as is_full
        --,hours/standard_hours  as hours_persent
        ---,case when t1.store_code=t2.department_code then 1 else 0 end as is_department
    from employee_list_geiban t1
    left join
    (
        select
            hps_dept_code_lv5
            ,case when length(emplid)<8 then concat_ws('','10',emplid) else emplid end as user_no
        from data_build.pdw_psprod_ps_blf_ehr_pers_vw_view
        where dt='${DATE}'
    )t2
    on t1.employee_id=t2.user_no
    where t1.is_available = 1
),
give_days_hours_base as
(
    select
    employee_id
    ,week_of_year
    ,sum(hours) as give_hours
    ,count(distinct target_date) as give_days
    from
    (
        select
        employee_id
        ,week_of_year
        ,target_date
        ,sum(hours) as hours
        from geibandays_base
        group by employee_id
        ,week_of_year
        ,target_date
    ) tt

    group by employee_id
    ,week_of_year
),
give_days_hours_a as
(
    select
    employee_id
    ,max(week_of_year) as week_of_year
    ,max(give_days) as give_days_max
    ,avg(give_days) as give_days_avg
    from give_days_hours_base
    group by employee_id
),
give_days_hours_b as
(
    select
    t1.employee_id
    ,max(case when t1.week_of_year = t2.week_of_year then give_days else 0 end ) as give_days
    ,max(case when t1.week_of_year = t2.week_of_year then give_hours else 0 end) as give_hours
    from give_days_hours_base t1
    left join give_days_hours_a t2 on t1.employee_id = t2.employee_id
    group by t1.employee_id
),
employee_geiban_performance as
(
    select
         employee_id
         ,employee_id_original
        -- ,week_of_year
        ,count(distinct target_date) as give_days
        ,count(target_date) as give_days1
        ,count(case when label='全班' then target_date end) as ad
        ,count(case when label='长白_10h' then target_date end) as ld_10
        ,count(case when label='长白_8_10h' then target_date end) as ld_8_10
        ,count(case when label='长夜_10h' then target_date end) as ln_10
        ,count(case when label='长夜_8_10h' then target_date end) as ln_8_10
        ,count(case when label='短白1' then target_date end) as sd1
        ,count(case when label='短白2' then target_date end) as sd2
        ,count(case when label='短夜1' then target_date end) as sn1
        ,count(case when label='短夜2' then target_date end) as sn2

        ,count(case when label='全班' then target_date end)/count(distinct target_date)  as p_all
        ,count(case when label='长白_10h' then target_date end)/count(distinct target_date)  as p_ld_10
        ,count(case when label='长白_8_10h' then target_date end)/count(distinct target_date)  as p_ld_8_10

        ,count(case when label='长夜_10h' then target_date end)/count(distinct target_date)  as p_ln_10
        ,count(case when label='长夜_8_10h' then target_date end)/count(distinct target_date)  as p_ln_8_10
        ,count(case when label='短白1' then target_date end)/count(distinct target_date) as p_sd1
        ,count(case when label='短白2' then target_date end)/count(distinct target_date) as p_sd2
        ,count(case when label='短夜1' then target_date end)/count(distinct target_date) as p_sn1
        ,count(case when label='短夜2' then target_date end)/count(distinct target_date) as p_sn2
    from base_list_geiban
    group by
         employee_id
        ,employee_id_original

),
label as
(
    select
         employee_id
        -- ,week_of_year
        ,max(p_s) as max_persent
    from
    (
        select
             employee_id
            -- ,week_of_year
            ,p_sd1  as p_s
        from employee_geiban_performance
        union all
        select
             employee_id
           --  ,week_of_year
            ,p_sd2  as p_s
        from employee_geiban_performance
        union all
        select
             employee_id
            -- ,week_of_year
            ,p_sn1 as p_s
        from employee_geiban_performance
        union all
        select
             employee_id
            -- ,week_of_year
            ,p_sn2 as p_s
        from employee_geiban_performance
        union all
        select
             employee_id
            -- ,week_of_year
            ,p_ln_10 as p_s
        from employee_geiban_performance
        union all
        select
             employee_id
            -- ,week_of_year
            ,p_ln_8_10 as p_s
        from employee_geiban_performance

        union all
        select
             employee_id
            -- ,week_of_year
            ,p_ld_10 as p_s
        from employee_geiban_performance
        union all
        select
             employee_id
            -- ,week_of_year
            ,p_ld_8_10 as p_s
        from employee_geiban_performance
        union all
        select
             employee_id
            -- ,week_of_year
            ,p_all as p_s
        from employee_geiban_performance
    )t1
    group by employee_id
),
label2 as
(
    select
         employee_id
        -- ,week_of_year
        ,max(p_s) as max_persent_s
    from
    (
        select
             employee_id
            -- ,week_of_year
            ,p_sd1  as p_s
        from employee_geiban_performance
        union all
        select
             employee_id
            -- ,week_of_year
            ,p_sd2  as p_s
        from employee_geiban_performance
        union all
        select
             employee_id
            -- ,week_of_year
            ,p_sn1 as p_s
        from employee_geiban_performance
        union all
        select
             employee_id
            -- ,week_of_year
            ,p_sn2 as p_s
        from employee_geiban_performance
    )t1
    group by employee_id
),
label3 as
(
    select
         employee_id
        -- ,week_of_year
        ,max(p_s) as max_persent_l
    from
    (
        select
             employee_id
            -- ,week_of_year
            ,p_ln_10 as p_s
        from employee_geiban_performance
         union all
         select
             employee_id
            -- ,week_of_year
            ,p_ln_8_10 as p_s
        from employee_geiban_performance
        union all
        select
             employee_id
            -- ,week_of_year
            ,p_ld_10 as p_s
        from employee_geiban_performance
        union all
        select
             employee_id
            -- ,week_of_year
            ,p_ld_8_10 as p_s
        from employee_geiban_performance
        union all
        select
             employee_id
            -- ,week_of_year
            ,p_all as p_s
        from employee_geiban_performance
    )t1
    group by employee_id
),
final_geiban as --根据历史给班和可用情况输出的最终标签
(
    select
         t1.employee_id
         ,employee_id_original
        -- ,t1.week_of_year
        ,give_days
        ,give_days1

        ,ad
        ,ld_10
        ,ld_8_10
        ,sd1
        ,sd2
        ,ln_10
        ,ln_8_10
        ,sn1
        ,sn2
        ,p_ld_10
        ,p_ld_8_10
        ,p_sd1
        ,p_sd2
        ,p_ln_10
        ,p_ln_8_10
        ,p_sn1
        ,p_sn2
        ,p_all
        ,case
            when max_persent>=0.75 and max_persent=p_ln_10  then '长夜_10型'
            when max_persent>=0.75 and max_persent=p_ln_8_10  then '长夜_8_10型'
            when max_persent>=0.75 and max_persent=p_ld_10  then '长白_10型'
            when max_persent>=0.75 and max_persent=p_ld_8_10  then '长白_8_10型'
            when max_persent>=0.75 and max_persent=p_sd1 then '短白1型'
            when max_persent>=0.75 and max_persent=p_sd2 then '短白2型'
            when max_persent>=0.75 and max_persent=p_sn1 then '短夜1型'
            when max_persent>=0.75 and max_persent=p_sn2 then '短夜1型'
            when max_persent>=0.75 and max_persent=p_all then '全天型'
            when max_persent<0.75 and (p_all+p_ln_10+p_ln_8_10+p_ld_10+p_ld_8_10)>=0.5 and (p_ld_10+p_ld_8_10)>=0.35 and (p_ln_10+p_ln_8_10)>=0.35 then '全天型'
            when max_persent<0.75 and (p_all+p_ln_10+p_ln_8_10+p_ld_10+p_ld_8_10)>=0.5 and max_persent_l=p_all then '全天型'
            when max_persent<0.75 and (p_all+p_ln_10+p_ln_8_10+p_ld_10+p_ld_8_10)>=0.5 and max_persent_l=p_ln_10  then '长夜_10型'
            when max_persent<0.75 and (p_all+p_ln_10+p_ln_8_10+p_ld_10+p_ld_8_10)>=0.5 and max_persent_l=p_ln_8_10  then '长夜_8_10型'
            when max_persent<0.75 and (p_all+p_ln_10+p_ln_8_10+p_ld_10+p_ld_8_10)>=0.5 and max_persent_l=p_ld_10  then '长白_10型'
            when max_persent<0.75 and (p_all+p_ln_10+p_ln_8_10+p_ld_10+p_ld_8_10)>=0.5 and max_persent_l=p_ld_8_10  then '长白_8_10型'
            when max_persent<0.75 and (p_sd1+p_sd2+p_sn1+p_sn2)>=0.5 and max_persent_s=p_sd1  then '组合供给_短白1型'
            when max_persent<0.75 and (p_sd1+p_sd2+p_sn1+p_sn2)>=0.5 and max_persent_s=p_sd2  then '组合供给_短白2型'
            when max_persent<0.75 and (p_sd1+p_sd2+p_sn1+p_sn2)>=0.5 and max_persent_s=p_sn1  then '组合供给_短夜1型'
            when max_persent<0.75 and (p_sd1+p_sd2+p_sn1+p_sn2)>=0.5 and max_persent_s=p_sn2  then '组合供给_短夜2型'
        else null end as label
    from employee_geiban_performance t1
    left join label  t2 on t1.employee_id=t2.employee_id
    left join label2 t3 on t1.employee_id=t3.employee_id
    left join label3 t4 on t1.employee_id=t4.employee_id
),
b_geiban as
(
    select
         employee_id
         ,employee_id_original
        -- ,week_of_year

        ,give_days
        ,case
            when label in ('长夜_10型','组合供给_长夜型') then '长夜型员工'
            when label in ('长夜_8_10型','组合供给_长夜型') then '中夜型员工'
            when label in ('长白_10型','组合供给_长白型') then '长白型员工'
            when label in ('长白_8_10型','组合供给_长白型') then '中白型员工'
            when label in ('全天型') then '全天型员工'
            when label in ('短白1型','组合供给_短白1型') then '短白1型'
            when label in ('短白2型','组合供给_短白2型') then '短白2型'
            when label in ('短夜2型','组合供给_短夜2型') then '短夜2型'
            when label in ('短夜1型','组合供给_短夜1型') then '短夜1型'
        end as label2
    from final_geiban
  --  where week_of_year>=34 and week_of_year<=37
),

status_original as
(
    select
 t1.hps_dept_code_lv5 as store_code
        ,if(length(t1.emplid)=6,concat('10',t1.emplid),t1.emplid) as employee_id
        ,t1.hps_d_hr_status
        ,t1.hps_d_jobcode
        ,datediff(date_add(from_unixtime(unix_timestamp(t1.dt,'yyyymmdd'),'yyyy-mm-dd'),1),to_date(hps_hire_dt)) as on_job_days
        ,case
when floor(datediff(date_add(from_unixtime(unix_timestamp(t1.dt,'yyyymmdd'),'yyyy-mm-dd'),1),t4.resume_birth_date)/365) is null then 0
when floor(datediff(date_add(from_unixtime(unix_timestamp(t1.dt,'yyyymmdd'),'yyyy-mm-dd'),1),t4.resume_birth_date)/365) <= 22 then 1
else 0 end as is_under_22
,row_number()over(partition by t1.emplid order by t4.order_status_change_time desc) as rn

        from data_build.pdw_psprod_ps_blf_ehr_pers_vw_view t1
        left join data_shop.dw_gis_hire_recruit_detail_v1_di_view t4 on length(t4.entry_user_id) >2 and t1.hps_sys_name = t4.entry_user_id and t4.dt ='${DATE}'

    where t1.dt='${DATE}'
    and t1.hps_d_jobcode in ('店经理','储备店经理','见习店经理','门店伙伴','店副经理','社会PT','学生PT','内部合作经营者','内部合作辅助人','内部合作伙伴','外部合作经营者','外部合作辅助人','外部合作伙伴')
    and t1.hps_d_hr_status = '在职'
),


status_prep as --20240327新增了这里，带店的机动队架构调整到实际带店的门店当中
(
select
dept_code as store_code
,dept_code
,lpad(manager_code,8,'10') as manager_code
,row_number() over(partition by lpad(manager_code,8,'10') order by update_time desc) as rn
from data_build.pdw_opc_shop_ehr_staff_dept_view
where dt= '${DATE_SUB1DAY}'
and dept_type <> 50

),


status as --20240327新增了这里，带店的机动队架构调整到实际带店的门店当中

(
    select 
       t1.employee_id
        ,t1.hps_d_hr_status
        ,t1.hps_d_jobcode
        ,t1.on_job_days
        ,t1.is_under_22
        ,t1.rn
        ,case when t1.store_code <> t2.dept_code and t2.dept_code is not null then t2.dept_code else t1.store_code end as store_code
        from status_original t1
        left join status_prep t2 on t1.employee_id = t2.manager_code and t2.rn = 1 --0909新增，有一个员工(11232591)是两个门店负责人



),


work_days_original_1 as
(
 select
 t1.dt
 ,t1.staff_code
 ,t1.target_date
 ,from_unixtime(unix_timestamp(t1.dt,'yyyyMMdd'),'yyyy-MM-dd') as new_dt
 ,t2.day_of_week_name
 ,t3.is_holiday
 from data_smartorder.dm_roster_staff_available_di t1
 inner join (
select max(dt) as max_dt
from data_smartorder.dm_roster_staff_available_di
where dt >= '${DATE_SUB2DAY}'
and dt <= '${DATE}'
) tmp
on t1.dt = tmp.max_dt
 left join data_build.dim_date_ya_v2 t2
 on from_unixtime(unix_timestamp(t1.dt,'yyyyMMdd'),'yyyy-MM-dd') = t2.date_key
 left join data_build.dim_date_ya_v2 t3
 on t1.target_date = t3.date_key
 where t1.dt >= '${DATE_SUB2DAY}'
    and t1.dt <= '${DATE}'
 and is_available_roster = 1
),

is_holiday_list as( --假期周统计
select
*
,date_sub(date_add(date_key,7 - case when dayofweek(date_key) = 1 then 7 else dayofweek(date_key) - 1 end),6) as holiday_week --假期周
from data_build.dim_date_ya_v2
where is_holiday = '1'
)

,work_days_original_2 as
(
 select
 t1.staff_code
 ,t1.day_of_week_name
 ,t1.target_date
 ,t1.is_holiday
 ,date_sub(next_day(t1.target_date,'mon'),7) as week_date
 ,nvl(t2.holiday_num,0) as holiday_num --当周的节假日天数
 from work_days_original_1 t1
 left join 
 (select
 holiday_week
 ,count(1) as holiday_num --节假日天数
 from is_holiday_list
 group by
 holiday_week
 ) t2 on date_sub(next_day(t1.target_date,'mon'),7) = t2.holiday_week
 where t1.day_of_week_name in ('星期一','星期二')
 and t1.target_date >= date_sub(next_day('${FDATE_SUB0DAY}','mon'),7)
 and t1.target_date <= date_add(next_day('${FDATE_SUB0DAY}','mon'),13) --本周+下周+下下周可用

 union

 select
 t1.staff_code
 ,t1.day_of_week_name
 ,t1.target_date
 ,t1.is_holiday
 ,date_sub(next_day(t1.target_date,'mon'),7) as week_date
 ,nvl(t2.holiday_num,0) as holiday_num --当周的节假日天数
 from work_days_original_1 t1
 left join 
 (select
 holiday_week
 ,count(1) as holiday_num --节假日天数
 from is_holiday_list
 group by
 holiday_week
 ) t2 on date_sub(next_day(t1.target_date,'mon'),7) = t2.holiday_week
 where t1.day_of_week_name not in ('星期一','星期二')
 and t1.target_date >= date_sub(next_day('${FDATE_SUB0DAY}','mon'),0)
 and t1.target_date <= date_add(next_day('${FDATE_SUB0DAY}','mon'),20) --下周+下下周+下下下周可用
),


work_days_original_3 as
(
select
staff_code
,week_date
,holiday_num
,work_days
,holiday_work_days
,row_number()over(partition by staff_code order by week_date) as rn
from(
select
staff_code
,week_date
,holiday_num --当周的节假日天数
,count(distinct target_date) as work_days
,count(case when is_holiday = '1' then target_date else null end) as holiday_work_days --节假日的给班天数
--,row_number()over(partition by staff_code order by week_date desc) as rn
from work_days_original_2
group by staff_code
,week_date
,holiday_num --当周的节假日天数
) a
where holiday_num = holiday_work_days --只保留节假日期间全给班的数据
),

--work_days_original as
--(
--select
--staff_code
--,nvl(sum(case when rn = 1 then work_days end),0) as work_days_1week
--,nvl(sum(case when rn = 2 then work_days end),0) as work_days_2week

--from work_days_original_3
--where holiday_work_days = holiday_num --
--group by
--staff_code
--),
--work_days as --0331作废(店员流失概率表没用了)
--(
--select
--a.staff_code
--,case when b.level = '高' then work_days_1week
-- when b.level is null then work_days_1week
-- when b.level = '低' and work_days_1week > work_days_2week then work_days_1week
-- when b.level = '低' and work_days_1week <= work_days_2week then work_days_2week
-- when b.level = '中' then (work_days_2week+ work_days_1week)/2
-- else work_days_1week end as work_days
--from work_days_original a
--left join data_promotion.dm_ai_clerk_miss_predict_v1_di b on a.staff_code = b.staff_code and b.dt = '${DATE}'
--),

work_days as
(
select
staff_code
,work_days
from work_days_original_3
where rn = 1
),

leave_day as
(
    select
if(length(man_code)=6,concat('10',man_code),man_code) as employee_id
,final_leave_date
,row_number()over(partition by man_code order by final_leave_date desc) as rn
,case when final_leave_date <= date_add('${FDATE_SUB0DAY}',21) and final_leave_date > '${FDATE_SUB0DAY}' then 1 else 0 end as is_leave_21
from data_shop.pdw_gis_workday_dimission_order_view
where dt = '${DATE}'
and order_status <> 'SUSPEND'
and final_leave = 'leave'
and final_leave_date > '${FDATE_SUB0DAY}'
),
leave_manager as
(
select
if(length(current_manager_code)=6,concat('10',current_manager_code),current_manager_code) as current_manager_code
,store_status
,structure_status
,max(t2.final_leave_date) as final_leave_date
,case when max(t2.final_leave_date) <= date_add('${FDATE_SUB0DAY}',21) then 1 else 0 end as is_leave_21

from data_shop.dwa_shop_store_structure_condition_di t1
left join data_shop.pdw_gis_workday_dimission_order_view t2
on if(length(current_manager_code)=6,concat('10',current_manager_code),current_manager_code) = if(length(man_code)=6,concat('10',man_code),man_code)
and t2.dt = '${DATE}'
where
t1.dt = '${DATE}'
and store_status < 3 and structure_status = 3.2

group by if(length(current_manager_code)=6,concat('10',current_manager_code),current_manager_code)
,store_status
,structure_status
),
base_list_chuqin as
(
    select
         t1.att_id
        ,t1.work_shift_id
        ,t1.work_shift_date
        ,t1.work_shift_type
        ,t1.store_code
        ,t1.store_name
        ,t1.dept_code
        ,t1.dept_name
        ,t1.employee_no
        ,t1.employee_name
        ,t1.work_shift_second_desc

        ,t1.work_shift_start_time
        ,t1.work_shift_end_time
        ,(unix_timestamp(t1.work_shift_end_time)-unix_timestamp(t1.work_shift_start_time))/3600 as work_shift_hours

        ,t1.attendance_start_time
        ,t1.attendance_end_time
        ,(unix_timestamp(t1.attendance_end_time)-unix_timestamp(t1.attendance_start_time))/3600 as attendance_hours

        ,t1.is_night
        ,datediff(to_date(work_shift_end_time),to_date(work_shift_start_time)) as work_shift_day
        ,datediff(to_date(attendance_end_time),to_date(attendance_start_time)) as attendance_day
        ,weekofyear(t1.work_shift_date) as week_of_year
    from data_build.dw_roster_attendance_detail_da_view t1
inner join (
select max(dt) as max_dt
from data_build.dw_roster_attendance_detail_da_view
where dt >= '${DATE_SUB2DAY}'
and dt <= '${DATE}'
) tmp
on t1.dt = tmp.max_dt

    where t1.dt >= '${DATE_SUB2DAY}'
    and t1.dt <= '${DATE}'
    and store_type_desc = '门店'
    and work_shift_type in ('1','12','9')
    and work_shift_date>= date_sub(next_day('${FDATE_SUB0DAY}','mon'),21)
    and work_shift_date<= date_sub(next_day('${FDATE_SUB0DAY}','mon'),7)
),

base_chuqin as
(
    select
             t1.att_id
            ,t1.week_of_year
            ,t1.work_shift_id
            ,t1.work_shift_date
            ,t1.work_shift_type
            ,t1.store_code
            ,t1.store_name
            ,t1.dept_code
            ,t1.dept_name
            ,t1.employee_no
            ,t1.employee_name
            ,t1.work_shift_second_desc
            ,t1.work_shift_start_time
            ,t1.work_shift_end_time
            ,t1.attendance_start_time
            ,t1.attendance_end_time
            ,t1.work_shift_hours
            ,t1.attendance_hours
            ,case when work_shift_start_time is null then ''
                when is_night=1 then '夜班'
                when is_night=0 then '白班'
            end as work_shift_label_1
            ,case when work_shift_hours>=10 then '长班_10h'
            -- when work_shift_hours>=10 then '长班_10_12h'
             when work_shift_hours>=8 then '长班_8_10h'
                when work_shift_hours<8 and work_shift_hours>=4 then '短班_4-8H'
                when work_shift_hours<4 then '短班_<4H'
            end as work_shift_label_2

            ,case when attendance_day=1 then '夜班'
                when attendance_day=0 then '白班'
            end as attendance_label_1
            ,case when attendance_hours>=10 then '长班_10h'
               -- when attendance_hours>=10 then '长班_10_12h'
                when attendance_hours>=8 then '长班_8_10h'
                when attendance_hours<8 and attendance_hours>=4 then '短班_4-8H'
                when attendance_hours<4 then '短班_<4H'
            end as attendance_label_2
    from base_list_chuqin t1
),
base_final_chuqin as
(
    select
         t1.store_code
        ,t1.store_name
        ,t1.work_shift_date
        ,t1.employee_no
        ,t1.employee_name
        ,case when work_shift_label_1 not in ('白班','夜班') then attendance_label_1 else work_shift_label_1 end as day_night
        ,case when work_shift_label_2 is null then attendance_label_2 else work_shift_label_2 end as long_short
        ,week_of_year
    from base_chuqin t1
    where attendance_hours is not null
),
chuqin_list1 as
(
    select
         t1.store_code
        ,t1.store_name
        ,t1.work_shift_date
        ,t1.employee_no
        ,t1.employee_name
        ,day_night
        ,long_short
        ,count(work_shift_date) as workdays
        ,case
            when day_night='白班' and long_short='长班_10h' then '长白班_10h'
           -- when day_night='白班' and long_short='长班_10_12h' then '长白班_10_12h'
            when day_night='白班' and long_short='长班_8_10h' then '长白班_8_10h'
            when day_night='白班' and long_short='短班_4-8H' then '短白班1'
            when day_night='白班' and long_short='短班_<4H' then '短白班2'

            when day_night='夜班' and long_short='长班_10h' then '长夜班_10h'
           -- when day_night='夜班' and long_short='长班_10_12h' then '长夜班_10_12h'
            when day_night='夜班' and long_short='长班_8_10h' then '长夜班_8_10h'
            when day_night='夜班' and long_short='短班_4-8H' then '短夜班1'
            when day_night='夜班' and long_short='短班_<4H' then '短夜班2'
        else null end as label
        ,t1.week_of_year
    from base_final_chuqin t1
  --  where t1.week_of_year >25 and t1.week_of_year <33
    group by
         t1.store_code
        ,t1.store_name
        ,t1.work_shift_date
        ,t1.employee_no
        ,t1.employee_name
        ,day_night
        ,long_short
        ,t1.week_of_year
        ,case
            when day_night='白班' and long_short='长班_10h' then '长白班_10h'
           -- when day_night='白班' and long_short='长班_10_12h' then '长白班_10_12h'
            when day_night='白班' and long_short='长班_8_10h' then '长白班_8_10h'
            when day_night='白班' and long_short='短班_4-8H' then '短白班1'
            when day_night='白班' and long_short='短班_<4H' then '短白班2'

            when day_night='夜班' and long_short='长班_10h' then '长夜班_10h'
           -- when day_night='夜班' and long_short='长班_10_12h' then '长夜班_10_12h'
            when day_night='夜班' and long_short='长班_8_10h' then '长夜班_8_10h'
            when day_night='夜班' and long_short='短班_4-8H' then '短夜班1'
            when day_night='夜班' and long_short='短班_<4H' then '短夜班2'
        else null end
),
employee_chuqin_performance as
(
    select
        --t1.store_code
        --,t1.store_name
         t1.employee_no
        ,t1.employee_name
       -- ,t1.week_of_year
        ,count(distinct store_code)      as stores
        ,sum(workdays) as workdays1
        ,count(distinct work_shift_date) as workdays

        ,nvl(sum(case when label='长白班_10h'  then workdays end),0) as ld_10
       -- ,nvl(sum(case when label='长白班_10_12h'  then workdays end),0) as ld_10_12
        ,nvl(sum(case when label='长白班_8_10h'  then workdays end),0) as ld_8_10
        ,nvl(sum(case when label='短白班1' then workdays end),0) as sd1
        ,nvl(sum(case when label='短白班2' then workdays end),0) as sd2

        ,nvl(sum(case when label='长夜班_10h'  then workdays end),0) as ln_10
       -- ,nvl(sum(case when label='长夜班_10_12h'  then workdays end),0) as ln_10_12
        ,nvl(sum(case when label='长夜班_8_10h'  then workdays end),0) as ln_8_10
        ,nvl(sum(case when label='短夜班1' then workdays end),0) as sn1
        ,nvl(sum(case when label='短夜班2' then workdays end),0) as sn2

        ,nvl(sum(case when label='长白班_10h'  then workdays end)/count(distinct work_shift_date),0)  as p_ld_10
       -- ,nvl(sum(case when label='长白班_10_12h'  then workdays end)/count(distinct work_shift_date),0)  as p_ld_10_12
        ,nvl(sum(case when label='长白班_8_10h'  then workdays end)/count(distinct work_shift_date),0)  as p_ld_8_10
        ,nvl(sum(case when label='短白班1' then workdays end)/count(distinct work_shift_date),0)  as p_sd1
        ,nvl(sum(case when label='短白班2' then workdays end)/count(distinct work_shift_date),0)  as p_sd2
       -- ,nvl(sum(case when label='长夜班'  then workdays end)/count(distinct work_shift_date),0)  as p_ln
        ,nvl(sum(case when label='长夜班_10h'  then workdays end)/count(distinct work_shift_date),0)  as p_ln_10
       -- ,nvl(sum(case when label='长夜班_10_12h'  then workdays end)/count(distinct work_shift_date),0)  as p_ln_10_12
        ,nvl(sum(case when label='长夜班_8_10h'  then workdays end)/count(distinct work_shift_date),0)  as p_ln_8_10
        ,nvl(sum(case when label='短夜班1' then workdays end)/count(distinct work_shift_date),0)  as p_sn1
        ,nvl(sum(case when label='短夜班2' then workdays end)/count(distinct work_shift_date),0)  as p_sn2
    from chuqin_list1 t1
    group by
        -- t1.store_code
        --,t1.store_name
         t1.employee_no
        ,t1.employee_name

),
/*
select
     p_ln
    ,count(distinct employee_no)
from t
group by p_ld
*/
chuqin_label as
(
    select
         employee_no
        --,week_of_year
        ,max(p_s) as max_persent
    from
    (
        select
             employee_no
            --,week_of_year
            ,p_sd1  as p_s
        from employee_chuqin_performance
        union all
        select
             employee_no
            --,week_of_year
            ,p_sd2  as p_s
        from employee_chuqin_performance
        union all
        select
             employee_no
            --,week_of_year
            ,p_sn1 as p_s
        from employee_chuqin_performance
        union all
        select
             employee_no
            --,week_of_year
            ,p_sn2 as p_s
        from employee_chuqin_performance
        union all
        select
             employee_no
            --,week_of_year
            ,p_ln_10 as p_s
        from employee_chuqin_performance
        -- union all
        -- select
        --      employee_no
        --   --  ,week_of_year
        --     ,p_ln_10_12 as p_s
        -- from employee_chuqin_performance
        union all
        select
             employee_no
           -- ,week_of_year
            ,p_ln_8_10 as p_s
        from employee_chuqin_performance
        union all
        select
             employee_no
           -- ,week_of_year
            ,p_ld_8_10 as p_s
        from employee_chuqin_performance
        union all
        select
             employee_no
           -- ,week_of_year
            ,p_ld_10 as p_s
        from employee_chuqin_performance
        -- union all
        -- select
        --      employee_no
        --     --,week_of_year
        --     ,p_ld_12 as p_s
        -- from employee_chuqin_performance
    )t1
    group by employee_no
            --,week_of_year
),
final_chuqin as
(
    select
         t1.employee_no
        ,employee_name
        ,workdays1
        ,workdays
        ,ld_10
       -- ,ld_10_12
        ,ld_8_10
        ,sd1
        ,sd2
        ,ln_10
       -- ,ln_10_12
        ,ln_8_10
        ,sn1
        ,sn2
        ,p_ld_10
       -- ,p_ld_10_12
        ,p_ld_8_10
        ,p_sd1
        ,p_sd2
        ,p_ln_10
       -- ,p_ln_10_12
        ,p_ln_8_10
        ,p_sn1
        ,p_sn2
        ,stores
        ,case
            when max_persent>=0.75 and max_persent=p_ln_10  then '长夜_10h型'
           -- when max_persent>=0.75 and max_persent=p_ln_10_12  then '长夜_10_12h型'
            when max_persent>=0.75 and max_persent=p_ln_8_10  then '长夜_8_10h型'
            when max_persent>=0.75 and max_persent=p_ld_10  then '长白_10h型'
           -- when max_persent>=0.75 and max_persent=p_ld_10_12  then '长白_10_12h型'
            when max_persent>=0.75 and max_persent=p_ld_8_10  then '长白_8_10h型'

            when max_persent>=0.75 and max_persent=p_sd1 then '短白1型'
            when max_persent>=0.75 and max_persent=p_sd2 then '短白2型'
            when max_persent>=0.75 and max_persent=p_sn1 then '短夜1型'
            when max_persent>=0.75 and max_persent=p_sn2 then '短夜1型'

            when max_persent<0.75 and p_ld_10>0.35 and p_ln_10>0.35  then '组合出勤_全能型'

            when max_persent<0.75 and max_persent=p_ln_10  then '组合出勤_长夜_10h型'
          --  when max_persent<0.75 and max_persent=p_ln_10_12  then '组合出勤_长夜_10_12h型'
            when max_persent<0.75 and max_persent=p_ln_8_10  then '组合出勤_长夜_8_10h型'
            when max_persent<0.75 and max_persent=p_ld_10  then '组合出勤_长白_10h型'
           -- when max_persent<0.75 and max_persent=p_ld_10_12  then '组合出勤_长白_10_12h型'
            when max_persent<0.75 and max_persent=p_ld_8_10  then '组合出勤_长白_8_10h型'

            when max_persent<0.75 and max_persent=p_sd1 then '组合出勤_短白1型'
            when max_persent<0.75 and max_persent=p_sd2 then '组合出勤_短白2型'
            when max_persent<0.75 and max_persent=p_sn1 then '组合出勤_短夜1型'
            when max_persent<0.75 and max_persent=p_sn2 then '组合出勤_短夜2型'
         else null end as label
        -- ,t1.week_of_year
    from employee_chuqin_performance t1
    left join chuqin_label t2
    on t1.employee_no=t2.employee_no
),
b_chuqin as
(
    select
    if(length(employee_no)=6,concat('10',employee_no),employee_no) as employee_no
    ,workdays
    ,case
        when label in ('长夜_10h型','组合出勤_长夜_10h型') then '长夜型员工'
      --  when label in ('长夜_10_12h型','组合出勤_长夜_10_12h型') then '长夜型员工'
        when label in ('长夜_8_10h型','组合出勤_长夜_8_10h型') then '中夜型员工'
        when label in ('长白_10h型','组合出勤_长白_10h型') then '长白型员工'
       -- when label in ('长白_10_12h型','组合出勤_长白_10_12h型') then '长白型员工'
        when label in ('长白_8_10h型','组合出勤_长白_8_10h型') then '中白型员工'

        when label in ('组合出勤_全能型') then '全天型员工'
        when label in ('短白1型','组合出勤_短白1型') then '短白1型'
        when label in ('短白2型','组合出勤_短白2型') then '短白2型'
        when label in ('短夜2型','组合出勤_短夜2型') then '短夜2型'
        when label in ('短夜1型','组合出勤_短夜1型') then '短夜1型'
     end as label_chuqin

from final_chuqin t1
-- where week_of_year>25
-- and week_of_year<33
where label is not null
),


 staff_adress as
(
select
if(length(staff_code)=6,concat('10',staff_code),staff_code) as staff_code
,staff_name as cn_name
,work_dept_code
,work_city_name as city_name
,work_city_code as city_code
,residence_address as staff_address
,residence_address_coordinate as staff_coordinate
,update_time as update_time
,row_number()over(partition by staff_code order by update_time desc) as rn
from data_build.dwd_pdw_gis_workday_staff_address_collect_record_view
where dt ='${DATE}'
),


base_roster_tomorrow as
(
 select
 IF(LENGTH(staff_code)<8,concat('10',staff_code),staff_code) as staff_code,
 staff_name,
 hps_d_jobcode, --岗位
 date_key,
 date_sub(next_day(date_key,'mon'),7) roster_week, --周
 count(distinct case when is_give_roster = 1 and is_vacation = 0 and is_dimission_apply_available = 1 and is_health_cer_right = 1 and is_in_black_list = 0 then rk_of_half_hour end)/2 avai_hours,--可用小时（给班&未请假&未离职&健康证可用&不在黑名单）
 count(distinct case when is_give_roster = 1 then rk_of_half_hour end)/2 give_hours, --给班小时
 count(distinct case when total_suc_roster_num_week is not null then rk_of_half_hour end)/2 shift_hours, --周班表排班小时
 count(distinct case when total_roster_num is not null then rk_of_half_hour end)/2 shift_hours_2 --排班小时
from data_smartorder.dm_roster_staff_half_hour_roster_and_attendance_quantity_di a
where dt = '${DATE}'
and hps_d_hr_status = '在职'
and date_key = date_add('${FDATE_SUB0DAY}',2)
and is_store_manager = 0 --非架构负责人
and hps_d_jobcode in ('门店伙伴','学生PT')

group by
 staff_code,
 staff_name,
 hps_d_jobcode,
 date_key
 ),

base_roster_tomorrow_2 as
(
 select
 IF(LENGTH(staff_code)<8,concat('10',staff_code),staff_code) as staff_code,
 staff_name,
 hps_d_jobcode, --岗位
 date_key,
 date_sub(next_day(date_key,'mon'),7) roster_week, --周
 count(distinct case when is_give_roster = 1 and is_vacation = 0 and is_dimission_apply_available = 1 and is_health_cer_right = 1 and is_in_black_list = 0 then rk_of_half_hour end)/2 avai_hours,--可用小时（给班&未请假&未离职&健康证可用&不在黑名单）
 count(distinct case when is_give_roster = 1 then rk_of_half_hour end)/2 give_hours, --给班小时
 count(distinct case when total_suc_roster_num_week is not null then rk_of_half_hour end)/2 shift_hours, --周班表排班小时
 count(distinct case when total_roster_num is not null then rk_of_half_hour end)/2 shift_hours_2 --排班小时
from data_smartorder.dm_roster_staff_half_hour_roster_and_attendance_quantity_di a
where dt = '${DATE}'
and hps_d_hr_status = '在职'
and date_key = date_add('${FDATE_SUB0DAY}',3)
and is_store_manager = 0 --非架构负责人
and hps_d_jobcode in ('门店伙伴','学生PT')
and rk_of_half_hour <= 38

group by
 staff_code,
 staff_name,
 hps_d_jobcode,
 date_key
 ),

chubei_raw as
(
select employee_id,
roster_id
,start_time
,end_time
from data_build.dw_roster_effect_roster_detail_info_da_view
where dt = '${DATE}'
and work_date  =  date_add('${FDATE_SUB0DAY}',2)
and attr_id = 342
)
,main_store_detail as 
(
select t1.store_code  as store_code 
,t1.is_main_store
,t1.business_district_id
,t2.store_code as main_store_code 
,t3.distince as distance_main_store
,row_number()over(partition by  t1.store_code  order by t3.distince+0 asc) as rn
from data_smartorder.ods_uploads_business_district_qiyang t1
left join data_smartorder.ods_uploads_business_district_qiyang t2 on t1.business_district_id= t2.business_district_id and t2.is_main_store = '是'
left join data_build.dm_order_external_same_city_store_riding_distance_type_zero_do_business_union_all_view t3 on t1.store_code = t3.a_store_code and t2.store_code = t3.b_store_code
and t3.dt = '${DATE}'
)
,waitlist_detail as 
(
select 
* 
,row_number()over(partition by employee_no order by update_time desc) as rn
from data_build.dwd_pdw_idss_ipes_admin_employee_blacklist_waitlist_view 
where dt = '${DATE}' 
and valid = 1 )

,blacklist_detail as 
(
select * 
,row_number()over(partition by employee_no order by update_time desc) as rn
from data_shop.pdw_idss_ipes_admin_employee_blacklist_view  
where dt = '${DATE}' 
and valid_status = 1 and start_date <= '${FDATE_SUB0DAY}' and end_date >= '${FDATE_SUB0DAY}'
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
left join data_build.dim_date_ya_v2 t3 on from_unixtime(unix_timestamp(t1.dt,'yyyyMMdd'),'yyyy-MM-dd') = t3.date_key
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

left join data_build.dim_date_ya_v2 t3 on from_unixtime(unix_timestamp(t1.dt,'yyyyMMdd'),'yyyy-MM-dd') = t3.date_key

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
,spring_festival_2025 as( --2025年春节给班结果表20250211停用
select
staff_code
,post_name
,give_days
,important_give_days
,is_black
,spring_festival_2025_result
from data_build.dwd_spring_festival_2025_give_info_da
where dt = '${DATE}'
)
,main_list as(
select
order_id --流程编码(流程信息)
,cast(substr(create_time,1,10) as date) as create_date
,order_status --流程状态(流程信息)
,initiator_code --发起人编码(流程信息)
,create_time --流程发起时间(流程信息)
,flow_ame --流程名称(流程信息)
,org_code --门店编码(流程信息)
,org_name --门店名称(流程信息)
from data_build.pdw_order_store_211_order_detail_flow_main
where dt = '${DATE}'
and flow_code = '032258' --流程code--离职风险员工信息调查
),

order_flow_groups as(
SELECT
order_id
,max(case when form_name = 'employeeNo' then get_json_object(get_json_object(form_values,'$.[0]'),'$.value') else null end) as employeeNo --员工工号
,max(case when form_name = 'employeeName' then get_json_object(get_json_object(form_values,'$.[0]'),'$.value') else null end) as employeeName --员工姓名
,max(case when form_name = 'planLeave' then get_json_object(get_json_object(form_values,'$.[0]'),'$.value') else null end) as planLeave --是否计划离职
,max(case when form_name = 'planLeaveDate' then get_json_object(get_json_object(form_values,'$.[0]'),'$.value') else null end) as planLeaveDate --计划离职日期
,max(case when form_name = 'planEliminate' then get_json_object(get_json_object(form_values,'$.[0]'),'$.value') else null end) as planEliminate --是否计划汰换
from data_build.pdw_order_store_211_order_detail_flow_form_variable_groups_da
where dt = '${DATE}'
--and order_id = '2110188849993308'
and form_name in ('employeeNo','employeeName','planLeave','planLeaveDate','planEliminate')
GROUP BY
order_id
),

raw_list as(
select
t0.order_id --流程编码(流程信息)
,t0.create_date
,t0.order_status --流程状态(流程信息)
,t1.employeeNo
,t1.employeeName
,t1.planLeave
,t1.planLeaveDate
,t1.planEliminate
,case when t1.planLeave in ('是') and datediff(t1.planLeaveDate,'${FDATE_SUB0DAY}') <= 21 then 'yes'
when planeliminate in ('是') then 'yes'
else 'no' end as need_recruit
from main_list t0
left join order_flow_groups t1 on t0.order_id = t1.order_id
)
,supply_staff_base_1 as 
(
    select 
    distinct
     t2.employee_id
    ,t3.hps_d_jobcode
    ,t3.hps_d_hr_status
    ,t8.week_of_year --上周周数
    ,t2.label2 as geiban_label --最新两周给班标签
   ,case when t18.valid = 1 then 0 
   when t17.valid_status = 1 then 0
   when t30.gap_new =0 and t32.employee_no is not null then 0 --20240903新增
   else nvl(t4.work_days,0) end as available_days  -- 前两周可用天数均值（高离职率），最大可用天数（非高离职）
   ,case when t17.valid_status = 1 or t18.valid =1 then 'blacklist' else t5.is_di end as is_di -- 是否低意愿
   ,case when t6.store_manager_no is not null then 1 else 0 end as is_manager --是否架构负责人
   ,t7.give_days as give_days --给班天数
   ,t7.give_hours as give_hours -- 给班小时数
   ,t3.store_code
   ,t8.give_days_max as give_days_max
   ,t8.give_days_avg as give_days_avg
   ,case when t8.give_days_max > t7.give_days then t8.give_days_max else t7.give_days end as give_days_final
   ,nvl(t9.is_leave_21,0) as is_leave_21
   ,t9.final_leave_date
   ,nvl(t10.is_leave_21,0) as is_leave_manager_21
   ,t11.label_chuqin as chuqin_label --历史两周出勤标签
   ,t12.cn_name
    ,t12.city_code
    ,t12.city_name
    ,t12.staff_address
    ,t12.staff_coordinate
   ,case when datediff(current_date(),from_unixtime(unix_timestamp(t5.entry_date,'yyyymmdd'),'yyyy-mm-dd')) <= 12 then 0
   when t5.is_di = 1 then 0
   when t6.store_manager_no is not null then 0
   when t2.label2 not in ('全天型员工','长夜型员工','长白型员工','中白型员工') then 0
   when t16.is_geiban_enough = 0 then 0
   when t16.is_paiban_enough = 1 then 0
   when t15.roster_id is not null then '有储备班次，先卸班'
   when t2.label2 = '长夜型员工' and t14.shift_hours_2 > 0 then 0
   when t13.shift_hours_2 = 0 and t13.avai_hours >=8 then '直接排班'
   else 0 end as roster_type_tomorrow

   ,t2.employee_id_original
   ,t20.business_district_id  as district_code 
   ,case when t17.valid_status = 1 or t18.valid = 1 then 'blacklist' when t21.distance_main_store >= 1 then '需替换' else '不需替换' end as is_need_replace
   ,case when t20.business_district_id is null or t5.protect_tag <> '应离职' or t17.valid_status = 1 or t18.valid = 1 or t6.store_manager_no is not null or t3.hps_d_jobcode ='店副经理' then '不需替换' else row_number()over(partition by t20.business_district_id order by (t21.distance_main_store+0,datediff(current_date(),from_unixtime(unix_timestamp(t5.entry_date,'yyyymmdd'),'yyyy-mm-dd')),(1-t5.protect_tag_detail)) asc) end as replace_rn
   ,t5.protect_tag as protect_tag
   ,case when t6.store_manager_no is not null then 'manager'
   when t3.hps_d_jobcode ='店副经理' then 'sec_manager'
   when t3.is_under_22 = 0 and t3.on_job_days >=30 and t5.protect_tag_detail<=2 and t4.work_days>=3 and t5.is_di = 0 and t5.hours>=200
   --and spring_festival_2025_result = '合格' --2025年春节给班结果，20250211停用 
   and t34.staff_code is null --非晋升店副黑名单
   then 'key_staff'
   else 'normal_staff' end as key_staff_type
   ,t5.hours as hours 
   ,t5.total_attend_days as total_attend_days
   ,t5.is_student as is_student
   ,t5.protect_tag_detail as protect_tag_detail
   ,t30.hc_new as hc_new
   ,nvl(t31.roster_count,0) as roster_count
   ,case when t32.employee_no is not null then '1' else '0' end as potential_leave --是否命中未来潜在离职

from b_geiban t2
left join status t3
on t2.employee_id=if(length(t3.employee_id)=6,concat('10',t3.employee_id),t3.employee_id) and t3.rn = 1
left join work_days t4
on t2.employee_id=if(length(t4.staff_code)=6,concat('10',t4.staff_code),t4.staff_code)
left join protect_tag_list t5
on t2.employee_id =if(length(t5.staff_code)=6,concat('10',t5.staff_code),t5.staff_code) 
left join manager_list t6
on t2.employee_id =if(length(t6.store_manager_no)=6,concat('10',t6.store_manager_no),t6.store_manager_no) 
left join give_days_hours_b t7
on t2.employee_id =if(length(t7.employee_id)=6,concat('10',t7.employee_id),t7.employee_id) 
left join give_days_hours_a t8
on t2.employee_id =if(length(t8.employee_id)=6,concat('10',t8.employee_id),t8.employee_id) 
left join leave_day t9
on t2.employee_id = if(length(t9.employee_id)=6,concat('10',t9.employee_id),t9.employee_id) and t9.rn = 1 
left join leave_manager t10
on t2.employee_id = if(length(t10.current_manager_code)=6,concat('10',t10.current_manager_code),t10.current_manager_code) 
left join b_chuqin t11
on t2.employee_id =  if(length(t11.employee_no)=6,concat('10',t11.employee_no),t11.employee_no)
left join staff_adress t12 on t2.employee_id = t12.staff_code and t12.rn = 1
left join base_roster_tomorrow t13 on t2.employee_id = t13.staff_code
left join base_roster_tomorrow_2 t14 on t2.employee_id = t14.staff_code
left join chubei_raw t15 on t2.employee_id = t15.employee_id
left join data_build.dwd_store_construction_total_staff_shifttag_v1_di t16 on t2.employee_id = t16.employee_id and t16.dt = '${DATE}'
left join blacklist_detail t17 on t2.employee_id = if(length(t17.employee_no)=6,concat('10',t17.employee_no),t17.employee_no) and t17.rn = 1
left join waitlist_detail t18 on t2.employee_id = if(length(t18.employee_no)=6,concat('10',t18.employee_no),t18.employee_no) and t18.rn = 1
left join data_smartorder.ods_uploads_business_district_qiyang t20 on t3.store_code = t20.store_code 
left join main_store_detail t21 on t3.store_code =  t21.store_code and t21.rn = 1 and t5.protect_tag = '应离职' and t6.store_manager_no is null and t3.hps_d_jobcode <>'店副经理'
left join data_build.dwd_store_construction_store_groups_recruit_gap t30 on t3.store_code = t30.store_code and t30.dt = '${DATE_SUB1DAY}'
left join success_roster_count t31 on t2.employee_id = t31.employee_id
left join( 
SELECT
distinct
employeeNo as employee_no
from raw_list
where need_recruit = 'yes'
and create_date between 
case when dayofweek('${FDATE_SUB0DAY}') in ('2','3','4','5') --周一周二周三周四
then date_sub(next_day('${FDATE_SUB0DAY}','mon'),35) 
else date_sub(next_day('${FDATE_SUB0DAY}','mon'),28) end
and
'${FDATE_SUB0DAY}'
) t32 on t2.employee_id = if(length(t32.employee_no)=6,concat('10',t32.employee_no),t32.employee_no)
left join spring_festival_2025 t33 on t2.employee_id = t33.staff_code
left join (
    select
    distinct
    staff_code
    from data_shop.dwd_vice_manager_transfer_blacklist_v1_da --店副晋升黑名单
    where dt = '${DATE}') t34 on t2.employee_id = t34.staff_code
where label2 is not null 
and t3.hps_d_hr_status = '在职'
)

,supply_staff_base_2 as 
(select 
* 
,case when key_staff_type = 'manager' then 1 
when key_staff_type = 'sec_manager' then 2 
when key_staff_type = 'key_staff' and protect_tag_detail = 1 and is_student = '非学生PT' then 3
when key_staff_type = 'key_staff' and protect_tag_detail = 2 and is_student = '非学生PT' then 4
when key_staff_type = 'key_staff' and protect_tag_detail = 4 and is_student = '非学生PT' then 5
when key_staff_type = 'normal_staff' and protect_tag_detail = 1 and is_student = '非学生PT' then 6
when key_staff_type = 'normal_staff' and protect_tag_detail = 2 and is_student = '非学生PT' then 7
when key_staff_type = 'normal_staff' and protect_tag_detail = 4 and is_student = '非学生PT' then 8
when key_staff_type = 'normal_staff' and protect_tag_detail = 3 and is_student = '非学生PT' then 9
when key_staff_type = 'normal_staff' and protect_tag_detail = 1 and is_student = '学生PT' then 10
when key_staff_type = 'normal_staff' and protect_tag_detail = 2 and is_student = '学生PT' then 11
when key_staff_type = 'normal_staff' and protect_tag_detail = 4 and is_student = '学生PT' then 12
when key_staff_type = 'normal_staff' and protect_tag_detail = 3 and is_student = '学生PT' then 13
when key_staff_type = 'normal_staff' and protect_tag_detail = 5 and is_student = '非学生PT' then 14
when key_staff_type = 'normal_staff' and protect_tag_detail = 5 and is_student = '学生PT' then 15
else 20 end as staff_type_rank
,row_number()over(partition by concat(store_code,key_staff_type,protect_tag_detail,is_student) order by hours desc) as roster_rank_1
from  
supply_staff_base_1
)
,supply_staff_base_3 as 
(select 
* 
,row_number()over(partition by concat(store_code) order by concat(10+staff_type_rank,10+roster_rank_1) asc) as roster_rank
from  
supply_staff_base_2
)


insert overwrite table ${TABLE_NAME} partition (dt='$DATE')

       select employee_id
    ,hps_d_jobcode
    ,hps_d_hr_status
    ,week_of_year --上周周数
    ,geiban_label --最新两周给班标签
   ,available_days  -- 前两周可用天数均值（高离职率），最大可用天数（非高离职）
   ,is_di -- 是否低意愿
   ,is_manager --是否架构负责人
   ,give_days --给班天数
   ,give_hours -- 给班小时数
   ,store_code
   ,give_days_max
   ,give_days_avg
   ,give_days_final
   ,is_leave_21
   ,final_leave_date
   ,is_leave_manager_21
   ,chuqin_label --历史两周出勤标签
   ,cn_name
    ,city_code
    ,city_name
    ,staff_address
    ,staff_coordinate
   ,roster_type_tomorrow

   ,employee_id_original
   ,district_code 
   ,is_need_replace
   ,replace_rn
   ,protect_tag
   ,key_staff_type
    ,roster_rank
    ,case when key_staff_type = 'normal_staff' then 0
    when key_staff_type = 'key_staff' and hc_new = 2 then 0
    when key_staff_type = 'key_staff' and hc_new = 3 and roster_rank <= 3 then 1 
    when key_staff_type = 'key_staff' and hc_new >= 4 and roster_rank <= 4 then 1 
    else 0 
    end as is_need_fulfill
    ,roster_count
    ,potential_leave --是否命中未来潜在离职
     from supply_staff_base_3

        ;

        -- 验证数据
        ${CHECK_DATA_SQL};

        "
EOF
}