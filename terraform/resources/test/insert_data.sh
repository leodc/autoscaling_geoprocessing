#!/bin/bash

createdb -p 30001 test_db;
psql -p 30001 -d test_db -U ubuntu -c 'CREATE EXTENSION postgis';
psql -p 30001 -d test_db -U ubuntu -c 'create table osm_points(osm_id bigint, x double precision, y double precision) distribute by replication';
psql -p 30001 -d test_db -U ubuntu -c "copy osm_points from '/home/ubuntu/osm_points.csv' DELIMITER ',' csv";
psql -p 30001 -d test_db -U ubuntu -c "select addGeometryColumn('public', 'osm_points', 'the_geom', 3857, 'POINT', 2)";
psql -p 30001 -d test_db -U ubuntu -c "update osm_points set the_geom=ST_SetSRID(ST_MakePoint(x, y), 3857)";
