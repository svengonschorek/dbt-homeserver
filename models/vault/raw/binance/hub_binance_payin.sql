{{
    config(
        materialized = 'table',
        order_by = 'pk_binance_payin'
    )
}}

-- select data from sources
-----------------------------------------------
with binance_payins as (

    select * from {{ source('binance', 'binance_payins') }}

),

-- implement logic to build the model
-----------------------------------------------
final as (

    select
        -- keys
        lower(hex(MD5(concat('binance_', order_id)))) as pk_binance_payin,
        concat('binance_', order_id) as bk_binance_payin,
        -- metadata
        '{{ invocation_id }}' as record_source,
        toDateTime(now(), 'Europe/Berlin') as load_dts
    from binance_payins
    where status = 'Successful'

)

select * from final
