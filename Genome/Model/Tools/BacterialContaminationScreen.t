#!/gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Test::More skip_all => 'related files not in place yet...';
#use Test::More tests => 4; 

BEGIN {
    use_ok('Genome::Model::Tools::BacterialContaminationScreen');
}

my $module_path = $INC{"Genome/Model/Tools/BacterialContaminationScreen.pm"};

my $input_path = $module_path;
$input_path =~ s/.pm$/.t/;
$input_path .= '.t.input';

my $output_path = $module_path;
$output_path =~ s/.pm$/.t/;
$output_path .= '.t.output';

my $output_expected_path = $module_path;
$output_expected_path =~ s/.pm$/.t/;
$output_expected_path .= '.t.output_expected';

my $batch_screen = Genome::Model::Tools::BacterialContaminationScreen->create(
    type=>'read',
    input_file => $input_path
    output_file => $output_path 
);
isa_ok($batch_screen,'Genome::Model::Tools::BacterialContaminationScreen');

my $r = $batch_screen->execute;
ok($r, "executed successfully");

my $diff = `diff $output_path $output_expected_path`;
is($diff, '', "output matches the expected output")
    or diag($diff);

ok( ! Genome::Model::Tools::BacterialContaminationScreen->create(), "Create w/o type - failed as expected");

exit;
