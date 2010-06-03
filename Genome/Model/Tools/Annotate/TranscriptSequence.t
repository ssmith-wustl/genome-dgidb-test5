#!/gsc/bin/perl

use strict;
use warnings;

use IPC::Run;

use above "Genome";
use Test::More tests => 8;


use_ok('Genome::Model::Tools::Annotate::TranscriptSequence');

my $test_dir = "/gsc/var/cache/testsuite/data/Genome-Model-Tools-Annotate-TranscriptSequence";
ok (-e "/gsc/var/cache/testsuite/data/Genome-Model-Tools-Annotate-TranscriptSequence/NM_001024809.compare.txt");

ok (-d $test_dir);

#my @command = ["gmt" , "annotate" , "transcript-sequence" , "-transcript" , "NM_001024809" , "-output" , "/gsc/var/cache/testsuite/data/Genome-Model-Tools-Annotate-TranscriptSequence/NM_001024809"];
my $AnnotateTranscriptSequence = Genome::Model::Tools::Annotate::TranscriptSequence->create(transcript=>"NM_001024809",output=>"/gsc/var/cache/testsuite/data/Genome-Model-Tools-Annotate-TranscriptSequence/NM_001024809",no_stdout=>"1");
ok($AnnotateTranscriptSequence);
ok($AnnotateTranscriptSequence->execute());
#&ipc_run(@command);

ok (-e "/gsc/var/cache/testsuite/data/Genome-Model-Tools-Annotate-TranscriptSequence/NM_001024809.txt");

my @command = ["diff" , "/gsc/var/cache/testsuite/data/Genome-Model-Tools-Annotate-TranscriptSequence/NM_001024809.txt" , "/gsc/var/cache/testsuite/data/Genome-Model-Tools-Annotate-TranscriptSequence/NM_001024809.compare.txt"];
my ($out) = &ipc_run(@command);
ok (! $out);

ok (! system qq(diff /gsc/var/cache/testsuite/data/Genome-Model-Tools-Annotate-TranscriptSequence/NM_001024809.txt /gsc/var/cache/testsuite/data/Genome-Model-Tools-Annotate-TranscriptSequence/NM_001024809.compare.txt));

@command = ["rm" , "/gsc/var/cache/testsuite/data/Genome-Model-Tools-Annotate-TranscriptSequence/NM_001024809.txt"];
&ipc_run(@command);


sub ipc_run {

    my (@command) = @_;
    my ($in, $out, $err);
    IPC::Run::run(@command, \$in, \$out, \$err);
    if ($err) {
       #print qq($err\n);
    }
    if ($out) {
        #print qq($out\n);
       return ($out);
    }
}
