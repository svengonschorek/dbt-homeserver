{{
    config(
        materialized = 'table',
        order_by = 'pk_kraken_ticker'
    )
}}

-- select data from source
---------------------------------------------------
with kraken_ticker as (

    select * from {{ source('kraken', 'kraken_tickers') }}

),

-- implement logic to build the model
---------------------------------------------------
final as (

    select
        -- keys
        lower(hex(MD5(concat('kraken_futures_', lower(symbol), '_', lower(tag))))) as pk_kraken_ticker,
        concat('kraken_futures_', lower(symbol), '_', lower(tag)) as bk_kraken_ticker,
        -- metadata
        '{{ invocation_id }}' as record_source,
        toDateTime(now(), 'Europe/Berlin') as load_dts
    from kraken_ticker

)

select * from final
