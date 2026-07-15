{{
    config(
        materialized = 'table',
        order_by = 'pk_bybit_trade'
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
        lower(hex(MD5(concat('bybit_', lower(symbol), '_', unique_key)))) as pk_bybit_trade,
        concat('bybit_', lower(symbol), '_', unique_key) as bk_crypto_trade,
        -- metadata
        '{{ invocation_id }}' as record_source,
        toDateTime(now(), 'Europe/Berlin') as load_dts
    from base_bybit
    where r = 1

)

select * from final
