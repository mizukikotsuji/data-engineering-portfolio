{{
  config(
    materialized='table'
  )
}}

with events as (
    select
        user_pseudo_id,
        event_name,
        purchase_revenue
    from {{ ref('stg_ga4_events') }}
),

crm as (
    select
        user_pseudo_id,
        user_id,
        member_rank
    from `mizuki-analytics.dbt_mart.crm_master`
),

joined as (
    select
        e.user_pseudo_id,
        e.event_name,
        e.purchase_revenue,
        crm.user_id,
        crm.member_rank
    from events e
    inner join crm
        on e.user_pseudo_id = crm.user_pseudo_id
),

aggregated as (
    select
        user_pseudo_id,
        user_id,
        member_rank,
        COUNTIF(event_name = 'view_item')    as view_item_count,
        COUNTIF(event_name = 'add_to_cart')  as add_to_cart_count,
        COUNTIF(event_name = 'purchase')     as purchase_count,
        IFNULL(SUM(purchase_revenue), 0)     as total_ltv
    from joined
    group by user_pseudo_id, user_id, member_rank
)

select
    user_pseudo_id,
    user_id,
    member_rank,
    view_item_count,
    add_to_cart_count,
    purchase_count,
    total_ltv,

    -- 遷移率
    SAFE_DIVIDE(add_to_cart_count, view_item_count) as view_to_cart_rate,
    SAFE_DIVIDE(purchase_count, add_to_cart_count)  as cart_to_purchase_rate

from aggregated
