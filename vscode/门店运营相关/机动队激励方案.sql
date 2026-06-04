--门店日商
with store_sale as(
select
t.order_date
,t.store_code
,sum(t.payable_price)/count(distinct order_date) as payable_price --折后销售额
from data_build.dw_order_sku_v1 t
where t.dt = '${today-1}'
and t.store_type = '0'
and t.order_status = 'FINISHED'
and t.sku_class_code not in ('86','50')
and t.sku_quantity > 0
--and t.order_date between '2023-09-18' and '2023-10-19'
group by
t.order_date
,t.store_code
)

,punish_detail as ( --惩处明细
 select
 t1.previous_order_id as order_id
 ,to_date(t1.1st_create_date) as order_create_date
 --,t4.start_cdate
 --,case when to_date(t1.1st_create_date) >= t4.start_cdate then 1 else 0 end as is_start

 --,t4.cal_days
 -- ,t2.occur_time as ab_create_time
 ,t1.chain_status as order_status
 ,case when locate('#', regexp_replace(t1.1st_item_id,'[0-9]','#')) > 0
 then t1.1st_flow_name else t1.1st_item_id end as punish_item
 ,coalesce(t1.3rd_operate_results,t1.2nd_operate_results,t1.1st_operate_results) as operate_results
 ,t1.1st_shop_code as shop_code
 -- ,t3.hps_dept_code_lv5 as dept_code
 ,coalesce(t1.3rd_final_user_name,t1.2nd_final_user_name,t1.1st_final_user_name) as staff_name
 ,coalesce(t1.3rd_final_user_code,t1.2nd_final_user_code,t1.1st_final_user_code) as emplid
 ,lpad(coalesce(t1.3rd_final_user_code,t1.2nd_final_user_code,t1.1st_final_user_code),8,'10') as staff_code
 ,case
 when coalesce(3rd_final_feedback_type,2nd_final_feedback_type,2nd_feedback_type
 ,1st_final_feedback_type,1st_feedback_type) = '工时数量扣减'
 then '工时数量扣减' else '工时工资扣减' end as punish_type
 ,case
 when coalesce(3rd_final_feedback_type,2nd_final_feedback_type
 ,2nd_feedback_type,1st_final_feedback_type,1st_feedback_type) = '工时数量扣减'
 then 20*round(coalesce(3rd_final_feedback_result_value,3rd_feedback_result_value
 ,2nd_final_feedback_result_value,2nd_feedback_result_value
 ,1st_final_feedback_result_value,1st_feedback_result_value),2) 
 else round(coalesce(3rd_final_feedback_result_value,3rd_feedback_result_value
 ,2nd_final_feedback_result_value,2nd_feedback_result_value
 ,1st_final_feedback_result_value,1st_feedback_result_value),2) end as punish_value
 ,case
 when coalesce(3rd_final_feedback_type,2nd_final_feedback_type
 ,2nd_feedback_type,1st_final_feedback_type,1st_feedback_type) = '工时数量扣减'
 then 20*round(coalesce(3rd_feedback_result_value
 ,2nd_final_feedback_result_value,2nd_feedback_result_value
 ,1st_final_feedback_result_value,1st_feedback_result_value),2) 
 else round(coalesce(3rd_feedback_result_value
 ,2nd_final_feedback_result_value,2nd_feedback_result_value
 ,1st_final_feedback_result_value,1st_feedback_result_value),2) end as punish_value_origin
 from data_build.dwd_store_construction_operation_punish_flow_pipeline_v1 t1
 -- left join ab_time_detail t2
 -- on coalesce(t1.next_order_id_2,t1.next_order_id,t1.previous_order_id) = t2.order_id 
 -- left join data_shop.pdw_psprod_ps_blf_ehr_pers_vw_view t3
 -- on t3.dt <= '${today-1}' and date_format(date_sub(to_date(t2.occur_time),1),'yyyyMMdd') = t3.dt
 -- and coalesce(t1.3rd_final_user_code,t1.2nd_final_user_code,t1.1st_final_user_code) = t3.emplid
 --left join base_manager_info t4 on t1.1st_shop_code = t4.store_code
 where t1.dt = '${today-1}'
 --and date_format(t1.1st_create_date,'yyyyMMdd') >=  '${today-30}'
 --and date_format(t1.1st_create_date,'yyyyMMdd') <=  '${today-1}'
 and (case when locate('#', regexp_replace(1st_item_id,'[0-9]','#')) > 0
 then 1st_flow_name else 1st_item_id end) not in ('请假/拒绝班次惩处','超成本工时费用')
)

