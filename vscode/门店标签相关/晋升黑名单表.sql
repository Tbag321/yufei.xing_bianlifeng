--data_shop.dwd_manager_transfer_blacklist_v1_di
with leave_tag as (
 select
 IF(LENGTH(t1.emplid)<8,CONCAT('10',t1.emplid),t1.emplid) as emplid
 ,t1.hps_d_jobcode as position_cn
 ,t1.hps_d_hr_status
 ,t1.leave_dt
 ,t2.protect_tag
 ,t2.dt 
 ,row_number() over(partition by t1.emplid order by t2.dt desc) rn
 ,t1.emplid as original_emplid --0314updated
 from data_shop.pdw_psprod_ps_blf_ehr_pers_vw_view t1
 left join data_shop.dm_shop_staff_protect_tag_v2 t2
 on IF(LENGTH(t1.emplid)<8,CONCAT('10',t1.emplid),t1.emplid) = t2.staff_code 
 and t2.dt <= date_format(date_sub(leave_dt,1) ,'yyyyMMdd') 
 and t2.dt >= date_format(date_sub(leave_dt,7) ,'yyyyMMdd') 
 and t2.dt <= '${today-1}'

 where t1.dt <='${today-1}'
 and t1.hps_d_hr_status = '离职'
 -- and t1.store_type = 0
 -- and t1.store_status = 1 --门店营业状态 0:待营业 1:营业 2：暂停营业 3：停业
 ),

id_list as(
select
IF(LENGTH(emplid)<8,CONCAT('10',emplid),emplid) as emplid_ten
,emplid as emplid_eight
from data_shop.pdw_psprod_ps_blf_ehr_pers_vw_view
where dt <= '${today-1}'
group by
IF(LENGTH(emplid)<8,CONCAT('10',emplid),emplid)
,emplid
)

,leave_tag_final as (
 select 
 emplid
 ,leave_dt
 ,protect_tag
 ,case when protect_tag in ('末位普通','应离职') then 1 else 0 end as is_di_leave 
 from leave_tag
 where rn = 1
 and emplid not in ('11138319','11186155') --1031李蕊反馈剔除
 )
,eliminate_list as (
select 
t1.staff_code 
,t1.store_code
,nvl(t1.type,'正常') as eliminate_type -- 汰换类型
from data_shop.ods_uploads_eliminate_manager t1
where t1.staff_code <> '11306829' --0417于佳茜反馈剔除
)
,should_leave_list as (
select 
employee_id
,store_code
,t4.class
,t4.code
from data_build.ods_uploads_manager_tag_4 t4 
where from_unixtime(unix_timestamp(t4.dt,'yyyyMMdd'),'yyyy-MM-dd') = date_sub(next_day('${TODAY-1}','mon'),7)
and t4.class = '须努力'
)

--降职后连续4天铜牌
,four_days_bronze as(
select distinct
if(length(mgr_code) = 8 and substr(mgr_code,0,2) = '10',substr(mgr_code,3,8),mgr_code) as mgr_code
,store_code
from(
SELECT
mgr_code
,store_code
,date_sub
,count(1) as days
from(
SELECT
roster_date
,store_code
,store_name
,leave_date
,mgr_code
,mgr_name
,leave_days
,will_score
,performance_score
,store_score
,manage_score
,work_level_score
,task_order_id
,typeofdemote
,protect_tag
,date_sub(date_format(roster_date,'yyyy-MM-dd'),cast(leave_days as INT)) as date_sub
from data_build.dwd_store_mgr_protect_tag_last_ten_da
where dt = date_format(date_sub(current_date,2),'yyyyMMdd')
and cast(leave_days as INT) between '1' and '10'
and protect_tag = '铜牌'
) a
group by
mgr_code
,store_code
,date_sub
) b
where days >= '4' --连续4天铜牌
),

--门店交接申请流程
order_flow_main as(
select
order_id --流程编码(流程信息)
,substr(create_time,1,10) as create_date
,order_status --流程状态(流程信息)
,initiator_code --发起人编码(流程信息)
,create_time --流程发起时间(流程信息)
,flow_ame --流程名称(流程信息)
,org_code --门店编码(流程信息)
,org_name --门店名称(流程信息)
from data_build.pdw_order_store_211_order_detail_flow_main
where dt = '${today-1}'
and flow_code = '017270' --流程code
--and order_status in ('PROCESSING','FINISHED')
),

order_flow_groups as(
select
order_id
,max(now_mgr) as now_mgr
,max(shop_name) as shop_name
from(
select
order_id
,case when form_name = 'shopOwnerCnName' then get_json_object(get_json_object(form_values,'$.[0]'),'$.value') else null end as now_mgr
,case when form_name = 'shopName' then get_json_object(get_json_object(form_values,'$.[0]'),'$.label') else null end as shop_name
from data_build.pdw_order_store_211_order_detail_flow_form_variable_groups_da
where dt = '${today-1}'
and form_name in ('shopOwnerCnName','shopName')
--and order_id = '2110157213089599'
) a
group by order_id
),

