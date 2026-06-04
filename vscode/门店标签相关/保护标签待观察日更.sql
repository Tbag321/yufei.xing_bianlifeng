select
  t1.emplid,
  t3.cum_attend_hours_after_entry as t0_cum_attend_hours_after_entry,
  t2.cum_attend_hours_after_entry as t1_cum_attend_hours_after_entry,
  t1.protect_tag_detail as protect_tag_detail_auto
from
  data_shop.app_shop_staff_protect_tag_v2_da t1
  inner join data_shop.dwa_shop_staff_will_v2_da t2 on t1.emplid = t2.emplid
  and t2.dt = '${today-2}'
  inner join data_shop.dwa_shop_staff_will_v2_da t3 on t1.emplid = t3.emplid
  and t3.dt = '${today-1}'
where
  t1.dt = '${today-1}'
  and t3.cum_attend_hours_after_entry >= 60
  and t2.cum_attend_hours_after_entry < 60