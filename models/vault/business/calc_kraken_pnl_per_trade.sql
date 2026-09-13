{{
    config(
        materialized = 'table',
        order_by = 'fk_kraken_trade'
    )
}}

-- select needed models
-----------------------------------------------
with sat_kraken_position as (

    select * from {{ ref('sat_kraken_position') }}

),

sat_kraken_ohlc as (

    select * from {{ ref('sat_kraken_ohlc') }}
    where symbol = 'PF_EURUSD'

),

-- create base with all positions and caculate the amounts into EUR
-----------------------------------------------
base as (

    select --noqa
        p.fk_kraken_position as fk_kraken_trade,
        p.contract as symbol,
        p.fill_at as trade_at,
        case
            when p.new_position > p.old_position
                then 'Buy'
            when p.new_position < p.old_position
                then 'Sell'
            else 'Funding'
        end as side,
        case
            when p.update_reason = 'fundingRealisation'
                then 'Funding'
            when p.update_reason = 'trade'
                then 'Trade'
            else p.update_reason
        end as execution_type,
        p.execution_price as price,
        p.execution_price / toDecimal32(o.close_price, 4) as price_eur,
        p.execution_size as quantity,
        coalesce(p.fee, 0) - coalesce(p.realized_funding, 0) as fee_amount,
        (coalesce(p.fee, 0) - coalesce(p.realized_funding, 0)) / toDecimal32(o.close_price, 4) as fee_amount_eur,
        coalesce(p.realized_pnl, 0) as realized_pnl,
        coalesce(p.realized_pnl, 0) / toDecimal32(o.close_price, 4) as realized_pnl_eur
    from sat_kraken_position as p

    inner join sat_kraken_ohlc as o
        on o.ohlc_at = toStartOfMinute(p.fill_at)

),

-- select final model
-----------------------------------------------
final as (

    select
        b.fk_kraken_trade,
        b.symbol,
        b.trade_at,
        b.side,
        b.execution_type,
        b.price,
        b.price_eur,
        b.quantity,
        b.fee_amount,
        b.fee_amount_eur,
        b.realized_pnl,
        b.realized_pnl_eur
    from base as b

)

select * from final
