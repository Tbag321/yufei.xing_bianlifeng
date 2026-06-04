--tableau报表 --门店分品类订单 --data_build.dwd_app_order_by_category_workday_or_notworkday_v1_da
with day_list as(
select
date_key
,is_working_day
from data_build.dim_date_ya_v2
),

nine_list as(
select
record_month
,store_code
,store_city
,sale_days
,bool_order
,val_order
,val_order/sale_days as val_order_day
from(
select
x.record_month
,x.store_code
,x.store_city
,x.sale_days
,MAP('日商',order_num_1,'槟榔',x.betel_nut_1,'冰淇淋',x.ice_cream_1,'饼干',x.cookie_1,'干果',x.dried_fruit_1,'果脯',x.preserved_fruit_1,'加工食品',x.processed_food_1,'饮品站/饮品机',x.coffee_soybean_milk_self_service_drink_1,
'烈酒',x.spirits_1,'面包',x.bread_1,'FF萌煮',x.cute_boiling_1,'巧克力',x.chocolate_1,'FF热餐',x.hot_meal_1,'FF早餐酥饼',x.flaky_pastry_1,'肉脯',x.portly_or_obese_person_1,'生活杂货',x.daily_necessities_1,
'嗜好品',x.asaddictive_things_1,'FF炸烤制品',x.fried_baked_goods_1,'水饮',x.retained_fluid_1,'糖果',x.candy_1,'香烟',x.cigarette_1,'休闲食品',x.snack_food_1,'FF蒸包小吃',x.steamed_bun_snacks_1,'热饮料',x.hot_drinks_1
,'便当面条',x.bento_noodles_1,'饭团寿司',x.rice_and_sushi_1,'干货速食',x.dry_and_fast_food_1,'粮油调味',x.grain_and_oil_seasoning_1,'肉蛋果蔬',x.meat_eggs_fruits_and_vegetables_1,'乳饮',x.milk_drink_1,
'三明治汉堡',x.sandwich_burger_1,'特设商品',x.special_merchandise_1,'甜品及其他',x.dessert_fast_food_and_other_1,'非常规卖品',x.unconventional_sales_items_1,'无归属',x.no_attribution_1) AS tmp_column_1
FROM(
select
trunc(t.order_date,'MM') as record_month
,t.store_code
,t.store_city

--营业日
,count(distinct order_date) as sale_days

--全部单量
,count(distinct order_no) as order_num_1

--单量 按照商品拆分
,count(distinct case when sku_division_code in ('3604') then order_no else null end) as betel_nut_1
,count(distinct case when sku_division_code in ('4201','4202','4203','4204','4205','7942') then order_no else null end) as ice_cream_1
,count(distinct case when sku_division_code in ('3408','3407','3405','3406','4401','4402') then order_no else null end) as cookie_1
,count(distinct case when sku_division_code in ('2501','2502','3602','4405','7936') then order_no else null end) as dried_fruit_1
,count(distinct case when sku_division_code in ('2504','3603') then order_no else null end) as preserved_fruit_1
,count(distinct case when sku_division_code in ('4001','4002','4003','4004','4005','4006','4007','4008','7940') then order_no else null end) as processed_food_1
,count(distinct case when sku_division_code in ('5003','5004','5005','5006','5007','5008','5009','5010','5019','5020','0702','0706','0713','0715','0716','0717','0718',
'0719','0720','0721') then order_no else null end) as coffee_soybean_milk_self_service_drink_1
,count(distinct case when sku_division_code in ('3101','3102','3103','3104','3105','3201','3202','3205','7931','7932') then order_no else null end) as spirits_1
,count(distinct case when sku_division_code in ('2101','2102','2103','2104','2105','2106','2107','2108','2109') then order_no else null end) as bread_1
,count(distinct case when sku_division_code in ('0501','0502','0503','0505','0508') then order_no else null end) as cute_boiling_1
,count(distinct case when sku_division_code in ('3404') then order_no else null end) as chocolate_1
,count(distinct case when sku_division_code in ('0301','0304') then order_no else null end) as hot_meal_1
,count(distinct case when sku_division_code in ('0602') then order_no else null end) as flaky_pastry_1
,count(distinct case when sku_division_code in ('3701','3702','3703','4406','7937') then order_no else null end) as portly_or_obese_person_1
,count(distinct case when sku_division_code in ('2701','4009','6401','6402','6403','6404','6406','6407','6408','6501','6502','6503','6504','6601','6602','6701','6702','6703','6801',
'6802','6803','6804','6805','6806','7001','7002','7003','7004','7005','7006','7007','7008','7101','7103','7104','7105','7106','7107','7301','7302','7303','7701','7801',
'7802','7964','7965','7966','7967','7968','7970','7971','7973','7978','7985','7988','7989','8501','8502','8503','8801','8802','8804','8902') then order_no else null end) as daily_necessities_1
,count(distinct case when sku_division_code in ('4101','4102','4103','4104','4105','4106','4407','7941') then order_no else null end) asaddictive_things_1
,count(distinct case when sku_division_code in ('0302') then order_no else null end) as fried_baked_goods_1
,count(distinct case when sku_division_code in ('1205','1206','1207','3001','3002','3003','3301','3302','3303','3304','3305','3306','3307','3309','7930','7933') then order_no else null end) as retained_fluid_1
,count(distinct case when sku_division_code in ('3401','3402','3403','4403') then order_no else null end) as candy_1
,count(distinct case when sku_division_code in ('6101','6102','6103') then order_no else null end) as cigarette_1
,count(distinct case when sku_division_code in ('3501','3502','3503','3601','4404','7935') then order_no else null end) as snack_food_1
,count(distinct case when sku_division_code in ('1501','1502','1503','1504','1505','1506','1507','1508','0303','0309','0310','0312','0313','0314','0601','0603','0604') then order_no else null end) as steamed_bun_snacks_1
,count(distinct case when sku_division_code in ('3310') then order_no else null end) as hot_drinks_1
,count(distinct case when sku_division_code in ('0103','0105','0106','0401','0402') then order_no else null end) as bento_noodles_1
,count(distinct case when sku_division_code in ('0101','0102') then order_no else null end) as rice_and_sushi_1 --饭团寿司
,count(distinct case when sku_division_code in ('1001','1004','1209','1301','1302','1303','1304','1305','1306','1307','1402','1410','2212','2308','2503','2505','2601','2603','2604','2605',
'2606','2607','2608','3801','3810','4301','4302','4303') then order_no else null end) as dry_and_fast_food_1 --干货速食
,count(distinct case when sku_division_code in ('2506','3802','3803','3804','3805','3806','3807','3808','3809','3811','3812','3813','7938') then order_no else null end) as grain_and_oil_seasoning_1 --粮油调味
,count(distinct case when sku_division_code in ('1401','1403','1404','1405','1406','1407','1408','1409','1411','1412','1413','1414','1415','1416','1418','2201','2202','2203','2204','2205',
'2206','2207','2208','2209','2210','2211','2213','2301','2302','2303','2304','2305','2306','2307','2309','2310','2311','2312','2313','2314','2316','2401','2402','2403','2404',
'2406','2407','0801','0802','0805') then order_no else null end) as meat_eggs_fruits_and_vegetables_1 --肉蛋果蔬
,count(distinct case when sku_division_code in ('1201','1202','1203','1204','1208','3308','7912') then order_no else null end) as milk_drink_1 --乳饮
,count(distinct case when sku_division_code in ('0201','0202') then order_no else null end) as sandwich_burger_1 --三明治汉堡
,count(distinct case when sku_division_code in ('3409','3901','3904','3907','3909','3910','3911','6201','7201','7203','7209','7210','7211','7934','7972') then order_no else null end) as special_merchandise_1 --特设商品
,count(distinct case when sku_division_code in ('1101','1102','1103','1104','1105','1210','0204') then order_no else null end) as dessert_fast_food_and_other_1 --甜品及其他
,count(distinct case when sku_division_code in ('2702','2703','4408','5001','5002','7504','8201','8202','8203','8204','8205','8206','8207','8208','8209','8210','8211','8212','8215','8216',
'8217','8218','8220','8222','8223','8224','8225','8226','8401','8601','8602','8603','8604','8605','8606','8607','8608','8701','8702','8703','8704','8705','8706','9101','9102',
'9103','9104','9105','9106','9107','9108','9109','9110','9112','9113','9114','9115','9118','9201','9203','9204','9205','9206','9207','9208','9209','9210','9211','9212','9218',
'9301','9302','9303','9304','9305','9306','9307','9308','9310','9311','9312','9314','9315','9316','9317','9318','9319','9320','9321','9399','9401','9402','9403','9404','9405',
'9601','9602','9603','9604','9605','9606','9607','9701','9702','9703','9704','9705','9706','9707','9708','9709','9710','9711','9712','9713','9714','9715','9716','9717','9801',
'9802','9803','9804','9805','9806','9807','9808','9809','9810','9812','9816','9818','9821','9822','9901','0307','0308','0311','0315','0316','0804','0901','0902','0904','0905',
'0906') then order_no else null end) as unconventional_sales_items_1 --非常规卖品
,count(distinct case when sku_division_code not in ('0501','0502','0503','0505','0508','0301','0304','0602','0302','1501','1502','1503','1504','1505','1506','1507','1508','0303','0309',
'0310','0312','0313','0314','0601','0603','0604','0103','0105','0106','0401','0402','3604','4201','4202','4203','4204','4205','7942','3405','3406','3407','3408','4401','4402',
'0101','0102','2702','2703','4408','5001','5002','7504','8201','8202','8203','8204','8205','8206','8207','8208','8209','8210','8211','8212','8215','8216','8217','8218','8220',
'8222','8223','8224','8225','8226','8401','8601','8602','8603','8604','8605','8606','8607','8608','8701','8702','8703','8704','8705','8706','9101','9102','9103','9104','9105','9106',
'9107','9108','9109','9110','9112','9113','9114','9115','9118','9201','9203','9204','9205','9206','9207','9208','9209','9210','9211','9212','9218','9301','9302','9303','9304','9305',
'9306','9307','9308','9310','9311','9312','9314','9315','9316','9317','9318','9319','9320','9321','9399','9401','9402','9403','9404','9405','9601','9602','9603','9604','9605','9606',
'9607','9701','9702','9703','9704','9705','9706','9707','9708','9709','9710','9711','9712','9713','9714','9715','9716','9717','9801','9802','9803','9804','9805','9806','9807','9808',
'9809','9810','9812','9816','9818','9821','9822','9901','0307','0308','0311','0315','0316','0804','0901','0902','0904','0905','0906','2501','2502','3602','4405','7936','1001','1004',
'1209','1301','1302','1303','1304','1305','1306','1307','1402','1410','2212','2308','2503','2505','2601','2603','2604','2605','2606','2607','2608','3801','3810','4301','4302','4303',
'2504','3603','4001','4002','4003','4004','4005','4006','4007','4008','7940','2506','3802','3803','3804','3805','3806','3807','3808','3809','3811','3812','3813','7938','3101','3102',
'3103','3104','3105','3201','3202','3205','7931','7932','2101','2102','2103','2104','2105','2106','2107','2108','2109','3404','3310','1401','1403','1404','1405','1406','1407','1408',
'1409','1411','1412','1413','1414','1415','1416','1418','2201','2202','2203','2204','2205','2206','2207','2208','2209','2210','2211','2213','2301','2302','2303','2304','2305','2306',
'2307','2309','2310','2311','2312','2313','2314','2316','2401','2402','2403','2404','2406','2407','0801','0802','0805','3701','3702','3703','4406','7937','1201','1202','1203','1204',
'1208','3308','7912','0201','0202','2701','4009','6401','6402','6403','6404','6406','6407','6408','6501','6502','6503','6504','6601','6602','6701','6702','6703','6801','6802','6803',
'6804','6805','6806','7001','7002','7003','7004','7005','7006','7007','7008','7101','7103','7104','7105','7106','7107','7301','7302','7303','7701','7801','7802','7964','7965','7966',
'7967','7968','7970','7971','7973','7978','7985','7988','7989','8501','8502','8503','8801','8802','8804','8902','4101','4102','4103','4104','4105','4106','4407','7941','1205','1206',
'1207','3001','3002','3003','3301','3302','3303','3304','3305','3306','3307','3309','7930','7933','3401','3402','3403','4403','3409','3901','3904','3907','3909','3910','3911','6201',
'7201','7203','7209','7210','7211','7934','7972','1101','1102','1103','1104','1105','1210','0204','6101','6102','6103','3501','3502','3503','3601','4404','7935','5003','5004','5005',
'5006','5007','5008','5009','5010','5019','5020','0702','0706','0713','0715','0716','0717','0718','0719','0720','0721') then order_no else null end) as no_attribution_1 --无归属
 
from 
data_build.dw_order_sku_promotion_v1 t --订单明细表
--data_or.dm_copy_dw_order_sku_promotion_v1_view t
where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and store_type = '0'
and pay_status = 'PAY_SUCCESS'
--and store_code = '100078005'
and t.sku_class_code not in ('86','50')
and order_date between '2023-09-01' and '2023-09-30'
group by
trunc(t.order_date,'MM')
,t.store_code
,store_city) x
) a
LATERAL VIEW EXPLODE(a.tmp_column_1) exptbl as bool_order,val_order
),

