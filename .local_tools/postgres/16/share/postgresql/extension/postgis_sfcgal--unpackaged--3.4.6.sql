-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
--
-- PostGIS - Spatial Types for PostgreSQL
-- http://postgis.net
--
-- This is free software; you can redistribute and/or modify it under
-- the terms of the GNU General Public Licence. See the COPYING file.
--
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
--
-- Generated on: 2026-05-13 23:39:27
--           by: ../../utils/create_unpackaged.pl
--          for: postgis_sfcgal
--         from: -
--
-- Do not edit manually, your changes will be lost.
--
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --


-- complain if script is sourced in psql
\echo Use "CREATE EXTENSION postgis_sfcgal to load this file. \quit

CREATE FUNCTION _postgis_package_object(type text, sig text)
RETURNS VOID
AS $$
DECLARE
	sql text;
	proc regproc;
	obj text := pg_catalog.format('%s %s', type, sig);
BEGIN

	sql := pg_catalog.format('ALTER EXTENSION postgis_sfcgal ADD %s', obj);
	EXECUTE sql;
	RAISE NOTICE 'newly registered %', obj;

EXCEPTION
WHEN object_not_in_prerequisite_state THEN
  IF SQLERRM ~ '\mpostgis_sfcgal\M'
  THEN
    RAISE NOTICE '% already registered', obj;
  ELSE
    RAISE EXCEPTION '%', SQLERRM;
  END IF;
WHEN
	undefined_function OR
	undefined_table OR
	undefined_object
	-- TODO: handle more exceptions ?
THEN
	RAISE NOTICE '% % does not exist yet', type, sig;
WHEN OTHERS THEN
	RAISE EXCEPTION 'Trying to add % to postgis_sfcgal, got % (%)', obj, SQLERRM, SQLSTATE;
END;
$$ LANGUAGE 'plpgsql';
-- Register all views.
-- Register all tables.
-- Register all sequences.
-- Register all aggregates.
SELECT _postgis_package_object('AGGREGATE', 'ST_3DUnion (geometry)');
-- Register all operators classes and families.
-- Register all operators.
-- Register all casts.
-- Register all functions.
SELECT _postgis_package_object('FUNCTION', 'postgis_sfcgal_scripts_installed ()');
SELECT _postgis_package_object('FUNCTION', 'postgis_sfcgal_version ()');
SELECT _postgis_package_object('FUNCTION', 'postgis_sfcgal_full_version ()');
SELECT _postgis_package_object('FUNCTION', 'postgis_sfcgal_noop (geometry)');
SELECT _postgis_package_object('FUNCTION', 'ST_3DIntersection (geom1 geometry, geom2 geometry)');
SELECT _postgis_package_object('FUNCTION', 'ST_3DDifference (geom1 geometry, geom2 geometry)');
SELECT _postgis_package_object('FUNCTION', 'ST_3DUnion (geom1 geometry, geom2 geometry)');
SELECT _postgis_package_object('FUNCTION', 'ST_Tesselate (geometry)');
SELECT _postgis_package_object('FUNCTION', 'ST_3DArea (geometry)');
SELECT _postgis_package_object('FUNCTION', 'ST_Extrude (geometry, float8, float8, float8)');
SELECT _postgis_package_object('FUNCTION', 'ST_ForceLHR (geometry)');
SELECT _postgis_package_object('FUNCTION', 'ST_Orientation (geometry)');
SELECT _postgis_package_object('FUNCTION', 'ST_MinkowskiSum (geometry, geometry)');
SELECT _postgis_package_object('FUNCTION', 'ST_StraightSkeleton (geometry)');
SELECT _postgis_package_object('FUNCTION', 'ST_ApproximateMedialAxis (geometry)');
SELECT _postgis_package_object('FUNCTION', 'ST_IsPlanar (geometry)');
SELECT _postgis_package_object('FUNCTION', 'ST_Volume (geometry)');
SELECT _postgis_package_object('FUNCTION', 'ST_MakeSolid (geometry)');
SELECT _postgis_package_object('FUNCTION', 'ST_IsSolid (geometry)');
SELECT _postgis_package_object('FUNCTION', 'ST_ConstrainedDelaunayTriangles (geometry)');
SELECT _postgis_package_object('FUNCTION', 'ST_3DConvexHull (geometry)');
SELECT _postgis_package_object('FUNCTION', 'ST_AlphaShape (g1 geometry, alpha float8 , allow_holes boolean )');
SELECT _postgis_package_object('FUNCTION', 'ST_OptimalAlphaShape (g1 geometry, allow_holes boolean , nb_components int )');
-- Register all types.
DROP FUNCTION _postgis_package_object(text, text);