order_flow_taskorders as(
select
order_id
,max(second_change) as second_change
from(
select
order_id
,taskorder_node_id
,element
,case when taskorder_node_id = 'UserTask_0601fr9' and get_json_object(element,'$.name') = 'secondchange' then get_json_object(get_json_object(element,'$.values'),'$.value') else null end as second_change --中台审核(是否允许现任店长后续再次接店)
from(
select
order_id
,taskorder_node_id
,task_orders
,row_number() over(partition by concat(order_id,taskorder_node_id) order by taskorder_create_time desc) as rn
from data_build.pdw_order_store_211_order_detail_flow_task_taskorders
where dt = '${today-1}'
--and order_id = '2110157929325986'
and taskorder_result = 'AGREE'
and taskorder_status = 'FINISHED'
and (taskorder_node_id = 'UserTask_0601fr9')
) a
lateral view
explode(split(regexp_replace(regexp_replace(task_orders, '\\\\[|\\\\]' , ''), '\\\\}\\\\,\\\\{' , '\\\\}\\\\&\\\\{'), '&')) x1 as element
where rn = 1
) b
group by
order_id
),

raw_list as(
select
t0.*
,case when reverse(substr(reverse(t1.now_mgr),0,instr(reverse(t1.now_mgr),'-')-1)) <> ''
then reverse(substr(reverse(t1.now_mgr),0,instr(reverse(t1.now_mgr),'-')-1)) else regexp_replace(t1.now_mgr, '[^一-龥]', '') end as now_mgr
,t1.shop_name
,t2.second_change
from order_flow_main t0
left join order_flow_groups t1 on t0.order_id = t1.order_id
left join order_flow_taskorders t2 on t0.order_id = t2.order_id
),

staff_list as(
select
from_unixtime(unix_timestamp(dt,'yyyyMMdd'),'yyyy-MM-dd') as new_dt --日期
,emplid --原始员工标号
,name --员工名称
,hps_dept_descr_lv5 --门店名称
from data_build.pdw_psprod_ps_blf_ehr_pers_vw_view
where dt > 20170101
),

second_change_list as(
select
t1.*
,t2.*
,case when t2.name is not null then t2.emplid else t1.now_mgr end as staff_code
from raw_list t1
left join staff_list t2 on t1.create_date = t2.new_dt and t1.shop_name = t2.hps_dept_descr_lv5 and t1.now_mgr = t2.name--替换员工中文名字的情况
where t1.order_status = 'FINISHED'
and t1.second_change = '禁止现任店长二次晋升'
and t1.order_id not in ('2110169134293321','2110167267388195','2110166134310967','2110174294446363'
,'2110160246038050','2110183751696761','2110193314728100','2110193525938136') --1009李蕊反馈店长已完成换签，可以二次晋升,1012陈欢反馈已特批，可以二次晋升，可以二次晋升,1031李蕊反馈剔除,1212剔除,0417于佳茜反馈剔除,0509杨立柱反馈剔除,0928杨立柱反馈豁免
)

select 
t2.emplid_eight as staff_code--0314updated
,t1.store_code
,'汰换' as reason 
from eliminate_list t1 
inner join id_list t2 on t1.staff_code = t2.emplid_ten --0314updated
where eliminate_type in ('普通汰换','末尾店汰换')
and t2.emplid_eight not in ('11360448','11379905','11402919','11398299','11369369')

union 

select 
t1.emplid as staff_code --0314updated
,hps_dept_code_lv5 as store_code
,'离职前低意愿' as reason
from data_shop.pdw_psprod_ps_blf_ehr_pers_vw_view t1 
left join leave_tag_final t2 on IF(LENGTH(t1.emplid)<8,CONCAT('10',t1.emplid),t1.emplid) = t2.emplid 
where t1.dt = '${today-1}' and t1.hps_d_hr_status = '在职' and t2.is_di_leave = 1
and t1.emplid not in ('11360448','11379905','11402919','11398299','11369369','11186155')

union 

select 
t2.emplid_eight as staff_code --0314updated
,t4.store_code 
,'须努力店长' as reason 
from should_leave_list t4
inner join id_list t2 on t4.employee_id = t2.emplid_ten --0314updated
where t2.emplid_eight not in ('11360448','11379905','11402919','11398299','11369369')

union

select
mgr_code as staff_code
,store_code
,'降职后持续铜牌' as reason
from four_days_bronze
where mgr_code not in ('11360448','11379905','11402919','11398299','11369369')

union

select
staff_code
,null as store_code
,'交接流程禁止二次晋升' as reason
from second_change_list
where staff_code not in ('11360448','11379905','11402919','11398299','11369369','11211894')

union

select
staff_code
,null as store_code
,'交接流程自动化判断禁止二次晋升' as reason
from data_build.dwd_store_handover_automated_judgment_da
where dt = '${today-1}'
and comments in ('禁止现任店长二次晋升')
and staff_code not in ('11125524','11211894') --20260212政委申请豁免

union

select
staff_code
,null as store_code
,'店长店副春节给班不合格' as reason
from data_shop.ods_uploads_spring_festival_unqualified