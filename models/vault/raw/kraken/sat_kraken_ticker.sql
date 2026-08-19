{{
    config(
        materialized = 'table',
        order_by = 'fk_kraken_ticker'
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
        lower(hex(MD5(concat('kraken_futures_', lower(symbol), '_', lower(tag))))) as fk_kraken_ticker,
        -- metadata
        '{{ invocation_id }}' as record_source,
        toDateTime(now(), 'Europe/Berlin') as load_dts,
        -- properties
        tag,
        symbol,
        pair,
        suspended as is_suspended,
        postOnly as is_post_only,
        toTimeZone(fromUTCTimestamp(parseDateTime64BestEffortOrNull(lastTime, 6), 'UTC'), 'Europe/Berlin') as last_trade_at,
        toDecimal64(last, 8) as last_price,
        toDecimal64(lastSize, 8) as last_size,
        toDecimal64(bid, 8) as bid_price,
        toDecimal128(bidSize, 8) as bid_size,
        toDecimal64(ask, 8) as ask_price,
        toDecimal128(askSize, 8) as ask_size,
        toDecimal64(markPrice, 8) as mark_price,
        toDecimal64(indexPrice, 8) as index_price,
        toDecimal64(vwap24h, 8) as vwap_24h,
        toDecimal64(open24h, 8) as open_24h,
        toDecimal64(high24h, 8) as high_24h,
        toDecimal64(low24h, 8) as low_24h,
        toDecimal64(change24h, 8) as change_24h,
        toDecimal128(vol24h, 8) as volume_24h,
        toDecimal64(volumeQuote, 8) as volume_quote,
        toDecimal128(openInterest, 8) as open_interest,
        toDecimal64(fundingRate, 8) as funding_rate,
        toDecimal64(fundingRatePrediction, 8) as funding_rate_prediction
    from kraken_ticker

)

select * from final