-- Security checks
DO LANGUAGE 'plpgsql' $BODY$
DECLARE
	rec RECORD;
BEGIN

	-- Check ownership of extension functions
	-- matches ownership of extension itself
	FOR rec IN
		SELECT
			p.oid,
			p.proowner,
			e.extowner
		FROM pg_catalog.pg_depend AS d
			INNER JOIN pg_catalog.pg_extension AS e ON (d.refobjid = e.oid)
			INNER JOIN pg_catalog.pg_proc AS p ON (d.objid = p.oid)
		WHERE d.refclassid = 'pg_catalog.pg_extension'::pg_catalog.regclass
		AND deptype = 'e'
		AND e.extname = 'postgis_sfcgal'
		AND d.classid = 'pg_catalog.pg_proc'::pg_catalog.regclass
		AND p.proowner != e.extowner
	LOOP
		RAISE EXCEPTION 'Function % is owned by % but extension is owned by %',
				rec.oid::regprocedure, rec.proowner::regrole, rec.extowner::regrole;
	END LOOP;

	-- TODO: check ownership of more objects ?

END;
$BODY$;



\echo Use "CREATE EXTENSION postgis_sfcgal" to load this file. \quit
-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
--
----
-- PostGIS - Spatial Types for PostgreSQL
-- http://postgis.net
--
-- Copyright (C) 2011 Regina Obe <lr@pcorp.us>
--
-- This is free software; you can redistribute and/or modify it under
-- the terms of the GNU General Public Licence. See the COPYING file.
--
-- Author: Regina Obe <lr@pcorp.us>
--
-- This is a suite of SQL helper functions for use during a PostGIS extension install/upgrade
-- The functions get uninstalled after the extention install/upgrade process
---------------------------

CREATE FUNCTION postgis_extension_drop_if_exists(param_extension text, param_statement text)
  RETURNS boolean AS
$$
DECLARE
	var_sql_ext text := pg_catalog.format('ALTER EXTENSION %s %s',
		pg_catalog.quote_ident(param_extension),
		pg_catalog.replace(param_statement, 'IF EXISTS', ''));
	var_result boolean := false;
BEGIN
	BEGIN
		EXECUTE var_sql_ext;
		var_result := true;
	EXCEPTION
		WHEN OTHERS THEN
			-- This is to allow ignoring if the object does not exist in extension
			var_result := false;
	END;
	RETURN var_result;
END;
$$
LANGUAGE 'plpgsql' VOLATILE;

CREATE FUNCTION postgis_extension_AddToSearchPath(a_schema_name text)


RETURNS text
AS
$BODY$
DECLARE
	var_result text;
	var_cur_search_path text;
	a_schema_name text := $1;
BEGIN
	WITH settings AS (
		SELECT unnest(setconfig) config
		FROM pg_catalog.pg_db_role_setting
		WHERE setdatabase = (
			SELECT oid
			FROM pg_catalog.pg_database
			WHERE datname = current_database()
		) and setrole = 0
	)
	SELECT regexp_replace(config, '^search_path=', '')
	FROM settings WHERE config like 'search_path=%'
	INTO var_cur_search_path;

	RAISE NOTICE 'cur_search_path from pg_db_role_setting is %', var_cur_search_path;

	-- only run this test if person creating the extension is a super user
	IF var_cur_search_path IS NULL AND (SELECT rolsuper FROM pg_catalog.pg_roles where rolname = CURRENT_USER) THEN
		SELECT setting
		INTO var_cur_search_path
		FROM pg_catalog.pg_file_settings
		WHERE name = 'search_path' AND applied;

		RAISE NOTICE 'cur_search_path from pg_file_settings is %', var_cur_search_path;
	END IF;

	IF var_cur_search_path IS NULL THEN
		SELECT boot_val
		INTO var_cur_search_path
		FROM pg_catalog.pg_settings
		WHERE name = 'search_path';

		RAISE NOTICE 'cur_search_path from pg_settings is %', var_cur_search_path;
	END IF;

	IF var_cur_search_path LIKE '%' || quote_ident(a_schema_name) || '%' THEN
		var_result := a_schema_name || ' already in database search_path';
	ELSE
		var_cur_search_path := var_cur_search_path || ', '
                       || quote_ident(a_schema_name);
		EXECUTE 'ALTER DATABASE ' || quote_ident(current_database())
                             || ' SET search_path = ' || var_cur_search_path;
		var_result := a_schema_name || ' has been added to end of database search_path ';
	END IF;

	EXECUTE 'SET search_path = ' || var_cur_search_path;

  RETURN var_result;
