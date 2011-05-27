#!/usr/bin/env perl

use strict;
use warnings;

use above "Genome";

use Test::More;
use Test::Differences;
use File::Temp;

use Genome::Model::Tools::Maq::MapSplit;
use Genome::Model::Tools::Maq::Map::Reader;

if (`uname -a` =~ /x86_64/){
    plan tests => 103;
}
else{
    plan skip_all => 'Must run on a 64 bit machine';
}

my $tmp_dir = File::Temp::tempdir(CLEANUP => 1);
my $map_file = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Maq-Map/2.map';
my @reference_names = qw(11 12 other);

my $map_split = Genome::Model::Tools::Maq::MapSplit->create(
                                                            map_file => $map_file,
                                                            submap_directory => $tmp_dir,
                                                            reference_names => \@reference_names,
                                                        );

isa_ok($map_split,'Genome::Model::Tools::Maq::MapSplit');
ok($map_split->execute,'execute');

my $maq_map_reader = Genome::Model::Tools::Maq::Map::Reader->new;
my $mapsplit_reader = Genome::Model::Tools::Maq::Map::Reader->new;
for my $ref_name (@reference_names) {
    if ($ref_name eq 'other') {
        next;
    }
    my $maq_map = $tmp_dir .'/'. $ref_name .'_maq.map';
    my $mapsplit = $tmp_dir .'/'. $ref_name  .'.map';
    my $maq_cmd = '/gsc/pkg/bio/maq/maq-0.6.3_x86_64-linux/maq submap '. $maq_map .' '. $map_file .' '. $ref_name .' 1';
    my $rv = system($maq_cmd);
    unless ($rv ==0) {
        die "non-zero exit code($rv) from maq cmd '$maq_cmd':  $!";
    }
    $maq_map_reader->open($maq_map);
    $mapsplit_reader->open($mapsplit);
    eq_or_diff($maq_map_reader->read_header,$mapsplit_reader->read_header, "testing header equality of $ref_name");
    my $record = 0;
    while (my $maq_record = $maq_map_reader->get_next) {
        my $mapsplit_record = $mapsplit_reader->get_next;
        $record++;
        eq_or_diff($maq_record,$mapsplit_record, "testing $record record equality of $ref_name");
    }
    is($mapsplit_reader->get_next,undef,'no more records');
}
my @output_files = $map_split->output_files;
is(scalar(@output_files),scalar(@reference_names),'output files match reference names');

exit;

