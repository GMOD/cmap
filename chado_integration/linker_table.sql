-- ================================================
-- TABLE: feature_to_cmap 
-- ================================================

create table feature_to_cmap (
    feature_to_cmap_id serial not null,
    primary key (feature_to_cmap_id),
    feature_id int not null,
    foreign key (feature_id) references feature (feature_id) on delete cascade INITIALLY DEFERRED,
    cmap_feature_aid varchar(20) not null,
    is_current boolean not null default 'true',
    constraint feature_to_cmap_c1 unique (feature_id,cmap_feature_aid)
);
create index feature_to_cmap_idx1 on feature_to_cmap (feature_id);

