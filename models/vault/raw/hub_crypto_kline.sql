{{
    config(
        materialized='table',
        order_by='pk_crypto_kline'
    )
}}

-- select data from sources
-----------------------------------------------
with bybit_klines_1m_usdt_eur as (

    select * from {{ source('bybit', 'bybit_kline_1m_usdt_eur') }}

),

-- implement logic to build the model
-----------------------------------------------
base_bybit as (

    select
        concat('usdteur_1m_', klineAt) as unique_key,
        row_number() over (
            partition by klineAt order by volume desc
        ) as r
    from bybit_klines_1m_usdt_eur

),

-- final model
-----------------------------------------------
final as (

    select
        -- keys
        lower(hex(MD5(unique_key))) as pk_crypto_kline,
        unique_key as bk_crypto_kline,
        -- metadata
        '{{ invocation_id }}' as record_source,
        toDateTime(now(), 'Europe/Berlin') as load_dts
    from base_bybit
    where r = 1

)

select * from final
