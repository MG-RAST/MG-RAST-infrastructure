#!/usr/bin/env perl

use strict;
use warnings;
use DBI;

use LWP::UserAgent;
use Log::Log4perl qw(:easy);
use YAML::Tiny;
use Data::Dumper;
use Digest::MD5 qw (md5_hex);
use JSON;
use MongoDB;
use Net::RabbitMQ;

# config
my $c = YAML::Tiny->read('config.yml')->[0];
print Dumper($c);

# rabbit mq
my $mq = Net::RabbitMQ->new();
my $rmq_user = $c->{rabbitmq}->{user} or die "missing rabbitmq config";
my $rmq_password = $c->{rabbitmq}->{password} or die "missing rabbitmq config";

$ENV{TZ} = "America/Chicago";

my $sleep_minutes = 5;
my $useragent_timeout = 30;
my $etcd_host_unhealthy = {};

my $debug = 0;
our $layout = '[%d] [%-5p] %m%n';

if ($debug) {
    Log::Log4perl->easy_init({level => $DEBUG, layout => $layout});
} else {
    Log::Log4perl->easy_init({level => $INFO, layout => $layout});
}
our $logger = Log::Log4perl->get_logger();

########################################################################################

sub logger {
    my ($type, $msg) = @_;
    # replace line breaks
    $msg =~ s/\n/, /g;
    # find logger channel
    if ($type eq 'debug') {
        $logger->debug($msg);
    } elsif ($type eq 'info') {
        $logger->info($msg);
    } elsif ($type eq 'warn') {
        $logger->warn($msg);
    } elsif ($type eq 'error') {
        $logger->error($msg);
    }
}

sub check_url {
    my $info = shift(@_);
    
    my $url = $info->{'url'};
    my $ua = LWP::UserAgent->new;
    $ua->timeout($useragent_timeout);
    
    &logger('info', "checking url $url");
    
    my $response = $ua->get($url);
    if ($response->is_success) {
        return {"success" => 1};
    }
    return {"success" => 0};
}

sub check_mongo {
    my $info = shift(@_);
    
    my $db  = $info->{'db'};
    my $uri = $info->{'host'}.':'.$info->{'port'}.'/'.$db;
    
    &logger('info', "checking mongo $uri");
    
    my $mongo_client = MongoDB::MongoClient->new(
        host => $info->{'host'},
        port => $info->{'port'},
        username => $info->{'user'},
        password => $info->{'pass'},
        db_name => $db
    );
    unless ($mongo_client) {
        &logger('error', "connection failed: $uri");
        return {success => 0, message => "connection failed: $uri"};
    }
    
    my $id = undef;
    eval {
        my $mongo_coll = $mongo_client->get_namespace($db.".".$info->{'name'});
        my $test_doc = $mongo_coll->find_one();
        $id = $test_doc->{'id'};
    };
    unless ($id) {
        &logger('error', "document retrieval failed: $uri");
        return {success => 0, message => "document retrieval failed: $uri"};
    }
    
    return {success => 1};
}

sub check_cassandra {
    my $info = shift(@_);
    
    # get seed info
    my $ua = LWP::UserAgent->new;
    $ua->timeout($useragent_timeout);
    
    my $etcd_seed = $info->{'seed'};
    my $seed_host = undef;
    eval {
        my $response = $ua->get($etcd_seed);
        my $result = decode_json($response->decoded_content);
        $seed_host = $result->{'node'}{'value'};
    };
    
    unless ($seed_host) {
        &logger('error', "failed accessing etcd ($etcd_seed) for seed host info");
        return {success => 0, message => "failed accessing etcd ($etcd_seed) for seed host info"};
    }
    
    # get test data
    my $test_md5 = $info->{'test-md5'};
    my $keyspace = $info->{'keyspace'};
    
    my $dbh = DBI->connect("dbi:Cassandra:host=$seed_host;keyspace=$keyspace", "", "", { RaiseError => 1 });
    my $test_data = $dbh->selectall_arrayref("SELECT * FROM md5_annotation WHERE md5=".$dbh->quote($test_md5));
    
    unless ($test_data && (scalar(@$test_data) > 0)) {
        &logger('error', "data retrieval failed, host=$seed_host, keyspace=$keyspace");
        return {success => 0, message => "data retrieval failed, host=$seed_host, keyspace=$keyspace"};
    }
    
    return {success => 1};
}

