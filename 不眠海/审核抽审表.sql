SELECT t2.stat_point_id AS `统计点id` ,
       t2.task_id AS `任务id` ,
       t2.task_type AS `任务类型` ,
       t2.project_code AS `统计对象id` ,
       t2.project_name AS `统计对象名称` ,
       t2.stat_point_name AS `统计点名称` ,
       t2.begin_time AS `开始时间` ,
       t2.end_time AS `结束时间` ,
       t2.audit_type AS `审核方式` ,
       t2.flow_type AS `计数类型` ,
       t2.applier_id AS `统计人编码` ,
       t2.applier_name AS `统计人姓名` ,
       t2.charge_person_id AS `负责人编码` ,
       t2.charge_person_name AS `负责人姓名` ,
       t2.project_id AS `项目id` ,
       t2.poi_id AS `统计对象poiid` ,
       t2.flag_code AS `统计对象插旗编码` ,
       t2.city_id AS `城市编码` ,
       t2.city_name AS `城市名称` ,
       t2.region_id AS `大区编码` ,
       t2.region_name AS `大区名称` ,
       t2.audit_id AS `审核id` ,
       t2.auditor_id AS `审核人编码` ,
       t2.auditor_name AS `审核人姓名` ,
       t2.audit_begin_time AS `审核开始时间` ,
       t2.audit_end_time AS `审核结束时间` ,
       t2.audit_count AS `审核统计人流量` ,
       t2.counter_count AS `审核人流量` ,
       t2.audit_error AS `审核误差` ,
       t2.audit_threshold AS `审核误差及格阈值` ,
       t2.audit_status AS `审核结果` ,
       t2.audit_remark AS `审核备注` ,
       t2.audit_round AS `审核轮数` ,
       t2.audit_submit_time AS `审核提交时间` ,
       t2.count_submit_time AS `人工计数任务统计员提交时间` ,
       t2.audit_is_delete AS `审核是否删除` ,
       t2.is_valid AS `逻辑判断有效` ,
       t2.finish_status AS `完成状态` ,
       t2.finish_time AS `完成时间` ,
       t2.audit_create_time AS `人工计数申请同意时间` ,
       t2.count_applicant AS `采集提交人` ,
       t2.count_applicant_submit_time AS `采集提交时间` ,
       t2.min_submit_time AS `审核第一次提交时间` ,
       t2.submit_times AS `提交次数` ,
       t2.init_count AS `待统计次数` ,
       t2.refuse_count AS `驳回次数` ,
       t2.pass_count AS `审核通过次数` ,
       t2.cancel_count AS `取消次数` ,
       t2.uncountable_hour AS `不可用时长`
FROM
  (SELECT t1.* ,
          CASE
              WHEN t1.audit_times = 1
                   AND t1.audit_status IN ('合格',
                                           '无法审核') THEN '有效'
              WHEN t1.audit_times >= 2
                   AND t1.audit_round = '二审' THEN '有效'
              WHEN t1.audit_status = '合格'
                   AND t1.after_audit_status = '不合格'
                   AND t1.after_audit_round = '二审' THEN '无效'
              WHEN t1.audit_status = '不合格'
                   AND t1.after_audit_status = '合格'
                   AND t1.after_audit_round = '二审' THEN '无效'
              WHEN t1.audit_status = t1.after_audit_status
                   AND t1.after_audit_round = '二审' THEN '有效'
              WHEN t1.audit_status = '合格'
                   AND t1.audit_round = '一审'
                   AND t1.before_audit_status = '不合格'
                   AND t1.before_audit_round = '二审' THEN '有效'
              ELSE NULL
          END AS is_valid
   FROM
     (SELECT stat_point_id ,
             task_id ,
             task_type ,
             project_code ,
             project_name ,
             stat_point_name ,
             begin_time ,
             end_time ,
             audit_type ,
             flow_type ,
             applier_id ,
             applier_name ,
             charge_person_id ,
             charge_person_name ,
             project_id ,
             poi_id ,
             flag_code ,
             city_id ,
             city_name ,
             region_id ,
             region_name ,
             audit_id ,
             auditor_id ,
             auditor_name ,
             audit_begin_time ,
             audit_end_time ,
             audit_count ,
             counter_count ,
             audit_error ,
             audit_threshold ,
             audit_status ,
             audit_remark ,
             audit_round ,
             audit_submit_time ,
             count_submit_time ,
             audit_is_delete ,
             finish_status ,
             finish_time ,
             audit_create_time ,
             count_applicant ,
             count_applicant_submit_time ,
             min_submit_time  ,
             submit_times ,
             init_count ,
             refuse_count ,
             pass_count ,
             cancel_count ,
             uncountable_hour ,
             count(task_id)over(partition BY task_id,audit_begin_time,audit_end_time) AS audit_times ,
             lead(audit_status)over(partition BY task_id,audit_begin_time,audit_end_time
                                    ORDER BY audit_submit_time) AS after_audit_status ,
             lead(audit_round)over(partition BY task_id,audit_begin_time,audit_end_time
                                   ORDER BY audit_submit_time) AS after_audit_round ,
             lag(audit_status)over(partition BY task_id,audit_begin_time,audit_end_time
                                   ORDER BY audit_submit_time) AS before_audit_status ,
             lag(audit_round)over(partition BY task_id,audit_begin_time,audit_end_time
                                  ORDER BY audit_submit_time) AS before_audit_round
      FROM data_build.dwd_store_construction_info_stat_audit_info_v1
      WHERE dt = date_format(date_sub(current_date(),1),'yyyyMMdd'))t1
   WHERE to_date(t1.audit_submit_time) between '2023-09-01' and date_format(date_sub(current_date(),1),'yyyy-MM-dd'))t2