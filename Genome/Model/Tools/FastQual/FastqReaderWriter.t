#! /gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Test::More 'no_plan';
require File::Temp;
require File::Compare;

#< Use >#
use_ok('Genome::Model::Tools::FastQual::FastqReader') or die;
use_ok('Genome::Model::Tools::FastQual::FastqWriter') or die;

#< Files >#
my $dir = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Fastq-ReaderWriter/v0.2';
my $input_fastq = $dir.'/in.fastq';
ok(-s $input_fastq, 'Input fastq exists') or die;
my $tmpdir = File::Temp::tempdir(CLEANUP => 1);
ok(-d $tmpdir, 'Created temp dir.');
my $output_fastq = $tmpdir.'/fastq';

#< Create Reader/Writer >#
my $reader = Genome::Model::Tools::FastQual::FastqReader->create(
    fastq_file => $input_fastq,
);
ok($reader, 'Create reader.');

my $writer = Genome::Model::Tools::FastQual::FastqWriter->create(
    fastq_file => $output_fastq,
);
ok($writer, 'Create writer.');

#< Read/Write >#
my $count = 0;
while ( my $seq = $reader->next ) {
    $count++;
    $writer->write($seq);
}
$writer->flush;
is($count, 25, 'Read/write 25 sequences');
is(File::Compare::compare($input_fastq, $output_fastq), 0, 'In/out-put files match');
#print "$tmpdir\n"; <STDIN>;

exit;

=pod

=head1 Tests

=head1 Disclaimer

 Copyright (C) 2010 Washington University Genome Sequencing Center

 This script is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY
 or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
 License for more details.

=head1 Author(s)

 Eddie Belter <ebelter@genome.wustl.edu>

=cut

#$HeadURL$
#$Id$