sub check_mysql {
    my $info = shift(@_);
    
    my $db   = $info->{'db'};
    my $host = $info->{'host'};
    my $user = $info->{'user'};
    my $pass = $info->{'password'};
    
    &logger('info', "checking mysql $host/$db");
    
    my $dbh  = DBI->connect(
        "DBI:mysql:database=".$db.";host=".$host.";",
        $user,
        $pass
    ) or return {success => 0, message => "$host/$db - ".$DBI::errstr};
    
    if ($dbh) {
        return {success => 1};
    }
    &logger('error', "$host/$db - unable to connect");
    return {success => 0, message => "$host/$db - unable to connect"};
}

sub check_etcdcluster {
    my $info = shift(@_);
    
    my $ua = LWP::UserAgent->new;
    $ua->timeout($info->{'timeout'});
    
    # get member list
    my $url = "http://".$info->{'host'}.":2379/v2/members";
    
    &logger('info', "checking etcd members at $url");
    
    my $e = undef;
    my $result = undef;
    eval {
        my $response = $ua->get($url);
        $result = decode_json($response->decoded_content);
        1;
    } or do {
        $e = $@;
        &logger('error', "connection error ".$e);
        return {success => 0, message => "Could not get list of members"};
    };
    
    unless ($result->{"members"} && (scalar(@{$result->{"members"}}) > 0)) {
        &logger('error', "member list empty");
        return {success => 0, message => "member list is empty"};
    }
    my $clust_size = @{$result->{"members"}};
    
    # check members health
    my $total_unhealthy = 0;
    
    foreach my $member (@{$result->{"members"}}) {
        my $host = $member->{'clientURLs'}[0];
        $url = "$host/health";
        
        # populate host map
        unless (exists $etcd_host_unhealthy->{$host}) {
            $etcd_host_unhealthy->{$host} = 0;
        }
        
        $result = undef;
        eval {
            my $response = $ua->get($url);
            $result = decode_json($response->decoded_content);
        };
        
        unless ($result && exists($result->{"health"}) && ($result->{"health"} eq "true")) {
            $etcd_host_unhealthy->{$host} += 1;
            $total_unhealthy += 1;
            next;
        }
        $etcd_host_unhealthy->{$host} = 0; # this host is healthy
    }
    
    if ($total_unhealthy > $info->{'max-hosts-unhealthy'}) {
        &logger('error', "$total_unhealthy out of $clust_size cluster members unhealthy");
        return {success => 0, message => "$total_unhealthy out of $clust_size cluster members unhealthy"};
    }
    foreach my $host (keys %$etcd_host_unhealthy) {
        if ($etcd_host_unhealthy->{$host} > $info->{'max-times-unhealthy'}) {
            &logger('error', "member $host has been unhealthy ".$etcd_host_unhealthy->{$host}." checks in a row");
            return {success => 0, message => "member $host has been unhealthy ".$etcd_host_unhealthy->{$host}." checks in a row"};
        }
    }

    return {success => 1, message => "cluster size: $clust_size"};
}

sub check_apiserver {
    my $info = shift(@_);
    
    my $image = $info->{'image'};
    my $testcmd = $info->{'test-cmd'};
    
    # build command
    my @cmds = ();
    if ($info->{"get-list"} && $info->{'host'}) {
        push @cmds, './'.$info->{"get-list"}.' '.$info->{'host'}.' > API.server.list';
    }
    if ($info->{'test-file'}) {
        push @cmds, "$testcmd > /dev/null 2>&1";
        push @cmds, "cat ".$info->{'test-file'};
    } else {
        push @cmds, $testcmd;
    }
    
    my $docker_cmd = "docker run --rm --name api-test $image bash -c '".join("; ", @cmds)."'";
    &logger('info', "API test: $docker_cmd");
    
    my $e = undef
    my $result = undef;
    eval {
        my $report = `$docker_cmd`;
        $result = decode_json($report);
        1;
    } or do {
        $e = $@;
        &logger('error', "error running API test: ".$e);
        return {success => 0, message => "error running API test: ".$e};
    };
    
    unless ($result->{"report"} && $result->{"report"}{"summary"} && $result->{"report"}{"tests"} && (scalar(@{$result->{"report"}{"tests"}}) > 0)) {
        &logger('error', "unknown error, tests did not run");
        return {success => 0, message => "unknown error, tests did not run"};
    }
    
    if ($result->{"report"}{"summary"}{"failed"} > 0) {
        my $msg = $result->{"report"}{"summary"}{"failed"}." of ".$result->{"report"}{"summary"}{"num_tests"}." tests failed";
        &logger('error', $msg);
        my @errors = ();
        foreach my $test (@{$result->{"report"}{"tests"}}) {
            if ($test->{"outcome"} eq "failed") {
                &logger('error', "failed: ".$test->{"name"});
                push @errors, $test->{"name"};
            }
        }
        return {success => 0, message => $msg."\n\t".join("\n\t", @errors)};
    }
    
    return {success => 1};
}

