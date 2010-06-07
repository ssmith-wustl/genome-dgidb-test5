#! /gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Data::Dumper 'Dumper';
use Genome::Model::Test;
use Genome::Model::MetagenomicComposition16s::Test;
use Test::More;

use_ok('Genome::Model::MetagenomicComposition16s::Command::CopyFiles') or die;

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
# aa model for backward compatibility
my $aa_model = Genome::Model::Test->create_mock_model(
    type_name => 'amplicon assembly',
    use_mock_dir => 1,
);
ok($aa_model, 'Created mock amplicon assembly model');
ok($aa_model->last_complete_build, 'Created mock amplicon assembly build');

my $copy_cmd;
my $tmpdir = File::Temp::tempdir(CLEANUP => 1);

# ok - list w/ model name
$copy_cmd = Genome::Model::MetagenomicComposition16s::Command::CopyFiles->execute(
    build_identifiers => $model->name,
    file_type => 'oriented_fasta',
    list => 1,
);
ok(
    $copy_cmd && $copy_cmd->result,
    'Execute list ok',
);

# ok - copy
#  tests multiple build retrieving methods: model id and build id
$copy_cmd = Genome::Model::MetagenomicComposition16s::Command::CopyFiles->execute(
    build_identifiers => $model->id.','.$aa_model->last_complete_build->id,
    file_type => 'processed_fasta',
    destination => $tmpdir,
);
ok(
    $copy_cmd && $copy_cmd->result,
    'Execute copy ok',
);
my @files = glob("$tmpdir/*");
is(scalar @files, 2, 'Copied files');

# fail - copy to existing
$copy_cmd = Genome::Model::MetagenomicComposition16s::Command::CopyFiles->execute(
    build_identifiers => $model->id,
    file_type => 'processed_fasta',
    destination => $tmpdir,
);
ok(
    $copy_cmd && !$copy_cmd->result,
    'Failed as expected - no copy to existing file',
);

# ok - force copy
$copy_cmd = Genome::Model::MetagenomicComposition16s::Command::CopyFiles->execute(
    build_identifiers => $model->id,
    file_type => 'processed_fasta',
    destination => $tmpdir,
    force => 1,
);
ok(
    $copy_cmd && $copy_cmd->result,
    'Execute copy ok',
);

# fail - no type
ok(
    !Genome::Model::MetagenomicComposition16s::Command::CopyFiles->execute(
        build_identifiers => $model->id,
    ),
    'Failed as expected - no type',
);

# fail - invalid type
ok(
    !Genome::Model::MetagenomicComposition16s::Command::CopyFiles->execute(
        build_identifiers => $model->id,
        file_type => 'some_file_type_that_is_not_valid',
    ),
    'Failed as expected - no type',
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
