-- MySQL dump 8.23
--
-- Host: localhost    Database: IMPORT
---------------------------------------------------------
-- Server version	4.0.16-standard-log

--
-- Dumping data for table `cmap_attribute`
--



--
-- Dumping data for table `cmap_correspondence_evidence`
--


INSERT INTO cmap_correspondence_evidence (correspondence_evidence_id, accession_id, feature_correspondence_id, evidence_type_accession, score, rank) VALUES (1,'1',1,'ANB',NULL,1);
INSERT INTO cmap_correspondence_evidence (correspondence_evidence_id, accession_id, feature_correspondence_id, evidence_type_accession, score, rank) VALUES (2,'2',2,'ANB',NULL,1);
INSERT INTO cmap_correspondence_evidence (correspondence_evidence_id, accession_id, feature_correspondence_id, evidence_type_accession, score, rank) VALUES (3,'3',3,'ANB',NULL,1);
INSERT INTO cmap_correspondence_evidence (correspondence_evidence_id, accession_id, feature_correspondence_id, evidence_type_accession, score, rank) VALUES (4,'4',4,'ANB',NULL,1);
INSERT INTO cmap_correspondence_evidence (correspondence_evidence_id, accession_id, feature_correspondence_id, evidence_type_accession, score, rank) VALUES (5,'5',5,'ANB',NULL,1);

--
-- Dumping data for table `cmap_correspondence_lookup`
--


INSERT INTO cmap_correspondence_lookup (feature_id1, feature_id2, feature_correspondence_id, start_position1, start_position2, stop_position1, stop_position2, map_id1, map_id2, feature_type_accession1, feature_type_accession2) VALUES (6,21,1,1000.00,2200.00,2000.00,2700.00,1,3,'read','read');
INSERT INTO cmap_correspondence_lookup (feature_id1, feature_id2, feature_correspondence_id, start_position1, start_position2, stop_position1, stop_position2, map_id1, map_id2, feature_type_accession1, feature_type_accession2) VALUES (21,6,1,2200.00,1000.00,2700.00,2000.00,3,1,'read','read');
INSERT INTO cmap_correspondence_lookup (feature_id1, feature_id2, feature_correspondence_id, start_position1, start_position2, stop_position1, stop_position2, map_id1, map_id2, feature_type_accession1, feature_type_accession2) VALUES (25,7,2,0.00,2000.00,500.00,2300.00,4,1,'read','read');
INSERT INTO cmap_correspondence_lookup (feature_id1, feature_id2, feature_correspondence_id, start_position1, start_position2, stop_position1, stop_position2, map_id1, map_id2, feature_type_accession1, feature_type_accession2) VALUES (7,25,2,2000.00,0.00,2300.00,500.00,1,4,'read','read');
INSERT INTO cmap_correspondence_lookup (feature_id1, feature_id2, feature_correspondence_id, start_position1, start_position2, stop_position1, stop_position2, map_id1, map_id2, feature_type_accession1, feature_type_accession2) VALUES (10,23,3,3100.00,3100.00,4000.00,4000.00,1,3,'read','read');
INSERT INTO cmap_correspondence_lookup (feature_id1, feature_id2, feature_correspondence_id, start_position1, start_position2, stop_position1, stop_position2, map_id1, map_id2, feature_type_accession1, feature_type_accession2) VALUES (23,10,3,3100.00,3100.00,4000.00,4000.00,3,1,'read','read');
INSERT INTO cmap_correspondence_lookup (feature_id1, feature_id2, feature_correspondence_id, start_position1, start_position2, stop_position1, stop_position2, map_id1, map_id2, feature_type_accession1, feature_type_accession2) VALUES (26,8,4,500.00,2200.00,1000.00,2700.00,4,1,'read','read');
INSERT INTO cmap_correspondence_lookup (feature_id1, feature_id2, feature_correspondence_id, start_position1, start_position2, stop_position1, stop_position2, map_id1, map_id2, feature_type_accession1, feature_type_accession2) VALUES (8,26,4,2200.00,500.00,2700.00,1000.00,1,4,'read','read');
INSERT INTO cmap_correspondence_lookup (feature_id1, feature_id2, feature_correspondence_id, start_position1, start_position2, stop_position1, stop_position2, map_id1, map_id2, feature_type_accession1, feature_type_accession2) VALUES (5,18,5,450.00,450.00,1000.00,1000.00,1,3,'read','read');
INSERT INTO cmap_correspondence_lookup (feature_id1, feature_id2, feature_correspondence_id, start_position1, start_position2, stop_position1, stop_position2, map_id1, map_id2, feature_type_accession1, feature_type_accession2) VALUES (18,5,5,450.00,450.00,1000.00,1000.00,3,1,'read','read');

