#! /gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Test::More;

use_ok('Genome::Model::Tools::Dacc::Upload') or die;

my $dir = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Dacc';
my @files = ( $dir.'/dacc.tar.gz' );

my $up = Genome::Model::Tools::Dacc::Upload->create(
    sample_id => 'SRS000000',
    format => 'kegg',
    files => \@files,
);
ok($up, 'create');
$up->dump_status_messages(1);
no warnings qw/ once redefine /;
*Genome::Model::Tools::Dacc::is_host_a_blade = sub{ return 1; };
*Genome::Utility::FileSystem::shellcmd = sub{
    my ($class, %params) = @_;
    diag($params{cmd});
    is(
        $params{cmd}, 
        'ascp -Q -l100M -i '.$up->certificate.' -d '.join(' ', $up->files).' '.$up->dacc_remote_directory,
        'Aspera command matches',
    );
    return 1;
};
use warnings;
ok($up->execute, 'execute');

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

