#! /gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Data::Dumper;
use Genome::Model::MetagenomicComposition16s::Test;
use Test::More;

use_ok('Genome::Model::MetagenomicComposition16s::Command');

# fake class and execute to test base class
class Genome::Model::MetagenomicComposition16s::Command::Tester {
    is => 'Genome::Model::MetagenomicComposition16s::Command',
};
sub Genome::Model::MetagenomicComposition16s::Command::Tester::execute { 
    my $self = shift;
    return $self->_builds;
}

# model
my $model = Genome::Model::MetagenomicComposition16s::Test->create_mock_mc16s_model(
    sequencing_platform => 'sanger',
);
ok($model, 'Got mock MC16s sanger model');
my $cmd;

#< FAIL >#
# fail in create - no build identifiers
ok(
    !Genome::Model::MetagenomicComposition16s::Command::Tester->execute(),
    'Failed as expected - no build identifiers',
);

# fail in execute - no models for identifiers
$cmd = Genome::Model::MetagenomicComposition16s::Command::Tester->execute(
    build_identifiers => 'BLAH',
);
ok(
    !$cmd->result,
    'Failed as expected - no build identifiers',
);

# fail in execute - model doesn't have a build
$cmd = Genome::Model::MetagenomicComposition16s::Command::Tester->execute(
    build_identifiers => $model->id,
);
ok(
    $cmd && !$cmd->result,
    'Execute list ok',
);

# fail in execute - no build for identifer
$cmd = Genome::Model::MetagenomicComposition16s::Command::Tester->execute(
    build_identifiers => 1,
);
ok(
    $cmd && !$cmd->result,
    'Execute list ok',
);
#<>#

# add build
my $build = Genome::Model::MetagenomicComposition16s::Test->create_mock_build_for_mc16s_model($model);
ok($build, 'Added build to model');

#< OK >#
# execute ok - model name
ok(
    Genome::Model::MetagenomicComposition16s::Command::Tester->execute(
        build_identifiers => $model->name,
    ),
    'Execute ok',
);

# execute ok - build id
ok(
    Genome::Model::MetagenomicComposition16s::Command::Tester->execute(
        build_identifiers => $build->id,
    ),
    'Execute ok',
);
#<>#

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

#$HeadURL$
#$Id$
