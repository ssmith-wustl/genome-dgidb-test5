package Test::TAP::Model::Smoke;

use strict;
use warnings FATAL => 'all';
use Moose;
use Path::Class ();
use YAML::Syck;
use English;
use File::chdir '$CWD';
use Test::Harness::Results;

extends 'Test::TAP::Model::Visual';

has 'base_dir' => (
    is       => 'ro',
    isa      => 'Path::Class::Dir',
    required => 1,
    lazy     => 1,
    default  => sub { Path::Class::dir($CWD); },
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

has 'handler' => (
    is       => 'rw',
    isa      => 'CodeRef',
    required => 1,
    default  => sub { sub { } },
);

# HACK: fool Test::Harness into using our
# already populated subclass object of Test::Harness::Straps
my $singleton;
sub new {
    my $class = shift;
    return $singleton ||= $class->SUPER::new(@_);
}

# HACK: this is borked in Test::TAP::Model
sub new_with_struct {
    my $pkg  = shift;
    my $meat = shift;
    my $self = $pkg->new(@_);
    $self->{meat} = $meat;
    $self;
}

sub add_raw_result_file {
    my ( $self, $file, $object ) = @_;
    my $raw = $self->raw_result_files;
    $raw->{$file} = $object;
}

sub _status {
    my ($self, @msg) = @_;
    my $cb = $self->handler;
    for my $m (@msg) {
        $cb->("$m\n");
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
    my $smoke_dir   = $self->smoke_dir;
    my $stdout_file = $smoke_dir->file("$test.stdout");
    my $stderr_file = $smoke_dir->file("$test.stderr");
    my $yaml_file   = $smoke_dir->file("$test.yml");
    $stdout_file->parent->mkpath( 0, 0775 );
#    my $rcmd = "$EXECUTABLE_NAME $script $test $yaml_file";
#    my $rcmd = "$EXECUTABLE_NAME -d:ptkdb $script $test $yaml_file";
    my $raw = Test::TAP::Model::LSF::Raw->new(
        test_file   => $test,
        stdout_file => $stdout_file,
        stderr_file => $stderr_file,
        yaml_file   => $yaml_file,
    ) or die;
    $self->add_raw_result_file($test, $raw);
    local $ENV{PERL5LIB} = $self->_INC2PERL5LIB;

    $self->_status("dispatching $test...");
    my $cmd = $self->cmd_for_test($raw);
    my @out = `$cmd 2>&1`;
    $self->_status(@out);
    if ($?) {
        die "command failed: $cmd";
    }
}

sub cmd_for_test {
    my ( $self, $raw ) = @_;
    my $script
        = $self->base_dir->subdir('util')->file('run_single_test.pl');
    my $stdout = $raw->stdout_file;
    my $stderr = $raw->stderr_file;
    my $yaml = $raw->yaml_file;
    my $test = $raw->test_file;
    my $cmd = "$EXECUTABLE_NAME $script $test $yaml > $stdout 2> $stderr";
    return $cmd;
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
}

sub status {
    my $self       = shift;
    my $test_files = $self->{meat}{test_files};
    my %status;
    for my $test (@$test_files) {
        my $pf = $test->{results}->passing ? 'PASS' : 'FAIL';
        $status{ $test->{file} } = $pf;
    }
    return %status;
}


# called by Test::Harness::runtests
# we simply return the Test::Harness::Results object that we
# picked up from the YAML file in gather_results()
sub analyze_file {
    my ( $self, $file ) = @_;

    for my $f ( @{$self->{meat}{test_files}} ) {
        if ($f->{file} eq $file) {
            my @events=@{$f->{events}};
            if(@events) {
                $self->{'next'}=$events[-1]{num}+1;
            } else {
                $self->{'next'}=0;
            }
            return $f->{results};
        }
    }
    die "no results for $file";
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

