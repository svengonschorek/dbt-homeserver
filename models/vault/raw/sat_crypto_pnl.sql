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
        lower(hex(MD5(concat('bybit_', symbol, '_', orderId)))) as fk_crypto_pnl,
        -- metadata
        '{{ invocation_id }}' as record_source,
        toDateTime(now(), 'Europe/Berlin') as load_dts,
        -- properties
        'bybit' as platform,
        symbol,
        side,
        orderType as order_type,
        toDecimal64(qty, 4) as quantity,
        toDecimal64(avgEntryPrice, 8) as avg_entry_price,
        toDecimal64(cumEntryValue, 8) as cum_entry_value,
        toDecimal64(avgExitPrice, 8) as avg_exit_price,
        toDecimal64(cumExitValue, 8) as cum_exit_value,
        toDecimal64(orderPrice, 8) as order_price,
        toDecimal64(closedPnl, 8) as closed_pnl
    from crypto_pnl

)

select * from final
