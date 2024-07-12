-- SQL queries

SELECT string_agg(name, ' + ') AS expression
FROM accounts
WHERE number % 1000 = 0
GROUP BY normal;


\timing [on|off]       toggle timing of commands (currently off)

-- old stuff


create materialized view transactions_by_account
with (
  timescaledb.continuous,
  timescaledb.materialized_only = false
) as
select
  debit_account_id,
  credit_account_id,
  time_bucket(INTERVAL '1 hour', created_at) AS bucket,
  sum(amount) as amount
from transactions
group by bucket, debit_account_id, credit_account_id;

create index idx_transactions_by_account_bucket_debit
  on transactions_by_account (debit_account_id);

create index idx_transactions_by_account_bucket_credit
  on transactions_by_account (credit_account_id);


-- seed data


--


---

\timing on

do language plpgsql
$$
declare
  batch_size int := 100000;
  total_records int := 10000000;
  current_start int := 1;
  current_end int;
begin
  -- current_start should be the greatest id in the table plus 1
select coalesce(max(id), 0) + 1 into current_start from transactions;
    
  while current_start <= total_records loop
    current_end := current_start + batch_size - 1;
    if current_end > total_records then
      current_end := total_records;
    end if;

    start transaction;

    insert into transactions (id, debit_account_id, credit_account_id, amount, created_at)
    select 
      gs.i, 
      -- (array[1000, 1100, 1110, 1120, 1200, 1300, 5000, 5100, 5200, 5300, 5400])[floor(random()*11)::int + 1] as debit_account_id,
      (array[1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 5400])[floor(random()*11)::int + 1] as debit_account_id,
      (array[2000, 2100, 2200, 2300, 3000, 3100, 3200, 4000, 4100, 4200])[floor(random()*10)::int + 1] as credit_account_id,
      (random() * 10000)::bigint + 1 as amount,
      '2024-01-01'::date - interval '5 years' + interval '5 years' * gs.i / total_records as created_at
    from generate_series(current_start, current_end) as gs(i);

    commit;

    current_start := current_end + 1;

    -- print progress
    raise notice 'Inserted % records up to id %', current_end, current_end;
  end loop;
end;
$$;

-- insert into transactions (id, debit_account_id, credit_account_id, amount, created_at)
-- select 
--   gs.i, 
--   (array[1000, 1100, 1110, 1120, 1200, 1300, 5000, 5100, 5200, 5300, 5400])[floor(random()*11)::int + 1] as debit_account_id,
--   (array[2000, 2100, 2200, 2300, 3000, 3100, 3200, 4000, 4100, 4200])[floor(random()*10)::int + 1] as credit_account_id,
--   (random() * 10000)::bigint + 1 as amount,
--   '2024-01-01'::date - interval '5 years' + interval '5 years' * gs.i / 100000 as created_at
-- from generate_series(1, 10000) as gs(i);

call refresh_continuous_aggregate('transactions_by_debit_account', null, now() - interval '6 years');

select sum(amount) from transactions where debit_account_id = 1000;
select sum(amount) from transactions_by_debit_account where debit_account_id = 1000;

select hypertable_detailed_size('transactions');
select chunks_detailed_size('transactions');
select chunks_detailed_size('transactions_by_debit_account');
select chunks_detailed_size('transactions_by_credit_account');

SELECT job_id, pid, proc_schema, proc_name, succeeded, config, sqlerrcode, err_message
FROM timescaledb_information.job_history
ORDER BY id, job_id;


select count(*) from transactions;

start transaction isolation level SERIALIZABLE;
select sum(amount) from transactions where debit_account_id = 1000;
select sum(amount) from transactions_by_debit_account where debit_account_id = 1000;
commit;


select id from _timescaledb_catalog.hypertable
    where table_name=(
        select materialization_hypertable_name
            from timescaledb_information.continuous_aggregates
            where view_name='transactions_by_credit_account'
    );