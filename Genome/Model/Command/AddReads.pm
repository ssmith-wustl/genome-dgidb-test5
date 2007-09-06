
package Genome::Model::Command::AddReads;

use strict;
use warnings;

use UR;
use Command; 

UR::Object::Class->define(
    class_name => __PACKAGE__,
    is => 'Command',
    has => [
        model_id   =>  { is => 'Integer', 
                      doc => "Identifies the genome model to which we'll add the reads." },
        sequencing_platform => { is => 'String',
                                 doc => 'Type of sequencing instrument used to generate the data'},
        full_path => { is => 'String',
                       doc => 'Pathname for the data produced by the run' },
    ],
    has_optional => [
        limit_regions =>  { is => 'String',
                            doc => 'Which regions should be kept during further analysis' },
        bsub    =>  { is => 'Boolean',
                      doc => 'Sub-commands should be submitted to bsub. Default is yes.',
                      default_value => 1 },
        bsub_queue => { is => 'String',
                      doc => 'Which bsub queue to use for sub-command jobs, default is "long"',
                       default_value => 'long'},
        bsub_args => { is => 'String',
                       doc => 'Additional arguments passed along to bsub (such as -o, for example)',
                       default_value => '' },
        test => { is => 'Boolean',
                  doc => 'Create run information in the database, but do not schedule any sub-commands',
                  is_optional => 1,
                  default_value => 0},
    ]
);

sub help_brief {
    "add reads from all or part of an instrument run to the model"
}

sub help_synopsis {
    return <<"EOS"
genome-model add-reads --model_id 123 --squencing-platform solexa --full-path /SOME/PATH
EOS
}

sub help_detail {
    return <<"EOS"
This command launches all of the appropriate commands to add a run,
or part of a run, to the specified model.

All of the sub-commands listed below will be executed on the model in succession.
EOS
}


sub execute {
    my $self = shift;

$DB::single=1;
    
    my @sub_command_classes = @{ $self->_get_sorted_sub_command_classes };
    my @sub_command_names = @{ $self->_get_sorted_sub_command_names };

    my $last_bsub_job_id;

    for (my $idx = 0; $idx < @sub_command_names; $idx++) {

        my $command_output = $self->_run_command_from_sub_command_name_and_last_bsub_id(
                                        $sub_command_names[$idx],
                                        $last_bsub_job_id,
                                );

        if ($self->bsub) {
            $last_bsub_job_id = $self->_verify_bsubbed_job_output( $command_output );
        }
        
        Genome::Model::Event->create(
                                        event_type         => $sub_command_classes[$idx],
                                        model_id           => $self->model_id,
                                        lsf_job_id         => $last_bsub_job_id,
                                        date_scheduled     => scalar(localtime),
                                        user_name          => $ENV{'USER'},
                                    );
        App::DB->sync_database();
        App::DB->commit();
    }

    return 1; 
}

#sub _get_genome_model_id{
#    my $self = shift;
#    
#    my $model_name = $self->model;
#    my $model = Genome::Model->get(name => $model_name);
#    unless($model) {
#        $self->error_message("Genome model named $model_name is unknown");
#        return 0;
#    }
#    
#    return $model->id;
#}

sub _get_run{
    my $self = shift;
    
    my $run = Genome::RunChunk->get_or_create(
                                  full_path => $self->full_path,
                                  limit_regions => $self->limit_regions,
                                  sequencing_platform => $self->sequencing_platform
                                  );
    unless ($run) {
        $self->error_message('Failed to get or create a new Run record, exiting');
        return 0;
    }
    
    return $run;
}

sub _get_sorted_sub_command_classes{
    my $self = shift;

    # Determine what all the sub-commands are going to be
    my @sub_command_classes = sort { $a->sub_command_sort_position
                                     <=>
                                     $b->sub_command_sort_position
                                   } $self->sub_command_classes();
    
    return \@sub_command_classes;
}

sub _get_sorted_sub_command_names{
    my $self = shift;
    
    my @sub_command_classes = @{ $self->_get_sorted_sub_command_classes
                                };
    my @sub_command_names = map { $_->command_name } @sub_command_classes;
    
    return \@sub_command_names;
}

sub _generate_command_with_sub_command_name_and_last_bsub_id{
    my ($self, $ssc_name, $last_bsub_job_id) = @_;
    
    my $run = $self->_get_run;
    my $queue = $self->bsub_queue;
    my $bsub_args = $self->bsub_args;
    
    my $cmd = '';
    if ($self->bsub) {
        $cmd .= "bsub -q $queue $bsub_args";
        if ($last_bsub_job_id) {
            $cmd .= " -w $last_bsub_job_id";
        }
    }

    $cmd .= sprintf(' %s --model-id %d --run-id %d',
                                $ssc_name,
                                $self->model_id,
                                $run->id);
    
    return $cmd;
}

sub _run_command_from_sub_command_name_and_last_bsub_id{
    my ($self, $ssc_name, $last_bsub_job_id) = @_;
    
    my $cmd = $self->_generate_command_with_sub_command_name_and_last_bsub_id(
                            $ssc_name,
                            $last_bsub_job_id,
                    );
    
    $self->status_message("Running command: $cmd");
    my($command_output, $retval);
    if ($self->test) {
        $self->status_message("** test mode, above command not executed");
    } else {
        $command_output = `$cmd`;
        $retval = $? >> 8;
    }

    if ($retval) {
        $self->error_message("sub-command \"$cmd\" exited with return value $retval, bailing out\n");
        return 0;
    }
    
    return $command_output;
}

sub _verify_bsubbed_job_output{
    my ($self, $command_output) = @_;
    
    $command_output =~ m/Job \<(\d+)\>/;
    if ($1 || $self->test) {
        return $1;
    } else {
        $self->error_message("Couldn't parse job out from bsub's output: $command_output");
        return 0;
    }
}

1;

