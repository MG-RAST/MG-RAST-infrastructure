#!/usr/bin/env perl

use strict;
use warnings;
use DBI;

use LWP::UserAgent;
use POSIX qw(tzset); 
use Log::Log4perl qw(:easy);
use Net::SMTP;
use YAML::Tiny;
use Data::Dumper;
use POSIX qw(strftime);
use File::Slurp;
use JSON;


use Net::RabbitMQ;
my $mq = Net::RabbitMQ->new();

# config
my $c = YAML::Tiny->read( 'config.yml' )->[0];
print Dumper($c);
  
my $do_send_mail = 0;


my $rmq=$c->{rabbitmq} or die;
my $rmq_user=$rmq->{user} or die;
my $rmq_password=$rmq->{password} or die;

$ENV{TZ} = "America/Chicago";


my $debug = 0;
our $layout = '[%d] [%-5p] %m%n';



# other gloabl variables


my $status={};


my $failures = 0;
my $all_ok = 5;
my $sleep_minutes = 2;

########################################################################################

if ($debug) {
    Log::Log4perl->easy_init({level => $DEBUG, layout => $layout});
} else {
    Log::Log4perl->easy_init({level => $INFO, layout => $layout});
}
our $logger = Log::Log4perl->get_logger();



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


sub send_mail {
    my ($cfg, $body, $subject) = @_;
    
    
    my $email_server = $cfg->{'server'};
    my $email_to = $cfg->{'to'};
    my $email_from = $cfg->{'from'};
    
    my $smtp = Net::SMTP->new($email_server, Hello => $email_server);
    
    
    #$smtp->mail('mg-rast');
    my @data = (
        "To: $email_to\n",
        "From: $email_from\n",
        "Date: ".strftime("%a, %d %b %Y %H:%M:%S %z", localtime)."\n",
        "Subject: $subject\n\n",
        $body
    );
    
    $smtp->mail('wilke');
    if ($smtp->to($email_to)) {
        logger('debug', "sending mail now.");
        $smtp->data(@data);
    } else {
        logger('error', $smtp->message());
    }
    $smtp->quit;

}


sub check_url {
     my ($url) = @_;
     $logger->info("checking url ".$url);
    
     my $ua = LWP::UserAgent->new;
     $ua->timeout(10);
     
      my $response = $ua->get($url);
     
     if ($response->is_success) {
         return {"success" => 1}
     }
     return {"error" => 1}
}



sub check_urls_deprecated {
    my $urls = shift(@_);
    
    foreach my $resource (keys %{$urls}) {
        my $url = $urls->{$resource};
        
        my $result = check_url($url);
        
        
        $status->{$resource}->{'success'}= $result;
        unless ($result) {
            $status->{$resource}->{'report'} = "url failed: ".$url;
        }
    }
}


sub check_mongo {
    require MongoDB;
    
    my $services = shift(@_);
    my $success = 1;
    my $message = undef;
    foreach my $database (keys %{$services}) {
        my $obj = $services->{$database};
        my $mongo_client = MongoDB::MongoClient->new(host => $obj->{'host'}, port => $obj->{'port'});
        
        my $service = "MongoDB/".$database;
        unless ($mongo_client) {
            #TODO connect to database ? my $db = $mongo_client->get_database("test");
           
            $success = 0;
            unless (defined $message) {
                $message = ""
            }
            
            $message .= "failed: ".$obj->{'host'}.':'.$obj->{'port'};
        }
    }
    
    if ($success) {
        return {success => 1}
    }
    return {error => 1, message => $message}
    
   
}


sub check_cassandra_depreacted {
    
    # TODO: use curl localhost:2379/v2/keys/services/cassandra-seed/
    # proxy.metagenomics.anl.gov:2379/v2/keys/services/cassandra-seed/cassandra-seed@1
    # docker pull cassandra:3.7
    # docker exec cassandra /usr/bin/nodetool status m5nr_v<version #> eg. m5nr_v1
    # docker run -ti --rm --name cassandra-nodetool cassandra:3.7 /usr/bin/nodetool --host <> --port 7199 status # Connection refused
    
    # need to test a query as handle can still be made but cluster in bad state
    # test md5 is 74428bf03d3c75c944ea0b2eb632701f / E. coli alcohol dehydrogenase / m5nr version 1
    my $test_md5_id = 10795366;
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
        $status->{"M5NR database (cassandra)"}->{'report'} = "failed: $host";
    }
}


