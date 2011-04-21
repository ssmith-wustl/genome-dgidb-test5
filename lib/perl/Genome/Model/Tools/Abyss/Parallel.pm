package Genome::Model::Tools::Abyss::Parallel;

use strict;
use warnings;

use Genome;
use File::Path qw/make_path/;
use File::pushd;

class Genome::Model::Tools::Abyss::Parallel {
    is => 'Genome::Model::Tools::Abyss',
    has_input => [
        kmer_size => {
            is => 'Number',
            doc => 'k-mer size for assembly',
        },
        min_pairs => {
            is => 'Number',
            doc => 'The minimum number of pairs needed to consider joining two contigs',
            default => 10,
        },
        num_jobs => {
            is => 'Number',
            doc => 'The number of jobs to run in parallel',
            default => 8,
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

sub parse_kmer_range {
    my ($self, $range) = @_;

    my @kmer_sizes;
    if (my ($start, $end, $step) = $range =~ /^(\d+)-(\d+)/) {
        die "invalid kmer size range '$range', end=$end < start=$start. abort." if $end < $start;
        if (my ($step) = $range =~ / step (.*)/) { # .* instead of \d+ so we can complain about bad input
            die "invalid kmer size range '$range', step=$step <= 0, abort." if $step <= 0;
            for (my $i = $start; $i <= $end; $i += $step) {
                push(@kmer_sizes, $i);
            }    
        } else {
            push(@kmer_sizes, $start..$end); 
        }
    } else {
        die "Invalid number '$range'" unless $range =~ /^\d+$/;
        push(@kmer_sizes, $range);
    }
    return @kmer_sizes;
}

sub get_kmer_sizes {
    my ($self, $kmer_size) = @_;
    my @kmer_sizes;
    my @values = split(',', $kmer_size);
    for my $v (@values) {
        push(@kmer_sizes, $self->parse_kmer_range($v));
    }
    return @kmer_sizes;
}

sub execute {
    my $self = shift;
    my $bindir = $self->bindir;

    die "Input fastq_a file '" . $self->fastq_a . " does not exist " unless -e $self->fastq_a;
    die "Input fastq_b file '" . $self->fastq_b . " does not exist " unless -e $self->fastq_b;

    for my $kmer_size ($self->get_kmer_sizes($self->kmer_size)) {
        my $output_dir = $self->output_directory . '/k' . $kmer_size;
        my $main_log_file = "$output_dir/abyss.log";
        my @cmd = (
            $self->abyss_pe_binary,
            "k=" . $self->kmer_size,
            "n=" . $self->min_pairs,
            "in='" . $self->fastq_a . " " . $self->fastq_b . "'", 
            "name=".$self->name,
            'mpirun="' . $self->mpirun_cmd.'"',
            " > $main_log_file 2>&1"
            );

        make_path($output_dir);
        pushd($output_dir);
        chdir($output_dir);
        local $ENV{PATH} = $self->bindir . ":$ENV{PATH}";
        return unless Genome::Sys->shellcmd( cmd => join(' ', @cmd),);
    }

    return 1;
}

1;
