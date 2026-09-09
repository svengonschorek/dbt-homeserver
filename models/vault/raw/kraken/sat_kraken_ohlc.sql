{{
    config(
        materialized = 'table',
        order_by = 'fk_kraken_ohlc'
    )
}}

-- select data from source
---------------------------------------------------
with kraken_ohlc as (
        
    select * from {{ source('kraken', 'kraken_ohlc_eur_usd') }}

),

-- implement logic to build the model
---------------------------------------------------
final as (
    
    select
        -- keys
        lower(hex(MD5(concat('eur_usd_1m_', time)))) as fk_kraken_ohlc,
        -- metadata
        '{{ invocation_id }}' as record_source,
        toDateTime(now(), 'Europe/Berlin') as load_dts,
        -- properties
        fromUnixTimestamp64Milli(toInt64(time), 'Europe/Berlin') as ohlc_at,
        'PF_EURUSD' as symbol,
        open as open_price,
        high as high_price,
        low as low_price,
        close as close_price,
        volume as volume
    from kraken_ohlc

    qualify row_number() over (partition by time) = 1 --noqa

)

select * from final
