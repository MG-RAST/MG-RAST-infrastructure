/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Curator` (
  `_id` int(11) NOT NULL AUTO_INCREMENT,
  `ID` int(11) DEFAULT NULL,
  `date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `status` varchar(128) DEFAULT NULL,
  `name` varchar(128) DEFAULT NULL,
  `email` varchar(128) DEFAULT NULL,
  `url` varchar(128) DEFAULT NULL,
  `user` int(11) DEFAULT NULL,
  `_user_db` int(11) DEFAULT NULL,
  `type` varchar(128) DEFAULT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `Curator_unique_0` (`ID`),
  KEY `Curator_0` (`name`),
  KEY `Curator_1` (`user`,`_user_db`)
) ENGINE=InnoDB AUTO_INCREMENT=3353 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Job` (
  `_id` int(11) NOT NULL AUTO_INCREMENT,
  `owner` int(11) DEFAULT NULL,
  `_owner_db` int(11) DEFAULT NULL,
  `viewable` tinyint(1) DEFAULT NULL,
  `file_checksum_raw` varchar(32) DEFAULT NULL,
  `job_id` int(11) DEFAULT NULL,
  `options` text,
  `primary_project` int(11) DEFAULT NULL,
  `_primary_project_db` int(11) DEFAULT NULL,
  `current_stage` text,
  `server_version` varchar(64) DEFAULT NULL,
  `file` text,
  `name` varchar(128) DEFAULT NULL,
  `metagenome_id` varchar(64) DEFAULT NULL,
  `created_on` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `public` tinyint(1) DEFAULT NULL,
  `sample` int(11) DEFAULT NULL,
  `_sample_db` int(11) DEFAULT NULL,
  `file_size_raw` bigint(20) DEFAULT NULL,
  `sequence_type` varchar(64) DEFAULT NULL,
  `library` int(11) DEFAULT NULL,
  `_library_db` int(11) DEFAULT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `Job_unique_0` (`job_id`),
  UNIQUE KEY `Job_unique_1` (`metagenome_id`),
  KEY `Job_0` (`owner`,`_owner_db`),
  KEY `Job_1` (`viewable`),
  KEY `Job_2` (`public`),
  KEY `Job_3` (`primary_project`,`_primary_project_db`),
  KEY `Job_4` (`sample`,`_sample_db`),
  KEY `Job_5` (`library`,`_library_db`),
  KEY `Job_6` (`file_checksum_raw`),
  KEY `Job_7` (`created_on`),
  KEY `Job_project` (`primary_project`)
) ENGINE=InnoDB AUTO_INCREMENT=422474 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `JobAttributes` (
  `_id` int(11) NOT NULL AUTO_INCREMENT,
  `timestamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `value` text,
  `tag` varchar(128) DEFAULT NULL,
  `job` int(11) DEFAULT NULL,
  `_job_db` int(11) DEFAULT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `JobAttributes_0` (`job`,`_job_db`,`tag`),
  KEY `JobAttributes_tag` (`tag`)
) ENGINE=InnoDB AUTO_INCREMENT=11281369 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `JobInfo` (
  `_id` int(11) NOT NULL AUTO_INCREMENT,
  `job` int(11) DEFAULT NULL,
  `_job_db` int(11) DEFAULT NULL,
  `timestamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `project_name` text,
  `project_pi` text,
  `sequence_type` text,
  `sequence_tech` text,
  `latitude` float DEFAULT NULL,
  `longitude` float DEFAULT NULL,
  `country` text,
  `location` text,
  `biome` text,
  `feature` text,
  `material` text,
  `env_package` text,
  `bp_count` int(11) DEFAULT NULL,
  `seq_count` int(11) DEFAULT NULL,
  `avg_len` float DEFAULT NULL,
  `drisee` float DEFAULT NULL,
  `alpha_diverse` float DEFAULT NULL,
  PRIMARY KEY (`_id`),
  KEY `JobInfo_0` (`job`,`_job_db`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `JobStatistics` (
  `_id` int(11) NOT NULL AUTO_INCREMENT,
  `timestamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `value` text,
  `tag` varchar(128) DEFAULT NULL,
  `job` int(11) DEFAULT NULL,
  `_job_db` int(11) DEFAULT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `JobStatistics_0` (`job`,`_job_db`,`tag`),
  KEY `JobStatistics_tag` (`tag`)
) ENGINE=InnoDB AUTO_INCREMENT=1016863692 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Jobgroup` (
  `_id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(64) DEFAULT NULL,
  PRIMARY KEY (`_id`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `JobgroupJob` (
  `_id` int(11) NOT NULL AUTO_INCREMENT,
  `jobgroup` int(11) DEFAULT NULL,
  `_jobgroup_db` int(11) DEFAULT NULL,
  `job` int(11) DEFAULT NULL,
  `_job_db` int(11) DEFAULT NULL,
  PRIMARY KEY (`_id`)
) ENGINE=InnoDB AUTO_INCREMENT=4895 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Measurement` (
  `_id` int(11) NOT NULL AUTO_INCREMENT,
  `unit` varchar(128) DEFAULT NULL,
  `value` text,
  `name` varchar(128) DEFAULT NULL,
  `collection` int(11) DEFAULT NULL,
  `_collection_db` int(11) DEFAULT NULL,
  `field` int(11) DEFAULT NULL,
  `_field_db` int(11) DEFAULT NULL,
  PRIMARY KEY (`_id`),
  KEY `Measurement_0` (`collection`,`_collection_db`),
  KEY `Measurement_1` (`field`,`_field_db`),
  KEY `Measurement_3` (`unit`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `MetaDataCV` (
  `_id` int(11) NOT NULL AUTO_INCREMENT,
  `type` varchar(32) NOT NULL,
  `tag` varchar(128) NOT NULL,
  `value` text,
  `value_id` text,
  `value_version` varchar(128) DEFAULT NULL,
  PRIMARY KEY (`_id`),
  KEY `MetaDataCV_version` (`value_version`),
  KEY `MetaDataCV_type` (`type`),
  KEY `MetaDataCV_tag` (`tag`)
) ENGINE=InnoDB AUTO_INCREMENT=378486 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `MetaDataCV_old` (
  `_id` int(11) NOT NULL AUTO_INCREMENT,
  `type` varchar(32) NOT NULL,
  `tag` varchar(128) NOT NULL,
  `value` text,
  `value_id` text,
  `value_version` varchar(32) DEFAULT NULL,
  PRIMARY KEY (`_id`),
  KEY `MetaDataCV_version` (`value_version`),
  KEY `MetaDataCV_type` (`type`),
  KEY `MetaDataCV_tag` (`tag`)
) ENGINE=InnoDB AUTO_INCREMENT=2202 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `MetaDataCollection` (
  `_id` int(11) NOT NULL AUTO_INCREMENT,
  `source` varchar(128) DEFAULT NULL,
  `ID` int(11) DEFAULT NULL,
  `creator` int(11) DEFAULT NULL,
  `_creator_db` int(11) DEFAULT NULL,
  `entry_date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `url` varchar(128) DEFAULT NULL,
  `type` varchar(64) DEFAULT NULL,
  `parent` int(11) DEFAULT NULL,
  `_parent_db` int(11) DEFAULT NULL,
  `name` varchar(128) DEFAULT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `MetaDataCollection_unique_0` (`ID`),
  KEY `MetaDataCollection_1` (`source`),
  KEY `MetaDataCollection_2` (`creator`,`_creator_db`),
  KEY `MetaDataCollection_3` (`type`),
  KEY `MetaDataCollection_4` (`parent`,`_parent_db`),
  KEY `MetaDataCollection_collection` (`parent`)
) ENGINE=InnoDB AUTO_INCREMENT=894124 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `MetaDataEntry` (
  `_id` int(11) NOT NULL AUTO_INCREMENT,
  `value` mediumtext COLLATE utf8mb4_unicode_ci,
  `collection` int(11) DEFAULT NULL,
  `_collection_db` int(11) DEFAULT NULL,
  `tag` varchar(128) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `mixs` tinyint(1) DEFAULT NULL,
  `required` tinyint(1) DEFAULT NULL,
  PRIMARY KEY (`_id`),
  KEY `MetaDataEntry_0` (`tag`),
  KEY `MetaDataEntry_2` (`collection`,`_collection_db`),
  KEY `MetaDataEntry_collection` (`collection`)
) ENGINE=InnoDB AUTO_INCREMENT=10915960 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `MetaDataTemplate` (
  `_id` int(11) NOT NULL AUTO_INCREMENT,
  `category` varchar(64) COLLATE utf8mb4_unicode_ci NOT NULL,
  `category_type` varchar(32) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `qiime_tag` varchar(128) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `mgrast_tag` varchar(128) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `tag` varchar(128) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `definition` mediumtext COLLATE utf8mb4_unicode_ci NOT NULL,
  `required` tinyint(1) NOT NULL,
  `mixs` tinyint(1) NOT NULL,
  `type` mediumtext COLLATE utf8mb4_unicode_ci NOT NULL,
  `fw_type` mediumtext COLLATE utf8mb4_unicode_ci,
  `unit` mediumtext COLLATE utf8mb4_unicode_ci,
  PRIMARY KEY (`_id`),
  KEY `MetaDataTemplate_0` (`category`,`tag`),
  KEY `MetaDataTemplate_1` (`required`)
) ENGINE=InnoDB AUTO_INCREMENT=877 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `PipelineStage` (
  `_id` int(11) NOT NULL AUTO_INCREMENT,
  `stage` varchar(128) DEFAULT NULL,
  `timestamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `options` text,
  `version` varchar(64) DEFAULT NULL,
  `status` varchar(128) DEFAULT NULL,
  `position` int(11) DEFAULT NULL,
  `display_name` text,
  `job` int(11) DEFAULT NULL,
  `_job_db` int(11) DEFAULT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `PipelineStage_0` (`job`,`_job_db`,`stage`),
  KEY `PipelineStage_1` (`status`),
  KEY `PipelineStage_stage_index` (`stage`)
) ENGINE=InnoDB AUTO_INCREMENT=2708506 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Project` (
  `_id` int(11) NOT NULL AUTO_INCREMENT,
  `creator` int(11) DEFAULT NULL,
  `_creator_db` int(11) DEFAULT NULL,
  `public` tinyint(1) DEFAULT NULL,
  `name` varchar(256) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `type` varchar(64) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `id` int(11) DEFAULT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `Project_unique_0` (`id`),
  KEY `Project_0` (`public`),
  KEY `Project_1` (`type`)
) ENGINE=InnoDB AUTO_INCREMENT=89791 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `ProjectCollection` (
  `_id` int(11) NOT NULL AUTO_INCREMENT,
  `project` int(11) DEFAULT NULL,
  `_project_db` int(11) DEFAULT NULL,
  `collection` int(11) DEFAULT NULL,
  `_collection_db` int(11) DEFAULT NULL,
  PRIMARY KEY (`_id`),
  KEY `ProjectCollection_0` (`collection`,`_collection_db`),
  KEY `ProjectCollection_1` (`project`,`_project_db`)
) ENGINE=InnoDB AUTO_INCREMENT=906290 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `ProjectJob` (
  `_id` int(11) NOT NULL AUTO_INCREMENT,
  `project` int(11) DEFAULT NULL,
  `_project_db` int(11) DEFAULT NULL,
  `job` int(11) DEFAULT NULL,
  `_job_db` int(11) DEFAULT NULL,
  PRIMARY KEY (`_id`),
  KEY `ProjectJob_0` (`job`,`_job_db`),
  KEY `ProjectJob_1` (`project`,`_project_db`)
) ENGINE=InnoDB AUTO_INCREMENT=407345 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `ProjectMD` (
  `_id` int(11) NOT NULL AUTO_INCREMENT,
  `project` int(11) DEFAULT NULL,
  `_project_db` int(11) DEFAULT NULL,
  `value` mediumtext COLLATE utf8mb4_unicode_ci,
  `tag` varchar(128) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`_id`),
  KEY `ProjectMD_0` (`project`,`_project_db`),
  KEY `ProjectMD_1` (`tag`)
) ENGINE=InnoDB AUTO_INCREMENT=194963 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `UpdateLog` (
  `_id` int(11) NOT NULL AUTO_INCREMENT,
  `comment` varchar(128) DEFAULT NULL,
  `date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `collection` int(11) DEFAULT NULL,
  `_collection_db` int(11) DEFAULT NULL,
  `curator` int(11) DEFAULT NULL,
  `_curator_db` int(11) DEFAULT NULL,
  `type` varchar(128) DEFAULT NULL,
  PRIMARY KEY (`_id`),
  KEY `UpdateLog_0` (`curator`,`_curator_db`),
  KEY `UpdateLog_1` (`collection`,`_collection_db`),
  KEY `UpdateLog_2` (`date`)
) ENGINE=InnoDB AUTO_INCREMENT=2498 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `UploadStatus` (
  `_id` int(11) NOT NULL AUTO_INCREMENT,
  `_ctime` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `user_directory` varchar(32) NOT NULL,
  `upload_directory` varchar(19) DEFAULT NULL,
  `filename` text,
  `status` varchar(64) DEFAULT NULL,
  `partitioned` int(1) DEFAULT NULL,
  PRIMARY KEY (`_id`),
  KEY `user_directory` (`user_directory`),
  KEY `UploadStatus_user_dir` (`user_directory`),
  KEY `UploadStatus_status` (`status`)
) ENGINE=InnoDB AUTO_INCREMENT=13762 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `_metainfo` (
  `_id` int(11) NOT NULL AUTO_INCREMENT,
  `info_name` varchar(255) DEFAULT NULL,
  `info_value` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`_id`),
  KEY `_metainfo_info_name` (`info_name`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `_objects` (
  `_id` int(11) NOT NULL AUTO_INCREMENT,
  `object` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`_id`)
) ENGINE=InnoDB AUTO_INCREMENT=25 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `_references` (
  `_id` int(11) NOT NULL AUTO_INCREMENT,
  `_database` varchar(512) DEFAULT NULL,
  `_backend_type` varchar(255) DEFAULT NULL,
  `_backend_data` varchar(1024) DEFAULT NULL,
  PRIMARY KEY (`_id`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;