package Genome::ModelGroup::Command::CreateCrossSampleVcf;

use strict;
use warnings;

use Genome;
use Workflow;
use Workflow::Simple;

class Genome::ModelGroup::Command::CreateCrossSampleVcf {
    is => 'Genome::Command::Base',
    has_input => [
        model_group => {
            is => 'Genome::ModelGroup',
            is_optional=>0,
            doc => 'this is the model group you wish to create a cross-sample vcf for',
        },
        output_directory => {
            is => 'Text',
            is_optional=>0,
            doc => 'the directory where you want results stored',
        },
        max_files_per_merge => {
            is => 'Text',
            is_optional => 1,
            doc => 'Set this to cause no more than N vcfs to be merged into a single operation at a time',
        },
    ],
    has_transient_optional => [
        _num_inputs => {
            is => 'Text',
            doc => 'number of builds being operated over',
        },
    ],
    doc => '', #TODO
};

sub help_synopsis {
    return <<EOS
genome model-group create-cross-sample-vcf --model-group=1745 --output-dir=/foo/bar/

EOS
}


sub execute {
    my $self=shift;
    my $model_group  = $self->model_group;
    my $output_directory = $self->output_directory;

    #Check for output directory
    unless(-d $output_directory) {
        $self->error_message("Unable to find output directory: " . $output_directory);
        return;
    }

    #grab VCF's from the builds
    my @builds = map{ $_->last_succeeded_build } $model_group->models;
    unless (@builds) {
        die $self->error_message("No succeeded builds found for this model group");
    }

    $self->_num_inputs(scalar(@builds));
    my @input_files = map{ $_->get_snvs_vcf.".gz" } @builds;

    #initialize the workflow inputs
    my $reference_sequence_build = $builds[0]->reference_sequence_build;
    my %inputs;
    $inputs{output_directory} = $output_directory;
    $inputs{final_output} = $output_directory."/".$model_group->id.".merged.vcf.gz";
    $inputs{reference_sequence_path} = $reference_sequence_build->full_consensus_path('fa');
    $inputs{merged_positions_bed} = $output_directory."/merged_positions.bed.gz";
    $inputs{input_files} = \@input_files;
    $inputs{use_bgzip} = 1;

    #populate the per-build inputs
    for my $build (@builds){
        unless ($build->reference_sequence_build == $reference_sequence_build) {
            die $self->error_message("Multiple reference sequence builds found for this model group between build " . $builds[0]->id . " and build " . $build->id);
        }
        my $sample = $build->model->subject->name;
        my $dir = $output_directory . "/".$sample;
        unless(-d $dir){
            mkdir $dir;
            unless(-d $dir){
                die $self->error_message("Could not create backfill directory for ".$sample);
            }
        }
        $inputs{$sample."_bam_file"} = $build->whole_rmdup_bam_file;
        $inputs{$sample."_mpileup_output_file"} = $dir."/".$sample.".for_".$model_group->id.".pileup.head1000.gz"; 
        $inputs{$sample."_vcf_file"} = $build->get_snvs_vcf;
        $inputs{$sample."_backfilled_vcf"} = $dir."/snvs.backfilled_for_".$model_group->id.".vcf.gz.head1000";
    }

    #create the workflow object and validate 
    my $workflow = $self->_generate_workflow(\@builds, $output_directory);
    my @errors = $workflow->validate;
    if (@errors) {
        $self->error_message(@errors);
        die "Errors validating workflow\n";
    }

    $self->status_message("Now launching the vcf-merge workflow.");
    my $result = Workflow::Simple::run_workflow_lsf( $workflow, %inputs);

    unless($result){
        $self->error_message( join("\n", map($_->name . ': ' . $_->error, @Workflow::Simple::ERROR)) );
        die $self->error_message("Workflow did not return correctly.");
    }

    return 1;

}

