{{
    config(
        materialized = 'table',
        order_by = 'pk_kraken_transaction'
    )
}}

-- select data from source
---------------------------------------------------
with kraken_transaction as (

    select * from {{ source('kraken', 'kraken_transactions') }}

),

-- implement logic to build the model
---------------------------------------------------
final as (

    select
        -- keys
        lower(hex(MD5(concat('kraken_futures_', booking_uid)))) as pk_kraken_transaction,
        -- metadata
        '{{ invocation_id }}' as record_source,
        toDateTime(now(), 'Europe/Berlin') as load_dts,
        -- properties
        id,
        booking_uid,
        execution,
        fromUTCTimestamp(parseDateTime64BestEffort(date, 3), 'Europe/Berlin') as transaction_at,
        info,
        asset,
        contract,
        margin_account,
        toDecimal64(mark_price, 8) as mark_price,
        toDecimal64(trade_price, 8) as trade_price,
        toDecimal64(funding_rate, 8) as funding_rate,
        toDecimal64(realized_pnl, 8) as realized_pnl,
        toDecimal64(realized_funding, 8) as realized_funding,
        toDecimal64(new_balance, 8) as new_balance,
        toDecimal64(old_balance, 8) as old_balance,
        toDecimal64(fee, 8) as fee,
        toDecimal64(liquidation_fee, 8) as liquidation_fee,
        toDecimal64(new_average_entry_price, 8) as new_average_entry_price,
        toDecimal64(old_average_entry_price, 8) as old_average_entry_price
    from kraken_transaction

    qualify row_number() over (partition by booking_uid order by date) = 1 --noqa

)

select * from final
