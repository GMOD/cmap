ALTER TABLE cmap_species CHANGE COLUMN common_name species_common_name varchar(64) NOT NULL default '';
ALTER TABLE cmap_species CHANGE COLUMN full_name species_full_name varchar(64) NOT NULL default '';
ALTER TABLE cmap_map_set CHANGE COLUMN short_name map_set_short_name varchar(30) NOT NULL default '';

ALTER TABLE cmap_map CHANGE COLUMN start_position map_start double(11,2) default NULL;
ALTER TABLE cmap_map CHANGE COLUMN stop_position map_stop double(11,2) default NULL;

update cmap_feature set stop_position = start_position where isNull(stop_position);
update cmap_correspondence_lookup set stop_position1 = start_position1 where isNull(stop_position1);
update cmap_correspondence_lookup set stop_position2 = start_position2 where isNull(stop_position2);
--If you've already changed the column names.
--update cmap_correspondence_lookup set feature_stop1 = feature_start1 where isNull(feature_stop1);
--update cmap_correspondence_lookup set feature_stop2 = feature_start2 where isNull(feature_stop2);

ALTER TABLE cmap_feature CHANGE COLUMN start_position feature_start double(11,2) NOT NULL default '0.00';
ALTER TABLE cmap_feature CHANGE COLUMN stop_position feature_stop double(11,2) NOT NULL;
DROP INDEX feature_id_map_id_start on cmap_feature;
CREATE INDEX feature_id_map_id_start ON cmap_feature (feature_id,feature_start,map_id);

ALTER TABLE cmap_correspondence_lookup CHANGE COLUMN start_position1 feature_start1 double(11,2) default NULL;
ALTER TABLE cmap_correspondence_lookup CHANGE COLUMN start_position2 feature_start2 double(11,2) default NULL;
ALTER TABLE cmap_correspondence_lookup CHANGE COLUMN stop_position1 feature_stop1 double(11,2) default NULL;
ALTER TABLE cmap_correspondence_lookup CHANGE COLUMN stop_position2 feature_stop2 double(11,2) default NULL;


ALTER TABLE cmap_correspondence_evidence CHANGE COLUMN accession_id correspondence_evidence_acc varchar(30) NOT NULL default '';
ALTER TABLE cmap_correspondence_evidence CHANGE COLUMN evidence_type_accession evidence_type_acc varchar(30) NOT NULL default '0';

ALTER TABLE cmap_correspondence_lookup CHANGE COLUMN feature_type_accession1 feature_type_acc1 varchar(30) default NULL;
ALTER TABLE cmap_correspondence_lookup CHANGE COLUMN feature_type_accession2 feature_type_acc2 varchar(30) default NULL;

ALTER TABLE cmap_correspondence_matrix CHANGE COLUMN reference_map_aid reference_map_acc varchar(30) NOT NULL default '0';
ALTER TABLE cmap_correspondence_matrix CHANGE COLUMN reference_map_set_aid reference_map_set_acc varchar(30) NOT NULL default '0';
ALTER TABLE cmap_correspondence_matrix CHANGE COLUMN reference_species_aid reference_species_acc varchar(30) NOT NULL default '0';
ALTER TABLE cmap_correspondence_matrix CHANGE COLUMN link_map_aid link_map_acc varchar(30) default NULL;
ALTER TABLE cmap_correspondence_matrix CHANGE COLUMN link_map_set_aid link_map_set_acc varchar(30) NOT NULL default '0';
ALTER TABLE cmap_correspondence_matrix CHANGE COLUMN link_species_aid link_species_acc varchar(30) NOT NULL default '0';
ALTER TABLE cmap_feature CHANGE COLUMN accession_id feature_acc varchar(30) NOT NULL default '' ;
ALTER TABLE cmap_feature CHANGE COLUMN feature_type_accession feature_type_acc varchar(30) NOT NULL default '0';
ALTER TABLE cmap_feature_correspondence CHANGE COLUMN accession_id feature_correspondence_acc varchar(30) NOT NULL default '' ;
ALTER TABLE cmap_map CHANGE COLUMN accession_id map_acc varchar(30) NOT NULL default '' ;
ALTER TABLE cmap_map_set CHANGE COLUMN accession_id map_set_acc varchar(30) NOT NULL default '' ;
ALTER TABLE cmap_map_set CHANGE COLUMN map_type_accession map_type_acc varchar(30) NOT NULL default '0' ;
ALTER TABLE cmap_species CHANGE COLUMN accession_id species_acc varchar(30) NOT NULL default '' ;

DROP INDEX acc_id_species_id on cmap_species;
CREATE INDEX acc_id_species_id ON cmap_species (species_acc,species_id);

DROP INDEX cmap_map_set_idx on cmap_map_set;
CREATE INDEX cmap_map_set_idx ON cmap_map_set (display_order,is_enabled,is_relational_map,map_set_short_name,published_on,species_id);

--ALTER TABLE cmap_map_set DROP can_be_reference_map;

--
-- Table structure for table `cmap_saved_link`
--

CREATE TABLE cmap_saved_link (
  saved_link_id int(11) NOT NULL default '0',
  saved_on date default NULL,
  last_access date default NULL,
  session_step_object text NOT NULL,
  saved_url text NOT NULL,
  legacy_url  text NOT NULL,
  link_title varchar(50) default '',
  link_comment varchar(200) default '',
  link_group varchar(40) NOT NULL default '',
  hidden  tinyint(4) NOT NULL default '0',
  PRIMARY KEY  (saved_link_id),
  KEY link_group (link_group)
) TYPE=MyISAM;
