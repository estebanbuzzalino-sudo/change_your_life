create table if not exists public.unlock_requests (
  id text primary key,
  installation_id text not null,
  package_name text not null,
  app_name text not null,
  requester_name text not null,
  friend_name text not null,
  friend_email text,
  minutes integer not null check (minutes > 0),
  status text not null default 'pending_approval'
    check (status in ('pending_approval', 'approved', 'expired')),
  requested_at timestamptz not null default now(),
  token_hash text not null unique,
  token_expires_at timestamptz not null,
  token_used_at timestamptz
);

create index if not exists idx_unlock_requests_installation_id
  on public.unlock_requests (installation_id);

create index if not exists idx_unlock_requests_token_hash
  on public.unlock_requests (token_hash);

create index if not exists idx_unlock_requests_status
  on public.unlock_requests (status);
