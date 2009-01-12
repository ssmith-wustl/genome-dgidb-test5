package Genome::Model::Build::ReferenceAlignment::Solexa;

use strict;
use warnings;

use Genome;

class Genome::Model::Build::ReferenceAlignment::Solexa {
    is => 'Genome::Model::Build::ReferenceAlignment',
    has => [],

};

sub create {
    my $class = shift;
    my $self = $class->SUPER::create(@_);

    my $model = $self->model;

    my @read_sets = $model->read_sets;

    unless (scalar(@read_sets) && ref($read_sets[0])  &&  $read_sets[0]->isa('Genome::Model::ReadSet')) {
        $self->error_message('No read sets have been added to model: '. $model->name);
        $self->error_message("The following command will add all available read sets:\ngenome-model add-reads --model-id=".
        $model->id .' --all');
        return;
    }

    return $self;
}

sub _consensus_files {
    return shift->_files_for_pattern_and_optional_ref_seq_id('%s/consensus/%s.cns',@_);
}
#clearly if multiple aligners/programs becomes common practice, we should be delegating to the appropriate module to construct this directory
sub _variant_list_files {
    return shift->_files_for_pattern_and_optional_ref_seq_id('%s/maq_snp_related_metrics/snps_%s',@_);
}

sub _variant_pileup_files {
    return shift->_files_for_pattern_and_optional_ref_seq_id('%s/maq_snp_related_metrics/pileup_%s',@_);
}

sub _variant_detail_files {
    return shift->_files_for_pattern_and_optional_ref_seq_id('%s/maq_snp_related_metrics/report_input_%s',@_);
}

sub _variation_metrics_files {
    return shift->_files_for_pattern_and_optional_ref_seq_id('%s/other_snp_related_metrics/variation_metrics_%s.csv',@_);
}
sub other_snp_related_metric_directory {
    my $self = shift;
    return $self->data_directory . "/other_snp_related_metrics/";
}
sub maq_snp_related_metric_directory {
    my $self = shift;
    return $self->data_directory . "/maq_snp_related_metrics/";
}

sub _filtered_variants_dir {
    my $self = shift;
    return sprintf('%s/filtered_variations/',$self->data_directory);
}

sub _reports_dir {
    my $self = shift;
    return sprintf('%s/annotation/',$self->data_directory);
}

sub _files_for_pattern_and_optional_ref_seq_id {
    my $self=shift;
    my $pattern = shift;
    my $ref_seq=shift;

    my @files = 
    map { 
        sprintf(
            $pattern,
            $self->data_directory,
            $_
        )
    }
    grep { $_ ne 'all_sequences' }
    grep { (!defined($ref_seq)) or ($ref_seq eq $_) }
    $self->model->get_subreference_names;

    return @files;
}


sub maplist_file_paths {
    my $self = shift;

    my %p = @_;
    my $ref_seq_id;

    if (%p) {
        $ref_seq_id = $p{ref_seq_id};
    } else {
        $ref_seq_id = 'all_sequences';
    }
    my @map_lists = grep { -e $_ } glob($self->accumulated_alignments_directory .'/*_'. $ref_seq_id .'.maplist');
    unless (@map_lists) {
        $self->error_message("No map lists found for ref seq $ref_seq_id in " . $self->accumulated_alignments_directory);
    }
    return @map_lists;
}

sub _get_sub_command_class_name{
  return __PACKAGE__; 
}

1;