END
$BODY$
-- explicitly move pg_temp after pg_catalog in search path
SET search_path = pg_catalog, pg_temp
LANGUAGE 'plpgsql' VOLATILE STRICT
;




-- PostGIS - Spatial Types for PostgreSQL
-- http://postgis.net
--
-- Copyright (C) 2020 Regina Obe <lr@pcorp.us>
-- This is free software; you can redistribute and/or modify it under
-- the terms of the GNU General Public Licence. See the COPYING file.
--
--
-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
-- These are functions that need to be dropped beforehand
-- where the argument names may have changed  --
-- so have to be dropped before upgrade can happen --
-- argument names changed --


--
-- UPGRADE SCRIPT TO PostGIS 3.4.6
--

LOAD '$libdir/postgis_sfcgal-3';

DO $$
DECLARE
    old_scripts text;
    new_scripts text;
    old_ver_int int[];
    new_ver_int int[];
    old_maj text;
    new_maj text;
    postgis_upgrade_info RECORD;
    postgis_upgrade_info_func_code TEXT;
BEGIN

    old_scripts := postgis_sfcgal_scripts_installed();
    new_scripts := '3.4.6';

    BEGIN
        new_ver_int := pg_catalog.string_to_array(
            pg_catalog.regexp_replace(
                new_scripts,
                E'[^\\d.].*',
                ''
            ),
            '.'
        )::int[];
    EXCEPTION WHEN OTHERS THEN
        RAISE EXCEPTION 'Cannot parse new version % into integers', new_scripts;
    END;

    BEGIN
        old_ver_int := pg_catalog.string_to_array(
            pg_catalog.regexp_replace(
                old_scripts,
                E'[^\\d.].*',
                ''
            ),
            '.'
        )::int[];
    EXCEPTION WHEN OTHERS THEN
        RAISE EXCEPTION 'Cannot parse old version % into integers', old_scripts;
    END;

    -- Guard against downgrade
    IF new_ver_int < old_ver_int
    THEN
        RAISE EXCEPTION 'Downgrade of postgis_sfcgal from version % to version % is forbidden', old_scripts, new_scripts;
    END IF;


    -- Check for hard-upgrade being required
    SELECT into old_maj pg_catalog.substring(old_scripts, 1, 1);
    SELECT into new_maj pg_catalog.substring(new_scripts, 1, 1);

    -- 2.x to 3.x was upgrade-compatible, see
    -- https://trac.osgeo.org/postgis/ticket/4170#comment:1
    IF new_maj = '3' AND old_maj = '2' THEN
        old_maj = '3'; -- let's pretend old major = new major
    END IF;

    IF old_maj != new_maj THEN
        RAISE EXCEPTION 'Upgrade of postgis_sfcgal from version % to version % requires a dump/reload. See PostGIS manual for instructions', old_scripts, new_scripts;
    END IF;

    WITH versions AS (
      SELECT '3.4.6'::text as upgraded,
      postgis_sfcgal_scripts_installed() as installed
    ) SELECT
      upgraded as scripts_upgraded,
      installed as scripts_installed,
      pg_catalog.substring(upgraded, '([0-9]+)\.')::int * 100 +
      pg_catalog.substring(upgraded, '[0-9]+\.([0-9]+)(\.|$)')::int
        as version_to_num,
      pg_catalog.substring(installed, '([0-9]+)\.')::int * 100 +
      pg_catalog.substring(installed, '[0-9]+\.([0-9]+)(\.|$)')::int
        as version_from_num,
      installed ~ 'dev|alpha|beta'
        as version_from_isdev
      FROM versions INTO postgis_upgrade_info
    ;

    postgis_upgrade_info_func_code := pg_catalog.format($func_code$
        CREATE FUNCTION _postgis_upgrade_info(OUT scripts_upgraded TEXT,
                                              OUT scripts_installed TEXT,
                                              OUT version_to_num INT,
                                              OUT version_from_num INT,
                                              OUT version_from_isdev BOOLEAN)
        AS
        $postgis_upgrade_info$
        BEGIN
            scripts_upgraded := %L :: TEXT;
            scripts_installed := %L :: TEXT;
            version_to_num := %L :: INT;
            version_from_num := %L :: INT;
            version_from_isdev := %L :: BOOLEAN;
            RETURN;
        END
        $postgis_upgrade_info$ LANGUAGE 'plpgsql' IMMUTABLE;
        $func_code$,
        postgis_upgrade_info.scripts_upgraded,
        postgis_upgrade_info.scripts_installed,
        postgis_upgrade_info.version_to_num,
        postgis_upgrade_info.version_from_num,
        postgis_upgrade_info.version_from_isdev);
    RAISE DEBUG 'Creating function %', postgis_upgrade_info_func_code;
    EXECUTE postgis_upgrade_info_func_code;
