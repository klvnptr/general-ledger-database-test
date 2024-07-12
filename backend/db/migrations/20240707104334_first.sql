-- +goose NO TRANSACTION
-- +goose Up

create table accounts (
  id int,
  name text,
  normal smallint
);

create table transactions (
  id bigint,
  debit_account_id int,
  credit_account_id int,

  amount bigint,

  created_at timestamp
);


select create_hypertable('transactions', by_range('created_at', interval '1 week'));


create materialized view transactions_by_debit_account
with (
  timescaledb.continuous,
  timescaledb.materialized_only = false
) as
select
  time_bucket(interval '1 hour', created_at) AS bucket,
  debit_account_id,
  sum(amount) as amount
from transactions
group by bucket, debit_account_id;

create index idx_transactions_by_debit_account_bucket
  on transactions_by_debit_account (debit_account_id);

select add_continuous_aggregate_policy('transactions_by_debit_account',
  start_offset => interval '6 years',
  end_offset => null,
  -- end_offset => interval '1 hour',
  schedule_interval => interval '10 seconds');


create materialized view transactions_by_credit_account
with (
  timescaledb.continuous,
  timescaledb.materialized_only = false
) as
select
  time_bucket(interval '1 hour', created_at) AS bucket,
  credit_account_id,
  sum(amount) as amount
from transactions
group by bucket, credit_account_id;

create index idx_transactions_by_credit_account_bucket
  on transactions_by_credit_account (credit_account_id);

select add_continuous_aggregate_policy('transactions_by_credit_account',
  start_offset => interval '6 years',
  end_offset => interval '1 day',
  schedule_interval => interval '1 minute');

-- Seed data for chart of accounts
insert into accounts (id, name, normal) values

-- Asset Accounts (negative balances for increase with debits)
(1000, 'Assets', -1),
(1100, 'Cash', -1),
(1110, 'Checking Account', -1),
(1120, 'Savings Account', -1),
(1200, 'Accounts Receivable', -1),
(1300, 'Inventory', -1),

-- Liability Accounts (positive balances for increase with credits)
(2000, 'Liabilities', 1),
(2100, 'Accounts Payable', 1),
(2200, 'Loans Payable', 1),
(2300, 'Credit Cards Payable', 1),

-- Equity Accounts (positive balances for increase with credits)
(3000, 'Equity', 1),
(3100, 'Owner Equity', 1),
(3200, 'Retained Earnings', 1),

-- Revenue Accounts (positive balances for increase with credits)
(4000, 'Revenue', 1),
(4100, 'Service Revenue', 1),
(4200, 'Product Sales', 1),

-- Expense Accounts (negative balances for increase with debits)
(5000, 'Expenses', -1),
(5100, 'Cost of Goods Sold', -1),
(5200, 'Salaries Expense', -1),
(5300, 'Rent Expense', -1),
(5400, 'Utilities Expense', -1);


-- +goose Down

drop materialized view if exists transactions_by_credit_account;
drop materialized view if exists transactions_by_debit_account;

drop table transactions;
drop table accounts;