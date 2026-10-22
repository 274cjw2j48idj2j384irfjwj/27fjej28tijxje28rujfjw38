-- SPECTER web platform schema. Plain SQL, applied in file order by scripts/migrate.ts (each file once, in a transaction).

create table users (
  id            uuid primary key default gen_random_uuid(),
  discord_id    text not null unique,
  username      text not null,
  global_name   text,
  avatar        text,
  is_admin      boolean not null default false,
  suspended     boolean not null default false,          -- whole platform ban
  verified_creator boolean not null default false,
  created_at    timestamptz not null default now(),
  last_login_at timestamptz not null default now()
);

create table sessions (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references users(id) on delete cascade,
  token_hash  text not null unique,
  created_at  timestamptz not null default now(),
  expires_at  timestamptz not null,
  user_agent  text
);
create index sessions_user_idx on sessions(user_id);

-- Products: names and ids come from the site config, the editable content lives here.
create table products (
  id              text primary key,                       -- 'gamesense' | 'primordial'
  features        jsonb not null default '[]'::jsonb,     -- [{category, title, text}]
  install_guide   text not null default '',
  compat_notes    text not null default '',
  latest_version  text not null default '',
  min_format      int  not null default 1,                -- config format versions the Lua can import
  max_format      int  not null default 1,
  updated_at      timestamptz not null default now()
);

create table releases (
  id           uuid primary key default gen_random_uuid(),
  product_id   text not null references products(id),
  version      text not null,
  title        text not null,
  notes        jsonb not null default '[]'::jsonb,        -- [text]
  released_at  timestamptz not null default now(),
  is_demo      boolean not null default false
);
create index releases_product_idx on releases(product_id, released_at desc);

create table blobs (
  id            uuid primary key default gen_random_uuid(),
  content_type  text not null,
  bytes         bytea not null,
  created_at    timestamptz not null default now()
);

create table product_media (
  id          uuid primary key default gen_random_uuid(),
  product_id  text not null references products(id),
  kind        text not null check (kind in ('screenshot','video')),
  category    text not null check (category in ('menu','visuals','configuration')),
  url         text,                                       -- https url, or null when blob_id is used
  blob_id     uuid references blobs(id) on delete set null,
  caption     text not null default '',
  sort        int not null default 0,
  is_demo     boolean not null default false
);

-- Discord role -> product. Env LUAx_ROLE_IDS is the fallback while a product has no rows here.
create table role_mappings (
  id              uuid primary key default gen_random_uuid(),
  product_id      text not null references products(id),
  discord_role_id text not null,
  label           text not null default '',
  unique (product_id, discord_role_id)
);

-- Time limited (or open ended) access that does not come from a Discord role: admin grants and leaderboard rewards.
create table access_grants (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references users(id) on delete cascade,
  product_id  text not null references products(id),
  source      text not null check (source in ('admin','reward')),
  starts_at   timestamptz not null default now(),
  expires_at  timestamptz,                                -- null = no expiry
  revoked_at  timestamptz,
  note        text not null default '',
  created_by  uuid references users(id),
  created_at  timestamptz not null default now()
);
create index grants_user_idx on access_grants(user_id, product_id);

create table suspensions (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references users(id) on delete cascade,
  product_id  text not null references products(id),
  reason      text not null default '',
  created_by  uuid references users(id),
  created_at  timestamptz not null default now(),
  lifted_at   timestamptz
);
create unique index suspensions_open_idx on suspensions(user_id, product_id) where lifted_at is null;

-- Last answer of the Discord member lookup (kept short, so a Discord outage is visible as an outage).
create table member_cache (
  user_id     uuid primary key references users(id) on delete cascade,
  in_guild    boolean not null,
  roles       text[] not null default '{}',
  fetched_at  timestamptz not null default now()
);

create table configs (
  id                 uuid primary key default gen_random_uuid(),
  slug               text not null unique,                -- short share id
  product_id         text not null references products(id),
  owner_id           uuid not null references users(id) on delete cascade,
  name               text not null,
  description        text not null default '',
  tags               text[] not null default '{}',
  visibility         text not null default 'public' check (visibility in ('public','unlisted','private')),
  is_official        boolean not null default false,
  is_featured        boolean not null default false,
  hidden             boolean not null default false,      -- moderation
  is_demo            boolean not null default false,
  latest_version     int not null default 1,
  likes_count        int not null default 0,
  downloads_count    int not null default 0,
  imports_count      int not null default 0,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);
create index configs_listing_idx on configs(product_id, visibility, hidden, updated_at desc);
create index configs_owner_idx on configs(owner_id);

create table config_versions (
  id             uuid primary key default gen_random_uuid(),
  config_id      uuid not null references configs(id) on delete cascade,
  version        int not null,
  payload        jsonb not null,                          -- {meta:{product,format_version,lua_version}, data}
  payload_bytes  int not null,
  format_version int not null,
  lua_version    text not null,
  changelog      text not null default '',
  created_at     timestamptz not null default now(),
  unique (config_id, version)
);

create table config_images (
  id         uuid primary key default gen_random_uuid(),
  config_id  uuid not null references configs(id) on delete cascade,
  blob_id    uuid not null references blobs(id) on delete cascade,
  sort       int not null default 0
);

