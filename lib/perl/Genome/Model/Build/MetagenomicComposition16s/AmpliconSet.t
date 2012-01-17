#!/usr/bin/env perl

use strict;
use warnings;

use above 'Genome';

use File::Temp;
use Test::More;

use_ok('Genome::Model::Build::MetagenomicComposition16s::AmpliconSet') or die;

my $tempdir = File::Temp::tempdir(CLEANUP => 1);
mkdir $tempdir.'/fasta';
mkdir $tempdir.'/classification';
my $file_base_name = 'H_GV-933124G-S.MOCK';
my $amplicon_set = Genome::Model::Build::MetagenomicComposition16s::AmpliconSet->create(
    name => 'V1_V3',
    primers => [qw/ c b a/],
    file_base_name => $file_base_name,
    directory => $tempdir,
    classifier => 'rdp2-1',
);
ok($amplicon_set, 'Created amplicon set');
is($amplicon_set->name, 'V1_V3', 'Set name');
is_deeply([$amplicon_set->primers], [qw/ c b a/], 'Primers');

is($amplicon_set->file_base_name, 'H_GV-933124G-S.MOCK', 'file base name');
is($amplicon_set->fasta_dir, $tempdir.'/fasta', 'fasta dir base name');
is($amplicon_set->processed_fasta_file, $tempdir.'/fasta/'.$file_base_name.'.V1_V3.processed.fasta', 'processed fasta file name');
is($amplicon_set->processed_qual_file, $tempdir.'/fasta/'.$file_base_name.'.V1_V3.processed.fasta.qual', 'processed qual file name');
is($amplicon_set->oriented_fasta_file, $tempdir.'/fasta/'.$file_base_name.'.V1_V3.oriented.fasta', 'oriented fasta file name');
is($amplicon_set->oriented_qual_file, $tempdir.'/fasta/'.$file_base_name.'.V1_V3.oriented.fasta.qual', 'oriented qual file name');

my $writer = $amplicon_set->seq_writer_for('processed');
ok($writer, 'seq writer');
my $seq = { id => 'FZ0V7MM01A01AQ', seq => 'ATGC', qual => 'AAAA', desc => 'blah', };
$writer->write($seq);
$writer->close;
my $reader = $amplicon_set->seq_reader_for('processed');
ok($reader, 'seq reader');
my $new_seq = $reader->read;
is_deeply($new_seq, $seq, 'seq matches');

my $classification_file = $amplicon_set->classification_file;
is($classification_file, $tempdir.'/classification/H_GV-933124G-S.MOCK.V1_V3.rdp2-1', 'classification file');
my $fh = Genome::Sys->open_file_for_writing($classification_file);
$fh->print("FZ0V7MM01A01AQ;-;Root:1.0;Bacteria:1.0;Fusobacteria:1.0;Fusobacteria:1.0;Fusobacteriales:1.0;Fusobacteriaceae:1.0;Fusobacterium:1.0;\n");
$fh->close;

my $amplicon = $amplicon_set->next_amplicon;
ok($amplicon, 'amplicon');
is($amplicon->{name}, 'FZ0V7MM01A01AQ', 'Amplicon name');
ok($amplicon->{seq}, 'Amplicon seq');
ok($amplicon->{classification}, 'Amplicon classification');

#print "$tempdir\n"; <STDIN>;
done_testing();
exit;

