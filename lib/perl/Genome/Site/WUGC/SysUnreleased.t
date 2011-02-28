#! /gsc/bin/perl

use strict;
use warnings;

use above 'Genome';


$Genome::Sys::IS_TESTING=1;
use Test::Class;

Test::Class->runtests(qw/ GenomeUtilityFileSystem::Test /);

exit 0;

#####################################################

package GenomeUtilityFileSystem::Test;

use base 'Test::Class';

use Data::Dumper;
use File::Path;
use File::Temp;
use Test::More;

use POSIX ":sys_wait_h";
use File::Slurp;
use Time::HiRes qw(gettimeofday);

sub startup : Test(startup => 1) {
    my $self = shift;

    require_ok('Genome::Sys');
    my $new_file = $self->_new_file;
    unlink $new_file if -e $new_file;

    return 1;
}

sub _base_test_dir {
    return '/gsc/var/cache/testsuite/data/Genome-Utility-Filesystem';
}

sub _tmpdir {
    my $self = shift;

    unless ( $self->{_tmpdir} ) {
        $self->{_tmpdir} = File::Temp::tempdir(CLEANUP => 1);
    }

    return $self->{_tmpdir};
}

sub _new_file {
    return sprintf('%s/new_file.txt', $_[0]->_tmpdir);
}

sub _existing_file {
    return sprintf('%s/existing_file.txt', _base_test_dir());
}

sub _existing_link {
    return sprintf('%s/existing_link.txt', _base_test_dir());
}

sub _new_link {
    return sprintf('%s/existing_link.txt', _tmpdir(@_));
}

sub _new_dir {
    return sprintf('%s/new_dir', _tmpdir(@_));
}

sub _no_write_dir {
    return sprintf('%s/no_write_dir', _base_test_dir());
}

sub _no_read_dir {
    return sprintf('%s/no_read_dir', _base_test_dir());
}

sub _no_write_file {
    return sprintf('%s/no_write_file.txt', _no_write_dir());
}

sub _no_read_file {
    return sprintf('%s/no_read_file.txt', _no_write_dir());
}

sub test_bzip : Tests {

    my $input_file = "/gsc/var/cache/testsuite/data/Genome-Utility-Filesystem/pileup.cns";
    my $source_file = Genome::Sys->create_temp_file_path();
    #my $source_file = "/gsc/var/cache/testsuite/running_testsuites/t1/pup.cns"; 
    ok(Genome::Sys->copy_file($input_file, $source_file),"Copied test file to temp."); 
   
    my $bzip_file = Genome::Sys->bzip($source_file);
 
    ok (-s $bzip_file, "Bzip file exists.");

    my $bunzip_file = Genome::Sys->bunzip($bzip_file);

    ok (-s $bunzip_file, "Bunzip file exists.");
    ok (-s $bzip_file, "Bzip file exists.");

}

