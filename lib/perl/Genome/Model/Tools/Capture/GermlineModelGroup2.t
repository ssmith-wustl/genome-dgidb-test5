use strict;
use warnings;
use Genome;
use Test::More tests => 3;

my $this_file_name = __FILE__;
my $tmp_dir = Genome::Sys->create_temp_directory;

my $command = Genome::Model::Tools::Capture::GermlineModelGroup2->create(
    model_group => Genome::ModelGroup->get(10407),
    qc_directory => "$this_file_name.d/qc_output",
    output_directory => $tmp_dir,
);

ok($command, 'create GermlineModelGroup2 command');
ok($command->execute, 'execute GermlineModelGroup2 command');

my $diff = `diff -q $this_file_name.d/correct_summary_output/ $tmp_dir`;
is($diff, '', 'correct output');
