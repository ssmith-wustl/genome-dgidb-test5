#! /gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Genome::Model::DeNovoAssembly::Test;
use Test::More;

use_ok('Genome::Model::DeNovoAssembly::Command::UploadToDacc') or die;


my $model = Genome::Model::DeNovoAssembly::Test->get_mock_model(
    sequencing_platform => 'solexa',
    assembler_name => 'soap de-novo-assemble',
);
ok($model, 'Got mock de novo assembly model') or die;

my $build = Genome::Model::DeNovoAssembly::Test->get_mock_build(
    model => $model,
    use_example_directory => 1,
);
ok($build, 'Got mock de novo assembly build') or die;
$build->assembly_length(100000);

no warnings;
*Genome::Sys::shellcmd = sub{ return 1; };
use warnings;
ok(Genome::Sys->shellcmd(), 'shellcmd overloaded');

my $uploader = Genome::Model::DeNovoAssembly::Command::UploadToDacc->create(
    model => $model,
);
ok($uploader, 'create');
$uploader->dump_status_messages(1);
ok($uploader->execute, 'execute');

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

 Eddie Belter <ebelter@watson.wustl.edu>

=cut

