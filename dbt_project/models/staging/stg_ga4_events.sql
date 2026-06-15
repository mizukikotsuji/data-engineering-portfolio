{{
  config(
    materialized='table'
  )
}}

with source as (
    select
        event_date,
        event_timestamp,
        event_name,
        user_pseudo_id,
        user_id,

        (
            select value.string_value
            from unnest(event_params)
            where key = 'page_location'
        ) as page_location,

        ecommerce.transaction_id,
        ecommerce.purchase_revenue,

        (
            select i.item_id
            from unnest(items) as i
            limit 1
        ) as first_item_id,

        device.category as device_category,
        geo.country,
        geo.region

    from `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_20210131`
)

select * from source
