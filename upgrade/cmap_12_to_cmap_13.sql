--Changes a CMap database from version 0.12 to version 0.13 
--  in place


--Update cmap_correspondence_evidence
alter table cmap_correspondence_evidence 
 add column evidence_type_accession varchar(20) default '0',
 add column rank int(11) default '0';
update cmap_evidence_type et, cmap_correspondence_evidence ce 
 set ce.evidence_type_accession=et.accession_id,
     ce.rank=et.rank
 where et.evidence_type_id = ce.evidence_type_id;


--Update features
alter table cmap_feature add column feature_type_accession varchar(20);
alter table cmap_feature add column default_rank int(11) default '1';
alter table cmap_feature add column direction tinyint(4) default '1';

update cmap_feature_type ft, cmap_feature f 
 set f.feature_type_accession=ft.accession_id,
     f.default_rank=ft.default_rank,
     f.direction=1
 where ft.feature_type_id = f.feature_type_id;


--Update map_sets
alter table cmap_map_set add column map_type_accession varchar(20);
alter table cmap_map_set add column map_units varchar(12);
alter table cmap_map_set add column is_relational_map tinyint(11);

update cmap_map_type mt, cmap_map_set ms 
 set ms.map_type_accession=mt.accession_id, 
     ms.map_units=mt.map_units, 
     ms.is_relational_map=mt.is_relational_map 
 where mt.map_type_id = ms.map_type_id;


--Drop lookup and then recreate it.
DROP TABLE cmap_correspondence_lookup;
CREATE TABLE cmap_correspondence_lookup (
  feature_id1 int(11) default NULL,
  feature_id2 int(11) default NULL,
  feature_correspondence_id int(11) default NULL,
  start_position1 double(11,2) default NULL,
  start_position2 double(11,2) default NULL,
  stop_position1 double(11,2) default NULL,
  stop_position2 double(11,2) default NULL,
  map_id1 int(11) default NULL,
  map_id2 int(11) default NULL,
  feature_type_accession1 varchar(20) default NULL,
  feature_type_accession2 varchar(20) default NULL,
  KEY feature_id1 (feature_id1),
  KEY corr_id (feature_correspondence_id),
  KEY cl_map_id1 (map_id1),
  KEY cl_map_id2 (map_id2),
  KEY cl_map_id1_map_id2 (map_id1,map_id2),
  KEY cl_map_id2_map_id1 (map_id2,map_id1)
) TYPE=MyISAM;

insert into cmap_correspondence_lookup
(feature_id1,feature_id2,
feature_correspondence_id,
start_position1,start_position2,
stop_position1,stop_position2,
map_id1,map_id2,
feature_type_accession1,feature_type_accession2)
select f1.feature_id,f2.feature_id,
fc.feature_correspondence_id,
f1.start_position,f2.start_position,
f1.stop_position,f2.stop_position,
f1.map_id,f2.map_id,
f1.feature_type_accession,f2.feature_type_accession
from cmap_feature_correspondence fc,cmap_feature f1, cmap_feature f2
where
f1.feature_id=fc.feature_id1 and f2.feature_id=fc.feature_id2
;

insert into cmap_correspondence_lookup
(feature_id2,feature_id1,
feature_correspondence_id,
start_position2,start_position1,
stop_position2,stop_position1,
map_id2,map_id1,
feature_type_accession2,feature_type_accession1)
select f1.feature_id,f2.feature_id,
fc.feature_correspondence_id,
f1.start_position,f2.start_position,
f1.stop_position,f2.stop_position,
f1.map_id,f2.map_id,
f1.feature_type_accession,f2.feature_type_accession
from cmap_feature_correspondence fc,cmap_feature f1, cmap_feature f2
where
f1.feature_id=fc.feature_id1 and f2.feature_id=fc.feature_id2
;

--Drop tables we no longer need
--DROP TABLE cmap_evidence_type;
--DROP TABLE cmap_feature_type;
--DROP TABLE cmap_map_cache;
--DROP TABLE cmap_map_type;
