-- PatiMap — uygulamanın harita/detay sorgusunda kullandığı TÜM kolonlar.
-- "Sunucuda eksik kolon olabilir (animal_type, report_status vb.)" hatası alıyorsanız
-- bu dosyayı Supabase Dashboard → SQL Editor’da tek seferde çalıştırın.
--
-- Not: Tablonuz zaten varsa yalnızca eksik kolonlar eklenir (IF NOT EXISTS).

alter table public.reports add column if not exists assigned_volunteer_id uuid references auth.users (id);
alter table public.reports add column if not exists assigned_at timestamptz;
alter table public.reports add column if not exists animal_type text;
alter table public.reports add column if not exists custom_animal_type text;
alter table public.reports add column if not exists report_status text;
alter table public.reports add column if not exists custom_report_status text;

-- Aşağıdakiler çok eski şemada yoksa diye (çoğu projede zaten vardır):
alter table public.reports add column if not exists location_note text;
alter table public.reports add column if not exists photo_url text;
alter table public.reports add column if not exists latitude double precision;
alter table public.reports add column if not exists longitude double precision;

comment on column public.reports.assigned_at is
  'Gönüllü üstlendiği an (UTC). Haritada ASSIGNED görünürlüğü 24 saat.';
