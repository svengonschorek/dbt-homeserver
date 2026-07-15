{{
    config(
        materialized = 'table',
        order_by = 'pk_bybit_order'
    )
}}

-- select data from sources
-----------------------------------------------
with bybit_orders as (

    select * from {{ source('bybit', 'bybit_orders') }}

),

-- implement logic to build the model
-----------------------------------------------
base_bybit as (

    select
        concat('bybit_', bo.orderId) as unique_key,
        row_number() over (
            partition by bo.orderId order by bo.createdTime desc
        ) as r
    from bybit_orders as bo

),

final as (

    select
        -- keys
        lower(hex(MD5(concat(unique_key, '_', r)))) as pk_bybit_order,
        concat(unique_key) as bk_bybit_order,
        -- metadata
        '{{ invocation_id }}' as record_source,
        toDateTime(now(), 'Europe/Berlin') as load_dts
    from base_bybit
    where r = 1

)

select * from final
