{{
    config(
        materialized = 'table',
        order_by = 'transaction_at'
    )
}}

-- select needed models
-----------------------------------------------
with sat_binance_transaction as (

    select * from {{ ref('sat_binance_transaction') }}

),

calc_binance_transaction_accountbalance as (

    select * from {{ ref('calc_binance_transaction_accountbalance') }}

),

-- join models to create final CTE
-----------------------------------------------
final as (

    select
        -- keys
        sct.fk_binance_transaction,
        -- metadata
        '{{ invocation_id }}' as record_source,
        toDateTime(now(), 'Europe/Berlin') as load_dts,
        -- measures
        sct.change_amount,
        cta.accountbalance,
        -- properties
        'binance' as platform,
        sct.coin,
        sct.transaction_at,
        sct.operation,
        sct.wallet
    from sat_binance_transaction as sct

    inner join calc_binance_transaction_accountbalance as cta
        on sct.fk_binance_transaction = cta.fk_binance_transaction
)

select * from final
