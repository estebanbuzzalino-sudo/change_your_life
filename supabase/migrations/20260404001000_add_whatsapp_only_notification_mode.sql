alter table public.unlock_requests
  drop constraint if exists unlock_requests_notification_mode_check;

alter table public.unlock_requests
  add constraint unlock_requests_notification_mode_check
  check (notification_mode in ('email_only', 'whatsapp_only', 'email_and_whatsapp'));
