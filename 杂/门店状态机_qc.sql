with sign_project as --项目归档信息
(

    select 
    t1.flag_code
    ,t1.project_id
    ,t1.project_name
    ,t1.city_name
    ,t1.store_code
    ,t1.store_name
    ,t1.project_status_updated_time --as `签约`
    ,t1.business_type
    ,t1.is_delete
    ,t2.cancel_sign_state
    ,case when t2.cancel_sign_state <>'900' and t2.is_store_closed <> '800' and t2.is_delete = '0' then 1
        else 0 end is_keep_project

    from app_store_construction_project_pipeline_indicators_ha_v1 t1
    left join dim_store_construction_project_info t2 on t1.flag_code = t2.flag_code and t2.dt = '20240121'
    where t1.project_status_group = '状态' --'状态'/'阶段'/'阶段-状态'
    and substring_index(t1.project_status_name,' ',1) = '10' --已签约归档
    --and t1.project_status_updated_time > '1990-01-01 00:00:00.0'
    --and t1.business_type = '便利店'
    --and t1.is_delete = 0 
    and t1.dt = '20240121' and t1.hr = '21'

),

open_project_info as --项目工程信息
(
    select
        t1.store_id
        ,t1.flag_number
        ,t1.address
        ,t1.used_area
        ,t1.inspector_name
        ,t1.inspector_id
        ,t1.manage_name
        ,t1.developer_name
        ,t1.project_engineer_name
        ,t1.equip_engineer_name
        ,t1.sign_date --签约日期
        ,t1.sign_status
        ,t1.rent_start_date
        ,t1.rent_type_peroid --起租阶段
        ,t1.rent_free_date --免租日期
        --进场协调会，无撤店信息
        ,t1.coordinate_enter_expect_time
        ,t1.coordinate_enter_real_time --实际进场协调会时间
        --收房
        ,date_format(coalesce(t1.room_expect_time,t2.take_over_expected_date),'yyyy-MM-dd') room_expect_time
        ,date_format(coalesce(t1.room_real_time,t2.take_over_actual_date),'yyyy-MM-dd') room_real_time
        --进场
        ,date_format(coalesce(t1.enter_expect_time,t2.engineering_started_expected_date),'yyyy-MM-dd') enter_expect_time
        ,date_format(coalesce(t1.enter_real_time,t2.engineering_started_actual_date),'yyyy-MM-dd') enter_real_time
        --交底
        ,date_format(coalesce(t1.decorated_expect_time,t2.disclosure_expected_date),'yyyy-MM-dd') decorated_expect_time
        ,date_format(coalesce(t1.decorated_real_time,t2.disclosure_actual_date),'yyyy-MM-dd') decorated_real_time
        --完工
        ,date_format(coalesce(t1.finiah_expect_time,t2.fake_engineering_finished_expected_date),'yyyy-MM-dd') finiah_expect_time
        ,date_format(coalesce(t1.finiah_real_time,t2.fake_engineering_finished_actual_date),'yyyy-MM-dd') finiah_real_time
        --保洁
        ,date_format(coalesce(t1.clean_expect_time,t2.engineering_finished_expected_date),'yyyy-MM-dd') clean_expect_time
        ,date_format(coalesce(t1.clean_real_time,t2.engineering_finished_actual_date),'yyyy-MM-dd') clean_real_time
        --交店
        ,date_format(coalesce(t1.submit_expect_time,t2.operation_check_expected_date),'yyyy-MM-dd') submit_expect_time
        ,date_format(coalesce(t1.submit_real_time,t2.operation_check_actual_date),'yyyy-MM-dd') submit_real_time
        --开业
        ,date_format(coalesce(t1.open_expect_date,t2.opening_expected_date),'yyyy-MM-dd') open_expect_date
        ,date_format(coalesce(t1.open_real_date,t2.opening_actual_date),'yyyy-MM-dd') open_real_date
        ,t1.open_final_date --运营确认开业时间
        --pdw_opc_engineering_engineering_report_all表剩余字段
        ,t2.create_time --创建时间
        ,t2.business_license_issued_expected_date --营业执照预计下发时间
        ,t2.operation_build_check_pass_date --运营交接建筑验收通过日期
        ,t2.total_cost --施工累计耗时
        ,t2.after_started_delay_days --收房后延期暂停天数
        ,t2.system_calc_period --系统计算出的工期
    from
    (
        select
        *
        ,row_number() over(partition by flag_number order by store_id desc) r_n
        from dwa_store_construction_project_signed_opening_schedure --CY15-2733对应2个store_id =('887','154')（887工程记录是全的，似乎因为续约）
        where dt = '20240121'
    ) t1
    left join
    (
        select
        *
        from data_build.pdw_opc_engineering_engineering_report_all
        where dt = '20240120' --刷新时间比较晚
    ) t2 on t1.store_id = t2.store_id
    where t1.r_n = 1
),

