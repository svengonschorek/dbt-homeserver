{{
    config(
        materialized='table',
        order_by='fk_crypto_kline'
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

    select --noqa
        -- keys
        concat('usdteur_1m_', kl.klineAt) as unique_key,
        row_number() over (
            partition by kl.klineAt order by kl.volume desc
        ) as r,
        -- properties
        toDateTime(kl.klineAt / 1000, 'Europe/Berlin') as kline_start_at,
        toDateTime(kl.klineAt / 1000 + 60, 'Europe/Berlin') as kline_end_at,
        toDecimal64(kl.openPrice, 8) as open_price,
        toDecimal64(kl.highPrice, 8) as high_price,
        toDecimal64(kl.lowPrice, 8) as low_price,
        toDecimal64(kl.closePrice, 8) as close_price,
        toDecimal64(kl.volume, 4) as volume,
        toDecimal64(kl.turnover, 8) as turnover
    from bybit_klines_1m_usdt_eur as kl

),

-- final model
-----------------------------------------------
final as (

    select
        -- keys
        lower(hex(MD5(unique_key))) as fk_crypto_kline,
        unique_key as bk_crypto_kline,
        -- metadata
        '{{ invocation_id }}' as record_source,
        toDateTime(now(), 'Europe/Berlin') as load_dts,
        -- properties
        'USDTEUR' as symbol,
        '1m' as kline_interval,
        kline_start_at,
        kline_end_at,
        open_price,
        high_price,
        low_price,
        close_price,
        volume,
        turnover
    from base_bybit
    where r = 1

)

select * from final
