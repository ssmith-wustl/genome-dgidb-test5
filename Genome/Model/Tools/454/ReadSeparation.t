#!/gsc/bin/perl

use strict;
use warnings;

use Genome;

use Test::More;

BEGIN {
    my $archos = `uname -a`;
    if ($archos !~ /64/) {
        plan skip_all => "Must run from 64-bit machine";
    }
    plan tests => 5;
    use_ok('Genome::Model::Tools::454::ReadSeparation');
    use_ok('Genome::Model::Tools::454::IsolatePrimerTag');
    use_ok('Genome::Model::Tools::454::CrossMatchPrimerTag');
    use_ok('Genome::Model::Tools::454::SeparateReadsWithCrossMatchAlignment');
}

my $sff_file = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-454-Read-Separation/test_454_primer_tag_100k.sff';

my $read_separation = Genome::Model::Tools::454::ReadSeparation->create(
                                                                        sff_file => $sff_file,
                                                                    );

ok($read_separation->execute,'execute '. $read_separation->command_name);

exit;
