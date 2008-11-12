#! /gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Test::Class;

Test::Class->runtests(qw/ GenomeUtilityFileSystem::Test /);

exit 0;

#####################################################

package GenomeUtilityFileSystem::Test;

use base 'Test::Class';

use Data::Dumper;
use File::Path;
use Test::More;

sub startup : Test(startup => 1) {
    require_ok('Genome::Utility::FileSystem');
}

sub _base_test_dir {
    return '/gsc/var/cache/testsuite/data/Genome-Utility-Filesystem';
}

sub test1_create_directory : Test(2) {
    my $self = shift;

    my $base_new_dir = sprintf('%s/new', _base_test_dir());
    my $new_dir = sprintf('%s/dir/with/sub/dirs/', $base_new_dir);
    Genome::Utility::FileSystem->create_directory($new_dir);
    ok(-d $new_dir, "Created new dir: $new_dir"); 
    ok(File::Path::rmtree($base_new_dir), "Removed base new dir: $base_new_dir");

    return 1;
}

=pod

=head1 Tests

=head1 Disclaimer

 Copyright (C) 2008 Washington University Genome Sequencing Center

 This script is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY
 or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
 License for more details.

=head1 Author(s)

 Eddie Belter <ebelter@watson.wustl.edu>

=cut

#$HeadURL$
#$Id$
