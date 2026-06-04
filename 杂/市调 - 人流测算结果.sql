select * as region_code 
from project_info p 
inner join stat_point_info s on p.id=s.project_id 
inner join stat_jobs sj on s.id=sj.stat_point_id 
inner join region_info r on r.id=p.region_id 
inner join city_info c on c.id=r.city_id 
where p.type='写字楼'
poi_info



select tag,sum(count_step) 
from stat_job_flows_${c.code}_${r.code} 
where client_job_code=client_job_code 
and count_time>=begin_time 
and count_time<end_time 
group by tag



select
c.name as `城市`,
p.name as `统计对象名称`,
s.name as `统计点`,
sj.begin_time as `统计日期`,
sj.begin_time as `统计开始时间`,
sj.end_time as `统计结束时间`,
audit_process as `审核状态`,
tag as tag,
sum(count_step)  as `人流量`
from project_info p
join stat_point_info s on p.id=s.project_id
join stat_jobs sj on s.id=



select
tag,
sum(count_step)
from default.pdw_opc_flag_stat_job_flows





with b as(
select a.* from
(select
*,
row_number() over (partition by concat(client_job_code,count_time,tag) order by created_time desc) as rn
from default.pdw_opc_flag_stat_job_flows
where dt=20220823) a
where rn = 1
)--处理发回重审情况

select
a.* from
(
SELECT
f.name,
d.type,
e.name as area,
b.project_name,
b.stat_point_name,
b.begin_time,
b.end_time,
substring(begin_time,12,10) as b_time,
substring(end_time,12,10) as e_time,
sum(a.count_step) as num
from b a
left JOIN default.pdw_opc_flag_stat_jobs b on a.client_job_code=b.client_job_code and b.dt=20220823
join default.pdw_opc_flag_stat_point_info c on b.stat_point_id = c.id and c.dt=20220823
join default.pdw_opc_flag_project_info d on c.project_id = d.id and d.dt=20220823
join default.pdw_opc_flag_region_info e on e.id = d.region_id and e.dt=20220823
join default.pdw_opc_flag_city_info f on f.id = e.city_id and f.dt=20220823
WHERE b.audit_process=3
and d.type='写字楼'
--and f.name in ('杭州')
and a.tag in ('t2_m_in','t2_w_in')
and b.task_detail_id = 0
GROUP BY f.name,
d.type,
e.name,
b.project_name,
b.stat_point_name,
b.begin_time,
b.end_time,
substring(begin_time,12,10),
substring(end_time,12,10)
) a
where b_time = '07:30:00'
and e_time = '11:30:00'




with b as(
select a.* from
(select
*,
row_number() over (partition by concat(client_job_code,count_time,tag) order by created_time desc) as rn
from default.pdw_opc_flag_stat_job_flows
where dt=date_format(date_sub(current_date(),2),'yyyyMMdd')) a
where rn = 1
)--处理发回重审情况

select
x.name,
x.type,
x.code,
x.area,
x.project_name,
x.stat_point_name,
x.begin_time,
x.end_time,
x.mw_in,
x.mw_out
from (
SELECT
a.client_job_code,
f.name,
g.code,
d.type,
e.name as area,
b.project_name,
b.stat_point_name,
b.begin_time,
b.end_time,
sum(case when a.tag in ('t2_m_in','t2_w_in') then a.count_step end) as mw_in,
sum(case when a.tag in ('t2_m_out','t2_w_out') then a.count_step end) as mw_out
from b a
left JOIN default.pdw_opc_flag_stat_jobs b on a.client_job_code=b.client_job_code and b.dt=date_format(date_sub(current_date(),2),'yyyyMMdd')
join default.pdw_opc_flag_stat_point_info c on b.stat_point_id = c.id and c.dt=date_format(date_sub(current_date(),2),'yyyyMMdd')
join default.pdw_opc_flag_project_info d on c.project_id = d.id and d.dt=date_format(date_sub(current_date(),2),'yyyyMMdd')
join default.pdw_opc_flag_region_info e on e.id = d.region_id and e.dt=date_format(date_sub(current_date(),2),'yyyyMMdd')
join default.pdw_opc_flag_city_info f on f.id = e.city_id and f.dt=date_format(date_sub(current_date(),2),'yyyyMMdd')
join default.pdw_opc_flag_poi_info g on g.id = d.poi_id and g.dt=date_format(date_sub(current_date(),2),'yyyyMMdd')
WHERE b.audit_process=3
--and f.name = '廊坊'
and substring(a.count_time,12,10) between '07:30:00' and '11:30:00'
GROUP BY 
a.client_job_code,
f.name,
g.code,
d.type,
e.name,
b.project_name,
b.stat_point_name,
b.begin_time,
b.end_time) x
where x.code in ('NK-299')

