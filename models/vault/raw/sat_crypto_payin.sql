{{
    config(
        materialized = 'table',
        order_by = 'fk_crypto_payin'
    )
}}

-- select data from sources
-----------------------------------------------
with binance_payins as (

    select * from {{ source('airbyte', 'binance_payins') }}

),

-- implement logic to build the model
-----------------------------------------------
final as (

    select
        -- keys
        lower(hex(MD5(concat('binance_', order_id)))) as fk_crypto_payin,
        -- metadata
        '{{ invocation_id }}' as record_source,
        toDateTime(now(), 'Europe/Berlin') as load_dts,
        -- properties
        'binance' as platform,
        toDateTime(payin_local_at) as payin_at,
        toDecimal32(amount, 2) as amount,
        toDecimal32(fee, 2) as fee_amount,
        coin,
        payment_method
    from binance_payins
    where status = 'Successful'

)

select * from final
