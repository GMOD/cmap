-- MySQL dump 9.09
--
-- Host: localhost    Database: CMAP
-- ------------------------------------------------------
-- Server version	4.0.16-standard

--
-- Table structure for table `cmap_attribute`
--

CREATE TABLE cmap_attribute (
  attribute_id int(11) NOT NULL default '0',
  table_name varchar(30) NOT NULL default '',
  object_id int(11) NOT NULL default '0',
  display_order int(11) NOT NULL default '1',
  is_public tinyint(4) NOT NULL default '1',
  attribute_name varchar(200) NOT NULL default '',
  attribute_value text NOT NULL,
  PRIMARY KEY  (attribute_id),
  KEY table_name (table_name,object_id,display_order,attribute_name)
) TYPE=MyISAM;

--
-- Dumping data for table `cmap_attribute`
--


--
-- Table structure for table `cmap_correspondence_evidence`
--

CREATE TABLE cmap_correspondence_evidence (
  correspondence_evidence_id int(11) NOT NULL default '0',
  accession_id varchar(20) NOT NULL default '',
  feature_correspondence_id int(11) NOT NULL default '0',
  evidence_type_accession varchar(20) NOT NULL default '0',
  score double(8,2) default NULL,
  rank int(11) NOT NULL default '0',
  PRIMARY KEY  (correspondence_evidence_id),
  UNIQUE KEY accession_id (accession_id),
  KEY feature_correspondence_id (feature_correspondence_id)
) TYPE=MyISAM;

--
-- Dumping data for table `cmap_correspondence_evidence`
--

INSERT INTO cmap_correspondence_evidence VALUES (1,'1',1,'ANB',0.00,1);
INSERT INTO cmap_correspondence_evidence VALUES (2,'2',2,'ANB',0.00,1);
INSERT INTO cmap_correspondence_evidence VALUES (3,'3',3,'ANB',0.00,1);
INSERT INTO cmap_correspondence_evidence VALUES (4,'4',4,'ANB',0.00,1);
INSERT INTO cmap_correspondence_evidence VALUES (5,'5',5,'ANB',0.00,1);

--
-- Table structure for table `cmap_correspondence_lookup`
--

CREATE TABLE cmap_correspondence_lookup (
  feature_id1 int(11) default NULL,
  feature_id2 int(11) default NULL,
  feature_correspondence_id int(11) default NULL,
  KEY feature_id1 (feature_id1),
  KEY corr_id (feature_correspondence_id)
) TYPE=MyISAM;

--
-- Dumping data for table `cmap_correspondence_lookup`
--

INSERT INTO cmap_correspondence_lookup VALUES (5,18,1);
INSERT INTO cmap_correspondence_lookup VALUES (18,5,1);
INSERT INTO cmap_correspondence_lookup VALUES (6,21,2);
INSERT INTO cmap_correspondence_lookup VALUES (21,6,2);
INSERT INTO cmap_correspondence_lookup VALUES (7,25,3);
INSERT INTO cmap_correspondence_lookup VALUES (25,7,3);
INSERT INTO cmap_correspondence_lookup VALUES (23,10,4);
INSERT INTO cmap_correspondence_lookup VALUES (10,23,4);
INSERT INTO cmap_correspondence_lookup VALUES (8,26,5);
INSERT INTO cmap_correspondence_lookup VALUES (26,8,5);

--
-- Table structure for table `cmap_correspondence_matrix`
--

CREATE TABLE cmap_correspondence_matrix (
  reference_map_aid varchar(20) NOT NULL default '0',
  reference_map_name varchar(32) NOT NULL default '',
  reference_map_set_aid varchar(20) NOT NULL default '0',
  reference_species_aid varchar(20) NOT NULL default '0',
  link_map_aid varchar(20) default NULL,
  link_map_name varchar(32) default NULL,
  link_map_set_aid varchar(20) NOT NULL default '0',
  link_species_aid varchar(20) NOT NULL default '0',
  no_correspondences int(11) NOT NULL default '0'
) TYPE=MyISAM;

--
-- Dumping data for table `cmap_correspondence_matrix`
--


--
-- Table structure for table `cmap_feature`
--

CREATE TABLE cmap_feature (
  feature_id int(11) NOT NULL default '0',
  accession_id varchar(20) NOT NULL default '',
  map_id int(11) NOT NULL default '0',
  feature_type_accession varchar(20) NOT NULL default '0',
  feature_name varchar(32) NOT NULL default '',
  is_landmark tinyint(4) NOT NULL default '0',
  start_position double(11,2) NOT NULL default '0.00',
  stop_position double(11,2) default NULL,
  default_rank int(11) NOT NULL default '1',
  PRIMARY KEY  (feature_id),
  UNIQUE KEY accession_id (accession_id),
  KEY feature_name (feature_name),
  KEY feature_id_map_id (feature_id,map_id),
  KEY feature_id_map_id_start (feature_id,map_id,start_position),
  KEY map_id (map_id),
  KEY map_id_feature_id (map_id,feature_id)
) TYPE=MyISAM;