internal_closure_pipeline as --原子嘉线下维护，现转线上
(
/*  select
    flag_code
    ,store_code
    ,tag
    ,version
    ,'1' is_delete
    from ods_uploads_internal_closure_pipeline_v2
    where version not like '%中止%'*/

    select
    *
    from
    (
        select
        t1.project_id
        ,t2.flag_code                                   --as `插旗编码`
        ,t2.project_name                                --as `项目名称`
        ,t2.city_name                                   --as `城市`
        ,t2.store_code                                  --as `门店编码`
        ,t2.store_name                                  --as `门店名称`
        ,flow_order_id                                  --as `解约主线任务工作流单号`
        ,case when t1.cancel_state = 'suspend' then '解约中止'
        when t1.cancel_state = 'doing' then '解约中'
        when t1.cancel_state = 'done' then '解约完成'
        end cancel_state                                --as `解约状态`
        ,case when cancel_type = 1 then '先谈后撤' 
        when cancel_type = 2 then '先撤后谈' 
        when cancel_type = 3 then '谈判同时撤店'
        when cancel_type = 0 then null
        end cancel_type                                 --as `解约类型`
        ,cancel_method                                  --as `解约方式`
        ,rent_reduction_ratio                           --as `降租保留比例`
        ,withdraw_shop_date                             --as `完成撤店时间`
        ,case when cancel_source = 1 then '甲方违约'
        when cancel_source = 2 then '乙方违约'
        when cancel_source = 3 then '到期不续'
        when cancel_source = 4 then '法务评估无责解约'
        when cancel_source = 99 then '其他'
        when cancel_source = 0 then null
        end cancel_source                               --as `发起来源`
        ,other_cancel_source                            --as `其他发起来源`
        ,case when revoke_reason = 1 then '门店降免租保留'
        when revoke_reason = 2 then '门店策略保留'
        when revoke_reason = 99 then '其他'
        when revoke_reason = 0 then null
        end revoke_reason                               --as `撤销备注`
        ,row_number()over(partition by flag_code order by create_time desc) as rn
        from data_build.pdw_opc_flag_project_cancel_sign_view t1
        left join sign_project t2 on t1.project_id = t2.project_id 
        where t1.dt = '20240121'
        and t2.flag_code is not null
    )t1
    where t1.rn = 1
),

internal_closure_history as --qc维护，线下表
(
    select
    flag_code
    ,tag
    ,additional_info
    from data_build.ods_uploads_internal_closure_history

),

