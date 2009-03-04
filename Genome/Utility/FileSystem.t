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
    my $new_file = _new_file();
    unlink $new_file if -e $new_file;
}

sub _base_test_dir {
    return '/gsc/var/cache/testsuite/data/Genome-Utility-Filesystem';
}

sub _new_file {
    return sprintf('%s/new_file.txt', _base_test_dir());
}

sub _existing_file {
    return sprintf('%s/existing_file.txt', _base_test_dir());
}

sub _existing_link {
    return sprintf('%s/existing_link.txt', _base_test_dir());
}

sub _no_write_dir {
    return sprintf('%s/no_write_dir', _base_test_dir());
}

sub _no_write_file {
    return sprintf('%s/no_write_file.txt', _no_write_dir());
}

sub _no_read_file {
    return sprintf('%s/no_read_file.txt', _no_write_dir());
}

sub test1_file : Test(12) {
    my $self = shift;

    my $existing_file = _existing_file();
    my $new_file = _new_file();

    # Read file
    my $fh = Genome::Utility::FileSystem->open_file_for_reading($existing_file);
    ok($fh, "Opened file ".$existing_file);
    isa_ok($fh, 'IO::File');
    $fh->close;

    # No file
    ok(!Genome::Utility::FileSystem->open_file_for_reading, 'Tried to open undef file');

    # File no exist 
    ok(
        !Genome::Utility::FileSystem->open_file_for_reading($new_file),
        'Tried to open a non existing file for reading'
    );
    
    # No read access
    ok(
        !Genome::Utility::FileSystem->open_file_for_reading( _no_read_file() ),
        'Try to open a file that can\'t be read from',
    );

    # File is a dir
    ok(
        !Genome::Utility::FileSystem->open_file_for_reading( _base_test_dir() ),
        'Try to open a file, but it\'s a directory',
    );

    # Write file
    my $fh = Genome::Utility::FileSystem->open_file_for_writing($new_file);
    ok($fh, "Opened file ".$new_file);
    isa_ok($fh, 'IO::File');
    $fh->close;
    unlink $new_file;

    # No file
    ok(!Genome::Utility::FileSystem->open_file_for_writing, 'Tried to open undef file');

    # File exists
    ok(
        !Genome::Utility::FileSystem->open_file_for_writing($existing_file), 
        'Tried to open an existing file for writing'
    );

    # No write access
    ok(
        !Genome::Utility::FileSystem->open_file_for_writing( _no_write_file() ),
        'Try to open a file that can\'t be written to',
    );

    # File is a dir
    ok(
        !Genome::Utility::FileSystem->open_file_for_writing( _base_test_dir() ),
        'Try to open a file, but it\'s a directory',
    );

    return 1;
}

sub test2_directory : Test(8) {
    my $self = shift;

    # Real dir
    my $dh = Genome::Utility::FileSystem->open_directory(_base_test_dir());
    ok($dh, "Opened dir: "._base_test_dir());
    isa_ok($dh, 'IO::Dir');

    # No dir
    ok(!Genome::Utility::FileSystem->open_directory, 'Tried to open undef directory');

    # Dir no exist 
    ok(
        !Genome::Utility::FileSystem->open_directory('/tmp/no_way_this_exists_for_cryin_out_loud'), 
        'Tried to open a non existing directory'
    );
    
    # Dir is file
    ok(
        !Genome::Utility::FileSystem->open_directory( sprintf('%s/existing_file.txt', _base_test_dir()) ),
        'Try to open a directory, but it\'s a file',
    );

    my $base_new_dir = sprintf('%s/new', _base_test_dir());
    my $new_dir = sprintf('%s/dir/with/sub/dirs/', $base_new_dir);
    Genome::Utility::FileSystem->create_directory($new_dir);
    ok(-d $new_dir, "Created new dir: $new_dir");
    my $fifo = $new_dir .'/test_pipe';
    `mkfifo $fifo`;
    ok(!Genome::Utility::FileSystem->create_directory($fifo),'failed to create_directory '. $fifo);
    ok(File::Path::rmtree($base_new_dir), "Removed base new dir: $base_new_dir");

    return 1;
}

