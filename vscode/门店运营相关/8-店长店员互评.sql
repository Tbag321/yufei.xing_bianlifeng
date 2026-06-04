--取店员sql
SELECT 
t1.*
,t2.hps_sys_name
from data_shop.dm_shop_staff_protect_tag_v2 t1
LEFT JOIN data_shop.pdw_psprod_ps_blf_ehr_pers_vw_view t2
on t1.staff_code = IF(LENGTH(t2.emplid)<8,concat('10',t2.emplid),t2.emplid) and t1.dt = t2.dt
where t1.dt = '${today-1}'
and t1.position_cn not in ('内部合作伙伴','内部合作经营者','内部合作辅助人','外部合作伙伴','外部合作经营者','外部合作辅助人')
and position_class not in ('老架构负责人','新架构负责人')