--
-- Dumping data for table `cmap_feature`
--

INSERT INTO cmap_feature VALUES (1,'1',1,'contig','T1.1',0,0.00,1000.00,1);
INSERT INTO cmap_feature VALUES (2,'2',1,'contig','T1.2',0,1000.00,2000.00,1);
INSERT INTO cmap_feature VALUES (3,'3',1,'contig','T1.3',0,2000.00,4000.00,1);
INSERT INTO cmap_feature VALUES (4,'4',1,'read','R1',0,0.00,500.00,1);
INSERT INTO cmap_feature VALUES (5,'5',1,'read','R2',0,450.00,1000.00,1);
INSERT INTO cmap_feature VALUES (6,'6',1,'read','R3',0,1000.00,2000.00,1);
INSERT INTO cmap_feature VALUES (7,'7',1,'read','R4',0,2000.00,2300.00,1);
INSERT INTO cmap_feature VALUES (8,'8',1,'read','R5',0,2200.00,2700.00,1);
INSERT INTO cmap_feature VALUES (9,'9',1,'read','R6',0,2650.00,3300.00,1);
INSERT INTO cmap_feature VALUES (10,'10',1,'read','R7',0,3100.00,4000.00,1);
INSERT INTO cmap_feature VALUES (11,'11',2,'contig','T2.1',0,0.00,1000.00,1);
INSERT INTO cmap_feature VALUES (12,'12',2,'read','R10',0,0.00,500.00,1);
INSERT INTO cmap_feature VALUES (13,'13',2,'read','R11',0,500.00,1000.00,1);
INSERT INTO cmap_feature VALUES (14,'14',3,'contig','T3.1',0,0.00,1000.00,1);
INSERT INTO cmap_feature VALUES (15,'15',3,'contig','T3.2',0,1000.00,2000.00,1);
INSERT INTO cmap_feature VALUES (16,'16',3,'contig','T3.3',0,2000.00,4000.00,1);
INSERT INTO cmap_feature VALUES (17,'17',3,'read','RA',0,0.00,500.00,1);
INSERT INTO cmap_feature VALUES (18,'18',3,'read','R2',0,450.00,1000.00,1);
INSERT INTO cmap_feature VALUES (19,'19',3,'read','RB',0,1000.00,2000.00,1);
INSERT INTO cmap_feature VALUES (20,'20',3,'read','RC',0,2000.00,2300.00,1);
INSERT INTO cmap_feature VALUES (21,'21',3,'read','R3',0,2200.00,2700.00,1);
INSERT INTO cmap_feature VALUES (22,'22',3,'read','RD',0,2650.00,3300.00,1);
INSERT INTO cmap_feature VALUES (23,'23',3,'read','R7',0,3100.00,4000.00,1);
INSERT INTO cmap_feature VALUES (24,'24',4,'contig','T4.1',0,0.00,1000.00,1);
INSERT INTO cmap_feature VALUES (25,'25',4,'read','R4',0,0.00,500.00,1);
INSERT INTO cmap_feature VALUES (26,'26',4,'read','R5',0,500.00,1000.00,1);

--
-- Table structure for table `cmap_feature_alias`
--

CREATE TABLE cmap_feature_alias (
  feature_alias_id int(11) NOT NULL default '0',
  feature_id int(11) NOT NULL default '0',
  alias varchar(255) default NULL,
  PRIMARY KEY  (feature_alias_id),
  UNIQUE KEY feature_id_2 (feature_id,alias),
  KEY feature_id (feature_id),
  KEY alias (alias)
) TYPE=MyISAM;

--
-- Dumping data for table `cmap_feature_alias`
--


--
-- Table structure for table `cmap_feature_correspondence`
--

CREATE TABLE cmap_feature_correspondence (
  feature_correspondence_id int(11) NOT NULL default '0',
  accession_id varchar(20) NOT NULL default '',
  feature_id1 int(11) NOT NULL default '0',
  feature_id2 int(11) NOT NULL default '0',
  is_enabled tinyint(4) NOT NULL default '1',
  PRIMARY KEY  (feature_correspondence_id),
  UNIQUE KEY accession_id (accession_id),
  KEY feature_id1 (feature_id1),
  KEY cmap_feature_corresp_idx (is_enabled,feature_correspondence_id)
) TYPE=MyISAM;

--
-- Dumping data for table `cmap_feature_correspondence`
--

INSERT INTO cmap_feature_correspondence VALUES (1,'1',5,18,1);
INSERT INTO cmap_feature_correspondence VALUES (2,'2',6,21,1);
INSERT INTO cmap_feature_correspondence VALUES (3,'3',7,25,1);
INSERT INTO cmap_feature_correspondence VALUES (4,'4',23,10,1);
INSERT INTO cmap_feature_correspondence VALUES (5,'5',8,26,1);

--
-- Table structure for table `cmap_map`
--

