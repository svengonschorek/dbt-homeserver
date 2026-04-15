{{
    config(
        materialized = 'table',
        order_by = 'fk_crypto_pnl'
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
        lower(hex(MD5(concat('bybit_', lower(pnl.symbol), '_', pnl.orderId)))) as fk_crypto_pnl,
        -- metadata
        '{{ invocation_id }}' as record_source,
        toDateTime(now(), 'Europe/Berlin') as load_dts,
        -- properties
        'bybit' as platform,
        pnl.symbol,
        pnl.side,
        pnl.orderType as order_type,
        toDecimal64(pnl.qty, 4) as quantity,
        toDecimal64(pnl.avgEntryPrice, 8) as avg_entry_price,
        toDecimal64(pnl.cumEntryValue, 8) as cum_entry_value,
        toDecimal64(pnl.avgExitPrice, 8) as avg_exit_price,
        toDecimal64(pnl.cumExitValue, 8) as cum_exit_value,
        toDecimal64(pnl.orderPrice, 8) as order_price,
        toDecimal64(pnl.closedPnl, 8) as closed_pnl
    from crypto_pnl as pnl

)

select * from final
