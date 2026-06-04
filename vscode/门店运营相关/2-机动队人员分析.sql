--0506在职的机动队员分析
with base_list as(
SELECT
*
from(
SELECT
*
,row_number() over(PARTITION BY concat(employee_id,rn) ORDER BY new_dt) as number_up --按日期升序对同岗位时进行编号
,row_number() over(PARTITION BY concat(employee_id,rn) ORDER BY new_dt desc) as number_desc --按日期降序对同岗位时进行编号
from(
SELECT
*
,sum(rm) over(PARTITION BY employee_id ORDER BY new_dt) as rn --得到每次岗位的唯一编号
from(
SELECT
*
,CASE WHEN post_name = LAG(post_name) OVER (ORDER BY concat(employee_id,new_dt)) THEN 0 ELSE 1 END as rm --如果和上一条岗位一致就是0否则就是1
from data_build.dwd_staff_raw_list_v1_da
where dt = 20240506
--and new_dt = '2024-05-06'
--and post_name = '机动队'
--and employee_id in ('11152461','11303805')
and hps_d_hr_status = '在职') a
) b
) c
where number_up = '1' or number_desc = '1'
),

--当前在职的机动队员
current_district_list as(
select
employee_id
,store_code
,hps_d_jobcode
from data_build.dwd_staff_raw_list_v1_da
where dt = 20240506
and new_dt = '2024-05-06'
and post_name = '机动队'
and hps_d_hr_status = '在职'
and hps_d_jobcode in ('店经理','门店伙伴','店员','社会PT','学生PT','见习店经理')
)

select
c.*
,d.store_name
,d.protect_tag
,d.protect_tag_detail
from(
select
a.*
,case when last_post_name is null then post_name
when datediff(new_dt,last_new_dt) > 60 then post_name
else last_post_name end as last_post_name_new --如果是空，证明这是首次入职，岗位就是当前入职的岗位，如果距离上次离职大于60天，也认为是首次入职
,row_number() over(partition by a.employee_id order by new_dt desc) as rn
from(
select
new_dt
,store_code
,employee_id
,name
,leave_dt
,hps_d_hr_status
,hps_hire_type
,hps_d_jobcode
,manager_code
,post_name
,hps_hire_date
,number_up
,number_desc
,lag(new_dt) over(partition by employee_id order by concat(employee_id,new_dt)) as last_new_dt 
,lag(post_name) over(partition by employee_id order by concat(employee_id,new_dt)) as last_post_name
from base_list
) a
left join current_district_list b on a.employee_id = b.employee_id
where post_name = '机动队'
and b.employee_id is not null
and number_up = '1'
) c
left join data_shop.dm_shop_staff_protect_tag_v2 d on c.employee_id = d.staff_code and d.dt = 20240506
where rn = '1'
and d.staff_code is not null

*********************************************************************************************************************************************
--2023年10月-2024年4月全部员工分析
--现在要分析店维度的数据，就要以店和人为单位了
with store_sale as( --门店日商
select
order_date
,t.store_code 
,t.store_name
,sum(t.payable_price) as payable_price --折后销售额
from data_build.dw_order_sku_v1 t
where t.dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and t.store_type = '0'
and t.order_status = 'FINISHED'
and t.sku_class_code not in ('86','50')
and t.sku_quantity > 0
and t.order_date between '2017-01-01' and '2024-04-30'
group by order_date
,t.store_code 
,t.store_name
),

store_sale_new_week as( --门店日商最新一周(0415-0421)
select
t.store_code 
,t.store_name
,sum(t.payable_price)/count(distinct order_date) as payable_price_new --最新一周日商
from data_build.dw_order_sku_v1 t
where t.dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and t.store_type = '0'
and t.order_status = 'FINISHED'
and t.sku_class_code not in ('86','50')
and t.sku_quantity > 0
and t.order_date between '2024-04-15' and '2024-04-21'
group by
t.store_code 
,t.store_name
),

store_sale_23_9 as( --门店日商(23m9--10月1号前28天)
select
t.store_code 
,t.store_name
,sum(t.payable_price)/count(distinct order_date) as payable_price_new --最新一周日商
from data_build.dw_order_sku_v1 t
where t.dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and t.store_type = '0'
and t.order_status = 'FINISHED'
and t.sku_class_code not in ('86','50')
and t.sku_quantity > 0
and t.order_date between '2023-09-03' and '2023-09-30'
group by
t.store_code 
,t.store_name
),

