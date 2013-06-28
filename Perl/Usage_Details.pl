#!/usr/bin/perl

#An example script which will print the usage for a specific zone, fqdn or print for all fqdn broken down by fqdn
   
#The credentials are read out of a configuration file in the same directory named credentials.cfg in the format:

#[Dynect]
#user : user_name
#customer : customer_name
#password: password

#Usage: %perl qps_detail.pl -s START -e END [-h|-a|-z|-f|-c]

#Options:
#	-h, --help            show this help message and exit
#    	-a, --all             Output all hostnames with QPS (default)
#	-z ZONE, --zone=ZONE  Return the QPS for a specific zone
#	-f FQDN, --fqdn=FQDN  Return the QPS for a specific fqdn (hostname)
#	-c FILE, --csv=FILE   File to output data to in csv format
#	-s START, --start=START  Start date for QPS (ie: 2012-09-30). The start time begins on 00:00:01
#	-e END, --end=END     End date for QPS (ie: 2012-09-30). The end time finshes at 23:59:59

#The library is available at: https://github.com/dyninc/Dynect-API-Python-Library

##TODO
#What is -a doing?



use warnings;
use strict;
use Data::Dumper;
use XML::Simple;
use Config::Simple;
use Getopt::Long qw(:config no_ignore_case);
use LWP::UserAgent;
use JSON;
use Time::Local;
use IO::Handle;
use Text::CSV;

#Get Options
my $opt_zone="";
my $opt_file="";
my $opt_help;
my $opt_node="";
my $opt_all;
my $opt_start;
my $opt_end=localtime(time);
my $fh;
my $csv;

GetOptions(
	'help' => \$opt_help,
	'file=s' => \$opt_file,
	'all' => \$opt_all,
	'zone=s' =>\$opt_zone,
	'node=s' =>\$opt_node,
	'start=s' =>\$opt_start,
	'end=s' => \$opt_end,
);
#Printing help menu
if ($opt_help) {
	print "\tOptions:\n";
	print "\t\t-h, --help\t\t Show the help message and exit\n";
	print "\t\t-a, --all\t\t Outputs all hostnames with QPS (default)\n";
	print "\t\t-z, --zone\t\t Return the QPS for a specific zone\n";
	print "\t\t-n, --node\t\t Return the QPS for a specific node(hostname)\n";
	print "\t\t-f, --file\t\t File to output data to in csv format\n";
	print "\t\t-s, --start\t\t Start Date for QPS(ie: 2012-09-30). The start time begins on 00:00:01\n";
	print "\t\t-e, --end\t\t End Date for QPS(ie: 2012-09-30). The start time begins on 23:59:59\n";
	exit;
}


if($opt_file ne "")
{
	# Setting up new csv file
	# If opt_file does not end in ".csv" append it
	$opt_file = "$opt_file.csv" unless ($opt_file =~ /.csv$/);
	$csv = Text::CSV->new ( { binary => 1, eol => "\n" } ) or die "Cannot use CSV: ".Text::CSV->error_diag ();
	open $fh, ">", $opt_file  or die "new.csv: $!";
}

#Create config reader
my $cfg = new Config::Simple();
# read configuration file (can fail)
$cfg->read('config.cfg') or die $cfg->error();

#dump config variables into hash for later use
my %configopt = $cfg->vars();
my $apicn = $configopt{'cn'} or do {
	print "Customer Name required in config.cfg for API login\n";
	exit;
};

my $apiun = $configopt{'un'} or do {
	print "User Name required in config.cfg for API login\n";
	exit;
};

my $apipw = $configopt{'pw'} or do {
	print "User password required in config.cfg for API login\n";
	exit;
};

#API login
my $session_uri = 'https://api2.dynect.net/REST/Session';
my %api_param = ( 
	'customer_name' => $apicn,
	'user_name' => $apiun,
	'password' => $apipw,);
my $api_request = HTTP::Request->new('POST',$session_uri);
$api_request->header ( 'Content-Type' => 'application/json' );
$api_request->content( to_json( \%api_param ) );
my $api_lwp = LWP::UserAgent->new;
my $api_result = $api_lwp->request( $api_request );
my $api_decode = decode_json ( $api_result->content ) ;
my $api_token = $api_decode->{'data'}->{'token'};


#Set start and end timestamps to proper format
#Set month to m-1 because timelocal month starts at 0
my ($y, $m, $d) = split '-', $opt_start;
$opt_start = timegm(1,0,0,$d,$m-1,$y);
($y, $m, $d) = split '-', $opt_end;
$opt_end = timegm(59,59,23,$d,$m-1,$y);

