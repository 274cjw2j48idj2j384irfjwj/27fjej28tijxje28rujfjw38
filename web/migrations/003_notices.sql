-- Which releases already produced notifications, and which expiring grants were already warned about.
create table release_notices (
  release_id uuid primary key references releases(id) on delete cascade,
  sent_at    timestamptz not null default now(),
  recipients int not null default 0
);

create table expiry_notices (
  grant_id   uuid primary key references access_grants(id) on delete cascade,
  sent_at    timestamptz not null default now()
);
