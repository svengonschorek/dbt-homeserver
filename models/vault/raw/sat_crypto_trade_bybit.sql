{{
    config(
        materialized='table',
        order_by='fk_crypto_trade'
    )
}}

-- select data from sources
-----------------------------------------------
with bybit_trades as (

    select * from {{ source('bybit', 'bybit_trades') }}

),

-- implement logic to build the model
-----------------------------------------------
base_bybit as (

    select --noqa
        -- for key generation
        execId as unique_key,
        symbol,
        row_number() over (
            partition by
                execId
            order by
                execTime desc
        ) as r,
        -- properties
        orderType as order_type,
        toDateTime(cast(execTime / 1000, 'UInt32'), 'Europe/Berlin') as trade_at,
        side,
        execType as execution_type,
        toDecimal64(execQty, 4) as quantity,
        toDecimal64(orderQty, 4) as order_quantity,
        toDecimal64(execPrice, 8) as price,
        toDecimal64(markPrice, 8) as mark_price,
        toDecimal64(orderPrice, 8) as order_price,
        toDecimal64(execValue, 8) as execution_value,
        toDecimal64(execFee, 4) as fee_amount,
        feeCurrency as fee_currency
    from bybit_trades

),

-- build the final model
-----------------------------------------------
final as (

    select
        -- keys
        lower(hex(MD5(concat('bybit_', symbol, '_', unique_key)))) as fk_crypto_trade,
        -- metadata
        '{{ invocation_id }}' as record_source,
        toDateTime(now(), 'Europe/Berlin') as load_dts,
        -- properties
        symbol,
        order_type,
        trade_at,
        side,
        execution_type,
        quantity,
        order_quantity,
        price,
        mark_price,
        order_price,
        execution_value,
        fee_amount,
        fee_currency
    from base_bybit
    where r = 1

)

select * from final