--
-- Dumping data for table `cmap_correspondence_matrix`
--


INSERT INTO cmap_correspondence_matrix (reference_map_aid, reference_map_name, reference_map_set_aid, reference_species_aid, link_map_aid, link_map_name, link_map_set_aid, link_species_aid, no_correspondences) VALUES ('1','T1','MST1','1','3','T3','MST2','1',3);
INSERT INTO cmap_correspondence_matrix (reference_map_aid, reference_map_name, reference_map_set_aid, reference_species_aid, link_map_aid, link_map_name, link_map_set_aid, link_species_aid, no_correspondences) VALUES ('1','T1','MST1','1','4','T4','MST2','1',2);
INSERT INTO cmap_correspondence_matrix (reference_map_aid, reference_map_name, reference_map_set_aid, reference_species_aid, link_map_aid, link_map_name, link_map_set_aid, link_species_aid, no_correspondences) VALUES ('3','T3','MST2','1','1','T1','MST1','1',3);
INSERT INTO cmap_correspondence_matrix (reference_map_aid, reference_map_name, reference_map_set_aid, reference_species_aid, link_map_aid, link_map_name, link_map_set_aid, link_species_aid, no_correspondences) VALUES ('4','T4','MST2','1','1','T1','MST1','1',2);

--
-- Dumping data for table `cmap_feature`
--


