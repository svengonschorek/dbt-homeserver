{{
    config(
        materialized = 'table',
        order_by = 'fk_binance_transaction'
    )
}}

-- select data from sources
-----------------------------------------------
with binance_transactions_spot as (

    select * from {{ source('binance', 'binance_transactions_spot') }}

),

binance_transactions_futures as (

    select * from {{ source('binance', 'binance_transactions_futures') }}

),

-- implement logic to build the model
-----------------------------------------------
base_spot as (

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
        lower(hex(MD5(concat(b.unique_key, '_', b.r)))) as fk_binance_transaction,
        -- metadata
        '{{ invocation_id }}' as record_source,
        toDateTime(now(), 'Europe/Berlin') as load_dts,
        -- properties
        toDateTime(b.transaction_utc_at, 'Europe/Berlin') as transaction_at,
        'Spot' as wallet,
        b.account as from_wallet,
        b.operation,
        toDecimal64(b.change, 8) as change_amount,
        b.coin
    from base_spot as b

    union all

    select
        -- keys
        lower(hex(MD5(concat(b.unique_key, '_', b.r)))) as fk_binance_transaction,
        -- metadata
        '{{ invocation_id }}' as record_source,
        toDateTime(now(), 'Europe/Berlin') as load_dts,
        -- properties
        toDateTime(b.transaction_utc_at, 'Europe/Berlin') as transaction_at,
        'USD-M Futures' as wallet,
        case
            when type = 'TRANSFER'
                then 'Spot'
            else 'USD-M Futures'
        end as from_wallet,
        b.type as operation,
        toDecimal64(b.amount, 8) as change_amount,
        b.asset as coin
    from base_futures as b

)

select * from final
