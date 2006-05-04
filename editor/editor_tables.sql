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

