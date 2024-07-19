{{
    config(
        materialized = 'table',
        order_by = 'fk_crypto_transaction'
    )
}}

-- select data from sources
-----------------------------------------------
with binance_transactions_spot as (

    select * from {{ source('binance', 'binance_transactions_spot') }}

),

-- implement logic to build the model
-----------------------------------------------
base as (

    select
        *,
        concat(
            'binance',
            '_',
            lower(replace(account, ' ', '_')),
            '_',
            lower(coin),
            '_',
            lower(replace(operation, ' ', '_')),
            '_',
            toUnixTimestamp(transaction_utc_at)
        ) as unique_key,
        row_number() over (
            partition by
                account,
                coin,
                operation,
                transaction_utc_at
            order by
                change
        ) as r
    from binance_transactions_spot

),

final as (

    select
        -- keys
        lower(hex(MD5(concat(b.unique_key, '_', b.r)))) as fk_crypto_transaction,
        -- metadata
        '{{ invocation_id }}' as record_source,
        toDateTime(now(), 'Europe/Berlin') as load_dts,
        -- properties
        toDateTime(b.transaction_utc_at, 'Europe/Berlin') as transaction_at,
        b.account as wallet,
        b.operation,
        toDecimal64(b.change, 8) as change_amount,
        b.coin
    from base as b

)

select * from final
