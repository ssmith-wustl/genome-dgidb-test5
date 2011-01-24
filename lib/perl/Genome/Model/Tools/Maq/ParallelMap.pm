package Genome::Model::Tools::Maq::ParallelMap;

use strict;
use warnings;

use Genome;
use Workflow;

class Genome::Model::Tools::Maq::ParallelMap {
    is  => ['Workflow::Operation::Command'],
    workflow => sub {
        my $rmapper = Workflow::Operation->create(
            name => 'parallel maq map',
            operation_type => Workflow::OperationType::Command->get('Genome::Model::Tools::Maq::Map')
        );
        $rmapper->parallel_by('fastq_files');
        return $rmapper;
    },
    has_optional => [
        sequences => {
            is => 'Number',
            doc => 'The number of sequence to include in each instance. default_value=1000000',
            default_value => 1000000,
        },
        _output_basename => { },
    ],
};


sub pre_execute {
    my $self = shift;

    if (ref($self->fastq_files) ne 'ARRAY') {
        my @fastq_files = split(/\s+/,$self->fastq_files);
        $self->fastq_files(\@fastq_files);
    }
    my @fastq_files = @{$self->fastq_files};
    my $fastq_count = scalar(@fastq_files);

    my @output_basenames;
    my @sub_fastqs;
    for my $fastq_file (@fastq_files) {
        my $split = Genome::Model::Tools::Fastq::Split->create(
            sequences => $self->sequences,
            fastq_file => $fastq_file,
            output_directory => $self->output_directory,
        );
        unless ($split) {
            die('Failed to create fastq split command');
        }
        unless ($split->execute) {
            die('Failed to execute fastq split command');
        }
        my @suffix = qw(txt fastq);
        my ($basename,$dirname,$suffix) = File::Basename::fileparse($fastq_file,@suffix);
        unless ($basename && $dirname && $suffix) {
            die('Failed to parse fastq file '. $fastq_file);
        }
        $basename =~ s/\.$//;
        push @output_basenames, $basename;
        push @sub_fastqs, $split->fastq_files;
    }
    $self->_output_basename(join('_',@output_basenames));

    my @parallel_fastq_files;
    if ($fastq_count == 2) {
        my @fastq_1s = @{$sub_fastqs[0]};
        my @fastq_2s = @{$sub_fastqs[1]};
        unless (scalar(@fastq_1s) == scalar(@fastq_2s)) {
            die('The number of Paired End Read 1 fastq '. scalar(@fastq_1s)
                    .' does not match the number of Paired End Read 2 fastq '. scalar(@fastq_2s));
        }
        for (my $i = 0; $i < scalar(@fastq_1s); $i++) {
            my @fastqs = ($fastq_1s[$i],$fastq_2s[$i]);
            push @parallel_fastq_files, \@fastqs;
        }
        my $lane;
        for my $output_basename (@output_basenames) {
            unless ($output_basename =~ m/((\d)_[12])/) {
                die('Failed to parse lane and end from file basename '. $output_basename);
            }
            my $read_id = $1;
            my $read_lane = $2;
            if ($lane) {
                unless ($lane == $read_lane) {
                    die('Fastq files do not contain reads from the same lane');
                }
            } else {
                $lane = $read_lane;
            }
            $output_basename =~ s/$read_id/$lane/;
            $self->_output_basename($output_basename);
        }
    } elsif ($fastq_count == 1) {
        @parallel_fastq_files = @{$sub_fastqs[0]};
        $self->_output_basename($output_basenames[0]);
    } else {
        die('Invalid number of fastq files '. $fastq_count);
    }
    $self->fastq_files(\@parallel_fastq_files);
    return 1;
}

sub post_execute {
    my $self = shift;

    $self->status_message(Data::Dumper->new([$self])->Dump);
    my @files_to_unlink;

    #MAP
    my @map_files = @{$self->map_file};
    $self->map_file($self->output_directory .'/'. $self->_output_basename .'.map');
    unless (Genome::Model::Tools::Maq::Mapmerge->execute(
        input_map_files => \@map_files,
        output_map_file => $self->map_file,
        use_version => $self->use_version,
    )) {
        die('Failed to merge map files');
    }
    push @files_to_unlink, @map_files;

    #OUTPUT
    my @output_files = @{$self->output_file};
    $self->output_file($self->output_directory .'/'. $self->_output_basename .'.aligner_output');
    unless (Genome::Sys->cat(
        input_files => \@output_files,
        output_file => $self->output_file,
    )) {
        die('Failed to merge output files');
    }
    push @files_to_unlink, @output_files;

    #UNALIGNED
    my @unaligned_files = grep { -s } @{$self->unaligned_file};
    $self->unaligned_file($self->output_directory .'/'. $self->_output_basename .'.unaligned');
    unless (Genome::Sys->cat(
        input_files => \@unaligned_files,
        output_file => $self->unaligned_file,
    ) ) {
        die('Failed to merge unaligned reads files');
    }
    push @files_to_unlink, @unaligned_files;
    #TODO: Convert unaligned reads to unaligned fastq and split by paired end

    my @fastq_files = @{$self->fastq_files};
    for my $fastq_file (@fastq_files) {
        if (ref($fastq_file) eq 'ARRAY') {
            push @files_to_unlink,@{$fastq_file};
        } else {
            push @files_to_unlink, $fastq_file;
        }
    }

    #REMOVE INTERMEDIATE FILES
    for my $file (@files_to_unlink) {
        unless (unlink $file) {
            die('Failed to remove file '. $file .":  $!");
        }
    }
    return 1;
}

1;
