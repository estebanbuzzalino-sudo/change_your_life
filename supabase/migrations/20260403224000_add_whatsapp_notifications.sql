alter table public.unlock_requests
  add column if not exists friend_whatsapp_e164 text;

alter table public.unlock_requests
  add column if not exists notification_mode text;

update public.unlock_requests
set notification_mode = 'email_only'
where notification_mode is null;

alter table public.unlock_requests
  alter column notification_mode set default 'email_only';

alter table public.unlock_requests
  drop constraint if exists unlock_requests_friend_whatsapp_e164_check;

alter table public.unlock_requests
  add constraint unlock_requests_friend_whatsapp_e164_check
  check (
    friend_whatsapp_e164 is null
    or friend_whatsapp_e164 ~ '^\+[1-9][0-9]{7,14}$'
  );

alter table public.unlock_requests
  drop constraint if exists unlock_requests_notification_mode_check;

alter table public.unlock_requests
  add constraint unlock_requests_notification_mode_check
  check (notification_mode in ('email_only', 'email_and_whatsapp'));

create index if not exists idx_unlock_requests_friend_whatsapp_e164
  on public.unlock_requests(friend_whatsapp_e164)
  where friend_whatsapp_e164 is not null;

create index if not exists idx_unlock_requests_notification_mode
  on public.unlock_requests(notification_mode);

create table if not exists public.unlock_request_notifications (
  id text primary key,
  request_id text not null references public.unlock_requests(id) on delete cascade,
  channel text not null check (channel in ('email', 'whatsapp')),
  provider text not null,
  target text not null,
  status text not null check (status in ('queued', 'sent', 'failed', 'skipped')),
  provider_message_id text,
  provider_status text,
  error_code text,
  error_message text,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_urn_request_id
  on public.unlock_request_notifications(request_id);

create index if not exists idx_urn_channel_status
  on public.unlock_request_notifications(channel, status);

create index if not exists idx_urn_created_at
  on public.unlock_request_notifications(created_at desc);

create or replace function public.set_current_timestamp_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_unlock_request_notifications_updated_at
  on public.unlock_request_notifications;

create trigger trg_unlock_request_notifications_updated_at
before update on public.unlock_request_notifications
for each row
execute function public.set_current_timestamp_updated_at();