,appeal_text_detail as ( --客诉详细说明
 select distinct
 order_id
 ,abnormal_explain
 ,exemption
 ,split(inspection_order_id,' ')[1] as inspection_order_id
 from data_build.dwd_store_construction_operation_punish_flow_details_long_middle_v1 t1
 where t1.dt = '${today-1}' and rm = 1
)
,appeal_punish_detail as ( --客诉分类调整0524
 select distinct
 t1.emplid
 ,t1.order_create_date
 -- ,t1.ab_create_time
 ,t1.shop_code
 --,t1.cal_days
 -- ,t1.dept_code
 ,t1.order_id
 ,t1.punish_item
 ,t1.punish_type
 ,t1.punish_value
 ,t1.punish_value_origin
 ,t2.abnormal_explain
 ,t2.exemption
 ,case when t2.abnormal_explain in ('客诉-投诉分类: 二级/BZ/变质','客诉-投诉分类: 二级/GQ/过期','客诉-投诉分类: 二级/YW/异物','客诉-投诉分类: 四级/服务问题/服务态度问题','客诉-投诉分类: 四级/服务问题/卫生/环境','客诉-投诉分类: 一级/CT/服务冲突','客诉-投诉分类: 一级/RS/人伤','客诉-投诉分类: 一级/WS/物损') 
 then 1 when t2.abnormal_explain in ('客诉-投诉分类: 三级/口感/口感','客诉-投诉分类: 三级/品质/品质','客诉-投诉分类: 三级/量少/量少','客诉-投诉分类: 三级/配套产品缺失/配套产品缺失','客诉-投诉分类: 三级/商品或包装破损/商品或包装破损','客诉-投诉分类: 三级/失温/失温'
                                    ,'客诉-投诉分类: 四级/服务问题/技能/专业不熟练','客诉-投诉分类: 四级/服务问题/沟通困难','客诉-投诉分类: 四级/购物体验/豆浆稀','客诉-投诉分类: 四级/购物体验/身体不适'
                                    -- ,'客诉-投诉分类: 四级/拣货问题/已下单商品部分缺货（在库）','客诉-投诉分类: 四级/拣货问题/已下单商品全部缺货（在库）'
                ,'客诉-投诉分类: 四级/设备故障问题/豆浆机故障','客诉-投诉分类: 四级/设备故障问题/点餐屏故障','客诉-投诉分类: 四级/退换货问题/店员给错商品','客诉-投诉分类: 四级/退换货问题/门店结错账','客诉-投诉分类: 四级/支付问题/支付金额与宣传不符')
                then 2 else 0 end as appeal_punish_type
                -- 1 为严重客诉 2为普通客诉
 --,case when lpad(t1.emplid,8,'10') = t3.employee_id then 1 else 0 end as is_manager_appeal

 from punish_detail t1
 left join appeal_text_detail t2
 on t1.order_id = t2.order_id
 --left join base_manager_info t3 on t1.shop_code = t3.store_code
 where t1.punish_item = '客诉惩处' 
 and t1.operate_results = '运营问题'
 and t1.order_status = 'FINISHED'
 --and t1.is_start = 1 
 and t2.abnormal_explain in ('客诉-投诉分类: 二级/BZ/变质','客诉-投诉分类: 二级/GQ/过期','客诉-投诉分类: 二级/YW/异物','客诉-投诉分类: 四级/服务问题/服务态度问题','客诉-投诉分类: 四级/服务问题/卫生/环境','客诉-投诉分类: 一级/CT/服务冲突'
 ,'客诉-投诉分类: 一级/RS/人伤','客诉-投诉分类: 一级/WS/物损',
 '客诉-投诉分类: 三级/口感/口感','客诉-投诉分类: 三级/品质/品质','客诉-投诉分类: 三级/量少/量少','客诉-投诉分类: 三级/配套产品缺失/配套产品缺失','客诉-投诉分类: 三级/商品或包装破损/商品或包装破损','客诉-投诉分类: 三级/失温/失温'
                                    ,'客诉-投诉分类: 四级/服务问题/技能/专业不熟练','客诉-投诉分类: 四级/服务问题/沟通困难','客诉-投诉分类: 四级/购物体验/豆浆稀','客诉-投诉分类: 四级/购物体验/身体不适'
                                    -- ,'客诉-投诉分类: 四级/拣货问题/已下单商品部分缺货（在库）','客诉-投诉分类: 四级/拣货问题/已下单商品全部缺货（在库）' -- 剔除普通客诉2项0601
                ,'客诉-投诉分类: 四级/设备故障问题/豆浆机故障','客诉-投诉分类: 四级/设备故障问题/点餐屏故障','客诉-投诉分类: 四级/退换货问题/店员给错商品','客诉-投诉分类: 四级/退换货问题/门店结错账','客诉-投诉分类: 四级/支付问题/支付金额与宣传不符')
                )
           
