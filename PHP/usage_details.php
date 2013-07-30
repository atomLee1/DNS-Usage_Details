#!/usr/bin/php
<?php
#This script will print a QPS report for all zones in an account, all hostnames in a zone, or record types in a hostname.
#Optionally, you can display the header information (off by default). You can send the QPS report to a CSV file.
#You can set your own breakdown using zones, hosts, or rrecs. The default values are in the help menu.

# Options:
# -h --help             Show the help message and exit
# -a --all              Outputs QPS for all zones
# -z --zone             Return the QPS by hosts
# -n --node             Return the record QPS for a specific node (hostname)
# -s --start            Start Date for QPS(ie: 07-01-2013) Start time begins on 00:00:01
# -e --end              End Date for QPS(ie: 07-15-2013) End time begins on 23:59:59
# -f --file             File to output data to in csv format
# -t --title            Prints the header information (Default is off)
# -b --breakdown        Set a custom breakdown. Defaults: -a: zones -z: hosts -n: rrecs

# Example Usage
# php Usage_Details.pl -z [example.com] -s [07-01-2013] -e [07-15-2013]
#       Will print out the QPS for each node in the zone, example.com

# php Usage_Details.pl -z [node.example.com] -s [07-01-2013] -e [07-15-2013] -f [filename.csv]
#       Will write the file to filename.csv with the QPS for the node in the zone, node.example.com

#Options
$shortopts .= "h"; 
$shortopts .= "f:"; 
$shortopts .= "a"; 
$shortopts .= "t";
$shortopts .= "b:";
$shortopts .= "z:"; 
$shortopts .= "n:"; 
$shortopts .= "s:";
$shortopts .= "e:";
$options = getopt($shortopts);

$opt_file .= $options["f"]; 
$opt_all .= $options["a"]; 
$opt_title .= $options["t"]; 
$opt_breakdown .= $options["b"]; 
$opt_zone .= $options["z"]; 
$opt_node .= $options["n"]; 
$opt_start .= $options["s"]; 
$opt_end .= $options["e"]; 
$line_num = 0;

#Print help menu
if (is_bool($options["h"])) {
	print "\nOptions:\n";
        print "-h\t Show the help message and exit\n";
        print "-a\t Outputs QPS for all zones\n";
        print "-z\t Return the QPS by hosts\n";
        print "-n\t Return the record QPS for a specific node (hostname)\n";
        print "-s\t Start Date for QPS(ie: 07-01-2013) Start time begins on 00:00:01\n";
        print "-e\t End Date for QPS(ie: 07-15-2013) End time begins on 23:59:59\n";
        print "-f\t File to output data to in csv format\n";
        print "-t\t Prints the header information (Default is off)\n";
        print "-b\t Set a custom breakdown. Defaults: -a: zones -z: hosts -n: rrecs\n";
        print "\nUsage Example:\n";
        print "php Usage_Details.php -z [example.com] -s [07-01-2013] -e [07-15-2013]\n\tWill print out the QPS for each node in the zone, example.com\n";
        print "php Usage_Details.php -z [node.example.com] -s [07-01-2013] -e [07-15-2013] -f [filename.csv]\n\tWill write the file to filename.csv with the QPS for the node in the zone, node.example.com\n";

	exit;}
#Setting values for set flags
if(!is_string($options["b"]))
	{$opt_breakdown = "";}
if(is_bool($options["t"]))
	{$opt_title = true;}
else
	{$opt_title = false;}
	
# Parse ini file (can fail)
#Set the values from file to variables or die
$ini_array = parse_ini_file("config.ini") or die;
$api_cn = $ini_array['cn'] or die("Customer Name required in config.ini for API login\n");
$api_un = $ini_array['un'] or die("User Name required in config.ini for API login\n");
$api_pw = $ini_array['pw'] or die("Password required in config.ini for API login\n");	

# Prevent the user from proceeding if they have not entered -n or -z
if(($opt_zone == "" && $opt_node == "" && !is_bool($options["a"])) || ($opt_zone != "" && $opt_node != "" && !is_bool($options["a"])))
{
	print "You must enter \"-z [example.com]\" or \"-n [node.example.com]\"\n";
	exit;
}
# Prevent the user from proceeding if they have not entered -n or -z
if($opt_start == ""|| $opt_end == "")
{
	print "You must enter both a start and an end time.\nExample:  \"-s [06-04-13] -e [06-24-13]\"\n";
	exit;
}


# Setting file name and opening file for writing
if(is_string($options["f"]))
{	
	$fp = fopen($opt_file, 'w') or die;
	print "Writing CSV file...\n";
}

# Log into DYNECT
# Create an associative array with the required arguments
$api_params = array(
			'customer_name' => $api_cn,
			'user_name' => $api_un,
			'password' => $api_pw);
$session_uri = 'https://api2.dynect.net/REST/Session/'; 
$decoded_result = api_request($session_uri, 'POST', $api_params,  $token);	

#Set the token
if($decoded_result->status == 'success')
	{$token = $decoded_result->data->token;}

