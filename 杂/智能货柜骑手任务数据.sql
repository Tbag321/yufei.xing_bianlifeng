日期 城市 人员 出货量 补货量 正向补货取消量 逆向返仓量 下架回调量 绑箱完成量 返仓任务数 返仓完成数



with list as(
SELECT
order_id,
executedate,
get_json_object(cityinfo,'$.cityName') as citay_name,
mvtstr as mvtstr,
mvtstre as mvtstre,
get_json_object(mvtstr,'$.actionType') as actionType,
get_json_object(mvtstr,'$.operatorId') as operatorId,
get_json_object(mvtstr,'$.operatorName') as operatorName,
get_json_object(mvtstre,'$.status') as order_status,
get_json_object(mvtstre,'$.orderType') as orderType,
case 
when get_json_object(mvtstre,'$.orderType') = 'ReverseCallback' then '差异返仓'
when get_json_object(mvtstre,'$.orderType') = 'CancelCallback' then '取消补货'
when get_json_object(mvtstre,'$.orderType') = 'UnshelveCallback' then '下架返仓'
end as backtype
from default.mid_shelf_work_order_order_detail
lateral view explode(split(regexp_replace(regexp_extract(actionlog,'^\\[(.+)\\]$',1),'\\}\\,\\{', '\\}\\|\\|\\{'),'\\|\\|')) addTable AS mvtstr
lateral view explode(split(regexp_replace(regexp_extract(backorders,'^\\[(.+)\\]$',1),'\\}\\,\\{', '\\}\\|\\|\\{'),'\\|\\|')) addTable AS mvtstre
where dt = '${today-1}'
)

select
cast(executedate as date) as order_date,
citay_name,
operatorId,
operatorName,
count(distinct order_id) as sell_num,
count(distinct case when ordertype is null then order_id end) as cpfr_num,
count(distinct case when backtype = '差异返仓' then order_id end) as callback_num,
count(distinct case when backtype = '取消补货' then order_id end) as cancel_num,
count(distinct case when backtype = '下架返仓' then order_id end) as down_num,
count(distinct case when actionType = 'PACKED_BOX' then order_id end) as PACKED_BOX,
count(distinct case when actionType = 'PACKED_BOX' then order_id end) as call_back_num,
count(distinct case when actionType = 'PACKED_BOX'  and order_status = 'Finished' then order_id end) as call_back_finished_num
from list
where operatorId not in ('SYSTEM','运营')
and operatorName is not null
and executedate > '2022-01-01'
group by
cast(executedate as date),
citay_name,
operatorId,
operatorName