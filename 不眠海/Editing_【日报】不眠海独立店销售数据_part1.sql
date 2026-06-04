--soberhi_standalone_store_sale_detail_v2_19015
SELECT
    a.order_date                                                               AS order_date
  , b.store_name                                                               AS store_name
  , COUNT(DISTINCT a.order_no)                                                 AS order_cnt
  , SUM(a.sku_quantity)                                                        AS qty_cnt
  , COUNT(DISTINCT CASE
                       WHEN NOT (a.delivery_type = 'DELIVERY' OR a.order_business_type = 'TAKEAWAYV5') THEN a.order_no
    END)                                                                       AS pickup_order_cnt
  , SUM(CASE
            WHEN NOT (a.delivery_type = 'DELIVERY' OR a.order_business_type = 'TAKEAWAYV5') THEN a.sku_quantity
            ELSE 0
    END)                                                                       AS pickup_qty_cnt
  , COUNT(DISTINCT CASE
                       WHEN a.delivery_type = 'DELIVERY' THEN a.order_no
    END)                                                                       AS self_order_cnt
  , SUM(CASE WHEN a.delivery_type = 'DELIVERY' THEN a.sku_quantity ELSE 0 END) AS self_qty_sum
  , 1.0000 * SUM(CASE WHEN a.delivery_type = 'DELIVERY' THEN a.payable_price ELSE 0 END) /
    (SUM(CASE WHEN a.delivery_type = 'DELIVERY' THEN a.sell_price ELSE 0 END) +
     1e-10)                                                                    AS self_discount_rate
  , COUNT(DISTINCT CASE
                       WHEN a.order_business_type = 'TAKEAWAYV5' AND a.delivery_type = 'TAKEOUT' THEN a.order_no
    END)                                                                       AS third_order_cnt
  , COUNT(DISTINCT CASE WHEN c.order_source = 'MEITUAN' THEN a.order_no END)   AS meituan_order_cnt
  , SUM(CASE WHEN c.order_source = 'MEITUAN' THEN a.sku_quantity ELSE 0 END)   AS meituan_qty_sum
  , 1.0000 * SUM(CASE WHEN c.order_source = 'MEITUAN' THEN a.payable_price ELSE 0 END) /
    (SUM(CASE WHEN c.order_source = 'MEITUAN' THEN a.sell_price ELSE 0 END) +
     1e-10)                                                                    AS meituan_discount_rate
  , COUNT(DISTINCT CASE WHEN c.order_source = 'ELEME' THEN a.order_no END)     AS eleme_order_cnt
  , SUM(CASE WHEN c.order_source = 'ELEME' THEN a.sku_quantity ELSE 0 END)     AS eleme_qty_sum
  , 1.0000 * SUM(CASE WHEN c.order_source = 'ELEME' THEN a.payable_price ELSE 0 END) /
    (SUM(CASE WHEN c.order_source = 'ELEME' THEN a.sell_price ELSE 0 END) +
     1e-10)                                                                    AS eleme_discount_rate
FROM (
     SELECT
         order_date
       , store_code
       , order_no
       , sku_quantity
       , delivery_type
       , order_business_type
       , sell_price
       , payable_price
     FROM data_promotion.dm_promotion_store_detl_order_detail_info_da a
          --          LEFT JOIN default.dw_order_info_v3 b
--                    ON a.order_no = b.order_no AND b.dt = date_format(date_add('day', -1, CURRENT_DATE), '%Y%m%d')

     WHERE a.dt = date_format(date_add('day', -1, CURRENT_DATE), '%Y%m%d')
       AND a.order_status = 'FINISHED'
       AND a.order_date >= TIMESTAMP '2021-03-31'
       AND (a.sku_class_code = '50' OR a.sku_division_code = '0716')
       AND a.sku_quantity > 0
       AND COALESCE(a.pay_id, '0') <> '30112507801894'
       AND a.store_code IN ('100003226', '107000187', '100003676','100005116','100005378')
     ) a
         LEFT JOIN
     (
     SELECT
         store_code
       , store_name
     FROM default.dim_store_info
     WHERE dt = date_format(date_add('day', -1, CURRENT_DATE), '%Y%m%d')
     ) b ON a.store_code = b.store_code
         LEFT JOIN
     (
     SELECT
         order_no
       , extended_info['sub_business_type'] AS order_source
     FROM default.dw_order_info_v3
     WHERE dt = date_format(date_add('day', -1, CURRENT_DATE), '%Y%m%d')
       AND order_time >= TIMESTAMP '2021-03-31'
     GROUP BY 1, 2
     ) c ON a.order_no = c.order_no
GROUP BY 1, 2
ORDER BY 1 DESC, 2