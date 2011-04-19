#!/gsc/bin/perl

$ENV{GENOME_DEV_MODE} = 0;

use strict;
use warnings;

use above 'Genome';

require File::Compare;
use Test::More;

# use
use_ok('Genome::Model::Tools::FastQual::Pipe') or die;

# Files
my $dir = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-FastQual';
my $in_fastq = $dir.'/in.fastq';
ok(-s $in_fastq, 'in fastq');
my $example_fastq = $dir.'/pipe.example.fastq';
ok(-s $example_fastq, 'example fastq');
my $tmp_dir = File::Temp::tempdir(CLEANUP => 1);
my $out_fastq = $tmp_dir.'/out.bases.fastq';

# execute fail - bad params to command
my $failed_pipe = Genome::Model::Tools::FastQual::Pipe->execute(
    input  => [ $in_fastq ],
    output => [ $out_fastq ],
);
ok(!$failed_pipe, 'failed w/o commands');
$failed_pipe = Genome::Model::Tools::FastQual::Pipe->execute(
    input  => [ $in_fastq ],
    output => [ $out_fastq ],
    commands => 'collate'
);
ok(($failed_pipe && !$failed_pipe->result), 'failed w/ one command');
$failed_pipe = Genome::Model::Tools::FastQual::Pipe->execute(
    input  => [ $in_fastq ],
    output => [ $out_fastq ],
    commands => 'limit by-coverage --count YY | sorter name',
);
ok(($failed_pipe && !$failed_pipe->result), 'failed in validate command with bad params for limit by coverage');
$failed_pipe = Genome::Model::Tools::FastQual::Pipe->execute(
    input  => [ $in_fastq ],
    output => [ $out_fastq ],
    commands => 'limit by-coverage --count 10 | collate | sorter name',
);
ok(($failed_pipe && !$failed_pipe->result), 'failed in execute of the collate command, and caught the error');

# ok
my $metrics_file = $tmp_dir.'/metrics';
my $pipe = Genome::Model::Tools::FastQual::Pipe->create(
    input  => [ $in_fastq ],
    output => [ $out_fastq ],
    commands => 'limit by-coverage --count 10 | rename illumina-to-pcap',
    #commands => 'limit by-coverage --count 10 | rename illumina-to-pcap | limit by-coverage --bases 200',
    metrics_file_out => $metrics_file,
);
ok($pipe, 'create pipe');
isa_ok($pipe, 'Genome::Model::Tools::FastQual::Pipe');
eval{
    $pipe->execute;
};
if ( $pipe->result ) {
    ok($pipe->result, 'execute pipe');
    is(File::Compare::compare($example_fastq, $out_fastq), 0, "fastq created as expected");
    ok(-s $metrics_file, 'created metrics file');
}
else {
    # We got a failure. If it is b/c of reading from STDIN, that is ok.
    if ( not $pipe->error_message ) { # failed, but not sure why...this should not happen
        ok(0, 'Pipe execute failed, and there was not an error message');
    }
    elsif ( $pipe->error_message =~ /No pipe meta info. Are you sure you wanted to read from a pipe/ ) { # ok
        ok(1, 'Execute failed b/c of error reading from STDIN. This is probably OK');
    }
    else { # real failure
        ok(0, 'Execute failed. Listing errors (if any) below');
        diag($pipe->error_message);
    }
}

print "$tmp_dir\n"; <STDIN>;
done_testing();
exit;

