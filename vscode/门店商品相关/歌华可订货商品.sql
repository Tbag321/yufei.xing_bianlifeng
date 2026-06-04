--歌华可订货商品
with warehouse_list as( 
SELECT
beginning_date	
,warehouse_code  --仓库code
,sku_division_code
,sku_division_name
,sku_code
,sku_name
,sku_main_code
,sku_main_name
,sum(quantity) as quantity
from data_smartorder.dm_copy_dm_logistics_inventory_wms_snapshoot_v1_view
where dt =date_format(date_sub(current_date(),1),'yyyyMMdd')
and inventory_type = '1' --库存类型: 1.可用 2.占用 3.冻结 4.锁定
and sku_grade <> '3'  --商品等级 1.良品 3.残品
group by
beginning_date
,warehouse_code  --仓库code
,sku_division_code
,sku_division_name
,sku_code
,sku_name
,sku_main_code
,sku_main_name
),

sku_info as(
select
sku_code
,sku_name
,sku_division_code
,sku_division_name
from data_build.dim_sku_info
where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
group by
sku_code
,sku_name
,sku_division_code
,sku_division_name
),

real_time_inventory as(
SELECT * from data_smartorder.dm_copy_dw_inventory_store_snapshot_ha_v1_view
where dt = date_format(current_date(),'yyyyMMdd')
and hr = substr(from_unixtime(unix_timestamp()-3600),12,2)
and store_code = '100078005'
and is_available = '1'
),

all_sku_list as(
select
t3.snapshot_time
,t0.store_code
,t0.store_name
,t1.sku_division_name
,case when t1.sku_division_name in ('成品便当','成品粥','面类其他','小碗菜便当','中式面类','饭团','寿司','蛋类','低温副食品','豆制品','方便菜','干货','干调','夹馅冷冻食品','冷藏饼类','冷冻方便菜',
'冷冻煎烤炸物','冷冻熟食卤味','冷冻甜品','麻辣烫','南北干货','其他','其他冷冻食品','生制品','熟食、精肉','熟食礼盒','熟食卤味','咸菜、小菜','一手店熟食','主食点心','常温蛋糕','节庆商品','曲奇饼干','甜味面包','吐司/切片面包',
'咸味面包','长保面包','中式糕点','冰鲜水产','称重菜-小菜','葱姜蒜椒','豆制品类','干果及南北货','根茎类','瓜果类','果菜类','果切拼盘','火锅测试项目','净菜/快手菜','卷类沙拉','菌菇类','卡券类','冷藏牛肉类','冷藏禽类',
'冷藏羊肉类','冷藏猪肉类','冷冻蔬菜类','冷冻水产','面食类','牛肉类','拼团商品','其他肉类','其它生鲜','禽类','球茎类','肉蛋禽','肉禽蛋礼盒','社区散称','生鲜节庆','蔬菜豆制品','蔬菜礼盒','蔬菜沙拉',
'熟食点心','水产干货','水果','水果切块','调理肉类','调理水产品','鲜活水产','箱装商品','芽苗/豆类','腌制/腊肉','羊肉类','叶菜类','有机/供港菜','猪肉类','猪肉预加工','猪肉预加工原料','汉堡包','三明治',
'蛋糕','卷饼','甜品杯装','甜品节庆','甜品其他','甜品饮料','芝士、黄油') then '风幕日配品'
when t1.sku_division_name in ('蛋黄酱．调味汁','果酱','其他罐头','低进价品牛奶、乳饮料','豆浆','牛奶','乳饮料','软饮乳饮料','酸奶','现打酸奶','即食甜点','低进价品软饮料','果汁','果汁饮料','咖啡饮料') then '风幕相关常规品'
else t1.sku_division_name end as sku_division_name_v1
,t0.sku_code
,t0.sku_name
,t0.warehouse_code
,t0.warehouse_name
,t2.quantity  --大仓库存
,t3.quantity as store_quantity  --门店实时库存
from data_smartorder.dm_copy_dim_store_sku_info_view t0
left join sku_info t1 on t0.sku_code = t1.sku_code
left join warehouse_list t2 on t0.warehouse_code = t2.warehouse_code and t0.sku_code = t2.sku_code
left join real_time_inventory t3 on t0.sku_code = t3.sku_code
where t0.dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and t0.store_code = '100078005'
and status_code = '01'  --门店商品状态编码
and logistics_status_code = '01'  --物流商品状态编码
--and sku_status_desc = '可订货'
--and t0.sku_code = '31010180'
)

select
snapshot_time
,sku_division_name_v1
,sku_division_name
,sku_code
,sku_name
,'可订货' as quantity
,store_quantity
from all_sku_list
where sku_division_name_v1 in ('风幕日配品')

union all

select
snapshot_time
,sku_division_name_v1
,sku_division_name
,sku_code
,sku_name
,cast(quantity as string) as quantity
,store_quantity
from all_sku_list
where sku_division_name_v1 in ('风幕相关常规品')
and quantity > 0






-----------------------------------------------------------------------------------------------------------------------------------------------------------------

--歌华可订货商品(冰淇淋)
with warehouse_list as( 
SELECT
beginning_date	
,warehouse_code  --仓库code
,sku_division_code
,sku_division_name
,sku_code
,sku_name
,sku_main_code
,sku_main_name
,sum(quantity) as quantity
from data_smartorder.dm_copy_dm_logistics_inventory_wms_snapshoot_v1_view
where dt =date_format(date_sub(current_date(),1),'yyyyMMdd')
and inventory_type = '1' --库存类型: 1.可用 2.占用 3.冻结 4.锁定
and sku_grade <> '3'
group by
beginning_date
,warehouse_code  --仓库code
,sku_division_code
,sku_division_name
,sku_code
,sku_name
,sku_main_code
,sku_main_name
),

sku_info as(
select
sku_code
,sku_name
,sku_division_code
,sku_division_name
from data_build.dim_sku_info
where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
group by
sku_code
,sku_name
,sku_division_code
,sku_division_name
)

select
t0.dt
,t0.store_code
,t0.store_name
,t1.sku_division_name
,t0.sku_code
,t0.sku_name
,t0.warehouse_code
,t0.warehouse_name
,t2.quantity
from data_smartorder.dm_copy_dim_store_sku_info_view t0
left join sku_info t1 on t0.sku_code = t1.sku_code
left join warehouse_list t2 on t0.warehouse_code = t2.warehouse_code and t0.sku_code = t2.sku_code
where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and store_code = '100078005'
and status_code = '01'  --门店商品状态编码
and logistics_status_code = '01'  --物流商品状态编码
and t1.sku_division_code in ('4201','4202','4203','4204','4205','7942')
--and sku_status_desc = '可订货'
--and t0.sku_code = '31010180'
