{{
    config(
        materialized='table',
        order_by='fk_bybit_trade'
    )
}}

-- select data from sources
-----------------------------------------------
with bybit_trades as (

    select * from {{ source('bybit', 'bybit_trades') }}

),

-- implement logic to build the model
-----------------------------------------------
final as (

    select
        -- keys
        lower(hex(MD5(concat('bybit_', symbol, '_', execId)))) as pk_bybit_trade_bybit_order,
        lower(hex(MD5(concat('bybit_', symbol, '_', execId)))) as fk_bybit_trade,
        lower(hex(MD5(concat('bybit_', orderId)))) as fk_bybit_order,
        -- metadata
        '{{ invocation_id }}' as record_source,
        toDateTime(now(), 'Europe/Berlin') as load_dts
    from bybit_trades

)

select * from final
