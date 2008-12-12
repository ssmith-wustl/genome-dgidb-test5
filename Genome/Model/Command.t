#! /gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Test::More tests => 15;

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
my $command_1 = Genome::Model::Command->create(
                                             model => $model,
                                         );
isa_ok($command_1,'Genome::Model::Command');
ok(! -e $sub_dir,$sub_dir .' does not exist');
ok($command_1->create_directory($sub_dir),'create directory');
ok(-d $sub_dir,$sub_dir .' is a directory');

my $command_2 = Genome::Model::Command->create(
                                               model => $model,
                                           );
isa_ok($command_2,'Genome::Model::Command');

ok($command_1->lock_resource(
                             lock_directory => $tmp_dir,
                             resource_id => --$bogus_id,
                         ),'command 1 lock resource_id '. $bogus_id);
my $expected_lock_info = $tmp_dir .'/'. $bogus_id .'.lock/info';
ok(-f $expected_lock_info,'lock info file found '. $expected_lock_info);
eval{
    $command_1->create_directory($expected_lock_info);
};
ok($@,'failed to create_directory '. $expected_lock_info);

eval {
    $command_2->lock_resource(
                              lock_directory => $tmp_dir,
                              resource_id => $bogus_id,
                              max_try => 1,
                              block_sleep => 3,
                          );
};
ok($@,'command 2 failed lock resource_id '. $bogus_id);

ok($command_1->unlock_resource(
                               lock_directory => $tmp_dir,
                               resource_id => $bogus_id,
                           ), 'command 1 unlock resource_id '. $bogus_id);
ok($command_2->lock_resource(
                             lock_directory => $tmp_dir,
                             resource_id => $bogus_id,
                         ),'command 2 lock resource_id '. $bogus_id);
ok($command_2->unlock_resource(
                               lock_directory => $tmp_dir,
                               resource_id => $bogus_id,
                           ), 'command 2 unlock resource_id '. $bogus_id);

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
