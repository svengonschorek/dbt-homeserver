{{
    config(
        materialized='table',
        order_by='fk_crypto_trade'
    )
}}

with sat_crypto_trade as (

    select * from {{ ref('sat_crypto_trade_bybit') }}

),

base as (

    select
        t.fk_crypto_trade,
        t.symbol,
        t.trade_at,
        t.side,
        t.execution_type,
        t.price,
        t.fee_amount,
        case
            when t.side = 'Buy' and t.execution_type = 'Trade'
                then t.quantity
            when t.side = 'Sell' and t.execution_type = 'Trade'
                then -1 * t.quantity
            else 0
        end as quantity
    from sat_crypto_trade as t

),

with_position as (

    select
        b.fk_crypto_trade,
        b.symbol,
        b.trade_at,
        b.side,
        b.execution_type,
        b.price,
        b.quantity,
        coalesce(
            sum(b.quantity) over (
                partition by
                    b.symbol
                order by
                    b.trade_at,
                    b.fk_crypto_trade
                rows between unbounded preceding and 1 preceding
            ), 0
        ) as net_before
    from base as b

),

legs as (

    select
        fk_crypto_trade,
        symbol,
        trade_at,
        price,
        'long_close' as leg_type,
        least(-quantity, net_before) as qty
    from with_position
    where quantity < 0 and net_before > 0

    union all

    select
        fk_crypto_trade,
        symbol,
        trade_at,
        price,
        'short_close' as leg_type,
        least(quantity, -net_before) as qty
    from with_position
    where quantity > 0 and net_before < 0

    union all

    select
        fk_crypto_trade,
        symbol,
        trade_at,
        price,
        'long_open' as leg_type,
        case
            when net_before >= 0 then quantity
            else quantity + net_before
        end as qty
    from with_position
    where
        quantity > 0
        and (net_before >= 0 or quantity + net_before > 0)

    union all

    select
        fk_crypto_trade,
        symbol,
        trade_at,
        price,
        'short_open' as leg_type,
        case
            when net_before <= 0 then -quantity
            else -quantity - net_before
        end as qty
    from with_position
    where
        quantity < 0
        and (net_before <= 0 or -quantity - net_before > 0)

),

long_opens as (

    select
        fk_crypto_trade,
        symbol,
        price as buy_price,
        coalesce(sum(qty) over (
            partition by symbol
            order by trade_at, fk_crypto_trade
            rows between unbounded preceding and 1 preceding
        ), 0) as cum_before,
        sum(qty) over (
            partition by symbol
            order by trade_at, fk_crypto_trade
        ) as cum_after
    from legs
    where leg_type = 'long_open'

),

long_closes as (

    select
        fk_crypto_trade,
        symbol,
        price as sell_price,
        coalesce(sum(qty) over (
            partition by symbol
            order by trade_at, fk_crypto_trade
            rows between unbounded preceding and 1 preceding
        ), 0) as cum_before,
        sum(qty) over (
            partition by symbol
            order by trade_at, fk_crypto_trade
        ) as cum_after
    from legs
    where leg_type = 'long_close'

),

short_opens as (

    select
        fk_crypto_trade,
        symbol,
        price as sell_price,
        coalesce(sum(qty) over (
            partition by symbol
            order by trade_at, fk_crypto_trade
            rows between unbounded preceding and 1 preceding
        ), 0) as cum_before,
        sum(qty) over (
            partition by symbol
            order by trade_at, fk_crypto_trade
        ) as cum_after
    from legs
    where leg_type = 'short_open'

),

short_closes as (

    select
        fk_crypto_trade,
        symbol,
        price as buy_price,
        coalesce(sum(qty) over (
            partition by symbol
            order by trade_at, fk_crypto_trade
            rows between unbounded preceding and 1 preceding
        ), 0) as cum_before,
        sum(qty) over (
            partition by symbol
            order by trade_at, fk_crypto_trade
        ) as cum_after
    from legs
    where leg_type = 'short_close'

),

pnl_fifo as (

    select
        c.fk_crypto_trade,
        sum(
            (c.sell_price - o.buy_price)
            * (least(o.cum_after, c.cum_after) - greatest(o.cum_before, c.cum_before))
        ) as realized_pnl
    from long_closes as c
    cross join long_opens as o
    where
        o.symbol = c.symbol
        and o.cum_before < c.cum_after
        and o.cum_after > c.cum_before
    group by
        c.fk_crypto_trade

    union all

    select
        c.fk_crypto_trade,
        sum(
            (o.sell_price - c.buy_price)
            * (least(o.cum_after, c.cum_after) - greatest(o.cum_before, c.cum_before))
        ) as realized_pnl
    from short_closes as c
    cross join short_opens as o
    where
        o.symbol = c.symbol
        and o.cum_before < c.cum_after
        and o.cum_after > c.cum_before
    group by
        c.fk_crypto_trade

),

final as (

    select
        b.fk_crypto_trade,
        b.symbol,
        b.trade_at,
        b.side,
        b.execution_type,
        b.price,
        b.quantity,
        b.fee_amount,
        coalesce(p.realized_pnl, 0) as realized_pnl
    from base as b
    left join pnl_fifo as p
        on b.fk_crypto_trade = p.fk_crypto_trade

)

select * from final
