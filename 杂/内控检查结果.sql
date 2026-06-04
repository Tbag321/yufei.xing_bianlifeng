--识别门店异常
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
 display_name)

select 
target_date
,b.store_cvs_code
,b.display_name
,case_type
,case when case_type = 1 then 'fake_make'
when case_type = 3 then 'early_sale'
when case_type = 4 then 'oden_no_cover'
when case_type = 5 then 'late_meal'
when case_type = 6 then 'meal_end_box'
when case_type = 8 then 'make_refuse_sale'
when case_type = 10 then 'unfinished_makedivision'
when case_type = 11 then 'FF_make_deficiency' 
when case_type = 12 then 'new_fake_make'
when case_type = 13 then 'finished_sold_out'
else null end as alarm_type
,case when case_type = 6 then '末期成盒'
when case_type = 8 then '现点现做拒绝销售'
when case_type = 11 then 'FF区生产计划符合标准(少制作)'
when case_type = 10 then '生产计划未执行'
when case_type = 5 then '出餐陈列合规'
when case_type = 1 then '虚假录入'
when case_type = 3 then '早做晚录'
when case_type = 4 then '关东煮盖盖'
when case_type = 13 then '成品售罄'
end as business_name
,get_json_object(content,'$.kindName') as kindName
,get_json_object(content,'$.mealSectionName') as mealSectionName
,count(distinct id) as show_cnt
from default.pdw_idss_ims_examine_inventory_bad_case a
left join desensitization b on a.shop_code = b.store_code
where (status = 3 or (status = 6 and eliminate_type = 1))
and dt = date_format(date_sub(current_date,1),'yyyyMMdd')
and target_date between date_sub(current_date,365) and date_sub(current_date,1)
-- and case_type in (1,3,4,5,6,8,10,11,12,13,14)
--and get_json_object(content,'$.manualCountJobVO.kindName') = '热菜'
--and get_json_object(content,'$.manualCountJobVO.mealSectionName') = '午餐'
and store_code in ('100000237','100002001','108000076')
group by target_date,b.store_cvs_code
,b.display_name,case_type
,case when case_type = 1 then 'fake_make'
when case_type = 3 then 'early_sale'
when case_type = 4 then 'oden_no_cover'
when case_type = 5 then 'late_meal'
when case_type = 6 then 'meal_end_box'
when case_type = 8 then 'make_refuse_sale'
when case_type = 10 then 'unfinished_makedivision'
when case_type = 11 then 'FF_make_deficiency' 
when case_type = 12 then 'new_fake_make'
when case_type = 13 then 'finished_sold_out'
else null end
,case when case_type = 6 then '末期成盒'
when case_type = 8 then '现点现做拒绝销售'
when case_type = 11 then 'FF区生产计划符合标准(少制作)'
when case_type = 10 then '生产计划未执行'
when case_type = 5 then '出餐陈列合规'
when case_type = 1 then '虚假录入'
when case_type = 3 then '早做晚录'
when case_type = 4 then '关东煮盖盖'
when case_type = 13 then '成品售罄'
end
,get_json_object(content,'$.kindName')
,get_json_object(content,'$.mealSectionName')

---------------------------------------------------------------------------------------------------------------------------------------------------------------
--大盘
--识别门店异常
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
 display_name)

select 
target_date
--,b.store_cvs_code
--,b.display_name
,case_type
,case when case_type = 1 then 'fake_make'
when case_type = 3 then 'early_sale'
when case_type = 4 then 'oden_no_cover'
when case_type = 5 then 'late_meal'
when case_type = 6 then 'meal_end_box'
when case_type = 8 then 'make_refuse_sale'
when case_type = 10 then 'unfinished_makedivision'
when case_type = 11 then 'FF_make_deficiency' 
when case_type = 12 then 'new_fake_make'
when case_type = 13 then 'finished_sold_out'
else null end as alarm_type
,case when case_type = 6 then '末期成盒'
when case_type = 8 then '现点现做拒绝销售'
when case_type = 11 then 'FF区生产计划符合标准(少制作)'
when case_type = 10 then '生产计划未执行'
when case_type = 5 then '出餐陈列合规'
when case_type = 1 then '虚假录入'
when case_type = 3 then '早做晚录'
when case_type = 4 then '关东煮盖盖'
when case_type = 13 then '成品售罄'
end as business_name
,count(distinct b.store_cvs_code)
,count(distinct id) as show_cnt
from default.pdw_idss_ims_examine_inventory_bad_case a
left join desensitization b on a.shop_code = b.store_code
where (status = 3 or (status = 6 and eliminate_type = 1))
and dt = date_format(date_sub(current_date,1),'yyyyMMdd')
and target_date between date_sub(current_date,1365) and date_sub(current_date,1)
-- and case_type in (1,3,4,5,6,8,10,11,12,13,14)
group by target_date
--,b.store_cvs_code
--,b.display_name
,case_type
,case when case_type = 1 then 'fake_make'
when case_type = 3 then 'early_sale'
when case_type = 4 then 'oden_no_cover'
when case_type = 5 then 'late_meal'
when case_type = 6 then 'meal_end_box'
when case_type = 8 then 'make_refuse_sale'
when case_type = 10 then 'unfinished_makedivision'
when case_type = 11 then 'FF_make_deficiency' 
when case_type = 12 then 'new_fake_make'
when case_type = 13 then 'finished_sold_out'
else null end
,case when case_type = 6 then '末期成盒'
when case_type = 8 then '现点现做拒绝销售'
when case_type = 11 then 'FF区生产计划符合标准(少制作)'
when case_type = 10 then '生产计划未执行'
when case_type = 5 then '出餐陈列合规'
when case_type = 1 then '虚假录入'
when case_type = 3 then '早做晚录'
when case_type = 4 then '关东煮盖盖'
when case_type = 13 then '成品售罄'
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--内控检查结果
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
 display_name)