END
$$
LANGUAGE 'plpgsql';

CREATE OR REPLACE FUNCTION postgis_sfcgal_scripts_installed() RETURNS text
	AS $$ SELECT trim('3.4.6'::text || $rev$ 82fd454 $rev$) AS version $$
	LANGUAGE 'sql' IMMUTABLE;
CREATE OR REPLACE FUNCTION postgis_sfcgal_version() RETURNS text
        AS '$libdir/postgis_sfcgal-3'
        LANGUAGE 'c' IMMUTABLE;
CREATE OR REPLACE FUNCTION postgis_sfcgal_full_version() RETURNS text
        AS '$libdir/postgis_sfcgal-3'
        LANGUAGE 'c' IMMUTABLE;
CREATE OR REPLACE FUNCTION postgis_sfcgal_noop(geometry)
        RETURNS geometry
        AS '$libdir/postgis_sfcgal-3', 'postgis_sfcgal_noop'
        LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
        COST 1;
CREATE OR REPLACE FUNCTION ST_3DIntersection(geom1 geometry, geom2 geometry)
       RETURNS geometry
       AS '$libdir/postgis_sfcgal-3','sfcgal_intersection3D'
       LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
       COST 100;
CREATE OR REPLACE FUNCTION ST_3DDifference(geom1 geometry, geom2 geometry)
       RETURNS geometry
       AS '$libdir/postgis_sfcgal-3','sfcgal_difference3D'
       LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
       COST 100;
CREATE OR REPLACE FUNCTION ST_3DUnion(geom1 geometry, geom2 geometry)
       RETURNS geometry
       AS '$libdir/postgis_sfcgal-3','sfcgal_union3D'
       LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
       COST 100;
-- Aggregate ST_3DUnion(geometry) -- LastUpdated: 303
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF pg_catalog.current_setting('server_version_num')::integer >= 120000
  THEN
    EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE OR REPLACE AGGREGATE ST_3DUnion(geometry) (
       sfunc = ST_3DUnion,
       stype = geometry,
       parallel = safe
);
 $postgis_proc_upgrade_parsed_def$;
  ELSIF 303 > version_from_num OR (
      303 = version_from_num AND version_from_isdev
    ) FROM _postgis_upgrade_info()
  THEN
    EXECUTE 'DROP AGGREGATE IF EXISTS ST_3DUnion(geometry)';
    EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE AGGREGATE ST_3DUnion(geometry) (
       sfunc = ST_3DUnion,
       stype = geometry,
       parallel = safe
);
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
CREATE OR REPLACE FUNCTION ST_Tesselate(geometry)
       RETURNS geometry
       AS '$libdir/postgis_sfcgal-3','sfcgal_tesselate'
       LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
       COST 100;
CREATE OR REPLACE FUNCTION ST_3DArea(geometry)
       RETURNS FLOAT8
       AS '$libdir/postgis_sfcgal-3','sfcgal_area3D'
       LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
       COST 100;
