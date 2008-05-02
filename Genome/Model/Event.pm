package Genome::Model::Event;

use strict;
use warnings;
use File::Path;

our $log_base = '/gscmnt/sata114/info/medseq/model_data/logs/';

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
        date_completed      => { is => 'TIMESTAMP(20)', len => 11, is_optional => 1 },
        date_scheduled      => { is => 'TIMESTAMP(20)', len => 11, is_optional => 1 },
        
        event_status        => { is => 'VARCHAR2', len => 32, is_optional => 1 },
        event_type          => { is => 'VARCHAR2', len => 255 },
        lsf_job_id          => { is => 'VARCHAR2', len => 64, is_optional => 1 },
        ref_seq_id          => { is => 'VARCHAR2', len => 64, is_optional => 1 },
        user_name           => { is => 'VARCHAR2', len => 64, is_optional => 1 },
        retry_count         => { is => 'NUMBER', len => 3, is_optional => 1 },
        
        run_id              => { is => 'NUMBER', len => 11, is_optional => 1 },
        run                 => { is => 'Genome::RunChunk', id_by => 'run_id', is_optional => 1, constraint_name => 'event_run' },
        run_name            => { via => 'run' },
        run_lane            => { via => 'run', to => 'limit_regions' },
        sample_name         => { via => 'run', to => 'sample_name' },
        read_set_id         => { via => 'run', to => 'seq_id' },
        
        model_id            => { is => 'NUMBER', len => 11, is_optional => 1 },
        model               => { is => 'Genome::Model', id_by => 'model_id', constraint_name => 'GME_GM_FK' },
        model_name          => { via => 'model', to => 'name' },
        
    ],
    is_abstract => 1,
    sub_classification_method_name => '_resolve_subclass_name',
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
);

# This is called by the infrastructure to appropriately classify abstract events
# according to their event type because of the "sub_classification_method_name" setting
# in the class definiton...
# TODO: replace with cleaner calculated property.
sub _resolve_subclass_name {
    my $class = shift;
    my $event_type;
    if (ref($_[0]) and $_[0]->isa(__PACKAGE__)) {
        $event_type = $_[0]->event_type;
    }
    else {
        $event_type = $class->get_rule_for_params(@_)->specified_value_for_property_name('event_type');
    }
    return $class->_resolve_subclass_name_for_event_type($event_type);
}

# This is called by some legacy code.
sub class_for_event_type {
    my $self = shift;
    return $self->_resolve_subclass_name_for_event_type($self->event_type);
}

# This is called by both of the above.
sub _resolve_subclass_name_for_event_type {
    my ($class,$event_type) = @_;
    my @command_parts = split(' ',$event_type);
    my $genome_model = shift @command_parts;
    if ($genome_model !~ m/genome-model/) {
        $class->error_message("Malformed event-type $event_type.  Expected it to begin with 'genome-model'");
        return;
    }

    foreach ( @command_parts ) {
        my @sub_parts = map { ucfirst } split('-');
        $_ = join('',@sub_parts);
    }

    my $class_name = join('::', 'Genome::Model::Command' , @command_parts);
    return $class_name;
}

sub desc {
    my $self = shift;
    return $self->id . " of type " . $self->event_type;
}

# Override the default message handling to auto-instantiate a log handle.
# TODO: have the command tell the current context to take messages

our @process_logs;

sub _get_msgdata {
    my $self = $_[0];
    my $msgdata = $self->SUPER::_get_msgdata;
    return $msgdata if $msgdata->{gm_fh_set};
    $msgdata->{gm_fh_set} = 1;

    my $name = $log_base;
    use Sys::Hostname;
    if (ref($self)) {
        no warnings;
        $name .= "/" . join('.', UR::Time->now, hostname(), $$, $self->id, $self->event_type, 
            $self->model_id, 
            $self->run_id || 'NORUN',
            $self->ref_seq_id || 'NOREF', 
            ($self->lsf_job_id || 'NOJOB')
        ) . ".log";
    }
    else {
        $name .= "/" . join(".", UR::Time->now, hostname(), $$) . ".process-log";
    }
    $name =~ s/\s/_/g;

    my $logfh = $msgdata->{gm_logfh} = IO::File->new(">$name");
    $logfh->autoflush(1);
    chmod(0644, $name) or die "chmod $name failed: $!";
    require IO::Tee;
    my $fh = IO::Tee->new(\*STDERR, $logfh) or die "failed to open tee for $name: $!";        

    push @process_logs, [$name,$logfh,$fh];

    $self->dump_status_messages($fh);
    $self->dump_warning_messages($fh);
    $self->dump_error_messages($fh);
 
    return $msgdata;
}

