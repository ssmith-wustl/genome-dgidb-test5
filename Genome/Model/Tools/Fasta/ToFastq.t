#!/gsc/bin/perl

use strict;
use warnings;

use above "Genome";
use Test::More tests => 4;
use File::Compare;
use File::Temp;
use FindBin qw/$Bin/;

BEGIN {
        use_ok ('Genome::Model::Tools::Fasta::ToFastq');
}

my $fasta_file = "$Bin/../t/test.fasta";
my $qual_file = "$Bin/../t/test.qual";
my $expected_fastq = "$Bin/../t/test.fastq";

my ($fastq_fh,$fastq_file) = File::Temp::tempfile;
my $fasta_to_fastq = Genome::Model::Tools::Fasta::ToFastq->create(
                                                                fasta_file => $fasta_file,
                                                                qual_file => $qual_file,
                                                                fastq_file => $fastq_file,
                                                            );
isa_ok($fasta_to_fastq,'Genome::Model::Tools::Fasta::ToFastq');
ok($fasta_to_fastq->execute,'execute Fasta::ToFastq');
ok(compare($fastq_file,$expected_fastq),'fastq files the same');
unlink $fastq_file || warn "Failed to remove fastq file $fastq_file";
exit;

