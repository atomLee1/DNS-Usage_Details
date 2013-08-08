#!/usr/bin/env perl

#This script will print a QPS report for all zones in an account, all hostnames in a zone, or record types in a hostname. 
#Optionally, you can display the header information (off by default). You can send the QPS report to a CSV file.
#You can set your own breakdown using zones, hosts, or rrecs. The default values are in the help menu.

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
# perl Usage_Details.pl -z [example.com] -s [2013-07-01] -e [2013-07-15]
# 	Will print out the QPS for each node in the zone, example.com

# perl Usage_Details.pl -z [node.example.com] -s [2013-07-01] -e [2013-07-15] -f [filename.csv]
# 	Will write the file to filename.csv with the QPS for the node in the zone, node.example.com


use warnings;
use strict;
use Config::Simple;
use Getopt::Long;
use Time::Local;
use Text::CSV_XS;

#Import DynECT handler
use FindBin;
use lib "$FindBin::Bin/DynECT";  # use the parent directory
require DynECT::DNS_REST;

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
	print "perl Usage_Details.pl -z [example.com] -s [2013-07-01] -e [2013-07-15]\n\tWill print out the QPS for each node in the zone, example.com\n";
	print "perl Usage_Details.pl -z [node.example.com] -s [2013-07-01] -e [2013-07-15] -f [filename.csv]\n\tWill write the file to filename.csv with the QPS for the node in the zone, node.example.com\n";
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
if ($opt_start && $opt_end )
{
	#Set start and end timestamps to proper format
	#Set month to m-1 because timelocal month starts at 0
	my ($y, $m, $d) = split '-', $opt_start;
	$opt_start = timegm(1,0,0,$d,$m-1,$y);
	($y, $m, $d) = split '-', $opt_end;
	$opt_end = timegm(59,59,23,$d,$m-1,$y);
}
else
{
	print "Need to use \"-s [2013-07-01]\" and \"-e [2013-07-15]\"\n";
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
my $dynect = DynECT::DNS_REST->new;
$dynect->login( $apicn, $apiun, $apipw) or
	die $dynect->message;

my %api_param;
my $api_decode;
#Set the parameters if either fqdn or zone is set.
if($opt_node ne "")	{
	$opt_breakdown = 'rrecs' unless($opt_breakdown ne ""); 
	%api_param = (start_ts => $opt_start, end_ts => $opt_end, breakdown => $opt_breakdown, hosts => $opt_node )
}
elsif($opt_zone ne "") {
	$opt_breakdown = 'hosts' unless($opt_breakdown ne ""); 
	%api_param = (start_ts => $opt_start, end_ts => $opt_end, breakdown => $opt_breakdown, zones => $opt_zone )
}
else {
	$opt_breakdown = 'zones' unless($opt_breakdown ne ""); 
	%api_param = (start_ts => $opt_start, end_ts => $opt_end, breakdown => $opt_breakdown )
}

$dynect->request( '/REST/QPSReport', 'POST',  \%api_param)
	or die $dynect->message;
$api_decode = $dynect->result; 

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
$dynect->logout;