CREATE TABLE cmap_map (
  map_id int(11) NOT NULL default '0',
  accession_id varchar(20) NOT NULL default '',
  map_set_id int(11) NOT NULL default '0',
  map_name varchar(32) NOT NULL default '',
  display_order int(11) NOT NULL default '1',
  start_position double(11,2) default NULL,
  stop_position double(11,2) default NULL,
  PRIMARY KEY  (map_id),
  UNIQUE KEY accession_id (accession_id),
  UNIQUE KEY map_id (map_id,map_set_id,map_name,accession_id)
) TYPE=MyISAM;

--
-- Dumping data for table `cmap_map`
--

INSERT INTO cmap_map VALUES (1,'1',2,'T1',1,0.00,4000.00);
INSERT INTO cmap_map VALUES (2,'2',2,'T2',1,0.00,1000.00);
INSERT INTO cmap_map VALUES (3,'3',3,'T3',1,0.00,4000.00);
INSERT INTO cmap_map VALUES (4,'4',3,'T4',1,0.00,1000.00);

--
-- Table structure for table `cmap_map_cache`
--

CREATE TABLE cmap_map_cache (
  pid int(11) NOT NULL default '0',
  slot_no smallint(6) NOT NULL default '0',
  map_id int(11) NOT NULL default '0',
  start_position double(11,2) default NULL,
  stop_position double(11,2) default NULL,
  KEY pid_cmap_map_cache (pid,slot_no,map_id)
) TYPE=MyISAM;

--
-- Dumping data for table `cmap_map_cache`
--


--
-- Table structure for table `cmap_map_set`
--

CREATE TABLE cmap_map_set (
  map_set_id int(11) NOT NULL default '0',
  accession_id varchar(20) NOT NULL default '',
  map_set_name varchar(64) NOT NULL default '',
  short_name varchar(30) NOT NULL default '',
  map_type_accession varchar(20) NOT NULL default '0',
  species_id int(11) NOT NULL default '0',
  published_on date default NULL,
  can_be_reference_map tinyint(4) NOT NULL default '1',
  display_order int(11) NOT NULL default '1',
  is_enabled tinyint(4) NOT NULL default '1',
  shape varchar(12) default NULL,
  color varchar(20) default NULL,
  width int(11) default NULL,
  map_units varchar(12) NOT NULL default '',
  is_relational_map tinyint(11) NOT NULL default '0',
  PRIMARY KEY  (map_set_id),
  UNIQUE KEY accession_id (accession_id),
  UNIQUE KEY map_set_id (map_set_id,species_id,short_name,accession_id),
  KEY cmap_map_set_idx (can_be_reference_map,is_enabled,species_id,display_order,published_on,short_name)
) TYPE=MyISAM;

--
-- Dumping data for table `cmap_map_set`
--

INSERT INTO cmap_map_set VALUES (2,'2','Map Set Test 1','MST1','Seq',1,NULL,1,1,1,'box','lightgrey',1,'bp',0);
INSERT INTO cmap_map_set VALUES (3,'3','Map Set Test 2','MST2','Seq',1,NULL,1,1,1,'box','lightgrey',1,'bp',0);

--
-- Table structure for table `cmap_next_number`
--

CREATE TABLE cmap_next_number (
  table_name varchar(40) NOT NULL default '',
  next_number int(11) NOT NULL default '0',
  PRIMARY KEY  (table_name)
) TYPE=MyISAM;

--
-- Dumping data for table `cmap_next_number`
--

INSERT INTO cmap_next_number VALUES ('cmap_species',2);
INSERT INTO cmap_next_number VALUES ('cmap_map_set',4);
INSERT INTO cmap_next_number VALUES ('cmap_map',5);
INSERT INTO cmap_next_number VALUES ('cmap_feature',27);
INSERT INTO cmap_next_number VALUES ('cmap_feature_correspondence',6);
INSERT INTO cmap_next_number VALUES ('cmap_correspondence_evidence',6);

--
-- Table structure for table `cmap_species`
--

CREATE TABLE cmap_species (
  species_id int(11) NOT NULL default '0',
  accession_id varchar(20) NOT NULL default '',
  common_name varchar(64) NOT NULL default '',
  full_name varchar(64) NOT NULL default '',
  display_order int(11) NOT NULL default '1',
  PRIMARY KEY  (species_id),
  KEY acc_id_species_id (accession_id,species_id)
) TYPE=MyISAM;

--
-- Dumping data for table `cmap_species`
--

INSERT INTO cmap_species VALUES (1,'SpTest','Species Test','Species Test',1);

--
-- Table structure for table `cmap_xref`
--

CREATE TABLE cmap_xref (
  xref_id int(11) NOT NULL default '0',
  table_name varchar(30) NOT NULL default '',
  object_id int(11) default NULL,
  display_order int(11) NOT NULL default '1',
  xref_name varchar(200) NOT NULL default '',
  xref_url text NOT NULL,
  PRIMARY KEY  (xref_id),
  KEY table_name (table_name,object_id,display_order)
) TYPE=MyISAM;

--
-- Dumping data for table `cmap_xref`
--


