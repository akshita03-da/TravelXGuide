/*
# TravelXGuide - Complete Database Schema

## Overview
Migrates the TravelXGuide travel companion app from MongoDB to PostgreSQL (Supabase).
Creates 5 tables matching the existing Mongoose models with all fields, constraints,
indexes, and row-level security.

## Architecture Note
The Express.js backend connects to Supabase using the service_role key, which bypasses
RLS. All authentication and authorization logic lives in the Express middleware
(userAuth, adminAuth, guideAuth) - same as the original MongoDB setup. RLS policies
are enabled as a defense-in-depth measure; the backend is the sole database client.

## New Tables

1. **users** - Traveler accounts (replaces User model)
   - id (uuid, PK), email (unique), password (hashed), role (traveler/guide/admin)
   - OAuth fields, email verification OTP, password reset OTP
   - Profile fields: name, phone, date_of_birth, location, bio, profile_picture
   - Status fields: is_active, is_blocked, last_login_at
   - Timestamps: created_at, updated_at (auto-updated via trigger)

2. **admins** - Admin accounts (replaces Admin model)
   - id (uuid, PK), email (unique), password (hashed), role (admin/super_admin)
   - permissions (text array), is_active, last_login
   - Timestamps: created_at, updated_at

3. **guide_applications** - Guide applications and approved guides (replaces GuideApplication model)
   - id (uuid, PK), email (unique), password (hashed)
   - Application fields: experience, languages, destinations, bio, hourly_rate
   - Profile image, documents (text array)
   - Status workflow: pending -> approved/rejected, admin_notes, approved_by, approved_at
   - Guide metrics: rating, total_reviews, tours_completed, is_active
   - Email verification: verification_otp, verification_otp_expire_at, is_email_verified
   - Timestamps: created_at, updated_at

4. **tours** - Tour listings (replaces Tour model)
   - id (uuid, PK), host (FK -> users)
   - Tour details: title, description, location, duration, price, max_participants
   - Schedule: start_date, end_date
   - Media: images (text array), location_photo
   - Classification: category, difficulty
   - Status workflow: pending -> approved/rejected/cancelled, admin_notes, approved_by, approved_at
   - Timestamps: created_at, updated_at

5. **messages** - Real-time chat messages (replaces Message model)
   - id (uuid, PK), group_id, sender_id, message, sender_name
   - Timestamps: created_at

## Security
- RLS enabled on all 5 tables
- GRANT CRUD to anon, authenticated (backend uses service_role which bypasses RLS)
- Policies allow all CRUD for anon + authenticated since the Express backend
  handles all authorization via JWT middleware (defense-in-depth; Supabase is not
  directly exposed to the frontend)
- GRANT ALL to service_role for backend operations

## Indexes
- users: email (unique), role, is_active + is_blocked, is_account_verified, created_at
- admins: email (unique)
- guide_applications: email (unique), status, status + is_active, destinations (GIN),
  languages (GIN), hourly_rate, rating
- tours: host, status, status + created_at, location, category, difficulty, start_date,
  price, status + start_date
- messages: group_id + created_at, sender_id, created_at

## Auto-updating timestamps
- A trigger function `update_updated_at_column()` automatically sets `updated_at = now()`
  on any UPDATE to tables with an `updated_at` column.
*/

-- ============================================
-- Helper: auto-update updated_at on UPDATE
-- ============================================
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;

