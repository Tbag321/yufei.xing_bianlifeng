--员工晋升店经理概率表(data_shop.dwd_manager_promotion_probability_di)
--确定员工岗位
with staff_list as(
select
t1.staff_code
,t1.staff_name
,t1.store_code
,t1.store_name
,t1.emplid
,t1.hours
,t1.protect_tag_detail_new
,case when t3.manager_code is not null and (t2.hps_dept_descr_lv5 not like '%区X%' or t2.hps_dept_descr_lv1 not in ('运营管理部X'))
and t2.hps_d_jobcode not in ('外部合作辅助人','外部合作经营者','外部合作伙伴','内部合作辅助人','内部合作经营者','内部合作伙伴') then '店经理'
when t2.hps_d_jobcode = '店副经理' then '店副经理'
when t4.employee_id is not null and (t2.hps_dept_descr_lv5 like '%区X%' or t2.hps_dept_descr_lv1 in ('运营管理部X')) then '机动队带店店长'
when t5.employee_no is not null and (t2.hps_dept_descr_lv5 like '%区X%' or t2.hps_dept_descr_lv1 in ('运营管理部X'))  then t5.relation_type
when t2.hps_dept_descr_lv5 like '%区X%' or t2.hps_dept_descr_lv1 in ('运营管理部X') then '机动队队员'
when t2.hps_d_jobcode not in ('外部合作辅助人','外部合作经营者','外部合作伙伴','内部合作辅助人','内部合作经营者','内部合作伙伴') then '店员'
else '加盟人员' end as post_name
from data_shop.dm_shop_staff_protect_tag_v2 t1
left join data_build.pdw_psprod_ps_blf_ehr_pers_vw_view t2 on t1.staff_code = lpad(t2.emplid,8,'10') and t2.dt = '${today-1}' --hps_d_jobcode in ('店副经理')
--left join data_build.dwd_store_construction_manager_base_info_vi_di t3 on t1.staff_code = t3.employee_id and t3.dt = '${today-2}'  --店长
left join data_build.pdw_opc_shop_ehr_staff_dept_view t3 on t2.hps_dept_code_lv5 = t3.dept_code and lpad(t2.emplid,8,'10') = lpad(t3.manager_code,8,'10') and t3.dt = '${today-1}' --店长
left join data_build.dwd_store_construction_district_manager_base_info0_di t4 on t1.staff_code = t4.employee_id and t4.dt = '${today-2}'  --带店机动队(店经理)
left join (select
* from(
select 
employee_no,
shop_code,
relation_type,
dt,
row_number() over(partition by employee_no order by create_time desc) as rn
from data_smartorder.dm_copy_pdw_opc_roster_motor_shop_relation_view
where dt ='${today-1}'
and delete_ts = 0
and end_date >= '${TODAY}'
) a
where rn = 1
) t5 on t1.staff_code = lpad(t5.employee_no,8,'10') --带店机动队(店长/店副/陪跑店长/陪跑店副)
left join data_smartorder.ods_uploads_business_district_qiyang t6 on t1.store_code = t6.store_code
where t1.dt = '${today-1}'
)

,main_list as( --历史流程统计
SELECT * 
from data_build.pdw_order_store_211_order_detail_flow_main
where dt = '${today-1}'
and flow_code = '031412' --晋升/接店意愿沟通
)

,result_list as(
select
substr(t1.create_time,1,10) as compute_period --流程发起日期
,t1.order_id --流程编码
,t1.order_status --流程状态
,t1.flow_ame --流程名称
,SUBSTRING(
    t1.flow_ame, 
    LOCATE('(', t1.flow_ame) + 1, 
    LOCATE(')', t1.flow_ame) - LOCATE('(', t1.flow_ame) - 1
  ) AS staff_code --员工编码
,t1.create_time --创建时间
,t2.form_values
,nvl(get_json_object(t2.form_values,'$[0].label'),'未处理') as result --意愿
,row_number() over(partition by SUBSTRING(
    t1.flow_ame, 
    LOCATE('(', t1.flow_ame) + 1, 
    LOCATE(')', t1.flow_ame) - LOCATE('(', t1.flow_ame) - 1
  ) order by t1.create_time) as rn --员工收到流程按照日期升序排序，用于确认首次收到流程日期
from main_list t1
left join data_build.pdw_order_store_211_order_detail_flow_form_variable_groups_da t2
on t1.order_id = t2.order_id
and t2.dt = '${today-1}'
and t2.form_name = 'accept'
where substr(t1.create_time,1,10) >= '2025-05-16' --5月16号起开始限制30天内收到3次流程，180天内收到5次流程
)

,date_raw as(
select
staff_code
,compute_period
,datediff('${TODAY}',compute_period) as diff_date --流程发起到今天的天数
,floor(datediff('${TODAY}',compute_period)/180) as multiple --流程第一次发起到今天的倍数 
from result_list
where rn = 1
)

,date_raw_list as(
select
staff_code
,compute_period --首次收到流程日期
,date_add(compute_period,cast(180*multiple as int)) as start_date --每180天为一个周期
from date_raw
)

select
t1.staff_code
,t1.staff_name
,t1.store_code
,t1.store_name
,t1.emplid
,t1.post_name
,t1.hours as attend_hours
,t1.protect_tag_detail_new
,t2.start_date
,nvl(t3.flow_num,0) as flow_num--截止当前收到流程数量
,5 - nvl(t3.flow_num,0) as rest_num --剩余的机会
,case when 5 - nvl(t3.flow_num,0) < 4 then '低概率' else '高概率' end as promotion_probability
,case when t4.staff_code is not null then '1' else '0' end as is_transfer_blacklist
from staff_list t1
left join date_raw_list t2 on t1.emplid = t2.staff_code
left join (
select
lpad(t1.staff_code,8,10) as staff_code
,count(1) as flow_num --截止当前收到流程数量
from result_list t1
left join date_raw_list t2 on t1.staff_code = t2.staff_code
where t1.compute_period >= start_date
and t1.result <> '愿意接受'
group by
lpad(t1.staff_code,8,10)
) t3 on t1.staff_code = t3.staff_code
left join data_shop.dwd_manager_transfer_blacklist_v1_di t4 on t1.emplid = t4.staff_code and t4.dt = '${today-2}' --晋升黑名单降级
where t1.post_name = '店员'
and t1.hours >= 250 --剔除新员工
and t1.protect_tag_detail_new not in ('4','5') --剔除差标签员工
and t4.staff_code is null --剔除晋升黑名单员工