store_sale_old as( --门店21-22年25分位值日商
select
store_code
,Percentile_approx(payable_price_new, 0.75) as payable_price_21_22
from(
select
order_date
,t.store_code 
,t.store_name
,sum(t.payable_price)/count(distinct order_date) as payable_price_new --门店日商
from data_build.dw_order_sku_v1 t
where t.dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and t.store_type = '0'
and t.order_status = 'FINISHED'
and t.sku_class_code not in ('86','50')
and t.sku_quantity > 0
and t.order_date between '2021-01-01' and '2022-12-31'
group by order_date
,t.store_code 
,t.store_name
) a
group by
store_code
),

store_type as(
select
from_unixtime(unix_timestamp(t1.dt,'yyyyMMdd'),'yyyy-MM-dd') as record_date
,t1.store_code
,case when t1.cancel_status_desc in ('解约中','已完成解约') and t2.payable_price is null --即使解约门店同时也没有日商
then 0 else 1 end as store_type
from data_build.dim_store_construction_project_info t1
left join store_sale t2 on from_unixtime(unix_timestamp(t1.dt,'yyyyMMdd'),'yyyy-MM-dd') = t2.order_date and t1.store_code = t2.store_code
where t1.dt >= 20170101
),

store_manager_list as( --仅限识别机动队带店,注意不容许一个人同一天带N个店
select distinct
from_unixtime(unix_timestamp(t0.dt,'yyyyMMdd'),'yyyy-MM-dd') as record_date
,t0.dept_code as store_code
,if(length(t0.manager_code)=6,concat('10',t0.manager_code),t0.manager_code) as manager_code
from data_build.pdw_opc_shop_ehr_staff_dept_view t0
left join data_build.pdw_psprod_ps_blf_ehr_pers_vw_view t1 on if(length(t0.manager_code)=6,concat('10',t0.manager_code),t0.manager_code) = if(length(t1.emplid)=6,concat('10',t1.emplid),t1.emplid) and t1.dt = t0.dt
left join --剔除停业门店
(select
concat(substr(dt,1,4),'-',substr(dt,5,2),'-',substr(dt,7,2)) as roster_date
,store_code
,if(store_status_desc in ('营业','暂停营业'),'已开业',store_status_desc) as store_status_desc
from data_smartorder.dw_ordering_store_tag_location_ranking_info_v1
where dt >= 20170101) t2 on from_unixtime(unix_timestamp(t0.dt,'yyyyMMdd'),'yyyy-MM-dd') = t2.roster_date and t0.dept_code = t2.store_code
left join store_type t3 on from_unixtime(unix_timestamp(t0.dt,'yyyyMMdd'),'yyyy-MM-dd') = t3.record_date and t0.dept_code = t3.store_code
where t0.dt >= 20170101
and t1.hps_d_jobcode in ('店经理','储备店经理','见习店经理','门店伙伴','社会PT','学生PT','防疫伙伴','店副经理','内部合作经营者','内部合作辅助人','内部合作伙伴','外部合作经营者','外部合作辅助人','外部合作伙伴')
and t1.hps_d_hr_status = '在职'
and t1.hps_dept_descr_lv1 in ('运营管理部X')
and t0.shop_sign = '1'
and t2.store_status_desc = '已开业'
and t3.store_type = '1' --不匹配已解约的门店，避免出现一个人带两个店的情况,但是如果门店正常有日商还是需要匹配
),

franchise_list as( --加盟清单
select distinct 
store_code
from data_build.pdw_bach_baseinfo_shop_shop
where dt <= date_format(date_sub(current_date(),1),'yyyyMMdd')
and self_take_type = '4' --加盟店
),

staff_list_base as( --每个人每天的岗位变化情况
SELECT
new_dt
,employee_id
,post_name
,rm
,rn
,number_up
,number_desc
from(
SELECT
new_dt
,employee_id
,post_name
,rm
,rn
,row_number() over(PARTITION BY concat(employee_id,rn) ORDER BY new_dt) as number_up --按日期升序对同岗位时进行编号
,row_number() over(PARTITION BY concat(employee_id,rn) ORDER BY new_dt desc) as number_desc --按日期降序对同岗位时进行编号
from(
SELECT
new_dt
,employee_id
,post_name
,rm
,sum(rm) over(PARTITION BY employee_id ORDER BY new_dt) as rn --得到每次岗位的唯一编号
from(
SELECT
new_dt
,employee_id
,post_name
,CASE WHEN post_name = LAG(post_name) OVER (ORDER BY concat(employee_id,new_dt)) THEN 0 ELSE 1 END as rm --如果和上一条岗位一致就是0否则就是1
from data_build.dwd_staff_raw_list_v1_da
where dt = 20240506
--and employee_id in ('11152461','11303805','11162439')
and hps_d_hr_status = '在职') a
) b
) c
),

