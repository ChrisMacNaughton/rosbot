<?php




unset($argv[0]);
unset($argv[1]);
unset($argv[2]);


$search_string = implode(" ",$argv);
$search_string  = escapeshellarg(trim(str_replace('"','',$search_string)));
unlink("/tmp/cveout.txt");
passthru("cd ~sinteur/vFeed;python vfeedcli.py -s " . $search_string . " > /tmp/cveout.txt");
$outp = file("/tmp/cveout.txt");

foreach($outp as $line) print htmlentities($line) ;
?>