CREATE OR REPLACE FUNCTION ST_Extrude(geometry, float8, float8, float8)
       RETURNS geometry
       AS '$libdir/postgis_sfcgal-3','sfcgal_extrude'
       LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
       COST 100;
CREATE OR REPLACE FUNCTION ST_ForceLHR(geometry)
       RETURNS geometry
       AS '$libdir/postgis_sfcgal-3','sfcgal_force_lhr'
       LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
       COST 100;
CREATE OR REPLACE FUNCTION ST_Orientation(geometry)
       RETURNS INT4
       AS '$libdir/postgis_sfcgal-3','sfcgal_orientation'
       LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
       COST 100;
CREATE OR REPLACE FUNCTION ST_MinkowskiSum(geometry, geometry)
       RETURNS geometry
       AS '$libdir/postgis_sfcgal-3','sfcgal_minkowski_sum'
       LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
       COST 100;
CREATE OR REPLACE FUNCTION ST_StraightSkeleton(geometry)
       RETURNS geometry
       AS '$libdir/postgis_sfcgal-3','sfcgal_straight_skeleton'
       LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
       COST 100;
CREATE OR REPLACE FUNCTION ST_ApproximateMedialAxis(geometry)
       RETURNS geometry
       AS '$libdir/postgis_sfcgal-3','sfcgal_approximate_medial_axis'
       LANGUAGE 'c'
       IMMUTABLE STRICT PARALLEL SAFE
       COST 100;
CREATE OR REPLACE FUNCTION ST_IsPlanar(geometry)
       RETURNS boolean
       AS '$libdir/postgis_sfcgal-3','sfcgal_is_planar'
       LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
       COST 100;
CREATE OR REPLACE FUNCTION ST_Volume(geometry)
       RETURNS FLOAT8
       AS '$libdir/postgis_sfcgal-3','sfcgal_volume'
       LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
       COST 100;
CREATE OR REPLACE FUNCTION ST_MakeSolid(geometry)
       RETURNS geometry
       AS '$libdir/postgis_sfcgal-3','sfcgal_make_solid'
       LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
       COST 100;
CREATE OR REPLACE FUNCTION ST_IsSolid(geometry)
       RETURNS boolean
       AS '$libdir/postgis_sfcgal-3','sfcgal_is_solid'
       LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
       COST 100;
CREATE OR REPLACE FUNCTION ST_ConstrainedDelaunayTriangles(geometry)
       RETURNS geometry
       AS '$libdir/postgis_sfcgal-3', 'ST_ConstrainedDelaunayTriangles'
       LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
       COST 100;
CREATE OR REPLACE FUNCTION ST_3DConvexHull(geometry)
       RETURNS geometry
       AS '$libdir/postgis_sfcgal-3', 'sfcgal_convexhull3D'
       LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
       COST 100;
CREATE OR REPLACE FUNCTION ST_AlphaShape(g1 geometry, alpha float8 DEFAULT 1.0, allow_holes boolean DEFAULT false)
       RETURNS geometry
       AS '$libdir/postgis_sfcgal-3', 'sfcgal_alphashape'
       LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
       COST 100;
CREATE OR REPLACE FUNCTION ST_OptimalAlphaShape(g1 geometry, allow_holes boolean DEFAULT false, nb_components int DEFAULT 1)
       RETURNS geometry
       AS '$libdir/postgis_sfcgal-3', 'sfcgal_optimalalphashape'
       LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
       COST 100;
DROP FUNCTION _postgis_upgrade_info();
-- PostGIS - Spatial Types for PostgreSQL
-- http://postgis.net
--
-- Copyright (C) 2020 Regina Obe <lr@pcorp.us>
-- This is free software; you can redistribute and/or modify it under
-- the terms of the GNU General Public Licence. See the COPYING file.
--
--
-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
-- These are reserved for functions that are changed to use default args
-- This is installed after the new functions are installed
-- We don't have any of these yet for sfcgal
-- The reason we put these after install is
-- you can't drop a function that is used by sql functions
-- without forcing a drop on those as well which may cause issues with user functions.
-- This allows us to CREATE OR REPLACE those in general sfcgal.sql.in
-- without dropping them.