sub _generate_workflow {
    my $self = shift;
    my $build_array = shift;
    my $output_directory = shift;
    my @builds = map { $_->last_succeeded_build } $self->model_group->models;
    my @inputs;
    for my $build (@builds){
        my $sample = $build->model->subject->name;
        push @inputs, ($sample."_bam_file",
            $sample."_mpileup_output_file",
            $sample."_vcf_file",
            $sample."_backfilled_vcf" );
    }
    
    #Initialize workflow object
    my $workflow = Workflow::Model->create(
        name => 'Multi-Vcf Merge',
        input_properties => [
            'input_files',
            'output_directory',
            'merged_positions_bed',
            'final_output',
            'use_bgzip',
            'reference_sequence_path',
            @inputs,
        ],
        output_properties => [
            'output',
        ],
    );

    #set log directory
    $workflow->log_dir($self->output_directory);

    #add vcf-merge-positions-only operation
    my $merge_operation;
    
    #if(defined($self->max_files_per_merge)){
    #    $merge_operation = $self->_add_limited_position_merge($self->max_files_per_merge, \$workflow);
    #} else {
        $merge_operation = $self->_add_position_merge(\$workflow);
    #}

    #add the mpileup and backfill operations
    my $backfill_ops = $self->_add_mpileup_and_backfill(\$workflow,$merge_operation);

    #converge the outputs of backfill and set up the final merge
    my $final_merge_op;
    if(defined($self->max_files_per_merge)){
        $final_merge_op = $self->_add_limited_final_merge(\$workflow, $backfill_ops);
    } else {
        $final_merge_op = $self->_add_final_merge(\$workflow, $backfill_ops);
    }

    #link the final merge to the output_connector
    $workflow->add_link(
        left_operation => $final_merge_op,
        left_property => "output_file",
        right_operation => $workflow->get_output_connector,
        right_property => "output",
    );

    return $workflow;
}

sub _add_position_merge {
    my $self = shift;
    my $workflow = shift;
    $workflow = $$workflow;
    my $op_number = shift;
    my $op_name  = defined($op_number) ? "Merge Positions Group ".$op_number : "Merge Positions";

    #create the merge operation object
    my $merge_operation = $workflow->add_operation(
        name => $op_name,
        operation_type => Workflow::OperationType::Command->get("Genome::Model::Tools::Joinx::VcfMergePositionsOnly"),
    );

    #link the merged_positions_bed input to the output_file param
    $workflow->add_link(
        left_operation => $workflow->get_input_connector,
        left_property => "merged_positions_bed",
        right_operation => $merge_operation,
        right_property => "output_file",
    );

    #link other input properties to merge operation
    for my $property ("input_files","use_bgzip"){
        $workflow->add_link(
            left_operation => $workflow->get_input_connector,
            left_property => $property,
            right_operation => $merge_operation,
            right_property => $property,
        );
    }

    return $merge_operation;
}

sub _add_limited_position_merge {
    my $self = shift;
    my $max_ops = shift;
    my $workflow = shift;
    $workflow = $$workflow;

    my $num_inputs = $self->_num_inputs;
    
    #if we have fewer inputs than max_ops, add one merge_op
    if($num_inputs <= $max_ops){
        return $self->_add_position_merge(\$workflow); 
    
    # if the number of merge_ops is less than the max_ops, we only need one level of merge ops
    } elsif ( int($num_inputs / $max_ops) <= $max_ops) {  

    
    } else { #else we need multiple layers of merge ops

    }
    return 1;
}