sub check_aweserver {
    my $info = shift(@_);
    
    my $url = $info->{'url'};
    my $auth_bearer = $info->{'authorization'}->{'bearer'};
    my $auth_token = $info->{'authorization'}->{'token'};
    
    my $ua = LWP::UserAgent->new;
    $ua->timeout($useragent_timeout);
    $ua->default_header('Authorization' => $auth_bearer . ' ' . $auth_token);
    
    &logger('info', "checking AWE at $url");

    my $e = undef;
    my $result = undef;
    eval {
        my $response = $ua->get($url);
        $result = decode_json($response->decoded_content);
        1;
    } or do {
        $e = $@;
        &logger('error', "connection error: ".$e);
        return {success => 0, message => "connection error: ".$e};
    };

    if ($result->{"error"}) {
        &logger('error', "error in response: ".$result->{"error"}[0]);
        return {success => 0, message => "error in response: ".$result->{"error"}[0]};
    }

    unless ($result->{"data"} && (scalar(@{$result->{"data"}}) > 0)) {
        &logger('error', "awe client list is empty");
        return {success => 0, message => "awe client list is empty"};
    }
    
    return {success => 1 , message => scalar(@{$result->{"data"}})." clients connected"};
}

sub check_shockserver {
    my $info = shift(@_);
    
    my $url = $info->{'url'}."/node/".$info->{'node'};
    
    my $ua = LWP::UserAgent->new;
    $ua->timeout($useragent_timeout);
    
    &logger('info', "checking Shock at $url");
    
    # get node
    my $e = undef;
    my $result = undef;
    eval {
        my $response = $ua->get($url);
        $result = decode_json($response->decoded_content);
        1;
    } or do {
        $e = $@;
        &logger('error', "connection error: ".$e);
        return {success => 0, message => "connection error: ".$e};
    };
    
    if ($result->{"error"}) {
        &logger('error', "error in response: ".$result->{"error"}[0]);
        return {success => 0, message => "error in response: ".$result->{"error"}[0]};
    }
    
    unless ($result->{"data"} && $result->{"data"}{"id"}) {
        &logger('error', "node is missing");
        return {success => 0, message => "node is missing"};
    }
    my $md5sum = $result->{"data"}{"file"}{"checksum"}{"md5"};
    
    # get download
    $e = undef;
    $result = undef;
    eval {
        my $response = $ua->get($url.'?download');
        $result = $response->content;
        1;
    } or do {
        $e = $@;
        &logger('error', "connection error: ".$e);
        return {success => 0, message => "connection error: ".$e};
    };
    
    unless ($result && (md5_hex($result) eq $md5sum)) {
        &logger('error', "test md5sum does not match");
        return {success => 0, message => "test md5sum does not match"};
    }
    
    return {success => 1};
}

sub test_service {
     my ($test) = @_;

     my $service_name = $test->{'name'};
     my $function = $test->{'function'};
     my $result = &$function($test->{'arg'});
     
     if (defined $result->{'ignore'} && $result->{'ignore'} == 1) {
         &logger('warn', "Do not report test result, ignore flag was set");
         return;
     }
     
     $result->{'event_type'} = 'service_test';
     $result->{'service'} = $service_name;
     $result->{'time'} = DateTime->now()->iso8601().'Z';
     
     my $result_json = to_json($result, {utf8 => 1});
     my $connection_result = eval { 
         $mq->connect("rabbitmq", { user => $rmq_user, password => $rmq_password });
     };
     
     if ($connection_result) {
         $mq->channel_open(1);
         $mq->publish(1, "event_service_test", $result_json);
         $mq->disconnect();
     } else {
         &logger('error', "Could not connect to rabbitmq.\n");
         &logger('info', "test result: $result_json\n");
     }
}

