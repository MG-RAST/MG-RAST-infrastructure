
CREATE KEYSPACE IF NOT EXISTS mgrast_abundance
    WITH REPLICATION = { 'class' : 'SimpleStrategy', 'replication_factor' : 3 };

use mgrast_abundance;

CREATE TABLE IF NOT EXISTS job_info (
    version int,
    job int,
    updated_on timestamp,
    md5s int,
    lcas int,
    loaded boolean,
    PRIMARY KEY ((version, job))
);

CREATE TABLE IF NOT EXISTS job_md5s (
    version int,
    job int,
    md5 text,
    abundance int,
    exp_avg float,
    ident_avg float,
    len_avg float,
    seek bigint,
    length int,
    PRIMARY KEY ((version, job), md5)
);


-- ############################################################################
-- WARNING - DO NOT RE-ENABLE THE CREATE INDEX STATEMENTS BELOW
--
-- These six secondary indexes were measured (2026-09-26) at 27.38 TiB on disk,
-- 69% of the entire cluster, and are NEVER consulted by any consumer:
--   * every API query on job_md5s is partition-key restricted
--     (WHERE version=? AND job=?), and where it filters on one of these columns
--     it uses a RANGE plus ALLOW FILTERING;
--   * a standard Cassandra secondary index serves EQUALITY only, so Cassandra
--     reports "No applicable indexes found" for every one of those queries;
--   * they additionally FORBID `job IN (...) AND <col> = x`, which Cassandra
--     rejects outright while an index exists on <col>.
--
-- These statements have no IF NOT EXISTS. Today re-running this file errors
-- harmlessly ("index already exists"). ONCE THE INDEXES ARE DROPPED, re-running
-- it would SUCCEED and silently start a multi-day, cluster-wide 27 TiB index
-- rebuild on all 14 nodes - non-resumable, and with compaction throughput at
-- 16 MB/s and concurrent_compactors resolving to 2. README.md still instructs
-- operators to curl this file and `cqlsh -f job_table.cql`.
--
-- See docs/cassandra-4.0-upgrade-findings.md before changing anything here.
-- ############################################################################

-- CREATE INDEX job_md5s_exp_idx ON job_md5s (exp_avg);
-- CREATE INDEX job_md5s_ident_idx ON job_md5s (ident_avg);
-- CREATE INDEX job_md5s_len_idx ON job_md5s (len_avg);

CREATE TABLE IF NOT EXISTS job_lcas (
    version int,
    job int,
    lca text,
    abundance int,
    exp_avg float,
    ident_avg float,
    len_avg float,
    md5s int,
    level int,
    PRIMARY KEY ((version, job), lca)
);

-- Disabled for the same reason as the job_md5s indexes above.
-- CREATE INDEX job_lcas_exp_idx ON job_lcas (exp_avg);
-- CREATE INDEX job_lcas_ident_idx ON job_lcas (ident_avg);
-- CREATE INDEX job_lcas_len_idx ON job_lcas (len_avg);

CREATE TABLE IF NOT EXISTS job_otu_lcas (
    source text,
    job int,
    lca text,
    abundance int,
    score float,
    otus int,
    level int,
    PRIMARY KEY ((source, job), lca)
);

-- NOTE: these two reference table `job_tap`, which this file never creates - so
-- this DDL has never been run end-to-end as written. Do not treat this file as a
-- record of what production actually has; check system_schema.indexes instead.
-- CREATE INDEX job_otu_lcas_score_idx ON job_tap (score);
-- CREATE INDEX job_otu_lcas_otus_idx ON job_tap (otus);
