#!/usr/bin/env perl

use strict;
use warnings;
use DBI;

use LWP::UserAgent;
use Log::Log4perl qw(:easy);
use POSIX qw(strftime);
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
        return {"success" => 1}
    }
    return {"success" => 0}
}

sub check_mongo {
    my $info = shift(@_);
    
    foreach my $database (keys %$info) {
        my $obj = $services->{$database};
        my $uri = $obj->{'host'}.':'.$obj->{'port'}.'/'.$database;
        
        &logger('info', "checking mongo $uri");
        
        my $mongo_client = MongoDB::MongoClient->new(
            host => $obj->{'host'},
            port => $obj->{'port'},
            username => $obj->{'user'},
            password => $obj->{'pass'},
            db_name => $database
        );
        unless ($mongo_client) {
            &logger('error', "connection failed: $uri");
            return {success => 0, message => "connection failed: $uri";
        }
        
        my $id = undef;
        eval {
            my $mongo_coll = $mongo_client->get_namespace($database.".".$obj->{'name'});
            my $test_doc = $mongo_coll->find_one();
            my $id = $test_doc->{'id'};
        }
        unless ($id) {
            &logger('error', "document retrieval failed: $uri");
            return {success => 0, message => "document retrieval failed: $uri"};
        }
    }
    return {success => 1};
}

sub check_cassandra_depreacted {
    
    # TODO: use curl localhost:2379/v2/keys/services/cassandra-seed/
    # proxy.metagenomics.anl.gov:2379/v2/keys/services/cassandra-seed/cassandra-seed@1
    # docker pull cassandra:3.7
    # docker exec cassandra /usr/bin/nodetool status m5nr_v<version #> eg. m5nr_v1
    # docker run -ti --rm --name cassandra-nodetool cassandra:3.7 /usr/bin/nodetool --host <> --port 7199 status # Connection refused
    
    # need to test a query as handle can still be made but cluster in bad state
    # test md5 is 74428bf03d3c75c944ea0b2eb632701f / E. coli alcohol dehydrogenase / m5nr version 1
    my $test_md5_id = '74428bf03d3c75c944ea0b2eb632701f';
    my $test_data = [];
    my $host = "";

    for (my $i=1; $i<=20; $i++) {
        eval {
            $host = "bio-worker".$i.".mcs.anl.gov";
            my $chdl = DBI->connect("dbi:Cassandra:host=".$host.";keyspace=m5nr_v1", "", "");
            $test_data = $chdl->selectall_arrayref("SELECT * FROM id_annotation WHERE id=".$test_md5_id);
        };
        if (@$test_data > 0) {
            last;
        }
    }
    if (@$test_data == 0) {
        #$failed{"M5NR database (cassandra)"} = $host;
        return {success => 0, message => "failed: $host"};
    }
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
        return {success => 1}
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
    foreach my $member (@{$result->{"members"}}) {
        my $host = $member->{'clientURLs'}[0];
        $url = "$host/health";
        
        $e = undef;
        $result = undef;
        eval {
            my $response = $ua->get($url);
            $result = decode_json($response->decoded_content);
            1;
        } or do {
            $e = $@;
            &logger('error', "connection error ".$e);
            return {success => 0, message => "Could not check health of member $host";
        };
        
        unless ($result->{"health"} && ($result->{"health"} eq "true")) {
            &logger('error', "Member $host is not healthy");
            return {success => 0, message => "Member $host is not healthy"};
        }
    }

    return {success => 1, message => "cluster size: $clust_size"};
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
    
    my $url = $info->{'url'};
    my $node = $info->{'node'};
    my $url = "$url/node/$node";
    
    my $ua = LWP::UserAgent->new;
    $ua->timeout($useragent_timeout);
    
    &logger('info', "checking Shock at $test_url");
    
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
        my $response = $ua->get($url);
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
        return {success => 0, message => "error running API test: ".$e);
    }
    
    unless ($result->{"tests"} && (scalar(@{$result->{"tests"}}) > 0)) {
        &logger('error', "unknown error, tests did not run");
        return {success => 0, message => "unknown error, tests did not run");
    }
    
    foreach my $test (@{$result->{"tests"}}) {
        if ($test->{"call"}{"outcome"} ne "passed") {
            my $msg = $test->{"call"}{"longrepr"} || $test->{"call"}{"stderr"} || $test->{"call"}{"stdout"};
            &logger('error', "test ".$test->{"name"}." failed: $msg");
            return {success => 0, message => "test ".$test->{"name"}." failed: $msg");
        }
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
     $result->{'time'} = strftime("%Y-%m-%dT%H:%M:%S", gmtime);
     
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
            {   name => "mysql",
                function => \&check_mysql,
                arg => $c->{'mysql'}
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
            if ($test->{'default-run'}) {
                test_service($test);
            }
        }
    }
    elsif ($command eq "test_all_continues") {
        while (1) {
            foreach my $test (@{$tests}) {
                # only run those with default true
                if ($test->{'default-run'}) {
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
                    if ($test->{'sleep-mins'} && ($test->{'sleep-mins'} > 0)) {
                        $seconds = $test->{'sleep-mins'} * 60;
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
