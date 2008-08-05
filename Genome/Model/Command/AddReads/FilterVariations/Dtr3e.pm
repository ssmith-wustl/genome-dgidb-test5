package Genome::Model::Command::AddReads::FilterVariations::Dtr3e;

use strict;
use warnings;
use above "Genome";
use Genome::Model::Tools::Snp::Filters::ScaledBinomialTest;
use Genome::Model::Tools::Snp::Filters::Dtr3e;
use Genome::Model::Tools::Snp::Filters::GenerateFigure3Files;
use FileHandle;
use FindBin qw($Script);
use Workflow;


####################################
#THIS IS THE NEW VERSION--DAVE LARSON WROTE IT
#CHRIS HARRIS REFACTORED IT
#IT EXPECTS DAVE LARSONS VERSION OF PP OUTPUT
####################################

class Genome::Model::Command::AddReads::FilterVariations::Dtr3e {
    is => ['Genome::Model::Command::AddReads::FilterVariations'],
    sub_classification_method_name => 'class',
    has => [ ]
};

sub sub_command_sort_position { 90 }

sub help_brief {
    "Create filtered lists of variations."
}

sub help_synopsis {
    return <<"EOS"
    genome-model postprocess-alignments filter-variations --model-id 5 --ref-seq-id 22 
EOS
}

sub help_detail {
    return <<"EOS"
    Create filtered list(s) of variations.
EOS
}

sub command_subclassing_model_property {
    "filter_ruleset_name"
}



sub execute {
    my $self=shift;
    $DB::single = $DB::stopper;
    my $model = $self->model;

    # TODO remove for workflow... output of another step
    my $basename = $model->_filtered_variants_dir . '/filtered.';
    my $keep_file = $basename . 'chr' . $self->ref_seq_id . '.keep.csv';

    ###undo previous times we did stuff for this event######
    unless($self->revert) {
        $self->error_message("There was a problem reverting the previous iterations changes.");
        return;
    }

    my $workflow = Workflow::Model->create_from_xml("/gscuser/charris/filtered_variations.xml");
    #$workflow->as_png('filtered_variations.png');
    
    my @errors = $workflow->validate;
    die 'Too many problems: ' . join("\n", @errors) unless $workflow->is_valid;
   
    $workflow->execute(
        input => {
                    parent_event                        => $self,
                    ref_seq_id                          => $self->ref_seq_id,
                    basedir                            => $model->_filtered_variants_dir,
                    experimental_metric_model_file      => $self->variation_metrics_file_name,
                    experimental_metric_normal_file     => $self->normal_sample_variation_metrics_file 
                 },
        output_cb => {}
    );

    $workflow->wait;
}



sub variation_metrics_file_name {
    my $self = shift;
    my $library_name = shift;

    my $annotate_step = Genome::Model::Event->get(parent_event_id => $self->parent_event_id, ref_seq_id => $self->ref_seq_id, "event_type like" => '%annotate%');
    my $post_process_step= Genome::Model::Event->get(parent_event_id => $self->parent_event_id, ref_seq_id => $self->ref_seq_id, "event_type like" => '%postprocess-variations%');

    my $base_variation_file_name = $post_process_step->experimental_variation_metrics_file_basename . ".csv";

    unless($library_name) {
        return $base_variation_file_name;
    }
    return "$base_variation_file_name.$library_name";
} 


sub _write_array_to_file {
    my $self=shift;
    my $array_ref_to_write=shift;
    my $file_handle=shift;

    my $line_to_write = join (" ", @{$array_ref_to_write});
    $file_handle->print($line_to_write . "\n");

    return 1;
}


sub somatic_variants_in_d_v_w {
    my $self = shift;
    my $name = 'somatic_variants_in_d_v_w';
    return $self->get_metric_value($name);
}

sub non_coding_tumor_only_variants {
    my $self = shift;
    my $name = 'non_coding_tumor_only_variants';
    return $self->get_metric_value($name);
}
sub novel_tumor_only_variants {
    my $self = shift;
    my $name = 'novel_tumor_only_variants';
    return $self->get_metric_value($name);
}


