#!/gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Test::More;

BEGIN {
    plan tests => 3;
    use_ok('Genome::Model::Tools::BacterialContaminationScreen');
}


my $batch_screen = Genome::Model::Tools::BacterialContaminationScreen->create(type=>'read',
                                                             input_file => 'in.txt',
                                                             output_file => 'commandLines.txt');
isa_ok($batch_screen,'Genome::Model::Tools::BacterialContaminationScreen');
$batch_screen->execute;

ok( ! Genome::Model::Tools::BacterialContaminationScreen->create(), "Create w/o type - failed as expected");

exit;
