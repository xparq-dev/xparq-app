-- Align radar age-gating with the Flutter AgeGroup enum.
--
-- Flutter sends AgeGroup.name, which is currently:
--   cadet    - restricted mode
--   explorer - 18+ full access
--
-- Older SQL/function drafts used "adult" for the adult branch. Keep accepting
-- that legacy value, but treat "explorer" as the canonical adult value.

UPDATE public.profiles
SET age_group = 'explorer'
WHERE age_group = 'adult';

CREATE OR REPLACE FUNCTION public.query_nearby_users(
  p_lat double precision,
  p_lng double precision,
  p_radius_km double precision,
  p_caller_age_group text
)
RETURNS TABLE(
  id uuid,
  xparq_name text,
  bio text,
  photo_url text,
  cover_photo_url text,
  birth_date_encrypted text,
  age_group text,
  blue_orbit boolean,
  is_adult_verified boolean,
  nsfw_opt_in boolean,
  constellations text[],
  is_online boolean,
  ghost_mode boolean,
  account_status text,
  deletion_requested_at timestamp with time zone,
  created_at timestamp with time zone,
  last_location geography,
  location_lat double precision,
  location_lng double precision,
  location_updated_at timestamp with time zone,
  total_pulse_count integer,
  nsfw_pulse_count integer,
  distance_meters double precision
)
LANGUAGE plpgsql
SET search_path = public
AS $function$
DECLARE
  v_point geography;
  v_caller_age_group text := lower(coalesce(p_caller_age_group, 'cadet'));
  v_caller_can_view_sensitive boolean;
BEGIN
  v_point := ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography;
  v_caller_can_view_sensitive := v_caller_age_group IN ('explorer', 'adult');

  RETURN QUERY
  SELECT
    nearby.id,
    nearby.xparq_name,
    nearby.bio,
    nearby.photo_url,
    nearby.cover_photo_url,
    nearby.birth_date_encrypted,
    nearby.age_group,
    nearby.blue_orbit,
    nearby.is_adult_verified,
    nearby.nsfw_opt_in,
    nearby.constellations,
    nearby.is_online,
    nearby.ghost_mode,
    nearby.account_status,
    nearby.deletion_requested_at,
    nearby.created_at,
    nearby.last_location,
    nearby.location_lat,
    nearby.location_lng,
    nearby.location_updated_at,
    nearby.total_pulse_count,
    nearby.nsfw_pulse_count,
    nearby.distance_meters
  FROM (
    SELECT
      p.id,
      p.xparq_name,
      p.bio,
      p.photo_url,
      p.cover_photo_url,
      p.birth_date_encrypted,
      p.age_group,
      p.blue_orbit,
      p.is_adult_verified,
      p.nsfw_opt_in,
      p.constellations,
      p.is_online,
      p.ghost_mode,
      p.account_status,
      p.deletion_requested_at,
      p.created_at,
      p.last_location,
      p.location_lat,
      p.location_lng,
      p.location_updated_at,
      p.total_pulse_count,
      p.nsfw_pulse_count,
      ST_Distance(
        ST_SetSRID(ST_MakePoint(p.location_lng, p.location_lat), 4326)::geography,
        v_point
      )::double precision AS distance_meters
    FROM public.profiles p
    WHERE
      p.is_online = TRUE
      AND p.ghost_mode = FALSE
      AND p.location_lat IS NOT NULL
      AND p.location_lng IS NOT NULL
      AND ST_DWithin(
        ST_SetSRID(ST_MakePoint(p.location_lng, p.location_lat), 4326)::geography,
        v_point,
        p_radius_km * 1000
      )
      AND (
        v_caller_can_view_sensitive
        OR (
          COALESCE(p.nsfw_opt_in, FALSE) = FALSE
          AND COALESCE(p.nsfw_pulse_count, 0)
            <= COALESCE(p.total_pulse_count, 0) * 0.7
        )
      )
  ) AS nearby
  ORDER BY nearby.distance_meters ASC;
END;
$function$;

NOTIFY pgrst, 'reload schema';
