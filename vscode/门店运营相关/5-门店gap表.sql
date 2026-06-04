# --------------------------------------
# DATE: 2020-02-05
# DEV:
# DESC:
# PRODUCT_WIKI:
# DEV_WIKI:https://wiki.corp.bianlifeng.com/pages/viewpage.action?pageId=615156086
# --------------------------------------
source ${ETC}/format_date.cnf


TABLE_NAME="data_build.dwd_store_construction_store_groups_recruit_gap"
UNIQ_KEY='store_code'
CHECK_DATA_SQL="
    select
        '数据条数必须大于0'
        , assert_true(count(1)>0)
        , count(1)
        ,'唯一键唯一'
        , assert_true(count(1)=sum(m))
        , sum(m)


    from
     (select
        t1.store_code
        ,count(1) m
       ,sum(t1.hc_new) n
       ,sum(t3.hc_new) n_dt_1
       ,sum(t1.gap_new) gap
       ,sum(t3.gap_new) gap_dt_1
        from ${TABLE_NAME} t1
        left join (
        select
        store_code
        ,hc_new
        ,gap_new
        from
        ${TABLE_NAME} t2
        where t2.dt = '${DATE_SUB1DAY}'
        ) t3 on t1.store_code = t3.store_code
        where t1.dt ='${DATE}'
        group by
        t1.store_code
        ) t
    ;
"

