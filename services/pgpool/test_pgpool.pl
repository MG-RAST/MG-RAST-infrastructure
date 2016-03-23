#!/usr/bin/perl

use strict;
use warnings;
use DBI;
use Getopt::Long;

my $cdir = "/config/postgresql";
my $host = "";
my $user = "mgrastprod";
my $pswd = "";

GetOptions (
    'cdir=s' => \$cdir,
    'host=s' => \$host,
    'user=s' => \$user,
    'pswd=s' => \$pswd 
);

my $certs = "sslcert=$cdir/postgresql.crt;sslkey=$cdir/postgresql.key";
my $dbname = "mgrast_analysis";

my $dbh = DBI->connect("DBI:Pg:dbname=$dbname;host=$host", $user, $pswd, { RaiseError => 1, AutoCommit => 0, PrintError => 0 }) || die $DBI::errstr;

my @names = $dbh->tables;
sort @names;
foreach (@names) { print $_."\n"; }

$dbh->disconnect;
