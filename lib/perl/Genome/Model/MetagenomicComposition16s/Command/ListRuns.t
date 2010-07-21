#! /gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Data::Dumper 'Dumper';
use Genome::Model::Test;
use Genome::Model::MetagenomicComposition16s::Test;
use Test::More;

use_ok('Genome::Model::MetagenomicComposition16s::Command::ListRuns') or die;

# model/build
my $model = Genome::Model::MetagenomicComposition16s::Test->get_mock_model(
    sequencing_platform => 'sanger',
);
ok($model, 'Got mock mc16s sanger model');
ok(
    Genome::Model::MetagenomicComposition16s::Test->get_mock_build(
        model => $model,
        use_example_directory => 1,

    ),
    'Got mock mc16s build',
);

my $cmd;
my $tmpdir = File::Temp::tempdir(CLEANUP => 1);

# ok - list w/ model name
$cmd = Genome::Model::MetagenomicComposition16s::Command::ListRuns->execute(
    build_identifiers => $model->name,
);
ok(
    $cmd && $cmd->result,
    'Execute list runs ok',
);

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
