package Genome::Model::Build::Command::ReferenceAlignment::SubmissionSummary;

use strict;
use warnings;

use Genome;

class Genome::Model::Build::Command::ReferenceAlignment::SubmissionSummary {
    is => 'Genome::Command::Base',
    doc => "List a summary of the merged alignment BAMs for the provided builds and a file suitable for submitting the bam list.",
    has => [
        sample_mapping_file => {
            is=> 'String',
            doc => 'this command will generate this list of bam file names & samples',
        }, 
        bam_list_file => {
            is=> 'String',
            doc => 'this command will generate this list of bam file names, space separated suitable for gxfer to submit bams',
        } 
    ],
    has_optional => [
        builds => {
            is => 'Genome::Model::Build::ReferenceAlignment',
            is_many => 1,
            shell_args_position => 1,
            doc => 'List of builds to use if searching on a list of builds'
        },
        flow_cell_id => {
            is => 'String',
            shell_args_position => 2,
            doc => 'Flow Cell ID to use if searching on a flowcell'
        },
        reference_sequence_name => {
            is=>'String',
            doc=>'Only include models with this reference sequence name',
        },
        region_of_interest_set_name => {
            is=>'String',
            doc=>'Only include models with this region of interest set name',
        }
    ],
};


sub help_detail {
    return "List the path of the merged alignment BAMs for the provided builds/flow cells, and generate a sample mapping.";
}


sub execute {
    my $self = shift;

    if ($self->flow_cell_id && $self->builds) {
        $self->error_message("Ambiguous input; you must provide either a flow cell id or a set of builds -- not both. ");
        return;
    }

    if ($self->flow_cell_id) {
        $self->status_message(sprintf("Searching for instrument data for %s...  ", $self->flow_cell_id));
        my @instr_data = Genome::InstrumentData::Solexa->get(flow_cell_id=>$self->flow_cell_id);
        $self->status_message(sprintf("Found %s instrument data.\n", scalar @instr_data));

        my %model_ids = map {$_->model_id, 1} map {Genome::Model::Input->get(name=>'instrument_data', value_id=>$_->id)} @instr_data;
        
        my @raw_models = Genome::Model->get(id=>[keys %model_ids]);
        my @models;
       
        # filter out Lane QC models, Pooled_Library models, and only the ROI/refseq requested if there was one
        for (@raw_models) {
            push @models, $_ unless (($_->subject_name =~ m/^Pooled_Library/) ||
                                     ($_->processing_profile->append_event_steps && $_->processing_profile->append_event_steps =~ m/LaneQc/) ||
                                     ($self->region_of_interest_set_name && $_->region_of_interest_set_name && $_->region_of_interest_set_name ne $self->region_of_interest_set_name) ||
                                     ($self->reference_sequence_name && $_->reference_sequence_build->name ne $self->reference_sequence_name));

        }

        $self->status_message(sprintf("Found %s models", scalar @models));

        my @builds;
        for (@models) {
            my ($latest_build) = sort {$b->id <=> $a->id} grep {$_->status eq 'Succeeded'} $_->builds;
            push @builds, $latest_build;
        }

        $self->builds([@builds]);

    } elsif ($self->builds) {

       
    } else {
        $self->error_message("You must provide either a flow cell id or a set of builds.  ");
        return;
    }

    my $samp_map = IO::File->new(">".$self->sample_mapping_file);
    unless ($samp_map) {
        $self->error_message("Failed to open sample mapping file for writing ". $self->sample_mapping_file);
        return;
    }
    my $bam_list = IO::File->new(">".$self->bam_list_file);
    unless ($bam_list) {
        $self->error_message("Failed to open bam list file for writing ". $self->bam_list_file);
        return;
    }

    my @builds = $self->builds;
    for my $build (@builds) {
        my $roi_name = $build->model->region_of_interest_set_name ? $build->model->region_of_interest_set_name : 'N/A';
        my $refbuild_name = $build->model->reference_sequence_build->name ? $build->model->reference_sequence_build->name : 'N/A';
        print $samp_map join ("\t", $build->model->subject_name, $refbuild_name, $roi_name, $build->whole_rmdup_bam_file);
        print $samp_map "\n";
    }
    
    print $bam_list join (" ", map {$_->whole_rmdup_bam_file} @builds);

    $samp_map->close;
    $bam_list->close;

    return 1;
}

1;

