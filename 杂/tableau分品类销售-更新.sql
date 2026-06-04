--tableau表分品类销售（data_build.app_app_sale_by_category_v1_da）--线下跑的数据
with database_table as(
select
t.store_code
,t.store_city

--营业日
,count(distinct order_date) as sale_days

--折后销售额
,sum(payable_price) as payable_price --全部销售额

--折后销售额 按照商品拆分
,sum(case when sku_division_code in ('3604') then payable_price else 0 end) as betel_nut
,sum(case when sku_division_code in ('4201','4202','4203','4204','4205','7942') then payable_price else 0 end) as ice_cream
,sum(case when sku_division_code in ('3408','3407','3405','3406','4401','4402') then payable_price else 0 end) as cookie
,sum(case when sku_division_code in ('2501','2502','3602','4405','7936') then payable_price else 0 end) as dried_fruit
,sum(case when sku_division_code in ('2504','3603') then payable_price else 0 end) as preserved_fruit
,sum(case when sku_division_code in ('4001','4002','4003','4004','4005','4006','4007','4008','7940') then payable_price else 0 end) as processed_food
,sum(case when sku_division_code in ('5003','5004','5005','5006','5007','5008','5009','5010','5019','5020','0702','0706','0713','0715','0716','0717','0718',
'0719','0720','0721') then payable_price else 0 end) as coffee_soybean_milk_self_service_drink
,sum(case when sku_division_code in ('3101','3102','3103','3104','3105','3201','3202','3205','7931','7932') then payable_price else 0 end) as spirits
,sum(case when sku_division_code in ('2101','2102','2103','2104','2105','2106','2107','2108','2109') then payable_price else 0 end) as bread
,sum(case when sku_division_code in ('0501','0502','0503','0505','0508') then payable_price else 0 end) as cute_boiling
,sum(case when sku_division_code in ('3404') then payable_price else 0 end) as chocolate
,sum(case when sku_division_code in ('0301','0304') then payable_price else 0 end) as hot_meal
,sum(case when sku_division_code in ('0602') then payable_price else 0 end) as flaky_pastry
,sum(case when sku_division_code in ('3701','3702','3703','4406','7937') then payable_price else 0 end) as portly_or_obese_person
,sum(case when sku_division_code in ('2701','4009','6401','6402','6403','6404','6406','6407','6408','6501','6502','6503','6504','6601','6602','6701','6702','6703','6801',
'6802','6803','6804','6805','6806','7001','7002','7003','7004','7005','7006','7007','7008','7101','7103','7104','7105','7106','7107','7301','7302','7303','7701','7801',
'7802','7964','7965','7966','7967','7968','7970','7971','7973','7978','7985','7988','7989','8501','8502','8503','8801','8802','8804','8902') then payable_price else 0 end) as daily_necessities
,sum(case when sku_division_code in ('4101','4102','4103','4104','4105','4106','4407','7941') then payable_price else 0 end) asaddictive_things
,sum(case when sku_division_code in ('0302') then payable_price else 0 end) as fried_baked_goods
,sum(case when sku_division_code in ('1205','1206','1207','3001','3002','3003','3301','3302','3303','3304','3305','3306','3307','3309','7930','7933') then payable_price else 0 end) as retained_fluid
,sum(case when sku_division_code in ('3401','3402','3403','4403') then payable_price else 0 end) as candy
,sum(case when sku_division_code in ('6101','6102','6103') then payable_price else 0 end) as cigarette
,sum(case when sku_division_code in ('3501','3502','3503','3601','4404','7935') then payable_price else 0 end) as snack_food
,sum(case when sku_division_code in ('1501','1502','1503','1504','1505','1506','1507','1508','0303','0309','0310','0312','0313','0314','0601','0603','0604') then payable_price else 0 end) as steamed_bun_snacks
,sum(case when sku_division_code in ('3310') then payable_price else 0 end) as hot_drinks
,sum(case when sku_division_code in ('0103','0105','0106','0401','0402') then payable_price else 0 end) as bento_noodles
,sum(case when sku_division_code in ('0101','0102') then payable_price else 0 end) as rice_and_sushi --饭团寿司
,sum(case when sku_division_code in ('1001','1004','1209','1301','1302','1303','1304','1305','1306','1307','1402','1410','2212','2308','2503','2505','2601','2603','2604','2605',
'2606','2607','2608','3801','3810','4301','4302','4303') then payable_price else 0 end) as dry_and_fast_food --干货速食
,sum(case when sku_division_code in ('2506','3802','3803','3804','3805','3806','3807','3808','3809','3811','3812','3813','7938') then payable_price else 0 end) as grain_and_oil_seasoning --粮油调味
,sum(case when sku_division_code in ('1401','1403','1404','1405','1406','1407','1408','1409','1411','1412','1413','1414','1415','1416','1418','2201','2202','2203','2204','2205',
'2206','2207','2208','2209','2210','2211','2213','2301','2302','2303','2304','2305','2306','2307','2309','2310','2311','2312','2313','2314','2316','2401','2402','2403','2404',
'2406','2407','0801','0802','0805') then payable_price else 0 end) as meat_eggs_fruits_and_vegetables --肉蛋果蔬
,sum(case when sku_division_code in ('1201','1202','1203','1204','1208','3308','7912') then payable_price else 0 end) as milk_drink --乳饮
,sum(case when sku_division_code in ('0201','0202') then payable_price else 0 end) as sandwich_burger --三明治汉堡
,sum(case when sku_division_code in ('3409','3901','3904','3907','3909','3910','3911','6201','7201','7203','7209','7210','7211','7934','7972') then payable_price else 0 end) as special_merchandise --特设商品
,sum(case when sku_division_code in ('1101','1102','1103','1104','1105','1210','0204') then payable_price else 0 end) as dessert_fast_food_and_other --甜品及其他
,sum(case when sku_division_code in ('2702','2703','4408','5001','5002','7504','8201','8202','8203','8204','8205','8206','8207','8208','8209','8210','8211','8212','8215','8216',
'8217','8218','8220','8222','8223','8224','8225','8226','8401','8601','8602','8603','8604','8605','8606','8607','8608','8701','8702','8703','8704','8705','8706','9101','9102',
'9103','9104','9105','9106','9107','9108','9109','9110','9112','9113','9114','9115','9118','9201','9203','9204','9205','9206','9207','9208','9209','9210','9211','9212','9218',
'9301','9302','9303','9304','9305','9306','9307','9308','9310','9311','9312','9314','9315','9316','9317','9318','9319','9320','9321','9399','9401','9402','9403','9404','9405',
'9601','9602','9603','9604','9605','9606','9607','9701','9702','9703','9704','9705','9706','9707','9708','9709','9710','9711','9712','9713','9714','9715','9716','9717','9801',
'9802','9803','9804','9805','9806','9807','9808','9809','9810','9812','9816','9818','9821','9822','9901','0307','0308','0311','0315','0316','0804','0901','0902','0904','0905',
'0906') then payable_price else 0 end) as unconventional_sales_items --非常规卖品
,sum(case when sku_division_code not in ('0501','0502','0503','0505','0508','0301','0304','0602','0302','1501','1502','1503','1504','1505','1506','1507','1508','0303','0309',
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
'5006','5007','5008','5009','5010','5019','5020','0702','0706','0713','0715','0716','0717','0718','0719','0720','0721') then payable_price else 0 end) as no_attribution --无归属

 
from 
data_build.dw_order_sku_promotion_v1 t --订单明细表
--data_or.dm_copy_dw_order_sku_promotion_v1_view t
where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and store_type = '0'
and pay_status = 'PAY_SUCCESS'
--and store_code = '100078005'
and t.sku_class_code not in ('86','50')
and order_date between '2024-01-01' and '2024-01-28'
group by
t.store_code
,store_city
),