########################################################################################

## tests that use functions
my $tests = [
            {   name => 'mongo-awe',
                function => \&check_mongo,
                arg => $c->{'mongo-awe'}
            },
            {   name => 'mongo-shock',
                function => \&check_mongo,
                arg => $c->{'mongo-shock'}
            },
            {   name => "mysql-metadata",
                function => \&check_mysql,
                arg => $c->{'mysql-metadata'}
            },
            {   name => "cassandra-cluster",
                function => \&check_cassandra,
                arg => $c->{'cassandra-cluster'}
            },
            {   name => "etcd-cluster",
                function => \&check_etcdcluster,
                arg => $c->{'etcd-cluster'}
            },
            {   name => "api-server",
                function => \&check_apiserver,
                arg => $c->{'api-server'}
            },
            {   name => "awe-server",
                function => \&check_aweserver,
                arg => $c->{'awe-server'}
            },
            {   name => "shock-server",
                function => \&check_shockserver,
                arg => $c->{'shock-server'}
            }
];

## add tests that have urls
my $urls = $c->{'urls'};
foreach my $resource (@$urls) {
    my $new_test = {};
    $new_test->{'name'} = $resource->{'name'};
    $new_test->{'function'} = \&check_url;
    $new_test->{'isUrl'} = 1;
    $new_test->{'arg'} = {
        'url' => $resource->{'url'},
        'default-run' => $resource->{'default-run'}
    };
    push(@{$tests}, $new_test)
}

# do argument command than exit
my $usage = qq(
usage: service-checker.pl <argument>
arguments: list | test_all | test_all_continues | test <service> | test_continues <service>
note: test_all and test_all_continues only runs tests with config field 'default-run' as true
      to run a test with 'default-run' as false, use 'test <service>' or 'test_continues <service>'
);

if (@ARGV > 0) {
    my $command = $ARGV[0];
        
    if ($command eq "list") {
        foreach my $test (@{$tests}) {
            if (defined $test->{'isUrl'}) {
                print("[URL]      ".$test->{'name'}."\n");
            } else {
                print("[FUNCTION] ".$test->{'name'}."\n");
            }
        } 
    }
    elsif ($command eq "test_all") {
        foreach my $test (@{$tests}) {
            # only run those with default true
            if ($test->{'arg'}->{'default-run'}) {
                test_service($test);
            }
        }
    }
    elsif ($command eq "test_all_continues") {
        while (1) {
            foreach my $test (@{$tests}) {
                # only run those with default true
                if ($test->{'arg'}->{'default-run'}) {
                    test_service($test);
                }
            }
            my $seconds = $sleep_minutes * 60;
            logger('info', "sleeping ".$seconds." seconds");
            sleep($seconds);
        }
    }
    elsif ($command eq "test") {
        my $service = $ARGV[1] || die "service name missing";
        foreach my $test (@{$tests}) {
            if ($test->{'name'} eq $service) {
                test_service($test);
                exit(0);
            }
        }
        die "service $service not found";
    }
    elsif ($command eq "test_continues") {
        my $service = $ARGV[1] || die "service name missing";
        foreach my $test (@{$tests}) {
            if ($test->{'name'} eq $service) {
                while (1) {
                    test_service($test);
                    my $seconds = $sleep_minutes * 60;
                    # override default sleep
                    if ($test->{'arg'}->{'sleep-mins'} && ($test->{'arg'}->{'sleep-mins'} > 0)) {
                        $seconds = $test->{'arg'}->{'sleep-mins'} * 60;
                    }
                    logger('info', "sleeping ".$seconds." seconds");
                    sleep($seconds);
                }
            }
        }
        die "service $service not found";
    }
    else {
        die "arguemnt $command not found\n$usage";
    }
    exit(0);
}

print $usage;
exit(0);