select 
substr(start_time,1,10) as check_date 
,store_cvs_code
,display_name
,alarm_type
,count(distinct id) as push_cnt
,count(distinct case when review_result = 2 then id else null end ) as unqualified_cnt
,count(distinct case when review_result = 1 then id else null end ) as qualified_cnt
,count(distinct case when review_result = 3 then id else null end ) as uncorrelated_cnt
from default.pdw_assassin_creed_alarm a
left join desensitization b on a.shop_id = b.store_code
where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and store_cvs_code = '108000076'
and substr(start_time,1,10) between date_sub(current_date(),1365) and date_sub(current_date(),1)
and alarm_type in ('make_refuse_sale','meal_end_box','FF_make_deficiency','unfinished_makedivision','early_clear_up','fake_make','early_sale','oden_no_cover','late_meal','finished_sold_out','material_sold_out')
group by 
substr(start_time,1,10)
,store_cvs_code
,display_name 
,alarm_type

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--大盘
--内控检查结果
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
 display_name)

select 
substr(start_time,1,10) as check_date 
--,store_cvs_code
--,display_name
,alarm_type
,count(distinct store_cvs_code) as store_num
,count(distinct id) as push_cnt
,count(distinct case when review_result = 2 then id else null end ) as unqualified_cnt
,count(distinct case when review_result = 1 then id else null end ) as qualified_cnt
,count(distinct case when review_result = 3 then id else null end ) as uncorrelated_cnt
from default.pdw_assassin_creed_alarm a
left join desensitization b on a.shop_id = b.store_code
where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
--and store_cvs_code = '108000076'
and substr(start_time,1,10) between date_sub(current_date(),1365) and date_sub(current_date(),1)
and alarm_type in ('make_refuse_sale','meal_end_box','FF_make_deficiency','unfinished_makedivision','early_clear_up','fake_make','early_sale','oden_no_cover','late_meal','finished_sold_out','material_sold_out')
group by 
substr(start_time,1,10)
--,store_cvs_code
--,display_name 
,alarm_type

--------------------------------------------------------------------------------------------------------------------------------
--识别门店异常
with desensitization as(
select
 store_code,
 store_name,
 store_cvs_code,
 display_name
 from data_md.dm_md_dim_store_base_info_store_v1
 where dt = date_format(date_sub(current_date(),2),'yyyyMMdd')
 group by
 store_code,
 store_name,
 store_cvs_code,
 display_name)

select 
target_date
,b.store_cvs_code
,b.display_name
,case_type
,case when case_type = 5 then 'late_meal'
else null end as alarm_type
,case when case_type = 5 then '出餐陈列合规'
end as business_name
,get_json_object(content,'$.kindName') as kindName
,get_json_object(content,'$.mealSectionName') as mealSectionName
,get_json_object(content,'$.checkTime') as mealSectionName
,count(distinct id) as show_cnt
from default.pdw_idss_ims_examine_inventory_bad_case a
left join desensitization b on a.shop_code = b.store_code
where (status = 3 or (status = 6 and eliminate_type = 1))
and dt = date_format(date_sub(current_date,2),'yyyyMMdd')
and target_date between date_sub(current_date,3365) and date_sub(current_date,1)
and case_type = '5'
-- and case_type in (1,3,4,5,6,8,10,11,12,13,14)
and get_json_object(content,'$.kindName') = '热菜'
--and target_date = '2022-12-09'
--and get_json_object(content,'$.manualCountJobVO.mealSectionName') = '午餐'
--and store_code in ('100000237','100002001','108000076')
--and substr(get_json_object(content,'$.checkTime'),11,2) between '11' and '14'
group by target_date,b.store_cvs_code
,b.display_name,case_type
,case when case_type = 5 then 'late_meal'
else null end
,case when case_type = 5 then '出餐陈列合规'
end
,get_json_object(content,'$.kindName')
,get_json_object(content,'$.mealSectionName')
,get_json_object(content,'$.checkTime')