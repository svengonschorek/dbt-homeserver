{{
    config(
        materialized = 'table',
        order_by = 'pk_bybit_pnl'
    )
}}

-- select data from sources
-----------------------------------------------
with crypto_pnl as (

    select * from {{ source('bybit', 'bybit_pnl') }}

),

-- implement logic to build the model
-----------------------------------------------
final as (
    select
        -- keys
        lower(hex(MD5(concat('bybit_', lower(symbol), '_', orderId)))) as pk_bybit_pnl,
        concat('bybit_', lower(symbol), '_', orderId) as bk_bybit_pnl,
        -- metadata
        '{{ invocation_id }}' as record_source,
        toDateTime(now(), 'Europe/Berlin') as load_dts
    from crypto_pnl

)

select * from final
