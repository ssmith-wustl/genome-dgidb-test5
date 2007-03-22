package Test::TAP::Model::LSF;

use strict;
use warnings FATAL => 'all';
use Moose;
use Path::Class ();
use YAML::Syck;
use File::chdir '$CWD';
use English;

extends 'Test::TAP::Model::Visual';

has 'base_dir' => (
    is       => 'rw',
    isa      => 'Path::Class::Dir',
    required => 1,
);

has 'callback' => (
    is      => 'rw',
    isa     => 'CodeRef',
);

has 'smoke_dir' => (
    is       => 'ro',
    isa      => 'Path::Class::Dir',
    required => 1,
    lazy     => 1,
    default  => sub { Path::Class::dir($CWD)->subdir('smoke_db') },
);

has 'test_files' => (
    is       => 'ro',
    isa      => 'ArrayRef',
    required => 1,
    lazy     => 1,
    default  => sub { [] },
);

sub add_test_file {
    my ($self, $file) = @_;
    my $files = $self->test_files;
    push @$files, $file;
}

sub event {
    my $self = shift;
    my $cb = $self->callback or return;
    $cb->(@_);
}

sub run_tests {
    my ($self, @tests) = @_;
    $self->{_timing}{start} = time;

    $self->smoke_dir->rmtree;
    for my $test (@tests) {
        $self->dispatch_test($test);
    }

    $self->gather_results;
    $self->{_timing}{end} = time;
    $self->{_timing}{duration} =
        $self->{_timing}{end} - $self->{_timing}{start};
};

sub dispatch_test {
    my ( $self, $test ) = @_;

    my $smoke_dir   = $self->smoke_dir;
    my $stdout_file = $smoke_dir->file("$test.stdout");
    my $stderr_file = $smoke_dir->file("$test.stderr");
    my $yaml_file   = $smoke_dir->file("$test.yml");
    my $script      = $self->base_dir->file('run_single_test.pl');
    my $rcmd        = "$EXECUTABLE_NAME $script $test $yaml_file";

    my $test_file = Test::TAP::Model::LSF::TestFile->new(
        test_file   => $test,
        stdout_file => $stdout_file,
        stderr_file => $stderr_file,
        yaml_file   => $yaml_file,
    ) or die;
    $self->add_test_file($test_file);

    local $ENV{PERL5LIB} = $self->_INC2PERL5LIB;
    my $cmd = "bsub -q short -N -o $stdout_file -e $stderr_file $rcmd";
    $self->event("dispatching $test...\n");
    my @out = `$cmd 2>&1`;
    $self->event("@out\n");
    if ($?) {
        die "command failed: $cmd";
    }
}

sub wait_for_results {
    my ($self) = @_;
    my %files = map { $_->test_file => $_ } @{ $self->test_files };
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

sub gather_results {
    my ($self) = @_;
    $self->wait_for_results;
    my @files = map { $_->yaml_file } @{ $self->test_files };
    for my $file (@files) {
        $self->event("loading $file\n");
        my $chunk = LoadFile($file)
            or die "can't parse chunk ($file)";
        $self->event("pushing $file data\n");
        push @{ $self->{meat}{test_files} }, @{ $chunk->{test_files} };
    }
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

package Test::TAP::Model::LSF::TestFile;

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

