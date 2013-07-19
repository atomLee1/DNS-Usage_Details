#!/usr/bin/env perl

#An example script which will print the usage for a specific zone, fqdn or print for all fqdn broken down by fqdn
   
#The credentials are read out of a configuration file in the same directory named config.cfg in the format:

#[Dynect]
#user : user_name
#customer : customer_name
#password: password

# Options:
# -h --help		Show the help message and exit
# -a --all		Outputs QPS for all zones
# -z --zone		Return the QPS by hosts
# -n --node		Return the record QPS for a specific node (hostname)
# -s --start		Start Date for QPS(ie: 07-01-2013) Start time begins on 00:00:01
# -e --end		End Date for QPS(ie: 07-15-2013) End time begins on 23:59:59
# -f --file		File to output data to in csv format
# -t --title		Prints the header information (Default is off)
# -b --breakdown	Set a custom breakdown. Defaults: -a: zones -z: hosts -n: rrecs

# Example Usage
# perl Usage_Details.pl -z [example.com] -s [07-01-2013] -e [07-15-2013]
# 	Will print out the QPS for each node in the zone, example.com

# perl Usage_Details.pl -z [node.example.com] -s [07-01-2013] -e [07-15-2013] -f [filename.csv]
# 	Will write the file to filename.csv with the QPS for the node in the zone, node.example.com

use warnings;
use strict;
use Config::Simple;
use Getopt::Long;
use LWP::UserAgent;
use JSON;
use Time::Local;
use Text::CSV_XS;

my $opt_zone="";
my $opt_node="";
my $opt_file="";
my $opt_start="";
my $opt_end="";
my $opt_breakdown="";
my $opt_help;
my $opt_all;
my $opt_title;
my $fh;
my $csv = Text::CSV_XS->new ( { binary => 1, eol => "\n" } ) or die "Cannot use CSV: ".Text::CSV->error_diag ();

GetOptions(
	'help' => \$opt_help,
	'file=s' => \$opt_file,
	'all' => \$opt_all,
	'title' => \$opt_title,
	'breakdown=s' =>\$opt_breakdown,
	'zone=s' =>\$opt_zone,
	'node=s' =>\$opt_node,
	'start=s' =>\$opt_start,
	'end=s' => \$opt_end,
);

#Printing help menu
if ($opt_help) {
	print "\nOptions:\n";
	print "-h --help\t Show the help message and exit\n";
	print "-a --all\t Outputs QPS for all zones\n";
	print "-z --zone\t Return the QPS by hosts\n";
	print "-n --node\t Return the record QPS for a specific node (hostname)\n";
	print "-s --start\t Start Date for QPS(ie: 07-01-2013) Start time begins on 00:00:01\n";
	print "-e --end\t End Date for QPS(ie: 07-15-2013) End time begins on 23:59:59\n";
	print "-f --file\t File to output data to in csv format\n";
	print "-t --title\t Prints the header information (Default is off)\n";
	print "-b --breakdown\t Set a custom breakdown. Defaults: -a: zones -z: hosts -n: rrecs\n";
	print "\nUsage Example:\n";
	print "perl Usage_Details.pl -z [example.com] -s [07-01-2013] -e [07-15-2013]\n\tWill print out the QPS for each node in the zone, example.com\n";
	print "perl Usage_Details.pl -z [node.example.com] -s [07-01-2013] -e [07-15-2013] -f [filename.csv]\n\tWill write the file to filename.csv with the QPS for the node in the zone, node.example.com\n";
	exit;
}

#Zone & node are required
elsif ($opt_zone eq "" && $opt_node eq "" && !$opt_all)
{
	print "Need to use \"-a\" \"-z [example.com]\" or \"-n [node.example.com]\".\n";
	exit;
}
# Setup the csv file for writing
elsif($opt_file ne "")
{
	# Setting up new csv file
	open $fh, ">", $opt_file  or die "new.csv: $!";
}
# Ensure both -s and -e are set
if ($opt_start ne "" && $opt_end ne "")
{
	#Set start and end timestamps to proper format
	#Set month to m-1 because timelocal month starts at 0
	my ($m, $d, $y) = split '-', $opt_start;
	$opt_start = timegm(1,0,0,$d,$m-1,$y);
	($m, $d, $y) = split '-', $opt_end;
	$opt_end = timegm(59,59,23,$d,$m-1,$y);
}
else
{
	print "Need to use \"-s [07-01-2013]\" and \"e [07-15-2013]\"\n";
	exit;
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
my $api_key = $api_decode->{'data'}->{'token'};

#Set the parameters if either fqdn or zone is set.
if($opt_node ne "")
	{$opt_breakdown = 'rrecs' unless($opt_breakdown ne ""); %api_param = (start_ts => $opt_start, end_ts => $opt_end, breakdown => $opt_breakdown, hosts => $opt_node )}
elsif($opt_zone ne "")
	{$opt_breakdown = 'hosts' unless($opt_breakdown ne ""); %api_param = (start_ts => $opt_start, end_ts => $opt_end, breakdown => $opt_breakdown, zones => $opt_zone )}
else
	{$opt_breakdown = 'zones' unless($opt_breakdown ne ""); %api_param = (start_ts => $opt_start, end_ts => $opt_end, breakdown => $opt_breakdown )}

$session_uri = "https://api2.dynect.net/REST/QPSReport";
$api_decode = &api_request($session_uri, 'POST', $api_key, %api_param); 

#Store the returned csv string
my $csv_string = ( $api_decode->{'data'}->{'csv'});

#Read in the csv from the response
my %hash;
my $linenum = 0;

#Read in each line one at a time.
my @lines = split /\n/, $csv_string;
foreach my $line (@lines){
	#Set each value in the csv to timestamp, hostname, queries
	$csv->parse ($line);
	my @columns = $csv->fields ();
	my($t, $h, $q) = @columns;
	
	#If its the first line, save it
	if ($linenum == 0){
		print "$q\t\t$h\n" unless($opt_file ne "" || !$opt_title);
		$csv->print ($fh, [ $q, $h] ) unless($opt_file eq "" || !$opt_title);
	}
	#Else if the hash exists, add the queries up
	else{
		$hash{$h} += $q;
	}
	$linenum ++;
}
#Goes through the hash printing the queries to the string
foreach my $hostname ( sort keys %hash ){
	print "$hash{$hostname}\t\t$hostname\n" unless($opt_file ne "");
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
&api_request($session_uri, 'DELETE', $api_key, %api_param); 



#Accepts Zone URI, Request Type, and Any Parameters
sub api_request{
	#Get in variables, send request, send parameters, get result, decode, display if error
	my ($zone_uri, $req_type, $api_token, %api_param) = @_;
	$api_request = HTTP::Request->new($req_type, $zone_uri);
	$api_request->header ( 'Content-Type' => 'application/json', 'Auth-Token' => $api_token );
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

