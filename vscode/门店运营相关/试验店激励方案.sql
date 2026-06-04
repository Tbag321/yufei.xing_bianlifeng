--算薪月在本店出勤时长
with attend_info as ( --实际出勤
select
work_shift_date --考勤班次日期
,if(length(employee_no) = 6,concat('10',employee_no),employee_no) as employee_no --员工工号
,employee_name --员工姓名
,store_code --排班门店code
,store_name --排班门店名称
,sum(attendance_work_hours) as attendance_work_hours --考勤工时小时数
from data_build.pdw_opc_shop_attendance_report_work_shift_view
where dt = '${today-1}'
and work_shift_date between '2024-08-01' and '2024-08-31' --算薪月
and work_shift_type in (1,9,12) --考勤班次类型CODE
and store_code in ('100001105','100000229','100003003','100001107','100001005','100001156','100000028','100000025','100001370','100000615','100000211','100000623','100000685','100001019','100003126','100000591','100000663','100001373','100000013','100000012','100000152','100000320','100000299','100000280','100005197','100000696',
'100000276','100001686','100001283','100009001','100025002','100000318','100000665','100000086','100000075','100001062','100000221','100000631','100001365','100001561','100073009','100011005','100000232','100001531','100000556','100000396',
'100079021','100000186','100003269','100005053','100005509','100000257','100001371','100000225','100079015','100000105','100000235','100003655','100000666','100000536','100000290','100001382','100001399','100000310','100000521','100000639',
'100000688','100000375','100000693','100000697','100005167','100001565','100001191','100001183','100000570','100002379','100001568','100001106','100003151','100005063','100003005','100000587','100000332','100005165',
'100001501','100003198','101000235','123000127','110000069','101000102','123000288','101000086','101000095','101000113','101001056','110000097','100000266','101000130','123000030','101000193','123001037','101000107','101000123','110000132','123000190','101000052','123000008','101000109','110000119','101000373','123000273','123000329','123000505','123001065','100000535',
'110000072','110000065','110000161','101000065','101000129','100071001','110000171')
group by
work_shift_date
,employee_no
,employee_name
,store_code
,store_name
)

--在职时长
,a_list as( --更新入职日期，防止换签导致的入职日期刷新
select
dt
,emplid
,leave_dt
,case when leave_dt is null then 0 else 1 end as add_num
from data_build.pdw_psprod_ps_blf_ehr_pers_vw_view
where dt >= 20210318
)

,b_list as( --更新入职日期，防止换签导致的入职日期刷新
select
dt
,emplid
,leave_dt
,sum(add_num) over(partition by emplid order by concat(dt,emplid) desc) as sum_num
from a_list
)

,c_list as( --更新入职日期，防止换签导致的入职日期刷新
select
dt
,emplid
,leave_dt
,sum_num
,max(leave_dt) over(partition by concat(emplid,sum_num) order by concat(dt,emplid) desc) as final_leave_dt
from b_list
)

,leave_list as( --更新入职日期，防止换签导致的入职日期刷新
select
dt
,if(length(t1.emplid)=6,concat('10',t1.emplid),t1.emplid) as employee_id
,case when final_leave_dt is null then '2035-12-31' else final_leave_dt end as leave_dt
from c_list t1
)

