-- MySQL dump 9.09
--
-- Host: localhost    Database: CMAP
-- ------------------------------------------------------
-- Server version	4.0.16-standard

--
-- Dumping data for table `cmap_attribute`
--


--
-- Dumping data for table `cmap_correspondence_evidence`
--

INSERT INTO cmap_correspondence_evidence VALUES (1,'1',1,'ANB',0.00,1);
INSERT INTO cmap_correspondence_evidence VALUES (2,'2',2,'ANB',0.00,1);
INSERT INTO cmap_correspondence_evidence VALUES (3,'3',3,'ANB',0.00,1);
INSERT INTO cmap_correspondence_evidence VALUES (4,'4',4,'ANB',0.00,1);
INSERT INTO cmap_correspondence_evidence VALUES (5,'5',5,'ANB',0.00,1);

--
-- Dumping data for table `cmap_correspondence_lookup`
--

INSERT INTO cmap_correspondence_lookup VALUES (23,36,1,3100.00,3100.00,4000.00,4000.00,3,5,'read','read');
INSERT INTO cmap_correspondence_lookup VALUES (36,23,1,3100.00,3100.00,4000.00,4000.00,5,3,'read','read');
INSERT INTO cmap_correspondence_lookup VALUES (38,20,2,0.00,2000.00,500.00,2300.00,6,3,'read','read');
INSERT INTO cmap_correspondence_lookup VALUES (20,38,2,2000.00,0.00,2300.00,500.00,3,6,'read','read');
INSERT INTO cmap_correspondence_lookup VALUES (21,39,3,2200.00,500.00,2700.00,1000.00,3,6,'read','read');
INSERT INTO cmap_correspondence_lookup VALUES (39,21,3,500.00,2200.00,1000.00,2700.00,6,3,'read','read');
INSERT INTO cmap_correspondence_lookup VALUES (34,19,4,2200.00,1000.00,2700.00,2000.00,5,3,'read','read');
INSERT INTO cmap_correspondence_lookup VALUES (19,34,4,1000.00,2200.00,2000.00,2700.00,3,5,'read','read');
INSERT INTO cmap_correspondence_lookup VALUES (18,31,5,450.00,450.00,1000.00,1000.00,3,5,'read','read');
INSERT INTO cmap_correspondence_lookup VALUES (31,18,5,450.00,450.00,1000.00,1000.00,5,3,'read','read');

--
-- Dumping data for table `cmap_correspondence_matrix`
--


--
-- Dumping data for table `cmap_feature`
--

