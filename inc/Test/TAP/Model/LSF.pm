package Test::TAP::Model::LSF;

use strict;
use warnings FATAL => 'all';
use Moose;
use Path::Class ();
use YAML::Syck;
use English;
use Test::Harness::Results;

extends 'Test::TAP::Model::Visual';

has 'base_dir' => (
    is       => 'rw',
    isa      => 'Path::Class::Dir',
);

has 'smoke_dir' => (
    is       => 'ro',
    isa      => 'Path::Class::Dir',
    required => 1,
    lazy     => 1,
    default  => sub {
        my $self = shift;
        return $self->base_dir->subdir('smoke_db');
    },
);

has 'raw_result_files' => (
    is       => 'ro',
    isa      => 'HashRef',
    required => 1,
    lazy     => 1,
    default  => sub { {} },
);

has 'status_fh' => (
    is       => 'rw',
);

# HACK: fool Test::Harness into using our
# already populated subclass object of Test::Harness::Straps
my $singleton;
sub new {
    my $class = shift;
    return $singleton ||= $class->SUPER::new(@_);
}

sub add_raw_result_file {
    my ( $self, $file, $object ) = @_;
    my $raw = $self->raw_result_files;
    $raw->{$file} = $object;
}

sub _status {
    my ($self, @msg) = @_;
    my $fh = $self->status_fh;
    for my $m (@msg) {
        $fh->print("$m\n");
    }
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
    $stdout_file->parent->mkpath( 0, 0775 );
    my $script
        = $self->base_dir->subdir('util')->file('run_single_test.pl');
    my $rcmd        = "$EXECUTABLE_NAME $script $test $yaml_file";
#    my $rcmd        = "$EXECUTABLE_NAME -d:ptkdb $script $test $yaml_file";

    my $raw = Test::TAP::Model::LSF::Raw->new(
        test_file   => $test,
        stdout_file => $stdout_file,
        stderr_file => $stderr_file,
        yaml_file   => $yaml_file,
    ) or die;
    $self->add_raw_result_file($test, $raw);

    local $ENV{PERL5LIB} = $self->_INC2PERL5LIB;
    my $cmd = "bsub -q short -N -o $stdout_file -e $stderr_file $rcmd";
    $self->_status("dispatching $test...");
    my @out = `$cmd 2>&1`;
    $self->_status(@out);
    if ($?) {
        die "command failed: $cmd";
    }
}

sub gather_results {
    my ( $self, @tests ) = @_;
    $self->wait_for_results;

    # read yaml files
    my $raw = $self->raw_result_files;
    my @yaml_files = map { $raw->{$_}->yaml_file } @tests;
    for my $file (@yaml_files) {
        $self->_status("loading $file");
        my $chunk = LoadFile($file)
            or die "can't parse chunk ($file)";
        $self->_status("pushing $file data");
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
            $self->_status("done " . $found->test_file);
        }
        else {
            sleep 3;
        }
    }
}

# called by Test::Harness::runtests
# we simply return the Test::Harness::Results object what we
# picked up from the YAML file in gather_results()
sub analyze_file {
    my ( $self, $file ) = @_;

    for my $f ( @{$self->{meat}{test_files}} ) {
        if ($f->{file} eq $file) {
            return $f->{results};
        }
    }
    die "no results for $file";
}

sub emit {
    my ( $self, $file ) = @_;
    DumpFile( $file, {
        meat => $self->structure,
        map { $_ => $self->{"_$_"} }
            qw( build_info smoker config revision timing )
    });
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