full_list as(
select
record_week
,store_code
,store_city
,sale_days
,bool_order
,val_order
,val_order/sale_days as val_order_day
from(
select
x.record_week
,x.store_code
,x.store_city
,x.sale_days
,MAP('日商',order_num_1,'槟榔',x.betel_nut_1,'冰淇淋',x.ice_cream_1,'饼干',x.cookie_1,'干果',x.dried_fruit_1,'果脯',x.preserved_fruit_1,'加工食品',x.processed_food_1,'饮品站/饮品机',x.coffee_soybean_milk_self_service_drink_1,
'烈酒',x.spirits_1,'面包',x.bread_1,'FF萌煮',x.cute_boiling_1,'巧克力',x.chocolate_1,'FF热餐',x.hot_meal_1,'FF早餐酥饼',x.flaky_pastry_1,'肉脯',x.portly_or_obese_person_1,'生活杂货',x.daily_necessities_1,
'嗜好品',x.asaddictive_things_1,'FF炸烤制品',x.fried_baked_goods_1,'水饮',x.retained_fluid_1,'糖果',x.candy_1,'香烟',x.cigarette_1,'休闲食品',x.snack_food_1,'FF蒸包小吃',x.steamed_bun_snacks_1,'热饮料',x.hot_drinks_1
,'便当面条',x.bento_noodles_1,'饭团寿司',x.rice_and_sushi_1,'干货速食',x.dry_and_fast_food_1,'粮油调味',x.grain_and_oil_seasoning_1,'肉蛋果蔬',x.meat_eggs_fruits_and_vegetables_1,'乳饮',x.milk_drink_1,
'三明治汉堡',x.sandwich_burger_1,'特设商品',x.special_merchandise_1,'甜品及其他',x.dessert_fast_food_and_other_1,'非常规卖品',x.unconventional_sales_items_1,'无归属',x.no_attribution_1) AS tmp_column_1
FROM(
select
date_add(t.order_date,7 - case when dayofweek(t.order_date) = 1 then 7 else dayofweek(t.order_date) - 1 end) as record_week
,t.store_code
,t.store_city

--营业日
,count(distinct order_date) as sale_days

--全部单量
,count(distinct order_no) as order_num_1

--单量 按照商品拆分
,count(distinct case when sku_division_code in ('3604') then order_no else null end) as betel_nut_1
,count(distinct case when sku_division_code in ('4201','4202','4203','4204','4205','7942') then order_no else null end) as ice_cream_1
,count(distinct case when sku_division_code in ('3408','3407','3405','3406','4401','4402') then order_no else null end) as cookie_1
,count(distinct case when sku_division_code in ('2501','2502','3602','4405','7936') then order_no else null end) as dried_fruit_1
,count(distinct case when sku_division_code in ('2504','3603') then order_no else null end) as preserved_fruit_1
,count(distinct case when sku_division_code in ('4001','4002','4003','4004','4005','4006','4007','4008','7940') then order_no else null end) as processed_food_1
,count(distinct case when sku_division_code in ('5003','5004','5005','5006','5007','5008','5009','5010','5019','5020','0702','0706','0713','0715','0716','0717','0718',
'0719','0720','0721') then order_no else null end) as coffee_soybean_milk_self_service_drink_1
,count(distinct case when sku_division_code in ('3101','3102','3103','3104','3105','3201','3202','3205','7931','7932') then order_no else null end) as spirits_1
,count(distinct case when sku_division_code in ('2101','2102','2103','2104','2105','2106','2107','2108','2109') then order_no else null end) as bread_1
,count(distinct case when sku_division_code in ('0501','0502','0503','0505','0508') then order_no else null end) as cute_boiling_1
,count(distinct case when sku_division_code in ('3404') then order_no else null end) as chocolate_1
,count(distinct case when sku_division_code in ('0301','0304') then order_no else null end) as hot_meal_1
,count(distinct case when sku_division_code in ('0602') then order_no else null end) as flaky_pastry_1
,count(distinct case when sku_division_code in ('3701','3702','3703','4406','7937') then order_no else null end) as portly_or_obese_person_1
,count(distinct case when sku_division_code in ('2701','4009','6401','6402','6403','6404','6406','6407','6408','6501','6502','6503','6504','6601','6602','6701','6702','6703','6801',
'6802','6803','6804','6805','6806','7001','7002','7003','7004','7005','7006','7007','7008','7101','7103','7104','7105','7106','7107','7301','7302','7303','7701','7801',
'7802','7964','7965','7966','7967','7968','7970','7971','7973','7978','7985','7988','7989','8501','8502','8503','8801','8802','8804','8902') then order_no else null end) as daily_necessities_1
,count(distinct case when sku_division_code in ('4101','4102','4103','4104','4105','4106','4407','7941') then order_no else null end) asaddictive_things_1
,count(distinct case when sku_division_code in ('0302') then order_no else null end) as fried_baked_goods_1
,count(distinct case when sku_division_code in ('1205','1206','1207','3001','3002','3003','3301','3302','3303','3304','3305','3306','3307','3309','7930','7933') then order_no else null end) as retained_fluid_1
,count(distinct case when sku_division_code in ('3401','3402','3403','4403') then order_no else null end) as candy_1
,count(distinct case when sku_division_code in ('6101','6102','6103') then order_no else null end) as cigarette_1
,count(distinct case when sku_division_code in ('3501','3502','3503','3601','4404','7935') then order_no else null end) as snack_food_1
,count(distinct case when sku_division_code in ('1501','1502','1503','1504','1505','1506','1507','1508','0303','0309','0310','0312','0313','0314','0601','0603','0604') then order_no else null end) as steamed_bun_snacks_1
,count(distinct case when sku_division_code in ('3310') then order_no else null end) as hot_drinks_1
,count(distinct case when sku_division_code in ('0103','0105','0106','0401','0402') then order_no else null end) as bento_noodles_1
,count(distinct case when sku_division_code in ('0101','0102') then order_no else null end) as rice_and_sushi_1 --饭团寿司
,count(distinct case when sku_division_code in ('1001','1004','1209','1301','1302','1303','1304','1305','1306','1307','1402','1410','2212','2308','2503','2505','2601','2603','2604','2605',
'2606','2607','2608','3801','3810','4301','4302','4303') then order_no else null end) as dry_and_fast_food_1 --干货速食
,count(distinct case when sku_division_code in ('2506','3802','3803','3804','3805','3806','3807','3808','3809','3811','3812','3813','7938') then order_no else null end) as grain_and_oil_seasoning_1 --粮油调味
,count(distinct case when sku_division_code in ('1401','1403','1404','1405','1406','1407','1408','1409','1411','1412','1413','1414','1415','1416','1418','2201','2202','2203','2204','2205',
'2206','2207','2208','2209','2210','2211','2213','2301','2302','2303','2304','2305','2306','2307','2309','2310','2311','2312','2313','2314','2316','2401','2402','2403','2404',
'2406','2407','0801','0802','0805') then order_no else null end) as meat_eggs_fruits_and_vegetables_1 --肉蛋果蔬
,count(distinct case when sku_division_code in ('1201','1202','1203','1204','1208','3308','7912') then order_no else null end) as milk_drink_1 --乳饮
,count(distinct case when sku_division_code in ('0201','0202') then order_no else null end) as sandwich_burger_1 --三明治汉堡
,count(distinct case when sku_division_code in ('3409','3901','3904','3907','3909','3910','3911','6201','7201','7203','7209','7210','7211','7934','7972') then order_no else null end) as special_merchandise_1 --特设商品
,count(distinct case when sku_division_code in ('1101','1102','1103','1104','1105','1210','0204') then order_no else null end) as dessert_fast_food_and_other_1 --甜品及其他
,count(distinct case when sku_division_code in ('2702','2703','4408','5001','5002','7504','8201','8202','8203','8204','8205','8206','8207','8208','8209','8210','8211','8212','8215','8216',
'8217','8218','8220','8222','8223','8224','8225','8226','8401','8601','8602','8603','8604','8605','8606','8607','8608','8701','8702','8703','8704','8705','8706','9101','9102',
'9103','9104','9105','9106','9107','9108','9109','9110','9112','9113','9114','9115','9118','9201','9203','9204','9205','9206','9207','9208','9209','9210','9211','9212','9218',
'9301','9302','9303','9304','9305','9306','9307','9308','9310','9311','9312','9314','9315','9316','9317','9318','9319','9320','9321','9399','9401','9402','9403','9404','9405',
'9601','9602','9603','9604','9605','9606','9607','9701','9702','9703','9704','9705','9706','9707','9708','9709','9710','9711','9712','9713','9714','9715','9716','9717','9801',
'9802','9803','9804','9805','9806','9807','9808','9809','9810','9812','9816','9818','9821','9822','9901','0307','0308','0311','0315','0316','0804','0901','0902','0904','0905',
'0906') then order_no else null end) as unconventional_sales_items_1 --非常规卖品
,count(distinct case when sku_division_code not in ('0501','0502','0503','0505','0508','0301','0304','0602','0302','1501','1502','1503','1504','1505','1506','1507','1508','0303','0309',
'0310','0312','0313','0314','0601','0603','0604','0103','0105','0106','0401','0402','3604','4201','4202','4203','4204','4205','7942','3405','3406','3407','3408','4401','4402',
'0101','0102','2702','2703','4408','5001','5002','7504','8201','8202','8203','8204','8205','8206','8207','8208','8209','8210','8211','8212','8215','8216','8217','8218','8220',
'8222','8223','8224','8225','8226','8401','8601','8602','8603','8604','8605','8606','8607','8608','8701','8702','8703','8704','8705','8706','9101','9102','9103','9104','9105','9106',
'9107','9108','9109','9110','9112','9113','9114','9115','9118','9201','9203','9204','9205','9206','9207','9208','9209','9210','9211','9212','9218','9301','9302','9303','9304','9305',
'9306','9307','9308','9310','9311','9312','9314','9315','9316','9317','9318','9319','9320','9321','9399','9401','9402','9403','9404','9405','9601','9602','9603','9604','9605','9606',
'9607','9701','9702','9703','9704','9705','9706','9707','9708','9709','9710','9711','9712','9713','9714','9715','9716','9717','9801','9802','9803','9804','9805','9806','9807','9808',
'9809','9810','9812','9816','9818','9821','9822','9901','0307','0308','0311','0315','0316','0804','0901','0902','0904','0905','0906','2501','2502','3602','4405','7936','1001','1004',
'1209','1301','1302','1303','1304','1305','1306','1307','1402','1410','2212','2308','2503','2505','2601','2603','2604','2605','2606','2607','2608','3801','3810','4301','4302','4303',
'2504','3603','4001','4002','4003','4004','4005','4006','4007','4008','7940','2506','3802','3803','3804','3805','3806','3807','3808','3809','3811','3812','3813','7938','3101','3102',
'3103','3104','3105','3201','3202','3205','7931','7932','2101','2102','2103','2104','2105','2106','2107','2108','2109','3404','3310','1401','1403','1404','1405','1406','1407','1408',
'1409','1411','1412','1413','1414','1415','1416','1418','2201','2202','2203','2204','2205','2206','2207','2208','2209','2210','2211','2213','2301','2302','2303','2304','2305','2306',
'2307','2309','2310','2311','2312','2313','2314','2316','2401','2402','2403','2404','2406','2407','0801','0802','0805','3701','3702','3703','4406','7937','1201','1202','1203','1204',
'1208','3308','7912','0201','0202','2701','4009','6401','6402','6403','6404','6406','6407','6408','6501','6502','6503','6504','6601','6602','6701','6702','6703','6801','6802','6803',
'6804','6805','6806','7001','7002','7003','7004','7005','7006','7007','7008','7101','7103','7104','7105','7106','7107','7301','7302','7303','7701','7801','7802','7964','7965','7966',
'7967','7968','7970','7971','7973','7978','7985','7988','7989','8501','8502','8503','8801','8802','8804','8902','4101','4102','4103','4104','4105','4106','4407','7941','1205','1206',
'1207','3001','3002','3003','3301','3302','3303','3304','3305','3306','3307','3309','7930','7933','3401','3402','3403','4403','3409','3901','3904','3907','3909','3910','3911','6201',
'7201','7203','7209','7210','7211','7934','7972','1101','1102','1103','1104','1105','1210','0204','6101','6102','6103','3501','3502','3503','3601','4404','7935','5003','5004','5005',
'5006','5007','5008','5009','5010','5019','5020','0702','0706','0713','0715','0716','0717','0718','0719','0720','0721') then order_no else null end) as no_attribution_1 --无归属
 
from 
data_build.dw_order_sku_promotion_v1 t --订单明细表
--data_or.dm_copy_dw_order_sku_promotion_v1_view t
where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and store_type = '0'
and pay_status = 'PAY_SUCCESS'
--and store_code = '100078005'
and t.sku_class_code not in ('86','50')
and order_date between '2023-08-28' and date_format(date_sub(current_date(),1),'yyyy-MM-dd')
group by
date_add(t.order_date,7 - case when dayofweek(t.order_date) = 1 then 7 else dayofweek(t.order_date) - 1 end)
,t.store_code
,store_city) x
) a
LATERAL VIEW EXPLODE(a.tmp_column_1) exptbl as bool_order,val_order
),

