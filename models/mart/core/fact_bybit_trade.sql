{{
    config(
        materialized='table',
        order_by='trade_at'
    )
}}

-- select needed models
-----------------------------------------------
with sat_bybit_trade as (

    select * from {{ ref('calc_bybit_pnl_per_trade') }}

),

-- final model
-----------------------------------------------
final as (

    select
        -- keys
        fk_bybit_trade,
        -- metadata
        '{{ invocation_id }}' as record_source,
        toDateTime(now(), 'Europe/Berlin') as load_dts,
        -- measures
        quantity,
        price,
        price_eur,
        fee_amount,
        fee_amount_eur,
        realized_pnl,
        realized_pnl_eur,
        -- properties
        'bybit' as platform,
        symbol,
        trade_at,
        side,
        execution_type
    from sat_bybit_trade

)

select * from final
