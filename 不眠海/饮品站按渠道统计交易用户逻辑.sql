 drop table if exists data_promotion.tmp_promotion_user_source_order_info_du;
        create table data_promotion.tmp_promotion_user_source_order_info_du as
                     select
                         order_date,
                         user_id,
                         order_no,
                         sku_type,
                         store_code,
                         store_name,
                         first_type,
                         ratio,
                         business_type,
                         activity_id,
                         activity_name,
                         sell_price,
                         payable_price,
                         store_city,
                         tag,
                         inout_type
                     from
                     (
                         select
                             order_date,
                             user_id,
                             order_no,
                             sku_type,
                             store_code,
                             store_name,
                             first_type,
                             ratio,
                             business_type,
                             activity_id,
                             activity_name,
                             sell_price,
                             payable_price,
                             store_city,
                             case when activity_id IN (
                                                       '1220097152088511'
                                                       ,'1220096002712500'
                                                       ,'1220098252152640'
                                                       ,'1220098282513420'
                                                       ,'1220098683782831'
                                                       ,'1220100863580561'
                                                       ,'1220102545379765'
                                                       ,'1220102585889578'
                                                       ,'1220103869278665'
                                                       ,'1220104176346466'
                                                       ,'1220104795356296'
                                                       ,'1220104977826805'
                                                       ,'1220104957952057'
                                                       ,'1220106926807724'
                                                       ,'1220106922110146'
                                                      ) then '清库存活动'
                                  when activity_name like '%BEETEA_DF%' then '动促活动'
                                  when activity_id in ('1220099923321398','1220099905803134') then '39/59大促'
                                  when activity_id = '1220108063033445' then '生日季'
                                  when activity_id = '1220110298379209' then '划线价促销活动'
                                  when activity_id in ('1220111257490795','1220111274441058') then '奥奥草莓&北海道dirty49折促销'
                                  when activity_id = '1220111400414779' then '第二件N折'
                                  when business_type IN ('SELFPOS', 'SELFPOSBLIPAY', 'SELFPAY') and activity_id is not null then '加购-有活动'
                                  when business_type IN ('SELFPOS', 'SELFPOSBLIPAY', 'SELFPAY') and activity_id is null then '加购-无活动'
                                  when business_type NOT IN ('SELFPOS', 'SELFPOSBLIPAY', 'SELFPAY') and strategy_codes in ('coupon_drink_0406','soberHiOfflinePackage','coupon_drink_0328') then '店内'
                                  when business_type NOT IN ('SELFPOS', 'SELFPOSBLIPAY', 'SELFPAY') and b.coupon_id is not null then inout_type
                                  else '其他' end as inout_type,
                             case when business_type NOT IN ('SELFPOS', 'SELFPOSBLIPAY', 'SELFPAY') and strategy_codes = 'coupon_drink_0406' then '饮品站结算页券包'
                                  when business_type NOT IN ('SELFPOS', 'SELFPOSBLIPAY', 'SELFPAY') and strategy_codes in ('soberHiOfflinePackage','coupon_drink_0328') then '饮品站月卡'
                                  when business_type NOT IN ('SELFPOS', 'SELFPOSBLIPAY', 'SELFPAY') and b.coupon_id is not null then channel_tag
                                  else null end as tag
                         from
                         (
                             select
                                 order_date,
                                 user_id,
                                 a.store_name as store_name,
                                 store_code,
                                 a.order_no,
                                 sku_type,
                                 case when b.order_no is null then '1-非首单' when b.order_no is not null then '2-首单' end as first_type,
                                 business_type,
                                 a.activity_id,
                                 d.activity_name,
                                 coupon_id,
                                 case when c.consume_order_no is not null then c.strategy_code else '' end as strategy_codes,
                                 sell_price,
                                 payable_price,
                                 store_city,
                                 ratio
                             from
                             (
                                 select
                                     order_date,
                                     order_no,
                                     sku_type,
                                     a.user_id,
                                     store_name,
                                     a.store_code,
                                     business_type,
                                     activity_id,
                                     coupon_id,
                                     --strategy_codes,
                                     sell_price,
                                     payable_price,
                                     store_city,
                                     c.ratio
                                 from
                                 (
                                     select
                                         order_date,
                                         order_no,
                                         type as sku_type,
                                         a.user_id,
                                         store_name,
                                         store_code,
                                         order_business_type as business_type,
                                         activity_id,
                                         coupon_id,
                                         --toString(sku_activity.activity_strategy_code[1]) as strategy_codes,
                                         sell_price,
                                         payable_price,
                                         order_time,
                                         store_city
                                     from data_promotion.dm_promotion_beetea_detl_order_detail_info_da a
                                     left join data_promotion.ods_uploads_dm_promotion_beetea_sku_list_info b on a.sku_code=b.sku_code
                                     where dt='$DATE'
                                     and order_date >= date_sub(current_date(),180)
                                     and order_status != 'CANCELLED'
                                     and order_date>='2021-03-31'
                                     and (user_id!='30112507801894' or user_id is null or user_id='null')
                                     and sku_quantity>0
                                     and (sku_division_code='0716' or sku_class_code='50')
                                     and order_business_type!='TAKEAWAYV5'
                                 ) a
                                 inner join
                                 (--取门店类型，取高效门店or低消门店
                                 select
                                 store_code
                                 ,case when ratio='typeB1_store' then 'B1类店'
                                        when ratio='typeB2_store' then 'B2类店'
                                     when ratio='typeA1_store' then 'A1类店'
                                     when ratio='typeA2_store' then 'A2类店'
                                     when ratio='typeC1_store' then 'C1类店'
                                     when ratio='typeC2_store' then 'C2类店'
                                     when ratio='typeC3_store' then 'C3类店'
                                     when ratio='typeNew_store' then 'D类店' end as ratio
                                 ,dt
                                 ,cast(concat(substring(dt,1,4),'-',substring(dt,5,2),'-',substring(dt,7,2)) as date) as dt_date
                                 from data_promotion.dm_promotion_weekcard_special_shop_info_v3 t
                                 where dt between  '20220215' and '$DATE'
                                 and batch_no in ('beeTea_store_classify_v2')

                                 ) c on a.store_code=c.store_code and a.order_date=date_add(c.dt_date,1) --当天订单看前一天的门店类型标签
                             ) a
                             left join
                             ( --取用户首次下饮品站订单的订单号
                                 select
                                     order_no
                                 from
                                 (
                                     select
                                         user_id,
                                         order_no,
                                         order_time,
                                         row_number()over(partition by user_id order by order_time) as rk
                                     from
                                     (
                                         select
                                             order_time,
                                             order_no,
                                             user_id
                                         from data_promotion.dm_promotion_beetea_detl_order_detail_info_da a
                                         where dt='$DATE'
                                         and order_status != 'CANCELLED'
                                         and order_date>='2021-03-31'
                                         and (user_id!='30112507801894' or user_id is null or user_id='null')
                                         and sku_quantity>0
                                         and (sku_division_code='0716' or sku_class_code='50')
                                     ) a
                                 ) a
                                 where rk=1
                             ) b on a.order_no=b.order_no
                             left join
                             (select --店内，饮品站结算页券包
                                 get_json_object(track_data,'$.consumeorderNoStr') as consume_order_no
                                ,get_json_object(track_data,'$.strategyCode') as strategy_code
                             from dw_promotion_coupon_usage a
                             where dt='$DATE'
                             and (get_json_object(track_data,'$.strategyCode') in ('coupon_drink_0406','soberHiOfflinePackage','coupon_drink_0328'))
                             and coupon_status = 'USED'
                             --and amount=1.9
                             group by get_json_object(track_data,'$.consumeorderNoStr')
                                     ,get_json_object(track_data,'$.strategyCode')
                             ) c on a.order_no=c.consume_order_no
                             left join
                             (select activity_id,activity_name
                             from dim_promotion_info
                             where dt='$DATE'
                             ) d on a.activity_id=d.activity_id
                         ) a
                         left join
                         (select
                             coupon_id,
                             coupon_amount,
                             type,
                             inout_type,
                             channel_tag
                         from data_promotion.ods_uploads_beetea_new_user_coupon_id a
                         ) b on a.coupon_id=b.coupon_id
                     ) a
                     ;


         insert overwrite table data_promotion.${TABLE_NAME} partition (dt='$DATE')

         select
             order_date,
             case when first_type IS NULL then '0-汇总'
               else first_type end as first_type,
             case when ratio IS NULL then '1-汇总'
               else ratio end as ratio,
             case when sku_type IS NULL then '0-汇总'
               else sku_type end as sku_type,
             '' as past_90_orders,
             store_num,
             all_user_num,
             all_discount_rate,
             coalesce(diannei_quanbao_user_num,0) as diannei_quanbao_user_num,
             coalesce(diannei_quanbao_user_num_rate,0) as diannei_quanbao_user_num_rate,
             coalesce(diannei_quanbao_discount_rate,0) as diannei_quanbao_discount_rate,
             coalesce(diannei_show_user_num,0) as diannei_show_user_num,
             coalesce(diannei_show_user_rate,0) as diannei_show_user_rate,
             coalesce(diannei_show_discount_rate,0) as diannei_show_discount_rate,
             coalesce(diannei_saoma_user_num,0) as diannei_saoma_user_num,
             coalesce(diannei_saoma_user_rate,0) as diannei_saoma_user_rate,
             coalesce(diannei_saoma_discount_rate,0) as diannei_saoma_discount_rate,
             coalesce(diannei_shiyin_user_num,0) as diannei_shiyin_user_num,
             coalesce(diannei_shiyin_user_rate,0) as diannei_shiyin_user_rate,
             coalesce(diannei_shiyin_discount_rate,0) as diannei_shiyin_discount_rate,
             coalesce(diannei_purchase_user_num,0) as diannei_purchase_user_num,
             coalesce(diannei_purchase_user_rate,0) as diannei_purchase_user_rate,
             coalesce(diannei_purchase_discount_rate,0) as diannei_purchase_discount_rate,
             coalesce(dianwai_message_user_num,0) as dianwai_message_user_num,
             coalesce(dianwai_message_user_rate,0) as dianwai_message_user_rate,
             coalesce(dianwai_message_discount_rate,0) as dianwai_message_discount_rate,
             coalesce(dianwai_kouling_user_num,0) as dianwai_kouling_user_num,
             coalesce(dianwai_kouling_user_rate,0) as dianwai_kouling_user_rate,
             coalesce(dianwai_kouling_discount_rate,0) as dianwai_kouling_discount_rate,
             coalesce(dianwai_liebian_user_num,0) as dianwai_liebian_user_num,
             coalesce(dianwai_liebian_user_rate,0) as dianwai_liebian_user_rate,
             coalesce(dianwai_liebian_discount_rate,0) as dianwai_liebian_discount_rate,
             coalesce(other_user_num,0) as other_user_num,
             coalesce(other_user_rate,0) as other_user_rate,
             coalesce(other_discount_rate,0) as other_discount_rate,

             coalesce(buchang_coupon_user_num,0) as buchang_coupon_user_num,
             coalesce(buchang_coupon_user_rate,0) as buchang_coupon_user_rate,
             coalesce(buchang_coupon_discount_rate,0) as buchang_coupon_discount_rate,
             coalesce(clean_kucun_user_num,0) as clean_kucun_user_num,
             coalesce(clean_kucun_user_rate,0) as clean_kucun_user_rate,
             coalesce(clean_kucun_discount_rate,0) as clean_kucun_discount_rate,

             coalesce(community_user_num,0) as community_user_num,
             coalesce(community_user_rate,0) as community_user_rate,
             coalesce(community_discount_rate,0) as community_discount_rate,
             coalesce(dmpage_user_num,0) as dmpage_user_num,
             coalesce(dmpage_user_rate,0) as dmpage_user_rate,
             coalesce(dmpage_discount_rate,0) as dmpage_discount_rate,
             coalesce(ditui_user_num,0) as ditui_user_num,
             coalesce(ditui_user_rate,0) as ditui_user_rate,
             coalesce(ditui_discount_rate,0) as ditui_discount_rate,
             coalesce(group_user_num,0) as group_user_num,
             coalesce(group_user_rate,0) as group_user_rate,
             coalesce(group_discount_rate,0) as group_discount_rate,
             coalesce(meituan_coupon_user_num,0) as meituan_coupon_user_num,
             coalesce(meituan_coupon_user_rate,0) as meituan_coupon_user_rate,
             coalesce(meituan_coupon_discount_rate,0) as meituan_coupon_discount_rate,
             case when store_city IS NULL then '0-汇总'
               else store_city end as store_city,
             coalesce(diannei_yueka_user_num,0) as diannei_yueka_user_num,
             coalesce(diannei_yueka_user_num_rate,0) as diannei_yueka_user_num_rate,
             coalesce(diannei_yueka_discount_rate,0) as diannei_yueka_discount_rate,

             coalesce(discount_dc_user_num,0) as discount_dc_user_num,
             coalesce(discount_dc_user_rate,0) as discount_dc_user_rate,
             coalesce(discount_dc_discount_rate,0) as discount_dc_discount_rate,

             coalesce(srj_user_num,0) as srj_user_num,
             coalesce(srj_user_rate,0) as srj_user_rate,
             coalesce(srj_discount_rate,0) as srj_discount_rate,

             coalesce(jxhb_user_num,0) as jxhb_user_num,
             coalesce(jxhb_user_rate,0) as jxhb_user_rate,
             coalesce(jxhb_discount_rate,0) as jxhb_discount_rate,

             coalesce(hxj_user_num,0) as hxj_user_num,
             coalesce(hxj_user_rate,0) as hxj_user_rate,
             coalesce(hxj_discount_rate,0) as hxj_discount_rate,

             coalesce(cmbhd_user_num,0) as cmbhd_user_num,
             coalesce(cmbhd_user_rate,0) as cmbhd_user_rate,
             coalesce(cmbhd_discount_rate,0) as cmbhd_discount_rate,

             coalesce(dc_user_num,0) as dc_user_num,
             coalesce(dc_user_rate,0) as dc_user_rate,
             coalesce(dc_discount_rate,0) as dc_discount_rate,

             coalesce(secondnz_user_num,0) as secondnz_user_num,
             coalesce(secondnz_user_rate,0) as secondnz_user_rate,
             coalesce(secondnz_discount_rate,0) as secondnz_discount_rate

         from
         (
             select
                 order_date,
                 first_type,
                 ratio,
                 sku_type,
                 store_city,
                 count(distinct store_code) as store_num,
                 count(distinct user_id) as all_user_num,
                 sum(payable_price)/sum(sell_price) as all_discount_rate,

                 count(distinct IF(inout_type='店内' and tag in ('饮品站结算页券包'),user_id,null)) as diannei_quanbao_user_num,
                 count(distinct IF(inout_type='店内' and tag in ('饮品站结算页券包'),user_id,null))/count(distinct user_id) as diannei_quanbao_user_num_rate,
                 sum(IF(inout_type='店内' and tag in ('饮品站结算页券包'),payable_price,null))/sum(IF(inout_type='店内' and tag in ('饮品站结算页券包'),sell_price,0)) as diannei_quanbao_discount_rate,
        --新增
                 count(distinct IF(inout_type='店内' and tag in ('饮品站月卡'),user_id,null)) as diannei_yueka_user_num,
                 count(distinct IF(inout_type='店内' and tag in ('饮品站月卡'),user_id,null))/count(distinct user_id) as diannei_yueka_user_num_rate,
                 sum(IF(inout_type='店内' and tag in ('饮品站月卡'),payable_price,null))/sum(IF(inout_type='店内' and tag in ('饮品站月卡'),sell_price,0)) as diannei_yueka_discount_rate,

                 count(distinct IF(inout_type='店内' and tag in ('支付成功通知'),user_id,null)) as diannei_show_user_num,
                 count(distinct IF(inout_type='店内' and tag in ('支付成功通知'),user_id,null))/count(distinct user_id) as diannei_show_user_rate,
                 sum(IF(inout_type='店内' and tag in ('支付成功通知'),payable_price,null))/sum(IF(inout_type='店内' and tag in ('支付成功通知'),sell_price,null)) as diannei_show_discount_rate,


                 count(distinct IF(inout_type='店内' and tag='店内扫码',user_id,null)) as diannei_saoma_user_num,
                 count(distinct IF(inout_type='店内' and tag='店内扫码',user_id,null))/count(distinct user_id) as diannei_saoma_user_rate,
                 sum(IF(inout_type='店内' and tag='店内扫码',payable_price,null))/sum(IF(inout_type='店内' and tag='店内扫码',sell_price,null)) as diannei_saoma_discount_rate,

                 count(distinct IF(inout_type='店内' and tag='试饮渠道',user_id,null)) as diannei_shiyin_user_num,
                 count(distinct IF(inout_type='店内' and tag='试饮渠道',user_id,null))/count(distinct user_id) as diannei_shiyin_user_rate,
                 sum(IF(inout_type='店内' and tag='试饮渠道',payable_price,null))/sum(IF(inout_type='店内' and tag='试饮渠道',sell_price,null)) as diannei_shiyin_discount_rate,

                 count(distinct IF(inout_type='加购-有活动',user_id,null)) as diannei_purchase_user_num,
                 count(distinct IF(inout_type='加购-有活动',user_id,null))/count(distinct user_id) as diannei_purchase_user_rate,
                 sum(IF(inout_type='加购-有活动',payable_price,null))/sum(IF(inout_type='加购-有活动',sell_price,null)) as diannei_purchase_discount_rate,

                 count(distinct IF(inout_type='店外' and tag='通知触达',user_id,null)) as dianwai_message_user_num,
                 count(distinct IF(inout_type='店外' and tag='通知触达',user_id,null))/count(distinct user_id) as dianwai_message_user_rate,
                 sum(IF(inout_type='店外' and tag='通知触达',payable_price,null))/sum(IF(inout_type='店外' and tag='通知触达',sell_price,null)) as dianwai_message_discount_rate,

                 count(distinct IF(inout_type='店外' and tag='口令分享',user_id,null)) as dianwai_kouling_user_num,
                 count(distinct IF(inout_type='店外' and tag='口令分享',user_id,null))/count(distinct user_id) as dianwai_kouling_user_rate,
                 sum(IF(inout_type='店外' and tag='口令分享',payable_price,null))/sum(IF(inout_type='店外' and tag='口令分享',sell_price,null)) as dianwai_kouling_discount_rate,

                 count(distinct IF(inout_type='店外' and tag='裂变',user_id,null)) as dianwai_liebian_user_num,
                 count(distinct IF(inout_type='店外' and tag='裂变',user_id,null))/count(distinct user_id) as dianwai_liebian_user_rate,
                 sum(IF(inout_type='店外' and tag='裂变',payable_price,null))/sum(IF(inout_type='店外' and tag='裂变',sell_price,null)) as dianwai_liebian_discount_rate,

                 count(distinct IF(inout_type='店外' and tag='被取消补偿券',user_id,null)) as buchang_coupon_user_num,
                 count(distinct IF(inout_type='店外' and tag='被取消补偿券',user_id,null))/count(distinct user_id) as buchang_coupon_user_rate,
                 sum(IF(inout_type='店外' and tag='被取消补偿券',payable_price,null))/sum(IF(inout_type='店外' and tag='被取消补偿券',sell_price,null)) as buchang_coupon_discount_rate,

                 count(distinct IF(inout_type='清库存活动',user_id,null)) as clean_kucun_user_num,
                 count(distinct IF(inout_type='清库存活动',user_id,null))/count(distinct user_id) as clean_kucun_user_rate,
                 sum(IF(inout_type='清库存活动',payable_price,null))/sum(IF(inout_type='清库存活动',sell_price,null)) as clean_kucun_discount_rate,

                 count(distinct IF(inout_type='动促活动',user_id,null)) as dc_user_num,
                 count(distinct IF(inout_type='动促活动',user_id,null))/count(distinct user_id) as dc_user_rate,
                 sum(IF(inout_type='动促活动',payable_price,null))/sum(IF(inout_type='动促活动',sell_price,null)) as dc_discount_rate,

                 count(distinct IF(inout_type='店外' and tag='社群营销',user_id,null)) as community_user_num,
                 count(distinct IF(inout_type='店外' and tag='社群营销',user_id,null))/count(distinct user_id) as community_user_rate,
                 sum(IF(inout_type='店外' and tag='社群营销',payable_price,null))/sum(IF(inout_type='店外' and tag='社群营销',sell_price,null)) as community_discount_rate,

                 count(distinct IF(inout_type='店外' and tag='外卖DM单',user_id,null)) as dmpage_user_num,
                 count(distinct IF(inout_type='店外' and tag='外卖DM单',user_id,null))/count(distinct user_id) as dmpage_user_rate,
                 sum(IF(inout_type='店外' and tag='外卖DM单',payable_price,null))/sum(IF(inout_type='店外' and tag='外卖DM单',sell_price,null)) as dmpage_discount_rate,

                 count(distinct IF(inout_type='店外' and tag='地推',user_id,null)) as ditui_user_num,
                 count(distinct IF(inout_type='店外' and tag='地推',user_id,null))/count(distinct user_id) as ditui_user_rate,
                 sum(IF(inout_type='店外' and tag='地推',payable_price,null))/sum(IF(inout_type='店外' and tag='地推',sell_price,null)) as ditui_discount_rate,

                 count(distinct IF(inout_type='社群' and tag='社群',user_id,null)) as group_user_num,
                 count(distinct IF(inout_type='社群' and tag='社群',user_id,null))/count(distinct user_id) as group_user_rate,
                 sum(IF(inout_type='社群' and tag='社群',payable_price,null))/sum(IF(inout_type='社群' and tag='社群',sell_price,null)) as group_discount_rate,

                 count(distinct If(inout_type='店外' and tag='美团营销',user_id,NULL)) AS meituan_coupon_user_num,
                 count(distinct If(inout_type='店外' and tag='美团营销',user_id,NULL))/count(distinct user_id) AS meituan_coupon_user_rate,
                 sum(IF(inout_type='店外' and tag='美团营销',payable_price,null))/sum(IF(inout_type='店外' and tag='美团营销',sell_price,null)) as meituan_coupon_discount_rate,
        --新增
                 count(distinct IF(inout_type='39/59大促',user_id,null)) as discount_dc_user_num,
                 count(distinct IF(inout_type='39/59大促',user_id,null))/count(distinct user_id) as discount_dc_user_rate,
                 sum(IF(inout_type='39/59大促',payable_price,null))/sum(IF(inout_type='39/59大促',sell_price,null)) as discount_dc_discount_rate,

                 count(distinct IF(inout_type='生日季',user_id,null)) as srj_user_num,
                 count(distinct IF(inout_type='生日季',user_id,null))/count(distinct user_id) as srj_user_rate,
                 sum(IF(inout_type='生日季',payable_price,null))/sum(IF(inout_type='生日季',sell_price,null)) as srj_discount_rate,

                 count(distinct If((inout_type='惊喜红包') or (inout_type = '店外' and tag='口令分享'),user_id,NULL)) AS jxhb_user_num,
                 count(distinct If((inout_type='惊喜红包') or (inout_type = '店外' and tag='口令分享'),user_id,NULL))/count(distinct user_id) AS jxhb_user_rate,
                 sum(IF((inout_type='惊喜红包') or (inout_type = '店外' and tag='口令分享'),payable_price,null))/sum(IF((inout_type='惊喜红包') or (inout_type = '店外' and tag='口令分享'),sell_price,null)) as jxhb_discount_rate,
        --更新

                 count(distinct IF(inout_type='划线价促销活动',user_id,null)) as hxj_user_num,
                 count(distinct IF(inout_type='划线价促销活动',user_id,null))/count(distinct user_id) as hxj_user_rate,
                 sum(IF(inout_type='划线价促销活动',payable_price,null))/sum(IF(inout_type='划线价促销活动',sell_price,null)) as hxj_discount_rate,

                 count(distinct IF(inout_type='奥奥草莓&北海道dirty49折促销',user_id,null)) as cmbhd_user_num,
                 count(distinct IF(inout_type='奥奥草莓&北海道dirty49折促销',user_id,null))/count(distinct user_id) as cmbhd_user_rate,
                 sum(IF(inout_type='奥奥草莓&北海道dirty49折促销',payable_price,null))/sum(IF(inout_type='奥奥草莓&北海道dirty49折促销',sell_price,null)) as cmbhd_discount_rate,

                 count(distinct IF(inout_type='第二件N折',user_id,null)) as secondnz_user_num,
                 count(distinct IF(inout_type='第二件N折',user_id,null))/count(distinct user_id) as secondnz_user_rate,
                 sum(IF(inout_type='第二件N折',payable_price,null))/sum(IF(inout_type='第二件N折',sell_price,null)) as secondnz_discount_rate,

                 count(distinct IF(inout_type not in ('店内','加购-有活动','店外','清库存活动','动促活动','39/59大促','惊喜红包','生日季','划线价促销活动','奥奥草莓&北海道dirty49折促销','第二件N折'),user_id,null)) as other_user_num,
                 count(distinct IF(inout_type not in ('店内','加购-有活动','店外','清库存活动','动促活动','39/59大促','惊喜红包','生日季','划线价促销活动','奥奥草莓&北海道dirty49折促销','第二件N折'),user_id,null))/count(distinct user_id) as other_user_rate,
                 sum(IF(inout_type not in ('店内','加购-有活动','店外','清库存活动','动促活动','39/59大促','惊喜红包','生日季','划线价促销活动','奥奥草莓&北海道dirty49折促销','第二件N折'),payable_price,null))/sum(IF(inout_type not in ('店内','加购-有活动','店外','清库存活动','动促活动','39/59大促','惊喜红包','生日季','划线价促销活动','奥奥草莓&北海道dirty49折促销','第二件N折'),sell_price,null)) as other_discount_rate

             from data_promotion.tmp_promotion_user_source_order_info_du a
             -- where sku_type='0-汇总'
             group by order_date,first_type,ratio,sku_type,store_city
             with CUBE
         ) a
         where order_date>'1970-01-01'
         ;