contract_status_info as --合同状态
(
    select
    t.*
    from
    (
    select
        t.contract_id
        ,t.flag_code
        ,t.project_id
        ,t.shop_code
        ,t.constructionArea
        ,t.businessArea
        ,t.contract_address
        ,case when get_json_object(t.content,'$.audit.mainStatus.name') = 'Start' and get_json_object(t.content,'$.audit.developAuditStatus.name') = 'Start'
                and get_json_object(t.content,'$.audit.developAcceptedCount') = 0 and (get_json_object(t.content,'$.main.projectCancelState.code') <> 'cancelDone' or get_json_object(t.content,'$.main.projectCancelState.code') is null)
                and (get_json_object(t.content,'$.main.pauseStatus.name') <> 'Pause' or get_json_object(t.content,'$.main.pauseStatus.name') is null) then '已创建'
             when get_json_object(t.content,'$.audit.mainStatus.name') = 'Start' and (get_json_object(t.content,'$.audit.developAuditStatus.name') <> 'Start' or get_json_object(t.content,'$.audit.developAuditStatus.name') is null)
                and (get_json_object(t.content,'$.audit.financialAuditStatus.name') <> 'Start' or get_json_object(t.content,'$.audit.financialAuditStatus.name') is null)
                and (get_json_object(t.content,'$.main.projectCancelState.code') <> 'cancelDone' or get_json_object(t.content,'$.main.projectCancelState.code') is null)
                and (get_json_object(t.content,'$.main.pauseStatus.name') <> 'Pause' or get_json_object(t.content,'$.main.pauseStatus.name') is null) then '未生效'
             when get_json_object(t.content,'$.audit.mainStatus.name') = 'Finished' and get_json_object(t.content,'$.audit.developAcceptedCount') > 0  and get_json_object(t.content,'$.audit.financialAcceptedCount') > 0
                and (get_json_object(t.content,'$.main.projectCancelState.code') <> 'cancelDone' or get_json_object(t.content,'$.main.projectCancelState.code') is null)
                and (get_json_object(t.content,'$.main.pauseStatus.name') <> 'Pause' or get_json_object(t.content,'$.main.pauseStatus.name') is null) then '已生效'
             when (get_json_object(t.content,'$.main.projectCancelState.code') <> 'cancelDone' or get_json_object(t.content,'$.main.projectCancelState.code') is null)
                and get_json_object(t.content,'$.main.pauseStatus.name') = 'Pause' then '已暂停'
             when get_json_object(t.content,'$.main.projectCancelState.code') = 'cancelDone' then '已解约'
             else null end as contract_status
        ,row_number() over(partition by t.flag_code order by t.update_time desc) r_n
    from        
        (
            select
            contract_id
            ,content
            ,create_time
            ,update_time
            ,get_json_object(content,'$.main.flagCode') as flag_code
            ,get_json_object(content,'$.main.projectId') as project_id
            ,get_json_object(content,'$.main.shopCode') as shop_code
            ,get_json_object(content,'$.main.constructionArea') as constructionArea
            ,get_json_object(content,'$.main.businessArea') as businessArea
            ,concat(get_json_object(content,'$.main.addressInfo.province.name'),get_json_object(content,'$.main.addressInfo.city.name'),get_json_object(content,'$.main.addressInfo.area.name'),get_json_object(content,'$.main.addressInfo.detail')) as contract_address
            ,row_number() over(partition by contract_id order by main_version desc) as r_n
            from data_build.dm_copy_pdw_opc_flag_contract_snapshot_view
            where dt='20240121'
        ) t
        where t.r_n = 1
    ) t
    where t.r_n = 1


/* --一类项目快照表有丢失，pdw_opc_flag_contract_snapshot这里面只会记录开发和财务都复核通过的合同，这种没复核通过过的合同，版本是0的，在order-store里面209单
select
get_json_object(a1.data,'$.flagCode')
,get_json_object(a.data,'$.constructionArea') constructionArea
,get_json_object(a.data,'$.businessArea') businessArea
,get_json_object(a.data,'$.projectCancelState.code') projectCancelState_code
,get_json_object(a.data,'$.projectCancelState.name') projectCancelState_name
from pdw_order_store_209_order_detail a
where a.section = 'contract_main'
and (get_json_object(a.data,'$.isDelete') <> 1 or get_json_object(a.data,'$.isDelete') is null) --剔除isDelete=1，保证209单的唯一性（等于按照version降序取1）
and a. dt ='20240121'
*/

),

contract_cancel_status as --用印归档状态
(
    select
    a.project_id
    ,a.contract_kind
    ,a.file_status
    ,a.seal_use_date
    ,a.file_date
    from
    (
        select
        project_id
        ,case 
            when contract_kind = 'propertyAgreement' then '物业协议'
            when contract_kind = 'brokerageAgreement' then '居间协议'
            when contract_kind = 'supplementaryAgreement' then '补充协议'
            when contract_kind = 'electricityIncreaseAgreement' then '电量增容协议'
            when contract_kind = 'cancelAgree' then '解约协议'
            when contract_kind = 'tras' then '转让协议'
            when contract_kind = 'separateContract' then '分租合同'
            when contract_kind = 'freerent' then '减免租补充协议'
            else contract_kind end as contract_kind
        -- ,apply_source as `申请来源`
        -- ,case 
        --         when stamp_type = '1' then '我方'
        --         when stamp_type = '2' then '对方'
        --         else stamp_type
        --     end as `盖章类型`
        -- ,seal_kind_name as `用印类型`
        ,seal_use_date
        ,file_date
        -- ,party_first_sign_date as `甲方签约日期`
        -- ,party_secord_sign_date as `我方签约日期`
        ,contract_file_code-- as `合同归档编号`
        -- ,contract_file_name as `合同名称`
        ,case
                when status = '100' then '待开发处理'
                when status = '110' then '待开发处理'
                when status = '130' then '待开发处理'
                when status = '300' then '待法务用印组处理'
                when status = '400' then '待法务用印组处理'
                when status = '500' then '待法务归档组处理'
                when status = '540' then '待法务归档组处理'
                when status = '600' then '用印归档已完成'
                when status = '700' then '待开发确认用印'
                when status = '800' then '待开发确认归档资料'
                when status = '900' then '用印归档已终止'
                else status end as file_status
        -- ,status_show as `展示状态`
        ,row_number() over(partition by project_id order by contract_file_code desc) r_n
        from pdw_opc_flag_seal_apply_info t2
        where dt='20240121'
        and contract_kind = 'cancelAgree'
        and status = '600'
    ) a
    where a.r_n = 1

),