sub check_mysql {
    my $jc = shift(@_);
    
    my $jobcache_db = $jc->{'db'};
    my $jobcache_host = $jc->{'host'};
    my $jobcache_user = $jc->{'user'};
    my $jobcache_password = $jc->{'password'};
    my $dbh = DBI->connect("DBI:mysql:database=".$jobcache_db.";host=".$jobcache_host.";",
           $jobcache_user,
           $jobcache_password)or return {error => 1, message => $jobcache_host." ".$DBI::errstr} ;
    my $service = "MySQL/".$jobcache_db;
    
    if ($dbh) {
        #$status->{$service}->{'success'}=1;
        return {success => 1}
    } 
    return {error => 1, message => $jobcache_host};
    
    
}


sub check_etcdcluster {
    
    my $resource = "etcdcluster";
    my $ua = LWP::UserAgent->new;
    $ua->timeout(10);
    
    # http://metagenomics.anl.gov:2379/health
    
    
    #my $url = "http://metagenomics.anl.gov:2379/v2/members";
    my $url = "http://metagenomics.anl.gov:2379/health";
    
    $logger->info("checking url ".$url);
    my $response = $ua->get($url);
    
    unless ($response->is_success) {
        # TODO fix etcd. This error will be ignored for now.
        #$status->{$resource}->{'success'}=0;
        #$failed{$resource} = "Could not check cluster health (1)";
        return;
    }
    
    my $e = undef;
    my $result = undef;
    eval {
     $result = decode_json($response->decoded_content);
      $logger->info($response->decoded_content);
        1;
    } or do {
        $e = $@;
        $logger->info("json error ".$e);
        #$status->{$resource}->{'success'}=0;
       
        #$status->{$resource}->{'report'} = "Could not check cluster health (2)";
        return {error => 1 , message => "Could not check cluster health (json error) "};
        #return;
    };
    
    unless (defined $result->{"health"}) {
        $logger->info("health field null");
        return {error => 1 , message => "Key health not found"};
    }
    
    unless ($result->{"health"} eq "true") {
        $logger->info("Cluster is not healthy !");

        return {error => 1 , message => "Cluster is not healthy !"};
        
    }
    
    #$status->{$resource}->{'success'}=1;
    
    # some info
    $url = "http://metagenomics.anl.gov:2379/v2/members";
    $response = $ua->get($url);
    unless ($response->is_success) {
        return {error => 1 , message => "Could not get list of members"};
    }
    
    
    $e = undef;
    $result = undef;
    eval {
     $result = decode_json($response->decoded_content);
      $logger->info($response->decoded_content);
        1;
    } or do {
        $e = $@;
        $logger->info("json error ".$e);
        return {error => 1 , message => "Could not get list of members (json error)"};
    };
    
    if (defined $result->{"members"}) {
        return {success => 1 , message => "Etcd cluster size: ".@{$result->{"members"}}};
    }
    return {error => 1 , message => "List of member empty"};
}


sub check_aweserver {
    
    my $cfg = shift(@_);
    
    
    my $resource = 'awe-server';
    my $url = $cfg->{'url'};
    my $auth_bearer = $cfg->{'authorization'}->{'bearer'};
    my $auth_token = $cfg->{'authorization'}->{'token'};
    
    
    #'http://awe.metagenomics.anl.gov/client';

    my $ua = LWP::UserAgent->new;
    $ua->timeout(10);
    $ua->default_header('Authorization' => $auth_bearer . ' ' . $auth_token);
    
    $logger->info("checking url ".$url);
    my $response = $ua->get($url);


    unless ($response->is_success) {
        
        return {error => 1 , message => $url. " ". ($response->message || "")};
        
    }

    my $e = undef;
    my $result = undef;
    eval {
     $result = decode_json($response->decoded_content);
      $logger->info($response->decoded_content);
        1;
    } or do {
        $e = $@;
        $logger->info("awe json error ".$e);
        
        return {error => 1 , message => "json error: ".$url};
       
    };

    if (defined $result->{"error"}) {
        $logger->info("awe error field non-null");
        
        return {error => 1 , message => "error in response: ".$url};
     
    }

    unless (defined $result->{"data"}) {
        $logger->info("awe data field null");
        
        return {error => 1 , message => "data field not defined: ".$url};
      
    }
    
    my $num_clients = @{$result->{"data"}};
    
    unless ($num_clients ) {
        $logger->info("awe data field null");
     
        return {error => 1 , message => "data field empty: ".$url};
     
    }
    
   
     return {success => 1 , message =>"$num_clients clients connected"};
}


