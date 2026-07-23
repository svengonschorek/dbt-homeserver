{{
    config(
        materialized = 'table',
        order_by = 'fk_kraken_position'
    )
}}

-- select data from source
---------------------------------------------------
with kraken_positions as (

    select * from {{ source('kraken', 'kraken_positions') }}

),

-- implement logic to build the model
---------------------------------------------------
final as (

    select
        -- keys
        case
            when updateReason = 'fundingRealisation'
                then lower(hex(MD5(concat('kraken_futures_funding_', lower(tradeable), '_', timestamp))))
            else lower(hex(MD5(concat('kraken_futures_', executionUid, '_', timestamp))))
        end as fk_kraken_position,
        -- metadata
        '{{ invocation_id }}' as record_source,
        toDateTime(now(), 'Europe/Berlin') as load_dts,
        -- properties
        accountUid as account_id,
        executionUid as execution_id,
        lower(tradeable) as contract,
        updateReason as update_reason,
        tradeType as trade_type,
        fromUnixTimestamp64Milli(toInt64(fillTime), 'Europe/Berlin') as fill_at,
        fromUnixTimestamp64Milli(toInt64(timestamp), 'Europe/Berlin') as update_at,
        toDecimal64(newPosition, 8) as new_position,
        toDecimal64(oldPosition, 8) as old_position,
        toDecimal64(fee, 8) as fee,
        feeCurrency as fee_currency,
        toDecimal64(realizedPnL, 8) as realized_pnl,
        toDecimal64(executionSize, 8) as execution_size,
        toDecimal64(executionPrice, 8) as execution_price,
        toDecimal64(positionChange, 8) as position_change,
        fromUnixTimestamp64Milli(toInt64(fundingRealizationTime), 'Europe/Berlin') as funding_at,
        toDecimal64(realizedFunding, 8) as realized_funding,
        toDecimal64(newAverageEntryPrice, 8) as new_average_entry_price,
        toDecimal64(oldAverageEntryPrice, 8) as old_average_entry_price
    from kraken_positions

    qualify row_number() over (partition by executionUid, timestamp) = 1 --noqa

)

select * from final
