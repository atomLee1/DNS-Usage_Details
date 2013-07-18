#!/usr/bin/php
<?php
#This script prints out the notes of your zone with the option to print to a file.
#The credentials are read in from a configuration file in the same directory.
#The file is named credentials.cfg in the format:

#Usage: %php znr.php  [-z]
#Options:
#-h, --help		Show this help message and exit
#-z, --zones		Output all zones
#-l, --limit		Set the maximum number of notes to retrieve
#-f, --file		File to output list to

#Get options from command line

$shortopts .= "z:"; 
$shortopts .= "n:"; 
$shortopts .= "f:"; 
$shortopts .= "h"; 
$shortopts .= "a"; 
$shortopts .= "s:";
$shortopts .= "e:";
$longopts  = array(
			"zones:",
			"nodes:",
			"file:",
			"help",
			"all",
			"start:",
			"end:");	
$options = getopt($shortopts, $longopts);

$opt_file .= $options["f"]; 
$opt_zone .= $options["z"]; 
$opt_node .= $options["n"]; 
$opt_start .= $options["s"]; 
$opt_end .= $options["e"]; 
$line_num = 0;

#Print help menu
if (is_bool($options["h"])) {
	print "\t\t-h, --help\t\t Show the help message and exit\n";
	print "\t\t-a, --all\t\t Outputs all hostnames with QPS (default)\n";
	print "\t\t-z, --zone\t\t Return the QPS for a specific zone\n\n";
	print "\t\t-f, --fqdn\t\t Return the QPS for a specific fqdn(hostname)\n\n";
	print "\t\t-c, --csv\t\t File to output data to in csv format\n\n";
	print "\t\t-s, --start\t\t Start Date for QPS(ie: 2012-09-30). The start time begins on 00:00:01\n\n";
	print "\t\t-e, --end\t\t End Date for QPS(ie: 2012-09-30). The start time begins on 23:59:59\n\n";
	exit;}
		
# Parse ini file (can fail)
#Set the values from file to variables or die
$ini_array = parse_ini_file("config.ini") or die;
$api_cn = $ini_array['cn'] or die("Customer Name required in config.ini for API login\n");
$api_un = $ini_array['un'] or die("User Name required in config.ini for API login\n");
$api_pw = $ini_array['pw'] or die("Password required in config.ini for API login\n");	

# Prevent the user from proceeding if they have not entered -n or -z
if(($opt_zone == "" && $opt_node == "") || ($opt_zone != "" && $opt_node != ""))
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
	if(!preg_match('/.csv$/', $opt_file))
		$opt_file = "$opt_file.csv";
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
	$api_params = array ('start_ts'=> $opt_start, 'end_ts' => $opt_end, 'breakdown' => 'hosts', 'hosts' => $opt_node);
elseif($opt_zone != "")
	$api_params = array ('start_ts'=> $opt_start, 'end_ts' => $opt_end, 'breakdown' => 'hosts', 'zones' => $opt_zone);
else
	$api_params = array ('start_ts'=> $opt_start, 'end_ts' => $opt_end, 'breakdown' => 'hosts');

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
		print "$q\t\t$h\n"; # Print queires and hostnames
		if($opt_file != "") #If -f is set, send output to file
			fputcsv($fp, array($q, $h)); #Send evertying in the array to the csv
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
	print "$query\t\t$host\n";
	if($opt_file != "") #If -f is set, send output to file
		fputcsv($fp, array($query, $host)); #Send evertying in the array to the csv
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


