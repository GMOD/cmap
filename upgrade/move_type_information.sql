alter table cmap_map_set add column map_units varchar(12);
alter table cmap_map_set add column is_relational_map tinyint(11);

alter table cmap_map_set add column map_type_accession varchar(20);
alter table cmap_feature add column feature_type_accession varchar(20);
alter table cmap_correspondence_evidence add column evidence_type_accession varchar(20);


update cmap_map_type mt, cmap_map_set ms set ms.map_type_accession=mt.accession_id, ms.map_units=mt.map_units, ms.is_relational_map=mt.is_relational_map where mt.map_type_id = ms.map_type_id;

update cmap_feature_type ft, cmap_feature f set f.feature_type_accession=ft.accession_id where ft.feature_type_id = f.feature_type_id; 

update cmap_evidence_type et, cmap_correspondence_evidence ce set ce.evidence_type_accession=et.accession_id where et.evidence_type_id = ce.evidence_type_id;

--alter table cmap_correspondence_evidence add column rank int(11);
--update cmap_evidence_type et, cmap_correspondence_evidence ce set ce.rank=et.rank where et.evidence_type_id = ce.evidence_type_id;

--alter table cmap_feature add column default_rank int(11);
--update cmap_feature_type ft, cmap_feature f set f.default_rank=ft.default_rank where ft.feature_type_id = f.feature_type_id;