INSERT INTO cmap_feature (feature_id, accession_id, map_id, feature_type_accession, feature_name, is_landmark, start_position, stop_position, default_rank, direction) VALUES (1,'1',1,'contig','T1.1',0,0.00,1000.00,2,1);
INSERT INTO cmap_feature (feature_id, accession_id, map_id, feature_type_accession, feature_name, is_landmark, start_position, stop_position, default_rank, direction) VALUES (2,'2',1,'contig','T1.2',0,1000.00,2000.00,2,1);
INSERT INTO cmap_feature (feature_id, accession_id, map_id, feature_type_accession, feature_name, is_landmark, start_position, stop_position, default_rank, direction) VALUES (3,'3',1,'contig','T1.3',0,2000.00,4000.00,2,1);
INSERT INTO cmap_feature (feature_id, accession_id, map_id, feature_type_accession, feature_name, is_landmark, start_position, stop_position, default_rank, direction) VALUES (4,'4',1,'read','R1',0,0.00,500.00,3,1);
INSERT INTO cmap_feature (feature_id, accession_id, map_id, feature_type_accession, feature_name, is_landmark, start_position, stop_position, default_rank, direction) VALUES (5,'5',1,'read','R2',0,450.00,1000.00,3,1);
INSERT INTO cmap_feature (feature_id, accession_id, map_id, feature_type_accession, feature_name, is_landmark, start_position, stop_position, default_rank, direction) VALUES (6,'6',1,'read','R3',0,1000.00,2000.00,3,1);
INSERT INTO cmap_feature (feature_id, accession_id, map_id, feature_type_accession, feature_name, is_landmark, start_position, stop_position, default_rank, direction) VALUES (7,'7',1,'read','R4',0,2000.00,2300.00,3,1);
INSERT INTO cmap_feature (feature_id, accession_id, map_id, feature_type_accession, feature_name, is_landmark, start_position, stop_position, default_rank, direction) VALUES (8,'8',1,'read','R5',0,2200.00,2700.00,3,1);
INSERT INTO cmap_feature (feature_id, accession_id, map_id, feature_type_accession, feature_name, is_landmark, start_position, stop_position, default_rank, direction) VALUES (9,'9',1,'read','R6',0,2650.00,3300.00,3,1);
INSERT INTO cmap_feature (feature_id, accession_id, map_id, feature_type_accession, feature_name, is_landmark, start_position, stop_position, default_rank, direction) VALUES (10,'10',1,'read','R7',0,3100.00,4000.00,3,1);
INSERT INTO cmap_feature (feature_id, accession_id, map_id, feature_type_accession, feature_name, is_landmark, start_position, stop_position, default_rank, direction) VALUES (11,'11',2,'contig','T2.1',0,0.00,1000.00,2,1);
INSERT INTO cmap_feature (feature_id, accession_id, map_id, feature_type_accession, feature_name, is_landmark, start_position, stop_position, default_rank, direction) VALUES (12,'12',2,'read','R10',0,0.00,500.00,3,1);
INSERT INTO cmap_feature (feature_id, accession_id, map_id, feature_type_accession, feature_name, is_landmark, start_position, stop_position, default_rank, direction) VALUES (13,'13',2,'read','R11',0,500.00,1000.00,3,1);
INSERT INTO cmap_feature (feature_id, accession_id, map_id, feature_type_accession, feature_name, is_landmark, start_position, stop_position, default_rank, direction) VALUES (14,'14',3,'contig','T3.1',0,0.00,1000.00,2,1);
INSERT INTO cmap_feature (feature_id, accession_id, map_id, feature_type_accession, feature_name, is_landmark, start_position, stop_position, default_rank, direction) VALUES (15,'15',3,'contig','T3.2',0,1000.00,2000.00,2,1);
INSERT INTO cmap_feature (feature_id, accession_id, map_id, feature_type_accession, feature_name, is_landmark, start_position, stop_position, default_rank, direction) VALUES (16,'16',3,'contig','T3.3',0,2000.00,4000.00,2,1);
INSERT INTO cmap_feature (feature_id, accession_id, map_id, feature_type_accession, feature_name, is_landmark, start_position, stop_position, default_rank, direction) VALUES (17,'17',3,'read','RA',0,0.00,500.00,3,1);
INSERT INTO cmap_feature (feature_id, accession_id, map_id, feature_type_accession, feature_name, is_landmark, start_position, stop_position, default_rank, direction) VALUES (18,'18',3,'read','R2',0,450.00,1000.00,3,1);
INSERT INTO cmap_feature (feature_id, accession_id, map_id, feature_type_accession, feature_name, is_landmark, start_position, stop_position, default_rank, direction) VALUES (19,'19',3,'read','RB',0,1000.00,2000.00,3,1);
INSERT INTO cmap_feature (feature_id, accession_id, map_id, feature_type_accession, feature_name, is_landmark, start_position, stop_position, default_rank, direction) VALUES (20,'20',3,'read','RC',0,2000.00,2300.00,3,1);
INSERT INTO cmap_feature (feature_id, accession_id, map_id, feature_type_accession, feature_name, is_landmark, start_position, stop_position, default_rank, direction) VALUES (21,'21',3,'read','R3',0,2200.00,2700.00,3,1);
INSERT INTO cmap_feature (feature_id, accession_id, map_id, feature_type_accession, feature_name, is_landmark, start_position, stop_position, default_rank, direction) VALUES (22,'22',3,'read','RD',0,2650.00,3300.00,3,1);
INSERT INTO cmap_feature (feature_id, accession_id, map_id, feature_type_accession, feature_name, is_landmark, start_position, stop_position, default_rank, direction) VALUES (23,'23',3,'read','R7',0,3100.00,4000.00,3,1);
INSERT INTO cmap_feature (feature_id, accession_id, map_id, feature_type_accession, feature_name, is_landmark, start_position, stop_position, default_rank, direction) VALUES (24,'24',4,'contig','T4.1',0,0.00,1000.00,2,1);
INSERT INTO cmap_feature (feature_id, accession_id, map_id, feature_type_accession, feature_name, is_landmark, start_position, stop_position, default_rank, direction) VALUES (25,'25',4,'read','R4',0,0.00,500.00,3,1);
INSERT INTO cmap_feature (feature_id, accession_id, map_id, feature_type_accession, feature_name, is_landmark, start_position, stop_position, default_rank, direction) VALUES (26,'26',4,'read','R5',0,500.00,1000.00,3,1);

