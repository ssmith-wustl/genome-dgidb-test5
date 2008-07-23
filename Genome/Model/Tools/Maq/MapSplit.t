#!/gsc/bin/perl

use strict;
use warnings;

use above "Genome";

use Test::More;
use Test::Differences;
use File::Temp;

use Genome::Model::Tools::Maq::MapSplit;
use Genome::Model::Tools::Maq::Map::Reader;

if (`uname -a` =~ /x86_64/){
    plan tests => 158;
}
else{
    plan skip_all => 'Must run on a 64 bit machine';
}

my $tmp_dir = File::Temp::tempdir(CLEANUP => 1);
my $map_file = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Maq-Map/2.map';
my @reference_names = qw(11 12 13);
my $type = 'unique';

my $map_split = Genome::Model::Tools::Maq::MapSplit->create(
                                                            map_file => $map_file,
                                                            submap_directory => $tmp_dir,
                                                            type => $type,
                                                            reference_names => \@reference_names,
                                                        );

isa_ok($map_split,'Genome::Model::Tools::Maq::MapSplit');
ok($map_split->execute,'execute');

my $maq_map_reader = Genome::Model::Tools::Maq::Map::Reader->new;
my $mapsplit_reader = Genome::Model::Tools::Maq::Map::Reader->new;
for my $ref_name (@reference_names) {
    my $maq_map = $tmp_dir .'/'. $ref_name .'.map';
    my $mapsplit = $tmp_dir .'/'. $ref_name .'_'. $type .'.map';
    my $maq_cmd = 'maq submap '. $tmp_dir .'/'. $ref_name .'.map '. $map_file .' '. $ref_name .' 1';
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

exit;

