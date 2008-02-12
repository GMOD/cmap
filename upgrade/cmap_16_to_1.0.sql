--
-- Table structure for table `cmap_map_to_feature`
--

CREATE TABLE cmap_map_to_feature (
  map_id int(11) NOT NULL default '0',
  map_acc varchar(30) NOT NULL default '',
  feature_id int(11) NOT NULL default '0',
  feature_acc varchar(30) NOT NULL default '',
  KEY map_id (map_id),
  KEY feature_id (feature_id)
) TYPE=MyISAM;

--
-- Table structure for table `cmap_transaction`
--

CREATE TABLE cmap_transaction (
  transaction_id int(11) NOT NULL default '0',
  transaction_date date default NULL,
  PRIMARY KEY (transaction_id)
) TYPE=MyISAM;

--
-- Table structure for table `cmap_commit_log`
--

CREATE TABLE cmap_commit_log (
  commit_log_id int(11) NOT NULL default '0',
  species_id int(11) NOT NULL default '0',
  species_acc varchar(30) NOT NULL default '',
  map_set_id int(11) NOT NULL default '0',
  map_set_acc varchar(30) NOT NULL default '',
  map_id int(11) NOT NULL default '0',
  map_acc varchar(30) NOT NULL default '',
  commit_type varchar(200) NOT NULL default '',
  commit_text varchar(200) NOT NULL default '',
  commit_object text NOT NULL default '',
  commit_date date default NULL,
  transaction_id int(11) NOT NULL default '0',
  PRIMARY KEY (commit_log_id)
) TYPE=MyISAM;


ALTER TABLE cmap_saved_link CHANGE COLUMN session_step_object session_step_object blob NOT NULL;
