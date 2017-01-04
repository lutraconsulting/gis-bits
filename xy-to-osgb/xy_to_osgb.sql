/*
-*- coding: utf-8 -*-

xy_to_osgb - A library of functions for converting eastings and 
northings to OS Grid References
Copyright (C) 2014 Peter Wells for Lutra Consulting

peter dot wells at lutraconsulting dot co dot uk
Lutra Consulting
23 Chestnut Close
Burgess Hill
West Sussex
RH15 8HN

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
*/


CREATE OR REPLACE FUNCTION xy_to_osgb(easting double precision, northing double precision, prec integer DEFAULT 1000)
	RETURNS text AS
$BODY$
DECLARE
	_easting integer;
	_northing integer;
	major_letters character(1)[][];
	minor_letters character(1)[][];
	supported_precisions integer[];
	x_idx integer;
	y_idx integer;
	major_letter character(1);
	macro_easting integer;
	macro_northing integer;
	micro_easting integer;
	micro_northing integer;
	macro_x_idx integer;
	macro_y_idx integer;
	minor_letter character(1);
	ref_x integer;
	ref_y integer;
	format_string text;
	grid_ref text;
	
BEGIN
	-- init letters
	major_letters := ARRAY[	['S', 'N', 'H'],
							['T', 'O', NULL]];
	
	minor_letters := ARRAY[	['V', 'Q', 'L', 'F', 'A'],
							['W', 'R', 'M', 'G', 'B'],
							['X', 'S', 'N', 'H', 'C'],
							['Y', 'T', 'O', 'J', 'D'],
							['Z', 'U', 'P', 'K', 'E']];

	-- init supported_precisions
	supported_precisions := ARRAY[1000, 100, 10, 1];
	
	-- round inputs to the nearest metre
	_easting := round(easting);
	_northing := round(northing);
	
	IF NOT prec = ANY(supported_precisions) THEN
		RAISE EXCEPTION 'Precision of % is not supported.', prec;
	END IF;
	
	-- Determine first letter
	
	x_idx := _easting / 500000;
	y_idx := _northing / 500000;
	major_letter := major_letters[x_idx+1][y_idx+1];
	
	-- Determine 'index' of 100km square within the larger 500km tile
	
	macro_easting := _easting % 500000;
	macro_northing := _northing % 500000;
	macro_x_idx := macro_easting / 100000;
	macro_y_idx := macro_northing / 100000;
	minor_letter := minor_letters[macro_x_idx+1][macro_y_idx+1];
	
	-- determine the internal coordinate withing the 100km tile
	micro_easting := macro_easting % 100000;
	micro_northing := macro_northing % 100000;
	
	-- determine how to report the numeric part
	ref_x := micro_easting / prec;
	ref_y := micro_northing / prec;
	
	format_string := '09';
	IF prec = 100 THEN
		format_string := '099';
	ELSIF prec = 10 THEN
		format_string := '0999';
	ELSIF prec = 1 THEN
		format_string := '09999';
	END IF;
	
	grid_ref := major_letter || minor_letter;
	grid_ref := grid_ref || to_char(ref_x,  format_string);
	grid_ref := grid_ref || to_char(ref_y,  format_string);
	
	RETURN grid_ref;

END;
$BODY$
LANGUAGE 'plpgsql' VOLATILE
COST 100;






/*	Unit tests
	SELECT 
	xy_to_osgb(432574, 332567) = 'SK 32 32' AND 
	xy_to_osgb(236336, 682945) = 'NS 36 82' AND 
	xy_to_osgb(392876, 494743) = 'SD 92 94' AND 
	xy_to_osgb(472945, 103830) = 'SU 72 03' AND 
	
	xy_to_osgb(432574, 332567, 100) = 'SK 325 325' AND 
	xy_to_osgb(236336, 682945, 100) = 'NS 363 829' AND 
	xy_to_osgb(392876, 494743, 100) = 'SD 928 947' AND 
	xy_to_osgb(472945, 103830, 100) = 'SU 729 038' AND 
	
	xy_to_osgb(432574, 332567, 10) = 'SK 3257 3256' AND 
	xy_to_osgb(236336, 682945, 10) = 'NS 3633 8294' AND 
	xy_to_osgb(392876, 494743, 10) = 'SD 9287 9474' AND 
	xy_to_osgb(472945, 103830, 10) = 'SU 7294 0383' AND 
	
	xy_to_osgb(432574, 332567, 1) = 'SK 32574 32567' AND 
	xy_to_osgb(236336, 682945, 1) = 'NS 36336 82945' AND 
	xy_to_osgb(392876, 494743, 1) = 'SD 92876 94743' AND 
	xy_to_osgb(472945, 103830, 1) = 'SU 72945 03830';
	
*/
