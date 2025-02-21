{{
    config(
        materialized = 'table',
        order_by = 'pk_crypto_trade'
    )
}}

-- select data from sources
-----------------------------------------------
with binance_trades_spot as (

    select * from {{ source('airbyte', 'binance_trades_spot') }}

),

binance_trades_futures as (

    select * from {{ source('airbyte', 'binance_trades_futures') }}

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

)

select * from final
