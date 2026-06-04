--冬眠门店list
SELECT
order_id,
version,
status,
get_json_object(extension,'$[0].value'),
get_json_object(extension,'$[1].value'),
get_json_object(get_json_object(selection_p_o_list,'$[0].values'),'$[0].value'),
get_json_object(get_json_object(selection_p_o_list,'$[0].values'),'$[0].key')
from data_smartorder.dm_ordering_information_system_order_detail
WHERE dt='20220818'
and l2_category_name='冬眠门店'