END {
    for (@process_logs) {
        my ($name,$logfh,$fh) = @$_;
        eval { $fh->close; };
        eval { $logfh->close; };
        if (-z $name) {
            print STDERR "removing empty file $name\n";
            unlink $name;
        }
    }
}

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
sub resolve_log_directory {
    my $self = shift;

    if (defined $self->run) {
        return sprintf('%s/logs/%s/%s', Genome::Model->get($self->model_id)->data_directory,
                                        $self->run->sequencing_platform,
                                        $self->run->name);
    } else {
        return sprintf('%s/logs/%s', Genome::Model->get($self->model_id)->data_directory,
                                     $self->ref_seq_id);
    }
}

sub resolve_lane_name {
    my ($self) = @_;

    # hack until the GSC.pm namespace is deployed ...after we fix perl5.6 issues...
    eval "use GSCApp; App->init;";
    my $lane_summary = GSC::RunLaneSolexa->get(seq_id => $self->run->seq_id);
    unless ($lane_summary) {
        $self->error_message('No lane summary');
    }
    if ($lane_summary->run_type && $lane_summary->run_type =~ /Paired End Read (\d+)/) {
        return $self->run->limit_regions . '_' . $1;
    } else {
        return $self->run->limit_regions;
    }
}

# maq map file for all this lane's alignments
sub unique_alignment_file_for_lane {
    my($self) = @_;

    return $self->resolve_run_directory . '/unique_alignments_lane_' . $self->resolve_lane_name . '.map';
}

sub duplicate_alignment_file_for_lane {
    my($self) = @_;

    return $self->resolve_run_directory . '/duplicate_alignments_lane_' . $self->resolve_lane_name . '.map';
}

# fastq file for all the reads in this lane
sub fastq_file_for_lane {
    my($self) = @_;

    return sprintf("%s/s_%s_sequence.fastq", $self->resolve_run_directory, $self->resolve_lane_name);
}


# a file containing sequence\tread_name\tquality sorted by sequence
sub sorted_fastq_file_for_lane {
    my($self) = @_;

    return sprintf("%s/s_%s_sequence.sorted.fastq", $self->resolve_run_directory, $self->resolve_lane_name);
}

sub original_sorted_unique_fastq_file_for_lane {
    my($self) = @_;

    return sprintf("%s/%s_sequence.unique.sorted.fastq", $self->run->full_path, $self->resolve_lane_name);
}

sub sorted_unique_fastq_file_for_lane {
    my($self) = @_;

    return sprintf("%s/s_%s_sequence.unique.sorted.fastq", $self->resolve_run_directory, $self->resolve_lane_name);
}

sub original_sorted_duplicate_fastq_file_for_lane {
    my($self) = @_;
    return sprintf("%s/%s_sequence.duplicate.sorted.fastq", $self->run->full_path, $self->resolve_lane_name);

}

sub sorted_duplicate_fastq_file_for_lane {
    my($self) = @_;
    return sprintf("%s/s_%s_sequence.duplicate.sorted.fastq", $self->resolve_run_directory, $self->resolve_lane_name);

}

# The maq bfq file that goes with that lane's fastq file
sub unique_bfq_file_for_lane {
    my($self) = @_;
    return sprintf("%s/s_%s_sequence.unique.bfq", $self->resolve_run_directory, $self->resolve_lane_name);
}

sub duplicate_bfq_file_for_lane {
    my($self) = @_;
    return sprintf("%s/s_%s_sequence.duplicate.bfq", $self->resolve_run_directory, $self->resolve_lane_name);
}

sub unaligned_unique_reads_file_for_lane {
    my($self) = @_;
    return sprintf("%s/s_%s_sequence.unaligned.unique", $self->resolve_run_directory, $self->resolve_lane_name);
}

sub unaligned_unique_fastq_file_for_lane {
    my($self) = @_;
    return sprintf("%s/s_%s_sequence.unaligned.unique.fastq", $self->resolve_run_directory, $self->resolve_lane_name);
}

