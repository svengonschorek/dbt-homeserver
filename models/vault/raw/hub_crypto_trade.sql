{{
    config(
        materialized = 'table',
        order_by = 'pk_crypto_trade'
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

bybit_trades as (

    select * from {{ source('bybit', 'bybit_trades') }}

),

-- implement logic to build the model
-----------------------------------------------
base_spot as (

    select
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
        trade_id as unique_key,
        row_number() over (
            partition by
                trade_id
            order by
                amount
        ) as r
    from binance_trades_futures

),

base_bybit as (

    select
        execId as unique_key,
        symbol,
        row_number() over (
            partition by
                execId
            order by
                execTime desc
        ) as r
    from bybit_trades

),

final as (

    select
        -- keys
        lower(hex(MD5(concat(unique_key, '_', r)))) as pk_crypto_trade,
        concat(unique_key, '_', r) as bk_crypto_trade,
        -- metadata
        '{{ invocation_id }}' as record_source,
        toDateTime(now(), 'Europe/Berlin') as load_dts
    from base_spot

    union all

    select
        -- keys
        lower(hex(MD5(concat(unique_key, '_', r)))) as pk_crypto_trade,
        concat(unique_key, '_', r) as bk_crypto_trade,
        -- metadata
        '{{ invocation_id }}' as record_source,
        toDateTime(now(), 'Europe/Berlin') as load_dts
    from base_futures

    union all

    select
        -- keys
        lower(hex(MD5(concat('bybit_', lower(symbol), '_', unique_key)))) as pk_crypto_trade,
        concat('bybit_', lower(symbol), '_', unique_key) as bk_crypto_trade,
        -- metadata
        '{{ invocation_id }}' as record_source,
        toDateTime(now(), 'Europe/Berlin') as load_dts
    from base_bybit

)

select * from final
