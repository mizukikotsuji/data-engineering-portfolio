{{
  config(
    materialized='table'
  )
}}

with cart_events as (
    select
        user_pseudo_id,
        first_item_id,
        MAX(event_timestamp) as last_cart_timestamp
    from {{ ref('stg_ga4_events') }}
    where event_name = 'add_to_cart'
    group by user_pseudo_id, first_item_id
),

purchase_events as (
    select distinct
        user_pseudo_id
    from {{ ref('stg_ga4_events') }}
    where event_name = 'purchase'
),

crm as (
    select
        user_pseudo_id,
        user_id,
        member_rank,
        opt_in_email
    from `mizuki-analytics.dbt_mart.crm_master`
    where opt_in_email = true
),

cart_abandonment as (
    select
        c.user_pseudo_id,
        c.first_item_id as last_cart_item_id,
        c.last_cart_timestamp,
        crm.user_id,
        crm.member_rank
    from cart_events c
    left join purchase_events p
        on c.user_pseudo_id = p.user_pseudo_id
    inner join crm
        on c.user_pseudo_id = crm.user_pseudo_id
    where p.user_pseudo_id is null
)

select * from cart_abandonment
