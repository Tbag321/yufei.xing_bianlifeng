with kehu as
(
select
distinct t.customer_id,---客户编码
t.customer_progress---客户状态
from data_autobox.app_mail_shelf_whole_process_info t
where t.dt='${today-1}'
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

from pdw_finance_buffett_svmachine_bill_sales_flow_statistic a
left join pdw_opc_crm_customer b on a.customer_code =b.id and b.dt='${today-1}'
left join default.dim_user_hr_view_nc_us d on b.bd=d.user_name and d.dt='${today-1}'
left join default.dim_user_hr_view_nc_us e on d.manager_user_name=e.user_name and e.dt='${today-1}'
left join kehu as c on a.customer_code =c.customer_id
where a.dt='${today-1}'
and a.pay_status in(0,3)
and a.bill_status =2
and a.data_source_type!='PEOPLE'
and a.fee_type =1
and a.is_deleted =0
and a.is_settle =0
and a.city_code in('100','109','110','123','125','101','115')