##JOB入口函数
function dwd_store_construction_store_groups_recruit_gap_run {
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
        set orc.compress.size=4096;
        set hive.exec.orc.default.stripe.size=268435456;


---店群
drop table if exists data_build.tmp_store_group_${DATE};
create table data_build.tmp_store_group_${DATE} as
    select
         t2.a_store_code
        ,t2.a_store_name
        ,t2.a_store_city
        ,t2.b_store_code
        ,t2.b_store_name
        ,t2.distince
    from data_build.dm_order_external_same_city_store_riding_distance_type_zero_do_business_union_all_view t2
    inner join (
select max(dt) as max_dt
from data_build.dm_order_external_same_city_store_riding_distance_type_zero_do_business_union_all_view
where dt >= '${DATE_SUB2DAY}'
and dt <= '${DATE}'
) tmp
on t2.dt = tmp.max_dt
    inner join data_build.dim_store_info t3 on t2.b_store_code  = t3.store_code and t3.dt = '${DATE}' and t3.store_type = 0 and t3.store_name not rlike '测试'
    left join data_build.ods_uploads_store_close_detail t4 on t2.b_store_code = t4.store_code
   -- left join data_build.ods_uploads_invalid_store_code t5 on t2.b_store_code = t5.store_code
    where t2.dt >= '${DATE_SUB2DAY}'
    and t2.dt <= '${DATE}'
    and t2.distince<=3000
    ---and t2.distince>1
    and t4.store_code is null
   -- and t5.store_code is null

;

drop table if exists data_build.tmp_base_list_${DATE};
create table data_build.tmp_base_list_${DATE} as
with person_tag as
(
    select
         t0.store_code
        ,t0.staff_code
        ,if(length(t0.staff_code) = 6, concat('10', t0.staff_code) , t0.staff_code) as user_no
        ,t0.protect_tag
        ,if(t0.protect_tag in ('应离职','末位普通') or t1.employee_no is not null,'1','0') as is_leave
        ,if(t0.protect_tag in ('应离职') ,'1','0') as is_leave_2
        ,if(t0.protect_tag in ('应离职','末位普通') ,'1','0') as is_leave_3
    from data_build.dm_shop_staff_protect_tag_v2_view t0
    inner join (
select max(dt) as max_dt
from data_build.dm_shop_staff_protect_tag_v2_view
where dt >= '${DATE_SUB2DAY}'
and dt <= '${DATE}'
) tmp
on t0.dt = tmp.max_dt
    left join data_build.ods_uploads_pre_dimission t1 on t0.staff_code=t1.employee_no

    where t0.dt >= '${DATE_SUB2DAY}'
    and t0.dt <= '${DATE}'
),
project_tag_person as
(
    select
         t1.store_code
        ,count(distinct t1.staff_code) as staffs
        ,count(distinct case when t1.position_cn in ('店经理','见习店经理') then t1.staff_code end) as managers
    from data_build.dm_shop_staff_protect_tag_v2_view t1
    inner join (
select max(dt) as max_dt
from data_build.dm_shop_staff_protect_tag_v2_view
where dt >= '${DATE_SUB2DAY}'
and dt <= '${DATE}'
) tmp
on t1.dt = tmp.max_dt
    where t1.dt >= '${DATE_SUB2DAY}'
    and t1.dt <= '${DATE}'
    and t1.job_status=1
    and t1.protect_tag not in ('应离职','末位普通')
    group by
        t1.store_code
),
project_tag_person_2 as
(
    select
             t1.hps_dept_code_lv5 as store_code
            ,count(distinct case when t2.protect_tag not in ('应离职','末位普通') then t1.emplid end) as staffs
    from data_build.pdw_psprod_ps_blf_ehr_pers_vw_view t1
    inner join (
        select max(dt) as max_dt
        from data_build.pdw_psprod_ps_blf_ehr_pers_vw_view
        where dt >= '${DATE_SUB2DAY}'
        and dt <= '${DATE}'
        ) tmp on t1.dt = tmp.max_dt
    left join data_build.dm_shop_staff_protect_tag_v2_view t2  on if(length(t1.emplid)=6,concat('10',t1.emplid),t1.emplid)=if(length(t2.staff_code)=6,concat('10',t2.staff_code),t2.staff_code) and t2.dt='${DATE}'
    where t1.dt >= '${DATE_SUB2DAY}'
    and t1.dt <= '${DATE}'
    and t1.hps_d_hr_status='在职'
    and t1.hps_d_jobcode in ('店经理','储备店经理','见习店经理','门店伙伴','社会PT','店副经理','学生PT','内部合作经营者','内部合作辅助人','内部合作伙伴','外部合作经营者','外部合作辅助人','外部合作伙伴')
    group by t1.hps_dept_code_lv5
),


---优化后的hc和FTE
full_capacity as
(
    select
         store_code
        ,b_hc--理想运营HC
        ,a_hc--最低开业HC
        ,store_epidemic_hc
        ,fte_all---全量未剔除
        ,fte_all_ne---全量剔除测温
        ,fte---全量剔除应离职末位普通
        ,fte_ne--剔除应离职末位普通&测温
        ,b_gap
        ,b_full_capacity_perdict_future--不含测温满编率
        ,full_capacity_perdict_future_all---含测温满编率
        ,full_capacity_all---含应离职末位普通的FTE
        ,store_type
        ,fte_nopipe
        ,full_capacity_nopipe---提出应离职末位普通含测温 不含pipeline
        ,fte_allocation--剔除应离职FTE，含pipeline
        ,full_capacity_allocation-----剔除应离职，含pipeline

        ,fte_all_allocation
        ,full_capacity_all_allocation

    from data_build.dwd_store_construction_full_capacity_perdict t1
    inner join (
        select max(dt) as max_dt
        from data_build.dwd_store_construction_full_capacity_perdict
        where dt >= '${DATE_SUB2DAY}'
        and dt <= '${DATE}'
        ) tmp on t1.dt = tmp.max_dt
    where t1.dt >= '${DATE_SUB2DAY}'
    and t1.dt <= '${DATE}'
),
store_group_gap_out as
(
    select
         t1.a_store_code
        ,t1.group_gap
    from
    (
        select
             t1.a_store_code
            ,t1.b_store_code
            ,max(t2.b_gap)over(partition by t1.a_store_code) as group_gap
        from data_build.tmp_store_group_${DATE} t1
        left join full_capacity t2 on t1.b_store_code=t2.store_code
        where b_gap>0
    )t1
),

--    sign_list as---签约后全量门店清单
--    (
--     select
--          t1.city_code
--         ,t1.id
--         ,t1.shop_code
--         ,t1.store_name
--         ,t1.flag_number
--         ,t2.name
--         ,t1.signing_date
--         ,t1.opening_date
--         ,case when t7.store_code is not null then 1 else 0 end as is_store_close---撤店清单
--     from data_build.pdw_opc_engineering_engineering_store_ha t1
--     left join data_build.pdw_opc_flag_city_info t2 on t1.city_code=t2.code and t2.dt='${DATE}'
--     left join data_build.ods_uploads_store_close_detail t7 on t1.shop_code=t7.store_code
--     where t1.status in (0,1,11)
--     and t1.type in (0, 4)
--     and t1.store_name is not null
--     and t1.store_name != ''
--     and t1.store_name not like '%测试%'
--     and t1.project_is_delete != 1
--     and t1.shop_code not in ("123000113","123000187","100000119") --排除无人店
--     and t1.dt = '${DATE}'
--     and t1.hr='21'
--     and t1.opening_date is not null
--     and t1.opening_date<='${FDATE_ADD30DAY}'
--    ),
opening_day as
(
select
store_code
,is_store_close
,tt.name
,store_name
,count(distinct record_date) as opening_days

from
(
select
 t1.record_date
 ,t1.store_code
 ,t5.store_name as store_name
 ,t4.name
 ,CASE WHEN change_reason in ('紧急闭店','门店延期营业') OR urgent_close_reason IS NOT NULL THEN ideal_shop_business_time
 ELSE bach_business_time END AS business_time
 ,case when t2.store_code = '100005510' then 0 
 when t2.store_code is not null then 1 else 0 end as is_store_close ---撤店清单
 FROM data_smartorder.dw_ordering_report_store_business_status_da t1
 left join data_build.ods_uploads_store_close_detail t2 on t1.store_code=t2.store_code
 left join data_build.pdw_opc_engineering_engineering_store_ha t3 on t1.store_code = t3.shop_code and t3.dt='${DATE}' -- 之前用于匹配门店名称，现替换为t5
 left join data_build.pdw_opc_flag_city_info t4 on t3.city_code=t4.code and t4.dt='${DATE}'
 left join data_shop.dwd_shop_store_information_di t5 on t1.store_code=t5.store_code and t5.dt='${DATE}'

 WHERE t1.dt = '${DATE}' AND t1.store_type = '0'
 AND t1.record_date >= '${FDATE_ADD1DAY}'
 AND t1.record_date <= '${FDATE_ADD14DAY}'
 ) tt
 where business_time not in ('全天不营业')
 group by store_code
 ,is_store_close
 ,tt.name
 ,store_name
 ),
store_epidemic_job as
(
    select
         t1.hps_dept_code_lv5  as department_code
        ,count(distinct case when t1.hps_d_jobcode='防疫伙伴' then t1.emplid end)  as epidemics
    from data_build.pdw_psprod_ps_blf_ehr_pers_vw_view t1
    inner join (
        select max(dt) as max_dt
        from data_build.pdw_psprod_ps_blf_ehr_pers_vw_view
        where dt >= '${DATE_SUB2DAY}'
        and dt <= '${DATE}'
        ) tmp on t1.dt = tmp.max_dt
    where t1.dt >= '${DATE_SUB2DAY}'
    and t1.dt <= '${DATE}'
    and t1.hps_d_hr_status = '在职'
    group by t1.hps_dept_code_lv5
),
---接传龙数据：城市给班FTE/城市排班工时折算FTE≤110%
---接王俊数据：高失败班次城市数据
-- date_week as
-- (
 --    select
 --          distinct dt_date
  --       ,dt_week
  --   from data_build.app_gis_store_full_capacity_by_sotre_all_view a
  --   where dt_date='${FDATE_SUB0DAY}'
-- ),
-- gra_info as
-- (
 --    select
 --         a.dt_week
 --        ,store_city
 --        ,shop_code
  --       ,sum(shift_hours)/60 as shift_demand_fte
  --   from data_build.app_gis_store_full_capacity_by_sotre_all_view a
  --   group by
  --         dt_week
  --       ,shop_code
  --       ,store_city
-- ),
-- fte_info as
-- (
--     select
 --         date_week
 --        ,store_code
 --        ,fte_by_give
  --   from data_build.app_gis_store_recruit_fte_by_give_roster_attend_view a
-- ),
-- high_level as
-- (
 --    select
  --        a.dt_week
  --       ,a.store_city
   --      ,sum(a.shift_demand_fte)                                 as shift_demand_fte --排班班次折算fte
   --      ,sum(b.fte_by_give)                                      as fte_by_give --门店给班fte
   --      ,sum(b.fte_by_give)/sum(a.shift_demand_fte)              as persent
   --      ,if(sum(b.fte_by_give)/sum(a.shift_demand_fte)<1.1,1,0)  as high_level
  --   from gra_info a
  --   left join fte_info b on a.dt_week = b.date_week and a.shop_code = b.store_code
  --   left join date_week t1 on a.dt_week=t1.dt_week
   --  where t1.dt_week is not null
 --    group by
  --        a.dt_week
   --      ,a.store_city
-- ),
-- recruit_high_level as
-- (
 --    select
  --       distinct city_name
  --   from
  --   (
  --       select
  --           store_city  as city_name
  --       from high_level
  --       where high_level=1
  --   )t1
-- ),
---门店简历降级
 is_downgrade as
 (
   select
       store_code
       ,case
          when (delivery_candiddate_fix-dc_demand_qty_static>=0)
               and (pre_arrive_store-ar_demand_qty_static>=0)
                ---and (diff_stage<=0 or diff_stage is null)
       then 1 else 0 end as is_pipeline_enough
    from data_build.mid_gis_h3_recuit_progress_detai_di_view

),
sold_out_list as
(
    -- 计算有空窗和断档门店的清单
    select
         distinct store_code
    from data_build.dwd_store_construction_empty_window_sold_out_list t1
    inner join (
        select max(dt) as max_dt
        from data_build.dwd_store_construction_empty_window_sold_out_list
        where dt >= '${DATE_SUB2DAY}'
        and dt <= '${DATE}'
        ) tmp on t1.dt = tmp.max_dt
    where t1.dt >= '${DATE_SUB2DAY}'
    and t1.dt <= '${DATE}'
    and t1.record_date>'${FDATE_SUB5DAY}'
    and t1.record_date<='${FDATE_SUB0DAY}'
),
jiameng_list as (
select distinct 
 store_code
from default.pdw_bach_baseinfo_shop_shop
where dt = '${DATE}'
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
 and t1.dt = '${DATE}'
 and t1.hr >=20 
 and t1.is_delete = 0 
 and t1.business_type = '便利店' 
 and substring_index(t1.project_status_name,' ',1) = '10' 
)
,chedian_list as ( --20260520调整，撤店清单不从撤店pipeline取，从yanchen.huang提供的确定撤店list里取
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

,chedian_list_1 as( --20260520新增
select
store_code
from data_build.ods_uploads_chedian_list
)

    select distinct     ``
         t1.store_code as store_code
        ,t1.store_name
        ,t1.name      as city_name
        ,''           as recovery_label--置空
        ,t3.b_hc--理想运营HC
        ,t3.a_hc--最低开业HC
        ,t3.fte_all_ne    as fte--剔除应离职末位普通测温
---替换新版门店缺口计算规则
        ,case
            when t3.b_hc<=3 and t3.b_gap>0 then t3.b_gap
            when t3.b_hc>3  and t3.b_hc<=5 and t3.b_gap>1 then t3.b_gap-1
            when t3.b_hc>3  and t3.b_hc<=5 and t3.b_gap=1 then 1
            when t3.b_hc>5  and t3.b_gap>2 then t3.b_gap-2
            when t3.b_hc>5  and t3.b_gap<=2 and t3.b_gap>0 then 1
         else 0 end as a_gap---总部招聘GAP
        ,t3.b_gap--门店自招GAP
        ,''  as  a_full_capacity_perdict_future---作废置空
        ,t3.b_full_capacity_perdict_future
        ,t3.store_type

        ,nvl(t2.group_gap,0) as group_gap--门店代招缺口

        ,'' as support_persons--置空
        ,'' as label--原总部/门店自招分级字段，废弃置空
        ---渠道招聘是否打开（1-打开，0-关闭）
        ---------------增加测温缺口
        ,t3.store_epidemic_hc
        ,t9.epidemics
        ,round(t3.store_epidemic_hc-t9.epidemics,0)  as epidemic_gap----防疫伙伴缺口
        ,case when round(t3.store_epidemic_hc-t9.epidemics,0)>0 then 1 else 0 end  as is_business_self_epidemic---是否打开门店自招_防疫（1-打开，0-不打开）
        ,'0'                                         as is_recruitment_department_epidemic---是否打开总部招聘_防疫（1-打开，0-不打开）
        ,'0'                                         as is_group_epidemic---是否打开店群招聘_防疫（1-打开，0-不打开）
        ----整体缺口计算
        ,t3.b_hc                                     as hc_all -- 剔除测温岗
        ,t3.fte                                      as fte_all -- 去低
        ,full_capacity_perdict_future_all
        ,case when (b_hc-fte)<0.3 and fte>2 then 0 else ceiling(b_hc-fte) end as gap_all -- 剔除测温岗
        ,t14.staffs
        ,'0' as is_upgrade
        ,case when t12.store_code is not null then 1 else 0 end as is_empty_window

       -----不剔除应离职和末位普通的全量情况
       ,fte_all                                      as fte_all2

       ,full_capacity_all
       ,t13.is_pipeline_enough

       ,t3.fte_nopipe
       ,t3.full_capacity_nopipe---提出应离职末位普通含测温 不含pipeline
       ,case when t10.managers>0 then 1 else 0 end   as is_manager
       ,fte_allocation--剔除应离职FTE，含pipeline
       ,full_capacity_allocation-----剔除应离职，含pipeline
       ,fte_all_allocation
       ,full_capacity_all_allocation
    from opening_day t1
    left join store_group_gap_out t2 on t1.store_code=t2.a_store_code
    left join full_capacity t3 on t1.store_code=t3.store_code
    left join store_epidemic_job t9 on t1.store_code=t9.department_code
    left join project_tag_person t10 on t1.store_code=t10.store_code
    left join project_tag_person_2 t14 on t1.store_code=t14.store_code
   -- left join recruit_high_level t11 on concat(t1.name, '市')=t11.city_name
    left join sold_out_list t12 on t1.store_code=t12.store_code
    left join is_downgrade t13 on t1.store_code=t13.store_code
    left join jiameng_list t4 on t1.store_code=t4.store_code
    left join chedian_list_1 t15 on t1.store_code=t15.store_code

    where t1.is_store_close=0
      and t1.opening_days is not null
      and t4.store_code is null -- 剔除加盟店
      and t15.store_code is null -- 剔除撤店
      and t1.store_code not in ('123001355')
  --  and t3.b_hc is not null
;

drop table if exists data_build.tmp_resume_info_${DATE};
create table data_build.tmp_resume_info_${DATE} as

    select
         t1.store_code
        ,nvl(count(distinct if(t1.order_stage_status_desc = '已投递简历',t1.candidate_id,null)),0)                     as resume_cnt
        ,max_days
    from
    (
        select
             store_code
            ,candidate_id
            ,order_stage_status_desc
            ,days
            ,nvl(min(days)over(partition by t1.store_code),60)                                                         as max_days
        from
        (
            select
                 t1.position_dept_code          as store_code
                ,t1.candidate_id
                ,t1.order_stage_status_desc
                ,datediff('${FDATE_SUB0DAY}',to_date(t1.start_time))  as days
            from data_build.app_gis_store_recruit_stage_log_detail_v1_view t1
            inner join (
        select max(dt) as max_dt
        from data_build.app_gis_store_recruit_stage_log_detail_v1_view
        where dt >= '${DATE_SUB2DAY}'
        and dt <= '${DATE}'
        ) tmp on t1.dt = tmp.max_dt
            where t1.dt >= '${DATE_SUB2DAY}'
            and t1.dt <= '${DATE}'
            and t1.position_create_time >= '2022-01-01'
            and t1.position_job_code in ('NB0125','100330')
            and t1.order_recruit_pool_type != 'moka'
            and to_date(t1.start_time)>='${FDATE_SUB30DAY}'
            and t1.order_stage_status_desc = '已投递简历'
        )t1
    )t1
    group by t1.store_code,max_days
;

drop table if exists data_build.tmp_final_list_${DATE};
create table data_build.tmp_final_list_${DATE} as
    select distinct
         store_code
        ,case when (full_capacity_perdict_future_all>=1 and b_gap=0) or (b_gap=0 and epidemic_gap=0) then 1 else 0 end as is_group_recruit
        ,case
            -----------when full_capacity_perdict_future_all<1 and is_empty_window=1 then 'C4'
            when full_capacity_all<0.8 and fte_all<=1 then 'C4'
            when full_capacity_perdict_future_all>=1 then 'A1'
            when (b_gap<=0 and epidemic_gap<=0) or gap_all<=0 then 'A1'
            when full_capacity_perdict_future_all>0.8 and full_capacity_perdict_future_all<1 and gap_all<=2 then 'B1'
            when full_capacity_perdict_future_all>0.8 and full_capacity_perdict_future_all<1 and gap_all<=2 and is_upgrade=1 then 'B2'
            when full_capacity_perdict_future_all>0.6 and full_capacity_perdict_future_all<=0.8 and gap_all<=2 then 'B2'
            when full_capacity_perdict_future_all>0.6 and full_capacity_perdict_future_all<=0.8 and gap_all<=2 and is_upgrade=1 then 'B3'
            when full_capacity_perdict_future_all<=0.6 and gap_all<=2 then 'C1'
            when full_capacity_perdict_future_all<=0.6 and gap_all<=2 and is_upgrade=1 then 'C2'
            when full_capacity_perdict_future_all>0.8 and full_capacity_perdict_future_all<=1 and gap_all>2 then 'C2'
            when full_capacity_perdict_future_all>0.8 and full_capacity_perdict_future_all<=1 and gap_all>2 and is_upgrade=1 then 'C2'
            when full_capacity_perdict_future_all>0.6 and full_capacity_perdict_future_all<=0.8 and gap_all>2 then 'C3'
            when full_capacity_perdict_future_all>0.6 and full_capacity_perdict_future_all<=0.8 and gap_all>2 and is_upgrade=1 then 'C4'
            when full_capacity_perdict_future_all<=0.6 and gap_all>2 then 'C4'
         else NULL end as new_level
        ,case when b_gap>=1 and b_full_capacity_perdict_future<1 then 1 else 0 end as is_business_self
        ,case when a_gap>=1 and b_full_capacity_perdict_future<1 then 1 else 0 end as is_recruitment_department
    from data_build.tmp_base_list_${DATE} t1
;


drop table if exists data_build.tmp_recruit_gap_${DATE};
create table data_build.tmp_recruit_gap_${DATE} as
    select distinct
         t1.store_code
        ,t1.city_name
        ,case when new_level in ('C1','C2','C3','C4','B2','B3','B4') and is_pipeline_enough=1 then 'B1' else new_level end as new_level
        ,nvl(staffs,0)        as staffs ---剔除低意愿人员数量
        ,nvl(staffs_all,0)    as staffs_all---架构下人数
        ,concat_ws('-',t1.city_name,t4.area_dept_code)                   as h3_group
    from data_build.tmp_base_list_${DATE} t1
    left join data_build.tmp_final_list_${DATE} t5 on t1.store_code=t5.store_code
    left join
    (
        select
             hps_dept_code_lv5 as department_code
            ,count(distinct emplid)  as staffs_all
        from data_build.pdw_psprod_ps_blf_ehr_pers_vw_view
        where dt='${DATE}'
        and hps_d_hr_status='在职'
        and hps_d_jobcode in ('店经理','储备店经理','见习店经理','门店伙伴','店副经理','社会PT','学生PT','内部合作经营者','内部合作辅助人','内部合作伙伴','外部合作经营者','外部合作辅助人','外部合作伙伴')
        group by hps_dept_code_lv5
    )t3 on t1.store_code=t3.department_code
    left join data_build.dim_store_info_managers_view t4 on t1.store_code=t4.store_code and t4.dt='${DATE}'
;

drop table if exists data_build.tmp_ddang_list_${DATE};
create table data_build.tmp_ddang_list_${DATE} as

with ddang as
(
    select
 t1.store_code
 ,t1.record_date
 ,t1.type
 ,from_unixtime(unix_timestamp(t1.dt,'yyyyMMdd'),'yyyy-MM-dd') as new_dt
 from data_smartorder.app_roster_report_last_30days_empty_store_list_di t1
    inner join (
    select max(dt) as max_dt
    from data_smartorder.app_roster_report_last_30days_empty_store_list_di
    where dt >= '${DATE_SUB2DAY}'
    and dt <= '${DATE}'
    ) tmp on t1.dt = tmp.max_dt
 where t1.dt >= '${DATE_SUB2DAY}'
 and t1.dt <= '${DATE}'
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
    left join default.dim_date_ya_v2 t2
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
)


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
;


drop table if exists data_build.tmp_paiban_level_${DATE};
create table data_build.tmp_paiban_level_${DATE} as

-- 1027累计单店排班结果
with paiban_base_list as
(
select
t1.store_code
,t1.dt
,t1.work_date
,date_sub(t1.work_date,1) as work_date_1
,date_sub(t1.work_date,2) as work_date_2
,date_sub(t1.work_date,3) as work_date_3
,date_sub(t1.work_date,4) as work_date_4
,date_sub(t1.work_date,5) as work_date_5
,date_sub(t1.work_date,6) as work_date_6
,date_sub(t1.work_date,7) as work_date_7
,t1.drop_range
,t1.schedule_range
,t1.failure_hours
,t1.cost_across_hours
,t1.uncost_across_hours
,(t1.should_leave_hours + t1.end_ordinary_hours) as di_hours
,(t1.drop_range/t1.schedule_range) as diuban_zhanbi
,(t1.failure_hours/t1.schedule_range) as shibai_zhanbi
,(t1.cost_across_hours/t1.schedule_range) as cost_across_zhanbi
,(t1.uncost_across_hours/t1.schedule_range) as uncost_across_zhanbi
,((t1.should_leave_hours + t1.end_ordinary_hours)/t1.schedule_range) as di_zhanbi
from data_smartorder.app_roster_report_shop_day_schedule_effect_di t1
inner join (
        select max(dt) as max_dt
        from data_smartorder.app_roster_report_shop_day_schedule_effect_di
        where dt >= '${DATE_SUB2DAY}'
        and dt <= '${DATE}'
        ) tmp on t1.dt = tmp.max_dt
where t1.dt >= '${DATE_SUB2DAY}'
and t1.dt <= '${DATE}'
-- and date_format(work_date,'yyyyMMdd') >= '2022-10-10'
),
paiban_7_days_list as
(
    select
    t1.store_code
    ,t1.work_date
    ,t1.work_date_1
    ,t1.work_date_2
    ,t1.work_date_3
    ,t1.work_date_4
    ,t1.work_date_5
    ,t1.work_date_6
    ,t1.work_date_7
    ,t1.diuban_zhanbi
    ,t1.shibai_zhanbi
    ,t1.cost_across_zhanbi
    ,t1.uncost_across_zhanbi
    ,t1.di_zhanbi

    ,max(nvl(case when t2.work_date = t1.work_date_1 then t2.drop_range else null end,0)) as drop_range_1
    ,max(nvl(case when t2.work_date = t1.work_date_2 then t2.drop_range else null end,0)) as drop_range_2
    ,max(nvl(case when t2.work_date = t1.work_date_3 then t2.drop_range else null end,0)) as drop_range_3
    ,max(nvl(case when t2.work_date = t1.work_date_4 then t2.drop_range else null end,0)) as drop_range_4
    ,max(nvl(case when t2.work_date = t1.work_date_5 then t2.drop_range else null end,0)) as drop_range_5
    ,max(nvl(case when t2.work_date = t1.work_date_6 then t2.drop_range else null end,0)) as drop_range_6
    ,max(nvl(case when t2.work_date = t1.work_date_7 then t2.drop_range else null end,0)) as drop_range_7
    ,max(nvl(case when t2.work_date = t1.work_date_1 then t2.failure_hours else null end,0)) as failure_hours_1
    ,max(nvl(case when t2.work_date = t1.work_date_2 then t2.failure_hours else null end,0)) as failure_hours_2
    ,max(nvl(case when t2.work_date = t1.work_date_3 then t2.failure_hours else null end,0)) as failure_hours_3
    ,max(nvl(case when t2.work_date = t1.work_date_4 then t2.failure_hours else null end,0)) as failure_hours_4
    ,max(nvl(case when t2.work_date = t1.work_date_5 then t2.failure_hours else null end,0)) as failure_hours_5
    ,max(nvl(case when t2.work_date = t1.work_date_6 then t2.failure_hours else null end,0)) as failure_hours_6
    ,max(nvl(case when t2.work_date = t1.work_date_7 then t2.failure_hours else null end,0)) as failure_hours_7
    ,max(nvl(case when t2.work_date = t1.work_date_1 then t2.cost_across_hours else null end,0)) as cost_across_hours_1
    ,max(nvl(case when t2.work_date = t1.work_date_2 then t2.cost_across_hours else null end,0)) as cost_across_hours_2
    ,max(nvl(case when t2.work_date = t1.work_date_3 then t2.cost_across_hours else null end,0)) as cost_across_hours_3
    ,max(nvl(case when t2.work_date = t1.work_date_4 then t2.cost_across_hours else null end,0)) as cost_across_hours_4
    ,max(nvl(case when t2.work_date = t1.work_date_5 then t2.cost_across_hours else null end,0)) as cost_across_hours_5
    ,max(nvl(case when t2.work_date = t1.work_date_6 then t2.cost_across_hours else null end,0)) as cost_across_hours_6
    ,max(nvl(case when t2.work_date = t1.work_date_7 then t2.cost_across_hours else null end,0)) as cost_across_hours_7
    ,max(nvl(case when t2.work_date = t1.work_date_1 then t2.uncost_across_hours else null end,0)) as uncost_across_hours_1
,max(nvl(case when t2.work_date = t1.work_date_2 then t2.uncost_across_hours else null end,0)) as uncost_across_hours_2
,max(nvl(case when t2.work_date = t1.work_date_3 then t2.uncost_across_hours else null end,0)) as uncost_across_hours_3
,max(nvl(case when t2.work_date = t1.work_date_4 then t2.uncost_across_hours else null end,0)) as uncost_across_hours_4
,max(nvl(case when t2.work_date = t1.work_date_5 then t2.uncost_across_hours else null end,0)) as uncost_across_hours_5
,max(nvl(case when t2.work_date = t1.work_date_6 then t2.uncost_across_hours else null end,0)) as uncost_across_hours_6
,max(nvl(case when t2.work_date = t1.work_date_7 then t2.uncost_across_hours else null end,0)) as uncost_across_hours_7
,max(nvl(case when t2.work_date = t1.work_date_1 then t2.schedule_range else null end,0)) as schedule_range_1
,max(nvl(case when t2.work_date = t1.work_date_2 then t2.schedule_range else null end,0)) as schedule_range_2
,max(nvl(case when t2.work_date = t1.work_date_3 then t2.schedule_range else null end,0)) as schedule_range_3
,max(nvl(case when t2.work_date = t1.work_date_4 then t2.schedule_range else null end,0)) as schedule_range_4
,max(nvl(case when t2.work_date = t1.work_date_5 then t2.schedule_range else null end,0)) as schedule_range_5
,max(nvl(case when t2.work_date = t1.work_date_6 then t2.schedule_range else null end,0)) as schedule_range_6
,max(nvl(case when t2.work_date = t1.work_date_7 then t2.schedule_range else null end,0)) as schedule_range_7
,max(nvl(case when t2.work_date = t1.work_date_1 then t2.di_hours else null end,0)) as di_hours_1
,max(nvl(case when t2.work_date = t1.work_date_2 then t2.di_hours else null end,0)) as di_hours_2
,max(nvl(case when t2.work_date = t1.work_date_3 then t2.di_hours else null end,0)) as di_hours_3
,max(nvl(case when t2.work_date = t1.work_date_4 then t2.di_hours else null end,0)) as di_hours_4
,max(nvl(case when t2.work_date = t1.work_date_5 then t2.di_hours else null end,0)) as di_hours_5
,max(nvl(case when t2.work_date = t1.work_date_6 then t2.di_hours else null end,0)) as di_hours_6
,max(nvl(case when t2.work_date = t1.work_date_7 then t2.di_hours else null end,0)) as di_hours_7

    from paiban_base_list t1
    left join paiban_base_list t2
    on t1.store_code = t2.store_code
    and t1.dt = t2.dt
    group by t1.store_code
    ,t1.work_date
    ,t1.work_date_1
    ,t1.work_date_2
    ,t1.work_date_3
    ,t1.work_date_4
    ,t1.work_date_5
    ,t1.work_date_6
    ,t1.work_date_7
    ,t1.diuban_zhanbi
    ,t1.shibai_zhanbi
    ,t1.cost_across_zhanbi
    ,t1.uncost_across_zhanbi
    ,t1.di_zhanbi
),
final_paiban_list as
(
select
store_code
,work_date
,(failure_hours_1+failure_hours_2+failure_hours_3+failure_hours_4+failure_hours_5+failure_hours_6+failure_hours_7) as failure_hours_7
,(cost_across_hours_1+cost_across_hours_2+cost_across_hours_3+cost_across_hours_4+cost_across_hours_5+cost_across_hours_6+cost_across_hours_7) as cost_across_hours_7
,(schedule_range_1+schedule_range_2+schedule_range_3+schedule_range_4+schedule_range_5+schedule_range_6+schedule_range_7) as schedule_range_7
,(di_hours_1+di_hours_2+di_hours_3+di_hours_4+di_hours_5+di_hours_6+di_hours_7) as di_hours_7
,(drop_range_1+drop_range_2+drop_range_3+drop_range_4+drop_range_5+drop_range_6+drop_range_7) as drop_range_7
,(uncost_across_hours_1+uncost_across_hours_2+uncost_across_hours_3+uncost_across_hours_4+uncost_across_hours_5+uncost_across_hours_6+uncost_across_hours_7) as uncost_across_hours_7
from paiban_7_days_list
),
paiban_final as
(
    select
    store_code
    ,work_date
    ,(cost_across_hours_7/schedule_range_7) as cost_across_zhanbi
    ,(drop_range_7/schedule_range_7) as diuban_zhanbi
    ,(failure_hours_7/schedule_range_7) as shibai_zhanbi
    ,(uncost_across_hours_7/schedule_range_7) as uncost_across_zhanbi
    ,(di_hours_7/schedule_range_7) as di_zhanbi
    from final_paiban_list
)

    select distinct
    work_date
    ,date_format(work_date,'yyyyMMdd') as work_datekey
    ,store_code
    ,case when shibai_zhanbi > 0.05 and cost_across_zhanbi >0.1 then 1
    else 0 end as paiban_level
    from paiban_final
    where date_format(work_date,'yyyyMMdd') = '${DATE}'
;

drop table if exists data_build.tmp_final_out_list_${DATE};
create table data_build.tmp_final_out_list_${DATE} as
with city_rank as
(
    select
         distinct city_name
        ,min(city_type)over(partition by city_name) as city_type
    from
    (
        select
             t1.store_city as city_name
            ,'1'        as city_type
        from data_build.app_roster_report_high_failure_shift_rate_city_da_view t1
        inner join
        (
        select max(dt) as max_dt
        from data_build.app_roster_report_high_failure_shift_rate_city_da_view
        where dt >= '${DATE_SUB2DAY}'
        and dt <= '${DATE}'
        ) tmp on t1.dt = tmp.max_dt
        where t1.dt >= '${DATE_SUB2DAY}'
        and t1.dt <= '${DATE}'

        union all

        select
             t1.store_city as city_name
            ,'2'  as  city_type
        from data_build.app_roster_report_high_failure_shift_rate_city_da_view t1
        inner join
        (
        select max(dt) as max_dt
        from data_build.app_roster_report_high_failure_shift_rate_city_da_view
        where dt >= '${DATE_SUB2DAY}'
        and dt <= '${DATE}'
        ) tmp on t1.dt = tmp.max_dt
        where t1.dt >= '${DATE_SUB2DAY}'
        and t1.dt <= '${DATE}'
    ) t1
),
area_list_1 as
(
    select
         h3_group
        ,h3_area_rank
        ,city_type
        ,max(h3_area_rank)over(partition by city_type) as rank_mark
    from
    (
        select
             h3_group
            ,row_number()over(partition by city_type order by stores desc)  as h3_area_rank
            ,city_type
        from
        (
            select
                h3_group
                ,count(distinct case when new_level='C4' then t1.store_code end) as stores
                ,case when t3.city_name is null then 3 else  t3.city_type end    as city_type
            from data_build.tmp_recruit_gap_${DATE} t1
            left join data_build.dim_store_info_managers_view t2 on t1.store_code=t2.store_code and t2.dt='${DATE}'
            left join city_rank t3 on concat(t1.city_name, '市')=t3.city_name
            group by
                h3_group
                ,case when t3.city_name is null then 3 else  t3.city_type end
        )t1
        where stores>0
    )t1
    group by
         h3_group
        ,h3_area_rank
        ,city_type
),
area_rank_1 as
(
    select
         city_type
        ,rank_mark
        ,cast(cast(city_type as int)+1  as string) as city_type2
        ,cast(cast(city_type as int)+2  as string) as city_type3
    from area_list_1
),
area_list as
(
    select
         t1.h3_group
        ,t1.city_type
        ,case
            when t1.city_type='1' then t1.h3_area_rank
            when t1.city_type='2' then t1.h3_area_rank+nvl(t2.rank_mark,0)
            when t1.city_type='3' then t1.h3_area_rank+nvl(t2.rank_mark,0)+nvl(t3.rank_mark,0)
         end  as h3_area_rank
    from area_list_1  t1
    left join area_rank_1 t2 on t1.city_type=t2.city_type2
    left join area_rank_1 t3 on t1.city_type=t3.city_type3
),
group_gap_list as
(
    select
         a_store_code
        ,count(distinct b_store_code) as stores_g
        ,sum(b_hc)      as operate_hc_g
        ,sum(fte)       as operate_fte_g
        ,ceil(sum(b_hc)-sum(fte))  as operate_gap_g
        ,sum(store_epidemic_hc)    as epidemic_hc_g
        ,sum(epidemics)            as epidemics_fte_g
        ,round(sum(store_epidemic_hc)-sum(epidemics),0) as epidemic_gap_g
        ,sum(hc_all)    as all_hc_g
        ,sum(fte_all)   as all_fte_g
        ,ceil(sum(hc_all)-sum(fte_all))  as all_gap_g
        ,sum(fte_all)/sum(hc_all)        as full_capacity_perdict_future_g
    from
    (
        select
             t1.a_store_code
            ,t1.b_store_code
            ,nvl(t2.b_hc,0)              as b_hc
            ,nvl(t2.fte,0)               as fte
            ,nvl(t2.store_epidemic_hc,0) as store_epidemic_hc
            ,nvl(t2.epidemics,0)         as epidemics
            ,nvl(t2.hc_all,0)            as hc_all
            ,nvl(t2.fte_all2,0)           as fte_all
        from data_build.tmp_store_group_${DATE} t1
        left join data_build.tmp_base_list_${DATE} t2 on t1.b_store_code=t2.store_code
    )t
    group by
         a_store_code
)

,flexible_onjob_detail as 
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
from data_build.pdw_psprod_ps_blf_ehr_pers_vw_view t1
where t1.dt = '${DATE}'
and t1.hps_dept_descr_lv5 like '%区X%'
and hps_d_hr_status ='在职'
)

,flexible_onjob_count as 
(
select 
district_code 
,nvl(count(distinct emplid),0) as flexible_count
from flexible_onjob_detail 
group by district_code
)

,student_count as 
( 
select 
t1.district_code
,nvl(count(distinct case when t1.hps_d_jobcode = '学生PT' and t1.roster_count >=3 and t1.is_di <> 'blacklist' then t1.employee_id end),0) as hc_district_student
from data_build.dwd_store_construction_roster_staff_supply_v1_di t1
where t1.dt = '${DATE}'
and t1.district_code <>0 
group by 
t1.district_code
)
,student_count_store as 
( 
select 
t1.store_code
,nvl(count(distinct case when t1.hps_d_jobcode = '学生PT' and t1.roster_count >=3 and t1.is_di <> 'blacklist' then t1.employee_id end),0) as gap_student
,nvl(count(distinct case when t1.key_staff_type ='manager' then t1.employee_id end),0) as manager_count
,nvl(count(distinct case when t1.key_staff_type ='sec_manager' then t1.employee_id end),0) as sec_manager_count
,nvl(count(distinct case when t1.key_staff_type ='key_staff' then t1.employee_id end),0) as key_staff_count
from data_build.dwd_store_construction_roster_staff_supply_v1_di t1
inner join (
        select max(dt) as max_dt
        from data_build.dwd_store_construction_roster_staff_supply_v1_di
        where dt >= '${DATE_SUB2DAY}'
        and dt <= '${DATE}'
        ) tmp on t1.dt = tmp.max_dt
where t1.dt >= '${DATE_SUB2DAY}'
    and t1.dt <= '${DATE}'
group by 
t1.store_code
)

,short_hc_count as 
(
select
t1.district_code as district_code
,nvl(sum(t1.hc_new),0) as hc_all_store
,nvl(sum(t1.gap_new),0) as gap_all_store
,nvl(sum(case when t1.hc_new <= 4 then t1.gap_short_day end),0) as hc_district_short
from data_build.dwd_store_construction_full_capacity_perdict t1 
    inner join (
        select max(dt) as max_dt
        from data_build.dwd_store_construction_full_capacity_perdict
        where dt >= '${DATE_SUB2DAY}'
        and dt <= '${DATE}'
        ) tmp on t1.dt = tmp.max_dt
where t1.dt >= '${DATE_SUB2DAY}'
    and t1.dt <= '${DATE}'
and t1.district_code <>0 
group by 
t1.district_code
)

 ,cv_today as 
 (
 select 
  t2.store_code 
  ,t2.date_key 
  ,sum(t2.delivery_candiddate) as deliver_cv_today

from  data_gis_h3.mid_gis_h3_store_recruit_level_da t2 
inner join (
select max(dt) as max_dt
from data_gis_h3.mid_gis_h3_store_recruit_level_da
where dt >= '${DATE_SUB2DAY}'
and dt <= '${DATE}'
) tmp
on t2.dt = tmp.max_dt
where t2.date_key = from_unixtime(unix_timestamp(t2.dt,'yyyymmdd'),'yyyy-mm-dd')
group by t2.store_code 
,t2.date_key
)

--20260323调整机动队利用率算法
,district_use_raw_list as(
select a.*,
case b.business_district_id
when '1000'then '区X001北京' when '1001'then '区X002北京' when '1002'then '区X003北京' when '1232'then '区X004天津' when '1231'then '区X005天津'
when '1018'then '区X006上海' when '1101'then '区X007南京' when '1094'then '区X008杭州' when '1074'then '区X009济南' when '6120'then '区X010宁波'
when '1080'then '区X012青岛' when '10012'then '区X013北京' when '10013'then '区X014北京' when '10014'then '区X015北京' when '10015'then '区X016北京'
when '10016'then '区X017北京' when '1230'then '区X018天津' when '1019'then '区X019上海' when '1100'then '区X020南京' when '1070'then '区X021济南'
when '10018'then '区X024北京' when '1880'then '区X027廊坊' when '1030'then '区X028石家庄' when '1210'then '区X029郑州' when '3970'then '区X030常州'
when '6121'then '区X031宁波' when '1110'then '区X032苏州' when '1182'then '区X033无锡' when '2330'then '区X034金华' when '2320'then '区X035温州'
when '1003'then '区X036北京' when '1004'then '区X037北京' when '1005'then '区X038北京' when '1006'then '区X039北京' when '1007'then '区X040北京'
when '1008'then '区X041北京' when '1009'then '区X042北京' when '10010'then '区X043北京' when '10011'then '区X044北京' when '10017'then '区X045北京'
when '1233'then '区X046天津' when '1234'then '区X047天津' when '1235'then '区X048天津' when '1236'then '区X049天津' when '1237'then '区X050天津'
when '1238'then '区X051天津' when '1239'then '区X052天津' when '3971'then '区X053常州' when '1093'then '区X054杭州' when '1092'then '区X055杭州'
when '1091'then '区X056杭州' when '1090'then '区X057杭州' when '1071'then '区X058济南' when '1072'then '区X059济南' when '1073'then '区X060济南'
when '1102'then '区X061南京' when '1103'then '区X062南京' when '1104'then '区X063南京' when '1105'then '区X064南京' when '1106'then '区X065南京'
when '1107'then '区X066南京' when '1211'then '区X067郑州' when '1181'then '区X068无锡' when '1180'then '区X069无锡' when '1113'then '区X070苏州'
when '1112'then '区X071苏州' when '1081'then '区X072青岛' when '1082'then '区X073青岛' when '6123'then '区X074宁波' when '6122'then '区X075宁波'
when '1011'then '区X076上海' when '1012'then '区X077上海' when '1013'then '区X078上海' when '1014'then '区X079上海' when '1015'then '区X080上海'
when '1016'then '区X081上海' when '1017'then '区X082上海' when '1018'then '区X083上海' else null end as business_district_id,
case when a.work_shift_second_desc in ('上货支援','普通','临时店长班次','储备班次','困难店整改','复业工时','撤店工时','效期整改班次','新店建店','机动队支援加盟店班次','机动队效期检查','机动队月盘','远程支援','陈列工时')
then 1 else 0 end as is_special,
case when a.work_shift_second_desc in ('上货支援','普通','专项整改','临时店长班次','储备班次','困难店整改','复业工时','撤店工时','效期整改班次','新店建店','机动队支援加盟店班次','机动队效期检查','机动队月盘','远程支援','陈列工时')
or a.day_manager_info = 1 or a.night_manager_info = 1 or a.roster_peace_info = 1  then  1 else 0 end as is_general
from data_smartorder.dm_roster_tmp_use_ratio a
left join data_smartorder.ods_uploads_business_district_qiyang b on a.store_code = b.store_code
where a.dt = '${DATE}'
and a.hps_dept_descr_lv1 = '运营管理部X'
and a.work_shift_second_desc not in ('机动队新人班次','机动队岗前培训班次','岗前培训班次')
)

,district_attendance as(--每个商圈的出勤
select 
work_shift_date,
business_district_id,
is_night,
count(distinct case when is_special = 1 then concat(employee_no,work_shift_date) end ) as is_special_cnt,
count(distinct case when is_general = 1 then concat(employee_no,work_shift_date)  end ) as is_general_cnt
from district_use_raw_list
group by
work_shift_date,
business_district_id,
is_night
)

,hps_dept_descr_lv5_attendance as(--每个商圈实际员工
select 
work_shift_date,
hps_dept_descr_lv5,
is_night,
count(distinct concat(employee_no,work_shift_date)) as employee_num 
from district_use_raw_list
group by
work_shift_date,
hps_dept_descr_lv5,
is_night
)

,final_district_use as(
select
a.work_shift_date,
a.business_district_id,
a.is_night,
a.is_special_cnt,
a.is_general_cnt,
b.employee_num,
nvl(a.is_special_cnt/b.employee_num,1) as special_rate,
nvl(a.is_general_cnt/b.employee_num,1) as general_rate
from district_attendance a
left join hps_dept_descr_lv5_attendance b on a.work_shift_date = b.work_shift_date and a.business_district_id = b.hps_dept_descr_lv5 and a.is_night = b.is_night
)

,district_usage_prep_data as (
    select
    business_district_id
    ,case business_district_id
        when '区X001北京' then '1000' when '区X002北京' then '1001'
        when '区X003北京' then '1002' when '区X004天津' then '1232'
        when '区X005天津' then '1231' when '区X006上海' then '1018'
        when '区X007南京' then '1101'
        when '区X008杭州' then '1094'when '区X009济南' then '1074'
        when '区X010宁波' then '6120' when '区X012青岛' then '1080'
        when '区X013北京' then '10012' when '区X014北京' then '10013'
        when '区X015北京' then '10014' when '区X016北京' then '10015'
        when '区X017北京' then '10016'
        when '区X018天津' then '1230' when '区X019上海' then '1019'
        when '区X020南京' then '1100' when '区X021济南' then '1070'
        when '区X024北京' then '10018' when '区X027廊坊' then '1880'
        when '区X028石家庄' then '1030' when '区X029郑州' then '1210'
        when '区X030常州' then '3970' when '区X031宁波' then '6121'
        when '区X032苏州' then '1110' when '区X033无锡' then '1182'
        when '区X034金华' then '2330' when '区X035温州' then '2320'
        when '区X036北京' then '1003' when '区X037北京' then '1004'
        when '区X038北京' then '1005'
        when '区X039北京' then '1006' when '区X040北京' then '1007'
        when '区X041北京' then '1008'
        when '区X042北京' then '1009' when '区X043北京' then '10010'
        when '区X044北京' then '10011'when '区X045北京' then '10017'
        when '区X046天津' then '1233' when '区X047天津' then '1234'
        when '区X048天津' then '1235' when '区X049天津' then '1236'
        when '区X050天津' then '1237'
        when '区X051天津' then '1238' when '区X052天津' then '1239'
        when '区X053常州' then '3971' when '区X054杭州' then '1093'
        when '区X055杭州' then '1092' when '区X056杭州' then '1091'
        when '区X057杭州' then '1090' when '区X058济南' then '1071'
        when '区X059济南' then '1072' when '区X060济南' then '1073'
        when '区X061南京' then '1102' when '区X062南京' then '1103'
        when '区X063南京' then '1104' when '区X064南京' then '1105'
        when '区X065南京' then '1106'
        when '区X066南京' then '1107' when '区X067郑州' then '1211'
        when '区X068无锡' then '1181' when '区X069无锡' then '1180'
        when '区X070苏州' then '1113' when '区X071苏州' then '1112'
        when '区X072青岛' then '1081' when '区X073青岛' then '1082'
        when '区X074宁波' then '6123' when '区X075宁波' then '6122'
        when '区X076上海' then '1011' when '区X077上海' then '1012'
        when '区X078上海' then '1013'
        when '区X079上海' then '1014' when '区X080上海' then '1015'
        when '区X081上海' then '1016' when '区X082上海' then '1017'
        when '区X083上海' then '1018' else business_district_id end as district_code

    ,AVG(CASE WHEN is_night = 1 AND work_shift_date BETWEEN date_sub(from_unixtime(unix_timestamp('${DATE}','yyyyMMdd'),'yyyy-MM-dd'),15)  AND date_sub(from_unixtime(unix_timestamp('${DATE}','yyyyMMdd'),'yyyy-MM-dd'),1) THEN special_rate ELSE NULL END) AS special_rate_night_14days
    ,AVG(CASE WHEN is_night = 1 AND work_shift_date BETWEEN date_sub(from_unixtime(unix_timestamp('${DATE}','yyyyMMdd'),'yyyy-MM-dd'),15)  AND date_sub(from_unixtime(unix_timestamp('${DATE}','yyyyMMdd'),'yyyy-MM-dd'),1) THEN general_rate ELSE NULL END) as general_rate_night_14days
    ,AVG(CASE WHEN is_night = 0 AND work_shift_date BETWEEN date_sub(from_unixtime(unix_timestamp('${DATE}','yyyyMMdd'),'yyyy-MM-dd'),15)  AND date_sub(from_unixtime(unix_timestamp('${DATE}','yyyyMMdd'),'yyyy-MM-dd'),1) THEN special_rate ELSE NULL END) AS special_rate_day_14days
    ,AVG(CASE WHEN is_night = 0 AND work_shift_date BETWEEN date_sub(from_unixtime(unix_timestamp('${DATE}','yyyyMMdd'),'yyyy-MM-dd'),15)  AND date_sub(from_unixtime(unix_timestamp('${DATE}','yyyyMMdd'),'yyyy-MM-dd'),1) THEN general_rate ELSE NULL END) as general_rate_day_14days

from final_district_use
group by business_district_id
)

,district_usage as (
select

t1.district_code
,t1.hc_all_district
,t1.hc_night_district
,t1.hc_day_district
,t1.gap_day_district
,t1.gap_night_district
,t1.gap_all_district
,t1.gap_with_replace_district
,t1.reward_level_district
,t1.reward_level_night_district
,t2.business_district_id
,t2.special_rate_night_14days
,t2.general_rate_night_14days
,t2.special_rate_day_14days
,t2.general_rate_day_14days
from data_build.dwd_store_construction_full_capacity_perdict t1
left join district_usage_prep_data t2 on t1.district_code = t2.district_code
inner join (
        select max(dt) as max_dt
        from data_build.dwd_store_construction_full_capacity_perdict
        where dt >= '${DATE_SUB2DAY}'
        and dt <= '${DATE}'
        ) tmp on t1.dt = tmp.max_dt
where t1.dt >= '${DATE_SUB2DAY}'
and t1.dt <= '${DATE}'
)


,district_reward_level_3 as
(
select
district_code
,hc_all_district
,hc_night_district
,hc_day_district
,gap_with_replace_district
,reward_level_district
,reward_level_night_district
,special_rate_night_14days
,general_rate_night_14days
,special_rate_day_14days
,general_rate_day_14days
,case when special_rate_day_14days < 0.85 or special_rate_night_14days < 0.85 then 0 else
(case when gap_day_district <=0 and special_rate_day_14days >=0.85 then (hc_day_district-gap_day_district)/special_rate_day_14days-hc_day_district else gap_day_district end) end as gap_day_district
,case when special_rate_day_14days < 0.85 or special_rate_night_14days < 0.85 then 0 else
(case when gap_night_district <=0 and special_rate_night_14days >=0.85 then (hc_night_district-gap_night_district)/special_rate_night_14days-hc_night_district else gap_night_district end) end as gap_night_district
,case when special_rate_day_14days < 0.85 or special_rate_night_14days < 0.85 then 0 else
((case when gap_day_district <=0 and special_rate_day_14days >=0.85 then (hc_day_district-gap_day_district)/special_rate_day_14days-hc_day_district else gap_day_district end) + (case when gap_night_district <=0 and special_rate_night_14days >=0.85 then (hc_night_district-gap_night_district)/special_rate_night_14days-hc_night_district else gap_night_district end)) end as gap_all_district

from district_usage t1

)

--20240515 midnight

,gap_district_output as
(
select distinct 
t1.district_code
,round(t1.hc_all_district,0) as hc_all_district
,round(t1.hc_night_district,0) as hc_night_district
,round(t1.hc_day_district,0) as hc_day_district
,round(t1.gap_all_district,0) as gap_all_district
,round(t1.gap_day_district,0) as gap_day_district
,round(t1.gap_night_district,0) as gap_night_district
,round(t1.gap_with_replace_district,0) as gap_with_replace_district
,case when t1.gap_all_district >0 and special_rate_day_14days >=0.9 then 'P5'
when t1.gap_all_district >0 and special_rate_day_14days >=0.85 then 'P3'
when t1.gap_all_district <=0 then 'P1' else 'P2' end as reward_level_district
,case when t1.gap_night_district >0 and special_rate_night_14days >=0.9 then 'P5'
when t1.gap_night_district >0 and special_rate_night_14days >=0.85 then 'P3'
when t1.gap_night_district <=0 then 'P1' else 'P2' end as reward_level_night_district
,t4.flexible_count as fte_district

from district_reward_level_3  t1 
left join flexible_onjob_count t4 on t1.district_code = t4.district_code
)
 
,longterm_last_list as
(
select 
store_code
,alarm_date, --T值对应日期
 is_tail_store, --是否长期尾部店(1 是, 0 不是 【06-24前 均值>=4.4是长期尾部店。06-24当日及以后 均值>=3.6是尾部店】)
 avg_last_7day_final_level --(近7日T值均值)
 from default.dwd_store_operation_level_changelog_ha_v1
 where dt = '${DATE_SUB0DAY}'
 and hr = '11'
 and alarm_date ='${FDATE_SUB1DAY}'
 and is_tail_store = 1
)


,new_difficulty_level_with_work_level as --20240525 added 
(
select
t1.store_id
,t1.sale_level 
,t1.work_level 
,int(substr(t2.difficulty_level, 2))
,case 
    when t1.work_level =6 and t1.sale_level between 6000 and 16000 then int(substr(t2.difficulty_level, 2))+2
    when t1.work_level >=5 and t1.sale_level < 6000 then int(substr(t2.difficulty_level, 2))+2
    when t1.work_level <=4 and t1.sale_level >= 15000 then int(substr(t2.difficulty_level, 2))
    when t1.work_level <=3 and t1.sale_level <15000 then int(substr(t2.difficulty_level, 2))
    else int(substr(t2.difficulty_level, 2))+1 end as difficulty_level_value_only




from data_build.dwd_store_construction_roster_store_demand_v1_di t1
left join data_build.dwd_store_construction_full_capacity_perdict t2
    on t1.store_id = t2.store_code and t1.dt = t2.dt
where t1.dt = '${DATE_SUB2DAY}' 

)




,new_fte_hc_gap as
(
    select
    t1.store_code
    ,concat('D',t5.difficulty_level_value_only) as difficulty_level --20240525 changed
    ,t1.priority_level
    ,t1.reward_level
    ,t1.reward_level_night
   -- ,t1.reward_level
   -- ,t1.reward_level_night
    ,t1.is_highsale
    ,t1.is_longterm
    ,t1.is_borderline
    ,t1.hc_day
    ,t1.hc_night
    ,t1.hc_new
    ,t1.fte_day
    ,t1.fte_night
    ,t1.fte_new
   -- ,t1.gap_day
   -- ,t1.gap_night
   -- ,t1.gap_new
    ,t1.gap_day + case when t4.student_type = 1 then 1 else 0 end as gap_day
    ,t1.gap_night + case when t4.student_type = -1 then 1 else 0 end as gap_night
    ,t1.gap_new + case when t4.store_code is not null then 1 else 0 end as gap_new 
    ,t1.full_capacity_day
    ,t1.full_capacity_night
    ,t1.full_capacity_new
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
,t1.fte_new_miss_2 as fte_new_miss_2
,t1.fte_new_withoutlow_miss_2 as fte_new_withoutlow_miss_2
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
 ,t1.group_level as group_level_new
,t1.is_vip as is_vip
,t1.is_potential as is_potential
,t1.difficulty_level_new as difficulty_level_new
,t1.group_type_day as group_type_day
,t1.group_type_night as group_type_night
,t1.roster_gap_day as roster_gap_day
,t1.roster_gap_night as roster_gap_night
,t1.reward_level_retention as reward_level_retention
,t1.reward_level_night_retention as reward_level_night_retention

,nvl(t1.district_code,0) as district_code
--,nvl(t2.hc_all_district,0) as hc_all_district
,nvl(t2.hc_all_district,0) as hc_all_district

,nvl(t2.hc_night_district,0) as hc_night_district
,nvl(t2.hc_day_district,0) as hc_day_district
--,nvl(t2.gap_all_district,0) as gap_all_district
,nvl(t2.gap_all_district,0) as gap_all_district

,nvl(t2.gap_day_district,0) as gap_day_district
,nvl(t2.gap_night_district,0) as gap_night_district
,nvl(t2.reward_level_district,0) as reward_level_district
,nvl(t2.reward_level_night_district,0) as reward_level_night_district
--,nvl(t2.gap_with_replace_district,0) as gap_with_replace_district
,nvl(t2.gap_with_replace_district,0) as gap_with_replace_district

,nvl(t3.gap_student,0) as gap_student
,t3.key_staff_count as key_staff_count
,case when t3.manager_count = 0 or t3.sec_manager_count = 0 then '4-店长店副缺编'  
when t1.gap_new >= 1 then '3-有缺口' 
when t1.hc_new = 3 and t3.key_staff_count = 0 then '2-骨干缺编' 
when t1.hc_new >=4 and t3.key_staff_count <=1 then '2-骨干缺编'
else '1-骨干满编' end as key_staff_store_type 
,case when t6.deliver_cv_today >=1 then 1 
 when t1.gap_new = 0 then '-' else 0 end as is_cv
,nvl(t2.fte_district,0) as fte_district
,nvl(t1.hc_all_district,0) as hc_all_district_base
    from data_build.dwd_store_construction_full_capacity_perdict t1
    left join cv_today t6 on t1.store_code = t6.store_code 
    left join gap_district_output t2 on t1.district_code =t2.district_code 
    left join student_count_store t3 on t1.store_code = t3.store_code 
    left join data_build.ods_uploads_student_gap t4 on t1.store_code = t4.store_code and t4.dt = '${DATE}'
    left join new_difficulty_level_with_work_level t5 on t1.store_code = t5.store_id 
    inner join (
        select max(dt) as max_dt
        from data_build.dwd_store_construction_full_capacity_perdict
        where dt >= '${DATE_SUB2DAY}'
        and dt <= '${DATE}'
        ) tmp on t1.dt = tmp.max_dt

    where t1.dt >= '${DATE_SUB2DAY}'
    and t1.dt <= '${DATE}'
    )


select distinct
     t0.store_code
    ,t0.store_name
    ,t0.city_name
    ,t0.recovery_label

    ,t0.b_hc--理想运营HC
    ,t0.a_hc--最低开业HC
    ,t0.fte
    ,case when t1.new_level='A1' then 0 else t0.a_gap end as a_gap ---总部招聘GAP
    ,t0.b_gap--门店自招GAP
    ,t0.a_full_capacity_perdict_future
    ,t0.b_full_capacity_perdict_future
    ,t0.store_type

    ,case when t1.new_level='A1' then t0.group_gap else 0 end as group_gap--门店代招缺口
    ,t0.support_persons
    ,t0.label
        ---渠道招聘是否打开（1-打开，0-关闭）
    ,t4.is_group_recruit
    ,t4.is_recruitment_department
    ,t4.is_business_self
        ---,end_fte
    ,case
        when t0.full_capacity_all>=0.7 and t1.new_level='C4' then 'C3'
        when t0.full_capacity_all>=0.7 and t1.new_level='C3' then 'C2'
     else t1.new_level  end as new_level
        ---------------增加测温缺口
    ,t0.store_epidemic_hc
    ,t0.epidemics
    ,t0.epidemic_gap----防疫伙伴缺口
    ,t0.is_business_self_epidemic---是否打开门店自招_防疫（1-打开，0-不打开）
    ,t0.is_recruitment_department_epidemic---是否打开总部招聘_防疫（1-打开，0-不打开）
    ,t0.is_group_epidemic---是否打开店群招聘_防疫（1-打开，0-不打开）

        ----整体缺口计算
    ,t0.hc_all
    ,t0.fte_all
    ,t0.full_capacity_perdict_future_all
    ,t0.gap_all
        ---招聘部优先级排序
----,t1.recruit_rank
    ,t0.is_upgrade
    ,t0.is_empty_window
        ,t0.is_pipeline_enough
    ,t1.staffs ---剔除低意愿人员数量
    ,t1.staffs_all---架构下人数
    ,t0.fte_all2
    ,(t0.fte_all2-t0.fte_all2/t1.staffs_all) as fte_all2_1 --少一个人的fte
    ,nvl((t0.fte_all2-t0.fte_all2/t1.staffs_all),0)/t0.hc_all  as full_capacity_all_1 ----少一个人的全量满编率
    ,t0.full_capacity_all
    ,t0.fte_nopipe
    ,t0.full_capacity_nopipe---提出应离职末位普通含测温 不含pipeline
---------新增
    ,t0.is_manager  --是否有高意愿店长
    ,case when t1.new_level in ('C4') then t2.h3_area_rank else '' end as to_h3_rank
    ,case when t1.new_level='A1' then 0 else t0.a_gap end              as h3_gap
    ,case when t1.new_level not in ('A1') then 1 else 0 end            as is_h3_recruit
    ,t3.stores_g
    ,t3.operate_hc_g
    ,t3.operate_fte_g
    ,t3.operate_gap_g
    ,t3.epidemic_hc_g
    ,t3.epidemics_fte_g
    ,t3.epidemic_gap_g
    ,t3.all_hc_g
    ,t3.all_fte_g
    ,t3.all_gap_g
    ,t3.full_capacity_perdict_future_g
---店群等级
-- 1121改为不去低满编率
    ,case
        when (t0.full_capacity_all>=1 and t0.b_gap<=0) or (t0.gap_all<=0 and t0.b_gap<=0) then 'Q1'
        -----------when full_capacity_perdict_future_all<1 and is_empty_window=1 then 'Q5'
        when t0.full_capacity_all<0.8 and t0.fte_all2<=1  then 'Q5'
        when t0.full_capacity_all<0.6 and t3.stores_g<=3 then 'Q5'
        when t0.full_capacity_all>=0.8 and t0.full_capacity_all<1 then 'Q2'
        when t0.full_capacity_all>=0.6 and t0.full_capacity_all<0.8 and nvl(t3.full_capacity_perdict_future_g,t0.full_capacity_all)>=0.6 then 'Q3'
        when t0.is_pipeline_enough=1 and t0.full_capacity_all>=0.4 and t0.full_capacity_all<0.6 and nvl(t3.full_capacity_perdict_future_g,t0.full_capacity_all)>=0.6 then 'Q3'
        when t0.full_capacity_all>=0.4 and t0.full_capacity_all<0.6 and nvl(t3.full_capacity_perdict_future_g,t0.full_capacity_all)>=0.6 then 'Q4'
        when t0.is_pipeline_enough=1 and t0.full_capacity_all>=0.6 and t0.full_capacity_all<0.8 and nvl(t3.full_capacity_perdict_future_g,t0.full_capacity_all)>=0.4 and nvl(t3.full_capacity_perdict_future_g,t0.full_capacity_all)<0.6 then 'Q3'
        when t0.full_capacity_all>=0.6 and t0.full_capacity_all<0.8 and nvl(t3.full_capacity_perdict_future_g,t0.full_capacity_all)>=0.4 and nvl(t3.full_capacity_perdict_future_g,t0.full_capacity_all)<0.6 then 'Q4'
        when t0.is_pipeline_enough=1 and t0.full_capacity_all>=0.6 and t0.full_capacity_all<0.8 and nvl(t3.full_capacity_perdict_future_g,t0.full_capacity_all)<0.4 then 'Q3'
        when t0.full_capacity_all>=0.6 and t0.full_capacity_all<0.8 and nvl(t3.full_capacity_perdict_future_g,t0.full_capacity_all)<0.4 then 'Q5'
        when t0.is_pipeline_enough=1 and t0.full_capacity_all>=0.4 and t0.full_capacity_all<0.6 and nvl(t3.full_capacity_perdict_future_g,t0.full_capacity_all)<0.6 then 'Q3'
        when t0.full_capacity_all>=0.4 and t0.full_capacity_all<0.6 and nvl(t3.full_capacity_perdict_future_g,t0.full_capacity_all)<0.6 then 'Q5'
        when t0.is_pipeline_enough=1 and  t0.full_capacity_all<0.4 then 'Q3'
        when t0.full_capacity_all<0.4 then 'Q5'
        when (t0.full_capacity_all>=1 and t0.b_gap>0) then 'Q2' -- 0915新增
     else 'Q1' end                                                        as group_level
    ,case when t1.new_level in ('C4') then t2.h3_group else '' end      as h3_group
    ,t0.fte_allocation--剔除应离职FTE，含pipeline
    ,t0.full_capacity_allocation-----剔除应离职，含pipeline
    ,case when t0.hc_all-t0.fte_allocation>=0.3 then ceiling(t0.hc_all-t0.fte_allocation) else 0 end as gap_allocation --------剔除应离职，含pipeline
    ,t0.fte_all_allocation
    ,t0.full_capacity_all_allocation
    ,case when t0.hc_all-t0.fte_all_allocation>=0.3 then ceiling(t0.hc_all-t0.fte_all_allocation) else 0 end as gap_all_allocation
    ,case
            when t0.fte_allocation<=1 then 1
            when t0.fte_allocation>1 and t0.fte_allocation<=2 then 2
            when t0.fte_allocation>2 and t0.fte_allocation<=3 then 3
            when t0.fte_allocation>3 then 4
         end          as classify_1
    ,case
            when is_manager=0 then 2
            when max_days>=7 or max_days is null then 1
         else 3 end   as classify_2
    ,is_upgrade_paiban_pre
    ,nvl(empty_days,0) as empty_days
    ,paiban_level
    ,nvl(t8.difficulty_level,'D2') as difficulty_level
    ,t8.priority_level
    ,nvl(t8.reward_level,'P1') as reward_level
    ,nvl(t8.is_longterm,0) as is_longterm_q56
    ,nvl(t8.is_highsale,0) as is_highsale
    ,nvl(t8.is_borderline,0) as is_boderline
    ,nvl(t8.hc_day,0) as hc_day
    ,nvl(t8.hc_night,0) as hc_night
    ,nvl(t8.hc_new,0) as hc_new
    ,nvl(t8.fte_day,0) as fte_day
    ,nvl(t8.fte_night,0) as fte_night
    ,nvl(t8.fte_new,0) as fte_new
    ,nvl(t8.gap_day,0) as gap_day
    ,nvl(t8.gap_night,0) as gap_night
    ,nvl(t8.gap_new,0) as gap_new
    ,nvl(t8.full_capacity_day,0) as full_capacity_day
    ,nvl(t8.full_capacity_night,0) as full_capacity_night
    ,nvl(t8.full_capacity_new,0) as full_capacity_new
    ,nvl(t8.fte_day_withoutlow,0) as fte_day_withoutlow
    ,nvl(t8.fte_night_withoutlow,0) as fte_night_withoutlow
    ,nvl(t8.fte_new_withoutlow,0) as fte_new_withoutlow
    ,nvl(t8.gap_day_withoutlow,0) as gap_day_withoutlow
    ,nvl(t8.gap_night_withoutlow,0) as gap_night_withoutlow
    ,nvl(t8.gap_new_withoutlow,0) as gap_new_withoutlow
    ,nvl(t8.full_capacity_day_withoutlow,0) as full_capacity_day_withoutlow
    ,nvl(t8.full_capacity_night_withoutlow,0) as full_capacity_night_withoutlow
    ,nvl(t8.full_capacity_new_withoutlow,0) as full_capacity_new_withoutlow
    ,t8.reward_level_night
    ,nvl(t8.is_extra_hc,0) as is_extra_hc
    ,nvl(t8.priority_level_new,0) as priority_level_new
    ,nvl(t8.fte_new_miss_2,0) as fte_new_miss_2
    ,nvl(t8.fte_new_withoutlow_miss_2,0) as fte_new_withoutlow_miss_2
    ,nvl(t8.gap_bonus_day,0) as gap_bonus_day
    ,nvl(t8.gap_bonus_night,0) as gap_bonus_night
    ,nvl(t8.gap_bonus_new,0) as gap_bonus_new
    ,nvl(t8.roster_count_1week,0) as roster_count_1week
    ,nvl(t8.roster_count_2week,0) as roster_count_2week
    ,nvl(t8.roster_count_3week,0) as roster_count_3week
    ,nvl(t8.roster_count_4week,0) as roster_count_4week
    ,nvl(t8.roster_count_5week,0) as roster_count_5week
    ,t8.group_level_new

 ,nvl(t8.gap_short_day,0) as gap_short_day
 ,nvl(t8.gap_short_night,0) as gap_short_night
 ,t8.is_vip as is_vip
 ,t8.is_potential as is_potential
 ,t8.difficulty_level_new as difficulty_level_new
,t8.group_type_day as group_type_day
,t8.group_type_night as group_type_night
,t8.roster_gap_day as roster_gap_day
,t8.roster_gap_night as roster_gap_night
,t8.reward_level_retention as reward_level_retention
,t8.reward_level_night_retention as reward_level_night_retention
,nvl(t8.district_code,0) as district_code
,nvl(t8.hc_all_district,0) as hc_all_district
,nvl(t8.hc_night_district,0) as hc_night_district
,nvl(t8.hc_day_district,0) as hc_day_district
,nvl(t8.gap_all_district,0) as gap_all_district
,nvl(t8.gap_day_district,0) as gap_day_district
,nvl(t8.gap_night_district,0) as gap_night_district
,nvl(t8.reward_level_district,0) as reward_level_district
,nvl(t8.reward_level_night_district,0) as reward_level_night_district
,nvl(t8.gap_with_replace_district,0) as gap_with_replace_district
,nvl(t8.gap_student,0) as gap_student
,nvl(t9.is_tail_store,0) as is_tail_store
,case when t8.gap_new - t8.gap_short_day >= 1 then 1
when t8.gap_short_day >= 1 then 3
when t8.is_highsale = 1  then 4 
when t8.is_vip = 1 then 4 
when t8.is_potential = 1 then 4
when t9.is_tail_store = 1 then 5 
when t8.gap_new = 0 and t8.gap_new_withoutlow>=1 then 6  else 0 end as district_center_priority 
,case when t8.gap_new - t8.gap_short_day >= 1 then t8.gap_new 
when t8.gap_short_day >= 1 then t8.gap_short_day
when t8.is_highsale = 1  then 2
when t8.is_vip = 1 then 2
when t8.is_potential = 1 then 2
when t9.is_tail_store = 1 then if(t8.gap_new>=2,t8.gap_new,2)
when t8.gap_new = 0 and t8.gap_new_withoutlow>=1 then t8.gap_new_withoutlow else 0 end as district_center_capacity 
,t8.key_staff_count as key_staff_count 
,t8.key_staff_store_type as key_staff_store_type
,t8.is_cv as is_cv
,t8.fte_district 
,t8.hc_all_district_base
from data_build.tmp_base_list_${DATE} t0
left join data_build.tmp_recruit_gap_${DATE} t1 on t0.store_code=t1.store_code
left join area_list t2 on t1.h3_group=t2.h3_group
left join group_gap_list t3 on t0.store_code=t3.a_store_code
left join data_build.tmp_final_list_${DATE} t4 on t0.store_code=t4.store_code
left join data_build.tmp_resume_info_${DATE} t5 on t0.store_code=t5.store_code
left join data_build.tmp_ddang_list_${DATE} t6 on t0.store_code=t6.store_code
left join data_build.tmp_paiban_level_${DATE} t7 on t0.store_code=t7.store_code
left join new_fte_hc_gap t8 on t0.store_code = t8.store_code
left join longterm_last_list t9 on t0.store_code = t9.store_code 

;

drop table if exists data_build.tmp_short_day_class_${DATE}; --20250620新增：统计班表中短白班次，短白班次小于等于2的门店，如果gap_new = gap_short_day = 1,将gap_new调整成0
create table data_build.tmp_short_day_class_${DATE} as
with
base_0 as
(
select
t1.roster_id
,t1.store_id
,t1.employee_id
,t1.work_date
,t1.start_time
,t1.end_time
,t1.is_night
,weekofyear(t1.work_date) as week_of_year
,year(t1.work_date) as year_of_work
,t2.holidays
,t1.dt
,date_sub(from_unixtime(unix_timestamp(t1.dt,'yyyyMMdd'),'yyyy-MM-dd'),1) as new_dt
from data_build.dw_roster_effect_roster_detail_info_da_view t1
left join (
select
weekofyear(date_key) as week_of_year
,year(date_key) as year_of_week
,sum(is_holiday) as holidays --当周节假日天数
from data_build.dim_date_ya_v2
group by
weekofyear(date_key)
,year(date_key)
) t2 on weekofyear(t1.work_date) = t2.week_of_year and year(t1.work_date) = t2.year_of_week
where t1.dt = '${DATE_ADD1DAY}'
and t1.store_type_desc = '门店'
and t1.class_id in ('0')
and t1.store_type = '0'
--and (sale_type <> '全天不营业' or sale_type is null)
and t1.work_date >= date_sub(next_day('${FDATE_SUB0DAY}','mon'),7)
and t1.work_date <= date_add(next_day('${FDATE_SUB0DAY}','mon'),20) --下周+未来三周
),
base_1 as
(
    select
roster_id
,store_id
,employee_id
,work_date
,start_time
,end_time
,is_night
,t1.week_of_year
,year_of_work
,holidays
,dt
,new_dt
,day_of_week_name
    from base_0 t1
    left join data_build.dim_date_ya_v2 t2
    on new_dt = t2.date_key

),
base_2 as
(
    select
    roster_id
    ,store_id
    ,employee_id
    ,work_date
    ,start_time
    ,end_time
    ,is_night
    ,week_of_year
    ,year_of_work
    ,holidays

        from base_1
        where day_of_week_name in ('星期一','星期二')
        and work_date >= date_sub(next_day('${FDATE_SUB0DAY}','mon'),7)
        and work_date <= date_sub(next_day('${FDATE_SUB0DAY}','mon'),1) --本周

        union

    select
    roster_id
    ,store_id
    ,employee_id
    ,work_date
    ,start_time
    ,end_time
    ,is_night
    ,week_of_year
    ,year_of_work
    ,holidays

        from base_1
        where day_of_week_name in ('星期一','星期二')
        and work_date >= date_sub(next_day('${FDATE_SUB0DAY}','mon'),0)
        and work_date <= date_add(next_day('${FDATE_SUB0DAY}','mon'),6) --下周

            union

    select
    roster_id
    ,store_id
    ,employee_id
    ,work_date
    ,start_time
    ,end_time
    ,is_night
    ,week_of_year
    ,year_of_work
    ,holidays

        from base_1
        where day_of_week_name in ('星期一','星期二')
        and work_date >= date_add(next_day('${FDATE_SUB0DAY}','mon'),7)
        and work_date <= date_add(next_day('${FDATE_SUB0DAY}','mon'),13) --下下周

        union

    select
    roster_id
    ,store_id
    ,employee_id
    ,work_date
    ,start_time
    ,end_time
    ,is_night
    ,week_of_year
    ,year_of_work
    ,holidays

        from base_1
        where day_of_week_name not in ('星期一','星期二')
        and work_date >= date_sub(next_day('${FDATE_SUB0DAY}','mon'),0)
        and work_date <= date_add(next_day('${FDATE_SUB0DAY}','mon'),6) --下周

        union

    select
    roster_id
    ,store_id
    ,employee_id
    ,work_date
    ,start_time
    ,end_time
    ,is_night
    ,week_of_year
    ,year_of_work
    ,holidays

        from base_1
        where day_of_week_name not in ('星期一','星期二')
        and work_date >= date_add(next_day('${FDATE_SUB0DAY}','mon'),7)
        and work_date <= date_add(next_day('${FDATE_SUB0DAY}','mon'),13) --下下周
        
        union

    select
    roster_id
    ,store_id
    ,employee_id
    ,work_date
    ,start_time
    ,end_time
    ,is_night
    ,week_of_year
    ,year_of_work
    ,holidays

        from base_1
        where day_of_week_name not in ('星期一','星期二')
        and work_date >= date_add(next_day('${FDATE_SUB0DAY}','mon'),14)
        and work_date <= date_add(next_day('${FDATE_SUB0DAY}','mon'),20) --下下下周
),

week_lsit as( --取假期最少的那周且离当前最远的那周
select
store_id
,week_of_year
,year_of_work
,holidays
,dense_rank() over(partition by store_id order by concat(year_of_work,week_of_year) desc) as rn--按照未来时间排序，时间越远排序越靠前
from(
select
store_id
,week_of_year
,year_of_work
,holidays
,dense_rank() over(partition by store_id order by holidays) as rn --按照当周的假期排序,假期少的排序靠前
from(
select distinct
store_id
,week_of_year
,year_of_work
,holidays
from base_2
) a
) b
where b.rn = 1
),

base as
(
    select
t.roster_id
,t.store_id
,t.employee_id
,t.work_date
,t.start_time
,t.end_time
,t.is_night
,(t.end_time - t.start_time) as work_hours
,t.week_of_year
,t.year_of_work
from base_2 t
join week_lsit t1 on t.store_id = t1.store_id and t.week_of_year = t1.week_of_year and t.year_of_work = t1.year_of_work and t1.rn = 1
),
base_list as
(
    select
    t.roster_id
    ,t.week_of_year
    ,t.work_date
    ,t.store_id
    ,t.employee_id
    ,t.work_hours
    ,t.start_time
    ,t.end_time
    ,case when t.start_time is null then ''
            when t.is_night=1 then '夜班'
            when t.is_night=0 then '白班'
        end as work_shift_label_1
    ,case when t.work_hours>=10 then '长班_10h'
    -- when work_hours>=10 then '长班_10_12h'
    when t.work_hours>=8 then '长班_8_10h'
            when t.work_hours<8 and t.work_hours>=4 then '短班_4-8H'
            when t.work_hours<4 then '短班_<4H'
        end as work_shift_label_2
    ,case when t.store_id = t1.hps_dept_code_lv5 then '本店'
    else '非本店' end as type
    from base t
    left join data_build.pdw_psprod_ps_blf_ehr_pers_vw_view t1 on t.employee_id = lpad(t1.emplid,8,'10') and t1.dt = '${DATE}' and hps_d_hr_status = '在职'
)
 
 select
 store_id
 ,work_shift_label_1
 ,work_shift_label_2
 ,type
 ,count(1) as num
 from base_list
 group by
  store_id
 ,work_shift_label_1
 ,work_shift_label_2
 ,type
;

drop table if exists data_build.tmp_gap_district_${DATE}; --20260521新增
create table data_build.tmp_gap_district_${DATE} as
--过去5天城市维度狭义利用率班次最大值
with city_special_shift as(
select
store_city
,max(is_special_cnt) as max_special_cnt
from (
select 
store_city
,work_shift_date
,count(distinct case when is_special = 1 and attendance_work_hours > 0 then concat(employee_no,work_shift_date) end ) as is_special_cnt
from (
select
a.*
,case when a.work_shift_second_desc in ('上货支援','普通','临时店长班次','储备班次','困难店整改','复业工时','撤店工时','效期整改班次','新店建店','机动队支援加盟店班次','机动队效期检查','机动队月盘','远程支援','陈列工时')
then 1 else 0 end as is_special
,case when a.work_shift_second_desc in ('上货支援','普通','专项整改','临时店长班次','储备班次','困难店整改','复业工时','撤店工时','效期整改班次','新店建店','机动队支援加盟店班次','机动队效期检查','机动队月盘','远程支援','陈列工时')
or a.day_manager_info = 1 or a.night_manager_info = 1 or a.roster_peace_info = 1  then  1 else 0 end as is_general
from data_smartorder.dm_roster_tmp_use_ratio a
where a.dt = '${DATE}'
and a.hps_dept_descr_lv1 = '运营管理部X'
and a.work_shift_second_desc not in ('机动队新人班次','机动队岗前培训班次','岗前培训班次')
and is_franchise_store = 0
) a
where work_shift_date between date_sub(from_unixtime(unix_timestamp('${DATE}','yyyyMMdd'),'yyyy-MM-dd'),4) and date_sub(from_unixtime(unix_timestamp('${DATE}','yyyyMMdd'),'yyyy-MM-dd'),0)
group by
store_city
,work_shift_date
) b
group by
store_city
)

--每个城市在职的机动队人数(非黑名单非离职中)
,district_staff_num as(
select
hps_d_city
,count(1) as district_staff_num
from data_build.pdw_psprod_ps_blf_ehr_pers_vw_view t1
left join (
        select distinct 
        employee_no
        ,lpad(employee_no,8,'10') as staff_code
    from data_shop.pdw_idss_ipes_admin_employee_blacklist_view -- 全量黑名单表
    where dt = '${DATE}'
        and valid_status=1 
        and start_date <= from_unixtime(unix_timestamp('${DATE}','yyyymmdd'),'yyyy-mm-dd')
        and end_date >= from_unixtime(unix_timestamp('${DATE}','yyyymmdd'),'yyyy-mm-dd')
    ) t2 on lpad(t1.emplid,8,'10') = t2.staff_code 
left join (
        select distinct
        t1.man_code as user_job_number
        ,lpad(t1.man_code,8,10) as staff_code
        ,t1.order_status
        ,date_format(create_time,'yyyy-MM-dd') as create_date
        ,date_format(final_leave_date,'yyyy-MM-dd') as leave_date
        ,'1' as is_leaving
    from data_shop.pdw_gis_workday_dimission_order_view t1
    where t1.dt = '${DATE}'
        and (t1.order_status = 'PROCESSING')
            or (date_format(final_leave_date,'yyyyMMdd') > t1.dt and final_leave = 'noleave' and t1.order_status = 'FINISHED')
    ) t3 on lpad(t1.emplid,8,'10') = t3.staff_code
where t1.dt = '${DATE}'
and t1.hps_dept_descr_lv5 like '%区X%'
and t1.hps_d_hr_status ='在职'
and t2.staff_code is null --非黑名单
and t3.staff_code is null --非离职中
group by
hps_d_city
)

--新gap_all_district计算逻辑
select
substr(t1.store_city,1,length(t1.store_city)-1) as store_city
,t1.max_special_cnt
,t2.district_staff_num
,if(t2.district_staff_num - t1.max_special_cnt >= 3 ,0 ,t1.max_special_cnt + 3 - t2.district_staff_num) as gap_all_district
from city_special_shift t1
left join district_staff_num t2 on substr(t1.store_city,1,length(t1.store_city)-1) = t2.hps_d_city
where substr(t1.store_city,1,length(t1.store_city)-1) in ('上海','南京','杭州')
;

insert overwrite table ${TABLE_NAME} partition (dt='$DATE')

select distinct

store_code
,tt.store_name
,tt.city_name
,recovery_label
,b_hc
,a_hc
,fte
,a_gap
,b_gap
,a_full_capacity_perdict_future
,b_full_capacity_perdict_future
,tt.store_type
,group_gap
,support_persons
,label
,concat(is_group_recruit,'') as is_group_recruit
,concat(is_recruitment_department,'') as is_recruitment_department
,concat(is_business_self,'') as is_business_self
,b_gap_end
,a_gap_end
,a_full_capacity_perdict_future_end
,b_full_capacity_perdict_future_end
,group_gap_end
,concat(is_business_self_end,'') as is_business_self_end
,new_level
,store_epidemic_hc
,concat(epidemics,'') as epidemics
,concat(epidemic_gap,'') as epidemic_gap
,concat(is_business_self_epidemic,'') as is_business_self_epidemic
,concat(is_recruitment_department_epidemic,'') as is_recruitment_department_epidemic
,concat(is_group_epidemic,'') as is_group_epidemic
,concat(hc_all,'') as hc_all
,concat(fte_all,'') as fte_all
,full_capacity_perdict_future_all
,concat(gap_all,'') as gap_all
,recruit_rank
,concat(is_upgrade,'') as is_upgrade
,concat(is_empty_window,'') as is_empty_window
,concat(is_pipeline_enough,'') as is_pipeline_enough
,concat(staffs,'') as staffs
,concat(staffs_all,'') as staffs_all
,fte_nopipe
,full_capacity_nopipe
,concat(is_manager,'') as is_manager
,to_h3_rank
,h3_gap
,concat(is_h3_recruit,'') as is_h3_recruit
,concat(stores_g,'') as stores_g
,concat(operate_hc_g,'') as operate_hc_g
,concat(operate_fte_g,'') as operate_fte_g
,concat(operate_gap_g,'') as operate_gap_g
,concat(epidemic_hc_g,'') as epidemic_hc_g
,concat(epidemics_fte_g,'') as epidemic_fte_g
,concat(epidemic_gap_g,'') as epidemic_gap_g
,concat(all_hc_g,'') as all_hc_g
,concat(all_fte_g,'') as all_fte_g
,concat(all_gap_g,'') as all_gap_g
,concat(full_capacity_perdict_future_g,'') as full_capacity_perdict_future_g
,nvl(group_level_new,'Q1') as group_level
,h3_group
,concat(fte_allocation,'') as fte_allocation
,concat(full_capacity_allocation,'') as full_capacity_allocation
,concat(gap_allocation,'') as gap_allocation
,concat(fte_all_allocation,'') as fte_all_allocation
,concat(full_capacity_all_allocation,'') as full_capacity_all_allocation
,concat(gap_all_allocation,'') as gap_all_allocation
,concat(full_capacity_all,'') as full_capacity_all
,group_level2
,difficulty_level
,priority_level
,reward_level
,concat(is_longterm_q56,'') as is_longterm_q56
,concat(is_highsale,'') as is_highsale
,concat(fte_all2,'') as fte_all2
,concat(is_boderline,'') as is_boderline
,hc_day
,tt.hc_night
,hc_new
,fte_day
,fte_night
,fte_new
,gap_day
,tt.gap_night
,gap_new
,full_capacity_day
,full_capacity_night
,full_capacity_new
,fte_day_withoutlow
,fte_night_withoutlow
,fte_new_withoutlow
,gap_day_withoutlow
,tt.gap_night_withoutlow
,gap_new_withoutlow
,full_capacity_day_withoutlow
,full_capacity_night_withoutlow
,full_capacity_new_withoutlow
,CASE
    when t2.store_id is not null and CAST(SUBSTRING(tt.reward_level_night, 2) AS INT) < 5 and t2.store_type not in ('非攻坚') then 'P5'
    WHEN tt.reward_level_night IN ('P8') THEN tt.reward_level_night
    ELSE
      CONCAT(
        'P',
        LPAD(
          CAST(
            CAST(SUBSTRING(tt.reward_level_night, 2) AS INT) + 1 AS STRING
          ),
          1,
          '0'
        )
      )
  END AS reward_level_night --20250630_P激励下发规则_临时为了招聘22岁调整的P等级 20250807夜班招聘困难门店升P5
,concat(b_gap_bakcup,'') as b_gap_bakcup
,is_extra_hc
,priority_level_new
,fte_new_miss_2
,fte_new_withoutlow_miss_2
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
 ,difficulty_level_new
 ,group_type_day as group_type_day
,group_type_night as group_type_night
,roster_gap_day as roster_gap_day
,roster_gap_night as roster_gap_night
,reward_level_retention as reward_level_retention
,reward_level_night_retention as reward_level_night_retention
,nvl(district_code,0) as district_code
,nvl(hc_all_district,0) as hc_all_district
,nvl(hc_night_district,0) as hc_night_district
,nvl(hc_day_district,0) as hc_day_district
,case when district_code in ('1090','1104','1016') then t5.gap_all_district else --上海南京杭州门店最多的商圈
IF(CASE
when district_code in ('10019','1101','1102','1103','1012','1018','1014','1015','1011') --上海南京杭州只保留一个店最多的商圈
then -1
WHEN NVL(tt.gap_all_district, 0) > NVL(hc_all_district, 0) THEN 0 
ELSE NVL(tt.gap_all_district, 0) END < 0, 
0, 
CASE 
WHEN NVL(tt.gap_all_district, 0) > NVL(hc_all_district, 0) THEN NVL(tt.gap_all_district, 0) - NVL(hc_all_district, 0)
ELSE NVL(tt.gap_all_district, 0) 
END) end AS gap_all_district
,IF(CASE 
WHEN NVL(gap_day_district, 0) > NVL(hc_day_district, 0) THEN 0 
ELSE NVL(gap_day_district, 0) END < 0, 
0, 
CASE 
WHEN NVL(gap_day_district, 0) > NVL(hc_day_district, 0) THEN NVL(gap_day_district, 0) - NVL(hc_day_district, 0)
ELSE NVL(gap_day_district, 0) END) AS gap_day_district
,IF(CASE WHEN NVL(gap_night_district, 0) > NVL(hc_night_district, 0) THEN 0 
ELSE NVL(gap_night_district, 0) END < 0, 
0, 
CASE WHEN NVL(gap_night_district, 0) > NVL(hc_night_district, 0) THEN NVL(gap_night_district, 0) - NVL(hc_night_district, 0) 
ELSE NVL(gap_night_district, 0) END) AS gap_night_district
,nvl(CASE when district_code in ('10019','1018','1011','1015')
then 'p1' else
reward_level_district end,0) as reward_level_district
,nvl(reward_level_night_district,0) as reward_level_night_district
,nvl(gap_with_replace_district,0) as gap_with_replace_district
,nvl(gap_student,0) as gap_student
,is_tail_store
,district_center_priority
,district_center_capacity
,key_staff_count 
,key_staff_store_type
,is_cv
,fte_district
,hc_all_district_base
,t4.hps_dept_code_lv5 as district_dept_code
,t3.operation_x as dept_name
from
(
select
     t1.store_code
    ,t1.store_name
    ,city_name
    ,recovery_label
    ,b_hc--理想运营HC
    ,a_hc--最低开业HC
    ,fte
    ,a_gap ---总部招聘GAP
    ,gap_new as b_gap--门店自招GAP --bgap改成gapnew
    ,a_full_capacity_perdict_future
    ,b_full_capacity_perdict_future
    ,nvl(store_type,'既存非折扣店') as store_type
    ,group_gap--门店代招缺口
    ,support_persons
    ,label ---渠道招聘是否打开（1-打开，0-关闭）
    ,is_group_recruit
    ,is_recruitment_department
    ,is_business_self ---,end_fte
    ,'' as b_gap_end
    ,'' as a_gap_end
    ,'' as a_full_capacity_perdict_future_end
    ,'' as b_full_capacity_perdict_future_end
    ,'' as group_gap_end
    ,'' as is_business_self_end
    ,new_level ---------------增加测温缺口
    ,store_epidemic_hc
    ,epidemics
    ,epidemic_gap----防疫伙伴缺口
    ,is_business_self_epidemic---是否打开门店自招_防疫（1-打开，0-不打开）
    ,is_recruitment_department_epidemic---是否打开总部招聘_防疫（1-打开，0-不打开）
    ,is_group_epidemic---是否打开店群招聘_防疫（1-打开，0-不打开） ----整体缺口计算
    ,hc_all
    ,fte_all
    ,full_capacity_perdict_future_all
    ,gap_all---招聘部优先级排-- ,row_number()over(partition by group_level3 order by classify_1,classify_2,full_capacity_allocation) as recruit_rank
    ,'' as recruit_rank
    ,is_upgrade
    ,is_empty_window
    ,is_pipeline_enough
    ,staffs ---剔除低意愿人员数量
    ,staffs_all---架构下人数----,full_capacity_all
    ,fte_nopipe
    ,full_capacity_nopipe---提出应离职末位普通含测温 不含pipeline   ---------下面是新增
    ,is_manager  --是否有高意愿店长
    ,to_h3_rank
    ,h3_gap
    ,is_h3_recruit
    ,stores_g
    ,operate_hc_g
    ,operate_fte_g
    ,operate_gap_g
    ,epidemic_hc_g
    ,epidemics_fte_g
    ,epidemic_gap_g
     ,group_level_new as group_level_new
    ,all_hc_g
    ,all_fte_g
    ,all_gap_g
    ,full_capacity_perdict_future_g
    ,group_level3 as group_level
    ,h3_group
    ,fte_allocation--剔除应离职FTE，含pipeline
    ,full_capacity_allocation-----剔除应离职，含pipeline
    ,gap_allocation --------剔除应离职，含pipeline
    ,fte_all_allocation
    ,full_capacity_all_allocation
    ,gap_all_allocation
    ,full_capacity_all----全量未剔除的满编率
    ,group_level2 --预警等级旧
    -- 1012新增5个字段
    ,difficulty_level
    ,priority_level
    ,reward_level
    ,is_longterm_q56
    ,is_highsale
    ,fte_all2 --全量未剔除的fte
    ,is_boderline
    ,hc_day
    ,hc_night
,hc_new
,fte_day
,fte_night
,fte_new
,gap_day
,gap_night
,gap_new
,full_capacity_day
,full_capacity_night
,full_capacity_new
,fte_day_withoutlow
,fte_night_withoutlow
,fte_new_withoutlow
,gap_day_withoutlow
,gap_night_withoutlow
,gap_new_withoutlow
,full_capacity_day_withoutlow
,full_capacity_night_withoutlow
,full_capacity_new_withoutlow
,reward_level_night
,b_gap as b_gap_bakcup
,is_extra_hc as is_extra_hc
,priority_level_new as priority_level_new
,fte_new_miss_2 as fte_new_miss_2
,fte_new_withoutlow_miss_2 as fte_new_withoutlow_miss_2
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
,district_code as district_code
,hc_all_district as hc_all_district
,hc_night_district as hc_night_district
,hc_day_district as hc_day_district
,gap_all_district as gap_all_district
,gap_day_district as gap_day_district
,gap_night_district as gap_night_district
,reward_level_district as reward_level_district
,reward_level_night_district as reward_level_night_district
,gap_with_replace_district as gap_with_replace_district
,gap_student as gap_student
,is_tail_store
,district_center_priority
,district_center_capacity
,key_staff_count 
,key_staff_store_type
,is_cv
,fte_district
,hc_all_district_base
from

(
    select
         t1.*
         -- 1027调整升级规则
        ,case when t1.group_level = 'Q5' and (nvl(t1.paiban_level,0)+t1.is_upgrade_paiban_pre)>0 then 'Q6'
        when t1.group_level = 'Q4' and (nvl(t1.paiban_level,0)+t1.is_upgrade_paiban_pre)>0 then 'Q5'
-- when t1.full_capacity_all>=0.7 and t1.group_level='Q5' then 'Q4'
-- when t1.full_capacity_all>=0.7 and t1.group_level='Q4' then 'Q3'
-- when t1.full_capacity_all>=0.7 and t1.group_level='Q3' then 'Q2'
        else t1.group_level end as group_level3
        ,case
            when t1.group_level='Q5' and is_upgrade_paiban_pre=1 then 'Q6' --0915由>4改成>3
            when empty_days >0 and t1.group_level='Q4' then 'Q5'
            when empty_days >0 and t1.group_level='Q3' then 'Q4'
            when empty_days >0 and t1.group_level='Q2' then 'Q3'
            when t1.full_capacity_all>=0.7 and t1.group_level='Q5' then 'Q4'
            when t1.full_capacity_all>=0.7 and t1.group_level='Q4' then 'Q3'
            when t1.full_capacity_all>=0.7 and t1.group_level='Q3' then 'Q2'
         else group_level  end as group_level2

        from data_build.tmp_final_out_list_${DATE} t1
 ) t1
) tt
left join(
select
store_id
,sum(num) as num
from data_build.tmp_short_day_class_${DATE}
where work_shift_label_1 = '白班'
and substr(work_shift_label_2,1,2) = '短班'
and type = '非本店'
group by
store_id
) t1 on tt.store_code = t1.store_id
left join data_shop.dwd_difficulty_night_store_list_da t2 on t2.dt = '${DATE}' and tt.store_code = t2.store_id
--0420新增
left join data_smartorder.ods_uploads_operation_x_business_district_qiyang t3 on tt.district_code = t3.business_district_id
left join (SELECT DISTINCT
hps_dept_code_lv5
,hps_dept_descr_lv5
from data_build.pdw_psprod_ps_blf_ehr_pers_vw_view
where dt = '20260415') t4 on t3.operation_x = t4.hps_dept_descr_lv5
left join data_build.tmp_gap_district_${DATE} t5 on tt.city_name = t5.store_city
where store_code <> '110000176'






         ;

        -- 验证数据
        ${CHECK_DATA_SQL};

        "
EOF
}
