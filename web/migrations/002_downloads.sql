-- Files that only users with access to a product may download (the loader of the Lua), uploaded by an admin.
create table product_downloads (
  id          uuid primary key default gen_random_uuid(),
  product_id  text not null references products(id),
  filename    text not null,
  version     text not null default '',
  note        text not null default '',
  blob_id     uuid not null references blobs(id) on delete cascade,
  bytes       int not null,
  created_at  timestamptz not null default now(),
  created_by  uuid references users(id)
);
create index product_downloads_idx on product_downloads(product_id, created_at desc);
