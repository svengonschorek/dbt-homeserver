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

-- implement logic to build the model
-----------------------------------------------
base as (

    select
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
        lower(hex(MD5(concat(unique_key, '_', r)))) as pk_crypto_trade,
        concat(unique_key, '_', r) as bk_crypto_trade,
        -- metadata
        '{{ invocation_id }}' as record_source,
        toDateTime(now(), 'Europe/Berlin') as load_dts
    from base

)

select * from final
