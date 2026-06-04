--工作日列表
with work_day_list as(
select
date_key
,case when is_working_day = 1 then '工作日' else '非工作日' end as is_working_day
from default.dim_date_ya_v2
group by
date_key
,is_working_day
),

store_open_info as(
select
store_code
,roster_date
,bach_status
from data_smartorder.app_store_open_info_quick_reference_night_d0_da
where dt = 20230327
)

select
t.store_code
,t.roster_date
,b.is_working_day
,c.bach_status
,sum(payable_price_on_site_ff_ordinary) as `折后日商-到店-FF-正常单`
,sum(payable_price_on_site_tobacco_ordinary) as `折后日商-到店-香烟-正常单`
,sum(payable_price_on_site_other_ordinary) as `折后日商-到店-其他-正常单`
,sum(payable_price_delivery_ff_ordinary) as `折后日商-外卖FF-正常单`
,sum(payable_price_delivery_tobacco_ordinary) as `折后日商-外卖香烟-正常单`
,sum(payable_price_delivery_other_ordinary) as `折后日商-外卖其他-正常单`

,sum(case when hr>=0 and hr<7 then payable_price_on_site_ff_ordinary end) as `折后日商-到店-FF-正常单-0=<hr<7`
,sum(case when hr>=0 and hr<7 then payable_price_on_site_tobacco_ordinary end) as `折后日商-到店-香烟-正常单-0=<hr<7`
,sum(case when hr>=0 and hr<7 then payable_price_on_site_other_ordinary end) as `折后日商-到店-其他-正常单-0=<hr<7`
,sum(case when hr>=0 and hr<7 then payable_price_delivery_ff_ordinary end) as `折后日商-外卖FF-正常单-0=<hr<7`
,sum(case when hr>=0 and hr<7 then payable_price_delivery_tobacco_ordinary end) as `折后日商-外卖香烟-正常单-0=<hr<7`
,sum(case when hr>=0 and hr<7 then payable_price_delivery_other_ordinary end) as `折后日商-外卖其他-正常单-0=<hr<7`

,sum(case when hr>=22 and hr<=23 then payable_price_on_site_ff_ordinary end) as `折后日商-到店-FF-正常单-22=<hr<=23`
,sum(case when hr>=22 and hr<=23 then payable_price_on_site_tobacco_ordinary end) as `折后日商-到店-香烟-正常单-22=<hr<=23`
,sum(case when hr>=22 and hr<=23 then payable_price_on_site_other_ordinary end) as `折后日商-到店-其他-正常单-22=<hr<=23`
,sum(case when hr>=22 and hr<=23 then payable_price_delivery_ff_ordinary end) as `折后日商-外卖FF-正常单-22=<hr<=23`
,sum(case when hr>=22 and hr<=23 then payable_price_delivery_tobacco_ordinary end) as `折后日商-外卖香烟-正常单-22=<hr<=23`
,sum(case when hr>=22 and hr<=23 then payable_price_delivery_other_ordinary end) as `折后日商-外卖其他-正常单-22=<hr<=23`

,sum(case when hr>=7 and hr<22 then payable_price_on_site_ff_ordinary end) as `折后日商-到店-FF-正常单-7=<hr<22`
,sum(case when hr>=7 and hr<22 then payable_price_on_site_tobacco_ordinary end) as `折后日商-到店-香烟-正常单-7=<hr<22`
,sum(case when hr>=7 and hr<22 then payable_price_on_site_other_ordinary end) as `折后日商-到店-其他-正常单-7=<hr<22`
,sum(case when hr>=7 and hr<22 then payable_price_delivery_ff_ordinary end) as `折后日商-外卖FF-正常单-7=<hr<22`
,sum(case when hr>=7 and hr<22 then payable_price_delivery_tobacco_ordinary end) as `折后日商-外卖香烟-正常单-7=<hr<22`
,sum(case when hr>=7 and hr<22 then payable_price_delivery_other_ordinary end) as `折后日商-外卖其他-正常单-7=<hr<22`
from data_smartorder.app_roster_act_sale_quick_reference_da t
left join work_day_list b on t.roster_date = b.date_key
left join store_open_info c on t.store_code = c.store_code and t.roster_date = c.roster_date
where dt = 20230327
and t.store_code in ('100000277',
'100000332',
'100000360',
'100000375',
'100000570',
'100000586',
'100000589',
'100000628',
'100000689',
'100001179',
'100001217',
'100001218',
'100001389',
'100001565',
'100001593',
'100001615',
'100002533',
'100003155',
'100005006',
'100005030',
'100005063',
'100005165',
'100005217',
'101000039',
'101000063',
'101000111',
'101000150',
'101000168',
'101000196',
'101000208',
'101000211',
'101000218',
'101000219',
'101000235',
'101000237',
'101000279',
'101000337',
'101000373',
'101000526',
'101000598',
'101000610',
'101000668',
'103000008',
'107000007',
'107000053',
'107000056',
'107000156',
'107000209',
'107000218',
'107000230',
'109000018',
'109000079',
'110000003',
'110000020',
'110000033',
'110000106',
'110000119',
'110000120',
'110000123',
'110000129',
'110000167',
'110000320',
'110000586',
'110000588',
'110000620',
'110001031',
'111000018',
'111000031',
'118000052',
'121000162',
'123000001',
'123000083',
'123000098',
'123000113',
'123000255',
'123000288',
'123000316',
'123000320',
'123000368',
'123000372',
'123000381',
'123000501',
'123000528',
'123000557',
'397000012',
'612000007',
'612000068',
'100000125',
'100000239',
'100000299',
'100000315',
'100001150',
'100003109',
'101000121',
'101000169',
'101000187',
'101000232',
'101000261',
'110000372',
'123001080',
'612000039',
'100000565',
'100000573',
'100000587',
'100000653',
'100000695',
'100001620',
'100001682',
'100002578',
'100003005',
'100005151',
'100005332',
'100005350',
'100005358',
'100005373',
'103000005',
'110000125',
'110000185',
'111000005',
'111000010',
'111000083',
'100000080',
'100000168',
'100002513',
'100011005',
'109000006')
group by t.store_code
,t.roster_date
,b.is_working_day
,c.bach_status