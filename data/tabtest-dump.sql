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
-- Dumping data for table `cmap_correspondence_matrix`
--



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
-- Dumping data for table `cmap_feature_alias`
--


--
-- Dumping data for table `cmap_feature_correspondence`
--

INSERT INTO cmap_feature_correspondence VALUES (1,'1',5,18,1);
INSERT INTO cmap_feature_correspondence VALUES (2,'2',6,21,1);
INSERT INTO cmap_feature_correspondence VALUES (3,'3',7,25,1);
INSERT INTO cmap_feature_correspondence VALUES (4,'4',23,10,1);
INSERT INTO cmap_feature_correspondence VALUES (5,'5',8,26,1);

--
-- Dumping data for table `cmap_map`
--

INSERT INTO cmap_map VALUES (1,'1',2,'T1',1,0.00,4000.00);
INSERT INTO cmap_map VALUES (2,'2',2,'T2',1,0.00,1000.00);
INSERT INTO cmap_map VALUES (3,'3',3,'T3',1,0.00,4000.00);
INSERT INTO cmap_map VALUES (4,'4',3,'T4',1,0.00,1000.00);

--
-- Dumping data for table `cmap_map_cache`
--


--
-- Dumping data for table `cmap_map_set`
--

INSERT INTO cmap_map_set VALUES (2,'2','Map Set Test 1','MST1','Seq',1,NULL,1,1,1,'box','lightgrey',1,'bp',0);
INSERT INTO cmap_map_set VALUES (3,'3','Map Set Test 2','MST2','Seq',1,NULL,1,1,1,'box','lightgrey',1,'bp',0);


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
-- Dumping data for table `cmap_species`
--

INSERT INTO cmap_species VALUES (1,'SpTest','Species Test','Species Test',1);


--
-- Dumping data for table `cmap_xref`
--


