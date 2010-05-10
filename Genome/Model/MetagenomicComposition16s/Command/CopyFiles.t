#! /gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Data::Dumper 'Dumper';
use Genome::Model::MetagenomicComposition16s::Test;
use Test::More;

use_ok('Genome::Model::MetagenomicComposition16s::Command::CopyFiles');

# model/build
my $model = Genome::Model::MetagenomicComposition16s::Test->create_mock_mc16s_model(
    sequencing_platform => 'sanger',
    use_mock_dir => 1,
);
ok(
    Genome::Model::MetagenomicComposition16s::Test->create_mock_build_for_mc16s_model($model),
    'Added build to model',
);

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
$copy_cmd = Genome::Model::MetagenomicComposition16s::Command::CopyFiles->execute(
    build_identifiers => $model->id,
    file_type => 'processed_fasta',
    destination => $tmpdir,
);
ok(
    $copy_cmd && $copy_cmd->result,
    'Execute copy ok',
);
my @files = glob("$tmpdir/*");
ok(@files, 'Copied files');

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
