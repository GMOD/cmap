  create table featureset (
    featureset_id serial not null,
    primary key (featureset_id),
    name varchar(255),
    uniquename varchar(255),
    feature_type_id int not null,
    foreign key (feature_type_id) references cvterm (cvterm_id) on delete cascade INITIALLY DEFERRED,
    organism_id int not null,
    foreign key (organism_id) references organism (organism_id) on delete cascade INITIALLY DEFERRED,
    constraint featureset_c1 unique (uniquename)
  );

  COMMENT ON TABLE featureset IS 'The featureset table is a mimic of the CMap map set idea';

  create table feature_featureset (
    featureset_id int not null,
    foreign key (featureset_id) references featureset (featureset_id) on delete cascade INITIALLY DEFERRED,
    feature_id int not null,
    foreign key (feature_id) references feature (feature_id) on delete cascade INITIALLY DEFERRED
  );

  COMMENT ON TABLE feature_featureset IS 'The feature_featureset table joins the feature and featureset tables.';

  create table featureset_dbxref (
    featureset_dbxref_id serial not null,
    primary key (featureset_dbxref_id),
    featureset_id int not null,
    foreign key (featureset_id) references featureset (featureset_id) on delete cascade INITIALLY DEFERRED,
    dbxref_id int not null,
    foreign key (dbxref_id) references dbxref (dbxref_id) on delete cascade INITIALLY DEFERRED,
    constraint featureset_dbxref_c1 unique (featureset_id,dbxref_id)
  );
  create index featureset_dbxref_idx1 on featureset_dbxref (featureset_id);
  create index featureset_dbxref_idx2 on featureset_dbxref (dbxref_id);

  create table featureloc_dbxref (
    featureloc_dbxref_id serial not null,
    primary key (featureloc_dbxref_id),
    featureloc_id int not null,
    foreign key (featureloc_id) references featureloc (featureloc_id) on delete cascade INITIALLY DEFERRED,
    dbxref_id int not null,
    foreign key (dbxref_id) references dbxref (dbxref_id) on delete cascade INITIALLY DEFERRED,
    constraint featureloc_dbxref_c1 unique (featureloc_id,dbxref_id)
  );
  create index featureloc_dbxref_idx1 on featureloc_dbxref (featureloc_id);
  create index featureloc_dbxref_idx2 on featureloc_dbxref (dbxref_id);