----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--无时间切片
with b as(
select a.* from
(select
*,
row_number() over (partition by concat(client_job_code,count_time,tag) order by created_time desc) as rn
from default.pdw_opc_flag_stat_job_flows
where dt=date_format(date_sub(current_date(),2),'yyyyMMdd')) a
where rn = 1
)--处理发回重审情况

select
x.client_job_code,
x.name,
x.type,
x.code,
x.area,
x.project_name,
x.stat_point_name,
x.begin_time,
x.end_time,
count_time,
count_step,
x.mw_in,
x.mw_out,
x.mw_in_new,
x.mw_out_new
from (
SELECT
a.client_job_code,
f.name,
g.code,
d.type,
e.name as area,
b.project_name,
b.stat_point_name,
b.begin_time,
b.end_time,
count_time,
sum(a.count_step) as count_step,
sum(case when a.tag in ('t2_m_in','t2_w_in') then a.count_step end) as mw_in,
sum(case when a.tag in ('t2_m_out','t2_w_out') then a.count_step end) as mw_out,
sum(case when a.tag in ('t4_in') then a.count_step end) as mw_in_new,
sum(case when a.tag in ('t4_out') then a.count_step end) as mw_out_new
from b a
left JOIN default.pdw_opc_flag_stat_jobs b on a.client_job_code=b.client_job_code and b.dt=date_format(date_sub(current_date(),2),'yyyyMMdd')
join default.pdw_opc_flag_stat_point_info c on b.stat_point_id = c.id and c.dt=date_format(date_sub(current_date(),2),'yyyyMMdd')
join default.pdw_opc_flag_project_info d on c.project_id = d.id and d.dt=date_format(date_sub(current_date(),2),'yyyyMMdd')
join default.pdw_opc_flag_region_info e on e.id = d.region_id and e.dt=date_format(date_sub(current_date(),2),'yyyyMMdd')
join default.pdw_opc_flag_city_info f on f.id = e.city_id and f.dt=date_format(date_sub(current_date(),2),'yyyyMMdd')
join default.pdw_opc_flag_poi_info g on g.id = d.poi_id and g.dt=date_format(date_sub(current_date(),2),'yyyyMMdd')
--WHERE b.audit_process=3
--and f.name = '廊坊'
--and substring(a.count_time,12,10) between '07:00:00' and '23:00:00'
GROUP BY 
a.client_job_code,
f.name,
g.code,
d.type,
e.name,
b.project_name,
b.stat_point_name,
b.begin_time,
b.end_time
,count_time) x
where x.code in ('JY-3721')

----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--汇总人数
with b as(
select a.* from
(select
*,
row_number() over (partition by concat(client_job_code,count_time,tag) order by created_time desc) as rn
from default.pdw_opc_flag_stat_job_flows
where dt=date_format(date_sub(current_date(),2),'yyyyMMdd')) a
where rn = 1
)--处理发回重审情况

