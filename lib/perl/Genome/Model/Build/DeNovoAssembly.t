#! /gsc/bin/perl
#
#
# Tests base Genome::Model::Build::DeNovoAssembly w/ velvet solexa model
#
#

use strict;
use warnings;

use above 'Genome';

use Genome::Model::DeNovoAssembly::Test;
use Test::More;

use_ok('Genome::Model::Build::DeNovoAssembly');

my $model = Genome::Model::DeNovoAssembly::Test->get_mock_model(
    sequencing_platform => 'solexa',
    assembler_name => 'velvet',
);
ok($model, 'Got mock de novo assembly model') or die;
my $build = Genome::Model::Build::DeNovoAssembly->create(
    model_id => $model->id,
    data_directory => Genome::Model::DeNovoAssembly::Test->example_directory_for_model($model),
);
ok($build, 'Created de novo assembly build') or die;
isa_ok($build, 'Genome::Model::Build::DeNovoAssembly');

is($build->calculate_estimated_kb_usage, (50_000_000 * 1.024), 'Kb usage');
is($build->genome_size, 4500000, 'Genome size');

# read length/limit
#  w/o trimmer
my $read_trimmer_name = $build->processing_profile->read_trimmer_name;
$build->processing_profile->read_trimmer_name(undef);
is($build->estimate_average_read_length, 100, 'Estimate average read length w/o trimmer');
is($build->calculate_read_limit_from_read_coverage, 22500, 'Calculated read limit w/o trimmer');
#  w/ trimmer
$build->processing_profile->read_trimmer_name($read_trimmer_name);
is($build->estimate_average_read_length, 90, 'Estimate average read length');
is($build->calculate_read_limit_from_read_coverage, 25000, 'Calculated read limit');

# metrics
my @interesting_metric_names = $build->interesting_metric_names;
is(scalar(@interesting_metric_names), 14, 'interesting metric names');
for my $metric_name ( @interesting_metric_names ) {
    $metric_name =~ s/\s/_/g;
    can_ok('Genome::Model::Build::DeNovoAssembly', $metric_name);
}

done_testing();
exit;

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

#$HeadURL: svn+ssh://svn/srv/svn/gscpan/perl_modules/trunk/Genome/Model/Build/MetagenomicComposition16s.t $
#$Id: MetagenomicComposition16s.t 56090 2010-03-03 23:57:25Z ebelter $