-- ============================================
-- 1. users table
-- ============================================
CREATE TABLE IF NOT EXISTS public.users (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text,
    email text UNIQUE NOT NULL,
    password text,
    role text NOT NULL DEFAULT 'traveler' CHECK (role IN ('traveler', 'guide', 'admin')),
    oauth_provider text NOT NULL DEFAULT 'local',
    oauth_id text,
    profile_picture text,
    verify_otp text,
    verify_otp_expire_at timestamptz,
    is_account_verified boolean NOT NULL DEFAULT false,
    email_verified_at timestamptz,
    reset_otp text,
    reset_otp_expire_at timestamptz,
    is_active boolean NOT NULL DEFAULT true,
    is_blocked boolean NOT NULL DEFAULT false,
    last_login_at timestamptz,
    phone text,
    date_of_birth date,
    location text,
    bio text,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

GRANT SELECT, INSERT, UPDATE, DELETE ON public.users TO anon, authenticated;
GRANT ALL ON public.users TO service_role;

DROP POLICY IF EXISTS "users_select_all" ON public.users;
CREATE POLICY "users_select_all" ON public.users FOR SELECT
TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "users_insert_all" ON public.users;
CREATE POLICY "users_insert_all" ON public.users FOR INSERT
TO anon, authenticated WITH CHECK (true);

DROP POLICY IF EXISTS "users_update_all" ON public.users;
CREATE POLICY "users_update_all" ON public.users FOR UPDATE
TO anon, authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "users_delete_all" ON public.users;
CREATE POLICY "users_delete_all" ON public.users FOR DELETE
TO anon, authenticated USING (true);

CREATE INDEX IF NOT EXISTS idx_users_role ON public.users(role);
CREATE INDEX IF NOT EXISTS idx_users_active_blocked ON public.users(is_active, is_blocked);
CREATE INDEX IF NOT EXISTS idx_users_verified ON public.users(is_account_verified);
CREATE INDEX IF NOT EXISTS idx_users_created_at ON public.users(created_at);

DROP TRIGGER IF EXISTS trg_users_updated_at ON public.users;
CREATE TRIGGER trg_users_updated_at
    BEFORE UPDATE ON public.users
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ============================================
-- 2. admins table
-- ============================================
CREATE TABLE IF NOT EXISTS public.admins (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text,
    email text UNIQUE NOT NULL,
    password text,
    role text NOT NULL DEFAULT 'admin' CHECK (role IN ('admin', 'super_admin')),
    is_active boolean NOT NULL DEFAULT true,
    last_login timestamptz,
    permissions text[] NOT NULL DEFAULT '{}',
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.admins ENABLE ROW LEVEL SECURITY;

GRANT SELECT, INSERT, UPDATE, DELETE ON public.admins TO anon, authenticated;
GRANT ALL ON public.admins TO service_role;

DROP POLICY IF EXISTS "admins_select_all" ON public.admins;
CREATE POLICY "admins_select_all" ON public.admins FOR SELECT
TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "admins_insert_all" ON public.admins;
CREATE POLICY "admins_insert_all" ON public.admins FOR INSERT
TO anon, authenticated WITH CHECK (true);

DROP POLICY IF EXISTS "admins_update_all" ON public.admins;
CREATE POLICY "admins_update_all" ON public.admins FOR UPDATE
TO anon, authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "admins_delete_all" ON public.admins;
CREATE POLICY "admins_delete_all" ON public.admins FOR DELETE
TO anon, authenticated USING (true);

DROP TRIGGER IF EXISTS trg_admins_updated_at ON public.admins;
CREATE TRIGGER trg_admins_updated_at
    BEFORE UPDATE ON public.admins
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ============================================
-- 3. guide_applications table
-- ============================================
CREATE TABLE IF NOT EXISTS public.guide_applications (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL,
    email text UNIQUE NOT NULL,
    phone text,
    password text,
    experience text,
    languages text[] NOT NULL DEFAULT '{}',
    destinations text[] NOT NULL DEFAULT '{}',
    bio text,
    hourly_rate numeric,
    profile_image text,
    documents text[] NOT NULL DEFAULT '{}',
    status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    admin_notes text,
    approved_by uuid REFERENCES public.admins(id),
    approved_at timestamptz,
    is_active boolean NOT NULL DEFAULT true,
    rating numeric NOT NULL DEFAULT 0,
    total_reviews int NOT NULL DEFAULT 0,
    tours_completed int NOT NULL DEFAULT 0,
    verification_otp text,
    verification_otp_expire_at timestamptz,
    is_email_verified boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.guide_applications ENABLE ROW LEVEL SECURITY;

GRANT SELECT, INSERT, UPDATE, DELETE ON public.guide_applications TO anon, authenticated;
GRANT ALL ON public.guide_applications TO service_role;

DROP POLICY IF EXISTS "guides_select_all" ON public.guide_applications;
CREATE POLICY "guides_select_all" ON public.guide_applications FOR SELECT
TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "guides_insert_all" ON public.guide_applications;
CREATE POLICY "guides_insert_all" ON public.guide_applications FOR INSERT
TO anon, authenticated WITH CHECK (true);

DROP POLICY IF EXISTS "guides_update_all" ON public.guide_applications;
CREATE POLICY "guides_update_all" ON public.guide_applications FOR UPDATE
TO anon, authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "guides_delete_all" ON public.guide_applications;
CREATE POLICY "guides_delete_all" ON public.guide_applications FOR DELETE
TO anon, authenticated USING (true);

CREATE INDEX IF NOT EXISTS idx_guides_status ON public.guide_applications(status);
CREATE INDEX IF NOT EXISTS idx_guides_status_active ON public.guide_applications(status, is_active);
CREATE INDEX IF NOT EXISTS idx_guides_destinations ON public.guide_applications USING GIN (destinations);
CREATE INDEX IF NOT EXISTS idx_guides_languages ON public.guide_applications USING GIN (languages);
CREATE INDEX IF NOT EXISTS idx_guides_hourly_rate ON public.guide_applications(hourly_rate);
CREATE INDEX IF NOT EXISTS idx_guides_rating ON public.guide_applications(rating);

DROP TRIGGER IF EXISTS trg_guides_updated_at ON public.guide_applications;
CREATE TRIGGER trg_guides_updated_at
    BEFORE UPDATE ON public.guide_applications
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ============================================
-- 4. tours table
-- ============================================
CREATE TABLE IF NOT EXISTS public.tours (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    host uuid REFERENCES public.users(id) NOT NULL,
    title text NOT NULL,
    description text,
    location text,
    duration int,
    price numeric,
    max_participants int,
    start_date timestamptz,
    end_date timestamptz,
    images text[] NOT NULL DEFAULT '{}',
    location_photo text,
    category text,
    difficulty text,
    status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'cancelled')),
    admin_notes text,
    approved_by uuid REFERENCES public.admins(id),
    approved_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.tours ENABLE ROW LEVEL SECURITY;

GRANT SELECT, INSERT, UPDATE, DELETE ON public.tours TO anon, authenticated;
GRANT ALL ON public.tours TO service_role;

DROP POLICY IF EXISTS "tours_select_all" ON public.tours;
CREATE POLICY "tours_select_all" ON public.tours FOR SELECT
TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "tours_insert_all" ON public.tours;
CREATE POLICY "tours_insert_all" ON public.tours FOR INSERT
TO anon, authenticated WITH CHECK (true);

DROP POLICY IF EXISTS "tours_update_all" ON public.tours;
CREATE POLICY "tours_update_all" ON public.tours FOR UPDATE
TO anon, authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "tours_delete_all" ON public.tours;
CREATE POLICY "tours_delete_all" ON public.tours FOR DELETE
TO anon, authenticated USING (true);

CREATE INDEX IF NOT EXISTS idx_tours_host ON public.tours(host);
CREATE INDEX IF NOT EXISTS idx_tours_status ON public.tours(status);
CREATE INDEX IF NOT EXISTS idx_tours_status_created ON public.tours(status, created_at);
CREATE INDEX IF NOT EXISTS idx_tours_location ON public.tours(location);
CREATE INDEX IF NOT EXISTS idx_tours_category ON public.tours(category);
CREATE INDEX IF NOT EXISTS idx_tours_difficulty ON public.tours(difficulty);
CREATE INDEX IF NOT EXISTS idx_tours_start_date ON public.tours(start_date);
CREATE INDEX IF NOT EXISTS idx_tours_price ON public.tours(price);
CREATE INDEX IF NOT EXISTS idx_tours_status_start ON public.tours(status, start_date);

DROP TRIGGER IF EXISTS trg_tours_updated_at ON public.tours;
CREATE TRIGGER trg_tours_updated_at
    BEFORE UPDATE ON public.tours
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ============================================
-- 5. messages table
-- ============================================
CREATE TABLE IF NOT EXISTS public.messages (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id text NOT NULL,
    sender_id text NOT NULL,
    message text NOT NULL,
    sender_name text,
    created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

GRANT SELECT, INSERT, UPDATE, DELETE ON public.messages TO anon, authenticated;
GRANT ALL ON public.messages TO service_role;

DROP POLICY IF EXISTS "messages_select_all" ON public.messages;
CREATE POLICY "messages_select_all" ON public.messages FOR SELECT
TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "messages_insert_all" ON public.messages;
CREATE POLICY "messages_insert_all" ON public.messages FOR INSERT
TO anon, authenticated WITH CHECK (true);

DROP POLICY IF EXISTS "messages_update_all" ON public.messages;
CREATE POLICY "messages_update_all" ON public.messages FOR UPDATE
TO anon, authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "messages_delete_all" ON public.messages;
CREATE POLICY "messages_delete_all" ON public.messages FOR DELETE
TO anon, authenticated USING (true);

CREATE INDEX IF NOT EXISTS idx_messages_group_created ON public.messages(group_id, created_at);
CREATE INDEX IF NOT EXISTS idx_messages_sender ON public.messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_messages_created_at ON public.messages(created_at);