#Set start and end timestamps to proper format
date_default_timezone_set('UTC');
$split = preg_split('/-/', $opt_start);
$m = $split[0];
$d = $split[1];
$y = $split[2];
$opt_start = mktime(0,0,1,$m,$d,$y);

$split = preg_split('/-/', $opt_end);
$m = $split[0];
$d = $split[1];
$y = $split[2];
$opt_end = mktime(23,59,59,$m,$d,$y);


# Setting params depending on user input	
if($opt_node != "")	
	{if($opt_breakdown == "") {$opt_breakdown = 'rrecs';} 
	$api_params = array ('start_ts'=> $opt_start, 'end_ts' => $opt_end, 'breakdown' => $opt_breakdown, 'hosts' => $opt_node);}
elseif($opt_zone != "")
	{if($opt_breakdown == "") {$opt_breakdown = 'hosts';} 
	$api_params = array ('start_ts'=> $opt_start, 'end_ts' => $opt_end, 'breakdown' => $opt_breakdown, 'zones' => $opt_zone);}
else
	{if($opt_breakdown == "") {$opt_breakdown = 'zones';} 
	$api_params = array ('start_ts'=> $opt_start, 'end_ts' => $opt_end, 'breakdown' => $opt_breakdown);}
$session_uri = 'https://api2.dynect.net/REST/QPSReport/'; 
$decoded_result = api_request($session_uri, 'POST', $api_params,  $token);	

foreach($decoded_result->data as $csvin);
	{$csv = $csvin;}
# Breaking the string into lines
$csvData = str_getcsv($csv, "\n");
foreach($csvData as $csvLine)
{
	# Breaking the line by commas	
	$value = str_getcsv($csvLine, ",");
	# Set value to hostname and queries
	$h = $value[1]; 
	$q = $value[2];
	if($line_num == 0)
	{
		#If opt_title has is set,  print the headers
		if($opt_title)
		{
			if($opt_file != "") #If -f is set, send output to file
				fputcsv($fp, array($q, $h)); #Send evertying in the array to the csv
			else
			print "$q\t\t$h\n"; # Print queires and hostnames
			
		}
	}
	else
	{
		$sum[$h] += $q; #Add up the queries by hostname
	}
	$line_num++;
}

#Print out each query count and unique hostname
foreach($sum as $host=>$query)
{
	if($opt_file != "") #If -f is set, send output to file
		fputcsv($fp, array($query, $host)); #Send evertying in the array to the csv
	else
		print "$query\t\t$host\n";
}

#Close file if
if($opt_file != "")
{
	fclose($fp);
	print "\nCSV file: $opt_file written sucessfully.\n";
}

# Logging Out
$session_uri = 'https://api2.dynect.net/REST/Session/'; 
$api_params = array (''=>'');
$decoded_result = api_request($session_uri, 'DELETE', $api_params,  $token);	

# Function that takes zone uri, request type, parameters, and token.
# Returns the decoded result
function api_request($zone_uri, $req_type, $api_params, $token)
{
	$ch = curl_init();
	curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);  # TRUE to return the transfer as a string of the return value of curl_exec() instead of outputting it out directly.
	curl_setopt($ch, CURLOPT_FAILONERROR, false); # Do not fail silently. We want a response regardless
	curl_setopt($ch, CURLOPT_HEADER, false); # disables the response header and only returns the response body
	curl_setopt($ch, CURLOPT_HTTPHEADER, array('Content-Type: application/json','Auth-Token: '.$token)); # Set the token and the content type so we know the response format
	curl_setopt($ch, CURLOPT_CUSTOMREQUEST, $req_type);
	curl_setopt($ch, CURLOPT_URL, $zone_uri); # Where this action is going,
	curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($api_params));
	
	$http_result = curl_exec($ch);
	$decoded_result = json_decode($http_result); # Decode from JSON as our results are in the same format as our request
	//print_r($decoded_result);	
	if($decoded_result->status != 'success')
		{$decoded_result = api_fail($token, $decoded_result);}  	
	
	return $decoded_result;
}

#Expects 2 variable, first a reference to the API key and second a reference to the decoded JSON response
function api_fail($token, $api_jsonref) 
{
	#loop until the job id comes back as success or program dies
	while ( $api_jsonref->status != 'success' ) {
        	if ($api_jsonref->status != 'incomplete') {
                       foreach($api_jsonref->msgs as $msgref) {
                                print "API Error:\n";
                                print "\tInfo: " . $msgref->INFO . "\n";
                                print "\tLevel: " . $msgref->LVL . "\n";
                                print "\tError Code: " . $msgref->ERR_CD . "\n";
                                print "\tSource: " . $msgref->SOURCE . "\n";
                        };
                        #api logout or fail
			$session_uri = 'https://api2.dynect.net/REST/Session/'; 
			$api_params = array (''=>'');
			if($token != "")
				$decoded_result = api_request($session_uri, 'DELETE', $api_params,  $token);	
                        exit;
                }
                else {
                        sleep(5);
                        $session_uri = "https://api2.dynect.net/REST/Job/" . $api_jsonref->job_id ."/";
			$api_params = array (''=>'');
			$api_jsonref = api_request($session_uri, 'GET', $api_params,  $token);	
               }
        }
        return $api_jsonref;
}


?>


