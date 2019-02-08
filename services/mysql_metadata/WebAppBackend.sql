/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Backend` (
  `_id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(64) DEFAULT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `Backend_unique_0` (`name`)
) ENGINE=InnoDB AUTO_INCREMENT=435 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Invitation` (
  `_id` int(11) NOT NULL AUTO_INCREMENT,
  `invitation_date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `email` varchar(255) DEFAULT NULL,
  `user_claimed` int(11) DEFAULT NULL,
  `_user_claimed_db` int(11) DEFAULT NULL,
  `user_inviting` int(11) DEFAULT NULL,
  `_user_inviting_db` int(11) DEFAULT NULL,
  `claimed` tinyint(1) DEFAULT NULL,
  `scope` int(11) DEFAULT NULL,
  `_scope_db` int(11) DEFAULT NULL,
  `invitation_string` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`_id`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Organization` (
  `_id` int(11) NOT NULL AUTO_INCREMENT,
  `country` varchar(128) DEFAULT NULL,
  `city` varchar(128) DEFAULT NULL,
  `date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `url` varchar(255) DEFAULT NULL,
  `name` varchar(255) DEFAULT NULL,
  `abbreviation` varchar(255) DEFAULT NULL,
  `scope` int(11) DEFAULT NULL,
  `_scope_db` int(11) DEFAULT NULL,
  `location` varchar(128) DEFAULT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `Organization_unique_0` (`name`)
) ENGINE=InnoDB AUTO_INCREMENT=6624 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `OrganizationUsers` (
  `_id` int(11) NOT NULL AUTO_INCREMENT,
  `user` int(11) DEFAULT NULL,
  `_user_db` int(11) DEFAULT NULL,
  `organization` int(11) DEFAULT NULL,
  `_organization_db` int(11) DEFAULT NULL,
  PRIMARY KEY (`_id`)
) ENGINE=InnoDB AUTO_INCREMENT=36923 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Preferences` (
  `_id` int(11) NOT NULL AUTO_INCREMENT,
  `value` varchar(255) DEFAULT NULL,
  `user` int(11) DEFAULT NULL,
  `_user_db` int(11) DEFAULT NULL,
  `application` int(11) DEFAULT NULL,
  `_application_db` int(11) DEFAULT NULL,
  `name` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`_id`),
  KEY `Preferences_user` (`user`,`_user_db`),
  KEY `Preferences_name` (`name`),
  KEY `Preferences_value` (`value`)
) ENGINE=InnoDB AUTO_INCREMENT=1786443 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Rights` (
  `_id` int(11) NOT NULL AUTO_INCREMENT,
  `granted` tinyint(1) DEFAULT NULL,
  `delegated` tinyint(1) DEFAULT NULL,
  `data_id` varchar(255) DEFAULT NULL,
  `data_type` varchar(255) DEFAULT NULL,
  `application` int(11) DEFAULT NULL,
  `_application_db` int(11) DEFAULT NULL,
  `name` varchar(255) DEFAULT NULL,
  `scope` int(11) DEFAULT NULL,
  `_scope_db` int(11) DEFAULT NULL,
  PRIMARY KEY (`_id`),
  KEY `rights_scope_idx` (`scope`),
  KEY `Rights_data_type` (`data_type`),
  KEY `Rights_data_id` (`data_id`)
) ENGINE=InnoDB AUTO_INCREMENT=4562521 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Scope` (
  `_id` int(11) NOT NULL AUTO_INCREMENT,
  `application` int(11) DEFAULT NULL,
  `_application_db` int(11) DEFAULT NULL,
  `name` varchar(255) DEFAULT NULL,
  `description` text,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `Scope_unique_0` (`name`,`application`)
) ENGINE=InnoDB AUTO_INCREMENT=165536 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Session` (
  `_id` int(11) NOT NULL AUTO_INCREMENT,
  `session_id` varchar(32) DEFAULT NULL,
  `user` int(11) DEFAULT NULL,
  `_user_db` int(11) DEFAULT NULL,
  `creation` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `Session_unique_0` (`session_id`,`user`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `SessionItem` (
  `_id` int(11) NOT NULL AUTO_INCREMENT,
  `parameters` text,
  `page` varchar(255) DEFAULT NULL,
  `timestamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Session_entries` (
  `_id` int(11) NOT NULL AUTO_INCREMENT,
  `_array_index` int(11) DEFAULT NULL,
  `_target_id` int(11) DEFAULT NULL,
  `_source_id` int(11) DEFAULT NULL,
  `_target_db` int(11) DEFAULT NULL,
  PRIMARY KEY (`_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `User` (
  `_id` int(11) NOT NULL AUTO_INCREMENT,
  `firstname` varchar(64) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `email` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `password` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `comment` mediumtext COLLATE utf8mb4_unicode_ci,
  `entry_date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `active` tinyint(1) DEFAULT NULL,
  `lastname` varchar(64) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `login` varchar(64) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `email2` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `User_unique_0` (`login`),
  UNIQUE KEY `User_unique_1` (`email`)
) ENGINE=InnoDB AUTO_INCREMENT=71290 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `UserHasScope` (
  `_id` int(11) NOT NULL AUTO_INCREMENT,
  `user` int(11) DEFAULT NULL,
  `_user_db` int(11) DEFAULT NULL,
  `scope` int(11) DEFAULT NULL,
  `_scope_db` int(11) DEFAULT NULL,
  `granted` tinyint(1) DEFAULT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `UserHasScope_unique_0` (`user`,`scope`)
) ENGINE=InnoDB AUTO_INCREMENT=83299 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `UserSession` (
  `_id` int(11) NOT NULL AUTO_INCREMENT,
  `error_page` varchar(255) DEFAULT NULL,
  `session_id` varchar(32) DEFAULT NULL,
  `error_parameters` text,
  `current_page` varchar(255) DEFAULT NULL,
  `timestamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `previous_page` varchar(255) DEFAULT NULL,
  `user` int(11) DEFAULT NULL,
  `_user_db` int(11) DEFAULT NULL,
  `current_parameters` text,
  `previous_parameters` text,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `UserSession_unique_0` (`session_id`),
  UNIQUE KEY `UserSession_unique_1` (`session_id`,`user`,`_user_db`),
  KEY `sess_key` (`_user_db`,`user`)
) ENGINE=InnoDB AUTO_INCREMENT=139945626 DEFAULT CHARSET=latin1;
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
) ENGINE=InnoDB AUTO_INCREMENT=13 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `_references` (
  `_id` int(11) NOT NULL AUTO_INCREMENT,
  `_database` varchar(512) DEFAULT NULL,
  `_backend_type` varchar(255) DEFAULT NULL,
  `_backend_data` varchar(1024) DEFAULT NULL,
  PRIMARY KEY (`_id`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;
