select
    t2.store_code
    ,t2.store_name
    ,t1.calendar_year
    ,t1.week_of_year
    ,min(t1.date_key)                           as start_date
    ,max(t1.date_key)                           as end_date
    ,avg(t2.saleout_cus_fenzi_zhi)              as saleout_cus_fenzi_zhi
    ,avg(t2.saleout_cus_fenmu_zhi)              as saleout_cus_fenmu_zhi
    ,avg(t2.saleout_cus_fenzi_zhi)/avg(t2.saleout_cus_fenmu_zhi)            as saleout_cus_rate_zhi
    ,avg(t2.saleout_cus_fenzi_feizhi)           as saleout_cus_fenzi_feizhi
    ,avg(t2.saleout_cus_fenmu_feizhi)           as saleout_cus_fenmu_feizhi
    ,avg(t2.saleout_cus_fenzi_feizhi)/avg(t2.saleout_cus_fenmu_feizhi)      as saleout_cus_rate_feizhi
    ,avg(t2.noff_open_div_cnt)                  as noff_open_div_cnt
    ,avg(t2.noff_all_div_cnt)                   as noff_all_div_cnt
    ,avg(t2.noff_open_div_cnt)/avg(t2.noff_all_div_cnt)                     as open_rate_feizhi
    ,avg(t2.ff_open_div_cnt)                    as ff_open_div_cnt
    ,avg(t2.ff_all_div_cnt)                     as ff_all_div_cnt
    ,avg(t2.ff_open_div_cnt)/avg(t2.ff_all_div_cnt)                         as open_rate_zhi
left join default.dim_date_ya_v2 t1
from data_smartorder.dm_copy_app_ordering_system_evaluation_store_info_di_cc_view t2 on t1.date_key = t2.record_date and t2.dt >= 20180101
where t1.date_key between '2018-01-01' and '${FDATE}'
group by
    t2.store_code
    ,t2.store_name
    ,t1.calendar_year
    ,t1.week_of_year




`store_code`                            string  COMMENT '门店编码'
,`store_name`                           string  COMMENT '门店名称'
,`calendar_year`                        string  COMMENT '年份'
,`week_of_year`                         string  COMMENT '周'
,`start_date`                           string  COMMENT '周开始日期'
,`end_date`                             string  COMMENT '周结束日期'
,`saleout_cus_fenzi_zhi`                string  COMMENT '售罄分子:制作-售罄时段人流*因子 制作-售罄时段权重'
,`saleout_cus_fenmu_zhi`                string  COMMENT '售罄分母:制作-时段总人流*因子 制作-时段总权重'
,`saleout_cus_rate_zhi`                 string  COMMENT '制作客户角度售罄率'
,`saleout_cus_fenzi_feizhi`             string  COMMENT '售罄分子:非制作-售罄时段人流*因子 制作-售罄时段权重'
,`saleout_cus_fenmu_feizhi`             string  COMMENT '售罄分母:非制作-时段总人流*因子 制作-时段总权重'
,`saleout_cus_rate_feizhi`              string  COMMENT '非制作客户角度售罄率'
,`noff_open_div_cnt`                    string  COMMENT '门店-非制作类开放数'
,`noff_all_div_cnt`                     string  COMMENT '门店-非制作类总分类数'
,`open_rate_feizhi`                     string  COMMENT '非制作类开放率'
,`ff_open_div_cnt`                      string  COMMENT '门店-制作类开放数'
,`ff_all_div_cnt`                       string  COMMENT '门店-制作类总分类数'
,`open_rate_zhi`                        string  COMMENT '制作类开放率'