INSERT INTO cmap_feature VALUES (23,'23',3,'read','R7',0,3100.00,4000.00,1,1);
INSERT INTO cmap_feature VALUES (22,'22',3,'read','R6',0,2650.00,3300.00,1,1);
INSERT INTO cmap_feature VALUES (21,'21',3,'read','R5',0,2200.00,2700.00,1,1);
INSERT INTO cmap_feature VALUES (20,'20',3,'read','R4',0,2000.00,2300.00,1,1);
INSERT INTO cmap_feature VALUES (19,'19',3,'read','R3',0,1000.00,2000.00,1,1);
INSERT INTO cmap_feature VALUES (18,'18',3,'read','R2',0,450.00,1000.00,1,1);
INSERT INTO cmap_feature VALUES (17,'17',3,'read','R1',0,0.00,500.00,1,1);
INSERT INTO cmap_feature VALUES (16,'16',3,'contig','T1.3',0,2000.00,4000.00,1,1);
INSERT INTO cmap_feature VALUES (15,'15',3,'contig','T1.2',0,1000.00,2000.00,1,1);
INSERT INTO cmap_feature VALUES (14,'14',3,'contig','T1.1',0,0.00,1000.00,1,1);
INSERT INTO cmap_feature VALUES (24,'24',4,'contig','T2.1',0,0.00,1000.00,1,1);
INSERT INTO cmap_feature VALUES (25,'25',4,'read','R10',0,0.00,500.00,1,1);
INSERT INTO cmap_feature VALUES (26,'26',4,'read','R11',0,500.00,1000.00,1,1);
INSERT INTO cmap_feature VALUES (27,'27',5,'contig','T3.1',0,0.00,1000.00,1,1);
INSERT INTO cmap_feature VALUES (28,'28',5,'contig','T3.2',0,1000.00,2000.00,1,1);
INSERT INTO cmap_feature VALUES (29,'29',5,'contig','T3.3',0,2000.00,4000.00,1,1);
INSERT INTO cmap_feature VALUES (30,'30',5,'read','RA',0,0.00,500.00,1,1);
INSERT INTO cmap_feature VALUES (31,'31',5,'read','R2',0,450.00,1000.00,1,1);
INSERT INTO cmap_feature VALUES (32,'32',5,'read','RB',0,1000.00,2000.00,1,1);
INSERT INTO cmap_feature VALUES (33,'33',5,'read','RC',0,2000.00,2300.00,1,1);
INSERT INTO cmap_feature VALUES (34,'34',5,'read','R3',0,2200.00,2700.00,1,1);
INSERT INTO cmap_feature VALUES (35,'35',5,'read','RD',0,2650.00,3300.00,1,1);
INSERT INTO cmap_feature VALUES (36,'36',5,'read','R7',0,3100.00,4000.00,1,1);
INSERT INTO cmap_feature VALUES (37,'37',6,'contig','T4.1',0,0.00,1000.00,1,1);
INSERT INTO cmap_feature VALUES (38,'38',6,'read','R4',0,0.00,500.00,1,1);
INSERT INTO cmap_feature VALUES (39,'39',6,'read','R5',0,500.00,1000.00,1,1);

--
-- Dumping data for table `cmap_feature_alias`
--


--
-- Dumping data for table `cmap_feature_correspondence`
--

INSERT INTO cmap_feature_correspondence VALUES (1,'1',23,36,1);
INSERT INTO cmap_feature_correspondence VALUES (2,'2',38,20,1);
INSERT INTO cmap_feature_correspondence VALUES (3,'3',21,39,1);
INSERT INTO cmap_feature_correspondence VALUES (4,'4',34,19,1);
INSERT INTO cmap_feature_correspondence VALUES (5,'5',18,31,1);

--
-- Dumping data for table `cmap_map`
--

INSERT INTO cmap_map VALUES (4,'4',4,'T2',1,0.00,1000.00);
INSERT INTO cmap_map VALUES (3,'3',4,'T1',1,0.00,4000.00);
INSERT INTO cmap_map VALUES (5,'5',5,'T3',1,0.00,4000.00);
INSERT INTO cmap_map VALUES (6,'6',5,'T4',1,0.00,1000.00);

--
-- Dumping data for table `cmap_map_cache`
--


--
-- Dumping data for table `cmap_map_set`
--

INSERT INTO cmap_map_set VALUES (4,'MST1','Map Set Test 1','MST1','Seq',1,NULL,1,1,1,'box','lightgrey',1,'bp',0);
INSERT INTO cmap_map_set VALUES (5,'MST2','Map Set Test 2','MST2','Seq',1,NULL,1,1,1,'box','lightgrey',1,'bp',0);

--
-- Dumping data for table `cmap_next_number`
--

INSERT INTO cmap_next_number VALUES ('cmap_species',2);
INSERT INTO cmap_next_number VALUES ('cmap_map_set',6);
INSERT INTO cmap_next_number VALUES ('cmap_map',7);
INSERT INTO cmap_next_number VALUES ('cmap_feature',40);
INSERT INTO cmap_next_number VALUES ('cmap_feature_correspondence',11);
INSERT INTO cmap_next_number VALUES ('cmap_correspondence_evidence',11);

--
-- Dumping data for table `cmap_species`
--

INSERT INTO cmap_species VALUES (1,'1','Test_Species','Test Species',1);

--
-- Dumping data for table `cmap_xref`
--