select
x.client_job_code,
x.name,
x.type,
x.code,
x.area,
x.project_name,
x.stat_point_name,
x.begin_time,
x.end_time,
case when flow_type = 0 then 'app' else 'artificial' end as flow_type,
sum(case when substring(count_time,12,8) between '07:30:00' and '11:30:00' and flow_type = 0 THEN x.mw_in else 0 end) as app_mw_in,
sum(case when substring(count_time,12,8) between '07:30:00' and '11:00:00' and flow_type = 1 THEN x.mw_in else 0 end) as artificial_mw_in,
sum(case when substring(count_time,12,8) between '07:30:00' and '11:30:00' and flow_type = 0 THEN x.mw_out else 0 end) as app_mw_out,
sum(case when substring(count_time,12,8) between '07:30:00' and '11:00:00' and flow_type = 1 THEN x.mw_out else 0 end) as artificial_mw_out,
sum(case when substring(count_time,12,8) between '07:30:00' and '11:30:00' and flow_type = 0 THEN x.mw_in_new else 0 end) as app_mw_in_new,
sum(case when substring(count_time,12,8) between '07:30:00' and '11:00:00' and flow_type = 1 THEN x.mw_in_new else 0 end) as artificial_mw_in_new,
sum(case when substring(count_time,12,8) between '07:30:00' and '11:30:00' and flow_type = 0 THEN x.mw_out_new else 0 end) as app_mw_out_new,
sum(case when substring(count_time,12,8) between '07:30:00' and '11:00:00' and flow_type = 1 THEN x.mw_out_new else 0 end) as artificial_mw_out_new
from (
SELECT
a.client_job_code,
f.name,
g.code,
d.type,
e.name as area,
b.project_name,
b.stat_point_name,
b.begin_time,
b.end_time,
b.flow_type,--0app计数，1人工计数
count_time,
sum(case when a.tag in ('t2_m_in','t2_w_in') then a.count_step end) as mw_in,
sum(case when a.tag in ('t2_m_out','t2_w_out') then a.count_step end) as mw_out,
sum(case when a.tag in ('t4_in') then a.count_step end) as mw_in_new,
sum(case when a.tag in ('t4_out') then a.count_step end) as mw_out_new
from b a
left JOIN default.pdw_opc_flag_stat_jobs b on a.client_job_code=b.client_job_code and b.dt=date_format(date_sub(current_date(),2),'yyyyMMdd')
join default.pdw_opc_flag_stat_point_info c on b.stat_point_id = c.id and c.dt=date_format(date_sub(current_date(),2),'yyyyMMdd')
join default.pdw_opc_flag_project_info d on c.project_id = d.id and d.dt=date_format(date_sub(current_date(),2),'yyyyMMdd')
join default.pdw_opc_flag_region_info e on e.id = d.region_id and e.dt=date_format(date_sub(current_date(),2),'yyyyMMdd')
join default.pdw_opc_flag_city_info f on f.id = e.city_id and f.dt=date_format(date_sub(current_date(),2),'yyyyMMdd')
join default.pdw_opc_flag_poi_info g on g.id = d.poi_id and g.dt=date_format(date_sub(current_date(),2),'yyyyMMdd')
GROUP BY 
a.client_job_code,
f.name,
g.code,
d.type,
e.name,
b.project_name,
b.stat_point_name,
b.begin_time,
b.end_time,
b.flow_type
,count_time) x
where x.code in ('DC6-216')
group by
x.client_job_code,
x.name,
x.type,
x.code,
x.area,
x.project_name,
x.stat_point_name,
x.begin_time,
x.end_time,
case when flow_type = 0 then 'app' else 'artificial' end

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--项目反馈明细
select
t2.requirement_name as xiang_mu_ming_cheng_tong_ji_dui_xiang_ming_cheng001 -- ,
,t2.flag_code as qi_biao_bian_hao002 -- ,
,t1.requirement_id as dui_ying_shu_chu_zhi_chi003 -- ,
,t1.operator as dui_ying_shu_chu_uid004 -- ,
,t2.project_type as xiang_mu_lei_xing005 -- ,
,t1.create_time as chuang_jian_shi_jian006 -- ,
,t2.type as lei_xing007 -- ,
,t3.name as ming_cheng008 -- 
--,'20230401' AS dt_start,
--'20230430' AS dt_end
FROM data_build.pdw_sts_info_collect_requirement_action_log t1
LEFT JOIN data_build.pdw_sts_info_collect_requirement_view t2 on t1.requirement_id = t2.id
AND t2.dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
LEFT JOIN data_build.pdw_opc_flag_city_info t3 on t2.city_id = t3.id
AND t3.dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
WHERE t1.dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and t2.type='HINTERLAND'
--and t1.action_type='35'
and t1.create_time BETWEEN concat('2023-03-01','00:00:00')
and concat('2023-08-20','23:59:59')
















--汇总人数
with b as(
select a.* from
(select
*,
row_number() over (partition by concat(client_job_code,count_time,tag) order by created_time desc) as rn
from default.pdw_opc_flag_stat_job_flows
where dt=date_format(date_sub(current_date(),2),'yyyyMMdd')) a
where rn = 1
)--处理发回重审情况

