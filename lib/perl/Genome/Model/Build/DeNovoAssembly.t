#!/usr/bin/env perl
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

use_ok('Genome::Model::Build::DeNovoAssembly') or die;

my $model = Genome::Model::DeNovoAssembly::Test->model_for_velvet;
ok($model, 'Got de novo assembly model') or die;
my $build = Genome::Model::DeNovoAssembly::Test->example_build_for_model($model);
ok($build, 'Got example de novo assembly build') or die;
isa_ok($build, 'Genome::Model::Build::DeNovoAssembly');

is($build->center_name, $build->model->center_name, 'center name');
is($build->genome_size, 4500000, 'Genome size');

# base limit
is($build->calculate_base_limit_from_coverage, 2_250_000, 'Calculated base limit');

#test disk reserve based on coverage
is($build->calculate_estimated_kb_usage, (5_056_250), 'Kb usage based on coverage');

#test disk reserve based on processed read count
my $coverage = $model->processing_profile->coverage;
$model->processing_profile->coverage(undef); #undef this to allow calc by proc reads coverage
$build->processed_reads_count(1_250_000);
is($build->calculate_estimated_kb_usage, (5_060_000), 'Kb usage based on processed read count');

#reset coverage values .. necessary ?? test passes w/o it
$model->processing_profile->coverage($coverage);

# insert size/sd
my $avg_insert_size = $build->calculate_average_insert_size;
is($avg_insert_size, 260, 'average insert size');

# metrics
my @interesting_metric_names = $build->interesting_metric_names;
is(scalar(@interesting_metric_names), 26, 'interesting metric names');
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
