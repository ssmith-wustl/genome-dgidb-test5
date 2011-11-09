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
        _submerged_position_beds => {
            doc => 'The names of the sub-merge outputs for bed positions',
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
    my $num_inputs = $self->_num_inputs;
    my @input_files = map{ $_->get_snvs_vcf.".gz" } @builds;

    #initialize the workflow inputs
    my $reference_sequence_build = $builds[0]->reference_sequence_build;
    my %inputs;

    $inputs{output_directory} = $output_directory;
    $inputs{final_output} = $output_directory."/".$model_group->id.".merged.vcf.gz";
    $inputs{reference_sequence_path} = $reference_sequence_build->full_consensus_path('fa');
    $inputs{merged_positions_bed} = $output_directory."/merged_positions.bed.gz";
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
        $inputs{$sample."_mpileup_output_file"} = $dir."/".$sample.".for_".$model_group->id.".pileup.gz"; 
        $inputs{$sample."_vcf_file"} = $build->get_snvs_vcf;
        $inputs{$sample."_backfilled_vcf"} = $dir."/snvs.backfilled_for_".$model_group->id.".vcf.gz";
    }

    #create the workflow object
    my $workflow = $self->_generate_workflow(\@builds, $output_directory);

    #set up inputs which are determined by the number of merge steps
    if(defined($self->max_files_per_merge) && ($self->max_files_per_merge < $num_inputs)){
        #setup a tmp directory for the intermediate output of merging
        my $tmp_dir = $output_directory."/tmp";
        unless(-d $tmp_dir){
            mkdir $tmp_dir;
            unless(-d $tmp_dir){
                die $self->error_message("Could not find or create a tmp dir at: ".$tmp_dir);
            }
        }
        my $submerge = $self->_submerged_position_beds;
        my @submerges = @{$submerge};
        my $input_num = 1;
        my @input_list = @input_files;

        #divide up input files into chunks for sub-merging operations
        for my $sub_merge (@submerges){
            $inputs{$sub_merge} = $tmp_dir."/".$sub_merge.".bed.gz";
            my @local_input_list;
            for (1..$self->max_files_per_merge){
                unless(@input_list){
                    last;
                }
                push @local_input_list, shift @input_list;
            }
            $inputs{"input_files_".$input_num} = \@local_input_list;
            $input_num++;
        }
    } else {
        #if the max merge width was set, but not exceeded, run as normal
        $inputs{input_files} = \@input_files;
    }
    my @errors = $workflow->validate;
    if (@errors) {
        $self->error_message(@errors);
        die "Errors validating workflow\n";
    }
    $self->_dump_workflow($workflow);

    $self->status_message("Now launching the vcf-merge workflow.");
    my $result = Workflow::Simple::run_workflow_lsf( $workflow, %inputs);

    unless($result){
        $self->error_message( join("\n", map($_->name . ': ' . $_->error, @Workflow::Simple::ERROR)) );
        die $self->error_message("Workflow did not return correctly.");
    }

    return 1;

}