create table config_likes (
  user_id    uuid not null references users(id) on delete cascade,
  config_id  uuid not null references configs(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, config_id)
);

create table config_library (
  user_id        uuid not null references users(id) on delete cascade,
  config_id      uuid not null references configs(id) on delete cascade,
  saved_version  int not null,
  saved_at       timestamptz not null default now(),
  primary key (user_id, config_id)
);

-- One counted event per user, config, kind and day: a refresh loop does not move the statistics.
create table config_events (
  id         bigserial primary key,
  config_id  uuid not null references configs(id) on delete cascade,
  user_id    uuid not null references users(id) on delete cascade,
  kind       text not null check (kind in ('download','import_code','client_import')),
  day        date not null default (now() at time zone 'utc')::date,
  unique (config_id, user_id, kind, day)
);

create table config_reports (
  id           uuid primary key default gen_random_uuid(),
  config_id    uuid not null references configs(id) on delete cascade,
  reporter_id  uuid not null references users(id) on delete cascade,
  reason       text not null,
  details      text not null default '',
  status       text not null default 'open' check (status in ('open','resolved','dismissed')),
  created_at   timestamptz not null default now(),
  resolved_by  uuid references users(id),
  resolved_at  timestamptz,
  unique (config_id, reporter_id)
);

-- Lua <-> web link (device code flow).
create table device_codes (
  id                uuid primary key default gen_random_uuid(),
  device_code_hash  text not null unique,
  user_code         text not null unique,
  product_id        text not null references products(id),
  client_name       text not null default '',
  status            text not null default 'pending' check (status in ('pending','approved','denied','consumed')),
  user_id           uuid references users(id) on delete cascade,
  created_at        timestamptz not null default now(),
  expires_at        timestamptz not null,
  last_polled_at    timestamptz
);

create table client_tokens (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references users(id) on delete cascade,
  product_id    text not null references products(id),
  token_hash    text not null unique,
  scopes        text[] not null,
  name          text not null default '',
  created_at    timestamptz not null default now(),
  last_used_at  timestamptz,
  expires_at    timestamptz not null,
  revoked_at    timestamptz
);
create index client_tokens_user_idx on client_tokens(user_id);

-- Leaderboards. 'product' boards collect points of one product, 'overall' adds the product boards of a month together.
create table boards (
  id                 text primary key,
  name               text not null,
  kind               text not null check (kind in ('product','overall')),
  product_id         text references products(id),
  scoring_enabled    boolean not null default false,      -- production point collection stays off until the rules are approved
  rules              jsonb not null default '{"events":{}}'::jsonb, -- {events:{<type>:{points,dailyCap}}}
  rewards_enabled    boolean not null default false,
  reward_product_id  text references products(id),
  reward_days        jsonb not null default '[30,14,7]'::jsonb
);

create table score_events (
  id          bigserial primary key,
  board_id    text not null references boards(id),
  user_id     uuid not null references users(id) on delete cascade,
  period      text not null,                              -- 'YYYY-MM', UTC
  event_type  text not null,
  points      int not null,
  dedupe_key  text not null,
  is_demo     boolean not null default false,
  created_at  timestamptz not null default now(),
  unique (board_id, dedupe_key)
);
create index score_events_board_idx on score_events(board_id, period, user_id);

create table period_closures (
  board_id   text not null references boards(id),
  period     text not null,
  closed_at  timestamptz not null default now(),
  primary key (board_id, period)
);

create table monthly_results (
  id         bigserial primary key,
  board_id   text not null references boards(id),
  period     text not null,
  rank       int not null,
  user_id    uuid not null references users(id) on delete cascade,
  points     int not null,
  is_demo    boolean not null default false,
  unique (board_id, period, rank)
);

create table reward_log (
  id                  bigserial primary key,
  board_id            text not null references boards(id),
  period              text not null,
  rank                int not null,
  user_id             uuid not null references users(id) on delete cascade,
  product_id          text not null references products(id),
  days                int not null,
  grant_id            uuid references access_grants(id),
  previous_expires_at timestamptz,
  new_expires_at      timestamptz,
  note                text not null default '',
  created_at          timestamptz not null default now(),
  unique (board_id, period, rank)                         -- the same result is never rewarded twice
);

create table notifications (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references users(id) on delete cascade,
  kind        text not null,
  title       text not null,
  body        text not null default '',
  link        text,
  read_at     timestamptz,
  created_at  timestamptz not null default now()
);
create index notifications_user_idx on notifications(user_id, created_at desc);

create table audit_log (
  id           bigserial primary key,
  actor_id     uuid references users(id) on delete set null,
  action       text not null,
  target_type  text not null default '',
  target_id    text not null default '',
  meta         jsonb not null default '{}'::jsonb,
  created_at   timestamptz not null default now()
);
create index audit_log_idx on audit_log(created_at desc);

create table rate_limits (
  key           text not null,
  window_start  timestamptz not null,
  count         int not null default 0,
  primary key (key, window_start)
);

insert into products (id) values ('gamesense'), ('primordial');
insert into boards (id, name, kind, product_id) values
  ('gamesense', 'Gamesense', 'product', 'gamesense'),
  ('primordial', 'Primordial', 'product', 'primordial'),
  ('overall', 'Overall', 'overall', null);