staff_list as(
select
new_dt
,employee_id
,post_name
,rm
,rn
,number_up
,number_desc
,last_new_dt
,next_new_dt

,case when number_up = '1' and last_post_name is null then concat('新入职的',post_name)
when number_up = '1' and  datediff(new_dt,last_new_dt) > 60 then concat('离职超过60天后新入职的',post_name)
else concat(last_post_name,'转',post_name) end as last_post_name_new --如果是空，证明这是首次入职，岗位就是当前入职的岗位，如果距离上次离职大于60天，也认为是首次入职

,case when number_desc = '1' and next_post_name is null then concat('彻底离职')
when number_desc = '1' and  datediff(next_new_dt,new_dt) > 60 then concat('离职超过60天后新入职的',next_post_name)
else concat(post_name,'转',next_post_name) end as next_post_name_new --如果是空，证明这是首次入职，岗位就是当前入职的岗位，如果距离上次离职大于60天，也认为是首次入职

from(
select
new_dt
,employee_id
,post_name
,rm
,rn
,number_up
,number_desc
,lag(new_dt) over(partition by employee_id order by concat(employee_id,new_dt)) as last_new_dt --上一个岗位的时间
,lag(post_name) over(partition by employee_id order by concat(employee_id,new_dt)) as last_post_name --上一个岗位的名称
,lead(new_dt) over(partition by employee_id order by concat(employee_id,new_dt)) as next_new_dt --下一个岗位的时间
,lead(post_name) over(partition by employee_id order by concat(employee_id,new_dt)) as next_post_name --下一个岗位的名称
from staff_list_base
) a
),

store_staff_list as(
SELECT
*
,row_number() over(PARTITION BY concat(employee_id,rn) ORDER BY new_dt) as number_up --按日期升序对同岗位时进行编号
,row_number() over(PARTITION BY concat(employee_id,rn) ORDER BY new_dt desc) as number_desc --按日期降序对同岗位时进行编号
from(
SELECT
*
,sum(rm) over(PARTITION BY employee_id ORDER BY new_dt) as rn --得到每次岗位的唯一编号
from(
SELECT
t0.dt_v1 --dt
,t0.new_dt --日期
,t0.store_code --门店编码
,nvl(case when t1.store_code is not null and t0.store_code <> t1.store_code then t1.store_code else t0.store_code end,'-1') as store_code_new --机动队带店的换成真实的门店编码
,t0.employee_id --员工编码
,t0.name --员工姓名
,t0.hps_hire_dt --系统雇佣时间(没用)
,t0.leave_dt --离职日期
,t0.hps_d_hr_status --在离职状态
,t0.hps_hire_type --雇佣类型
,t0.hps_d_jobcode --系统岗位
,t0.manager_code --判断是否架构负责人
,t0.post_name --岗位
,t0.rn_1 --按照人*时间维度排序
,t0.rn_2 --第几次入职
,t0.hps_hire_date --本次雇佣周期开始日期
,t0.hire_date_num --本次雇佣周期时长
,CASE WHEN 
concat(nvl(case when t1.store_code is not null and t0.store_code <> t1.store_code then t1.store_code else t0.store_code end,-1),post_name) 
= 
LAG(concat(nvl(case when t1.store_code is not null and t0.store_code <> t1.store_code then t1.store_code else t0.store_code end,-1),post_name)) 
OVER (ORDER BY concat(employee_id,new_dt)) THEN 0 ELSE 1 END as rm --如果和上一条岗位一致就是0否则就是1,这里要变化的是如果这个人换店了，应该从1重新开始
from data_build.dwd_staff_raw_list_v1_da t0
left join store_manager_list t1 on t0.new_dt = t1.record_date and t0.employee_id = t1.manager_code
where t0.dt = 20240506
--and t0.employee_id in ('11162439','11179803','11249443','11152461')
and t0.hps_d_hr_status = '在职'
) a
) b
),

