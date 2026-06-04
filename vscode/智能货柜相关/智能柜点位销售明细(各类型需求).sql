--点位订单维度销售明细
--dw_order_sku_v1替换为default.dw_order_sku_v1_view_us_ab
SELECT order_no as `订单号`,order_date as `订单日期`,user_id as `user_id`,store_code as `点位code`,store_name as `点位名称`,sku_code as `商品code`,sku_name as `商品名称`,sku_quantity as `商品数量`,sell_price as `零售价`,payable_price as `支付金额`,discount_price as `优惠金额`,refund_price as `退款金额` 
from data_shop.dwd_dw_order_sku_v1_view a
WHERE dt = '20250107'
and order_business_type = 'SELFTAKE'
and pay_status = 'PAY_SUCCESS'
and store_code in ('100160702')
and order_date BETWEEN '2023-11-01' and '2025-04-30'

--点位订单销售明细(不同表同样效果)

SELECT order_no as `订单号`,order_date as `订单日期`,store_code as `点位code`,store_name as `点位名称`,sku_code as `商品code`,sku_name as `商品名称`,sku_quantity as `商品数量`,sell_price as `零售价`,payable_price as `支付金额`,discount_price as `优惠金额`,refund_price as `退款金额` 
from data_build.dw_order_sku_v1 
WHERE dt = date_format(date_sub(current_date,1),'yyyyMMdd') 
and order_business_type = 'SELFTAKE' 
and pay_status = 'PAY_SUCCESS' 
and store_code in ('100148751','100148750','100148749','100148748','100148746') 
and order_date BETWEEN '2025-07-17' and '2025-07-17'


--点位日销售数据（该表只有日gmv，并包含柜子维度）
SELECT * from data_autobox.dw_shelf_order_sales
WHERE dt = '20220911'
and shop_code in('40fe3523532e9f781feae18be4a4a5d2','334e74752153327b44487256cd540010','85a36521da673e39bc569cd4a1ac4dd8') 
and record_date between '2022-08-01' and '2022-08-31' 
ORDER BY record_date
LIMIT 5000

--点位日销售数据2（同上）
SELECT record_date as `销售日期`,shop_code as `点位ID`,shop_name as `点位名称`,sum(day_sum_sale) as `日销量` 
from data_autobox.dw_shelf_order_sales 
WHERE dt = '20231108' 
and shop_code in ('100118792') 
and record_date between '2024-07-01' and '2023-12-10' 
GROUP BY record_date,shop_code,shop_name 

--点位月销售额(柜子维度)
SELECT sum(day_sum_sale) as `销售额`, shop_code,shop_name,device_sn,substr(record_date,1,7) as `销售月份` 
from default.dw_shelf_order_sales 
WHERE dt = '20250513' 
and shop_code in ('100132717') 
and record_date between '2024-08-01' and '2025-04-30' 
GROUP BY shop_code,shop_name,device_sn,substr(record_date,1,7)

--点位月销售额--2(上表无数据时使用此sql)
SELECT sum(payable_price) as `销售额`
,a.store_code
,substr(order_date,1,7) as `销售月份` 
from data_build.dw_order_sku_v1 a
WHERE a.dt = date_format(date_sub(current_date(),1),'yyyyMMdd') 
and a.store_code in ('100165794',
'100165795',
'100165796',
'100165797',
'100166701',
'100166702',
'100166703')
and a.pay_status = 'PAY_SUCCESS'
and a.order_date between '2025-11-22' and '2026-01-20' 
GROUP BY a.store_code
,substr(order_date,1,7)


--北京商品销售数据(城市维度)
SELECT order_date,sku_code,sku_name as `商品名称`,sum(sku_quantity) as `商品数量`,sum(payable_price) as `销售额`,store_city 
from default.dw_order_sku_v1 
WHERE dt = '20220407' 
and order_business_type = 'SELFTAKE' 
and pay_status = 'PAY_SUCCESS' 
and store_city = '北京市' 
and order_date = '2022-04-06' 
GROUP BY order_date,sku_code,sku_name,store_city

--点位总GMV
SELECT count(DISTINCT(order_no)) as `订单数`,sum(payable_price) as `销售总额`,sum(sku_quantity) as `商品数量`,store_code as `点位code`,store_name as `点位名称`
from default.dw_order_sku_v1_view_us_ab
WHERE dt = '20250818' 
and order_business_type = 'SELFTAKE' 
and pay_status = 'PAY_SUCCESS' 
and store_code in ('100148751','100148750','100148749','100148748','100148746') 
and order_date BETWEEN '2024-07-30' and '2025-07-30'
GROUP BY store_code,store_name


