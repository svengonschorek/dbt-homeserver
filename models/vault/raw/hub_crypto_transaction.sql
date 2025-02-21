{{
    config(
        materialized = 'table',
        order_by = 'pk_crypto_transaction'
    )
}}

-- select data from sources
-----------------------------------------------
with binance_transactions_spot as (

    select * from {{ source('airbyte', 'binance_transactions_spot') }}

),

binance_transactions_futures as (

    select * from {{ source('airbyte', 'binance_transactions_futures') }}

),

-- implement logic to build the model
-----------------------------------------------
base_spot as (

    select
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

base_futures as (

    select
        *,
        transaction_id as unique_key,
        row_number() over (
            partition by
                transaction_id
            order by
                amount,
                type
        ) as r
    from binance_transactions_futures
),

final as (

    select
        -- keys
        lower(hex(MD5(concat(unique_key, '_', r)))) as pk_crypto_transaction,
        concat(unique_key, '_', r) as bk_crypto_transaction,
        -- metadata
        '{{ invocation_id }}' as record_source,
        toDateTime(now(), 'Europe/Berlin') as load_dts
    from base_spot

    union all

    select
        -- keys
        lower(hex(MD5(concat(unique_key, '_', r)))) as pk_crypto_transaction,
        concat(unique_key, '_', r) as bk_crypto_transaction,
        -- metadata
        '{{ invocation_id }}' as record_source,
        toDateTime(now(), 'Europe/Berlin') as load_dts
    from base_futures

)

select * from final