sub test3_resource_locking : Test(19) {
    my $bogus_id = '-55555';
    my $tmp_dir = File::Temp::tempdir(CLEANUP => 1);
    my $sub_dir = $tmp_dir .'/sub/dir/test';
    ok(! -e $sub_dir,$sub_dir .' does not exist');
    ok(Genome::Utility::FileSystem->create_directory($sub_dir),'create directory');
    ok(-d $sub_dir,$sub_dir .' is a directory');

    test_locking(successful => 1,
                 message => 'lock resource_id '. $bogus_id,
                 lock_directory => $tmp_dir,
                 resource_id => $bogus_id,);

    my $expected_lock_info = $tmp_dir .'/'. $bogus_id .'.lock/info';
    ok(-f $expected_lock_info,'lock info file found '. $expected_lock_info);
    ok(!Genome::Utility::FileSystem->create_directory($expected_lock_info),
       'failed to create_directory '. $expected_lock_info);

    test_locking(successful => 0,
                 message => 'failed lock resource_id '. $bogus_id,
                 lock_directory => $tmp_dir,
                 resource_id => $bogus_id,
                 max_try => 1,
                 block_sleep => 3,);
    
    ok(Genome::Utility::FileSystem->unlock_resource(
                                                    lock_directory => $tmp_dir,
                                                    resource_id => $bogus_id,
                                                ), 'unlock resource_id '. $bogus_id);
    my $lock = test_locking(successful => 1,
                            message => 'lock resource_id '. $bogus_id,
                            lock_directory => $tmp_dir,
                            resource_id => $bogus_id,);
    my $file_to_break_unlocking = $lock .'/break_stuff';
    my $break_unlock_fh = Genome::Utility::FileSystem->open_file_for_writing($file_to_break_unlocking);
    print $break_unlock_fh "This will break the unlock";
    $break_unlock_fh->close;
    ok(-s $file_to_break_unlocking,'file to break unlocking exists with size');
    ok(!Genome::Utility::FileSystem->unlock_resource(
                                                     lock_directory => $tmp_dir,
                                                     resource_id => $bogus_id,
                                                 ), 'failed unlock because of junk file');
    ok(rename($file_to_break_unlocking,$lock.'/info'),'copy file breaking unlock to lock info file name');
    ok(Genome::Utility::FileSystem->unlock_resource(
                                                     lock_directory => $tmp_dir,
                                                     resource_id => $bogus_id,
                                                 ), 'unlock works after removing junk file');
    
    my $init_lsf_job_id = $ENV{'LSB_JOBID'};
    $ENV{'LSB_JOBID'} = 1;
    test_locking(successful => 1,
                 message => 'lock resource with bogus lsf_job_id',
                 lock_directory => $tmp_dir,
                 resource_id => $bogus_id,);
    test_locking(
                 successful=> 1,
                 message => 'lock resource with removing invalid lock with bogus lsf_job_id first',
                 lock_directory => $tmp_dir,
                 resource_id => $bogus_id,
                 max_try => 1,
                 block_sleep => 3,);
    ok(Genome::Utility::FileSystem->unlock_resource(
                                                    lock_directory => $tmp_dir,
                                                    resource_id => $bogus_id,
                                                ), 'unlock resource_id '. $bogus_id);
    # TODO: add skip test but if we are on a blade, lets see that the locking works correctly
    # Above the test is that old bogus locks can get removed when the lsf_job_id no longer exists
    # We should test that while an lsf_job_id does exist (ie. our current job) we still hold the lock
    SKIP: {
          skip 'only test the state of the lsf job if we are running on a blade with a job id',
              3 unless ($init_lsf_job_id);
          $ENV{'LSB_JOBID'} = $init_lsf_job_id;
          ok(Genome::Utility::FileSystem->lock_resource(
                                                        lock_directory => $tmp_dir,
                                                        resource_id => $bogus_id,
                                                    ),'lock resource with real lsf_job_id');
          ok(!Genome::Utility::FileSystem->lock_resource(
                                                         lock_directory => $tmp_dir,
                                                         resource_id => $bogus_id,
                                                         max_try => 1,
                                                         block_sleep => 3,
                                                     ),'failed lock resource with real lsf_job_id blocking');
          ok(Genome::Utility::FileSystem->unlock_resource(
                                                          lock_directory => $tmp_dir,
                                                          resource_id => $bogus_id,
                                                      ), 'unlock resource_id '. $bogus_id);
      };
}

sub test_locking {
    my %params = @_;
    my $successful = delete $params{successful};
    die unless defined($successful);
    my $message = delete $params{message};
    die unless defined($message);

    my $lock = Genome::Utility::FileSystem->lock_resource(%params);
    if ($successful) {
        ok($lock,$message);
        if ($lock) { return $lock; }
    } else {
        ok(!$lock,$message);
    }
    return;
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
