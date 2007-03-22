package Test::TAP::Model::LSF;

use strict;
use warnings FATAL => 'all';
use Moose;
use Path::Class ();
use YAML::Syck;
use File::chdir '$CWD';
use English;
use Test::Harness::Results;

extends 'Test::TAP::Model::Visual';

has 'base_dir' => (
    is       => 'rw',
    isa      => 'Path::Class::Dir',
    required => 1,
);

has 'smoke_dir' => (
    is       => 'ro',
    isa      => 'Path::Class::Dir',
    required => 1,
    lazy     => 1,
    default  => sub { Path::Class::dir($CWD)->subdir('smoke_db') },
);

has 'raw_result_files' => (
    is       => 'ro',
    isa      => 'HashRef',
    required => 1,
    lazy     => 1,
    default  => sub { {} },
);

sub add_raw_result_file {
    my ( $self, $file, $object ) = @_;
    my $raw = $self->raw_result_files;
    $raw->{$file} = $object;
}

sub event {
    my $self = shift;
    print shift;
#    my $cb = $self->callback or return;
#    $cb->(@_);
}

sub run_tests {
    my ($self, @tests) = @_;
    $self->smoke_dir->rmtree;
    $self->SUPER::run_tests(@tests);
    $self->gather_results(@tests);
}

sub run_test {
    my ( $self, $test ) = @_;
    $self->dispatch_test($test);
}

sub dispatch_test {
    my ( $self, $test ) = @_;

    my $smoke_dir   = $self->smoke_dir;
    my $stdout_file = $smoke_dir->file("$test.stdout");
    my $stderr_file = $smoke_dir->file("$test.stderr");
    my $yaml_file   = $smoke_dir->file("$test.yml");
    my $script      = $self->base_dir->file('run_single_test.pl');
    my $rcmd        = "$EXECUTABLE_NAME $script $test $yaml_file";

    my $raw = Test::TAP::Model::LSF::Raw->new(
        test_file   => $test,
        stdout_file => $stdout_file,
        stderr_file => $stderr_file,
        yaml_file   => $yaml_file,
    ) or die;
    $self->add_raw_result_file($test, $raw);

    local $ENV{PERL5LIB} = $self->_INC2PERL5LIB;
    my $cmd = "bsub -q short -N -o $stdout_file -e $stderr_file $rcmd";
    $self->event("dispatching $test...\n");
    my @out = `$cmd 2>&1`;
    $self->event("@out\n");
    if ($?) {
        die "command failed: $cmd";
    }
}

sub gather_results {
    my ( $self, @tests ) = @_;
    $self->wait_for_results;

    my $raw = $self->raw_result_files;
    for my $file (@tests) {
        my $stdout_file = $raw->{$file}->stdout_file;
        my @stdout = $stdout_file->openr->getlines;
        my $results = $self->analyze_fh( $file, \@stdout );
        $results ||= Test::Harness::Results->new;
        my $test_file = $self->start_file($file);
        $test_file->{results} = $results;
    }

    # read yaml files
    my @yaml_files = map { $raw->{$_}->yaml_file } @tests;
    for my $file (@yaml_files) {
        $self->event("loading $file\n");
        my $chunk = LoadFile($file)
            or die "can't parse chunk ($file)";
        $self->event("pushing $file data\n");
        push @{ $self->{meat}{test_files} }, @{ $chunk->{test_files} };
    }
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
            $self->event($found->test_file . "\n");
        }
        else {
            sleep 3;
        }
    }
}

sub run_single_file {
    my ($self, $file) = @_;
    return $self->SUPER::run_test($file);
}

sub emit_chunk {
    my ( $self, $result_file ) = @_;
    DumpFile( $result_file, $self->structure );
}

sub emit {
    my ( $self, $file ) = @_;
    DumpFile( $file, {
        meat => $self->structure,
        map { $_ => $self->{"_$_"} }
            qw( build_info smoker config revision timing )
    });
}

# repeat the line to STDOUT
sub _analyze_line {
    my $self = shift;
    print $_[0];
    return $self->SUPER::_analyze_line(@_);
}

package Test::TAP::Model::LSF::Raw;

use strict;
use warnings FATAL => 'all';
use Moose;
use Path::Class ();

has 'test_file' => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has 'stdout_file' => (
    is       => 'ro',
    isa      => 'Path::Class::File',
    required => 1,
);

has 'stderr_file' => (
    is       => 'ro',
    isa      => 'Path::Class::File',
    required => 1,
);

has 'yaml_file' => (
    is       => 'ro',
    isa      => 'Path::Class::File',
    required => 1,
);

sub is_finished_running {
    my $self = shift;
    return ( -e $self->yaml_file && -e $self->stdout_file );

}

1;

__END__

