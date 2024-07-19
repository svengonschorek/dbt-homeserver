{{
    config(
        materialized = 'table',
        order_by = 'fk_crypto_trade'
    )
}}

-- select data from sources
-----------------------------------------------
with binance_trades_spot as (

    select * from {{ source('binance', 'binance_trades_spot') }}

),

-- implement logic to build the model
-----------------------------------------------
base as (

    select
        *,
        concat(
            'binance_',
            '_',
            side,
            '_',
            toUnixTimestamp(trade_utc_at),
            '_',
            pair
        ) as unique_key,
        row_number() over (
            partition by
                side,
                trade_utc_at,
                pair
            order by
                amount
        ) as r
    from binance_trades_spot

),

final as (

    select
        -- keys
        lower(hex(MD5(concat(b.unique_key, '_', b.r)))) as fk_crypto_trade,
        -- metadata
        '{{ invocation_id }}' as record_source,
        toDateTime(now(), 'Europe/Berlin') as load_dts,
        -- properties
        toDateTime(b.trade_utc_at, 'Europe/Berlin') as order_at,
        b.side,
        b.pair,
        toDecimal64(regexpExtract(b.amount, '(\\d+).(\\d+)', 0), 8) as trade_amount,
        regexpExtract(b.amount, '[A-Z]+', 0) as trade_coin,
        toDecimal64(regexpExtract(b.fee, '(\\d+).(\\d+)', 0), 8) as fee_amount,
        regexpExtract(b.fee, '[A-Z]+', 0) as fee_coin,
        toDecimal64(regexpExtract(b.executed, '(\\d+).(\\d+)', 0), 8) as executed_amount,
        regexpExtract(b.executed, '[A-Z]+', 0) as executed_coin
    from base as b

)

select * from final
