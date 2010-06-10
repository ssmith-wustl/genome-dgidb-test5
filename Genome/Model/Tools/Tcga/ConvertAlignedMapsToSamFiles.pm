package Genome::Model::Tools::Tcga::ConvertAlignedMapsToSamFiles;

use strict;
use warnings;

use Genome;
use Workflow;
use IO::File;

class Genome::Model::Tools::Tcga::ConvertAlignedMapsToSamFiles {
    is  => ['Command'],
    has => [
        model_id => {
            is  => 'String',
            is_input => '1',
            doc => 'The model id.',
        },
        working_directory => {
            is => 'String',
            is_input => '1',
            doc => 'The working directory.',
        },
        aligned_sam_file_directory => {
            is => 'String',
            is_output =>1,
            is_optional =>1,
            doc => 'The directory where all the resulting sam files will be generated.', 
        }, 
    ],
};

sub help_brief {
    'Convert Maq map files into the TCGA format.';
}

sub help_detail {
    return <<EOS
    Convert Maq map files into the TCGA format.
EOS
}


sub execute {
    my $self = shift;

    $self->dump_status_messages(1);
    my $model_id = $self->model_id;
    my $model = Genome::Model->get($model_id);
    die "Model $model_id is not defined. Quitting." unless defined($model);
     
    my @idas = $model->instrument_data_assignments;
    $self->status_message("There are ".scalar(@idas)." id assignemnts for model id $model_id\n");
    
    my $build = $model->last_complete_build;

    my $count=0;
    my @alignments;
    for my $ida (@idas) {
        my $seq_id = $ida->instrument_data->seq_id;
        my $alignment = $ida->results;
        my $alignment_directory = $alignment->alignment_directory;
        
        #testing data 
        push (@alignments, "$seq_id|$alignment_directory");
        #if ($seq_id == 2792545037 || $seq_id == 2792546284 ) {
        #    push (@alignments, "$seq_id|$alignment_directory");
            #$count++;
       # }

    }
  
        $self->status_message("Alignment info sent to workers: ".join("\n",@alignments));
        $self->status_message("Working dir sent to workers: ".$self->working_directory);

        require Workflow::Simple;
            
        my $op = Workflow::Operation->create(
            name => 'Generate per lane sams',
            operation_type => Workflow::OperationType::Command->get('Genome::Model::Tools::Tcga::ConvertAlignedMapsToSamFilesWorker')
        );

        $op->parallel_by('alignment_info');

        my $output = Workflow::Simple::run_workflow_lsf(
            $op,
            'alignment_info'  => \@alignments,
            'working_directory' => $self->working_directory, 
        );

        #check workflow for errors 
        if (!defined $output) {
           foreach my $error (@Workflow::Simple::ERROR) {
               $self->error_message($error->error);
           }
           return;
        } else {
           $self->status_message("Workflow completed with no errors.");
        }


    $self->aligned_sam_file_directory($self->working_directory."/aligned/");

    return 1;
 
    }
1;
