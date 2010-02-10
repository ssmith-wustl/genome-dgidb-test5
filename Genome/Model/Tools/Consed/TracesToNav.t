#!/gsc/bin/perl

use strict;
use warnings;
use IPC::Run;


use above "Genome";
use Test::More tests => 6;

use_ok('Genome::Model::Tools::Consed::TracesToNav');

my $refseq = "/gsc/var/cache/testsuite/data/Genome-Model-Tools-Consed-TracesToConsed/10_126008345_126010576/edit_dir/10_126008345_126010576.c1.refseq.fasta";
my $ace = "/gsc/var/cache/testsuite/data/Genome-Model-Tools-Consed-TracesToConsed/10_126008345_126010576/edit_dir/10_126008345_126010576.ace.1";

my $list = "/gsc/var/cache/testsuite/data/Genome-Model-Tools-Consed-TracesToNav/Nav.list";

ok (-s $refseq);
ok (-s $ace);
ok (-s $list);

#my @command = ["gmt" , "consed" , "traces-to-nav" , "--ace" , "$ace" , "--convert-coords" , "$refseq" , "--unpaired" , "--name-nav" , "test.traces.to.nav" , "--list" , "$list"];
my @command = ["gmt" , "consed" , "traces-to-nav" , "--ace" , "$ace" , "--convert-coords" , "$refseq" , "--input-type" , "simple" , "--name-nav" , "test.traces.to.nav" , "--list" , "$list"];
#system qq(gmt consed traces-to-nav --ace $ace --convert-coords $refseq --input-type simple --name-nav test.traces.to.nav --list $list);

&ipc_run(@command);


my $date = &get_date_tag;

my $navigator = "/gsc/var/cache/testsuite/data/Genome-Model-Tools-Consed-TracesToConsed/10_126008345_126010576/edit_dir/test.traces.to.nav.$date.nav";
my $spreadsheet = "/gsc/var/cache/testsuite/data/Genome-Model-Tools-Consed-TracesToConsed/10_126008345_126010576/edit_dir/test.traces.to.nav.$date.csv";


ok (-s $navigator);
ok (-s $spreadsheet);



sub ipc_run {

    my (@command) = @_;
    my ($in, $out, $err);
    IPC::Run::run(@command, \$in, \$out, \$err);
    if ($err) {
	print qq(Error $err\n);
    }
    if ($out) {
#	print qq($out\n);
    }
}

sub get_date_tag {
    
    my $time=`date`;
    #my ($handle) = getpwuid($<);
    my $date = `date +%D`;
    (my $new_date) = $date =~ /(\d\d)\/(\d\d)\/(\d\d)/ ;
    my $date_tag = "$3$1$2" ;
    return $date_tag;
}
