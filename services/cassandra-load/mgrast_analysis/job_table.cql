
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

CREATE INDEX job_md5s_exp_idx ON job_md5s (exp_avg);
CREATE INDEX job_md5s_ident_idx ON job_md5s (ident_avg);
CREATE INDEX job_md5s_len_idx ON job_md5s (len_avg);

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

CREATE INDEX job_lcas_exp_idx ON job_lcas (exp_avg);
CREATE INDEX job_lcas_ident_idx ON job_lcas (ident_avg);
CREATE INDEX job_lcas_len_idx ON job_lcas (len_avg);

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

CREATE INDEX job_otu_lcas_score_idx ON job_tap (score);
CREATE INDEX job_otu_lcas_otus_idx ON job_tap (otus);