sub _dump_workflow {
    my $self = shift;
    my $workflow = shift;
    my $xml = $workflow->save_to_xml;
    my $xml_location = $self->output_directory."/workflow.xml";
    my $xml_file = Genome::Sys->open_file_for_writing($xml_location);
    print $xml_file $xml;
    $xml_file->close;
    #$workflow->as_png($self->output_directory."/workflow.png"); #currently commented out because blades do not all have the "dot" library to use graphviz
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

    my $num_inputs = $self->_num_inputs;
    my @merged_positions_beds;

    #prepare sub-merge inputs, outputs, etc
    if(defined($self->max_files_per_merge) && ($self->max_files_per_merge < $num_inputs) ){
        my $max_ops = $self->max_files_per_merge;
        my $num_merge_ops = int($num_inputs/$max_ops);
        if($num_inputs % $max_ops){
            $num_merge_ops++;
        }
        for my $group (1..$num_merge_ops){
            push @merged_positions_beds, "merged_positions_bed_".$group;
            push @inputs, "input_files_".$group;
        }
        push @inputs, @merged_positions_beds;
        $self->_submerged_position_beds(\@merged_positions_beds);
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
    
    #if max_files_per_merge was set, consider creating sub-merge operations, else run with a single merge operation
    if(defined($self->max_files_per_merge)){
        $merge_operation = $self->_add_limited_position_merge($self->max_files_per_merge, \$workflow);
    } else {
        $merge_operation = $self->_add_position_merge(\$workflow);
    }

    #add the mpileup and backfill operations
    my $backfill_ops = $self->_add_mpileup_and_backfill(\$workflow,$merge_operation);

    #converge the outputs of backfill and set up the final merge
    #TODO currently we do not support sub-merge operations on the final vcf merge, but we will add this shortly
    my $final_merge_op;
    #if(defined($self->max_files_per_merge)){
    #    $final_merge_op = $self->_add_limited_final_merge(\$workflow, $backfill_ops);
    #} else {
        $final_merge_op = $self->_add_final_merge(\$workflow, $backfill_ops);
    #}

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
    my $output_file_prop = defined($op_number) ? "merged_positions_bed_".$op_number : "merged_positions_bed";

    #create the merge operation object
    my $merge_operation = $workflow->add_operation(
        name => $op_name,
        operation_type => Workflow::OperationType::Command->get("Genome::Model::Tools::Joinx::VcfMergePositionsOnly"),
    );

    #link the merged_positions_bed input to the output_file param
    $workflow->add_link(
        left_operation => $workflow->get_input_connector,
        left_property => $output_file_prop,
        right_operation => $merge_operation,
        right_property => "output_file",
    );

    #link other input properties to merge operation

    my $input_property = defined($op_number) ? "input_files_".$op_number : "input_files";

    $workflow->add_link(
        left_operation => $workflow->get_input_connector,
        left_property => $input_property,
        right_operation => $merge_operation,
        right_property => "input_files",
    );
    $workflow->add_link(
        left_operation => $workflow->get_input_connector,
        left_property => "use_bgzip",
        right_operation => $merge_operation,
        right_property => "use_bgzip",
    );

    return $merge_operation;
}

sub _add_limited_position_merge {
    my $self = shift;
    my $max_ops = shift;
    my $workflow = shift;
    $workflow = $$workflow;

    my $num_inputs = $self->_num_inputs;
    
    my $num_merge_ops = int($num_inputs/$max_ops);
    if($num_inputs % $max_ops){
        $num_merge_ops++;
    }

    my @merge_ops;
    my $merge_op;
    #if we have fewer inputs than max_ops, add one merge_op
    if($num_inputs <= $max_ops){
        return $self->_add_position_merge(\$workflow); 
    # if the number of merge_ops is less than the max_ops, we only need one level of merge ops
    } elsif ( int($num_inputs / $max_ops) <= $max_ops) {
        for my $group(1..$num_merge_ops){
            push @merge_ops, $self->_add_position_merge(\$workflow,$group);
        }
        return $self->_merge_position_merges(\$workflow,\@merge_ops);
    } else { #else we need multiple layers of merge ops
        die $self->error_message("Given that: B = number of builds, MFPM = max-files-per-merge, you have caused this: B/MFPM < MFPM to evaluate as false\n We intend to support this condition soon though.");
    }
    return 1;
}
sub _merge_position_merges {
    my $self = shift;
    my $workflow = shift;
    $workflow = $$workflow;
    my $merge_ops = shift;
    my @merge_ops = @{$merge_ops};
    my @input_properties;
    my $num_merges = scalar(@merge_ops);
    for my $num (1..$num_merges){
        push @input_properties, $num."_of_".$num_merges."_merge_operation";
    } 

    #create a converge operation to take the output of the position merge operations 
    # and merge them into a single input for the final position merge operation
    my $converge_positions = $workflow->add_operation(
        name => "converge positions",
        operation_type => Workflow::OperationType::Converge->create(
            input_properties => \@input_properties,
            output_properties => [ qw|input_files| ],
        ),
    );
    my $num = 1;
    #link the backfill ops to the converge step
    for my $merge_op (@merge_ops){
        $workflow->add_link(
            left_operation => $merge_op,
            left_property => "output_file",
            right_operation => $converge_positions,
            right_property => $num."_of_".$num_merges."_merge_operation",
        );
        $num++;
    }

    #create the merge operation object
    my $merge_operation = $workflow->add_operation(
        name => "Final Union of Positions to Backfill",
        operation_type => Workflow::OperationType::Command->get("Genome::Model::Tools::Joinx::UnionBedPositions"),
    );

    #link the merged_positions_bed input to the output_file param
    $workflow->add_link(
        left_operation => $workflow->get_input_connector,
        left_property => "merged_positions_bed",
        right_operation => $merge_operation,
        right_property => "output_file",
    );

    #link other input properties to merge operation
#    $workflow->add_link(
#        left_operation => $workflow->get_input_connector,
#        left_property => "use_bgzip",
#        right_operation => $merge_operation,
#        right_property => "use_bgzip",
#    );
    $workflow->add_link(
        left_operation => $converge_positions,
        left_property => "input_files",
        right_operation => $merge_operation,
        right_property => "input_files",
    );

    return $merge_operation;

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

    my $op_number = shift;
    my $op_name  = defined($op_number) ? "Final Merge Sub Group ".$op_number : "Final VCF Merge";
    my $output_file_prop = defined($op_number) ? "vcf_sub_merge_".$op_number : "";

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
=cut
sub _add_final_merge {
    my $self = shift;
    my $workflow = shift;
    $workflow = $$workflow;
    my $op_number = shift;
    my $op_name  = defined($op_number) ? "Final Merge Sub Group ".$op_number : "Final VCF Merge";
    my $output_file_prop = defined($op_number) ? "merged_positions_bed_".$op_number : "merged_positions_bed";

    #create the merge operation object
    my $merge_operation = $workflow->add_operation(
        name => $op_name,
        operation_type => Workflow::OperationType::Command->get("Genome::Model::Tools::Joinx::VcfMergePositionsOnly"),
    );

    #link the merged_positions_bed input to the output_file param
    $workflow->add_link(
        left_operation => $workflow->get_input_connector,
        left_property => $output_file_prop,
        right_operation => $merge_operation,
        right_property => "output_file",
    );

    #link other input properties to merge operation

    my $input_property = defined($op_number) ? "input_files_".$op_number : "input_files";

    $workflow->add_link(
        left_operation => $workflow->get_input_connector,
        left_property => $input_property,
        right_operation => $merge_operation,
        right_property => "input_files",
    );
    $workflow->add_link(
        left_operation => $workflow->get_input_connector,
        left_property => "use_bgzip",
        right_operation => $merge_operation,
        right_property => "use_bgzip",
    );

    return $merge_operation;
}
=cut

sub _add_limited_final_merge {
    my $self = shift;
    my $max_ops = shift;
    my $workflow = shift;
    $workflow = $$workflow;

    my $num_inputs = $self->_num_inputs;
    
    my $num_merge_ops = int($num_inputs/$max_ops);
    if($num_inputs % $max_ops){
        $num_merge_ops++;
    }

    my @merge_ops;
    my $merge_op;
    #if we have fewer inputs than max_ops, add one merge_op
    if($num_inputs <= $max_ops){
        return $self->_add_final_merge(\$workflow); 
    # if the number of merge_ops is less than the max_ops, we only need one level of merge ops
    } elsif ( int($num_inputs / $max_ops) <= $max_ops) {
        for my $group(1..$num_merge_ops){
            push @merge_ops, $self->_add_final_merge(\$workflow,$group);
        }
        return $self->_merge_position_merges(\$workflow,\@merge_ops);
    } else { #else we need multiple layers of merge ops
        die $self->error_message("Given that: B = number of builds, MFPM = max-files-per-merge, you have caused this: B/MFPM < MFPM to evaluate as false\n We intend to support this condition soon though.");
    }
    return 1;
}

1;