sub _add_mpileup_and_backfill {
    my $self = shift;
    my $workflow = shift;
    $workflow = $$workflow; #de-reference workflow ref
    my $merge_operation = shift;

    my @builds = map { $_->last_succeeded_build } $self->model_group->models;
    my @backfill_ops;

    #for each model, add an mpileup and backfill command
    for my $build (@builds) {
        my $sample = $build->model->subject->name;

        #add mpileup operation
        my $mpileup = $workflow->add_operation(
            name => "mpileup ".$sample,
            operation_type => Workflow::OperationType::Command->get("Genome::Model::Tools::Sam::Pileup"),
        );

        $workflow->add_link(
            left_operation => $workflow->get_input_connector,
            left_property => $sample."_bam_file",
            right_operation => $mpileup,
            right_property => "bam_file",
        );
        $workflow->add_link(
            left_operation => $workflow->get_input_connector,
            left_property => "reference_sequence_path",
            right_operation => $mpileup,
            right_property => "reference_sequence_path",
        );
        $workflow->add_link(
            left_operation => $workflow->get_input_connector,
            left_property => $sample."_mpileup_output_file",
            right_operation => $mpileup,
            right_property => "output_file",
        );
        $workflow->add_link(
            left_operation => $workflow->get_input_connector,
            left_property => "use_bgzip",
            right_operation => $mpileup,
            right_property => "use_bgzip",
        );
        $workflow->add_link(
            left_operation => $merge_operation,
            left_property => "output_file",
            right_operation => $mpileup,
            right_property => "region_file",
        );

        #add a backfill operation on to the mpileup op
        my $backfill = $workflow->add_operation(
            name => "backfill ".$sample,
            operation_type => Workflow::OperationType::Command->get("Genome::Model::Tools::Vcf::Backfill"),
        );
        $workflow->add_link(
            left_operation => $workflow->get_input_connector,
            left_property => $sample."_vcf_file",
            right_operation => $backfill,
            right_property => "vcf_file",
        );
        $workflow->add_link(
            left_operation => $workflow->get_input_connector,
            left_property => $sample."_backfilled_vcf",
            right_operation => $backfill,
            right_property => "output_file",
        );
        $workflow->add_link(
            left_operation => $workflow->get_input_connector,
            left_property => "use_bgzip",
            right_operation => $backfill,
            right_property => "use_bgzip",
        );
        $workflow->add_link(
            left_operation => $mpileup,
            left_property => "output_file",
            right_operation => $backfill,
            right_property => "pileup_file",
        );

        push @backfill_ops, $backfill;
    }
    return \@backfill_ops;
} 

sub _add_final_merge {
    my $self = shift;
    my $workflow = shift;
    $workflow = $$workflow;
    my $backfill_ops = shift;
    my @backfill_ops = @{ $backfill_ops };
    my @input_properties;

    #get the number of builds being merged
    my $build_count = scalar(map {$_->last_succeeded_build } $self->model_group->models);
    for my $num (1..$build_count){
        push @input_properties, "vcf_".$num;
    }

    #create a converge operation to take the output of the backfill operations 
    # and merge them into a single input for the final merge operation
    my $converge_vcfs = $workflow->add_operation(
        name => "converge vcfs",
        operation_type => Workflow::OperationType::Converge->create(
            input_properties => \@input_properties,
            output_properties => [ qw|vcf_files| ],
        )
    );
    my $num = 1;
    #link the backfill ops to the converge step
    for my $backfill (@backfill_ops){
        $workflow->add_link(
            left_operation => $backfill,
            left_property => "output_file",
            right_operation => $converge_vcfs,
            right_property => "vcf_".$num,
        );
        $num++;
    }
    
    #create and link final merge operation
    my $merge = $workflow->add_operation(
        name => "final merge",
        operation_type => Workflow::OperationType::Command->get("Genome::Model::Tools::Joinx::VcfMerge"),
    );
    $workflow->add_link(
        left_operation => $workflow->get_input_connector,
        left_property => "use_bgzip",
        right_operation => $merge,
        right_property => "use_bgzip",
    );
    $workflow->add_link(
        left_operation => $workflow->get_input_connector,
        left_property => "final_output",
        right_operation => $merge,
        right_property => "output_file",
    );
    $workflow->add_link(
        left_operation => $converge_vcfs,
        left_property => "vcf_files",
        right_operation => $merge,
        right_property => "input_files",
    );
    return $merge;
}

sub _add_limited_final_merge {
    return 1;
}

1;