COMMENT ON FUNCTION postgis_sfcgal_version() IS 'Returns the version of SFCGAL in use';
			
COMMENT ON FUNCTION postgis_sfcgal_full_version() IS 'Returns the full version of SFCGAL in use including CGAL and Boost versions';
			
COMMENT ON FUNCTION ST_3DArea(geometry) IS 'args: geom1 - Computes area of 3D surface geometries. Will return 0 for solids.';
			
COMMENT ON FUNCTION ST_3DConvexHull(geometry) IS 'args: geom1 - Computes the 3D convex hull of a geometry.';
			
COMMENT ON FUNCTION ST_3DIntersection(geometry, geometry) IS 'args: geom1, geom2 - Perform 3D intersection';
			
COMMENT ON FUNCTION ST_3DDifference(geometry, geometry) IS 'args: geom1, geom2 - Perform 3D difference';
			
COMMENT ON FUNCTION ST_3DUnion(geometry, geometry) IS 'args: geom1, geom2 - Perform 3D union.';
			
COMMENT ON AGGREGATE ST_3DUnion(geometry) IS 'args: g1field - Perform 3D union.';
			
COMMENT ON FUNCTION ST_AlphaShape(geometry, float , boolean ) IS 'args: geom, alpha, allow_holes = false - Computes an Alpha-shape enclosing a geometry';
			
COMMENT ON FUNCTION ST_ApproximateMedialAxis(geometry) IS 'args: geom - Compute the approximate medial axis of an areal geometry.';
			
COMMENT ON FUNCTION ST_ConstrainedDelaunayTriangles(geometry ) IS 'args: g1 - Return a constrained Delaunay triangulation around the given input geometry.';
			
COMMENT ON FUNCTION ST_Extrude(geometry, float, float, float) IS 'args: geom, x, y, z - Extrude a surface to a related volume';
			
COMMENT ON FUNCTION ST_ForceLHR(geometry) IS 'args: geom - Force LHR orientation';
			
COMMENT ON FUNCTION ST_IsPlanar(geometry) IS 'args: geom - Check if a surface is or not planar';
			
COMMENT ON FUNCTION ST_IsSolid(geometry) IS 'args: geom1 - Test if the geometry is a solid. No validity check is performed.';
			
COMMENT ON FUNCTION ST_MakeSolid(geometry) IS 'args: geom1 - Cast the geometry into a solid. No check is performed. To obtain a valid solid, the input geometry must be a closed Polyhedral Surface or a closed TIN.';
			
COMMENT ON FUNCTION ST_MinkowskiSum(geometry, geometry) IS 'args: geom1, geom2 - Performs Minkowski sum';
			
COMMENT ON FUNCTION ST_OptimalAlphaShape(geometry, boolean , integer ) IS 'args: geom, allow_holes = false, nb_components = 1 - Computes an Alpha-shape enclosing a geometry using an "optimal" alpha value.';
			
COMMENT ON FUNCTION ST_Orientation(geometry) IS 'args: geom - Determine surface orientation';
			
COMMENT ON FUNCTION ST_StraightSkeleton(geometry) IS 'args: geom - Compute a straight skeleton from a geometry';
			
COMMENT ON FUNCTION ST_Tesselate(geometry) IS 'args: geom - Perform surface Tesselation of a polygon or polyhedralsurface and returns as a TIN or collection of TINS';
			
COMMENT ON FUNCTION ST_Volume(geometry) IS 'args: geom1 - Computes the volume of a 3D solid. If applied to surface (even closed) geometries will return 0.';
			-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
--
----
-- PostGIS - Spatial Types for PostgreSQL
-- http://postgis.net
--
-- Copyright (C) 2011 Regina Obe <lr@pcorp.us>
--
-- This is free software; you can redistribute and/or modify it under
-- the terms of the GNU General Public Licence. See the COPYING file.
--
-- Author: Regina Obe <lr@pcorp.us>
--
-- This drops extension helper functions
-- and should be called at the end of the extension upgrade file
DROP FUNCTION IF EXISTS postgis_extension_drop_if_exists(text, text);
DROP FUNCTION IF EXISTS postgis_extension_AddToSearchPath(varchar);
DROP FUNCTION IF EXISTS postgis_extension_AddToSearchPath(text);
