package Genome::Model::Event;

use strict;
use warnings;

use Genome;
UR::Object::Type->define(
    class_name => 'Genome::Model::Event',
    is => ['Command'],
    english_name => 'genome model event',
    table_name => 'GENOME_MODEL_EVENT',
    id_by => [
        genome_model_event_id => { is => 'NUMBER', len => 11 },
    ],
    has => [
        #date_completed        => { is => 'TIMESTAMP(6)', len => 11, is_optional => 1 },
        #date_scheduled        => { is => 'TIMESTAMP(6)', len => 11, is_optional => 1 },
        date_completed        => { is => 'TIMESTAMP(20)', len => 11, is_optional => 1 },
        date_scheduled        => { is => 'TIMESTAMP(20)', len => 11, is_optional => 1 },
        event_status          => { is => 'VARCHAR2', len => 32, is_optional => 1 },
        event_type            => { is => 'VARCHAR2', len => 255 },
        model                 => { is => 'Genome::Model', id_by => 'model_id', constraint_name => 'GME_GM_FK' },
        lsf_job_id            => { is => 'VARCHAR2', len => 64, is_optional => 1 },
        model_id              => { is => 'NUMBER', len => 11, is_optional => 1 },
        ref_seq_id            => { is => 'VARCHAR2', len => 64, is_optional => 1 },
        run_id                => { is => 'NUMBER', len => 11, is_optional => 1 },
        user_name             => { is => 'VARCHAR2', len => 64, is_optional => 1 },
        run            => { is => 'Genome::RunChunk', id_by => 'run_id', constraint_name => 'event_run' },
    ],
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
);



#sub execute {
#    my $self = shift;
#
#    my $rv = $self->_execute();
#    $self->date_completed(UR::Time->now());
#    $self->event_status($rv ? 'Succeeded' : 'Failed');
#    return $rv;
#}



sub _shell_args_property_meta {
    # exclude this class' commands from shell arguments
    return grep { 
            $_->class_name ne __PACKAGE__ 
            or
            ($_->via and $_->via eq 'run')
        } shift->SUPER::_shell_args_property_meta(@_);
}


sub resolve_run_directory {
    my $self = shift;

    return sprintf('%s/runs/%s/%s', Genome::Model->get($self->model_id)->data_directory,
                                    $self->run->sequencing_platform,
                                    $self->run->name);
}


# I thought that the Command API should be able to do this through
# resolve_class_and_params_for_argv(), but it didn't work...
sub class_for_event_type {
    my $self = shift;

    my @command_parts = split(' ',$self->event_type);
    my $genome_model = shift @command_parts;
    if ($genome_model !~ m/genome-model/) {
        $self->error_message("Malformed event-type for event ".$self->event_id.
                             ". Expected it to begin with 'genome-model'");
        return;
    }

    foreach ( @command_parts ) {
        my @sub_parts = map { ucfirst } split('-');
        $_ = join('',@sub_parts);
    }

    my $class_name = join('::', 'Genome::Model::Command' , @command_parts);
    return $class_name;
}


# maq map file for all this lane's alignments
sub alignment_file_for_lane {
    my($self) = @_;

    my $run = Genome::RunChunk->get($self->run_id);
    return $self->resolve_run_directory . '/alignments_lane_' . $run->limit_regions . '.map';
}

# fastq file for all the reads in this lane
sub fastq_file_for_lane {
    my($self) = @_;
    my $run = Genome::RunChunk->get($self->run_id);
    return sprintf("%s/s_%d_sequence.fastq", $self->resolve_run_directory, $run->limit_regions);
}


# a file containing sequence\tread_name\tquality sorted by sequence
sub sorted_fastq_file_for_lane {
    my($self,$lane) = @_;

    my $run = Genome::RunChunk->get($self->run_id);
    return sprintf("%s/s_%d_sequence.sorted.fastq", $self->resolve_run_directory, $run->limit_regions);
}


sub sorted_screened_fastq_file_for_lane {
    my($self,$lane) = @_;

    my $model = $self->model();

    my $path;
    if ($model->multi_read_fragment_strategy()) {
        my $run = Genome::RunChunk->get($self->run_id);
        $path = sprintf("%s/s_%d_sequence.unique.sorted.fastq", $self->resolve_run_directory, $run->limit_regions);
    } else {
        $path = $self->sorted_fastq_file_for_lane();
    }
    return $path;
}

sub sorted_redundant_fastq_file_for_lane {
    my($self,$lane) = @_;
    my $model = $self->model();
    my $run = Genome::RunChunk->get($self->run_id);
    my $path = sprintf("%s/s_%d_sequence.duplicate.sorted.fastq", $self->resolve_run_directory, $run->limit_regions);
    return $path;
}


# The maq bfq file that goes with that lane's fastq file
sub bfq_file_for_lane {
    my($self) = @_;
    my $run = Genome::RunChunk->get($self->run_id);
    return sprintf("%s/s_%d_sequence.bfq", $self->resolve_run_directory, $run->limit_regions);
}

# And ndbm file keyed by read name, value is the offset in the sorted fastq file where the read info is
sub read_index_dbm_file_for_lane {
    my($self) = @_;
    my $run = Genome::RunChunk->get($self->run_id);
    return sprintf("%s/s_%d_read_name_index.dbm", $self->resolve_run_directory, $run->limit_regions);
}

sub unaligned_reads_file_for_lane {
    my($self) = @_;
    my $run = Genome::RunChunk->get($self->run_id);
    return sprintf("%s/s_%d_sequence.unaligned", $self->resolve_run_directory, $run->limit_regions);
}

sub unaligned_fastq_file_for_lane {
    my($self) = @_;
    my $run = Genome::RunChunk->get($self->run_id);
    return sprintf("%s/s_%d_sequence.unaligned.fastq", $self->resolve_run_directory, $run->limit_regions);
}



1;