--京东点位销售数据（京东大客户，点位多备份下）
SELECT substr(order_time,12,2) as `时段`,count(DISTINCT(order_no)) as `订单数`,sum(payable_price) as `销售总额`,sum(sku_quantity) as `商品数量`
from default.dw_order_sku_v1_view_us_ab
WHERE dt = '20220424' 
and order_business_type = 'SELFTAKE' 
and pay_status = 'PAY_SUCCESS' 
and store_code in ('153cd63b9b12b72d0db27240278c6075',
'047bba9941d6b5c1801391e6be326efc',
'9ec55e3d21bc7ff3e11560da1fe42207',
'5d37fdf6b1d9c8a8ff26fc659a106c63',
'f3ecf0cc0347dba42d9b3dfcd73504fc',
'b63b5296a9278e6f09b064ac83be0e99',
'08650c322863a64fa40fc69279f4b1a7',
'b6c733d913ffc30de30e11f7098d70be',
'a2717541f3c078a699a5e2a6096fbf93',
'5632cb483f3d399e9a86b4670e13df58',
'd322205311f87576989e631b53b36f72',
'da22e9d5ba0a531cfae3809144744fa3',
'b036d4c4c71670fa6c87f44a4d103ccd',
'05ff3b3b054d9575d6a0dfd7a632c589',
'93d8544214798cf5c2fdc732b8730008',
'7f22907d4acdef11c8b7ababc4d2cf5d',
'75015fe24ea4fb287a0999078d4667d5',
'44e49cc76c57dde1bc71c7795e067d68',
'8ed15702c40e14b7c323ad78fdf220e4',
'00b2c8baeb014ce5a815855bda513fa1',
'e09f1bdd3174c3859b9b51e78262e383',
'3b38a4988d31332957b8515ca17bd478',
'19e0149def228ef71c46090e174085b4',
'ca86efa5fba8aaeafdb0cdef5ac1f2f0',
'b439cce644c5328d65323e0671d3d816',
'f67379f8edfb23f5fb8024bb4a97af06',
'c14ed99a72ac852e098f4ab5ccb40bdb',
'4e650d02cbaa40b5144c90f47345e0d7',
'2606bd3504a8d9e55441b0d2ca5c7fd5',
'bafb7c86f69a79911b420a9e2341dcef',
'3c99f0e6e4e56cc07b315bea49ca599d',
'cb161054c9c1efa98890ac92968087af',
'06e62c9b29ecd59533b6ba9800c3437a',
'88cde13e4b2767b9452abc8ea5041eac',
'3af67f78451e1b81234693458cad0a12',
'e52cd0e0f4c81b8ff155b0de9ee532d7',
'71fa762b3927098f166a02af6940dc44',
'e967a9bbd3b1bcaed2f84866b5426703',
'883588046122607af95e137f8851d310',
'e19f23aa42e58f999f1d2407c5d30faf',
'0d7b9d6078cfd75b2d5d09599135d336',
'a92acca58a1eb5e635ae5ff8e9c42af7',
'ccf45944374f12c8ccc805ef654d7fcd',
'7d67180239b6c29116380042d607bb20',
'692777958b2833c9d52e42ab2c3bbe34',
'89bf9347f59eaa5dcfc9fda943b8d90b',
'48a4f48220a42c9a4652f3a3e132802e',
'6a5d3c6198c8cbb299e45d18b5b9e18b',
'aa2abdcea4329819b1498aaade15f327',
'd022a67334c0772364c8c24c7511ddf7',
'ba9b05d646ff5478aa538e56304b8902',
'33ede9703299580eef11e2d637d10e0d',
'b498dfd94f5fc7abe4b57a6325c6bf23',
'27fa16eae3f1739c69d24e47130a0a33',
'cdb79e0a0d0e4d8876ce0c2f683e9ea3',
'132e4e7efd8e2641ada6c160b21ce2c1',
'ac6a7f2bec2c5de65570774b8a782f4c',
'867c2d4309892297a41feae2493495db',
'1b31401f2b53e1c5d12e0649818a98e0',
'bdabb358f691311d7e0baec86bd7ef7c',
'5030d619b702038f94f153a901d0494f',
'b5a89c97bef5606985f88f09f6452019',
'251073cd71e9593134928b6b19ce6156',
'99380c38a19f780b8eb451e61e4967ca',
'553c7909163b2547f91d1f8676c17561',
'ee70c175d36a389623333b9ace172401',
'85bba88e3b388b30064777ed3742b1ce',
'594905f04778113aa26cae8f23dd5d2f',
'7a19dd0d8106f79dad640d8e2cb66474',
'443e3c2e620865fa6aa701ff7d96283f',
'3e765b3942af198059392fc6b5eff1b8',
'473fe5a5691fe874d17f4da98b75a16c',
'0f87a9f9965de43d777a14d893dd5894',
'6ba276116b058d05058646c2ad601d05',
'fab8193a526acbd0c0a39a11711a34ab',
'33c8e6b09d41e5c8783e50657c861d66',
'bedd3cd0c339ebfc1b7d7a79ef4eb4cc',
'31c6bbcdd2dd1f1f82e12753d3847b85',
'85e6a110e139b491295ea3bc34cb2a0e',
'b7ee1ef80364c796ee19138589d6082f',
'b07fbb2ace84b545b8ba1139d15342b0',
'93e2d5e7e3a3868c00d3aff2421eff39',
'fb2925203da272d27aa219ec75e6c920',
'3fb6e38e82ccd34ebcf0c8a910e9f789',
'5e9409cd7ee0168fec5008f9146a1909',
'7d47847b10a7d91d1205803719c20dee',
'68c8f912e0c823cef020622358ace170',
'6a4c805d68e31a2196ea5b59c7e3b0a7',
'8c2e6c6305c7ebdcfee08582667677df',
'8102192bdfb4896ca9588c0649d2efaa',
'9f9792a9781daabc80c84c372ba88ec0',
'6a7a68cd2f4e0e54cd60a61adb0c799c',
'2eb5073886984d61c50ce000ed4e689e',
'edea63127f0f060d10afc91e6371a338',
'187750c3d461cefcd5939fd0ba26b91f',
'a0a9334c1b4636c0029592545959cc09',
'e762d171a7168faaa72825ca1fab0776',
'8c99f1247aeddce7e2b776d6dd89e0dc',
'0a4336e3de33a1f396123b49e5aadcdb',
'efed52619ce85321d09af71648b9696e',
'8d237ab4a835e843eed9ddbfd56f8f37',
'772fd277a5e67ca6f63dc4b7b1e1e883',
'1f152052e882ee0dfde1ff28195ddb6a',
'24b72cf9cd6288d705f53e4203c5c89e',
'fa66633b7a0043fbbf652f351b764f15',
'0c5cef018fb1ce7763e7a533ade394ae',
'6d72108b42fa505b00dd7be0c60c2344',
'bff339802ba6675d38c21744ea8532bd',
'8ac9bd3d8d7b3d156c336c7f6ee0e6c1',
'e2cb28a5cd5b9275efa1eae6c1a02355',
'c85033ae2a93057ad7295f0b32dae570',
'e9cf4856432ff4298988c44dd0be65da',
'fb050a8f3a1bfc1a82877fb8da21f0f7',
'6aa7b1f5e7157c9a440e326c8ce906d2',
'18e8c1798124460c36ef680e9c0c9c6f',
'30348405d08016b435a9e3cf294c4699',
'40f13858a869b49db4c312bf37729ab2',
'1ddbdcfab1633efab83f22656c1ddfc7') 
and order_date BETWEEN '2022-09-01' and '2022-09-25'
GROUP BY substr(order_time,12,2)