nine_list_wonw as(
select
record_month
,store_code
,store_city
,sale_days
,is_working_day
,bool_order
,val_order
,val_order/sale_days as val_order_day
from(
select
x.record_month
,x.store_code
,x.store_city
,x.sale_days
,x.is_working_day
,MAP('日商',order_num_1,'槟榔',x.betel_nut_1,'冰淇淋',x.ice_cream_1,'饼干',x.cookie_1,'干果',x.dried_fruit_1,'果脯',x.preserved_fruit_1,'加工食品',x.processed_food_1,'饮品站/饮品机',x.coffee_soybean_milk_self_service_drink_1,
'烈酒',x.spirits_1,'面包',x.bread_1,'FF萌煮',x.cute_boiling_1,'巧克力',x.chocolate_1,'FF热餐',x.hot_meal_1,'FF早餐酥饼',x.flaky_pastry_1,'肉脯',x.portly_or_obese_person_1,'生活杂货',x.daily_necessities_1,
'嗜好品',x.asaddictive_things_1,'FF炸烤制品',x.fried_baked_goods_1,'水饮',x.retained_fluid_1,'糖果',x.candy_1,'香烟',x.cigarette_1,'休闲食品',x.snack_food_1,'FF蒸包小吃',x.steamed_bun_snacks_1,'热饮料',x.hot_drinks_1
,'便当面条',x.bento_noodles_1,'饭团寿司',x.rice_and_sushi_1,'干货速食',x.dry_and_fast_food_1,'粮油调味',x.grain_and_oil_seasoning_1,'肉蛋果蔬',x.meat_eggs_fruits_and_vegetables_1,'乳饮',x.milk_drink_1,
'三明治汉堡',x.sandwich_burger_1,'特设商品',x.special_merchandise_1,'甜品及其他',x.dessert_fast_food_and_other_1,'非常规卖品',x.unconventional_sales_items_1,'无归属',x.no_attribution_1) AS tmp_column_1
FROM(
select
trunc(t.order_date,'MM') as record_month
,t.store_code
,t.store_city
,t1.is_working_day

--营业日
,count(distinct order_date) as sale_days

--全部单量
,count(distinct order_no) as order_num_1

--单量 按照商品拆分
,count(distinct case when sku_division_code in ('3604') then order_no else null end) as betel_nut_1
,count(distinct case when sku_division_code in ('4201','4202','4203','4204','4205','7942') then order_no else null end) as ice_cream_1
,count(distinct case when sku_division_code in ('3408','3407','3405','3406','4401','4402') then order_no else null end) as cookie_1
,count(distinct case when sku_division_code in ('2501','2502','3602','4405','7936') then order_no else null end) as dried_fruit_1
,count(distinct case when sku_division_code in ('2504','3603') then order_no else null end) as preserved_fruit_1
,count(distinct case when sku_division_code in ('4001','4002','4003','4004','4005','4006','4007','4008','7940') then order_no else null end) as processed_food_1
,count(distinct case when sku_division_code in ('5003','5004','5005','5006','5007','5008','5009','5010','5019','5020','0702','0706','0713','0715','0716','0717','0718',
'0719','0720','0721') then order_no else null end) as coffee_soybean_milk_self_service_drink_1
,count(distinct case when sku_division_code in ('3101','3102','3103','3104','3105','3201','3202','3205','7931','7932') then order_no else null end) as spirits_1
,count(distinct case when sku_division_code in ('2101','2102','2103','2104','2105','2106','2107','2108','2109') then order_no else null end) as bread_1
,count(distinct case when sku_division_code in ('0501','0502','0503','0505','0508') then order_no else null end) as cute_boiling_1
,count(distinct case when sku_division_code in ('3404') then order_no else null end) as chocolate_1
,count(distinct case when sku_division_code in ('0301','0304') then order_no else null end) as hot_meal_1
,count(distinct case when sku_division_code in ('0602') then order_no else null end) as flaky_pastry_1
,count(distinct case when sku_division_code in ('3701','3702','3703','4406','7937') then order_no else null end) as portly_or_obese_person_1
,count(distinct case when sku_division_code in ('2701','4009','6401','6402','6403','6404','6406','6407','6408','6501','6502','6503','6504','6601','6602','6701','6702','6703','6801',
'6802','6803','6804','6805','6806','7001','7002','7003','7004','7005','7006','7007','7008','7101','7103','7104','7105','7106','7107','7301','7302','7303','7701','7801',
'7802','7964','7965','7966','7967','7968','7970','7971','7973','7978','7985','7988','7989','8501','8502','8503','8801','8802','8804','8902') then order_no else null end) as daily_necessities_1
,count(distinct case when sku_division_code in ('4101','4102','4103','4104','4105','4106','4407','7941') then order_no else null end) asaddictive_things_1
,count(distinct case when sku_division_code in ('0302') then order_no else null end) as fried_baked_goods_1
,count(distinct case when sku_division_code in ('1205','1206','1207','3001','3002','3003','3301','3302','3303','3304','3305','3306','3307','3309','7930','7933') then order_no else null end) as retained_fluid_1
,count(distinct case when sku_division_code in ('3401','3402','3403','4403') then order_no else null end) as candy_1
,count(distinct case when sku_division_code in ('6101','6102','6103') then order_no else null end) as cigarette_1
,count(distinct case when sku_division_code in ('3501','3502','3503','3601','4404','7935') then order_no else null end) as snack_food_1
,count(distinct case when sku_division_code in ('1501','1502','1503','1504','1505','1506','1507','1508','0303','0309','0310','0312','0313','0314','0601','0603','0604') then order_no else null end) as steamed_bun_snacks_1
,count(distinct case when sku_division_code in ('3310') then order_no else null end) as hot_drinks_1
,count(distinct case when sku_division_code in ('0103','0105','0106','0401','0402') then order_no else null end) as bento_noodles_1
,count(distinct case when sku_division_code in ('0101','0102') then order_no else null end) as rice_and_sushi_1 --饭团寿司
,count(distinct case when sku_division_code in ('1001','1004','1209','1301','1302','1303','1304','1305','1306','1307','1402','1410','2212','2308','2503','2505','2601','2603','2604','2605',
'2606','2607','2608','3801','3810','4301','4302','4303') then order_no else null end) as dry_and_fast_food_1 --干货速食
,count(distinct case when sku_division_code in ('2506','3802','3803','3804','3805','3806','3807','3808','3809','3811','3812','3813','7938') then order_no else null end) as grain_and_oil_seasoning_1 --粮油调味
,count(distinct case when sku_division_code in ('1401','1403','1404','1405','1406','1407','1408','1409','1411','1412','1413','1414','1415','1416','1418','2201','2202','2203','2204','2205',
'2206','2207','2208','2209','2210','2211','2213','2301','2302','2303','2304','2305','2306','2307','2309','2310','2311','2312','2313','2314','2316','2401','2402','2403','2404',
'2406','2407','0801','0802','0805') then order_no else null end) as meat_eggs_fruits_and_vegetables_1 --肉蛋果蔬
,count(distinct case when sku_division_code in ('1201','1202','1203','1204','1208','3308','7912') then order_no else null end) as milk_drink_1 --乳饮
,count(distinct case when sku_division_code in ('0201','0202') then order_no else null end) as sandwich_burger_1 --三明治汉堡
,count(distinct case when sku_division_code in ('3409','3901','3904','3907','3909','3910','3911','6201','7201','7203','7209','7210','7211','7934','7972') then order_no else null end) as special_merchandise_1 --特设商品
,count(distinct case when sku_division_code in ('1101','1102','1103','1104','1105','1210','0204') then order_no else null end) as dessert_fast_food_and_other_1 --甜品及其他
,count(distinct case when sku_division_code in ('2702','2703','4408','5001','5002','7504','8201','8202','8203','8204','8205','8206','8207','8208','8209','8210','8211','8212','8215','8216',
'8217','8218','8220','8222','8223','8224','8225','8226','8401','8601','8602','8603','8604','8605','8606','8607','8608','8701','8702','8703','8704','8705','8706','9101','9102',
'9103','9104','9105','9106','9107','9108','9109','9110','9112','9113','9114','9115','9118','9201','9203','9204','9205','9206','9207','9208','9209','9210','9211','9212','9218',
'9301','9302','9303','9304','9305','9306','9307','9308','9310','9311','9312','9314','9315','9316','9317','9318','9319','9320','9321','9399','9401','9402','9403','9404','9405',
'9601','9602','9603','9604','9605','9606','9607','9701','9702','9703','9704','9705','9706','9707','9708','9709','9710','9711','9712','9713','9714','9715','9716','9717','9801',
'9802','9803','9804','9805','9806','9807','9808','9809','9810','9812','9816','9818','9821','9822','9901','0307','0308','0311','0315','0316','0804','0901','0902','0904','0905',
'0906') then order_no else null end) as unconventional_sales_items_1 --非常规卖品
,count(distinct case when sku_division_code not in ('0501','0502','0503','0505','0508','0301','0304','0602','0302','1501','1502','1503','1504','1505','1506','1507','1508','0303','0309',
'0310','0312','0313','0314','0601','0603','0604','0103','0105','0106','0401','0402','3604','4201','4202','4203','4204','4205','7942','3405','3406','3407','3408','4401','4402',
'0101','0102','2702','2703','4408','5001','5002','7504','8201','8202','8203','8204','8205','8206','8207','8208','8209','8210','8211','8212','8215','8216','8217','8218','8220',
'8222','8223','8224','8225','8226','8401','8601','8602','8603','8604','8605','8606','8607','8608','8701','8702','8703','8704','8705','8706','9101','9102','9103','9104','9105','9106',
'9107','9108','9109','9110','9112','9113','9114','9115','9118','9201','9203','9204','9205','9206','9207','9208','9209','9210','9211','9212','9218','9301','9302','9303','9304','9305',
'9306','9307','9308','9310','9311','9312','9314','9315','9316','9317','9318','9319','9320','9321','9399','9401','9402','9403','9404','9405','9601','9602','9603','9604','9605','9606',
'9607','9701','9702','9703','9704','9705','9706','9707','9708','9709','9710','9711','9712','9713','9714','9715','9716','9717','9801','9802','9803','9804','9805','9806','9807','9808',
'9809','9810','9812','9816','9818','9821','9822','9901','0307','0308','0311','0315','0316','0804','0901','0902','0904','0905','0906','2501','2502','3602','4405','7936','1001','1004',
'1209','1301','1302','1303','1304','1305','1306','1307','1402','1410','2212','2308','2503','2505','2601','2603','2604','2605','2606','2607','2608','3801','3810','4301','4302','4303',
'2504','3603','4001','4002','4003','4004','4005','4006','4007','4008','7940','2506','3802','3803','3804','3805','3806','3807','3808','3809','3811','3812','3813','7938','3101','3102',
'3103','3104','3105','3201','3202','3205','7931','7932','2101','2102','2103','2104','2105','2106','2107','2108','2109','3404','3310','1401','1403','1404','1405','1406','1407','1408',
'1409','1411','1412','1413','1414','1415','1416','1418','2201','2202','2203','2204','2205','2206','2207','2208','2209','2210','2211','2213','2301','2302','2303','2304','2305','2306',
'2307','2309','2310','2311','2312','2313','2314','2316','2401','2402','2403','2404','2406','2407','0801','0802','0805','3701','3702','3703','4406','7937','1201','1202','1203','1204',
'1208','3308','7912','0201','0202','2701','4009','6401','6402','6403','6404','6406','6407','6408','6501','6502','6503','6504','6601','6602','6701','6702','6703','6801','6802','6803',
'6804','6805','6806','7001','7002','7003','7004','7005','7006','7007','7008','7101','7103','7104','7105','7106','7107','7301','7302','7303','7701','7801','7802','7964','7965','7966',
'7967','7968','7970','7971','7973','7978','7985','7988','7989','8501','8502','8503','8801','8802','8804','8902','4101','4102','4103','4104','4105','4106','4407','7941','1205','1206',
'1207','3001','3002','3003','3301','3302','3303','3304','3305','3306','3307','3309','7930','7933','3401','3402','3403','4403','3409','3901','3904','3907','3909','3910','3911','6201',
'7201','7203','7209','7210','7211','7934','7972','1101','1102','1103','1104','1105','1210','0204','6101','6102','6103','3501','3502','3503','3601','4404','7935','5003','5004','5005',
'5006','5007','5008','5009','5010','5019','5020','0702','0706','0713','0715','0716','0717','0718','0719','0720','0721') then order_no else null end) as no_attribution_1 --无归属
 
from 
data_build.dw_order_sku_promotion_v1 t --订单明细表
--data_or.dm_copy_dw_order_sku_promotion_v1_view t
left join day_list t1 on t.order_date = t1.date_key
where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and store_type = '0'
and pay_status = 'PAY_SUCCESS'
--and store_code = '100078005'
and t.sku_class_code not in ('86','50')
and order_date between '2023-09-01' and '2023-09-30'
group by
trunc(t.order_date,'MM')
,t.store_code
,store_city
,t1.is_working_day) x
) a
LATERAL VIEW EXPLODE(a.tmp_column_1) exptbl as bool_order,val_order
),

