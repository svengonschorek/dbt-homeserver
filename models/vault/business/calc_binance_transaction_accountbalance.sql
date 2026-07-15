{{
    config(
        materialized = 'table',
        order_by = 'fk_binance_transaction'
    )
}}

-- select data
-----------------------------------------------
with sat_binance_transaction as (

    select * from {{ ref('sat_binance_transaction') }}

),

-- apply calculation logic
-----------------------------------------------

final as (

    select
        -- keys
        fk_binance_transaction,
        -- metadata
        '{{ invocation_id }}' as record_source,
        toDateTime(now(), 'Europe/Berlin') as load_dts,
        -- properties
        sum(change_amount) over (
            partition by
                wallet,
                coin
            order by
                transaction_at asc,
                change_amount desc
        ) as accountbalance
    from sat_binance_transaction

)

select * from final