nine_month_large_market as(
select
record_month
,store_code
,store_city
,sale_days
,bool
,val
,val/sale_days as val_day
from(
select
x.record_month
,x.store_code
,x.store_city
,x.sale_days
,MAP('日商',x.payable_price,'槟榔',x.betel_nut,'冰淇淋',x.ice_cream,'饼干',x.cookie,'干果',x.dried_fruit,'果脯',x.preserved_fruit,'加工食品',x.processed_food,'饮品站/饮品机',x.coffee_soybean_milk_self_service_drink,
'烈酒',x.spirits,'面包',x.bread,'FF萌煮',x.cute_boiling,'巧克力',x.chocolate,'FF热餐',x.hot_meal,'FF早餐酥饼',x.flaky_pastry,'肉脯',x.portly_or_obese_person,'生活杂货',x.daily_necessities,
'嗜好品',x.asaddictive_things,'FF炸烤制品',x.fried_baked_goods,'水饮',x.retained_fluid,'糖果',x.candy,'香烟',x.cigarette,'休闲食品',x.snack_food,'FF蒸包小吃',x.steamed_bun_snacks,'热饮料',x.hot_drinks
,'便当面条',x.bento_noodles,'饭团寿司',x.rice_and_sushi,'干货速食',x.dry_and_fast_food,'粮油调味',x.grain_and_oil_seasoning,'肉蛋果蔬',x.meat_eggs_fruits_and_vegetables,'乳饮',x.milk_drink,
'三明治汉堡',x.sandwich_burger,'特设商品',x.special_merchandise,'甜品及其他',x.dessert_fast_food_and_other,'非常规卖品',x.unconventional_sales_items,'无归属',x.no_attribution) AS tmp_column
FROM(
select
trunc(t.order_date,'MM') as record_month
,t.store_code
,t.store_city

--营业日
,count(distinct order_date) as sale_days

--折后销售额
,sum(payable_price) as payable_price --全部销售额

--折后销售额 按照商品拆分
,sum(case when sku_division_code in ('3604') then payable_price else 0 end) as betel_nut
,sum(case when sku_division_code in ('4201','4202','4203','4204','4205','7942') then payable_price else 0 end) as ice_cream
,sum(case when sku_division_code in ('3408','3407','3405','3406','4401','4402') then payable_price else 0 end) as cookie
,sum(case when sku_division_code in ('2501','2502','3602','4405','7936') then payable_price else 0 end) as dried_fruit
,sum(case when sku_division_code in ('2504','3603') then payable_price else 0 end) as preserved_fruit
,sum(case when sku_division_code in ('4001','4002','4003','4004','4005','4006','4007','4008','7940') then payable_price else 0 end) as processed_food
,sum(case when sku_division_code in ('5003','5004','5005','5006','5007','5008','5009','5010','5019','5020','0702','0706','0713','0715','0716','0717','0718',
'0719','0720','0721') then payable_price else 0 end) as coffee_soybean_milk_self_service_drink
,sum(case when sku_division_code in ('3101','3102','3103','3104','3105','3201','3202','3205','7931','7932') then payable_price else 0 end) as spirits
,sum(case when sku_division_code in ('2101','2102','2103','2104','2105','2106','2107','2108','2109') then payable_price else 0 end) as bread
,sum(case when sku_division_code in ('0501','0502','0503','0505','0508') then payable_price else 0 end) as cute_boiling
,sum(case when sku_division_code in ('3404') then payable_price else 0 end) as chocolate
,sum(case when sku_division_code in ('0301','0304') then payable_price else 0 end) as hot_meal
,sum(case when sku_division_code in ('0602') then payable_price else 0 end) as flaky_pastry
,sum(case when sku_division_code in ('3701','3702','3703','4406','7937') then payable_price else 0 end) as portly_or_obese_person
,sum(case when sku_division_code in ('2701','4009','6401','6402','6403','6404','6406','6407','6408','6501','6502','6503','6504','6601','6602','6701','6702','6703','6801',
'6802','6803','6804','6805','6806','7001','7002','7003','7004','7005','7006','7007','7008','7101','7103','7104','7105','7106','7107','7301','7302','7303','7701','7801',
'7802','7964','7965','7966','7967','7968','7970','7971','7973','7978','7985','7988','7989','8501','8502','8503','8801','8802','8804','8902') then payable_price else 0 end) as daily_necessities
,sum(case when sku_division_code in ('4101','4102','4103','4104','4105','4106','4407','7941') then payable_price else 0 end) asaddictive_things
,sum(case when sku_division_code in ('0302') then payable_price else 0 end) as fried_baked_goods
,sum(case when sku_division_code in ('1205','1206','1207','3001','3002','3003','3301','3302','3303','3304','3305','3306','3307','3309','7930','7933') then payable_price else 0 end) as retained_fluid
,sum(case when sku_division_code in ('3401','3402','3403','4403') then payable_price else 0 end) as candy
,sum(case when sku_division_code in ('6101','6102','6103') then payable_price else 0 end) as cigarette
,sum(case when sku_division_code in ('3501','3502','3503','3601','4404','7935') then payable_price else 0 end) as snack_food
,sum(case when sku_division_code in ('1501','1502','1503','1504','1505','1506','1507','1508','0303','0309','0310','0312','0313','0314','0601','0603','0604') then payable_price else 0 end) as steamed_bun_snacks
,sum(case when sku_division_code in ('3310') then payable_price else 0 end) as hot_drinks
,sum(case when sku_division_code in ('0103','0105','0106','0401','0402') then payable_price else 0 end) as bento_noodles
,sum(case when sku_division_code in ('0101','0102') then payable_price else 0 end) as rice_and_sushi --饭团寿司
,sum(case when sku_division_code in ('1001','1004','1209','1301','1302','1303','1304','1305','1306','1307','1402','1410','2212','2308','2503','2505','2601','2603','2604','2605',
'2606','2607','2608','3801','3810','4301','4302','4303') then payable_price else 0 end) as dry_and_fast_food --干货速食
,sum(case when sku_division_code in ('2506','3802','3803','3804','3805','3806','3807','3808','3809','3811','3812','3813','7938') then payable_price else 0 end) as grain_and_oil_seasoning --粮油调味
,sum(case when sku_division_code in ('1401','1403','1404','1405','1406','1407','1408','1409','1411','1412','1413','1414','1415','1416','1418','2201','2202','2203','2204','2205',
'2206','2207','2208','2209','2210','2211','2213','2301','2302','2303','2304','2305','2306','2307','2309','2310','2311','2312','2313','2314','2316','2401','2402','2403','2404',
'2406','2407','0801','0802','0805') then payable_price else 0 end) as meat_eggs_fruits_and_vegetables --肉蛋果蔬
,sum(case when sku_division_code in ('1201','1202','1203','1204','1208','3308','7912') then payable_price else 0 end) as milk_drink --乳饮
,sum(case when sku_division_code in ('0201','0202') then payable_price else 0 end) as sandwich_burger --三明治汉堡
,sum(case when sku_division_code in ('3409','3901','3904','3907','3909','3910','3911','6201','7201','7203','7209','7210','7211','7934','7972') then payable_price else 0 end) as special_merchandise --特设商品
,sum(case when sku_division_code in ('1101','1102','1103','1104','1105','1210','0204') then payable_price else 0 end) as dessert_fast_food_and_other --甜品及其他
,sum(case when sku_division_code in ('2702','2703','4408','5001','5002','7504','8201','8202','8203','8204','8205','8206','8207','8208','8209','8210','8211','8212','8215','8216',
'8217','8218','8220','8222','8223','8224','8225','8226','8401','8601','8602','8603','8604','8605','8606','8607','8608','8701','8702','8703','8704','8705','8706','9101','9102',
'9103','9104','9105','9106','9107','9108','9109','9110','9112','9113','9114','9115','9118','9201','9203','9204','9205','9206','9207','9208','9209','9210','9211','9212','9218',
'9301','9302','9303','9304','9305','9306','9307','9308','9310','9311','9312','9314','9315','9316','9317','9318','9319','9320','9321','9399','9401','9402','9403','9404','9405',
'9601','9602','9603','9604','9605','9606','9607','9701','9702','9703','9704','9705','9706','9707','9708','9709','9710','9711','9712','9713','9714','9715','9716','9717','9801',
'9802','9803','9804','9805','9806','9807','9808','9809','9810','9812','9816','9818','9821','9822','9901','0307','0308','0311','0315','0316','0804','0901','0902','0904','0905',
'0906') then payable_price else 0 end) as unconventional_sales_items --非常规卖品
,sum(case when sku_division_code not in ('0501','0502','0503','0505','0508','0301','0304','0602','0302','1501','1502','1503','1504','1505','1506','1507','1508','0303','0309',
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
'5006','5007','5008','5009','5010','5019','5020','0702','0706','0713','0715','0716','0717','0718','0719','0720','0721') then payable_price else 0 end) as no_attribution --无归属
 
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
LATERAL VIEW EXPLODE(a.tmp_column) exptbl as bool,val
)


select
x.*
,t.val_day as nine_val_day
,case when t.val_day = '0' and x.val_day <> '0' then '100%' else x.val_day/t.val_day end as val_recovery
,t1.location_type
from(
select
store_code
,store_city
,sale_days
,bool
,val
,val/sale_days as val_day
from(
SELECT store_code
      ,store_city
      ,sale_days
           ,MAP('日商',payable_price,'槟榔',betel_nut,'冰淇淋',ice_cream,'饼干',cookie,'干果',dried_fruit,'果脯',preserved_fruit,'加工食品',processed_food,'饮品站/饮品机',coffee_soybean_milk_self_service_drink,
'烈酒',spirits,'面包',bread,'FF萌煮',cute_boiling,'巧克力',chocolate,'FF热餐',hot_meal,'FF早餐酥饼',flaky_pastry,'肉脯',portly_or_obese_person,'生活杂货',daily_necessities,
'嗜好品',asaddictive_things,'FF炸烤制品',fried_baked_goods,'水饮',retained_fluid,'糖果',candy,'香烟',cigarette,'休闲食品',snack_food,'FF蒸包小吃',steamed_bun_snacks,'热饮料',hot_drinks
,'便当面条',bento_noodles,'饭团寿司',rice_and_sushi,'干货速食',dry_and_fast_food,'粮油调味',grain_and_oil_seasoning,'肉蛋果蔬',meat_eggs_fruits_and_vegetables,'乳饮',milk_drink,
'三明治汉堡',sandwich_burger,'特设商品',special_merchandise,'甜品及其他',dessert_fast_food_and_other,'非常规卖品',unconventional_sales_items,'无归属',no_attribution) AS tmp_column
   FROM database_table) x
   LATERAL VIEW EXPLODE(tmp_column) exptbl as bool,val) x
   left join nine_month_large_market t on x.store_code = t.store_code and x.bool = t.bool
   left join data_build.dm_site_selection_project_feature_info_di t1 on x.store_code = t1.store_code and t1.dt = 20221114

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
--tableau表分品类销售（data_build.app_app_sale_by_category_workday_or_notworkday_v1_da）--分工作日/非工作日
with day_list as(
select
date_key
,is_working_day
from data_build.dim_date_ya_v2
),

database_table as(
select
date_add(t.order_date,7 - case when dayofweek(t.order_date) = 1 then 7 else dayofweek(t.order_date) - 1 end) as record_week
,t.store_code
,t.store_city
,is_working_day

--营业日
,count(distinct order_date) as sale_days

--折后销售额
,sum(payable_price) as payable_price --全部销售额

--折后销售额 按照商品拆分
,sum(case when sku_division_code in ('3604') then payable_price else 0 end) as betel_nut
,sum(case when sku_division_code in ('4201','4202','4203','4204','4205','7942') then payable_price else 0 end) as ice_cream
,sum(case when sku_division_code in ('3408','3407','3405','3406','4401','4402') then payable_price else 0 end) as cookie
,sum(case when sku_division_code in ('2501','2502','3602','4405','7936') then payable_price else 0 end) as dried_fruit
,sum(case when sku_division_code in ('2504','3603') then payable_price else 0 end) as preserved_fruit
,sum(case when sku_division_code in ('4001','4002','4003','4004','4005','4006','4007','4008','7940') then payable_price else 0 end) as processed_food
,sum(case when sku_division_code in ('5003','5004','5005','5006','5007','5008','5009','5010','5019','5020','0702','0706','0713','0715','0716','0717','0718',
'0719','0720','0721') then payable_price else 0 end) as coffee_soybean_milk_self_service_drink
,sum(case when sku_division_code in ('3101','3102','3103','3104','3105','3201','3202','3205','7931','7932') then payable_price else 0 end) as spirits
,sum(case when sku_division_code in ('2101','2102','2103','2104','2105','2106','2107','2108','2109') then payable_price else 0 end) as bread
,sum(case when sku_division_code in ('0501','0502','0503','0505','0508') then payable_price else 0 end) as cute_boiling
,sum(case when sku_division_code in ('3404') then payable_price else 0 end) as chocolate
,sum(case when sku_division_code in ('0301','0304') then payable_price else 0 end) as hot_meal
,sum(case when sku_division_code in ('0602') then payable_price else 0 end) as flaky_pastry
,sum(case when sku_division_code in ('3701','3702','3703','4406','7937') then payable_price else 0 end) as portly_or_obese_person
,sum(case when sku_division_code in ('2701','4009','6401','6402','6403','6404','6406','6407','6408','6501','6502','6503','6504','6601','6602','6701','6702','6703','6801',
'6802','6803','6804','6805','6806','7001','7002','7003','7004','7005','7006','7007','7008','7101','7103','7104','7105','7106','7107','7301','7302','7303','7701','7801',
'7802','7964','7965','7966','7967','7968','7970','7971','7973','7978','7985','7988','7989','8501','8502','8503','8801','8802','8804','8902') then payable_price else 0 end) as daily_necessities
,sum(case when sku_division_code in ('4101','4102','4103','4104','4105','4106','4407','7941') then payable_price else 0 end) asaddictive_things
,sum(case when sku_division_code in ('0302') then payable_price else 0 end) as fried_baked_goods
,sum(case when sku_division_code in ('1205','1206','1207','3001','3002','3003','3301','3302','3303','3304','3305','3306','3307','3309','7930','7933') then payable_price else 0 end) as retained_fluid
,sum(case when sku_division_code in ('3401','3402','3403','4403') then payable_price else 0 end) as candy
,sum(case when sku_division_code in ('6101','6102','6103') then payable_price else 0 end) as cigarette
,sum(case when sku_division_code in ('3501','3502','3503','3601','4404','7935') then payable_price else 0 end) as snack_food
,sum(case when sku_division_code in ('1501','1502','1503','1504','1505','1506','1507','1508','0303','0309','0310','0312','0313','0314','0601','0603','0604') then payable_price else 0 end) as steamed_bun_snacks
,sum(case when sku_division_code in ('3310') then payable_price else 0 end) as hot_drinks
,sum(case when sku_division_code in ('0103','0105','0106','0401','0402') then payable_price else 0 end) as bento_noodles
,sum(case when sku_division_code in ('0101','0102') then payable_price else 0 end) as rice_and_sushi --饭团寿司
,sum(case when sku_division_code in ('1001','1004','1209','1301','1302','1303','1304','1305','1306','1307','1402','1410','2212','2308','2503','2505','2601','2603','2604','2605',
'2606','2607','2608','3801','3810','4301','4302','4303') then payable_price else 0 end) as dry_and_fast_food --干货速食
,sum(case when sku_division_code in ('2506','3802','3803','3804','3805','3806','3807','3808','3809','3811','3812','3813','7938') then payable_price else 0 end) as grain_and_oil_seasoning --粮油调味
,sum(case when sku_division_code in ('1401','1403','1404','1405','1406','1407','1408','1409','1411','1412','1413','1414','1415','1416','1418','2201','2202','2203','2204','2205',
'2206','2207','2208','2209','2210','2211','2213','2301','2302','2303','2304','2305','2306','2307','2309','2310','2311','2312','2313','2314','2316','2401','2402','2403','2404',
'2406','2407','0801','0802','0805') then payable_price else 0 end) as meat_eggs_fruits_and_vegetables --肉蛋果蔬
,sum(case when sku_division_code in ('1201','1202','1203','1204','1208','3308','7912') then payable_price else 0 end) as milk_drink --乳饮
,sum(case when sku_division_code in ('0201','0202') then payable_price else 0 end) as sandwich_burger --三明治汉堡
,sum(case when sku_division_code in ('3409','3901','3904','3907','3909','3910','3911','6201','7201','7203','7209','7210','7211','7934','7972') then payable_price else 0 end) as special_merchandise --特设商品
,sum(case when sku_division_code in ('1101','1102','1103','1104','1105','1210','0204') then payable_price else 0 end) as dessert_fast_food_and_other --甜品及其他
,sum(case when sku_division_code in ('2702','2703','4408','5001','5002','7504','8201','8202','8203','8204','8205','8206','8207','8208','8209','8210','8211','8212','8215','8216',
'8217','8218','8220','8222','8223','8224','8225','8226','8401','8601','8602','8603','8604','8605','8606','8607','8608','8701','8702','8703','8704','8705','8706','9101','9102',
'9103','9104','9105','9106','9107','9108','9109','9110','9112','9113','9114','9115','9118','9201','9203','9204','9205','9206','9207','9208','9209','9210','9211','9212','9218',
'9301','9302','9303','9304','9305','9306','9307','9308','9310','9311','9312','9314','9315','9316','9317','9318','9319','9320','9321','9399','9401','9402','9403','9404','9405',
'9601','9602','9603','9604','9605','9606','9607','9701','9702','9703','9704','9705','9706','9707','9708','9709','9710','9711','9712','9713','9714','9715','9716','9717','9801',
'9802','9803','9804','9805','9806','9807','9808','9809','9810','9812','9816','9818','9821','9822','9901','0307','0308','0311','0315','0316','0804','0901','0902','0904','0905',
'0906') then payable_price else 0 end) as unconventional_sales_items --非常规卖品
,sum(case when sku_division_code not in ('0501','0502','0503','0505','0508','0301','0304','0602','0302','1501','1502','1503','1504','1505','1506','1507','1508','0303','0309',
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
'5006','5007','5008','5009','5010','5019','5020','0702','0706','0713','0715','0716','0717','0718','0719','0720','0721') then payable_price else 0 end) as no_attribution --无归属

 
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
,is_working_day
),

nine_month_large_market as(
select
record_month
,store_code
,store_city
,is_working_day
,sale_days
,bool
,val
,val/sale_days as val_day
from(
select
x.record_month
,x.store_code
,x.store_city
,x.is_working_day
,x.sale_days
,MAP('日商',x.payable_price,'槟榔',x.betel_nut,'冰淇淋',x.ice_cream,'饼干',x.cookie,'干果',x.dried_fruit,'果脯',x.preserved_fruit,'加工食品',x.processed_food,'饮品站/饮品机',x.coffee_soybean_milk_self_service_drink,
'烈酒',x.spirits,'面包',x.bread,'FF萌煮',x.cute_boiling,'巧克力',x.chocolate,'FF热餐',x.hot_meal,'FF早餐酥饼',x.flaky_pastry,'肉脯',x.portly_or_obese_person,'生活杂货',x.daily_necessities,
'嗜好品',x.asaddictive_things,'FF炸烤制品',x.fried_baked_goods,'水饮',x.retained_fluid,'糖果',x.candy,'香烟',x.cigarette,'休闲食品',x.snack_food,'FF蒸包小吃',x.steamed_bun_snacks,'热饮料',x.hot_drinks
,'便当面条',x.bento_noodles,'饭团寿司',x.rice_and_sushi,'干货速食',x.dry_and_fast_food,'粮油调味',x.grain_and_oil_seasoning,'肉蛋果蔬',x.meat_eggs_fruits_and_vegetables,'乳饮',x.milk_drink,
'三明治汉堡',x.sandwich_burger,'特设商品',x.special_merchandise,'甜品及其他',x.dessert_fast_food_and_other,'非常规卖品',x.unconventional_sales_items,'无归属',x.no_attribution) AS tmp_column
FROM(
select
trunc(t.order_date,'MM') as record_month
,t.store_code
,t.store_city
,t1.is_working_day

--营业日
,count(distinct order_date) as sale_days

--折后销售额
,sum(payable_price) as payable_price --全部销售额

--折后销售额 按照商品拆分
,sum(case when sku_division_code in ('3604') then payable_price else 0 end) as betel_nut
,sum(case when sku_division_code in ('4201','4202','4203','4204','4205','7942') then payable_price else 0 end) as ice_cream
,sum(case when sku_division_code in ('3408','3407','3405','3406','4401','4402') then payable_price else 0 end) as cookie
,sum(case when sku_division_code in ('2501','2502','3602','4405','7936') then payable_price else 0 end) as dried_fruit
,sum(case when sku_division_code in ('2504','3603') then payable_price else 0 end) as preserved_fruit
,sum(case when sku_division_code in ('4001','4002','4003','4004','4005','4006','4007','4008','7940') then payable_price else 0 end) as processed_food
,sum(case when sku_division_code in ('5003','5004','5005','5006','5007','5008','5009','5010','5019','5020','0702','0706','0713','0715','0716','0717','0718',
'0719','0720','0721') then payable_price else 0 end) as coffee_soybean_milk_self_service_drink
,sum(case when sku_division_code in ('3101','3102','3103','3104','3105','3201','3202','3205','7931','7932') then payable_price else 0 end) as spirits
,sum(case when sku_division_code in ('2101','2102','2103','2104','2105','2106','2107','2108','2109') then payable_price else 0 end) as bread
,sum(case when sku_division_code in ('0501','0502','0503','0505','0508') then payable_price else 0 end) as cute_boiling
,sum(case when sku_division_code in ('3404') then payable_price else 0 end) as chocolate
,sum(case when sku_division_code in ('0301','0304') then payable_price else 0 end) as hot_meal
,sum(case when sku_division_code in ('0602') then payable_price else 0 end) as flaky_pastry
,sum(case when sku_division_code in ('3701','3702','3703','4406','7937') then payable_price else 0 end) as portly_or_obese_person
,sum(case when sku_division_code in ('2701','4009','6401','6402','6403','6404','6406','6407','6408','6501','6502','6503','6504','6601','6602','6701','6702','6703','6801',
'6802','6803','6804','6805','6806','7001','7002','7003','7004','7005','7006','7007','7008','7101','7103','7104','7105','7106','7107','7301','7302','7303','7701','7801',
'7802','7964','7965','7966','7967','7968','7970','7971','7973','7978','7985','7988','7989','8501','8502','8503','8801','8802','8804','8902') then payable_price else 0 end) as daily_necessities
,sum(case when sku_division_code in ('4101','4102','4103','4104','4105','4106','4407','7941') then payable_price else 0 end) asaddictive_things
,sum(case when sku_division_code in ('0302') then payable_price else 0 end) as fried_baked_goods
,sum(case when sku_division_code in ('1205','1206','1207','3001','3002','3003','3301','3302','3303','3304','3305','3306','3307','3309','7930','7933') then payable_price else 0 end) as retained_fluid
,sum(case when sku_division_code in ('3401','3402','3403','4403') then payable_price else 0 end) as candy
,sum(case when sku_division_code in ('6101','6102','6103') then payable_price else 0 end) as cigarette
,sum(case when sku_division_code in ('3501','3502','3503','3601','4404','7935') then payable_price else 0 end) as snack_food
,sum(case when sku_division_code in ('1501','1502','1503','1504','1505','1506','1507','1508','0303','0309','0310','0312','0313','0314','0601','0603','0604') then payable_price else 0 end) as steamed_bun_snacks
,sum(case when sku_division_code in ('3310') then payable_price else 0 end) as hot_drinks
,sum(case when sku_division_code in ('0103','0105','0106','0401','0402') then payable_price else 0 end) as bento_noodles
,sum(case when sku_division_code in ('0101','0102') then payable_price else 0 end) as rice_and_sushi --饭团寿司
,sum(case when sku_division_code in ('1001','1004','1209','1301','1302','1303','1304','1305','1306','1307','1402','1410','2212','2308','2503','2505','2601','2603','2604','2605',
'2606','2607','2608','3801','3810','4301','4302','4303') then payable_price else 0 end) as dry_and_fast_food --干货速食
,sum(case when sku_division_code in ('2506','3802','3803','3804','3805','3806','3807','3808','3809','3811','3812','3813','7938') then payable_price else 0 end) as grain_and_oil_seasoning --粮油调味
,sum(case when sku_division_code in ('1401','1403','1404','1405','1406','1407','1408','1409','1411','1412','1413','1414','1415','1416','1418','2201','2202','2203','2204','2205',
'2206','2207','2208','2209','2210','2211','2213','2301','2302','2303','2304','2305','2306','2307','2309','2310','2311','2312','2313','2314','2316','2401','2402','2403','2404',
'2406','2407','0801','0802','0805') then payable_price else 0 end) as meat_eggs_fruits_and_vegetables --肉蛋果蔬
,sum(case when sku_division_code in ('1201','1202','1203','1204','1208','3308','7912') then payable_price else 0 end) as milk_drink --乳饮
,sum(case when sku_division_code in ('0201','0202') then payable_price else 0 end) as sandwich_burger --三明治汉堡
,sum(case when sku_division_code in ('3409','3901','3904','3907','3909','3910','3911','6201','7201','7203','7209','7210','7211','7934','7972') then payable_price else 0 end) as special_merchandise --特设商品
,sum(case when sku_division_code in ('1101','1102','1103','1104','1105','1210','0204') then payable_price else 0 end) as dessert_fast_food_and_other --甜品及其他
,sum(case when sku_division_code in ('2702','2703','4408','5001','5002','7504','8201','8202','8203','8204','8205','8206','8207','8208','8209','8210','8211','8212','8215','8216',
'8217','8218','8220','8222','8223','8224','8225','8226','8401','8601','8602','8603','8604','8605','8606','8607','8608','8701','8702','8703','8704','8705','8706','9101','9102',
'9103','9104','9105','9106','9107','9108','9109','9110','9112','9113','9114','9115','9118','9201','9203','9204','9205','9206','9207','9208','9209','9210','9211','9212','9218',
'9301','9302','9303','9304','9305','9306','9307','9308','9310','9311','9312','9314','9315','9316','9317','9318','9319','9320','9321','9399','9401','9402','9403','9404','9405',
'9601','9602','9603','9604','9605','9606','9607','9701','9702','9703','9704','9705','9706','9707','9708','9709','9710','9711','9712','9713','9714','9715','9716','9717','9801',
'9802','9803','9804','9805','9806','9807','9808','9809','9810','9812','9816','9818','9821','9822','9901','0307','0308','0311','0315','0316','0804','0901','0902','0904','0905',
'0906') then payable_price else 0 end) as unconventional_sales_items --非常规卖品
,sum(case when sku_division_code not in ('0501','0502','0503','0505','0508','0301','0304','0602','0302','1501','1502','1503','1504','1505','1506','1507','1508','0303','0309',
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
'5006','5007','5008','5009','5010','5019','5020','0702','0706','0713','0715','0716','0717','0718','0719','0720','0721') then payable_price else 0 end) as no_attribution --无归属
 
from 
data_build.dw_order_sku_promotion_v1 t --订单明细表
left join day_list t1 on t.order_date = t1.date_key
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
,store_city
,t1.is_working_day) x
) a
LATERAL VIEW EXPLODE(a.tmp_column) exptbl as bool,val
)


select
x.*
,t.val_day as nine_val_day
,case when t.val_day = '0' and x.val_day <> '0' then '100%' else x.val_day/t.val_day end as val_recovery
,t1.location_type
from(
select
record_week
,store_code
,store_city
,is_working_day
,sale_days
,bool
,val
,val/sale_days as val_day
from(
SELECT record_week
      ,store_code
      ,store_city
      ,is_working_day
      ,sale_days
           ,MAP('日商',payable_price,'槟榔',betel_nut,'冰淇淋',ice_cream,'饼干',cookie,'干果',dried_fruit,'果脯',preserved_fruit,'加工食品',processed_food,'饮品站/饮品机',coffee_soybean_milk_self_service_drink,
'烈酒',spirits,'面包',bread,'FF萌煮',cute_boiling,'巧克力',chocolate,'FF热餐',hot_meal,'FF早餐酥饼',flaky_pastry,'肉脯',portly_or_obese_person,'生活杂货',daily_necessities,
'嗜好品',asaddictive_things,'FF炸烤制品',fried_baked_goods,'水饮',retained_fluid,'糖果',candy,'香烟',cigarette,'休闲食品',snack_food,'FF蒸包小吃',steamed_bun_snacks,'热饮料',hot_drinks
,'便当面条',bento_noodles,'饭团寿司',rice_and_sushi,'干货速食',dry_and_fast_food,'粮油调味',grain_and_oil_seasoning,'肉蛋果蔬',meat_eggs_fruits_and_vegetables,'乳饮',milk_drink,
'三明治汉堡',sandwich_burger,'特设商品',special_merchandise,'甜品及其他',dessert_fast_food_and_other,'非常规卖品',unconventional_sales_items,'无归属',no_attribution) AS tmp_column
   FROM database_table) x
   LATERAL VIEW EXPLODE(tmp_column) exptbl as bool,val) x
   left join nine_month_large_market t on x.store_code = t.store_code and x.bool = t.bool and x.is_working_day = t.is_working_day
   left join data_build.dm_site_selection_project_feature_info_di t1 on x.store_code = t1.store_code and t1.dt = 20221114

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
--全周和分工作日和非工作日
select
record_week
,store_code
,store_city
,sale_days
,bool
,val
,val_day
,nine_val_day
,val_recovery
,location_type
,'全周' as is_working_day
,dt
from data_build.app_app_sale_by_category_v1_da
where dt = 20240221
and store_code = '100078005'
union all
select * from data_build.app_app_sale_by_category_workday_or_notworkday_v1_da
where dt = 20240221
and store_code = '100078005'

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
with full_list as
(
select
record_week
,store_code
,store_city
,sale_days
,bool
,val
,val_day
,nine_val_day
,val_recovery
,location_type
,'全周' as is_working_day
,dt
from data_build.app_app_sale_by_category_v1_da
where dt = 20240221
and store_code = '100078005'
union all
select * from data_build.app_app_sale_by_category_workday_or_notworkday_v1_da
where dt = 20240221
and store_code = '100078005'
),

store_list as(
select
store_code
,bool
,store_city
,location_type
,is_working_day
,1 as joinkey
from full_list
group by
store_code
,bool
,store_city
,location_type
,is_working_day
,1
),

date_list as(
select
date_add(date_key,7 - case when dayofweek(date_key) = 1 then 7 else dayofweek(date_key) - 1 end) as record_week
,1 as joinkey
from data_build.dim_date_ya_v2
where date_key between'2023-08-28' and date_format(date_sub(current_date(),1),'yyyy-MM-dd')
group by
date_add(date_key,7 - case when dayofweek(date_key) = 1 then 7 else dayofweek(date_key) - 1 end)
,1
),

date_store_list as(
select
a.record_week
,b.bool
,b.store_city
,b.location_type
,b.store_code
,b.is_working_day
from date_list a
cross join store_list b on a.joinkey = b.joinkey
),

nine_sale as(
select
store_code
,bool
,nine_val_day
,is_working_day
from full_list
--where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
where record_week = '2023-09-03'
),

nine_sale_null as(--剔除一些9月日商异常的门店
SELECT
store_code
from data_build.app_app_sale_by_category_v1_da
where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and record_week = '2023-09-03'
and bool = '日商'
and (nine_val_day < '1000' or nine_val_day is null)
)

select
a.record_week
,a.store_code
,a.store_city
,b.sale_days
,a.bool
,b.val
,b.val_day
,c.nine_val_day
,b.val_recovery
,a.location_type
,b.is_working_day
from date_store_list a
left join full_list b on a.record_week = b.record_week and a.store_code = b.store_code and a.bool = b.bool and a.is_working_day = b.is_working_day
left join nine_sale c on a.store_code = c.store_code and a.bool = c.bool and a.is_working_day = c.is_working_day
left join nine_sale_null d on a.store_code = d.store_code
where d.store_code is null

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
--季度分品类销售额
select
'19Q3' as record_date
,store_code
,store_city
,sale_days
,bool
,val
,val/sale_days as val_day
from(
select
x.store_code
,x.store_city
,x.sale_days
,MAP('日商',x.payable_price,'槟榔',x.betel_nut,'冰淇淋',x.ice_cream,'饼干',x.cookie,'干果',x.dried_fruit,'果脯',x.preserved_fruit,'加工食品',x.processed_food,'饮品站/饮品机',x.coffee_soybean_milk_self_service_drink,
'烈酒',x.spirits,'面包',x.bread,'FF萌煮',x.cute_boiling,'巧克力',x.chocolate,'FF热餐',x.hot_meal,'FF早餐酥饼',x.flaky_pastry,'肉脯',x.portly_or_obese_person,'生活杂货',x.daily_necessities,
'嗜好品',x.asaddictive_things,'FF炸烤制品',x.fried_baked_goods,'水饮',x.retained_fluid,'糖果',x.candy,'香烟',x.cigarette,'休闲食品',x.snack_food,'FF蒸包小吃',x.steamed_bun_snacks,'热饮料',x.hot_drinks
,'便当面条',x.bento_noodles,'饭团寿司',x.rice_and_sushi,'干货速食',x.dry_and_fast_food,'粮油调味',x.grain_and_oil_seasoning,'肉蛋果蔬',x.meat_eggs_fruits_and_vegetables,'乳饮',x.milk_drink,
'三明治汉堡',x.sandwich_burger,'特设商品',x.special_merchandise,'甜品及其他',x.dessert_fast_food_and_other,'非常规卖品',x.unconventional_sales_items,'无归属',x.no_attribution) AS tmp_column
FROM(
select
t.store_code
,t.store_city

--营业日
,count(distinct order_date) as sale_days

--折后销售额
,sum(payable_price) as payable_price --全部销售额

--折后销售额 按照商品拆分
,sum(case when sku_division_code in ('3604') then payable_price else 0 end) as betel_nut
,sum(case when sku_division_code in ('4201','4202','4203','4204','4205','7942') then payable_price else 0 end) as ice_cream
,sum(case when sku_division_code in ('3408','3407','3405','3406','4401','4402') then payable_price else 0 end) as cookie
,sum(case when sku_division_code in ('2501','2502','3602','4405','7936') then payable_price else 0 end) as dried_fruit
,sum(case when sku_division_code in ('2504','3603') then payable_price else 0 end) as preserved_fruit
,sum(case when sku_division_code in ('4001','4002','4003','4004','4005','4006','4007','4008','7940') then payable_price else 0 end) as processed_food
,sum(case when sku_division_code in ('5003','5004','5005','5006','5007','5008','5009','5010','5019','5020','0702','0706','0713','0715','0716','0717','0718',
'0719','0720','0721') then payable_price else 0 end) as coffee_soybean_milk_self_service_drink
,sum(case when sku_division_code in ('3101','3102','3103','3104','3105','3201','3202','3205','7931','7932') then payable_price else 0 end) as spirits
,sum(case when sku_division_code in ('2101','2102','2103','2104','2105','2106','2107','2108','2109') then payable_price else 0 end) as bread
,sum(case when sku_division_code in ('0501','0502','0503','0505','0508') then payable_price else 0 end) as cute_boiling
,sum(case when sku_division_code in ('3404') then payable_price else 0 end) as chocolate
,sum(case when sku_division_code in ('0301','0304') then payable_price else 0 end) as hot_meal
,sum(case when sku_division_code in ('0602') then payable_price else 0 end) as flaky_pastry
,sum(case when sku_division_code in ('3701','3702','3703','4406','7937') then payable_price else 0 end) as portly_or_obese_person
,sum(case when sku_division_code in ('2701','4009','6401','6402','6403','6404','6406','6407','6408','6501','6502','6503','6504','6601','6602','6701','6702','6703','6801',
'6802','6803','6804','6805','6806','7001','7002','7003','7004','7005','7006','7007','7008','7101','7103','7104','7105','7106','7107','7301','7302','7303','7701','7801',
'7802','7964','7965','7966','7967','7968','7970','7971','7973','7978','7985','7988','7989','8501','8502','8503','8801','8802','8804','8902') then payable_price else 0 end) as daily_necessities
,sum(case when sku_division_code in ('4101','4102','4103','4104','4105','4106','4407','7941') then payable_price else 0 end) asaddictive_things
,sum(case when sku_division_code in ('0302') then payable_price else 0 end) as fried_baked_goods
,sum(case when sku_division_code in ('1205','1206','1207','3001','3002','3003','3301','3302','3303','3304','3305','3306','3307','3309','7930','7933') then payable_price else 0 end) as retained_fluid
,sum(case when sku_division_code in ('3401','3402','3403','4403') then payable_price else 0 end) as candy
,sum(case when sku_division_code in ('6101','6102','6103') then payable_price else 0 end) as cigarette
,sum(case when sku_division_code in ('3501','3502','3503','3601','4404','7935') then payable_price else 0 end) as snack_food
,sum(case when sku_division_code in ('1501','1502','1503','1504','1505','1506','1507','1508','0303','0309','0310','0312','0313','0314','0601','0603','0604') then payable_price else 0 end) as steamed_bun_snacks
,sum(case when sku_division_code in ('3310') then payable_price else 0 end) as hot_drinks
,sum(case when sku_division_code in ('0103','0105','0106','0401','0402') then payable_price else 0 end) as bento_noodles
,sum(case when sku_division_code in ('0101','0102') then payable_price else 0 end) as rice_and_sushi --饭团寿司
,sum(case when sku_division_code in ('1001','1004','1209','1301','1302','1303','1304','1305','1306','1307','1402','1410','2212','2308','2503','2505','2601','2603','2604','2605',
'2606','2607','2608','3801','3810','4301','4302','4303') then payable_price else 0 end) as dry_and_fast_food --干货速食
,sum(case when sku_division_code in ('2506','3802','3803','3804','3805','3806','3807','3808','3809','3811','3812','3813','7938') then payable_price else 0 end) as grain_and_oil_seasoning --粮油调味
,sum(case when sku_division_code in ('1401','1403','1404','1405','1406','1407','1408','1409','1411','1412','1413','1414','1415','1416','1418','2201','2202','2203','2204','2205',
'2206','2207','2208','2209','2210','2211','2213','2301','2302','2303','2304','2305','2306','2307','2309','2310','2311','2312','2313','2314','2316','2401','2402','2403','2404',
'2406','2407','0801','0802','0805') then payable_price else 0 end) as meat_eggs_fruits_and_vegetables --肉蛋果蔬
,sum(case when sku_division_code in ('1201','1202','1203','1204','1208','3308','7912') then payable_price else 0 end) as milk_drink --乳饮
,sum(case when sku_division_code in ('0201','0202') then payable_price else 0 end) as sandwich_burger --三明治汉堡
,sum(case when sku_division_code in ('3409','3901','3904','3907','3909','3910','3911','6201','7201','7203','7209','7210','7211','7934','7972') then payable_price else 0 end) as special_merchandise --特设商品
,sum(case when sku_division_code in ('1101','1102','1103','1104','1105','1210','0204') then payable_price else 0 end) as dessert_fast_food_and_other --甜品及其他
,sum(case when sku_division_code in ('2702','2703','4408','5001','5002','7504','8201','8202','8203','8204','8205','8206','8207','8208','8209','8210','8211','8212','8215','8216',
'8217','8218','8220','8222','8223','8224','8225','8226','8401','8601','8602','8603','8604','8605','8606','8607','8608','8701','8702','8703','8704','8705','8706','9101','9102',
'9103','9104','9105','9106','9107','9108','9109','9110','9112','9113','9114','9115','9118','9201','9203','9204','9205','9206','9207','9208','9209','9210','9211','9212','9218',
'9301','9302','9303','9304','9305','9306','9307','9308','9310','9311','9312','9314','9315','9316','9317','9318','9319','9320','9321','9399','9401','9402','9403','9404','9405',
'9601','9602','9603','9604','9605','9606','9607','9701','9702','9703','9704','9705','9706','9707','9708','9709','9710','9711','9712','9713','9714','9715','9716','9717','9801',
'9802','9803','9804','9805','9806','9807','9808','9809','9810','9812','9816','9818','9821','9822','9901','0307','0308','0311','0315','0316','0804','0901','0902','0904','0905',
'0906') then payable_price else 0 end) as unconventional_sales_items --非常规卖品
,sum(case when sku_division_code not in ('0501','0502','0503','0505','0508','0301','0304','0602','0302','1501','1502','1503','1504','1505','1506','1507','1508','0303','0309',
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
'5006','5007','5008','5009','5010','5019','5020','0702','0706','0713','0715','0716','0717','0718','0719','0720','0721') then payable_price else 0 end) as no_attribution --无归属
 
from 
data_build.dw_order_sku_promotion_v1 t --订单明细表
--data_or.dm_copy_dw_order_sku_promotion_v1_view t
where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and store_type = '0'
and pay_status = 'PAY_SUCCESS'
--and store_code = '100078005'
and t.sku_class_code not in ('86','50')
and order_date between '2019-07-01' and '2019-09-30'
group by
t.store_code
,store_city) x
) a
LATERAL VIEW EXPLODE(a.tmp_column) exptbl as bool,val

union all

select
'20Q3' as record_date
,store_code
,store_city
,sale_days
,bool
,val
,val/sale_days as val_day
from(
select
x.store_code
,x.store_city
,x.sale_days
,MAP('日商',x.payable_price,'槟榔',x.betel_nut,'冰淇淋',x.ice_cream,'饼干',x.cookie,'干果',x.dried_fruit,'果脯',x.preserved_fruit,'加工食品',x.processed_food,'饮品站/饮品机',x.coffee_soybean_milk_self_service_drink,
'烈酒',x.spirits,'面包',x.bread,'FF萌煮',x.cute_boiling,'巧克力',x.chocolate,'FF热餐',x.hot_meal,'FF早餐酥饼',x.flaky_pastry,'肉脯',x.portly_or_obese_person,'生活杂货',x.daily_necessities,
'嗜好品',x.asaddictive_things,'FF炸烤制品',x.fried_baked_goods,'水饮',x.retained_fluid,'糖果',x.candy,'香烟',x.cigarette,'休闲食品',x.snack_food,'FF蒸包小吃',x.steamed_bun_snacks,'热饮料',x.hot_drinks
,'便当面条',x.bento_noodles,'饭团寿司',x.rice_and_sushi,'干货速食',x.dry_and_fast_food,'粮油调味',x.grain_and_oil_seasoning,'肉蛋果蔬',x.meat_eggs_fruits_and_vegetables,'乳饮',x.milk_drink,
'三明治汉堡',x.sandwich_burger,'特设商品',x.special_merchandise,'甜品及其他',x.dessert_fast_food_and_other,'非常规卖品',x.unconventional_sales_items,'无归属',x.no_attribution) AS tmp_column
FROM(
select
t.store_code
,t.store_city

--营业日
,count(distinct order_date) as sale_days

--折后销售额
,sum(payable_price) as payable_price --全部销售额

--折后销售额 按照商品拆分
,sum(case when sku_division_code in ('3604') then payable_price else 0 end) as betel_nut
,sum(case when sku_division_code in ('4201','4202','4203','4204','4205','7942') then payable_price else 0 end) as ice_cream
,sum(case when sku_division_code in ('3408','3407','3405','3406','4401','4402') then payable_price else 0 end) as cookie
,sum(case when sku_division_code in ('2501','2502','3602','4405','7936') then payable_price else 0 end) as dried_fruit
,sum(case when sku_division_code in ('2504','3603') then payable_price else 0 end) as preserved_fruit
,sum(case when sku_division_code in ('4001','4002','4003','4004','4005','4006','4007','4008','7940') then payable_price else 0 end) as processed_food
,sum(case when sku_division_code in ('5003','5004','5005','5006','5007','5008','5009','5010','5019','5020','0702','0706','0713','0715','0716','0717','0718',
'0719','0720','0721') then payable_price else 0 end) as coffee_soybean_milk_self_service_drink
,sum(case when sku_division_code in ('3101','3102','3103','3104','3105','3201','3202','3205','7931','7932') then payable_price else 0 end) as spirits
,sum(case when sku_division_code in ('2101','2102','2103','2104','2105','2106','2107','2108','2109') then payable_price else 0 end) as bread
,sum(case when sku_division_code in ('0501','0502','0503','0505','0508') then payable_price else 0 end) as cute_boiling
,sum(case when sku_division_code in ('3404') then payable_price else 0 end) as chocolate
,sum(case when sku_division_code in ('0301','0304') then payable_price else 0 end) as hot_meal
,sum(case when sku_division_code in ('0602') then payable_price else 0 end) as flaky_pastry
,sum(case when sku_division_code in ('3701','3702','3703','4406','7937') then payable_price else 0 end) as portly_or_obese_person
,sum(case when sku_division_code in ('2701','4009','6401','6402','6403','6404','6406','6407','6408','6501','6502','6503','6504','6601','6602','6701','6702','6703','6801',
'6802','6803','6804','6805','6806','7001','7002','7003','7004','7005','7006','7007','7008','7101','7103','7104','7105','7106','7107','7301','7302','7303','7701','7801',
'7802','7964','7965','7966','7967','7968','7970','7971','7973','7978','7985','7988','7989','8501','8502','8503','8801','8802','8804','8902') then payable_price else 0 end) as daily_necessities
,sum(case when sku_division_code in ('4101','4102','4103','4104','4105','4106','4407','7941') then payable_price else 0 end) asaddictive_things
,sum(case when sku_division_code in ('0302') then payable_price else 0 end) as fried_baked_goods
,sum(case when sku_division_code in ('1205','1206','1207','3001','3002','3003','3301','3302','3303','3304','3305','3306','3307','3309','7930','7933') then payable_price else 0 end) as retained_fluid
,sum(case when sku_division_code in ('3401','3402','3403','4403') then payable_price else 0 end) as candy
,sum(case when sku_division_code in ('6101','6102','6103') then payable_price else 0 end) as cigarette
,sum(case when sku_division_code in ('3501','3502','3503','3601','4404','7935') then payable_price else 0 end) as snack_food
,sum(case when sku_division_code in ('1501','1502','1503','1504','1505','1506','1507','1508','0303','0309','0310','0312','0313','0314','0601','0603','0604') then payable_price else 0 end) as steamed_bun_snacks
,sum(case when sku_division_code in ('3310') then payable_price else 0 end) as hot_drinks
,sum(case when sku_division_code in ('0103','0105','0106','0401','0402') then payable_price else 0 end) as bento_noodles
,sum(case when sku_division_code in ('0101','0102') then payable_price else 0 end) as rice_and_sushi --饭团寿司
,sum(case when sku_division_code in ('1001','1004','1209','1301','1302','1303','1304','1305','1306','1307','1402','1410','2212','2308','2503','2505','2601','2603','2604','2605',
'2606','2607','2608','3801','3810','4301','4302','4303') then payable_price else 0 end) as dry_and_fast_food --干货速食
,sum(case when sku_division_code in ('2506','3802','3803','3804','3805','3806','3807','3808','3809','3811','3812','3813','7938') then payable_price else 0 end) as grain_and_oil_seasoning --粮油调味
,sum(case when sku_division_code in ('1401','1403','1404','1405','1406','1407','1408','1409','1411','1412','1413','1414','1415','1416','1418','2201','2202','2203','2204','2205',
'2206','2207','2208','2209','2210','2211','2213','2301','2302','2303','2304','2305','2306','2307','2309','2310','2311','2312','2313','2314','2316','2401','2402','2403','2404',
'2406','2407','0801','0802','0805') then payable_price else 0 end) as meat_eggs_fruits_and_vegetables --肉蛋果蔬
,sum(case when sku_division_code in ('1201','1202','1203','1204','1208','3308','7912') then payable_price else 0 end) as milk_drink --乳饮
,sum(case when sku_division_code in ('0201','0202') then payable_price else 0 end) as sandwich_burger --三明治汉堡
,sum(case when sku_division_code in ('3409','3901','3904','3907','3909','3910','3911','6201','7201','7203','7209','7210','7211','7934','7972') then payable_price else 0 end) as special_merchandise --特设商品
,sum(case when sku_division_code in ('1101','1102','1103','1104','1105','1210','0204') then payable_price else 0 end) as dessert_fast_food_and_other --甜品及其他
,sum(case when sku_division_code in ('2702','2703','4408','5001','5002','7504','8201','8202','8203','8204','8205','8206','8207','8208','8209','8210','8211','8212','8215','8216',
'8217','8218','8220','8222','8223','8224','8225','8226','8401','8601','8602','8603','8604','8605','8606','8607','8608','8701','8702','8703','8704','8705','8706','9101','9102',
'9103','9104','9105','9106','9107','9108','9109','9110','9112','9113','9114','9115','9118','9201','9203','9204','9205','9206','9207','9208','9209','9210','9211','9212','9218',
'9301','9302','9303','9304','9305','9306','9307','9308','9310','9311','9312','9314','9315','9316','9317','9318','9319','9320','9321','9399','9401','9402','9403','9404','9405',
'9601','9602','9603','9604','9605','9606','9607','9701','9702','9703','9704','9705','9706','9707','9708','9709','9710','9711','9712','9713','9714','9715','9716','9717','9801',
'9802','9803','9804','9805','9806','9807','9808','9809','9810','9812','9816','9818','9821','9822','9901','0307','0308','0311','0315','0316','0804','0901','0902','0904','0905',
'0906') then payable_price else 0 end) as unconventional_sales_items --非常规卖品
,sum(case when sku_division_code not in ('0501','0502','0503','0505','0508','0301','0304','0602','0302','1501','1502','1503','1504','1505','1506','1507','1508','0303','0309',
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
'5006','5007','5008','5009','5010','5019','5020','0702','0706','0713','0715','0716','0717','0718','0719','0720','0721') then payable_price else 0 end) as no_attribution --无归属
 
from 
data_build.dw_order_sku_promotion_v1 t --订单明细表
--data_or.dm_copy_dw_order_sku_promotion_v1_view t
where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and store_type = '0'
and pay_status = 'PAY_SUCCESS'
--and store_code = '100078005'
and t.sku_class_code not in ('86','50')
and order_date between '2020-07-01' and '2020-09-30'
group by
t.store_code
,store_city) x
) a
LATERAL VIEW EXPLODE(a.tmp_column) exptbl as bool,val

union all

select
'21Q3' as record_date
,store_code
,store_city
,sale_days
,bool
,val
,val/sale_days as val_day
from(
select
x.store_code
,x.store_city
,x.sale_days
,MAP('日商',x.payable_price,'槟榔',x.betel_nut,'冰淇淋',x.ice_cream,'饼干',x.cookie,'干果',x.dried_fruit,'果脯',x.preserved_fruit,'加工食品',x.processed_food,'饮品站/饮品机',x.coffee_soybean_milk_self_service_drink,
'烈酒',x.spirits,'面包',x.bread,'FF萌煮',x.cute_boiling,'巧克力',x.chocolate,'FF热餐',x.hot_meal,'FF早餐酥饼',x.flaky_pastry,'肉脯',x.portly_or_obese_person,'生活杂货',x.daily_necessities,
'嗜好品',x.asaddictive_things,'FF炸烤制品',x.fried_baked_goods,'水饮',x.retained_fluid,'糖果',x.candy,'香烟',x.cigarette,'休闲食品',x.snack_food,'FF蒸包小吃',x.steamed_bun_snacks,'热饮料',x.hot_drinks
,'便当面条',x.bento_noodles,'饭团寿司',x.rice_and_sushi,'干货速食',x.dry_and_fast_food,'粮油调味',x.grain_and_oil_seasoning,'肉蛋果蔬',x.meat_eggs_fruits_and_vegetables,'乳饮',x.milk_drink,
'三明治汉堡',x.sandwich_burger,'特设商品',x.special_merchandise,'甜品及其他',x.dessert_fast_food_and_other,'非常规卖品',x.unconventional_sales_items,'无归属',x.no_attribution) AS tmp_column
FROM(
select
t.store_code
,t.store_city

--营业日
,count(distinct order_date) as sale_days

--折后销售额
,sum(payable_price) as payable_price --全部销售额

--折后销售额 按照商品拆分
,sum(case when sku_division_code in ('3604') then payable_price else 0 end) as betel_nut
,sum(case when sku_division_code in ('4201','4202','4203','4204','4205','7942') then payable_price else 0 end) as ice_cream
,sum(case when sku_division_code in ('3408','3407','3405','3406','4401','4402') then payable_price else 0 end) as cookie
,sum(case when sku_division_code in ('2501','2502','3602','4405','7936') then payable_price else 0 end) as dried_fruit
,sum(case when sku_division_code in ('2504','3603') then payable_price else 0 end) as preserved_fruit
,sum(case when sku_division_code in ('4001','4002','4003','4004','4005','4006','4007','4008','7940') then payable_price else 0 end) as processed_food
,sum(case when sku_division_code in ('5003','5004','5005','5006','5007','5008','5009','5010','5019','5020','0702','0706','0713','0715','0716','0717','0718',
'0719','0720','0721') then payable_price else 0 end) as coffee_soybean_milk_self_service_drink
,sum(case when sku_division_code in ('3101','3102','3103','3104','3105','3201','3202','3205','7931','7932') then payable_price else 0 end) as spirits
,sum(case when sku_division_code in ('2101','2102','2103','2104','2105','2106','2107','2108','2109') then payable_price else 0 end) as bread
,sum(case when sku_division_code in ('0501','0502','0503','0505','0508') then payable_price else 0 end) as cute_boiling
,sum(case when sku_division_code in ('3404') then payable_price else 0 end) as chocolate
,sum(case when sku_division_code in ('0301','0304') then payable_price else 0 end) as hot_meal
,sum(case when sku_division_code in ('0602') then payable_price else 0 end) as flaky_pastry
,sum(case when sku_division_code in ('3701','3702','3703','4406','7937') then payable_price else 0 end) as portly_or_obese_person
,sum(case when sku_division_code in ('2701','4009','6401','6402','6403','6404','6406','6407','6408','6501','6502','6503','6504','6601','6602','6701','6702','6703','6801',
'6802','6803','6804','6805','6806','7001','7002','7003','7004','7005','7006','7007','7008','7101','7103','7104','7105','7106','7107','7301','7302','7303','7701','7801',
'7802','7964','7965','7966','7967','7968','7970','7971','7973','7978','7985','7988','7989','8501','8502','8503','8801','8802','8804','8902') then payable_price else 0 end) as daily_necessities
,sum(case when sku_division_code in ('4101','4102','4103','4104','4105','4106','4407','7941') then payable_price else 0 end) asaddictive_things
,sum(case when sku_division_code in ('0302') then payable_price else 0 end) as fried_baked_goods
,sum(case when sku_division_code in ('1205','1206','1207','3001','3002','3003','3301','3302','3303','3304','3305','3306','3307','3309','7930','7933') then payable_price else 0 end) as retained_fluid
,sum(case when sku_division_code in ('3401','3402','3403','4403') then payable_price else 0 end) as candy
,sum(case when sku_division_code in ('6101','6102','6103') then payable_price else 0 end) as cigarette
,sum(case when sku_division_code in ('3501','3502','3503','3601','4404','7935') then payable_price else 0 end) as snack_food
,sum(case when sku_division_code in ('1501','1502','1503','1504','1505','1506','1507','1508','0303','0309','0310','0312','0313','0314','0601','0603','0604') then payable_price else 0 end) as steamed_bun_snacks
,sum(case when sku_division_code in ('3310') then payable_price else 0 end) as hot_drinks
,sum(case when sku_division_code in ('0103','0105','0106','0401','0402') then payable_price else 0 end) as bento_noodles
,sum(case when sku_division_code in ('0101','0102') then payable_price else 0 end) as rice_and_sushi --饭团寿司
,sum(case when sku_division_code in ('1001','1004','1209','1301','1302','1303','1304','1305','1306','1307','1402','1410','2212','2308','2503','2505','2601','2603','2604','2605',
'2606','2607','2608','3801','3810','4301','4302','4303') then payable_price else 0 end) as dry_and_fast_food --干货速食
,sum(case when sku_division_code in ('2506','3802','3803','3804','3805','3806','3807','3808','3809','3811','3812','3813','7938') then payable_price else 0 end) as grain_and_oil_seasoning --粮油调味
,sum(case when sku_division_code in ('1401','1403','1404','1405','1406','1407','1408','1409','1411','1412','1413','1414','1415','1416','1418','2201','2202','2203','2204','2205',
'2206','2207','2208','2209','2210','2211','2213','2301','2302','2303','2304','2305','2306','2307','2309','2310','2311','2312','2313','2314','2316','2401','2402','2403','2404',
'2406','2407','0801','0802','0805') then payable_price else 0 end) as meat_eggs_fruits_and_vegetables --肉蛋果蔬
,sum(case when sku_division_code in ('1201','1202','1203','1204','1208','3308','7912') then payable_price else 0 end) as milk_drink --乳饮
,sum(case when sku_division_code in ('0201','0202') then payable_price else 0 end) as sandwich_burger --三明治汉堡
,sum(case when sku_division_code in ('3409','3901','3904','3907','3909','3910','3911','6201','7201','7203','7209','7210','7211','7934','7972') then payable_price else 0 end) as special_merchandise --特设商品
,sum(case when sku_division_code in ('1101','1102','1103','1104','1105','1210','0204') then payable_price else 0 end) as dessert_fast_food_and_other --甜品及其他
,sum(case when sku_division_code in ('2702','2703','4408','5001','5002','7504','8201','8202','8203','8204','8205','8206','8207','8208','8209','8210','8211','8212','8215','8216',
'8217','8218','8220','8222','8223','8224','8225','8226','8401','8601','8602','8603','8604','8605','8606','8607','8608','8701','8702','8703','8704','8705','8706','9101','9102',
'9103','9104','9105','9106','9107','9108','9109','9110','9112','9113','9114','9115','9118','9201','9203','9204','9205','9206','9207','9208','9209','9210','9211','9212','9218',
'9301','9302','9303','9304','9305','9306','9307','9308','9310','9311','9312','9314','9315','9316','9317','9318','9319','9320','9321','9399','9401','9402','9403','9404','9405',
'9601','9602','9603','9604','9605','9606','9607','9701','9702','9703','9704','9705','9706','9707','9708','9709','9710','9711','9712','9713','9714','9715','9716','9717','9801',
'9802','9803','9804','9805','9806','9807','9808','9809','9810','9812','9816','9818','9821','9822','9901','0307','0308','0311','0315','0316','0804','0901','0902','0904','0905',
'0906') then payable_price else 0 end) as unconventional_sales_items --非常规卖品
,sum(case when sku_division_code not in ('0501','0502','0503','0505','0508','0301','0304','0602','0302','1501','1502','1503','1504','1505','1506','1507','1508','0303','0309',
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
'5006','5007','5008','5009','5010','5019','5020','0702','0706','0713','0715','0716','0717','0718','0719','0720','0721') then payable_price else 0 end) as no_attribution --无归属
 
from 
data_build.dw_order_sku_promotion_v1 t --订单明细表
--data_or.dm_copy_dw_order_sku_promotion_v1_view t
where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and store_type = '0'
and pay_status = 'PAY_SUCCESS'
--and store_code = '100078005'
and t.sku_class_code not in ('86','50')
and order_date between '2021-07-01' and '2021-09-30'
group by
t.store_code
,store_city) x
) a
LATERAL VIEW EXPLODE(a.tmp_column) exptbl as bool,val

union all

select
'22Q3' as record_date
,store_code
,store_city
,sale_days
,bool
,val
,val/sale_days as val_day
from(
select
x.store_code
,x.store_city
,x.sale_days
,MAP('日商',x.payable_price,'槟榔',x.betel_nut,'冰淇淋',x.ice_cream,'饼干',x.cookie,'干果',x.dried_fruit,'果脯',x.preserved_fruit,'加工食品',x.processed_food,'饮品站/饮品机',x.coffee_soybean_milk_self_service_drink,
'烈酒',x.spirits,'面包',x.bread,'FF萌煮',x.cute_boiling,'巧克力',x.chocolate,'FF热餐',x.hot_meal,'FF早餐酥饼',x.flaky_pastry,'肉脯',x.portly_or_obese_person,'生活杂货',x.daily_necessities,
'嗜好品',x.asaddictive_things,'FF炸烤制品',x.fried_baked_goods,'水饮',x.retained_fluid,'糖果',x.candy,'香烟',x.cigarette,'休闲食品',x.snack_food,'FF蒸包小吃',x.steamed_bun_snacks,'热饮料',x.hot_drinks
,'便当面条',x.bento_noodles,'饭团寿司',x.rice_and_sushi,'干货速食',x.dry_and_fast_food,'粮油调味',x.grain_and_oil_seasoning,'肉蛋果蔬',x.meat_eggs_fruits_and_vegetables,'乳饮',x.milk_drink,
'三明治汉堡',x.sandwich_burger,'特设商品',x.special_merchandise,'甜品及其他',x.dessert_fast_food_and_other,'非常规卖品',x.unconventional_sales_items,'无归属',x.no_attribution) AS tmp_column
FROM(
select
t.store_code
,t.store_city

--营业日
,count(distinct order_date) as sale_days

--折后销售额
,sum(payable_price) as payable_price --全部销售额

--折后销售额 按照商品拆分
,sum(case when sku_division_code in ('3604') then payable_price else 0 end) as betel_nut
,sum(case when sku_division_code in ('4201','4202','4203','4204','4205','7942') then payable_price else 0 end) as ice_cream
,sum(case when sku_division_code in ('3408','3407','3405','3406','4401','4402') then payable_price else 0 end) as cookie
,sum(case when sku_division_code in ('2501','2502','3602','4405','7936') then payable_price else 0 end) as dried_fruit
,sum(case when sku_division_code in ('2504','3603') then payable_price else 0 end) as preserved_fruit
,sum(case when sku_division_code in ('4001','4002','4003','4004','4005','4006','4007','4008','7940') then payable_price else 0 end) as processed_food
,sum(case when sku_division_code in ('5003','5004','5005','5006','5007','5008','5009','5010','5019','5020','0702','0706','0713','0715','0716','0717','0718',
'0719','0720','0721') then payable_price else 0 end) as coffee_soybean_milk_self_service_drink
,sum(case when sku_division_code in ('3101','3102','3103','3104','3105','3201','3202','3205','7931','7932') then payable_price else 0 end) as spirits
,sum(case when sku_division_code in ('2101','2102','2103','2104','2105','2106','2107','2108','2109') then payable_price else 0 end) as bread
,sum(case when sku_division_code in ('0501','0502','0503','0505','0508') then payable_price else 0 end) as cute_boiling
,sum(case when sku_division_code in ('3404') then payable_price else 0 end) as chocolate
,sum(case when sku_division_code in ('0301','0304') then payable_price else 0 end) as hot_meal
,sum(case when sku_division_code in ('0602') then payable_price else 0 end) as flaky_pastry
,sum(case when sku_division_code in ('3701','3702','3703','4406','7937') then payable_price else 0 end) as portly_or_obese_person
,sum(case when sku_division_code in ('2701','4009','6401','6402','6403','6404','6406','6407','6408','6501','6502','6503','6504','6601','6602','6701','6702','6703','6801',
'6802','6803','6804','6805','6806','7001','7002','7003','7004','7005','7006','7007','7008','7101','7103','7104','7105','7106','7107','7301','7302','7303','7701','7801',
'7802','7964','7965','7966','7967','7968','7970','7971','7973','7978','7985','7988','7989','8501','8502','8503','8801','8802','8804','8902') then payable_price else 0 end) as daily_necessities
,sum(case when sku_division_code in ('4101','4102','4103','4104','4105','4106','4407','7941') then payable_price else 0 end) asaddictive_things
,sum(case when sku_division_code in ('0302') then payable_price else 0 end) as fried_baked_goods
,sum(case when sku_division_code in ('1205','1206','1207','3001','3002','3003','3301','3302','3303','3304','3305','3306','3307','3309','7930','7933') then payable_price else 0 end) as retained_fluid
,sum(case when sku_division_code in ('3401','3402','3403','4403') then payable_price else 0 end) as candy
,sum(case when sku_division_code in ('6101','6102','6103') then payable_price else 0 end) as cigarette
,sum(case when sku_division_code in ('3501','3502','3503','3601','4404','7935') then payable_price else 0 end) as snack_food
,sum(case when sku_division_code in ('1501','1502','1503','1504','1505','1506','1507','1508','0303','0309','0310','0312','0313','0314','0601','0603','0604') then payable_price else 0 end) as steamed_bun_snacks
,sum(case when sku_division_code in ('3310') then payable_price else 0 end) as hot_drinks
,sum(case when sku_division_code in ('0103','0105','0106','0401','0402') then payable_price else 0 end) as bento_noodles
,sum(case when sku_division_code in ('0101','0102') then payable_price else 0 end) as rice_and_sushi --饭团寿司
,sum(case when sku_division_code in ('1001','1004','1209','1301','1302','1303','1304','1305','1306','1307','1402','1410','2212','2308','2503','2505','2601','2603','2604','2605',
'2606','2607','2608','3801','3810','4301','4302','4303') then payable_price else 0 end) as dry_and_fast_food --干货速食
,sum(case when sku_division_code in ('2506','3802','3803','3804','3805','3806','3807','3808','3809','3811','3812','3813','7938') then payable_price else 0 end) as grain_and_oil_seasoning --粮油调味
,sum(case when sku_division_code in ('1401','1403','1404','1405','1406','1407','1408','1409','1411','1412','1413','1414','1415','1416','1418','2201','2202','2203','2204','2205',
'2206','2207','2208','2209','2210','2211','2213','2301','2302','2303','2304','2305','2306','2307','2309','2310','2311','2312','2313','2314','2316','2401','2402','2403','2404',
'2406','2407','0801','0802','0805') then payable_price else 0 end) as meat_eggs_fruits_and_vegetables --肉蛋果蔬
,sum(case when sku_division_code in ('1201','1202','1203','1204','1208','3308','7912') then payable_price else 0 end) as milk_drink --乳饮
,sum(case when sku_division_code in ('0201','0202') then payable_price else 0 end) as sandwich_burger --三明治汉堡
,sum(case when sku_division_code in ('3409','3901','3904','3907','3909','3910','3911','6201','7201','7203','7209','7210','7211','7934','7972') then payable_price else 0 end) as special_merchandise --特设商品
,sum(case when sku_division_code in ('1101','1102','1103','1104','1105','1210','0204') then payable_price else 0 end) as dessert_fast_food_and_other --甜品及其他
,sum(case when sku_division_code in ('2702','2703','4408','5001','5002','7504','8201','8202','8203','8204','8205','8206','8207','8208','8209','8210','8211','8212','8215','8216',
'8217','8218','8220','8222','8223','8224','8225','8226','8401','8601','8602','8603','8604','8605','8606','8607','8608','8701','8702','8703','8704','8705','8706','9101','9102',
'9103','9104','9105','9106','9107','9108','9109','9110','9112','9113','9114','9115','9118','9201','9203','9204','9205','9206','9207','9208','9209','9210','9211','9212','9218',
'9301','9302','9303','9304','9305','9306','9307','9308','9310','9311','9312','9314','9315','9316','9317','9318','9319','9320','9321','9399','9401','9402','9403','9404','9405',
'9601','9602','9603','9604','9605','9606','9607','9701','9702','9703','9704','9705','9706','9707','9708','9709','9710','9711','9712','9713','9714','9715','9716','9717','9801',
'9802','9803','9804','9805','9806','9807','9808','9809','9810','9812','9816','9818','9821','9822','9901','0307','0308','0311','0315','0316','0804','0901','0902','0904','0905',
'0906') then payable_price else 0 end) as unconventional_sales_items --非常规卖品
,sum(case when sku_division_code not in ('0501','0502','0503','0505','0508','0301','0304','0602','0302','1501','1502','1503','1504','1505','1506','1507','1508','0303','0309',
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
'5006','5007','5008','5009','5010','5019','5020','0702','0706','0713','0715','0716','0717','0718','0719','0720','0721') then payable_price else 0 end) as no_attribution --无归属
 
from 
data_build.dw_order_sku_promotion_v1 t --订单明细表
--data_or.dm_copy_dw_order_sku_promotion_v1_view t
where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and store_type = '0'
and pay_status = 'PAY_SUCCESS'
--and store_code = '100078005'
and t.sku_class_code not in ('86','50')
and order_date between '2022-07-01' and '2022-09-30'
group by
t.store_code
,store_city) x
) a
LATERAL VIEW EXPLODE(a.tmp_column) exptbl as bool,val

union all

select
'23Q3' as record_date
,store_code
,store_city
,sale_days
,bool
,val
,val/sale_days as val_day
from(
select
x.store_code
,x.store_city
,x.sale_days
,MAP('日商',x.payable_price,'槟榔',x.betel_nut,'冰淇淋',x.ice_cream,'饼干',x.cookie,'干果',x.dried_fruit,'果脯',x.preserved_fruit,'加工食品',x.processed_food,'饮品站/饮品机',x.coffee_soybean_milk_self_service_drink,
'烈酒',x.spirits,'面包',x.bread,'FF萌煮',x.cute_boiling,'巧克力',x.chocolate,'FF热餐',x.hot_meal,'FF早餐酥饼',x.flaky_pastry,'肉脯',x.portly_or_obese_person,'生活杂货',x.daily_necessities,
'嗜好品',x.asaddictive_things,'FF炸烤制品',x.fried_baked_goods,'水饮',x.retained_fluid,'糖果',x.candy,'香烟',x.cigarette,'休闲食品',x.snack_food,'FF蒸包小吃',x.steamed_bun_snacks,'热饮料',x.hot_drinks
,'便当面条',x.bento_noodles,'饭团寿司',x.rice_and_sushi,'干货速食',x.dry_and_fast_food,'粮油调味',x.grain_and_oil_seasoning,'肉蛋果蔬',x.meat_eggs_fruits_and_vegetables,'乳饮',x.milk_drink,
'三明治汉堡',x.sandwich_burger,'特设商品',x.special_merchandise,'甜品及其他',x.dessert_fast_food_and_other,'非常规卖品',x.unconventional_sales_items,'无归属',x.no_attribution) AS tmp_column
FROM(
select
t.store_code
,t.store_city

--营业日
,count(distinct order_date) as sale_days

--折后销售额
,sum(payable_price) as payable_price --全部销售额

--折后销售额 按照商品拆分
,sum(case when sku_division_code in ('3604') then payable_price else 0 end) as betel_nut
,sum(case when sku_division_code in ('4201','4202','4203','4204','4205','7942') then payable_price else 0 end) as ice_cream
,sum(case when sku_division_code in ('3408','3407','3405','3406','4401','4402') then payable_price else 0 end) as cookie
,sum(case when sku_division_code in ('2501','2502','3602','4405','7936') then payable_price else 0 end) as dried_fruit
,sum(case when sku_division_code in ('2504','3603') then payable_price else 0 end) as preserved_fruit
,sum(case when sku_division_code in ('4001','4002','4003','4004','4005','4006','4007','4008','7940') then payable_price else 0 end) as processed_food
,sum(case when sku_division_code in ('5003','5004','5005','5006','5007','5008','5009','5010','5019','5020','0702','0706','0713','0715','0716','0717','0718',
'0719','0720','0721') then payable_price else 0 end) as coffee_soybean_milk_self_service_drink
,sum(case when sku_division_code in ('3101','3102','3103','3104','3105','3201','3202','3205','7931','7932') then payable_price else 0 end) as spirits
,sum(case when sku_division_code in ('2101','2102','2103','2104','2105','2106','2107','2108','2109') then payable_price else 0 end) as bread
,sum(case when sku_division_code in ('0501','0502','0503','0505','0508') then payable_price else 0 end) as cute_boiling
,sum(case when sku_division_code in ('3404') then payable_price else 0 end) as chocolate
,sum(case when sku_division_code in ('0301','0304') then payable_price else 0 end) as hot_meal
,sum(case when sku_division_code in ('0602') then payable_price else 0 end) as flaky_pastry
,sum(case when sku_division_code in ('3701','3702','3703','4406','7937') then payable_price else 0 end) as portly_or_obese_person
,sum(case when sku_division_code in ('2701','4009','6401','6402','6403','6404','6406','6407','6408','6501','6502','6503','6504','6601','6602','6701','6702','6703','6801',
'6802','6803','6804','6805','6806','7001','7002','7003','7004','7005','7006','7007','7008','7101','7103','7104','7105','7106','7107','7301','7302','7303','7701','7801',
'7802','7964','7965','7966','7967','7968','7970','7971','7973','7978','7985','7988','7989','8501','8502','8503','8801','8802','8804','8902') then payable_price else 0 end) as daily_necessities
,sum(case when sku_division_code in ('4101','4102','4103','4104','4105','4106','4407','7941') then payable_price else 0 end) asaddictive_things
,sum(case when sku_division_code in ('0302') then payable_price else 0 end) as fried_baked_goods
,sum(case when sku_division_code in ('1205','1206','1207','3001','3002','3003','3301','3302','3303','3304','3305','3306','3307','3309','7930','7933') then payable_price else 0 end) as retained_fluid
,sum(case when sku_division_code in ('3401','3402','3403','4403') then payable_price else 0 end) as candy
,sum(case when sku_division_code in ('6101','6102','6103') then payable_price else 0 end) as cigarette
,sum(case when sku_division_code in ('3501','3502','3503','3601','4404','7935') then payable_price else 0 end) as snack_food
,sum(case when sku_division_code in ('1501','1502','1503','1504','1505','1506','1507','1508','0303','0309','0310','0312','0313','0314','0601','0603','0604') then payable_price else 0 end) as steamed_bun_snacks
,sum(case when sku_division_code in ('3310') then payable_price else 0 end) as hot_drinks
,sum(case when sku_division_code in ('0103','0105','0106','0401','0402') then payable_price else 0 end) as bento_noodles
,sum(case when sku_division_code in ('0101','0102') then payable_price else 0 end) as rice_and_sushi --饭团寿司
,sum(case when sku_division_code in ('1001','1004','1209','1301','1302','1303','1304','1305','1306','1307','1402','1410','2212','2308','2503','2505','2601','2603','2604','2605',
'2606','2607','2608','3801','3810','4301','4302','4303') then payable_price else 0 end) as dry_and_fast_food --干货速食
,sum(case when sku_division_code in ('2506','3802','3803','3804','3805','3806','3807','3808','3809','3811','3812','3813','7938') then payable_price else 0 end) as grain_and_oil_seasoning --粮油调味
,sum(case when sku_division_code in ('1401','1403','1404','1405','1406','1407','1408','1409','1411','1412','1413','1414','1415','1416','1418','2201','2202','2203','2204','2205',
'2206','2207','2208','2209','2210','2211','2213','2301','2302','2303','2304','2305','2306','2307','2309','2310','2311','2312','2313','2314','2316','2401','2402','2403','2404',
'2406','2407','0801','0802','0805') then payable_price else 0 end) as meat_eggs_fruits_and_vegetables --肉蛋果蔬
,sum(case when sku_division_code in ('1201','1202','1203','1204','1208','3308','7912') then payable_price else 0 end) as milk_drink --乳饮
,sum(case when sku_division_code in ('0201','0202') then payable_price else 0 end) as sandwich_burger --三明治汉堡
,sum(case when sku_division_code in ('3409','3901','3904','3907','3909','3910','3911','6201','7201','7203','7209','7210','7211','7934','7972') then payable_price else 0 end) as special_merchandise --特设商品
,sum(case when sku_division_code in ('1101','1102','1103','1104','1105','1210','0204') then payable_price else 0 end) as dessert_fast_food_and_other --甜品及其他
,sum(case when sku_division_code in ('2702','2703','4408','5001','5002','7504','8201','8202','8203','8204','8205','8206','8207','8208','8209','8210','8211','8212','8215','8216',
'8217','8218','8220','8222','8223','8224','8225','8226','8401','8601','8602','8603','8604','8605','8606','8607','8608','8701','8702','8703','8704','8705','8706','9101','9102',
'9103','9104','9105','9106','9107','9108','9109','9110','9112','9113','9114','9115','9118','9201','9203','9204','9205','9206','9207','9208','9209','9210','9211','9212','9218',
'9301','9302','9303','9304','9305','9306','9307','9308','9310','9311','9312','9314','9315','9316','9317','9318','9319','9320','9321','9399','9401','9402','9403','9404','9405',
'9601','9602','9603','9604','9605','9606','9607','9701','9702','9703','9704','9705','9706','9707','9708','9709','9710','9711','9712','9713','9714','9715','9716','9717','9801',
'9802','9803','9804','9805','9806','9807','9808','9809','9810','9812','9816','9818','9821','9822','9901','0307','0308','0311','0315','0316','0804','0901','0902','0904','0905',
'0906') then payable_price else 0 end) as unconventional_sales_items --非常规卖品
,sum(case when sku_division_code not in ('0501','0502','0503','0505','0508','0301','0304','0602','0302','1501','1502','1503','1504','1505','1506','1507','1508','0303','0309',
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
'5006','5007','5008','5009','5010','5019','5020','0702','0706','0713','0715','0716','0717','0718','0719','0720','0721') then payable_price else 0 end) as no_attribution --无归属
 
from 
data_build.dw_order_sku_promotion_v1 t --订单明细表
--data_or.dm_copy_dw_order_sku_promotion_v1_view t
where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and store_type = '0'
and pay_status = 'PAY_SUCCESS'
--and store_code = '100078005'
and t.sku_class_code not in ('86','50')
and order_date between '2023-07-01' and '2023-09-30'
group by
t.store_code
,store_city) x
) a
LATERAL VIEW EXPLODE(a.tmp_column) exptbl as bool,val

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
with store_list as(
select
store_code
,bool
,store_city
,location_type
,1 as joinkey
from data_build.app_app_sale_by_category_v1_da
where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
group by
store_code
,bool
,store_city
,location_type
,1
),

date_list as(
select
date_add(date_key,7 - case when dayofweek(date_key) = 1 then 7 else dayofweek(date_key) - 1 end) as record_week
,1 as joinkey
from data_build.dim_date_ya_v2
where date_key between'2023-08-28' and date_format(date_sub(current_date(),1),'yyyy-MM-dd')
group by
date_add(date_key,7 - case when dayofweek(date_key) = 1 then 7 else dayofweek(date_key) - 1 end)
,1
),

date_store_list as(
select
a.record_week
,b.bool
,b.store_city
,b.location_type
,b.store_code
from date_list a
cross join store_list b on a.joinkey = b.joinkey
),

nine_sale as(
select
store_code
,bool
,nine_val_day
from data_build.app_app_sale_by_category_v1_da
where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and record_week = '2023-09-03'
),

nine_sale_null as(--剔除一些9月日商异常的门店
SELECT
store_code
from data_build.app_app_sale_by_category_v1_da
where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and record_week = '2023-09-03'
and bool = '日商'
and (nine_val_day < '1000' or nine_val_day is null)
),

all_week_list as(
select
a.record_week
,a.store_code
,a.store_city
,b.sale_days
,a.bool
,b.val
,b.val_day
,c.nine_val_day
,b.val_recovery
,a.location_type
,'全周' as is_working_day
from date_store_list a
left join data_build.app_app_sale_by_category_v1_da b on a.record_week = b.record_week and a.store_code = b.store_code and a.bool = b.bool and b.dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
left join nine_sale c on a.store_code = c.store_code and a.bool = c.bool
left join nine_sale_null d on a.store_code = d.store_code
where d.store_code is null
),

store_list_2 as(
select
store_code
,bool
,store_city
,location_type
,is_working_day
,1 as joinkey
from data_build.app_app_sale_by_category_workday_or_notworkday_v1_da
where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
group by
store_code
,bool
,store_city
,location_type
,is_working_day
,1
),

date_list_2 as(
select
date_add(date_key,7 - case when dayofweek(date_key) = 1 then 7 else dayofweek(date_key) - 1 end) as record_week
,is_working_day
,1 as joinkey
from data_build.dim_date_ya_v2
where date_key between'2023-08-28' and date_format(date_sub(current_date(),1),'yyyy-MM-dd')
group by
date_add(date_key,7 - case when dayofweek(date_key) = 1 then 7 else dayofweek(date_key) - 1 end)
,is_working_day
,1
),

date_store_list_2 as(
select
a.record_week
,b.bool
,b.store_city
,b.location_type
,b.store_code
,b.is_working_day
from date_list_2 a
cross join store_list_2 b on a.joinkey = b.joinkey
),

nine_sale_2 as(
select
store_code
,bool
,nine_val_day
,is_working_day
from data_build.app_app_sale_by_category_workday_or_notworkday_v1_da
where dt = date_format(date_sub(current_date(),1),'yyyyMMdd')
and record_week = '2023-09-03'
),

all_week_list_2 as(
select
a.record_week
,a.store_code
,a.store_city
,b.sale_days
,a.bool
,b.val
,b.val_day
,c.nine_val_day
,b.val_recovery
,a.location_type
,a.is_working_day
from date_store_list_2 a
left join data_build.app_app_sale_by_category_workday_or_notworkday_v1_da b on a.record_week = b.record_week and a.store_code = b.store_code and a.bool = b.bool and b.dt = date_format(date_sub(current_date(),1),'yyyyMMdd') and a.is_working_day = b.is_working_day
left join nine_sale_2 c on a.store_code = c.store_code and a.bool = c.bool and a.is_working_day = c.is_working_day
left join nine_sale_null d on a.store_code = d.store_code
where d.store_code is null
)

select *
from all_week_list
--where store_code = '100078005'
--where record_week in ('2023-09-03','2024-01-28')
--and bool = '日商'
union all
select 
distinct distinct *
from all_week_list_2
--where store_code = '100078005'
--where record_week in ('2023-09-03','2024-01-28')
--and bool = '日商'
