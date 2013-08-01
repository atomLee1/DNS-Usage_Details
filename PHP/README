Dyn Inc, Integration Team Deliverable
"Copyright © 2013, Dyn Inc.
All rights reserved.
 
Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are
met:
 
* Redistributions of source code must retain the above copyright notice,
  this list of conditions and the following disclaimer.
 
* Redistributions in binary form must reproduce the above copyright
  notice, this list of conditions and the following disclaimer in the
  documentation and/or other materials provided with the distribution.
 
* Neither the name of Dynamic Network Services, Inc. nor the names of
  its contributors may be used to endorse or promote products derived
  from this software without specific prior written permission.
 
THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
"AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR
CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
ADVISED OF THE POSSIBILITY OF SUCH DAMAGE."

___________________________________________________________________________________

This script will print a QPS report for all zones in an account, all hostnames in a zone, or record types in a hostname. 
Optionally, you can display the header information (off by default). You can send the QPS report to a CSV file. 
You can set your own breakdown using zones, hosts, or rrecs. The default values are in the help menu.

Options:
-h  	Show the help message and exit
-a	Outputs QPS for all zones
-z	Return the QPS by hosts
-n	Return the record QPS for a specific node (hostname)
-s	Start Date for QPS(ie: 07-01-2013) Start time begins on 00:00:01
-e	End Date for QPS(ie: 07-15-2013) End time begins on 23:59:59
-f	File to output data to in csv format
-t	Prints the header information (Default is off)
-b	Set a custom breakdown. Defaults: -a: zones -z: hosts -n: rrecs

Example Usage
php Usage_Details.pl -z [example.com] -s [07-01-2013] -e [07-15-2013]
Will print out the QPS for each node in the zone, example.com

php Usage_Details.pl -z [node.example.com] -s [07-01-2013] -e [07-15-2013] -f [filename.csv]
Will write the file to filename.csv with the QPS for the node in the zone, node.example.com