full_list_wonw as(
select
record_week
,store_code
,store_city
,sale_days
,is_working_day
,bool_order
,val_order
,val_order/sale_days as val_order_day
from(
select
x.record_week
,x.store_code
,x.store_city
,x.sale_days
,x.is_working_day
,MAP('日商',order_num_1,'槟榔',x.betel_nut_1,'冰淇淋',x.ice_cream_1,'饼干',x.cookie_1,'干果',x.dried_fruit_1,'果脯',x.preserved_fruit_1,'加工食品',x.processed_food_1,'饮品站/饮品机',x.coffee_soybean_milk_self_service_drink_1,
'烈酒',x.spirits_1,'面包',x.bread_1,'FF萌煮',x.cute_boiling_1,'巧克力',x.chocolate_1,'FF热餐',x.hot_meal_1,'FF早餐酥饼',x.flaky_pastry_1,'肉脯',x.portly_or_obese_person_1,'生活杂货',x.daily_necessities_1,
'嗜好品',x.asaddictive_things_1,'FF炸烤制品',x.fried_baked_goods_1,'水饮',x.retained_fluid_1,'糖果',x.candy_1,'香烟',x.cigarette_1,'休闲食品',x.snack_food_1,'FF蒸包小吃',x.steamed_bun_snacks_1,'热饮料',x.hot_drinks_1
,'便当面条',x.bento_noodles_1,'饭团寿司',x.rice_and_sushi_1,'干货速食',x.dry_and_fast_food_1,'粮油调味',x.grain_and_oil_seasoning_1,'肉蛋果蔬',x.meat_eggs_fruits_and_vegetables_1,'乳饮',x.milk_drink_1,
'三明治汉堡',x.sandwich_burger_1,'特设商品',x.special_merchandise_1,'甜品及其他',x.dessert_fast_food_and_other_1,'非常规卖品',x.unconventional_sales_items_1,'无归属',x.no_attribution_1) AS tmp_column_1
FROM(
select
date_add(t.order_date,7 - case when dayofweek(t.order_date) = 1 then 7 else dayofweek(t.order_date) - 1 end) as record_week
,t.store_code
,t.store_city
,t1.is_working_day

--营业日
,count(distinct order_date) as sale_days

--全部单量
,count(distinct order_no) as order_num_1

--单量 按照商品拆分
,count(distinct case when sku_division_code in ('3604') then order_no else null end) as betel_nut_1
,count(distinct case when sku_division_code in ('4201','4202','4203','4204','4205','7942') then order_no else null end) as ice_cream_1
,count(distinct case when sku_division_code in ('3408','3407','3405','3406','4401','4402') then order_no else null end) as cookie_1
,count(distinct case when sku_division_code in ('2501','2502','3602','4405','7936') then order_no else null end) as dried_fruit_1
,count(distinct case when sku_division_code in ('2504','3603') then order_no else null end) as preserved_fruit_1
,count(distinct case when sku_division_code in ('4001','4002','4003','4004','4005','4006','4007','4008','7940') then order_no else null end) as processed_food_1
,count(distinct case when sku_division_code in ('5003','5004','5005','5006','5007','5008','5009','5010','5019','5020','0702','0706','0713','0715','0716','0717','0718',
'0719','0720','0721') then order_no else null end) as coffee_soybean_milk_self_service_drink_1
,count(distinct case when sku_division_code in ('3101','3102','3103','3104','3105','3201','3202','3205','7931','7932') then order_no else null end) as spirits_1
,count(distinct case when sku_division_code in ('2101','2102','2103','2104','2105','2106','2107','2108','2109') then order_no else null end) as bread_1
,count(distinct case when sku_division_code in ('0501','0502','0503','0505','0508') then order_no else null end) as cute_boiling_1
,count(distinct case when sku_division_code in ('3404') then order_no else null end) as chocolate_1
,count(distinct case when sku_division_code in ('0301','0304') then order_no else null end) as hot_meal_1
,count(distinct case when sku_division_code in ('0602') then order_no else null end) as flaky_pastry_1
,count(distinct case when sku_division_code in ('3701','3702','3703','4406','7937') then order_no else null end) as portly_or_obese_person_1
,count(distinct case when sku_division_code in ('2701','4009','6401','6402','6403','6404','6406','6407','6408','6501','6502','6503','6504','6601','6602','6701','6702','6703','6801',
'6802','6803','6804','6805','6806','7001','7002','7003','7004','7005','7006','7007','7008','7101','7103','7104','7105','7106','7107','7301','7302','7303','7701','7801',
'7802','7964','7965','7966','7967','7968','7970','7971','7973','7978','7985','7988','7989','8501','8502','8503','8801','8802','8804','8902') then order_no else null end) as daily_necessities_1
,count(distinct case when sku_division_code in ('4101','4102','4103','4104','4105','4106','4407','7941') then order_no else null end) asaddictive_things_1
,count(distinct case when sku_division_code in ('0302') then order_no else null end) as fried_baked_goods_1
,count(distinct case when sku_division_code in ('1205','1206','1207','3001','3002','3003','3301','3302','3303','3304','3305','3306','3307','3309','7930','7933') then order_no else null end) as retained_fluid_1
,count(distinct case when sku_division_code in ('3401','3402','3403','4403') then order_no else null end) as candy_1
,count(distinct case when sku_division_code in ('6101','6102','6103') then order_no else null end) as cigarette_1
,count(distinct case when sku_division_code in ('3501','3502','3503','3601','4404','7935') then order_no else null end) as snack_food_1
,count(distinct case when sku_division_code in ('1501','1502','1503','1504','1505','1506','1507','1508','0303','0309','0310','0312','0313','0314','0601','0603','0604') then order_no else null end) as steamed_bun_snacks_1
,count(distinct case when sku_division_code in ('3310') then order_no else null end) as hot_drinks_1
,count(distinct case when sku_division_code in ('0103','0105','0106','0401','0402') then order_no else null end) as bento_noodles_1
,count(distinct case when sku_division_code in ('0101','0102') then order_no else null end) as rice_and_sushi_1 --饭团寿司
,count(distinct case when sku_division_code in ('1001','1004','1209','1301','1302','1303','1304','1305','1306','1307','1402','1410','2212','2308','2503','2505','2601','2603','2604','2605',
'2606','2607','2608','3801','3810','4301','4302','4303') then order_no else null end) as dry_and_fast_food_1 --干货速食
,count(distinct case when sku_division_code in ('2506','3802','3803','3804','3805','3806','3807','3808','3809','3811','3812','3813','7938') then order_no else null end) as grain_and_oil_seasoning_1 --粮油调味
,count(distinct case when sku_division_code in ('1401','1403','1404','1405','1406','1407','1408','1409','1411','1412','1413','1414','1415','1416','1418','2201','2202','2203','2204','2205',
'2206','2207','2208','2209','2210','2211','2213','2301','2302','2303','2304','2305','2306','2307','2309','2310','2311','2312','2313','2314','2316','2401','2402','2403','2404',
'2406','2407','0801','0802','0805') then order_no else null end) as meat_eggs_fruits_and_vegetables_1 --肉蛋果蔬
,count(distinct case when sku_division_code in ('1201','1202','1203','1204','1208','3308','7912') then order_no else null end) as milk_drink_1 --乳饮
,count(distinct case when sku_division_code in ('0201','0202') then order_no else null end) as sandwich_burger_1 --三明治汉堡
,count(distinct case when sku_division_code in ('3409','3901','3904','3907','3909','3910','3911','6201','7201','7203','7209','7210','7211','7934','7972') then order_no else null end) as special_merchandise_1 --特设商品
,count(distinct case when sku_division_code in ('1101','1102','1103','1104','1105','1210','0204') then order_no else null end) as dessert_fast_food_and_other_1 --甜品及其他
,count(distinct case when sku_division_code in ('2702','2703','4408','5001','5002','7504','8201','8202','8203','8204','8205','8206','8207','8208','8209','8210','8211','8212','8215','8216',
'8217','8218','8220','8222','8223','8224','8225','8226','8401','8601','8602','8603','8604','8605','8606','8607','8608','8701','8702','8703','8704','8705','8706','9101','9102',
'9103','9104','9105','9106','9107','9108','9109','9110','9112','9113','9114','9115','9118','9201','9203','9204','9205','9206','9207','9208','9209','9210','9211','9212','9218',
'9301','9302','9303','9304','9305','9306','9307','9308','9310','9311','9312','9314','9315','9316','9317','9318','9319','9320','9321','9399','9401','9402','9403','9404','9405',
'9601','9602','9603','9604','9605','9606','9607','9701','9702','9703','9704','9705','9706','9707','9708','9709','9710','9711','9712','9713','9714','9715','9716','9717','9801',
'9802','9803','9804','9805','9806','9807','9808','9809','9810','9812','9816','9818','9821','9822','9901','0307','0308','0311','0315','0316','0804','0901','0902','0904','0905',
'0906') then order_no else null end) as unconventional_sales_items_1 --非常规卖品
,count(distinct case when sku_division_code not in ('0501','0502','0503','0505','0508','0301','0304','0602','0302','1501','1502','1503','1504','1505','1506','1507','1508','0303','0309',
'0310','0312','0313','0314','0601','0603','0604','0103','0105','0106','0401','0402','3604','4201','4202','4203','4204','4205','7942','3405','3406','3407','3408','4401','4402',
'0101','0102','2702','2703','4408','5001','5002','7504','8201','8202','8203','8204','8205','8206','8207','8208','8209','8210','8211','8212','8215','8216','8217','8218','8220',
'8222','8223','8224','8225','8226','8401','8601','8602','8603','8604','8605','8606','8607','8608','8701','8702','8703','8704','8705','8706','9101','9102','9103','9104','9105','9106',
'9107','9108','9109','9110','9112','9113','9114','9115','9118','9201','9203','9204','9205','9206','9207','9208','9209','9210','9211','9212','9218','9301','9302','9303','9304','9305',
'9306','9307','9308','9310','9311','9312','9314','9315','9316','9317','9318','9319','9320','9321','9399','9401','9402','9403','9404','9405','9601','9602','9603','9604','9605','9606',
'9607','9701','9702','9703','9704','9705','9706','9707','9708','9709','9710','9711','9712','9713','9714','9715','9716','9717','9801','9802','9803','9804','9805','9806','9807','9808',
'9809','9810','9812','9816','9818','9821','9822','9901','0307','0308','0311','0315','0316','0804','0901','0902','0904','0905','0906','2501','2502','3602','4405','7936','1001','1004',
'1209','1301','1302','1303','1304','1305','1306','1307','1402','1410','2212','2308','2503','2505','2601','2603','2604','2605','2606','2607','2608','3801','3810','4301','4302','4303',
'2504','3603','4001','4002','4003','4004','4005','4006','4007','4008','7940','2506','3802','3803','3804','3805','3806','3807','3808','3809','3811','3812','3813','7938','3101','3102',
'3103','3104','3105','3201','3202','3205','7931','7932','2101','2102','2103','2104','2105','2106','2107','2108','2109','3404','3310','1401','1403','1404','1405','1406','1407','1408',
'1409','1411','1412','1413','1414','1415','1416','1418','2201','2202','2203','2204','2205','2206','2207','2208','2209','2210','2211','2213','2301','2302','2303','2304','2305','2306',
'2307','2309','2310','2311','2312','2313','2314','2316','2401','2402','2403','2404','2406','2407','0801','0802','0805','3701','3702','3703','4406','7937','1201','1202','1203','1204',
'1208','3308','7912','0201','0202','2701','4009','6401','6402','6403','6404','6406','6407','6408','6501','6502','6503','6504','6601','6602','6701','6702','6703','6801','6802','6803',
'6804','6805','6806','7001','7002','7003','7004','7005','7006','7007','7008','7101','7103','7104','7105','7106','7107','7301','7302','7303','7701','7801','7802','7964','7965','7966',
'7967','7968','7970','7971','7973','7978','7985','7988','7989','8501','8502','8503','8801','8802','8804','8902','4101','4102','4103','4104','4105','4106','4407','7941','1205','1206',
'1207','3001','3002','3003','3301','3302','3303','3304','3305','3306','3307','3309','7930','7933','3401','3402','3403','4403','3409','3901','3904','3907','3909','3910','3911','6201',
'7201','7203','7209','7210','7211','7934','7972','1101','1102','1103','1104','1105','1210','0204','6101','6102','6103','3501','3502','3503','3601','4404','7935','5003','5004','5005',
'5006','5007','5008','5009','5010','5019','5020','0702','0706','0713','0715','0716','0717','0718','0719','0720','0721') then order_no else null end) as no_attribution_1 --无归属
 
from 
data_build.dw_order_sku_promotion_v1 t --订单明细表
--data_or.dm_copy_dw_order_sku_promotion_v1_view t
left join day_list t1 on t.order_date = t1.date_key
where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and store_type = '0'
and pay_status = 'PAY_SUCCESS'
--and store_code = '100078005'
and t.sku_class_code not in ('86','50')
and order_date between '2023-08-28' and date_format(date_sub(current_date(),1),'yyyy-MM-dd')
group by
date_add(t.order_date,7 - case when dayofweek(t.order_date) = 1 then 7 else dayofweek(t.order_date) - 1 end)
,t.store_code
,store_city
,t1.is_working_day) x
) a
LATERAL VIEW EXPLODE(a.tmp_column_1) exptbl as bool_order,val_order
)

select
t.record_week
,t.store_code
,t.store_city
,t.bool_order
,t.val_order
,t1.val_order as nine_val_order
,'全周' as is_working_day
,t.val_order_day
,t1.val_order_day as al_order_day --9月日均
from full_list t
left join nine_list t1 on t.store_code = t1.store_code and t.bool_order = t1.bool_order

union all

select
t.record_week
,t.store_code
,t.store_city
,t.bool_order
,t.val_order
,t1.val_order as nine_val_order
,cast(t.is_working_day as string) as is_working_day
,t.val_order_day
,t1.val_order_day as al_order_day --9月日均
from full_list_wonw t
left join nine_list_wonw t1 on t.store_code = t1.store_code and t.bool_order = t1.bool_order and t.is_working_day = t1.is_working_day