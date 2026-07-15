{{
    config(
        materialized = 'table',
        order_by = 'fk_bybit_pnl'
    )
}}

-- select data from sources
-----------------------------------------------
with crypto_pnl as (

    select * from {{ source('bybit', 'bybit_pnl') }}

),

-- implement logic to build the model
-----------------------------------------------
final as (

    select
        -- keys
        lower(hex(MD5(concat('bybit_', lower(pnl.symbol), '_', pnl.orderId)))) as pk_bybit_pnl_bybit_order,
        lower(hex(MD5(concat('bybit_', lower(pnl.symbol), '_', pnl.orderId)))) as fk_bybit_pnl,
        lower(hex(MD5(concat('bybit_', pnl.orderId)))) as fk_bybit_order,
        -- metadata
        '{{ invocation_id }}' as record_source,
        toDateTime(now(), 'Europe/Berlin') as load_dts
    from crypto_pnl as pnl

)

select * from final
