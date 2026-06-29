-- Bu dosya tarihsel; tüm gerekli kolonlar için bkz. ../reports_app_columns.sql
alter table public.reports
  add column if not exists assigned_at timestamptz;

comment on column public.reports.assigned_at is
  'Gönüllü üstlendiği an (UTC). ASSIGNED kayıtlarda harita görünürlüğü 24 saat ile sınırlanır.';
