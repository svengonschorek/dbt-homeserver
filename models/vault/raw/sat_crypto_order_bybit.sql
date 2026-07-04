{{
    config(
        materialized = 'table',
        order_by = 'fk_crypto_order'
    )
}}

-- select data from sources
-----------------------------------------------
with orders as (

    select * from {{ source('bybit', 'bybit_orders') }}

),

-- implement logic to build the model
-----------------------------------------------
base as (

    select --noqa
        -- keys
        concat('bybit_', orderId) as unique_key,
        -- properties
        symbol,
        side,
        orderId as order_id,
        orderType as order_type,
        orderStatus as order_status,
        toDateTime(cast(createdTime / 1000, 'UInt32'), 'Europe/Berlin') as order_at,
        toDecimal64(qty, 4) as quantity,
        toDecimal64(price, 8) as price,
        toDecimal64(cumExecValue, 8) as cumumlative_exec_value,
        toDecimal64(cumExecFee, 8) as cumulative_exec_fee,
        -- deduplication
        row_number() over (
            partition by orderId order by createdTime desc
        ) as r
    from orders

),

final as (

    select
        -- keys
        lower(hex(MD5(unique_key))) as fk_crypto_order,
        -- metadata
        '{{ invocation_id }}' as record_source,
        toDateTime(now(), 'Europe/Berlin') as load_dts,
        -- properties
        'bybit' as platform,
        symbol,
        side,
        order_id,
        order_type,
        order_status,
        order_at,
        quantity,
        price,
        cumumlative_exec_value,
        cumulative_exec_fee
    from base
    where r = 1

)

select * from final