sub unaligned_duplicate_reads_file_for_lane {
    my($self) = @_;
    return sprintf("%s/s_%s_sequence.unaligned.duplicate", $self->resolve_run_directory, $self->resolve_lane_name);
}

sub unaligned_duplicate_fastq_file_for_lane {
    my($self) = @_;
    return sprintf("%s/s_%s_sequence.unaligned.duplicate.fastq", $self->resolve_run_directory, $self->resolve_lane_name);
}

sub aligner_unique_output_file_for_lane {
    return $_[0]->unique_alignment_file_for_lane . '.aligner_output';
}

sub aligner_duplicate_output_file_for_lane {
    return $_[0]->duplicate_alignment_file_for_lane . '.aligner_output';
}

sub alignment_submaps_dir_for_lane {
    my $self = shift;
    return sprintf("%s/alignments_lane_%s.submaps", $self->resolve_run_directory, $self->resolve_lane_name)
}

sub adaptor_file_for_run {
    my $self = shift;

    my $pathname = $self->resolve_run_directory . '/adaptor_sequence_file';
    return $pathname;
}

sub map_files_for_refseq {
    my $self = shift;
    my $ref_seq_id=shift;
    my $model= $self->model;
    
    my $path = $self->alignment_submaps_dir_for_lane;
    my @map_files =  (sprintf("%s/%s_unique.map",$path, $ref_seq_id));
    if($model->is_eliminate_all_duplicates) {
        return @map_files;
    }
    else {
        push (@map_files, sprintf("%s/%s_duplicate.map",$path, $ref_seq_id));
        return @map_files;
    }
}

sub run_command_with_bsub {
    my($self,$command,$last_command, $dep_type) = @_;
## should check if $self isa Command??
    $dep_type ||= 'ended';

    my $last_bsub_job_id;
    $last_bsub_job_id = $last_command->lsf_job_id if defined $last_command;

    my $queue = $self->bsub_queue;
    my $bsub_args = $self->bsub_args;
    
   if ($command->can('bsub_rusage')) {
        $bsub_args .= ' ' . $command->bsub_rusage;
    }
    my $cmd = 'genome-model bsub-helper';

    my $event_id = $command->genome_model_event_id;
    my $prior_event_id = $last_command->genome_model_event_id if defined $last_command;
    my $model_id = $self->model_id;

    my $log_dir = $command->resolve_log_directory;
    unless (-d $log_dir) {
        eval { mkpath($log_dir) };
        if ($@) {
            $self->error_message("Couldn't create run directory path $log_dir: $@");
            return;
        }
    }
  
    my $err_log_file=  sprintf("%s/%s.err", $command->resolve_log_directory, $event_id);
    my $out_log_file=  sprintf("%s/%s.out", $command->resolve_log_directory, $event_id);
    $bsub_args .= ' -o ' . $out_log_file . ' -e ' . $err_log_file;
 

    my $cmdline;
    { no warnings 'uninitialized';
        $cmdline = "bsub -q $queue $bsub_args" .
                   ($last_bsub_job_id && " -w '$dep_type($last_bsub_job_id)'") .
                   " $cmd --model-id $model_id --event-id $event_id" .
                   ($prior_event_id && " --prior-event-id $prior_event_id");
    }

    if ($self->can('test') && $self->test) {
        #$command->status_message("Test mode, command not executed: $cmdline");
        print "Test mode, command not executed: $cmdline\n";
        $last_bsub_job_id = 'test';
    } else {
        $self->status_message("Running command: " . $cmdline);

        my $bsub_output = `$cmdline`;
        my $retval = $? >> 8;

        if ($retval) {
            $self->error_message("bsub returned a non-zero exit code ($retval), bailing out");
            return;
        }

        if ($bsub_output =~ m/Job <(\d+)>/) {
            $last_bsub_job_id = $1;

        } else {
            $self->error_message('Unable to parse bsub output, bailing out');
            $self->error_message("The output was: $bsub_output");
            return;
        }

    }

    return $last_bsub_job_id;
}

## for automatic retries by bsub-helper, override if you want less or more than 3
sub max_retries {
    0;  #temporarily disabled until rusage issue is dealt with,  sometimes retries maq on non-64 bit blades
}
    
1;