select
x.client_job_code,
x.name,
x.type,
x.code,
x.area,
x.project_name,
x.stat_point_name,
x.begin_time,
x.end_time,
case when flow_type = 0 then 'app' else 'artificial' end as flow_type,
sum(case when substring(count_time,12,8) between '07:00:00' and '07:30:00' THEN count_step else 0 end) as app_mw_in,
sum(case when substring(count_time,12,8) between '07:30:01' and '08:00:00' THEN count_step else 0 end) as app_mw_in,
sum(case when substring(count_time,12,8) between '08:00:01' and '08:30:00' THEN count_step else 0 end) as app_mw_in,
sum(case when substring(count_time,12,8) between '08:30:01' and '09:00:00' THEN count_step else 0 end) as app_mw_in,
sum(case when substring(count_time,12,8) between '09:00:01' and '09:30:00' THEN count_step else 0 end) as app_mw_in,
sum(case when substring(count_time,12,8) between '09:30:01' and '10:00:00' THEN count_step else 0 end) as app_mw_in,
sum(case when substring(count_time,12,8) between '10:00:01' and '10:30:00' THEN count_step else 0 end) as app_mw_in,
sum(case when substring(count_time,12,8) between '10:30:01' and '11:00:00' THEN count_step else 0 end) as app_mw_in,
sum(case when substring(count_time,12,8) between '11:00:01' and '11:30:00' THEN count_step else 0 end) as app_mw_in,
sum(case when substring(count_time,12,8) between '11:30:01' and '12:00:00' THEN count_step else 0 end) as app_mw_in,
sum(case when substring(count_time,12,8) between '12:00:01' and '12:30:00' THEN count_step else 0 end) as app_mw_in,
sum(case when substring(count_time,12,8) between '12:30:01' and '13:00:00' THEN count_step else 0 end) as app_mw_in,
sum(case when substring(count_time,12,8) between '13:00:01' and '13:30:00' THEN count_step else 0 end) as app_mw_in,
sum(case when substring(count_time,12,8) between '13:30:01' and '14:00:00' THEN count_step else 0 end) as app_mw_in,
sum(case when substring(count_time,12,8) between '14:00:01' and '14:30:00' THEN count_step else 0 end) as app_mw_in,
sum(case when substring(count_time,12,8) between '14:30:01' and '15:00:00' THEN count_step else 0 end) as app_mw_in,
sum(case when substring(count_time,12,8) between '15:00:01' and '15:30:00' THEN count_step else 0 end) as app_mw_in,
sum(case when substring(count_time,12,8) between '15:30:01' and '16:00:00' THEN count_step else 0 end) as app_mw_in,
sum(case when substring(count_time,12,8) between '16:00:01' and '16:30:00' THEN count_step else 0 end) as app_mw_in,
sum(case when substring(count_time,12,8) between '16:30:01' and '17:00:00' THEN count_step else 0 end) as app_mw_in,
sum(case when substring(count_time,12,8) between '17:00:01' and '17:30:00' THEN count_step else 0 end) as app_mw_in,
sum(case when substring(count_time,12,8) between '17:30:01' and '18:00:00' THEN count_step else 0 end) as app_mw_in,
sum(case when substring(count_time,12,8) between '18:00:01' and '18:30:00' THEN count_step else 0 end) as app_mw_in,
sum(case when substring(count_time,12,8) between '18:30:01' and '19:00:00' THEN count_step else 0 end) as app_mw_in,
sum(case when substring(count_time,12,8) between '19:00:01' and '19:30:00' THEN count_step else 0 end) as app_mw_in,
sum(case when substring(count_time,12,8) between '19:30:01' and '20:00:00' THEN count_step else 0 end) as app_mw_in,
sum(case when substring(count_time,12,8) between '20:00:01' and '20:30:00' THEN count_step else 0 end) as app_mw_in,
sum(case when substring(count_time,12,8) between '20:30:01' and '21:00:00' THEN count_step else 0 end) as app_mw_in,
sum(case when substring(count_time,12,8) between '21:00:01' and '21:30:00' THEN count_step else 0 end) as app_mw_in,
sum(case when substring(count_time,12,8) between '21:30:01' and '22:00:00' THEN count_step else 0 end) as app_mw_in
from (
SELECT
a.client_job_code,
f.name,
g.code,
d.type,
e.name as area,
b.project_name,
b.stat_point_name,
b.begin_time,
b.end_time,
b.flow_type,--0app计数，1人工计数
count_time,
sum(a.count_step) as count_step
from b a
left JOIN default.pdw_opc_flag_stat_jobs b on a.client_job_code=b.client_job_code and b.dt=date_format(date_sub(current_date(),2),'yyyyMMdd')
join default.pdw_opc_flag_stat_point_info c on b.stat_point_id = c.id and c.dt=date_format(date_sub(current_date(),2),'yyyyMMdd')
join default.pdw_opc_flag_project_info d on c.project_id = d.id and d.dt=date_format(date_sub(current_date(),2),'yyyyMMdd')
join default.pdw_opc_flag_region_info e on e.id = d.region_id and e.dt=date_format(date_sub(current_date(),2),'yyyyMMdd')
join default.pdw_opc_flag_city_info f on f.id = e.city_id and f.dt=date_format(date_sub(current_date(),2),'yyyyMMdd')
join default.pdw_opc_flag_poi_info g on g.id = d.poi_id and g.dt=date_format(date_sub(current_date(),2),'yyyyMMdd')
GROUP BY 
a.client_job_code,
f.name,
g.code,
d.type,
e.name,
b.project_name,
b.stat_point_name,
b.begin_time,
b.end_time,
b.flow_type
,count_time) x
where substring(count_time,1,10) between '2021-01-01' and '2021-12-31'
group by
x.client_job_code,
x.name,
x.type,
x.code,
x.area,
x.project_name,
x.stat_point_name,
x.begin_time,
x.end_time,
case when flow_type = 0 then 'app' else 'artificial' end