#! /gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Genome::Model::DeNovoAssembly::Test;
use Test::More skip_all => 'Newbler is currently does not run in de-novo pipeline';

use_ok('Genome::Model::Build::DeNovoAssembly::Newbler');

my $model = Genome::Model::DeNovoAssembly::Test->get_mock_model(
    sequencing_platform => 454,
    assembler_name => 'newbler',
);
ok($model, 'Got mock de novo assembly model') or die;
my $build = Genome::Model::Build::DeNovoAssembly->create(
    model_id => $model->id,
    data_directory => Genome::Model::DeNovoAssembly::Test->example_directory_for_model($model),
);
ok($build, 'Created de novo assembly build') or die;
isa_ok($build, 'Genome::Model::Build::DeNovoAssembly::Newbler');

# dirs
is($build->assembly_directory, $build->data_directory.'/assembly', 'Assembly directory');
is($build->sff_directory, $build->data_directory.'/sff', 'Sff directory');

done_testing();
exit;

# files in main dir
_test_files_and_values(
    $build->data_directory,
    # TODO
    collated_fastq_file => 'collated.fastq',
);

done_testing();
exit;

sub _test_files_and_values {
    my ($dir, %files_and_values) = @_;

    for my $file ( keys %files_and_values ) {
        my $value = $build->$file or die;
        is($value, $dir.'/'.$files_and_values{$file}, $file);
        ok(-e $value, "$file exists");
    }

    return 1;
}

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
