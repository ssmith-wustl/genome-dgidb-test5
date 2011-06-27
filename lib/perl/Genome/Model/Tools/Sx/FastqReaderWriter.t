#!/usr/bin/env perl

use strict;
use warnings;

use above 'Genome';

use Data::Dumper 'Dumper';
require File::Temp;
require File::Compare;
use Test::More;

#< Use >#
use_ok('Genome::Model::Tools::Sx::FastqReader') or die;
use_ok('Genome::Model::Tools::Sx::FastqWriter') or die;

#< Files >#
my $tmpdir = File::Temp::tempdir(CLEANUP => 1);
ok(-d $tmpdir, 'Created temp dir');
my $dir = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Sx/';

my $collated_fastq = $dir.'/reader_writer.collated.fastq';
ok(-s $collated_fastq, 'Collated fastq exists') or die;
my $forward_fastq = $dir.'/reader_writer.forward.fastq';
ok(-s $forward_fastq, 'Forward fastq exists') or die;
my $reverse_fastq = $dir.'/reader_writer.reverse.fastq';
ok(-s $reverse_fastq, 'Reverse fastq exists') or die;

my $example4_forward_fastq = $dir.'/reader_writer.example_4.forward.fastq';
ok(-s $example4_forward_fastq, 'Forward fastq example 4 exists') or die;
my $example4_reverse_fastq = $dir.'/reader_writer.example_4.reverse.fastq';
ok(-s $example4_reverse_fastq, 'Reverse fastq example 4 exists') or die;
my $example4_sing_fastq = $dir.'/reader_writer.example_4.sing.fastq';
ok(-s $example4_sing_fastq, 'Reverse fastq example 4 exists') or die;

#< Create Fails >#
my $failed_create;
eval{ $failed_create = Genome::Model::Tools::Sx::FastqReader->create(); };
ok(($@ && !$failed_create), 'Failed to create w/ reader w/o fastqs');
eval{ 
    $failed_create = Genome::Model::Tools::Sx::FastqReader->create(files => []); 
};
ok(($@ && !$failed_create), 'Failed to create w/ reader w/ empty fastqs aryref');
eval{ 
    $failed_create = Genome::Model::Tools::Sx::FastqReader->create(files => [qw/ 1 2 3/]); 
};
ok(($@ && !$failed_create), 'Failed to create w/ reader w/ too many fastqs');
eval{ $failed_create = Genome::Model::Tools::Sx::FastqWriter->create(); };
ok(($@ && !$failed_create), 'Failed to create w/ writer w/o fastqs');
eval{ 
    $failed_create = Genome::Model::Tools::Sx::FastqWriter->create(files => []); 
};
ok(($@ && !$failed_create), 'Failed to create w/ writer w/ empty fastqs aryref');
eval{ 
    $failed_create = Genome::Model::Tools::Sx::FastqWriter->create(files => [qw/ 1 2 3 4 /]); 
};
ok(($@ && !$failed_create), 'Failed to create w/ writer w/ too many fastqs');

#< Write Fails >#
my $failed_write;
eval{ $failed_write = Genome::Model::Tools::Sx::FastqWriter->write(); };
ok(($@ && !$failed_write), 'Failed to write w/o fastqs');

#< Read/write separate >#
note('Read separate, write separate');
my $reader = Genome::Model::Tools::Sx::FastqReader->create(
    files => [ $forward_fastq, $reverse_fastq ],
);
ok($reader, 'Create reader');
my $out_forward_fastq = $tmpdir.'/test1.forward.fastq';
my $out_reverse_fastq = $tmpdir.'/test1.reverse.fastq';
my $writer = Genome::Model::Tools::Sx::FastqWriter->create(
    files => [ $out_forward_fastq, $out_reverse_fastq ],
);
ok($writer, 'Create writer');
my $count = 0;
while ( my $fastqs = $reader->read ) {
#my $fastqs = $reader->read; while ( 1 ) {
    $count++;
    #if ( $count++ > 100000 ) { last; }
    $writer->write($fastqs)
        or die;
}
is($count, 12, 'Read/write 12 fastq sets');
ok($writer->flush, 'flush');
is(File::Compare::compare($forward_fastq, $out_forward_fastq), 0, 'Foward in/output files match');
is(File::Compare::compare($reverse_fastq, $out_reverse_fastq), 0, 'Reverse in/output files match');

#< Read/write collate and test giving fastq file as a string >#
note('Read collated, write collated');
$reader = Genome::Model::Tools::Sx::FastqReader->create(
    files => [ $forward_fastq, $reverse_fastq ],
    is_paired => 1,
);
ok($reader, 'Create reader');
my $out_collated_fastq = $tmpdir.'/test2.collated.fastq';
$writer = Genome::Model::Tools::Sx::FastqWriter->create(
    files => [ $out_collated_fastq ],
);
ok($writer, 'Create writer');
$count = 0;
while ( my $fastqs = $reader->read ) {
    $count++;
    $writer->write($fastqs)
        or die;
}
is($count, 12, 'Read/write 12 fastq sets');
ok($writer->flush, 'flush');
is(File::Compare::compare($collated_fastq, $out_collated_fastq), 0, 'Reverse in/output files match');

#< Read collated, write separate >#
note('Read collated, write collated');
$reader = Genome::Model::Tools::Sx::FastqReader->create(
    files => [ $collated_fastq ],
    is_paired => 1,
);
ok($reader, 'Create reader');
$out_forward_fastq = $tmpdir.'/test3.forward.fastq';
$out_reverse_fastq = $tmpdir.'/test3.reverse.fastq';
$writer = Genome::Model::Tools::Sx::FastqWriter->create(
    files => [ $out_forward_fastq, $out_reverse_fastq ],
);
ok($writer, 'Create writer');
$count = 0;
while ( my $fastqs = $reader->read ) {
    $count++;
    $writer->write($fastqs)
        or die;
}
is($count, 12, 'Read/write 12 fastq sets');
ok($writer->flush, 'flush');
is(File::Compare::compare($out_forward_fastq, $forward_fastq), 0, 'Foward in/output files match');
is(File::Compare::compare($out_reverse_fastq, $reverse_fastq), 0, 'Reverse in/output files match');

#< Read collated, write collated w/ singletons >#
note('Read collated, write collated');
$reader = Genome::Model::Tools::Sx::FastqReader->create(
    files => [ $collated_fastq ],
    is_paired => 1,
);
ok($reader, 'Create reader');
$out_forward_fastq = $tmpdir.'/test4.forward.fastq';
$out_reverse_fastq = $tmpdir.'/test4.reverse.fastq';
my $out_sing_fastq = $tmpdir.'/test4.sing.fastq';
$writer = Genome::Model::Tools::Sx::FastqWriter->create(
    files => [ $out_forward_fastq, $out_reverse_fastq, $out_sing_fastq ],
);
ok($writer, 'Create writer');
$count = 0;
while ( my $fastqs = $reader->read ) {
    if ( $count++ == 8 ) {
        $fastqs = [ $fastqs->[1] ];
    }
    $writer->write($fastqs)
        or die;
}
is($count, 12, 'Read/write 12 fastq sets');
ok($writer->flush, 'flush');
is(File::Compare::compare($out_forward_fastq, $example4_forward_fastq), 0, 'Foward in/output files match');
is(File::Compare::compare($out_reverse_fastq, $example4_reverse_fastq), 0, 'Reverse in/output files match');
is(File::Compare::compare($out_sing_fastq, $example4_sing_fastq), 0, 'Singleton in/output files match');

#print "$tmpdir\n"; <STDIN>;
done_testing();
exit;