raw_list as(
select
t0.*
,t1.last_new_dt
,t1.next_new_dt
,t1.last_post_name_new
,t1.next_post_name_new

,case when t0.number_desc = '1' and t1.next_post_name_new = '架构负责人转机动队' then '门店架构负责人转机动队' 
      when t0.number_desc = '1' and t1.next_post_name_new = '店副经理转机动队' then '门店店副经理转机动队'
      when t0.number_desc = '1' and t1.next_post_name_new = '店员转机动队' then '门店店员转机动队'
      when t0.number_up = '1' and t0.post_name = '机动队' then '架构负责人变化-由机动队带店'
      when t0.number_up = '1' and t1.last_post_name_new in ('店副经理转架构负责人','店员转架构负责人','其它转架构负责人') then '架构负责人变化-原有店员晋升带店'
      else '无门店人员转为机动队，长期店长带店' end as change_type 

from store_staff_list t0
left join staff_list t1 on t0.employee_id = t1.employee_id and t0.new_dt = t1.new_dt
left join store_sale t2 on t0.store_code_new = t2.store_code and t2.order_date = '2024-04-30'
left join franchise_list t4 on t0.store_code_new = t4.store_code
where t0.new_dt between '2023-10-01' and '2024-04-30'
and t2.store_code is not null --取4月30号有日商的门店
and t4.store_code is null --剔除已经加盟的门店
--and t0.store_code_new in ('123000072','123000339','123000165','123000109','123000561','123001351','123000060',
--'100000282','100002501','100078005','100001083','100003195','100000370','100001693','123000555','100005076','100005535','100000219','123001251'
--,'109000083','100000231','100005138')
--and (t0.number_up = '1' or t0.number_desc = '1') --这里不要限制第一天进或最后一天出的条件，避免在统计周期内没有进出的门店统计不进去
),

store_type_list as(
select distinct
t0.store_code_new
,case when t1.change_type is not null then t1.change_type
when t1.change_type is null and t2.change_type is not null then t2.change_type
when t1.change_type is null and t2.change_type is null and t3.change_type is not null then t3.change_type
when t1.change_type is null and t2.change_type is null and t3.change_type is null and t4.change_type is not null then t4.change_type
when t1.change_type is null and t2.change_type is null and t3.change_type is null and t4.change_type is null and t5.change_type is not null then t5.change_type
else '无门店人员转为机动队，长期店长带店' end as change_type_final
from 
(select
distinct
store_code_new
from raw_list) t0
left join 
(select distinct
store_code_new
,change_type
from
raw_list
where change_type = '门店架构负责人转机动队'
) t1 on t0.store_code_new = t1.store_code_new
left join 
(select distinct
store_code_new
,change_type
from
raw_list
where change_type = '门店店副经理转机动队'
) t2 on t0.store_code_new = t2.store_code_new
left join 
(select distinct
store_code_new
,change_type
from
raw_list
where change_type = '门店店员转机动队'
) t3 on t0.store_code_new = t3.store_code_new
left join 
(select distinct
store_code_new
,change_type
from
raw_list
where change_type = '架构负责人变化-由机动队带店'
) t4 on t0.store_code_new = t4.store_code_new
left join 
(select distinct
store_code_new
,change_type
from
raw_list
where change_type = '架构负责人变化-原有店员晋升带店'
) t5 on t0.store_code_new = t5.store_code_new 
),

raw_list_1 as(
select
*
,case when change_type_final = '无门店人员转为机动队，长期店长带店' then '2023-10-01' else new_dt end as new_dt_new --把没有人员变化的日期锁定在23-10-01，后续算其前28天日商使用 
from(
select
t0.*
,t1.change_type_final
,row_number() over(partition by t0.store_code_new order by t0.new_dt) as rn_one --以门店为一组，根据日期升序编号
from raw_list t0
left join store_type_list t1 on t0.store_code_new = t1.store_code_new and t0.change_type = t1.change_type_final --从明细里取和门店类型一样的那条数据
where t1.store_code_new is not null
) a
where a.rn_one = '1' --取第一次发生变化的那条数据
)

select
t0.*
,t1.order_date
,t1.store_name
,t1.payable_price
,t2.payable_price_new
,t3.breakeven_point
,t4.payable_price_21_22
from raw_list_1 t0
left join store_sale t1 on t0.store_code_new = t1.store_code and t1.order_date between date_sub(t0.new_dt_new,28) and date_sub(t0.new_dt_new,1)
left join store_sale_new_week t2 on t0.store_code_new = t2.store_code --最新一周日商
left join data_build.dm_site_selection_store_info_lite t3 on t0.store_code_new = t3.store_code and t3.dt = 20240511 --门店BE
left join store_sale_old t4 on t0.store_code_new = t4.store_code --21-22年25分位值日商































1）门店架构负责人转机动队
2）门店店副经理转机动队
3）门店店员转机动队
4）架构负责人变化-由机动队带店
5）架构负责人变化-原有店员晋升带店
6）无门店人员转为机动队，长期店长带店

- 有门店人员转为机动队的门店 （可以进一步细分为有架构负责人转的、有店员/店副转的）
- 无门店人员转为机动队的门店，但是架构负责人变化过，变成由机动队带店的 （再加一列最新架构负责人是机动队/门店体系的人）
- 无门店人员转为机动队的门店，但是架构负责人变化过，变成由新店长（原有店员晋升）带店的（再加一列最新架构负责人是机动队/门店体系的人）
- 无门店人员转为机动队的门店，无架构负责人变化，长期店长带店的

--最新一周日商取0415-0421周日商