,staff_list as( --更新入职日期，防止换签导致的入职日期刷新
select
dt
,new_dt
,store_code
,emplid
,employee_id
,name
,hps_hire_dt
,leave_dt
,hps_d_hr_status
,hps_hire_type
,hps_d_jobcode
,hps_dept_descr_lv1
,hps_d_city
,hps_dept_code_lv5
,hps_dept_descr_lv5
,row_number() over(partition by employee_id order by dt) as rn_1 --按照人*时间排序
,dense_rank() over(partition by employee_id order by leave_dt) as rn_2 --第几次在职
,min(hps_hire_dt) over(partition by concat(employee_id,dense_rank() over(partition by employee_id order by leave_dt)) order by hps_hire_dt) as hps_hire_date
,case when hps_d_hr_status = '离职' then '离职' else 
datediff(new_dt,min(hps_hire_dt) over(partition by concat(employee_id,dense_rank() over(partition by employee_id order by leave_dt)) order by hps_hire_dt))
end as hire_date_num
from
(
select
t1.dt
,from_unixtime(unix_timestamp(t1.dt,'yyyyMMdd'),'yyyy-MM-dd') as new_dt
,t1.hps_dept_code_lv5 as store_code
,t1.emplid
,if(length(t1.emplid)=6,concat('10',t1.emplid),t1.emplid) as employee_id
,name
,t1.hps_hire_dt
,t3.leave_dt
,case when t3.leave_dt = '2035-12-31' then '在职'
when t3.leave_dt >= from_unixtime(unix_timestamp(t1.dt,'yyyyMMdd'),'yyyy-MM-dd') then '在职'
else '离职' end as hps_d_hr_status --在离职状态
,t1.hps_hire_type --用工形式
,t1.hps_d_jobcode
,t1.hps_dept_descr_lv1
,t1.hps_d_city
,t1.hps_dept_code_lv5
,t1.hps_dept_descr_lv5
from data_build.pdw_psprod_ps_blf_ehr_pers_vw_view t1
left join leave_list t3 on if(length(t1.emplid)=6,concat('10',t1.emplid),t1.emplid) = t3.employee_id and t1.dt = t3.dt
where t1.dt >= 20210318
) a
)

,raw_list as( --更新入职日期，防止换签导致的入职日期刷新
select
t.dt
,t.new_dt --日期
,t.store_code --门店编码
,t.emplid
,t.employee_id
,t.name
,t.hps_hire_dt --系统雇佣时间(没用)
,t.leave_dt --离职日期
,t.hps_d_hr_status --在离职状态
,t.hps_hire_type
,t.hps_d_jobcode
,t.hps_dept_descr_lv1
,t.hps_d_city
,t.hps_dept_code_lv5
,t.hps_dept_descr_lv5
,t.rn_1 --按照人*时间维度排序
,t.rn_2 --第几次入职
,t.hps_hire_date --本次雇佣周期开始日期(真实的入职日期)
,t.hire_date_num --本次雇佣周期时长
from staff_list t
)

select
t1.work_shift_date --考勤班次日期
,t1.employee_no --员工工号
,t1.employee_name --员工姓名
,t1.store_code --排班门店code
,t1.store_name --排班门店名称
,t1.attendance_work_hours --考勤工时小时数
,case when t2.protect_tag_detail_new = '0' then '钻石'
when t2.protect_tag_detail_new = '1' then '金牌'
when t2.protect_tag_detail_new = '2' then '普通银牌'
when t2.protect_tag_detail_new = '3' then '待观察'
when t2.protect_tag_detail_new = '4' then '铜牌'
when t2.protect_tag_detail_new = '5' then '应离职'
when t2.protect_tag_detail_new = '6' then '优质银牌' end as protect_tag_detail_new
,t3.hps_hire_date --入职日期
,t4.position_cn
,t4.position_class
from attend_info t1
left join data_shop.dm_shop_staff_protect_tag_v2 t2 on t1.employee_no = t2.staff_code and t2.dt = '20240831' --算薪月最后一天(取当天架构判断是否换店以及标签)
left join 
(select
employee_id
,max(hps_hire_date) as hps_hire_date
from raw_list
group by
employee_id) t3 on t1.employee_no = t3.employee_id --取入职日期
left join data_shop.dm_shop_staff_protect_tag_v2 t4 on t1.employee_no = t4.staff_code and date_format(t1.work_shift_date,'yyyyMMdd') = t4.dt and t4.dt > '20170101' --取出勤当天的岗位
where datediff('2024-08-31',date_format(hps_hire_date,'yyyy-MM-dd')) >= 90 --在职大于等于90天
and t1.store_code = t2.store_code --算薪月最后一天架构属于本店且仍在职
and t2.protect_tag_detail_new in ('0','1','2','6') --金银牌