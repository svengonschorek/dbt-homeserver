{{
    config(
        materialized='table',
        order_by='fk_crypto_trade'
    )
}}

with sat_crypto_trade as (

    select
        t.fk_crypto_trade,
        t.symbol,
        t.trade_at,
        t.side,
        case
            when t.side = 'Buy' and t.execution_type = 'Trade'
                then quantity
            when t.side = 'Sell' and t.execution_type = 'Trade'
                then -1 * t.quantity
            else 0
        end as quantity,
        t.price,
        case
            when t.side = 'Buy' and t.execution_type = 'Trade'
                then t.quantity * t.price
            when t.side = 'Sell' and t.execution_type = 'Trade'
                then -1 * t.quantity * t.price
            else 0
        end as execution_value,
        rank() over (
            order by
                t.trade_at,
                t.fk_crypto_trade
        ) as r
    from {{ ref('sat_crypto_trade_bybit') }} as t

),

final as (

    select
        *
    from sat_crypto_trade

)

select * from final
