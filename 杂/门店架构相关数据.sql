--在dt生效日，store_code门店的manager_code架构负责人的position_cn岗位、hps_d_hr_status
--在职状态、和protect_tag保护标签
--,structure_info as ( --门店架构负责人是否在职店经理+保护标签
--脱敏处理
with desensitization as(
select
 store_code,
 store_name,
 store_cvs_code,
 display_name
 from data_md.dm_md_dim_store_base_info_store_v1
 where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
 group by
 store_code,
 store_name,
 store_cvs_code,
 display_name),

 list as(
 select
 t1.dt --生效日
 ,t1.store_code
 ,t1.store_name
 ,t4.store_cvs_code
 ,t4.display_name
 ,t1.store_city
 ,IF(LENGTH(store_manager_no)<8,CONCAT('10',store_manager_no),store_manager_no) AS manager_code
 ,t3.protect_tag
 ,t2.hps_d_jobcode as position_cn
 ,t2.hps_d_hr_status
 from data_smartorder.dw_ordering_store_tag_location_ranking_info_v1 t1
 left join data_sec_dw.pdw_psprod_ps_blf_ehr_pers_vw_view t2
 on t1.store_manager_no = t2.emplid and t2.dt >= '${today-1}' and t1.dt = t2.dt
 left join data_shop.dm_shop_staff_protect_tag_v2 t3
 on IF(LENGTH(store_manager_no)<8,CONCAT('10',store_manager_no),store_manager_no) = t3.staff_code 
 and t3.dt >= '${today-1}' and t1.dt = t3.dt
 left join desensitization t4 on t1.store_code = t4.store_code
 where t1.dt >= '${today-1}'
 and t1.store_type = 0 --门店默认0
 --and t1.store_status = 1 --门店营业状态 0:待营业 1:营业 2：暂停营业 3：停业
 --and t4.store_cvs_code = '110000096'
 )

 select
 *
  ,row_number() over (partition by concat(store_cvs_code,manager_code,protect_tag,position_cn,hps_d_hr_status) order by dt desc) as rn
  from list
  where store_cvs_code = '101001036'