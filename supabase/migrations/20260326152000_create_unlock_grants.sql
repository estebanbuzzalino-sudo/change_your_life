create table if not exists public.unlock_grants (
  id text primary key,
  request_id text not null unique,
  installation_id text not null,
  package_name text not null,
  app_name text not null,
  minutes integer not null check (minutes > 0),
  approved_at timestamptz not null default now(),
  unlock_until timestamptz not null,
  created_at timestamptz not null default now()
);

create index if not exists idx_unlock_grants_installation_id
  on public.unlock_grants (installation_id);

create index if not exists idx_unlock_grants_unlock_until
  on public.unlock_grants (unlock_until desc);
