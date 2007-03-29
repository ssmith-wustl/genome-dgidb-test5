package Test::TAP::Model::LSF;

use strict;
use warnings FATAL => 'all';
use Moose;
use Path::Class ();
use YAML::Syck;
use English;
use File::chdir '$CWD';
use Test::Harness::Results;

extends 'Test::TAP::Model::Smoke';

sub cmd_for_test {
    my ( $self, $raw ) = @_;
    my $script
        = $self->base_dir->subdir('util')->file('run_single_test.pl');
    my $stdout = $raw->stdout_file;
    my $stderr = $raw->stderr_file;
    my $yaml   = $raw->yaml_file;
    my $test   = $raw->test_file;
    my $cmd = "bsub -q seqmgr-long -N -o $stdout -e $stderr -R 'select[type==LINUX86]' $EXECUTABLE_NAME $script $test $yaml";
    return $cmd;
}

sub wait_for_results {
    my ($self) = @_;
    my %files = %{ $self->raw_result_files };
    while ( keys %files ) {
        my $found;
        for my $file ( values %files ) {
            if ( $file->is_finished_running ) {
                $found = $file;
                last;
            }
        }
        if ($found) {
            delete $files{ $found->test_file };
            # TODO: make this do the harness-y thing instead
            $self->_status("done " . $found->test_file);
        }
        else {
            sleep 3;
        }
    }
}

1;

__END__