store_status_bach_info as --店务清单
(
    /*营业时间测算时会选取【门店状态】为启用、【营业状态】为营业、待营业、暂停营业门店。
    待营业在本次测算周期的门店会正常测算，暂停营业最终营业时间为全天不营业。*/
    select 
     store_code
     ,store_name
     ,store_city
     ,to_date(original_openning_date) open_date
     ,store_status
    from data_build.dw_ordering_store_tag_location_ranking_info_v1_view t
    where dt= date_format(date_sub(current_date,1),'yyyyMMdd')
    and store_status <> '3' -- 营业状态非停业（0:待营业 1:营业 2：暂停营业 3：停业）
    and store_cvs_status = '1' -- 门店状态为启用（门店状态值：启用、停用）
    and store_type = '0' -- 门店
    -- and to_date(original_openning_date) <= 测算周期

),


store_status_engineering_store as --dwa_store_construction_project_signed_opening_schedure的上游dim_store_construction_project_signed_opening_info  
(
    select *
    from pdw_opc_engineering_engineering_store_ha t1
    where t1.dt = '20240121'
    and t1.hr = '21' 
    --progress枚举，11:待收房 12:待开工 13:施工中 14:已完工 15:移交运营 16:待开业 17:已开业
    --pdw_opc_engineering_engineering_report_ha是工程施工进度的上游表dwd_store_construction_project_decorated_schedure笑伟治理了很多分块的进度信息表
/*
    case status
    when 0 then '进行中'
    when 1 then '暂停'
    when 2 then '失效'
    when 3 then '闭店'
    when 10 then '启动设计（未签约）'
    when 11 then '已签约'
    when 12 then '进场协调会'
    else status end as status*/
)


