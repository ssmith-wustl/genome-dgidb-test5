package Genome::Model::Tools::Abyss::Parallel;

use strict;
use warnings;

use Genome;
use File::Path qw/make_path/;
use File::pushd;

class Genome::Model::Tools::Abyss::Parallel {
    is => 'Genome::Model::Tools::Abyss',
    has_input => [
        params => {
            is => 'Text',
            doc => 'Assembler params',
        },
        job_queue => {
            is => 'Text',
            doc => 'The job queue to schedule the work in.',
            default => 'apipe',
        },
        output_directory => {
            is => 'String',
            doc => 'Directory to write output to',
        },
        fastq_a => {
            is => 'Text',
            doc => 'fastq file a',
        },
        fastq_b => {
            is => 'Text',
            doc => 'fastq file b',
        },
        name => {
            is => 'Text',
            doc => 'Name to prepend to output files',
            default => 'abyss',
        }
    ]
};

sub abyss_pe_binary {
    return shift->bindir . "/abyss-pe";
}

sub job_count {
    my $self = shift;
    my ($processes) = $self->params =~ /\bnp=([0-9]+)\b/;
    return $processes || 1;
}

# TODO: abstract job submission, it's bad to hard code bsub all over
sub mpirun_cmd {
    my $self = shift;

    my $rusage = 'span[ptile=1] select[fscache]';
    my $log_file = $self->output_directory . '/abyss_parallel.log';
    my $job_count = $self->job_count;
    my $job_queue = $self->job_queue;
    return "bsub -K -oo $log_file -n $job_count -a openmpi -q $job_queue -R '$rusage' mpirun.lsf -x PATH";
}

sub execute {
    my $self = shift;
    my $bindir = $self->bindir;

    die "Input fastq_a file '" . $self->fastq_a . " does not exist " unless -e $self->fastq_a;
    die "Input fastq_b file '" . $self->fastq_b . " does not exist " unless -e $self->fastq_b;

    my $main_log_file = $self->output_directory . '/abyss.log';
    my @cmd = (
        $self->abyss_pe_binary,
        $self->params,
        "in='" . $self->fastq_a . " " . $self->fastq_b . "'", 
        "name=".$self->name,
        'mpirun="' . $self->mpirun_cmd.'"',
        " > $main_log_file 2>&1"
        );

    make_path($self->output_directory);
    pushd($self->output_directory);
    chdir($self->output_directory);
    local $ENV{PATH} = $self->bindir . ":$ENV{PATH}";
    return Genome::Sys->shellcmd(
        cmd => join(' ', @cmd),
    );
}

1;
