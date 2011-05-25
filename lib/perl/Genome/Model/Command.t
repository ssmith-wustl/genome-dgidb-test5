#!/usr/bin/env perl

use strict;
use warnings;

use above 'Genome';

require Genome::Model::Test;
use Test::More tests => 7;

BEGIN {
    use_ok('Genome::Model::Command');
}


my $model = Genome::Model::Test->create_basic_mock_model(type_name => 'tester');
ok($model, 'Created mock model');
my $sub_dir = $model->data_directory.'/sub/dir/test';
my $command = Genome::Model::Command->create(
                                             model => $model,
                                         );
isa_ok($command,'Genome::Model::Command');
ok(! -e $sub_dir,$sub_dir .' does not exist');
ok($command->create_directory($sub_dir),'create directory');
ok(-d $sub_dir,$sub_dir .' is a directory');

my $fifo = $sub_dir .'/test_pipe';
`mkfifo $fifo`;
eval{
    $command->create_directory($fifo);
};
ok($@,'failed to create_directory '. $fifo);

exit;


=pod

=head1 Tests

=head1 Disclaimer

 Copyright (C) 2006 Washington University Genome Sequencing Center

 This script is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY
 or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
 License for more details.

=head1 Author(s)

 Eddie Belter <ebelter@watson.wustl.edu>

=cut

#$HeadURL$
#$Id$
