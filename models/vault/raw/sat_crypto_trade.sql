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

binance_trades_futures as (

    select * from {{ source('binance', 'binance_trades_futures') }}

),

-- implement logic to build the model
-----------------------------------------------
base_spot as (

    select
        *,
        concat(
            'binance',
            '_',
            lower(side),
            '_',
            toUnixTimestamp(trade_utc_at),
            '_',
            lower(pair)
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

base_futures as (

    select
        *,
        trade_id as unique_key,
        row_number() over (
            partition by
                trade_id
            order by
                amount
        ) as r
    from binance_trades_futures

),

final as (

    select
        -- keys
        lower(hex(MD5(concat(b.unique_key, '_', b.r)))) as fk_crypto_trade,
        -- metadata
        '{{ invocation_id }}' as record_source,
        toDateTime(now(), 'Europe/Berlin') as load_dts,
        -- properties
        toDateTime(b.trade_utc_at, 'Europe/Berlin') as trade_at,
        'binance' as platform,
        'Spot' as wallet,
        b.side,
        b.pair,
        toDecimal64(regexpExtract(b.amount, '(\\d+).(\\d+)', 0), 8) as trade_amount,
        regexpExtract(b.amount, '[A-Z]+', 0) as trade_coin,
        toDecimal64(regexpExtract(b.fee, '(\\d+).(\\d+)', 0), 8) as fee_amount,
        regexpExtract(b.fee, '[A-Z]+', 0) as fee_coin,
        toDecimal64(regexpExtract(b.executed, '(\\d+).(\\d+)', 0), 8) as executed_amount,
        regexpExtract(b.executed, '[A-Z]+', 0) as executed_coin,
        null as realized_profit
    from base_spot as b

    union all

    select
        -- keys
        lower(hex(MD5(concat(b.unique_key, '_', b.r)))) as fk_crypto_trade,
        -- metadata
        '{{ invocation_id }}' as record_source,
        toDateTime(now(), 'Europe/Berlin') as load_dts,
        -- properties
        toDateTime(b.trade_utc_at, 'Europe/Berlin') as trade_at,
        'binance' as platform,
        'USD-M Futures' as wallet,
        b.side,
        b.symbol as pair,
        toDecimal64(regexpExtract(b.amount, '(\\d+).(\\d+)', 0), 8) as trade_amount,
        'UDST' as trade_coin,
        toDecimal64(regexpExtract(b.fee, '(\\d+).(\\d+)', 0), 8) as fee_amount,
        regexpExtract(b.fee, '[A-Z]+', 0) as fee_coin,
        toDecimal64(regexpExtract(b.quantity, '(\\d+).(\\d+)', 0), 8) as executed_amount,
        replace(b.symbol, 'USDT', '') as executed_coin,
        toDecimal64(realized_profit, 8) as realized_profit
    from base_futures as b

)

select * from final
