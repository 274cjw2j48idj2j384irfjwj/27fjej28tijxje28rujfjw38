-- Weekly roulette: one row per spin. The prize is rolled on the server; a prize with hours is paid by extending the user's registered key.
create table roulette_spins (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references users(id) on delete cascade,
  prize           text not null check (prize in ('nothing','5h','12h','1d','7d','14d','30d')),
  hours           int  not null default 0 check (hours >= 0),
  lua             text check (lua in ('gamesense','primordial')),
  license_key     text,                                   -- the key the hours go to (never shown whole)
  status          text not null default 'pending' check (status in ('pending','done')),
  new_expires_at  timestamptz,
  created_at      timestamptz not null default now(),
  applied_at      timestamptz
);
create index roulette_spins_user_idx on roulette_spins (user_id, created_at desc);