#Set the parameters if either fqdn or zone is set.
if($opt_node ne "")
	{%api_param = (start_ts => $opt_start, end_ts => $opt_end, breakdown => 'hosts', hosts => $opt_node )}
elsif($opt_zone ne "")
	{%api_param = (start_ts => $opt_start, end_ts => $opt_end, breakdown => 'hosts', zones => $opt_zone )}
else
	{%api_param = (start_ts => $opt_start, end_ts => $opt_end, breakdown => 'hosts' )}

$session_uri = "https://api2.dynect.net/REST/QPSReport";
$api_decode = &api_request($session_uri, 'POST', $api_token, %api_param); 

#Store the returned csv string
my $csv_string = ( $api_decode->{'data'}->{'csv'});

#Read in the csv from the response
my %hash;
my $linenum = 0;
#Read in each line one at a time.
my @lines = split /\n/, $csv_string;
foreach my $line (@lines){
	#Set each value in the csv to timestamp, hostname, queries
	my($t, $h, $q)  = split(",", $line, 3);
	#If its the first line, save it
	if ($linenum == 0 ){
		print "$q\t\t$h\n";
		$csv->print ($fh, [ $q, $h] ) unless($opt_file eq "");
	}
	#Else if the hash exists, add the queries up
	else{
		$hash{$h} += $q;
	}
	$linenum ++;
}
#Goes through the hash printing the queries to the string
foreach my $hostname ( keys %hash ){
	print "$hash{$hostname}\t\t$hostname\n";
	$csv->print ($fh, [ $hash{$hostname}, $hostname] ) unless($opt_file eq "");
}


# Close csv file
if($opt_file ne "")
{
close $fh or die "$!";
print "CSV file: $opt_file written sucessfully.\n";
}

#api logout
%api_param = ();
$session_uri = 'https://api2.dynect.net/REST/Session';
&api_request($session_uri, 'DELETE', $api_token, %api_param); 



#Accepts Zone URI, Request Type, and Any Parameters
sub api_request{
	#Get in variables, send request, send parameters, get result, decode, display if error
	my ($zone_uri, $req_type, $api_key, %api_param) = @_;
	$api_request = HTTP::Request->new($req_type, $zone_uri);
	$api_request->header ( 'Content-Type' => 'application/json', 'Auth-Token' => $api_key );
	$api_request->content( to_json( \%api_param ) );
	$api_result = $api_lwp->request($api_request);
	$api_decode = decode_json( $api_result->content);
	$api_decode = &api_fail(\$api_key, $api_decode) unless ($api_decode->{'status'} eq 'success');
	return $api_decode;
}

#Expects 2 variable, first a reference to the API key and second a reference to the decoded JSON response
sub api_fail {
	my ($api_keyref, $api_jsonref) = @_;
	#set up variable that can be used in either logic branch
	my $api_request;
	my $api_result;
	my $api_decode;
	my $api_lwp = LWP::UserAgent->new;
	my $count = 0;
	#loop until the job id comes back as success or program dies
	while ( $api_jsonref->{'status'} ne 'success' ) {
		if ($api_jsonref->{'status'} ne 'incomplete') {
			foreach my $msgref ( @{$api_jsonref->{'msgs'}} ) {
				print "API Error:\n";
				print "\tInfo: $msgref->{'INFO'}\n" if $msgref->{'INFO'};
				print "\tLevel: $msgref->{'LVL'}\n" if $msgref->{'LVL'};
				print "\tError Code: $msgref->{'ERR_CD'}\n" if $msgref->{'ERR_CD'};
				print "\tSource: $msgref->{'SOURCE'}\n" if $msgref->{'SOURCE'};
			};
			#api logout or fail
			$api_request = HTTP::Request->new('DELETE','https://api2.dynect.net/REST/Session');
			$api_request->header ( 'Content-Type' => 'application/json', 'Auth-Token' => $$api_keyref );
			$api_result = $api_lwp->request( $api_request );
			$api_decode = decode_json ( $api_result->content);
			exit;
		}
		else {
			sleep(5);
			my $job_uri = "https://api2.dynect.net/REST/Job/$api_jsonref->{'job_id'}/";
			$api_request = HTTP::Request->new('GET',$job_uri);
			$api_request->header ( 'Content-Type' => 'application/json', 'Auth-Token' => $$api_keyref );
			$api_result = $api_lwp->request( $api_request );
			$api_jsonref = decode_json( $api_result->content );
		}
	}
	$api_jsonref;
}