sub check_apiserver {
    
    
    my $text = read_file( '/host_tmp/api_test.json' ) ;

   
    my $resource = "api-server";
    my $tests_total = 0;
    my $tests_failed = 0;
    
   
    my $api_testing_hash =undef;
    eval {
        $api_testing_hash = decode_json($text);
        1;
    } or do {
        my $e = $@;
        $logger->info($e);
        
        return {error => 1 , message => "Could not parse json: ".$e};
      
        };
    
    my $test_time = $api_testing_hash->{"epoch_utc_start"};
    
    
    my $current_time = time();
    
    my $time_diff = $current_time - $test_time;
    my $time_diff_minutes = $time_diff/60;
    if ($time_diff_minutes > 60) { # 60 minutes
       
         return {error => 1 , message => "last test too long ago ($time_diff_minutes minutes)"};
         
    }
    
    
    foreach my $test_key (keys %{$api_testing_hash->{"tests"}}) {
        my $test_obj = $api_testing_hash->{"tests"}->{$test_key};
        $tests_total += 1 ;
        
        if ( $test_obj->{"status"} == JSON::false ) {
            $tests_failed +=1 ;
        }
        
    }
    
    if ( $tests_failed > 0 ) {
        # $failed{"api-server"} = 
      
      return {error => 1 , message => $tests_failed ." of ".$tests_total." tests failed"};
    }
     
    
    
    $logger->info("API tests: ".$tests_failed ." of ".$tests_total." tests failed");
    return { success => 1, message => "$tests_total tests successful"};
}

sub do_report {
    
    my ($count_failed, $cfg) = @_;
    
   
    
    if ($count_failed == 0) {
        $logger->info("No resources failed to respond");
    } else {
    
        my $time = localtime();
        my $message = '';
        
        
        
        if ($count_failed == 1) {
            $message .= "One service failed:\n\n";
        } else {
            $message .= $count_failed." services failed:\n\n";
        }
        #foreach my $res (keys %failed) {
        #    $message .= "$res at $failed{$res}\n";
        #}
        foreach my $service (sort keys %$status) {
            my $success = $status->{$service}->{'success'};
            my $report = $status->{$service}->{'report'} || "";
            if ($success == 0) {
                $message .= "$service : $report\n";
            }
        }
        
        $message .= "\nfailures: $failures\n\nOverview: http://log.metagenomics.anl.gov/\n($time)\n\n";
    
        #print "message:\n".$message;
    
        if ($do_send_mail == 1) {
            send_mail($cfg, $message, '[MG-RAST-STATUS-UPDATE] Failed to access a resource');
        }
    
    }
    
}


sub check_all_resources_deprecated {
    
    $status={};
    
    # Check that urls are working
    check_urls($c->{'urls'});
    
    
    # check etcd cluster
    check_etcdcluster();
    
    ### Shock MongoDB anf AWE MongoDB
    check_mongo($c->{'mongo'});
    
    
    ### Cassandra
    #check_cassandra();
    
    ### postgres
    #check_postgress($c->{'postgres'});
    
    ### MySQL/JobDB
    check_mysql($c->{'jobcache'});
    
    
    ### check AWE
    check_aweserver($c->{'awe-server'});
    
    ### check API server
    #check_apiserver();
    
   
    my $count_failed=0;
    foreach my $service (sort keys %$status) {
        my $success = $status->{$service}->{'success'};
        unless (defined $success) {
            $success = 0;
        }
        if ($success == 0) {
            $count_failed++;
        }
    }
    
    return $count_failed;
}


sub test_service {
     my ($test) = @_;
    
    
     my $service_name = $test->{'name'};
     print("service name: ".$service_name."\n");
     
     my $function =  $test->{'function'};
     
     my $result = &$function($test->{'arg'});
     
     $result->{'event_type'} = 'service_test';
     $result->{'service'} = $service_name;
     $result->{'time'} = DateTime->now()->iso8601().'Z';
    
    
     my $result_json_pretty = to_json($result, {utf8 => 1, pretty => 1});
     print($result_json_pretty."\n");
     
     
     my $result_json = to_json($result, {utf8 => 1});
     
     my $connection_result = eval { 
     $mq->connect("rabbitmq", { user => $rmq_user, password => $rmq_password });
     };
     if ($connection_result) {
         $mq->channel_open(1);
         $mq->publish(1, "event_service_test", $result_json);
         $mq->disconnect();
     } else {
         print("Could not connect to rabbitmq.\n");
     }
    
     
}

