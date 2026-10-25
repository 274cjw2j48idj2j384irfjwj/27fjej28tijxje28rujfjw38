-- Payments: sellable plans (edited by admins), orders (one per checkout) and webhook de-duplication.
create table plans (
  id             uuid primary key default gen_random_uuid(),
  slug           text not null unique check (slug ~ '^[a-z0-9][a-z0-9-]{1,39}$'),
  name           text not null check (length(name) between 1 and 80),
  description    text not null default '',
  license_plan   text not null check (license_plan in ('beta','nightly','specter','debug','pm_dev','pm_nightly','pm_beta')),
  duration       text not null check (duration ~ '^(lifetime|[0-9]+[dwm])$'),
  price_cents    int  not null check (price_cents > 0),
  currency       text not null default 'usd' check (currency ~ '^[a-z]{3}$'),
  active         boolean not null default true,
  sort           int  not null default 0,
  card_enabled   boolean not null default true,
  crypto_enabled boolean not null default true,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

create table orders (
  id              uuid primary key default gen_random_uuid(),  -- the public, unguessable order reference
  plan_id         uuid not null references plans(id) on delete restrict,
  plan_snapshot   jsonb not null,                              -- name, license_plan, duration, price_cents, currency at purchase time
  provider        text not null check (provider in ('stripe','nowpayments','manual')),
  provider_ref    text,                                        -- Stripe session id / NOWPayments invoice id
  provider_payment text,                                       -- Stripe payment_intent id / NOWPayments payment id
  amount_cents    int  not null check (amount_cents > 0),
  currency        text not null check (currency ~ '^[a-z]{3}$'),
  status          text not null default 'pending' check (status in ('pending','paid','issued','expired','failed','review','refunded')),
  license_key     text,
  email           text,
  user_id         uuid references users(id) on delete set null,
  last_error      text,
  admin_note      text,
  issue_attempts  int  not null default 0,
  created_at      timestamptz not null default now(),
  paid_at         timestamptz,
  issued_at       timestamptz,
  revoked_at      timestamptz
);
create unique index orders_provider_ref_uq on orders (provider, provider_ref) where provider_ref is not null;
create index orders_provider_payment_idx on orders (provider_payment);
create index orders_status_idx on orders (status, created_at);
create index orders_user_idx on orders (user_id, created_at desc);

-- A webhook event is recorded after it was processed successfully; a repeated delivery is then ignored.
create table payment_events (
  provider   text not null,
  event_id   text not null,
  created_at timestamptz not null default now(),
  primary key (provider, event_id)
);