,appeal_punish_info1 as ( --客诉final
 select
 shop_code
 ,substr(order_create_date,1,10) as order_create_date
 ,appeal_punish_type
 --,is_manager_appeal
 ,count(distinct order_id) as appeal_punish_cnts
 ,sum(punish_value) as appeal_punish_value
 ,sum(punish_value_origin) as appeal_punish_value_origin
 from appeal_punish_detail
 -- where date_format(order_create_date,'yyyyMMdd') >= '${today-30}'
 group by shop_code
 ,order_create_date
 ,appeal_punish_type
 --,is_manager_appeal
)

,raw_list as(
select
from_unixtime(unix_timestamp(a.dt,'yyyyMMdd'),'yyyy-MM-dd') as record_date
,a.dept_code --门店编码
,a.dept_name --门店名称
,if(length(a.manager_code)=6,concat('10',a.manager_code),a.manager_code) as manager_code
,a.manager_name
,case when e.position_cn in ('内部合作伙伴','内部合作经营者','内部合作辅助人','外部合作伙伴','外部合作经营者','外部合作辅助人') then '加盟店' else '直营店' end as store_type
,case when b.hps_dept_descr_lv5 like '%区X%' or b.hps_dept_descr_lv1 in ('运营管理部X') then '机动队' else '店经理' end as position_cn
,case when c.final_rank = 'S' then '0'
when c.final_rank = 'A' then '1'
when c.total_score <= 3.4 and c.final_rank = 'B' then '1.5'
when c.final_rank = 'B' then '2'
when c.final_rank = 'C' then '4'
when c.final_rank = 'D' then '5'
when c.final_rank = 'F' then '3'
when d.protect_tag_detail_new is not null then d.protect_tag_detail_new else null end as protect_tag_detail_new
,f.gap_new --gap
,f.hc_new --hc
,f.full_capacity_new --满编率
,f.key_staff_count --骨干人数
,j.key_staff_store_type --用每月最后一天的数
,substr(g.final_level_modify,2,1) as final_level_modify
,h.payable_price
--,i.appeal_punish_cnts_serious_manager --店经理严重客诉
--,i.appeal_punish_cnts_serious_manager0 --店员严重客诉
--,i.appeal_punish_cnts_common_manager --店经理普通客诉
--,i.appeal_punish_cnts_common_manager0 --店员普通客诉
--,i.appeal_punish_cnts_serious_manager + i.appeal_punish_cnts_serious_manager0 + i.appeal_punish_cnts_common_manager + i.appeal_punish_cnts_common_manager0 as total_appeal_punish_cnts
,i.appeal_punish_cnts --投诉数量
from data_build.pdw_opc_shop_ehr_staff_dept_view a
left join data_build.pdw_psprod_ps_blf_ehr_pers_vw_view b on if(length(a.manager_code)=6,concat('10',a.manager_code),a.manager_code) = if(length(b.emplid)=6,concat('10',b.emplid),b.emplid) and a.dt = b.dt
left join data_build.dwd_manager_tag_v1_di c on if(length(a.manager_code)=6,concat('10',a.manager_code),a.manager_code) = c.employee_id and c.dt = a.dt --店经理标签
left join data_build.dwd_dwd_district_staff_protect_tag_v2_da_di d on if(length(a.manager_code)=6,concat('10',a.manager_code),a.manager_code) = d.staff_code and a.dt = d.dt --机动队标签
left join data_smartorder.dm_copy_dm_shop_staff_protect_tag_v2_view e on a.dept_code = e.store_code and if(length(a.manager_code)=6,concat('10',a.manager_code),a.manager_code) = e.staff_code and a.dt = e.dt --判断加盟/直营门店
left join data_build.dwd_store_construction_store_groups_recruit_gap f on a.dept_code = f.store_code and a.dt = f.dt --门店gap表
left join (
SELECT * from data_build.dwd_store_construction_store_groups_recruit_gap
where from_unixtime(unix_timestamp(dt,'yyyyMMdd'),'yyyy-MM-dd') = last_day(from_unixtime(unix_timestamp(dt,'yyyyMMdd'),'yyyy-MM-dd'))
) j on a.dept_code = j.store_code and last_day(from_unixtime(unix_timestamp(a.dt,'yyyyMMdd'),'yyyy-MM-dd')) = from_unixtime(unix_timestamp(j.dt,'yyyyMMdd'),'yyyy-MM-dd') --门店gap表(为了取每月最后一天的ey_staff_store_type)
left join data_smartorder.dm_copy_dwd_ic_new_import_store_level_da_view g on a.dept_code = g.shop_id and from_unixtime(unix_timestamp(a.dt,'yyyyMMdd'),'yyyy-MM-dd') = g.alarm_start_date and g.dt = '${today-1}' --门店T值表
left join store_sale h on a.dept_code = h.store_code and from_unixtime(unix_timestamp(a.dt,'yyyyMMdd'),'yyyy-MM-dd') = h.order_date --日商
left join appeal_punish_info1 i on a.dept_code = i.shop_code and from_unixtime(unix_timestamp(a.dt,'yyyyMMdd'),'yyyy-MM-dd') = i.order_create_date --客诉数量
where a.dt > 20160101
and a.shop_sign = '1' --门店
--and a.dept_code in ('100000559','100071001','100000366','110000011','110000127','110000583')
)

