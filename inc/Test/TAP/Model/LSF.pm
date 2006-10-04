package Test::TAP::Model::LSF;

use strict;
use warnings;
use Moose;
use Path::Class ();
use File::Temp ();
use YAML ();

extends 'Test::TAP::Model::Visual';

has 'base_dir' => (
    is       => 'rw',
    isa      => 'Path::Class::Dir',
    required => 1,
);

has 'result_iteration' => (
    is      => 'rw',
    isa     => 'Int',
    default => 0,
);

has 'callback' => (
    is      => 'rw',
    isa     => 'CodeRef',
);

sub event {
    my $self = shift;
    my $cb = $self->callback or return;
    $cb->(@_);
}

sub run_tests {
    my ($self, @tests) = @_;
    $self->{_timing}{start} = time;

    $self->result_iteration(0);

    for my $test (@tests) {
        $self->dispatch_test($test);
    }

    $self->gather_results;
    $self->{_timing}{end} = time;
    $self->{_timing}{duration} =
        $self->{_timing}{end} - $self->{_timing}{start};
};

sub temp_dir {
    my $self = shift;
    if ( !$self->{temp_dir} ) {
        my $d = File::Temp::tempdir(
            '_smoke_lsf.XXXXX',
            DIR      => $self->base_dir,
            CLEANUP  => 1
        );
        $self->{temp_dir} = Path::Class::dir($d);
    }
    return $self->{temp_dir};
}

sub remote_cmd {
    my ($self, $test) = @_;
    my $cmd = $self->base_dir->file('remote_lsf.pl');
    my $nrf = $self->next_result_file;
    return "$^X $cmd $test $nrf";
#    return "$^X -d:ptkdb $cmd $test $nrf";
}

sub next_result_file {
    my $self = shift;
    my $it = $self->result_iteration;
    $it++;
    $self->result_iteration($it);
    my $dir = $self->temp_dir;
    return $dir->file("$it.yml");
}

sub dispatch_test {
    my ($self, $test) = @_;
    my $rcmd = $self->remote_cmd($test);
    my $err = $self->temp_dir->file($self->result_iteration . '.out');
    local $ENV{PERL5LIB} = $self->_INC2PERL5LIB;
    my $cmd = "bsub -q short -oo $err $rcmd";
#    my $cmd = "$rcmd";
    $self->event("dispatching $test...\n");
    my @out = `$cmd 2>&1`;
    $self->event("@out\n");
    if ($?) {
        die "command failed: $cmd";
    }
}

sub wait_for_results {
    my ($self) = @_;
    my $dir = $self->temp_dir;
    my $it = $self->result_iteration;
    $self->event("waiting for jobs to finish.");
    while (1) {
        my $all_done = 1;
        for my $i ( 1 .. $it ) {
            my $file = $dir->file("$i.yml");
            if ( !-f $file ) {
                $all_done = 0;
                last;
            }
        }
        if ($all_done) {
            $self->event("finished\n");
            return;
        }
        $self->event(".");
        sleep 5;
    }
}

sub gather_results {
    my ($self) = @_;
    $self->wait_for_results;
    my $dir = $self->temp_dir;
    my $it = $self->result_iteration;
    for my $i ( 1 .. $it ) {
        my $file  = $dir->file("$i.yml");
        my $chunk = YAML::LoadFile($file)
            or die "can't parse chunk ($file)";
        push @{ $self->{meat}{test_files} }, @{ $chunk->{test_files} };
        unlink $file or die "unlink failed: $!";
    }
    $dir->rmtree;
}

sub emit_chunk {
    my ( $self, $result_file ) = @_;
    YAML::DumpFile( $result_file, $self->structure );
}

sub emit {
    my ( $self, $file ) = @_;
    YAML::DumpFile(
        $file,
        {   meat => $self->structure,
            map { $_ => $self->{"_$_"} }
                qw( build_info smoker config revision timing )
        }
    );
}

1;

