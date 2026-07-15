{{
    config(
        materialized='table',
        order_by='fk_bybit_trade'
    )
}}

-- select needed models
-----------------------------------------------

with sat_bybit_trade as (

    select * from {{ ref('sat_bybit_trade') }}

),

sat_bybit_kline as (

    select * from {{ ref('sat_bybit_kline') }}
    where symbol = 'USDTEUR' and kline_interval = '1m'

),

-- create base with all trades and their properties, including price in EUR
-----------------------------------------------

base as (

    select
        t.fk_bybit_trade,
        t.symbol,
        t.trade_at,
        t.side,
        t.execution_type,
        t.price,
        t.fee_amount,
        t.price * toDecimal32(k.close_price, 4) as price_eur,
        t.fee_amount * toDecimal32(k.close_price, 4) as fee_amount_eur,
        case
            when t.side = 'Buy' and t.execution_type = 'Trade'
                then t.quantity
            when t.side = 'Sell' and t.execution_type = 'Trade'
                then -1 * t.quantity
            else 0
        end as quantity
    from sat_bybit_trade as t

    inner join sat_bybit_kline as k
        on k.kline_start_at = toStartOfMinute(t.trade_at)

),

-- split trades into legs (long open, long close, short open, short close)
-----------------------------------------------

with_position as (

    select
        b.fk_bybit_trade,
        b.symbol,
        b.trade_at,
        b.side,
        b.execution_type,
        b.price,
        b.price_eur,
        b.quantity,
        coalesce(
            sum(b.quantity) over (
                partition by
                    b.symbol
                order by
                    b.trade_at,
                    b.fk_bybit_trade
                rows between unbounded preceding and 1 preceding
            ), 0
        ) as net_before
    from base as b

),

legs as (

    select
        fk_bybit_trade,
        symbol,
        trade_at,
        price,
        price_eur,
        'long_close' as leg_type,
        least(-quantity, net_before) as qty
    from with_position
    where quantity < 0 and net_before > 0

    union all

    select
        fk_bybit_trade,
        symbol,
        trade_at,
        price,
        price_eur,
        'short_close' as leg_type,
        least(quantity, -net_before) as qty
    from with_position
    where quantity > 0 and net_before < 0

    union all

    select
        fk_bybit_trade,
        symbol,
        trade_at,
        price,
        price_eur,
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
        fk_bybit_trade,
        symbol,
        trade_at,
        price,
        price_eur,
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
        fk_bybit_trade,
        symbol,
        price as buy_price,
        price_eur as buy_price_eur,
        coalesce(sum(qty) over (
            partition by symbol
            order by trade_at, fk_bybit_trade
            rows between unbounded preceding and 1 preceding
        ), 0) as cum_before,
        sum(qty) over (
            partition by symbol
            order by trade_at, fk_bybit_trade
        ) as cum_after
    from legs
    where leg_type = 'long_open'

),

long_closes as (

    select
        fk_bybit_trade,
        symbol,
        price as sell_price,
        price_eur as sell_price_eur,
        coalesce(sum(qty) over (
            partition by symbol
            order by trade_at, fk_bybit_trade
            rows between unbounded preceding and 1 preceding
        ), 0) as cum_before,
        sum(qty) over (
            partition by symbol
            order by trade_at, fk_bybit_trade
        ) as cum_after
    from legs
    where leg_type = 'long_close'

),

short_opens as (

    select
        fk_bybit_trade,
        symbol,
        price as sell_price,
        price_eur as sell_price_eur,
        coalesce(sum(qty) over (
            partition by symbol
            order by trade_at, fk_bybit_trade
            rows between unbounded preceding and 1 preceding
        ), 0) as cum_before,
        sum(qty) over (
            partition by symbol
            order by trade_at, fk_bybit_trade
        ) as cum_after
    from legs
    where leg_type = 'short_open'

),

short_closes as (

    select
        fk_bybit_trade,
        symbol,
        price as buy_price,
        price_eur as buy_price_eur,
        coalesce(sum(qty) over (
            partition by symbol
            order by trade_at, fk_bybit_trade
            rows between unbounded preceding and 1 preceding
        ), 0) as cum_before,
        sum(qty) over (
            partition by symbol
            order by trade_at, fk_bybit_trade
        ) as cum_after
    from legs
    where leg_type = 'short_close'

),

-- calculate PnL per trade using FIFO approach
-----------------------------------------------

pnl_fifo as (

    select
        c.fk_bybit_trade,
        sum(
            (c.sell_price - o.buy_price)
            * (least(o.cum_after, c.cum_after) - greatest(o.cum_before, c.cum_before))
        ) as realized_pnl,
        sum(
            (c.sell_price_eur - o.buy_price_eur)
            * (least(o.cum_after, c.cum_after) - greatest(o.cum_before, c.cum_before))
        ) as realized_pnl_eur
    from long_closes as c
    cross join long_opens as o
    where
        o.symbol = c.symbol
        and o.cum_before < c.cum_after
        and o.cum_after > c.cum_before
    group by
        c.fk_bybit_trade

    union all

    select
        c.fk_bybit_trade,
        sum(
            (o.sell_price - c.buy_price)
            * (least(o.cum_after, c.cum_after) - greatest(o.cum_before, c.cum_before))
        ) as realized_pnl,
        sum(
            (o.sell_price_eur - c.buy_price_eur)
            * (least(o.cum_after, c.cum_after) - greatest(o.cum_before, c.cum_before))
        ) as realized_pnl_eur
    from short_closes as c
    cross join short_opens as o
    where
        o.symbol = c.symbol
        and o.cum_before < c.cum_after
        and o.cum_after > c.cum_before
    group by
        c.fk_bybit_trade

),

-- join PnL back to base to get final model with PnL per trade
-----------------------------------------------

final as (

    select
        b.fk_bybit_trade,
        b.symbol,
        b.trade_at,
        b.side,
        b.execution_type,
        b.price,
        b.price_eur,
        b.quantity,
        b.fee_amount,
        b.fee_amount_eur,
        coalesce(p.realized_pnl, 0) as realized_pnl,
        coalesce(p.realized_pnl_eur, 0) as realized_pnl_eur
    from base as b
    left join pnl_fifo as p
        on b.fk_bybit_trade = p.fk_bybit_trade

)

select * from final
