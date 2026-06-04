select distinct
 previous_order_id as order_id
 ,date_format(1st_create_date,'yyyy-MM-dd') as 1st_create_time
 ,chain_status as order_status
 ,case
 when locate('#', regexp_replace(1st_item_id,'[0-9]','#')) > 0
 then 1st_flow_name else 1st_item_id end as punish_item
 ,case when length(1st_shop_code)>9 then regexp_extract(1st_shop_code,'(.*)(: )(.*)',3)
 else 1st_shop_code end as shop_code
 ,1st_shop_name as shop_name
 ,null as event_date
 ,coalesce(3rd_final_user_name,2nd_final_user_name,1st_final_user_name) as staff_name
 ,if(length(coalesce(3rd_final_user_code,2nd_final_user_code,1st_final_user_code))<8
 ,concat('10',coalesce(3rd_final_user_code,2nd_final_user_code,1st_final_user_code))
 ,coalesce(3rd_final_user_code,2nd_final_user_code,1st_final_user_code)) as final_code
 ,coalesce(3rd_final_user_code,2nd_final_user_code,1st_final_user_code) as emplid
 ,case
 when coalesce(3rd_final_feedback_type,2nd_final_feedback_type,2nd_feedback_type
 ,1st_final_feedback_type,1st_feedback_type) = '工时数量扣减'
 then '工时数量扣减' else '工时费用扣减' end as punish_type
 ,case
 when coalesce(3rd_final_feedback_type,2nd_final_feedback_type,2nd_feedback_type,1st_final_feedback_type
 ,1st_feedback_type)= '工时数量扣减'
 then 20*cast(coalesce(1st_final_feedback_result_value,1st_feedback_result_value
 ,2nd_final_feedback_result_value,2nd_feedback_result_value
 ,3rd_final_feedback_result_value,0) as double)
 else cast(coalesce(
 1st_final_feedback_result_value,1st_feedback_result_value,2nd_final_feedback_result_value
 ,2nd_feedback_result_value,3rd_final_feedback_result_value,0) as double) end as punish_money_value
 ,cast(coalesce(
 1st_final_feedback_result_value,1st_feedback_result_value,2nd_final_feedback_result_value
 ,2nd_feedback_result_value,3rd_final_feedback_result_value,0) as double) as punish_value
 from data_build.dwd_store_construction_operation_punish_flow_pipeline_v1 t1
 where dt = '${DATE}'