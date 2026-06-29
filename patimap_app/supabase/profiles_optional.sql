-- Profil yönetimi için önerilen profiles şeması.
-- Bu yapı, uygulamadaki hesap bilgileri düzenleme ekranı ile uyumludur.

create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  user_id uuid unique references auth.users (id) on delete cascade,
  first_name text,
  last_name text,
  email text,
  role text,
  updated_at timestamptz default now()
);

alter table public.profiles add column if not exists user_id uuid unique references auth.users (id) on delete cascade;
alter table public.profiles add column if not exists first_name text;
alter table public.profiles add column if not exists last_name text;
alter table public.profiles add column if not exists email text;
alter table public.profiles add column if not exists role text;
alter table public.profiles add column if not exists updated_at timestamptz default now();
alter table public.profiles add column if not exists avatar_url text;

update public.profiles
set user_id = id
where user_id is null;

alter table public.profiles enable row level security;

drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_own"
  on public.profiles for select
  to authenticated
  using (auth.uid() = id or auth.uid() = user_id);

drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own"
  on public.profiles for insert
  to authenticated
  with check (auth.uid() = id or auth.uid() = user_id);

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own"
  on public.profiles for update
  to authenticated
  using (auth.uid() = id or auth.uid() = user_id)
  with check (auth.uid() = id or auth.uid() = user_id);

-- Giriş/kayıt sonrası satır eklemek isterseniz tetikleyici veya uygulama tarafı insert kullanın.
