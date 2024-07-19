{{
    config(
        materialized = 'table',
        order_by = 'fk_crypto_order'
    )
}}

-- select data from sources
-----------------------------------------------
with binance_orders_spot as (

    select * from {{ source('binance', 'binance_orders_spot') }}

),

-- implement logic to build the model
-----------------------------------------------
base as (

    select
        concat(
            'binance_',
            lower(side),
            '_',
            toUnixTimestamp(order_utc_at),
            '_',
            lower(pair),
            '_',
            lower(type)
        ) as unique_key,
        row_number() over (
            partition by
                side,
                order_utc_at,
                pair,
                type
            order by
                trading_total
        ) as r,
        *
    from binance_orders_spot
    where status = 'FILLED'

),

final as (

    select
        -- keys
        lower(hex(MD5(concat(b.unique_key, '_', b.r)))) as fk_crypto_order,
        -- metadata
        '{{ invocation_id }}' as record_source,
        toDateTime(now(), 'Europe/Berlin') as load_dts,
        -- properties
        toDateTime(b.order_utc_at, 'Europe/Berlin') as order_at,
        b.side,
        b.pair,
        b.type,
        toDecimal64(regexpExtract(b.order_amount, '(\\d+).(\\d+)', 0), 8) as order_amount,
        regexpExtract(b.order_amount, '[A-Z]+', 0) as order_coin,
        toDecimal64(b.order_price, 8) as order_price,
        toDecimal64(regexpExtract(b.executed, '(\\d+).(\\d+)', 0), 8) as executed_amount,
        toDecimal64(b.average_price, 8) as executed_price,
        toDecimal64(regexpExtract(b.trading_total, '(\\d+).(\\d+)', 0), 8) as trade_amount,
        regexpExtract(b.trading_total, '[A-Z]+', 0) as trade_coin
    from base as b

)

select * from final
