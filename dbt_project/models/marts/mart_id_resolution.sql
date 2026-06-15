{{
  config(
    materialized='table'
  )
}}

with ga4_users as (
    select distinct
        user_pseudo_id,
        country
    from {{ ref('stg_ga4_events') }}
),

crm as (
    select
        user_pseudo_id,
        user_id,
        member_rank,
        opt_in_email,
        registered_at
    from `mizuki-analytics.dbt_mart.crm_master`
),

resolved as (
    select
        g.user_pseudo_id,
        crm.user_id,
        crm.member_rank,
        crm.opt_in_email,
        crm.registered_at,
        g.country,
        CASE
            WHEN crm.user_id IS NOT NULL THEN 'logged_in'
            ELSE 'anonymous'
        END as user_type
    from ga4_users g
    left join crm
        on g.user_pseudo_id = crm.user_pseudo_id
)

select * from resolved