select
trunc(record_date,'MM') as record_month --月份
,dept_code --门店编码
,dept_name --门店名称
,key_staff_store_type
,avg(case when protect_tag_detail_new = '3' then null else protect_tag_detail_new end) as avg_protect_tag_detail_new
,avg(gap_new) as avg_gap_new
,avg(hc_new) as avg_hc_new
,avg(full_capacity_new) as avg_full_capacity_new
,avg(key_staff_count) as avg_key_staff_count
,avg(final_level_modify) as avg_final_level_modify
,avg(payable_price) as avg_payable_price
,sum(appeal_punish_cnts) as sum_appeal_punish_cnts
from raw_list
group by
trunc(record_date,'MM')
,dept_code
,dept_name
,key_staff_store_type


select
dept_code --门店编码
,dept_name --门店名称
,count(distinct manager_code) as manager_code_num --一共有几个不同的架构负责人
from raw_list
where record_date between '2024-03-01' and '2024-08-31'
group by
dept_code
,dept_name


select
trunc(record_date,'MM') as record_month --月份
,dept_code --门店编码
,dept_name --门店名称
,count(distinct case when position_cn = '店经理' then record_date else null end) as manager_days --店经理带店天数
,count(distinct case when position_cn = '机动队' then record_date else null end) as district_manager_days --机动队带店天数  
from raw_list
group by
trunc(record_date,'MM')
,dept_code
,dept_name


select
trunc(record_date,'MM') as record_month --月份
,dept_code --门店编码
,dept_name --门店名称
,avg(case when position_cn = '店经理' then (case when protect_tag_detail_new = '3' then null else protect_tag_detail_new end) else null end) as manager_protect_tag_detail_new --店经理标签
,avg(case when position_cn = '机动队' then (case when protect_tag_detail_new = '3' then null else protect_tag_detail_new end) else null end) as manager_protect_tag_detail_new --机动队标签 
from raw_list
group by
trunc(record_date,'MM')
,dept_code
,dept_name