{{
    config(
        materialized = 'table',
        order_by = 'pk_kraken_ohlc'
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
        lower(hex(MD5(concat('eur_usd_1m_', time)))) as pk_kraken_ohlc,
        concat('eur_usd_1m_', time) as bk_kraken_ohlc,
        -- metadata
        '{{ invocation_id }}' as record_source,
        toDateTime(now(), 'Europe/Berlin') as load_dts
    from kraken_ohlc

    qualify row_number() over (partition by time) = 1 --noqa

)

select * from final
