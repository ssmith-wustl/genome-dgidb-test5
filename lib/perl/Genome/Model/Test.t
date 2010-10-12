#! /gsc/bin/perl

# THIS TESTS Genome::Model::Test and MODEL MOCKING

use strict;
use warnings;

use above 'Genome';
use Carp::Always;
use Data::Dumper 'Dumper';
use Test::More 'no_plan';

use_ok('Genome::Model::Test');

# Model
my $model = Genome::Model::Test->create_mock_model(
    type_name => 'tester',
    instrument_data_count => 2,
);
ok($model, 'Created mock model');
is($model->id, $model->genome_model_id, 'model_id and genome_model_id match');

# PP 
ok($model->processing_profile, 'Model has a Processing profile');
is($model->processing_profile_id, $model->processing_profile->id, 'processing profile id');
is($model->type_name, $model->processing_profile->type_name, 'type name');
is($model->sequencing_platform, $model->processing_profile->sequencing_platform, 'sequencing_platform');
is($model->dna_source, $model->processing_profile->dna_source, 'dna_source');

# Subject
ok($model->processing_profile, 'Model has a subject');
is($model->subject_name, $model->subject->name, 'subject name');

# Builds
my @builds = $model->builds;
is_deeply(
    \@builds,
    [Genome::Model::Build->get(model_id => $model->id)],
    'Model\'s builds match Genome::Model::Build->get',
);
my $last_complete_build = $model->last_complete_build;
is_deeply($last_complete_build, $builds[0], 'last_complete_build');
is($last_complete_build->status, 'Succeeded', 'Build is succeeded');
is_deeply($model->last_succeeded_build, $last_complete_build, 'Last succeeded build');

# Ints Data
my @instrument_data_assignments = $model->instrument_data_assignments;
ok(@instrument_data_assignments, 'instrument_data_assignments');
my @instrument_data = $model->instrument_data;
is_deeply(
    \@instrument_data,
    [map { $_->instrument_data } $model->instrument_data_assignments],
    'instrument_data',
);

exit;

=pod

=head1 Disclaimer

Copyright (C) 2009 Washington University Genome Sequencing Center

This script is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

=head1 Author(s)

B<Eddie Belter> <ebelter@watson.wustl.edu>

=cut

#$HeadURL$
#$Id$
