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
        date_completed        => { is => 'TIMESTAMP(20)', len => 20, is_optional => 1 },
        date_scheduled        => { is => 'TIMESTAMP(20', len => 20, is_optional => 1 },
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


# This create() can get called in two different occasions:
# 1) When some initiator programs runs (like the top-level add-reads), we actually want to
#    create a brand new event and log it as 'scheduled'
# 2) When the sub-sub command acutally executes, say on a blade, the Command module
#    wrapper system will create() an object of the appropriate subtype.  In this
#    case we want to find the right previously created command and return that
#    instead of making a new one
sub create {
    my $class = shift;
    my %args = @_;

$DB::single=1;

    #if (! exists($args{'lsf_job_id'}) and exists($ENV{'LSB_JOBID'})) {
    #    $args{'lsf_job_id'} = $ENV{'LSB_JOBID'};
    #}
    #return $class->SUPER::create(%args);

    delete $args{' '};  # Most (all?) Of these things are really going to be some 
                        # derivitives of Command::Something, so there'll be a ' ' param in there
    my @candidates = $class->get(%args,
                                 event_status => 'Scheduled');

    my $event;
    if (@candidates == 0) {
        if (! exists($args{'lsf_job_id'}) and exists($ENV{'LSB_JOBID'})) {
            $args{'lsf_job_id'} = $ENV{'LSB_JOBID'};
        }
        $event = $class->SUPER::create(%args);
    } elsif (@candidates == 1) {
        if (! exists($args{'lsf_job_id'}) and exists($ENV{'LSB_JOBID'})) {
            $candidates[0]->lsf_job_id($ENV{'LSB_JOBID'});
        }
        $event = $candidates[0];
    } else {
         $class->warning_message("Got back ".scalar(@candidates)." objects from get() returning the oldest one");
         @candidates = sort { $a->date_scheduled cmp $b->date_scheduled } @candidates;
         $event = $candidates[0];
    }

    $event->date_scheduled(UR::Time->now());
    $event->event_status('Scheduled');
    $event->user_name($ENV{'USER'});
    if ($event->can('command_name')) {
        $event->event_type($event->command_name);
    } else {
        $event->event_type('unknown');
    }

    # A nasty, ugly hack
    # This in effect overrides the lowest-level commands' execute() method
    # so that it gets called, then updates the date_completed and event_status
    # before returning Command infrastructure 
    #
    # The right way is to change all the sub- and sub-sub commands' execute()
    # to something like _execute() and then define execute() in here which would
    # call _execute();
#    no strict 'refs';
#    my $class_path = $class . '::';
#    my $glob = ${$class_path}{'execute'};
#    my $orig_execute  = *{$glob}{'CODE'};
#    my $sub = sub {
#                      $DB::single=1;
#                      my $rv = $orig_execute->(@_);
#                      $_[0]->date_completed(UR::Time->now());
#                      $_[0]->event_status($rv ? 'Succeeded' : 'Failed');
#                      return $rv;
#                   };
#    my $execute_path = $class_path . 'execute';
#    no warnings 'redefine';
#    *{$execute_path} = $sub;
    
    return $event;
}


sub execute {
    my $self = shift;

    my $rv = $self->_execute();
    $self->date_completed(UR::Time->now());
    $self->event_status($rv ? 'Succeeded' : 'Failed');
    return $rv;
}



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

    my $path;
    if ($model->multi_read_fragment_strategy()) {
        my $run = Genome::RunChunk->get($self->run_id);
        $path = sprintf("%s/s_%d_sequence.cchredundant.sorted.fastq", $self->resolve_run_directory, $run->limit_regions);
    } else {
        $path = $self->sorted_fastq_file_for_lane();
    }
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