sub test1_file : Tests {
    my $self = shift;

    my $base_dir = $self->_base_test_dir;
    my $existing_file = _existing_file();
    my $new_file = $self->_new_file;

    # Read file
    my $fh = Genome::Sys->open_file_for_reading($existing_file);
    ok($fh, "Opened file ".$existing_file);
    isa_ok($fh, 'IO::File');
    $fh->close;

    # No file
    my $worked = eval { Genome::Sys->open_file_for_reading };
    ok(! $worked, 'open_file_for_reading with no args fails as expected');
    like($@, qr/Can't validate_file_for_reading: No file given/, 'Exception looks right');

    # File no exist 
    $worked = eval { Genome::Sys->open_file_for_reading($new_file) };
    ok(!$worked, 'Tried to open a non existing file for reading');
    like($@, qr/File \($new_file\) does not exist/, 'exception message is correct');
    
    # No read access
    $worked = eval { Genome::Sys->open_file_for_reading( $self->_no_read_file() ) };
    ok(!$worked, 'Try to open a file that can\'t be read from');
    like($@, qr/File .* does not exist/, 'exception message is correct');

    # File is a dir
    $worked = eval { Genome::Sys->open_file_for_reading( $self->_base_test_dir() ) };
    ok(!$worked, 'Try to open a file, but it\'s a directory');
    like($@, qr/File .* exists but is not a plain file/, 'exception message is correct');

    #< APPENDING >#
    # new file
    $fh = Genome::Sys->open_file_for_appending($new_file);
    ok($fh, "Opened file for appending: ".$new_file);
    isa_ok($fh, 'IO::File');
    $fh->close;

    # open existing file
    $fh = Genome::Sys->open_file_for_appending($new_file);
    ok($fh, "Opened file for appending: ".$new_file);
    isa_ok($fh, 'IO::File');
    $fh->close;
    
    # No file
    $worked = eval { Genome::Sys->open_file_for_appending };
    ok(!$worked, 'Tried to open undef file for appending');
    like($@, qr/No append file given/, 'exception message is correct');

    # No write access
    $worked = eval { Genome::Sys->open_file_for_appending( _no_write_file() ) };
    ok(!$worked, 'Try to open a file for appending that can\'t be written to');
    like($@, qr/Do not have WRITE access to directory/, 'exception message is correct');

    # File is a dir
    $worked = eval { Genome::Sys->open_file_for_appending( _base_test_dir() ) };
    ok(!$worked, 'Try to open a file for appending, but it\'s a directory');
    like($@, qr/is a directory and cannot be opend as a file/, 'exception message is correct');
    unlink $new_file;
    #< APPENDING >#

    # WRITING
    $fh = Genome::Sys->open_file_for_writing($new_file);
    ok($fh, "Opened file ".$new_file);
    isa_ok($fh, 'IO::File');
    $fh->close;
    unlink $new_file;

    # No file
    $worked = eval { Genome::Sys->open_file_for_writing };
    ok(!$worked, 'Tried to open undef file');
    like($@, qr/Can't validate_file_for_writing: No file given/, 'exception message is correct');

    # File exists
    $worked = eval { Genome::Sys->open_file_for_writing($existing_file) };
    ok(!$worked, 'Tried to open an existing file for writing');
    like($@, qr/Can't validate_file_for_writing: File \($existing_file\) has non-zero size/, 'exception message is correct');

    # No write access
    $worked = eval { Genome::Sys->open_file_for_writing( _no_write_file() ) };
    ok(!$worked, 'Try to open a file that can\'t be written to');
    like($@, qr/Can't validate_file_for_writing_overwrite: Do not have WRITE access to directory/, 'exception message is correct');

    # File is a dir
    $worked = eval { Genome::Sys->open_file_for_writing( _base_test_dir() ) };
    ok(!$worked, 'Try to open a file, but it\'s a directory');
    like($@, qr/Can't validate_file_for_writing: File .* has non-zero size, refusing to write to it/, 'exception message is correct');

    #< Copying >#
    my $file_to_copy_to = $self->_tmpdir.'/file_to_copy_to';
    ok(
        Genome::Sys->copy_file(_existing_file(), $file_to_copy_to),
        'copy_file',
    );

    eval { Genome::Sys->copy_file(_existing_file(), $file_to_copy_to) };
    ok( $@, 
       'copy_file fails as expected when destination already exists'
    );
    unlink $file_to_copy_to;

    eval { Genome::Sys->copy_file('does_not_exist', $file_to_copy_to) };
    ok( $@, 
        'copy_file fails when there is not file to copy',
    );

    eval { Genome::Sys->copy_file(_existing_file()) };
    ok( $@, 
        'copy_file failed as expected - no destination given',
    );
    
    return 1;
}

sub test2_directory : Test(26) {
    my $self = shift;

    # Real dir
    my $dh = Genome::Sys->open_directory(_base_test_dir());
    ok($dh, "Opened dir: "._base_test_dir());
    isa_ok($dh, 'IO::Dir');

    # No dir
    my $worked = eval { Genome::Sys->open_directory };
    ok (!$worked, 'open_directory with no args fails as expected');
    like($@, qr/Can't open_directory : No such file or directory/, 'Exception message is correct');

    # Dir no exist 
    $worked = eval { Genome::Sys->open_directory('/tmp/no_way_this_exists_for_cryin_out_loud') };
    ok(!$worked, 'Tried to open a non existing directory');
    like($@, qr(Can't open_directory /tmp/no_way_this_exists_for_cryin_out_loud: No such file or directory), 'Exception message is correct');
    
    # Dir is file
    $worked = eval { Genome::Sys->open_directory( sprintf('%s/existing_file.txt', _base_test_dir()) ) };
    ok(!$worked, 'Try to open a directory, but it\'s a file');
    like($@, qr/Can't open_directory .*existing_file.txt: Not a directory/, 'Exception message is correct');

    # Read access
    ok( # good
        Genome::Sys->validate_directory_for_read_access( _base_test_dir() ),
        'validate_directory_for_read_access',
    );
    $worked = eval { Genome::Sys->validate_directory_for_read_access( _no_read_dir() ) };
    ok(!$worked, 'Failed as expected - can\'t read from dir');
    like($@, qr/Directory .* is not readable/, 'Exception message is correct');

    #test data directory is now read-only so make a temporary directory we know will have write access for testing
    my $tmp_dir = File::Temp::tempdir('Genome-Utility-FileSystem-writetest-XXXXX', DIR => '/gsc/var/cache/testsuite/running_testsuites', CLEANUP => 1);

    # Write access
    ok( # good
        Genome::Sys->validate_directory_for_write_access( $tmp_dir ),
        'validate_directory_for_write_access',
    );
    $worked = eval { Genome::Sys->validate_directory_for_write_access( _no_write_dir() ) };
    ok(!$worked, 'Failed as expected - can\'t write to dir');
    like($@, qr/Directory .* is not writable/, 'Exception message is correct');

    # R+W access
    ok( # good
        Genome::Sys->validate_directory_for_read_write_access( $tmp_dir ),
        'validate_directory_for_read_write_access',
    );
    $worked = eval { Genome::Sys->validate_directory_for_read_write_access( _no_read_dir() ) };
    ok(!$worked, 'Failed as expected - can\'t read from dir');
    like($@, qr/Directory .* is not readable/, 'Exception message is correct');

    $worked = eval { Genome::Sys->validate_directory_for_read_write_access( _no_write_dir() ) };
    ok(!$worked, 'Failed as expected - can\'t write to dir');
    like($@, qr/Directory .* is not writable/, 'Exception message is correct');

    my $new_dir = $self->_new_dir;
    ok( Genome::Sys->create_directory($new_dir), "Created new dir: $new_dir");

    my $fifo = $new_dir .'/test_pipe';
    `mkfifo $fifo`;
    $worked = eval { Genome::Sys->create_directory($fifo) };
    ok(!$worked,'failed to create_directory '. $fifo);
    like($@, qr/create_directory for path .* failed/, 'exception message is correct');

    # tree removal
    my $dir_tree_root = $self->_new_dir;
    ok(Genome::Sys->create_directory($dir_tree_root), "Created new dir for tree removal test: $dir_tree_root");
    my $dir_tree_node = $dir_tree_root . '/node';
    ok(Genome::Sys->create_directory($dir_tree_node), "Created new node dir for tree removal test: $dir_tree_node");
    ok(Genome::Sys->remove_directory_tree($dir_tree_root), "removed directory tree at $dir_tree_root successfully");
    ok(!-d $dir_tree_root, "root directory $dir_tree_root is indeed gone");
    return 1;
}

sub test3_symlink : Test(9) {
    my $self = shift;

    my $target = _existing_file();
    my $new_link = $self->_new_link;

    # Good
    ok( Genome::Sys->create_symlink($target, $new_link), 'Created symlink');

    # Link Failures
    my $worked = eval { Genome::Sys->create_symlink($target) };
    ok(!$worked, "create_symlink with no 'link' fails as expected");
    like($@, qr/Can't create_symlink: no 'link' given/, 'exception message is correct');

    $worked = eval { Genome::Sys->create_symlink($target, $new_link) };
    ok(!$worked, 'Failed as expected - create_symlink when link already exists');
    like($@, qr/Link \($new_link\) for target \($target\) already exists/, 'exception message is correct');
    unlink $new_link; # remove to not influence target failures below
    
    # Target Failures
    $worked = eval { Genome::Sys->create_symlink(undef, $new_link) };
    ok(!$worked, 'Failed as expected - create_symlink w/o target');
    like($@, qr/Can't create_symlink: no target given/, 'exception message is correct');

    $worked = eval { Genome::Sys->create_symlink(_tmpdir().'/target', $new_link) };
    ok(!$worked, 'Failed as expected - create_symlink when target does not exist');
    like($@, qr/Cannot create link \($new_link\) to target \(.*target\): target does not exist/, 'exception message is correct');
    
    return 1;
}

sub test4_resource_locking : Test(20) {
    my $bogus_id = '-55555';
    my $tmp_dir = File::Temp::tempdir(CLEANUP => 1);
    my $sub_dir = $tmp_dir .'/sub/dir/test';
    ok(! -e $sub_dir,$sub_dir .' does not exist');
    ok(Genome::Sys->create_directory($sub_dir),'create directory');
    ok(-d $sub_dir,$sub_dir .' is a directory');

    test_locking(successful => 1,
                 message => 'lock resource_id '. $bogus_id,
                 lock_directory => $tmp_dir,
                 resource_id => $bogus_id,);

    test_locking(successful => 0,
                 wait_on_self => 1,
                 message => 'failed lock resource_id '. $bogus_id,
                 lock_directory => $tmp_dir,
                 resource_id => $bogus_id,
                 max_try => 1,
                 block_sleep => 3,);
    
    ok(Genome::Sys->unlock_resource(
                                                    lock_directory => $tmp_dir,
                                                    resource_id => $bogus_id,
                                                ), 'unlock resource_id '. $bogus_id);
    my $init_lsf_job_id = $ENV{'LSB_JOBID'};
    $ENV{'LSB_JOBID'} = 1;
    test_locking(successful => 1,
                 message => 'lock resource with bogus lsf_job_id',
                 lock_directory => $tmp_dir,
                 resource_id => $bogus_id,);
    test_locking(
                 successful=> 1,
                 wait_on_self => 1,
                 message => 'lock resource with removing invalid lock with bogus lsf_job_id first',
                 lock_directory => $tmp_dir,
                 resource_id => $bogus_id,
                 max_try => 1,
                 block_sleep => 3,);
    ok(Genome::Sys->unlock_resource(
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
          ok(Genome::Sys->lock_resource(
                                                        lock_directory => $tmp_dir,
                                                        resource_id => $bogus_id,
                                                    ),'lock resource with real lsf_job_id');
          ok(!Genome::Sys->lock_resource(
                                                         lock_directory => $tmp_dir,
                                                         resource_id => $bogus_id,
                                                         max_try => 1,
                                                         block_sleep => 3,
                                                     ),'failed lock resource with real lsf_job_id blocking');
          ok(Genome::Sys->unlock_resource(
                                                          lock_directory => $tmp_dir,
                                                          resource_id => $bogus_id,
                                                      ), 'unlock resource_id '. $bogus_id);
      };
}

sub test_race_condition : Test(60) {
    my $base_dir = File::Temp::tempdir("Genome-Utility-FileSystem-RaceCondition-XXXX", DIR=>"/gsc/var/cache/testsuite/running_testsuites/", CLEANUP=>1);
    
    my $resource = "/tmp/Genome-Utility-Filesystem.test.resource.$$";
    
    if (defined $ENV{'LSB_JOBID'} && $ENV{'LSB_JOBID'} eq "1") {
        delete $ENV{'LSB_JOBID'}; 
    }

    my @pids;

    my $children = 20;

    for my $child (1...$children) {
       my $pid;
       if ($pid = fork()) {
            push @pids, $pid;
        } else {
            do_race_lock($child,$resource,$base_dir);
        }
    }

    for my $pid (@pids) {
        my $status = waitpid $pid, 0;
    }

    my @event_log;

    for my $child (1...$children) {
        my $report_log = "$base_dir/$child";
        ok (-e $report_log, "Expected to see a report for $report_log");
        if (!-e $report_log) {
            die "Expected output file did not exist";
        } else {
            my @lines = read_file($report_log);
            for (@lines) {
                my ($time, $event, $pid, $msg) = split /\t/;
                my $report = {etime => $time, event=>$event, pid=>$pid, msg=>$msg};
                push @event_log, $report;
           } 
       }
    }
    
    ok(scalar @event_log  == 2*$children, "read in got 2 lock/unlock events for each child.");

    @event_log = sort {$a->{etime} <=> $b->{etime}} @event_log;
    my $last_event;
    for (@event_log) {
        if (defined $last_event) {
            my $valid_next_event = ($last_event eq "UNLOCK_SUCCESS" ? "LOCK_SUCCESS" : "UNLOCK_SUCCESS");
            ok($_->{event} eq $valid_next_event, sprintf("Last lock event was a %s so we expected a to see %s, got a %s", $last_event, $valid_next_event, $_->{event}));
        }
        $last_event = $_->{event};
        printf("%s\t%s\t%s\n", $_->{etime}, $_->{pid}, $_->{event});
    }
}

sub do_race_lock {
    my $output_offset = shift;
    my $resource = shift;
    my $tempdir = shift;

    my $output_file = $tempdir . "/" . $output_offset;
    my $fh = new IO::File(">>$output_file");

    my $lock = Genome::Sys->lock_resource(
        resource_lock => $resource,
        block_sleep   => 1
    );
    unless ($lock) {
        print_event($fh, "LOCK_FAIL", "Failed to get a lock" );
        $fh->close;
        exit(1);
    }
    
    #sleep for half a second before printing this, to let a prior process catch up with
    #printing its "unlocked" message.  sometimes we get a lock (properly) in between the time
    #someone else has given up the lock, but before it had a chance to report that it did.
    select(undef, undef, undef, 0.50);
    print_event($fh, "LOCK_SUCCESS", "Successfully got a lock" );
    sleep 2;

    unless (Genome::Sys->unlock_resource(resource_lock => $resource)) {
        print_event($fh, "UNLOCK_FAIL", "Failed to release a lock" );
        $fh->close;
        exit(1);
    }
    print_event($fh, "UNLOCK_SUCCESS", "Successfully released my lock" );

    $fh->close;
    exit(0);
}

sub print_event {
        my $fh = shift;
        my $info = shift;
        my $msg  = shift;

        my ( $seconds, $ms ) = gettimeofday();
        $ms = sprintf("%06d",$ms);
        my $time = "$seconds.$ms";

        my $tp = sprintf( "%s\t%s\t%s\t%s", $time, $info, $$, $msg );

        print $fh $tp, "\n";
        print $tp, "\n";
}


sub test_locking {
    my %params = @_;
    my $successful = delete $params{successful};
    die unless defined($successful);
    my $message = delete $params{message};
    die unless defined($message);

    my $lock = Genome::Sys->lock_resource(%params);
    if ($successful) {
        ok($lock,$message);
        if ($lock) { return $lock; }
    } else {
        ok(!$lock,$message);
    }
    return;
}

sub test_md5sum : Test(1) {
    my $dir = File::Temp->tempdir("Genome-Utility-Filesystem-t-md5sum-XXXX",CLEANUP=>1);
   
    open (F, ">$dir/md5test"); 
    print F "ABCDEF\n";
    close F;

    my $expected_md5sum = "f6674e62795f798fe2b01b08580c3fdc";

    is(Genome::Sys->md5sum("$dir/md5test"),$expected_md5sum, "md5sum: matches what we expected");

}

sub test_directory_size_recursive : Test(1) {
    my $dir = File::Temp->tempdir("Genome-Utility-Filesystem-t-directory-size-recursive-XXXX", CLEANUP=>1);
    mkdir($dir."/testing",0777);
    mkdir($dir."/testing2",0777);
    open (F, ">$dir/testing/file1");
    print F "1234567890\n";
    close F;
    open (F, ">$dir/testing2/file2");
    print F "1234567890\n";
    close F;
    my $size = Genome::Sys->directory_size_recursive($dir);
    my $expected_size = 22;

    is($size,$expected_size,"directory_size_recursive returned the correct size for the test case");
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