sub silent_tumor_only_variants {
    my $self = shift;
    my $name = 'silent_tumor_only_variants';
    return $self->get_metric_value($name);
}

sub non_synonymous_splice_site_variants {
    my $self = shift;
    my $name = 'non_synonymous_splice_site_variants';
    return $self->get_metric_value($name);
}

sub var_pass_manreview {
    my $self = shift;
    my $name = 'var_pass_manreview';
    return $self->get_metric_value($name);
}

sub var_fail_manreview {
    my $self = shift;
    my $name = 'var_fail_manreview';
    return $self->get_metric_value($name);
}


sub var_fail_valid_assay {
    my $self = shift;
    my $name = 'var_fail_valid_assay';
    return $self->get_metric_value($name);
}


sub var_complete_validation {
    my $self = shift;
    my $name = 'var_complete_validation';
    return $self->get_metric_value($name);
}

sub validated_snps {
    my $self = shift;
    my $name = 'validated_snps';
    return $self->get_metric_value($name);
}
sub false_positives {
    my $self = shift;
    my $name = 'false_positives';
    return $self->get_metric_value($name);
}
sub validated_somatic_variants {
    my $self = shift;
    my $name = 'validated_somatic_variants';
    return $self->get_metric_value($name);
}

sub _calculate_somatic_variants_in_d_v_w {
    my $self = shift;
    my $name = 'somatic_variants_in_d_v_w';
    return $self->get_metric_value($name);
}

sub _calculate_non_coding_tumor_only_variants {
    my $self = shift;
    my $name = 'non_coding_tumor_only_variants';
    return $self->get_metric_value($name);
}
sub _calculate_novel_tumor_only_variants {
    my $self = shift;
    my $name = 'novel_tumor_only_variants';
    return $self->get_metric_value($name);
}


sub _calculate_silent_tumor_only_variants {
    my $self = shift;
    my $name = 'silent_tumor_only_variants';
    return $self->get_metric_value($name);
}

sub _calculate_non_synonymous_splice_site_variants {
    my $self = shift;
    my $name = 'non_synonymous_splice_site_variants';
    return $self->get_metric_value($name);
}

sub _calculate_var_pass_manreview {
    my $self = shift;
    my $name = 'var_pass_manreview';
    return $self->get_metric_value($name);
}

sub _calculate_var_fail_manreview {
    my $self = shift;
    my $name = 'var_fail_manreview';
    return $self->get_metric_value($name);
}


sub _calculate_var_fail_valid_assay {
    my $self = shift;
    my $name = 'var_fail_valid_assay';
    return $self->get_metric_value($name);
}


sub _calculate_var_complete_validation {
    my $self = shift;
    my $name = 'var_complete_validation';
    return $self->get_metric_value($name);
}

sub _calculate_validated_snps {
    my $self = shift;
    my $name = 'validated_snps';
    return $self->get_metric_value($name);
}
sub _calculate_false_positives {
    my $self = shift;
    my $name = 'false_positives';
    return $self->get_metric_value($name);
}
sub _calculate_validated_somatic_variants {
    my $self = shift;
    my $name = 'validated_somatic_variants';
    return $self->get_metric_value($name);
}

sub tumor_only_variants {
    my $self = shift;
    my $name = 'tumor_only_variants';
    return $self->get_metric_value($name);
}
sub skin_variants {
    my $self = shift;
    my $name = 'skin_variants';
    return $self->get_metric_value($name);
}

sub well_supported_variants {
    my $self = shift;
    my $name = 'well_supported_variants';
    return $self->get_metric_value($name);
}

sub _calculate_well_supported_variants {
    my $self = shift;
    my $file_I_will_wordcount_to_find_total_variants = $self->keep_file_name;
    my $file_wordcount_1  = `wc -l $file_I_will_wordcount_to_find_total_variants | cut -f1 -d' '`;
    chomp($file_wordcount_1);
    return $file_wordcount_1;
}


