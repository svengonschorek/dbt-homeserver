{{
    config(
        materialized = 'table',
        order_by = 'pk_crypto_order'
    )
}}

-- select data from sources
-----------------------------------------------
with binance_orders_spot as (

    select * from {{ source('airbyte', 'binance_orders_spot') }}

),

-- implement logic to build the model
-----------------------------------------------
base as (

    select
        concat(
            'binance',
            '_',
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
        ) as r
    from binance_orders_spot
    where status = 'FILLED'

),

final as (

    select
        -- keys
        lower(hex(MD5(concat(unique_key, '_', r)))) as pk_crypto_order,
        concat(unique_key, '_', r) as bk_crypto_order,
        -- metadata
        '{{ invocation_id }}' as record_source,
        toDateTime(now(), 'Europe/Berlin') as load_dts
    from base

)

select * from final
