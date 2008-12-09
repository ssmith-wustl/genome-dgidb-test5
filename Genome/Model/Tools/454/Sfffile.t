#!/gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Test::More;

BEGIN {
    my $archos = `uname -a`;
    if ($archos !~ /64/) {
        plan skip_all => "Must run from 64-bit machine";
    }
    plan tests => 3;
    use_ok('Genome::Model::Tools::454::Sfffile');
}

my $tmp_dir = File::Temp::tempdir(CLEANUP => 1);
my $out_file = $tmp_dir .'/tmp.sff';

my $data_dir = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-454-Newbler/R_2008_09_22_14_01_00_FLX12345678_TEST_12345678';

my @sff_files = glob($data_dir.'/*.sff');
my $sfffile = Genome::Model::Tools::454::Sfffile->create(
	in_sff_files => \@sff_files,
        out_sff_file => $out_file,
	assembler_version => '2.0.00.20',					 
);
isa_ok($sfffile,'Genome::Model::Tools::454::Sfffile');
ok($sfffile->execute,'execute '. $sfffile->command_name);

exit;