--京东四月份各点位销售gmv（备份）
SELECT store_code,store_name,substr(order_date,1,7) as `销售月份`,sum(payable_price) as `销售总额`,count(DISTINCT(order_no)) as `订单数`,sum(sku_quantity) as `商品数量` 
from default.dw_order_sku_v1_view_us_ab 
WHERE dt = '20220509' 
and order_business_type = 'SELFTAKE' 
and pay_status = 'PAY_SUCCESS' 
and store_code in ('100144767','100147727','100146737','100147718','100147725','100150754','100144765','100149741','100149751','100150753','100150761','100145769','100145780','100147720','100149750','100149752','100150755','100151741','100153793','115025719','100146740','100145765','100147724','100150757','115025723','100143794','100146749','100150775','100153796','115025720','100144763','100146739','100150766','100150768','115025724','100145770','100149749','100143791','100144772','100145772','100146738','100149742','100150752','100150771','115025725','100144770','100144773','100144775','100145763','100145768','100149746','100153795','100143793','100144777','100145775','100145776','100149761','100144769','100146740','100149743','100150751','100151706','100152711','115025717','100145766','100146738','100143792','100145764','100149745','100150773','100145774','100149744','100150770','100150759','115025721','100144774','100144776','100145761','100145771','100147721','100150765','100152703','100145773','115025718','100144768','100150763','100150764','100150774','100152702','100145777','100146748','100147723','100149748','100143795','100146737','100150756','100150762','100147716','100152701','100152704','100145762','100146736','100147717','100147726','100149747','100150772','100152705','100153794','100145767','100150758','100150760','100145760','100146739','100147722','100150767','100145778','100147719','100150769','100144766','100144771','100144778','100146761') 
and order_date BETWEEN '2022-04-01' and '2022-04-30' 
GROUP BY substr(order_date,1,7),store_code,store_name


