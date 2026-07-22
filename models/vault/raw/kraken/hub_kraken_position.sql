{{
    config(
        materialized = 'table',
        order_by = 'pk_kraken_position'
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
        end as pk_kraken_position,
        case
            when updateReason = 'fundingRealisation'
                then concat('kraken_futures_funding_', lower(tradeable), '_', timestamp)
            else concat('kraken_futures_', executionUid, '_', timestamp)
        end as bk_kraken_position,
        -- metadata
        '{{ invocation_id }}' as record_source,
        toDateTime(now(), 'Europe/Berlin') as load_dts
    from kraken_positions

    qualify row_number() over (partition by executionUid, timestamp) = 1 --noqa

)

select * from final