########################################################################################






my $tests = [  
            {   name => 'mongo',
                function => \&check_mongo
            },
           
            {   name => "mysql",
                function => \&check_mysql,
                arg => $c->{'jobcache'}
            },
            {   name => "etcdcluster",
                function => \&check_etcdcluster
                
            },
           # {   name => "",
        #     function => \&check_apiserver  
         #   },
            {   name => "awe-server",
             function => \&check_aweserver,
             arg => $c->{'awe-server'}
            }
           
];



my $urls = $c->{'urls'};
foreach my $resource (keys %{$urls}) {
    my $url = $urls->{$resource};
    
    my $new_test = {};
        
    $new_test->{'name'}=$resource;
    $new_test->{'function'}=\&check_url;
    $new_test->{'url'}=1;
    $new_test->{'arg'}=$url;
    
    push(@{$tests}, $new_test)

}


# work-around
#foreach my $file ($c->{'postgres'}->{'sslkey'}, $c->{'postgres'}->{'sslcert'}) {
#    print("chmod 600 $file");
#    chmod(0600, $file);
#}



# The $failures counter decides how often emails are sent out. With more failures, less often email are send out.
# 5 successful tests will reset the failure counter.



if (@ARGV > 0) {
    
    my $service = $ARGV[0];
    #print($service);
    
    
    if ($service eq "list") {
        
        foreach my $test (@{$tests}) {
            if (defined $test->{'url'}) {
                print("[URL]      ".$test->{'name'}."\n");
            } else {
                print("[FUNCTION] ".$test->{'name'}."\n");
            }
        } 
        
        exit(0);
    }
    if ($service eq "test_all") {
        foreach my $test (@{$tests}) {
            test_service($test);
        }
        exit(0);
    }
    if ($service eq "test_all_continues") {
        while (1) {
            foreach my $test (@{$tests}) {
                test_service($test);
            }
            my $seconds = $sleep_minutes * 60;
            logger('info', "sleeping ".$seconds." seconds");
            sleep($seconds);
        }
        exit(0);
    }
    
    if ($service eq "test") {
        $service = $ARGV[1] || die "service missing";
        foreach my $test (@{$tests}) {
        
            if ($test->{'name'} eq $service) {
                test_service($test);
                exit(0);
            }
        }
        die("test not found");
    }
    
    exit(0);
}


print("count:".@ARGV ."\n");
print ("arguments: list | test_all | test_all_continues | test <service> \n");

exit(0);





while (1) {
    my $count_failed = check_all_resources();

    ### Report
    if ($count_failed > 0) {
        $failures+=1;
        logger('info', "failures: ".$failures);
        $all_ok = 0;
    } else {
        $all_ok += 1;
        if ($all_ok >= 5) {
            # reset failure counter now.
            $failures = 0;
            
            if ($all_ok == 5) {
                my $message = "No failures reported.\n\n";
                
                send_mail($c->{'email'}, $message, '[MG-RAST-STATUS-UPDATE] All resources active');
            }
            
        }
    }
    
    if ($count_failed > 0) {
        
        
        if ( ($failures <=3) || # first three failures
             (($failures-3) % 10 ==0 && $failures <= 30) ||  # every 20 minutes
             (($failures-3) % 100 ==0 ) ) { # every 200 minutes
            do_report($count_failed, $c->{'email'});
            }
        
       
    }
    
    print Dumper($status);
    
    ### create HTML file ###
    if (0) {
        open(my $fh, '>', '/html/status.html')
          or die "Could not open file";
      
       
        print $fh '<table border="1">'."\n";
   
    
        foreach my $service (sort keys %$status) {
            my $success = $status->{$service}->{'success'};
            my $report = $status->{$service}->{'report'};
            unless (defined $report) {
                $report = "";
            }
        
            print $fh '<tr>'."\n";
            print $fh "<td>$service</td><td>".($success?'OK':'failed')."</td><td>".$report."</td>\n";
            print $fh '</tr>'."\n";
        }
        print $fh '</table>'."\n";
        print $fh "<br>\n";
        print $fh "last updated: ".localtime()."\n";
        close($fh);
    }

    my $seconds = $sleep_minutes * 60;
    logger('info', "sleeping ".$seconds." seconds");
    sleep($seconds);

}