--单点位单sku销售数据
SELECT order_date as `订单日期`,order_no as `订单号`,user_id as `用户ID`,store_code as `点位ID`,store_name as `门店名称`,sku_code as `商品code`,sku_name as `商品名称`,sku_quantity as `商品数量`,payable_price as `实际支付金额`,refund_price as `退款金额`
from default.dw_order_sku_v1_view_us_ab
WHERE dt = '20220424' 
and order_business_type = 'SELFTAKE' 
and pay_status = 'PAY_SUCCESS' 
and store_code = '110038782'
and sku_code = '87010105'
and order_date BETWEEN '2019-08-01' and '2021-09-30'

--所有扶贫点位订单明细数据(天津扶贫点位备份)
SELECT order_no as `订单号`,order_date as `订单日期`,store_code as `点位code`,store_name as `点位名称`,sku_code as `商品code`,sku_name as `商品名称`,sku_quantity as `商品数量`,sell_price as `零售价`,payable_price as `支付金额`,discount_price as `优惠金额`,refund_price as `退款金额` 
from default.dw_order_sku_v1_view_us_ab
WHERE dt = '20220530' 
and order_business_type = 'SELFTAKE' 
and pay_status = 'PAY_SUCCESS' 
and store_name like '%扶贫%'
and order_date BETWEEN '2022-04-01' and '2022-04-30'

--点位编号，点位名称，商品名称，商品数量，支付金额
with desensitization as(
select
store_code,
store_name,
store_cvs_code,
display_name
from data_md.dm_md_dim_store_base_info_store_v1
where dt = date_format(date_sub(current_date(),2),'yyyyMMdd')
group by
store_code,
store_name,
store_cvs_code,
display_name)

SELECT
b.store_cvs_code as `点位code`,
b.display_name as `点位名称`,
a.sku_code as `商品code`,
a.sku_name as `商品名称`,
sum(sku_quantity) as `商品数量`,
sum(payable_price) as `支付金额`
from default.dw_order_sku_v1_view_us_ab a
left join desensitization b on a.store_code = b.store_code
WHERE a.dt = '20230505'
and order_business_type = 'SELFTAKE'
and pay_status = 'PAY_SUCCESS'
and b.store_cvs_code in ('100143791',)
and order_date BETWEEN '2023-04-01' and '2023-04-30'
group by 
b.store_cvs_code
,b.display_name
,a.sku_code
,a.sku_name

￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥
￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥
￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥￥
--智能货柜费用明细
--intelligence_container_costomer_fee_detailed
with kehu as
(
select
distinct t.customer_id,---客户编码
t.customer_progress---客户状态
from data_smartorder.dm_copy_app_mail_shelf_whole_process_info_view t
where t.dt=date_format(date_sub(current_date(),1),'yyyyMMdd')
)

select 
case a.settlement_cycle
when '1' then '年结' 
when '2' then '半年结' 
when '3' then '季结' 
when '4' then '月结' 
when '5' then '日结' 
else '其他' 
end `结算类型` ,

a.settlement_date_start `结算开始日期`,
a.settlement_date_end `结算结束日期`,
a.settlement_period `结算周期`,