--
-- Dumping data for table `cmap_feature_alias`
--



--
-- Dumping data for table `cmap_feature_correspondence`
--


INSERT INTO cmap_feature_correspondence (feature_correspondence_id, accession_id, feature_id1, feature_id2, is_enabled) VALUES (1,'1',6,21,1);
INSERT INTO cmap_feature_correspondence (feature_correspondence_id, accession_id, feature_id1, feature_id2, is_enabled) VALUES (2,'2',25,7,1);
INSERT INTO cmap_feature_correspondence (feature_correspondence_id, accession_id, feature_id1, feature_id2, is_enabled) VALUES (3,'3',10,23,1);
INSERT INTO cmap_feature_correspondence (feature_correspondence_id, accession_id, feature_id1, feature_id2, is_enabled) VALUES (4,'4',26,8,1);
INSERT INTO cmap_feature_correspondence (feature_correspondence_id, accession_id, feature_id1, feature_id2, is_enabled) VALUES (5,'5',5,18,1);

--
-- Dumping data for table `cmap_map`
--


INSERT INTO cmap_map (map_id, accession_id, map_set_id, map_name, display_order, start_position, stop_position) VALUES (1,'1',1,'T1',1,0.00,4000.00);
INSERT INTO cmap_map (map_id, accession_id, map_set_id, map_name, display_order, start_position, stop_position) VALUES (2,'2',1,'T2',1,0.00,1000.00);
INSERT INTO cmap_map (map_id, accession_id, map_set_id, map_name, display_order, start_position, stop_position) VALUES (3,'3',2,'T3',1,0.00,4000.00);
INSERT INTO cmap_map (map_id, accession_id, map_set_id, map_name, display_order, start_position, stop_position) VALUES (4,'4',2,'T4',1,0.00,1000.00);

--
-- Dumping data for table `cmap_map_set`
--


INSERT INTO cmap_map_set (map_set_id, accession_id, map_set_name, short_name, map_type_accession, species_id, published_on, can_be_reference_map, display_order, is_enabled, shape, color, width, map_units, is_relational_map) VALUES (1,'MST1','Map Set Test 1','MST1','Seq',1,'2005-04-13',1,1,1,'span','lightgrey',0,'bp',0);
INSERT INTO cmap_map_set (map_set_id, accession_id, map_set_name, short_name, map_type_accession, species_id, published_on, can_be_reference_map, display_order, is_enabled, shape, color, width, map_units, is_relational_map) VALUES (2,'MST2','Map Set Test 2','MST2','Seq',1,'2005-04-13',1,1,1,'span','lightgrey',0,'bp',0);

--
-- Dumping data for table `cmap_next_number`
--


INSERT INTO cmap_next_number (table_name, next_number) VALUES ('cmap_species',2);
INSERT INTO cmap_next_number (table_name, next_number) VALUES ('cmap_map_set',3);
INSERT INTO cmap_next_number (table_name, next_number) VALUES ('cmap_map',5);
INSERT INTO cmap_next_number (table_name, next_number) VALUES ('cmap_feature',27);
INSERT INTO cmap_next_number (table_name, next_number) VALUES ('cmap_feature_correspondence',6);
INSERT INTO cmap_next_number (table_name, next_number) VALUES ('cmap_correspondence_evidence',6);

--
-- Dumping data for table `cmap_species`
--


INSERT INTO cmap_species (species_id, accession_id, common_name, full_name, display_order) VALUES (1,'1','Test_Species','Test Species',1);

--
-- Dumping data for table `cmap_xref`
--



