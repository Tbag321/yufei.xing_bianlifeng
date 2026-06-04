--门店货架数，看的是历史下发陈列任务中，货架数最大的一次
--blf_sotre_normal_temperature_shelf_num
select
b.*
from(
select
a.*,
row_number() over (partition by concat(a.store_code,a.shelf_division_name) order by a.shelf_num desc) as rn
from(
with a as(
    SELECT
shelf_division_code,
shelf_division_name
from default.pdw_cvs_product_display_base_shelf_type
WHERE dt = '${today-1}'
GROUP BY shelf_division_code,
shelf_division_name
)
select
a.effective_date
,a.store_code
,b.shelf_division_name
,count(distinct a.shelf_id) as shelf_num
from data_smartorder.dw_sku_display_next_week_store_sku_display_di a
left join a b on a.shelf_type=b.shelf_division_code
where a.dt > 20160101--如果要看最近一期的陈列，把日期调整成周四，每周四是陈列下发日期
and a.shelf_id > 0 
and a.sku_code is not null 
--and a.shelf_division_name = '常温货架' 
--and b.shelf_division_name = '常温货架'
--and store_code='4de548348098ef294bca53c2e1007f02'
group by a.effective_date,a.store_code,b.shelf_division_name
) a
) b
where rn = 1