case a.bill_status
when '0' then '待提交' 
when '1' then '审核中' 
when '2' then '已通过' 
when '3' then '已驳回' 
when '4' then '作废' 
else '其他' 
end `对账单状态` ,---对账单状态0：待提交，1：审核中，2：已通过，3：已驳回，4：作废

a.bill_code `对账单编号`,
a.customer_code `客户编号`,
a.customer_name `客户名称`,
a.agreement_code `协议编码`,
a.sign_body_code `签约主体编码`,
a.sign_body_name `签约主体名称`,
a.contract_code `合同编码`,
a.account_name `收款方账号名称`,
a.sign_company_code `签约公司编码`,
a.sign_company_name `签约公司名称`,

case a.fee_type
when '1' then '流水分成' 
when '2' then '点位费' 
when '3' then '电费' 
when '4' then '押金' 
else '其他' 
end `费用类型` ,

case a.cal_fee_type
when '0' then '按度数实报实销' 
when '1' then '按固定费用' 
else '其他' 
end `计费类型` ,---计费类型1:按度数实报实销、2:电费固定费用

a.expect_pay_date `对账单生成日期` ,
a.personal_tax `代扣个人所得税` ,
a.expect_pay_money `应付金额` ,
a.real_pay_money `实付金额` ,

case a.voucher_order
when '1' then '先票后款' 
when '2' then '先款后票' 
else '其他' 
end `开票顺序` ,---开票顺序（1:先票后款、2:先款后票）

case a.voucher_type
when '1' then '增值税专用发票' 
when '2' then '增值税普通发票' 
when '3' then '收据' 
else '其他' 
end `发票类型` ,

a.voucher_proportion `开票税率`,
a.flow_amount_without_tax `净销售流水金额（不含税）`,
a.flow_amount_with_tax `净销售流水金额（含税）`,

case a.benchmark_type
when '0' then '不含税' 
when '1' then '含税' 
else '其他' 
end `分成金额基准` ,---分成金额基准（0:不含税、1:含税）

a.flow_proportion `流水分成比例`,
a.loss_amount `盗损金额`,
a.loss_proportion `盗损比例基准`,
a.actual_loss_proportion `实际盗损比例`,

case a.voucher_status
when '0' then '未收票' 
when '1' then '已收票' 
else '其他' 
end `发票状态` ,---发票状态（0:未收票、1:已收票）

case a.settlement_status
when '0' then '待确认' 
when '1' then '已确认' 
else '其他' 
end `结算状态` ,---结算状态（0:待确认、1:已确认）

case a.pay_status
when '0' then '未生成' 
when '1' then '已付款' 
when '3' then '付款驳回' 
when '4' then '付款中' 
else '其他' 
end `付款状态` ,---付款状态（0:未付款、1:已付款）

a.point_location `点位编码`,
a.department_code `是否_KA`,

case a.city_code 
when '100' then '北京'
when '109' then '杭州'
when '110' then '南京'
when '123' then '天津'
when '125' then '广州'
when '101' then '上海'
when '115' then '深圳'
when '102' then '保定' 
when '119' then '武汉' 
else '其他'
end `城市`, 

c.customer_progress `客户状态`,
b.bd `负责BD域名`,
d.user_namecn `负责BD中文名`,

case d.is_in_hire
when '0' then '离职' 
when '1' then '在职' 
else '其他' 
end `负责BD状态` ,

d.manager_user_name `负责BD上级域名`,
e.user_namecn `负责BD上级`,
int(1) `统计量`

from default.pdw_finance_buffett_svmachine_bill_sales_flow_statistic a
left join default.pdw_opc_crm_customer b on a.customer_code =b.id and b.dt=date_format(date_sub(current_date(),1),'yyyyMMdd')
left join default.dim_user_hr_view_nc_us d on b.bd=d.user_name and d.dt=date_format(date_sub(current_date(),1),'yyyyMMdd')
left join default.dim_user_hr_view_nc_us e on d.manager_user_name=e.user_name and e.dt=date_format(date_sub(current_date(),1),'yyyyMMdd')
left join kehu as c on a.customer_code =c.customer_id
where a.dt=date_format(date_sub(current_date(),1),'yyyyMMdd')
--and a.pay_status in(0,3)
--and a.bill_status =2
and a.data_source_type!='PEOPLE'
--and a.fee_type =1
and a.is_deleted =0
and a.is_settle =0
--and a.city_code in('100','109','110','123','125','101','115')