--------------------
select
a.flag_code
,a.project_id
,a.project_name
,a.city_name
,a.store_code
,a.store_name
,a.business_type
,a.is_delete
,a.is_keep_project
,b.address
,b.used_area
,b.inspector_name
,b.inspector_id
,b.manage_name
,b.developer_name
,b.project_engineer_name
,b.equip_engineer_name
--,to_date(b.sign_date) sign_date --签约日期
,to_date(date_format(a.project_status_updated_time,'yyyy-MM-dd')) project_status_updated_time
,case when b.sign_status = '已开业' then '4已开业'
when b.sign_status = '待开业' then '3交店未开业'
when b.sign_status = '已完工' then '2完工未交店'
when b.sign_status = '施工中' then '1收房未完工'
when b.sign_status = '待开工' then '1收房未完工'
else '0未收房' end as project_progress_eng
,nvl(b.sign_status,'待收房') sign_status
,to_date(b.rent_start_date) rent_start_date
,b.rent_type_peroid --起租阶段
,b.rent_free_date --免租日期
--收房
,to_date(b.room_expect_time) room_expect_time
,to_date(b.room_real_time) room_real_time
--进场
,to_date(b.enter_expect_time) enter_expect_time
,to_date(b.enter_real_time) enter_real_time
--进场协调会
,to_date(b.coordinate_enter_expect_time) coordinate_enter_expect_time
,to_date(b.coordinate_enter_real_time) coordinate_enter_real_time
--交底
,to_date(b.decorated_expect_time) decorated_expect_time
,to_date(b.decorated_real_time) decorated_real_time
--完工
,to_date(b.finiah_expect_time) finiah_expect_time
,to_date(b.finiah_real_time) finiah_real_time
--保洁
,to_date(b.clean_expect_time) clean_expect_time
,to_date(b.clean_real_time) clean_real_time
--交店
,to_date(b.submit_expect_time) submit_expect_time
,to_date(b.submit_real_time) submit_real_time
--开业
,to_date(b.open_expect_date) open_expect_date
,to_date(b.open_final_date) open_final_date
,nvl(to_date(b.open_real_date),to_date(j.opening_date)) open_real_date
,to_date(date_format(b.open_real_date , 'yyyy-MM-01')) open_real_month
,to_date(date_format(b.open_expect_date , 'yyyy-MM-01')) open_expect_month
--状态标签
,c.cancel_state
,c.revoke_reason
,c.other_cancel_source
,c.withdraw_shop_date
,d.contract_status
,e.file_status
,f.store_status
,if(b.open_real_date >= date_format(date_add(current_date(),-1),'yyyy-MM-01') and b.open_real_date <= current_date() ,1,0) current_month_open
,if(b.open_real_date >= date_format(add_months(date_add(current_date(),-1),-1),'yyyy-MM-01') and b.open_real_date < date_format(date_add(current_date(),-1),'yyyy-MM-01') ,1,0) last_month_open
,if(b.open_real_date >= date_format(add_months(date_add(current_date(),-1),-2),'yyyy-MM-01') and b.open_real_date < date_format(add_months(date_add(current_date(),-1),-1),'yyyy-MM-01') ,1,0) last_two_month_open
,if(b.open_real_date >= date_format(add_months(date_add(current_date(),-1),-3),'yyyy-MM-01') and b.open_real_date < date_format(add_months(date_add(current_date(),-1),-2),'yyyy-MM-01') ,1,0) last_three_month_open
,if(b.open_expect_date >= current_date() and b.open_expect_date < date_format(add_months(date_add(current_date(),-1),1),'yyyy-MM-01'),1,0) current_month_expect_open
,if(b.open_expect_date >= date_format(add_months(date_add(current_date(),-1),1),'yyyy-MM-01') and b.open_expect_date < date_format(add_months(date_add(current_date(),-1),2),'yyyy-MM-01'),1,0) next_month_expect_open
,if(b.open_expect_date >= date_format(add_months(date_add(current_date(),-1),2),'yyyy-MM-01') and b.open_expect_date < date_format(add_months(date_add(current_date(),-1),3),'yyyy-MM-01'),1,0) next_two_month_expect_open
,if(b.open_expect_date >= date_format(add_months(date_add(current_date(),-1),3),'yyyy-MM-01') and b.open_expect_date < date_format(add_months(date_add(current_date(),-1),4),'yyyy-MM-01'),1,0) next_three_month_expect_open
----------------------
,case --when c.is_delete = 1 and a.business_type = '便利店' then '3BLF内部已决策要解约门店'
    when c.cancel_state in ('解约完成','解约中') and a.business_type = '便利店' then '3BLF内部已决策要解约门店'
    when a.business_type <> '便利店' then '5非便利店'
    when h.additional_info is not null then h.additional_info
    when j.progress <> '17' then '2正常保留-未开业门店'
    when f.store_status is not null or c.cancel_state in ('解约中止') then '1正常保留-已开业门店'
    when a.is_delete = 0 and (d.contract_status not in ('已解约') or d.contract_status is null) and e.file_status is null and b.sign_status in ('已开业') then '1正常保留-已开业门店'
    else null end store_status_BLF
,a.cancel_sign_state
,d.constructionArea
,d.businessArea
,d.contract_address
,case j.progress when 11 then '0未收房'
    when 12 then '1收房未完工'
    when 13 then '1收房未完工'
    when 14 then '2完工未交店'
    when 15 then '3交店未开业'
    when 16 then '3交店未开业'
    when 17 then '4已开业'
    else null end store_status_eng
,case j.progress
            when 0 then '待收房'
            when 1 then '待开工'
            when 5 then '已开业'
            when 11 then '待收房'
            when 12 then '待开工'
            when 13 then '施工中'
            when 14 then '已完工'
            when 15 then '移交运营'
            when 16 then '待开业'
            when 17 then '已开业'
            else progress end progress
from sign_project a
left join open_project_info b on a.flag_code = b.flag_number
left join internal_closure_pipeline c on a.flag_code = c.flag_code
left join contract_status_info d on a.flag_code = d.flag_code
left join contract_cancel_status e on a.project_id = e.project_id
left join store_status_bach_info f on a.store_code = f.store_code
left join internal_closure_history h on a.flag_code = h.flag_code
left join store_status_engineering_store j on a.store_code = j.shop_code --撤店项目的最终工程状态与实际开业时间