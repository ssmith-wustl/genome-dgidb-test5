#! /gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Data::Dumper 'Dumper';
require File::Temp;
require File::Compare;
use Test::More;

#< Use >#
use_ok('Genome::Model::Tools::Fastq::SetReader') or die;
use_ok('Genome::Model::Tools::Fastq::SetWriter') or die;

#< Files >#
my $dir = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Fastq-SetReaderWriter';
my $collated_fastq = $dir.'/collated.fastq';
ok(-s $collated_fastq, 'Colated fastq exists');
my $forward_fastq = $dir.'/forward.fastq';
ok(-s $forward_fastq, 'Forward fastq exists');
my $reverse_fastq = $dir.'/reverse.fastq';
ok(-s $reverse_fastq, 'Reverse fastq exists');

my $tmpdir = File::Temp::tempdir(CLEANUP => 1);
ok(-d $tmpdir, 'Created temp dir.');
my $out_collated_fastq = $tmpdir.'/collated.fastq';
my $out_forward_fastq = $tmpdir.'/forward.fastq';
my $out_reverse_fastq = $tmpdir.'/reverse.fastq';

#< Create Fails >#
my $failed_create;
eval{ $failed_create = Genome::Model::Tools::Fastq::SetReader->create(); };
ok(($@ && !$failed_create), 'Failed to create w/ reader w/o fastqs');
eval{ 
    $failed_create = Genome::Model::Tools::Fastq::SetReader->create(fastq_files => []); 
};
ok(($@ && !$failed_create), 'Failed to create w/ reader w/ empty fastqs aryref');
eval{ 
    $failed_create = Genome::Model::Tools::Fastq::SetReader->create(fastq_files => [qw/ 1 2 3/]); 
};
ok(($@ && !$failed_create), 'Failed to create w/ reader w/ too many fastqs');
eval{ $failed_create = Genome::Model::Tools::Fastq::SetWriter->create(); };
ok(($@ && !$failed_create), 'Failed to create w/ writer w/o fastqs');
eval{ 
    $failed_create = Genome::Model::Tools::Fastq::SetWriter->create(fastq_files => []); 
};
ok(($@ && !$failed_create), 'Failed to create w/ writer w/ empty fastqs aryref');
eval{ 
    $failed_create = Genome::Model::Tools::Fastq::SetWriter->create(fastq_files => [qw/ 1 2 3/]); 
};
ok(($@ && !$failed_create), 'Failed to create w/ writer w/ too many fastqs');

#< Write Fails >#
my $failed_write;
eval{ $failed_write = Genome::Model::Tools::Fastq::SetWriter->write(); };
ok(($@ && !$failed_write), 'Failed to write w/o fastqs');

#< Read/write separate >#
my $reader = Genome::Model::Tools::Fastq::SetReader->create(
    fastq_files => [ $forward_fastq, $reverse_fastq ],
);
ok($reader, 'Create reader.');
my $writer = Genome::Model::Tools::Fastq::SetWriter->create(
    fastq_files => [ $out_forward_fastq, $out_reverse_fastq ],
);
ok($writer, 'Create writer.');
is($writer->_write_strategy, '_separate', 'Write to separate files');

my $count = 0;
while ( my $fastqs = $reader->next ) {
    $count++;
    $writer->write($fastqs)
        or die;
}
$writer->flush;
is($count, 12, 'Read/write 12 fastq sets');
is(File::Compare::compare($forward_fastq, $out_forward_fastq), 0, 'Foward in/output files match');
is(File::Compare::compare($reverse_fastq, $out_reverse_fastq), 0, 'Reverse in/output files match');

#< Read/write collate and test giving fastq file as a string >#
$reader = Genome::Model::Tools::Fastq::SetReader->create(
    fastq_files => [ $forward_fastq, $reverse_fastq ],
);
ok($reader, 'Create reader.');
$writer = Genome::Model::Tools::Fastq::SetWriter->create(
    fastq_files => $out_collated_fastq,
);
ok($writer, 'Create writer.');
is($writer->_write_strategy, '_collate', 'Write to collated file');

$count = 0;
while ( my $fastqs = $reader->next ) {
    $count++;
    $writer->write($fastqs)
        or die;
}
$writer->flush;
is($count, 12, 'Read/write 12 fastq sets');
is(File::Compare::compare($collated_fastq, $out_collated_fastq), 0, 'Reverse in/output files match');

#print "$tmpdir\n"; <STDIN>;

done_testing();
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
