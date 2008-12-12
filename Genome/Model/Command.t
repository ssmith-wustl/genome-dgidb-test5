#! /gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Test::More tests => 8;

BEGIN {
    use_ok('Genome::Model::Command');
}

my $bogus_id = 0;
my $pp = Genome::ProcessingProfile->create_mock(
                                                id => --$bogus_id,
                                            );
isa_ok($pp,'Genome::ProcessingProfile');

my $model = Genome::Model->create_mock(
                                       id => --$bogus_id,
                                       genome_model_id => $bogus_id,
                                       processing_profile_id => $pp->id,
                                       last_complete_build_id => undef,
                                       subject_name => 'test_subject_name',
                                       subject_type => 'test_subject_type',
                                       name => 'test_model_name',
                                   );
isa_ok($model,'Genome::Model');

my $tmp_dir = File::Temp::tempdir(CLEANUP => 1);
my $sub_dir = $tmp_dir .'/sub/dir/test';
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
