#! /gsc/bin/perl

use strict;
use warnings;
use Genome;
use File::Temp;

use Test::More;

if (`uname -a` =~ /x86_64/){
    plan tests => 1;
}
else{
    plan skip_all => 'Must run on a 64 bit machine';
}

my ($fh_pipe,$pipe_path) = File::Temp::tempfile;
$fh_pipe->close;
unlink($pipe_path);

my $vmerge_pid = fork();
if (! $vmerge_pid) {
# Child 
    exec("gt maq vmerge --maplist /gsc/var/cache/testsuite/data/Genome-Model-Tools-Maq-Vmerge/all.maplist --pipe $pipe_path 2>/dev/null");
    exit();  # Should not get here...
}


while(1) {
    if (-e $pipe_path) {
        sleep 1;
        last;
    }
    sleep 1;
}

`maq mapview $pipe_path > $pipe_path.virtual`;
die "maq mapview: $?" if ($?);

my $output= `diff $pipe_path.virtual /gsc/var/cache/testsuite/data/Genome-Model-Tools-Maq-Vmerge/myresult_real`; 
is($output,'', "No diffs");
#ok ( (!defined($output) or !$output), "No diffs");

#Clean up
unlink($pipe_path);
unlink("./${pipe_path}.virtual");

print "Killing child:";
if(`kill 0 $vmerge_pid`){
    `kill $vmerge_pid`;    
}

#exit off blade
#system("exit");
