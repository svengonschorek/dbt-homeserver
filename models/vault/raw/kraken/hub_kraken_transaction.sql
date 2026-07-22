{{
    config(
        materialized = 'table',
        order_by = 'pk_kraken_transaction'
    )
}}

-- select data from source
---------------------------------------------------
with kraken_transaction as (

    select * from {{ source('kraken', 'kraken_transactions') }}

),

-- implement logic to build the model
---------------------------------------------------
final as (

    select
        -- keys
        lower(hex(MD5(concat('kraken_futures_', booking_uid)))) as pk_kraken_transaction,
        concat('kraken_futures_', booking_uid) as bk_kraken_transaction,
        -- metadata
        '{{ invocation_id }}' as record_source,
        toDateTime(now(), 'Europe/Berlin') as load_dts
    from kraken_transaction

)

select * from final