sub _calculate_tumor_only_variants {
    my $self = shift;
    my $file_I_will_wordcount_to_find_only_tumor_variants = $self->somatic_file_name;
    my $file_wordcount = `wc -l $file_I_will_wordcount_to_find_only_tumor_variants | cut -f1 -d' '`;
    chomp($file_wordcount);
    return $file_wordcount;
}
sub _calculate_skin_variants {
    my $self = shift;
    my $file_I_will_wordcount_to_find_total_variants = $self->keep_file_name;
    my $file_I_will_wordcount_to_find_only_tumor_variants = $self->somatic_file_name;
    my $file_wordcount_1  = `wc -l $file_I_will_wordcount_to_find_total_variants | cut -f1 -d' '`;
    my $file_wordcount_2  = `wc -l $file_I_will_wordcount_to_find_only_tumor_variants | cut -f1 -d' '`;
    chomp($file_wordcount_1);
    chomp($file_wordcount_2);    
    return $file_wordcount_1 - $file_wordcount_2;
}

sub somatic_file_name {
    my $self=shift;
    my $model = $self->model;
    return  $model->_filtered_variants_dir() . "/filtered.chr" . $self->ref_seq_id . '.somatic.csv';
}

sub keep_file_name {
    my $self=shift;
    my $model = $self->model;
    return  $model->_filtered_variants_dir() . "/filtered.chr" . $self->ref_seq_id . '.keep.csv';
}
sub remove_file_name {
    my $self=shift;
    my $model = $self->model;
    return  $model->_filtered_variants_dir() . "/filtered.chr" . $self->ref_seq_id . '.remove.csv';
}

sub report_file_name {
    my $self=shift;
    my $model = $self->model;
    return  $model->_filtered_variants_dir() . "/filtered.chr" . $self->ref_seq_id . '.report.csv';
}

sub invalue_file_name {
    my $self=shift;
    my $model = $self->model;
    return  $model->_filtered_variants_dir() . "/filtered.chr" . $self->ref_seq_id . '.invalue.csv';
}

sub metrics_for_class {
    my $self = shift;
    my @metrics = qw| 
    somatic_variants_in_d_v_w
    non_coding_tumor_only_variants
    novel_tumor_only_variants
    silent_tumor_only_variants
    non_synonymous_splice_site_variants
    var_pass_manreview
    var_fail_manreview
    var_fail_valid_assay
    var_complete_validation
    validated_snps
    false_positives
    validated_somatic_variants
    skin_variants
    tumor_only_variants 
    well_supported_variants
    |;
}


sub normal_sample_variation_metrics_file {
    my $self= shift;
    my $model = $self->model;

    my $model_name = $model->name;
    my $normal_name = $model_name;

    $normal_name =~ s/98tumor/34skin/g;
    my $normal_model = Genome::Model->get('name like' => $normal_name);
    unless ($normal_model) {
        $self->error_message(sprintf("normal model matching name %s does not exist.  please verify this first.", $normal_name));
        return undef;
    }

    # Get metrics for the normal sample for processing.
    my $latest_normal_build = $normal_model->latest_build_event;
    unless ($latest_normal_build) {
        $self->error_message("Failed to find a build event for the comparable normal model " . $normal_model->name);
        return;
    }

    my ($equivalent_skin_event) =
    grep { $_->isa("Genome::Model::Command::AddReads::PostprocessVariations")  }
    $latest_normal_build->child_events(
        ref_seq_id => $self->ref_seq_id
    );

    unless ($equivalent_skin_event) {
        $self->error_message("Failed to find an event on the skin model to match the tumor.  Probably need to re-run after that completes.  In the future, we will have the tumor/skin filtering separate from the individual model processing.\n");
        return;
    }
    my $normal_sample_variation_metrics_file_name =  $equivalent_skin_event->experimental_variation_metrics_file_basename . ".csv";

    unless (-e $normal_sample_variation_metrics_file_name) {
        $self->error_message("Failed to find variation metrics for \"normal\": $normal_sample_variation_metrics_file_name");
        return;
    }
    return $normal_sample_variation_metrics_file_name

}






