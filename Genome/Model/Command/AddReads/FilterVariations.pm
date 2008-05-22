package Genome::Model::Command::AddReads::FilterVariations;

use strict;
use warnings;

use above "Genome";
use Command; 

class Genome::Model::Command::AddReads::FilterVariations {
    is => ['Genome::Model::EventWithRefSeq'],
    sub_classification_method_name => 'class',
    has => [
    ]
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

sub execute {
    my $self = shift;
    
    my $chromosome = $self->ref_seq_id;
    my $model = $self->model;

    my ($snp_file) = $model->_variant_list_files($chromosome);
    my ($pileup_file) = $model->_variant_pileup_files($chromosome);
    my ($detail_file) = $model->_variant_detail_files($chromosome);

    $DB::single = 1; # when debugging, stop here...

    my ($filtered_list_dir) = $model->_filtered_variants_dir();
    print "$filtered_list_dir\n";
    unless (-d $filtered_list_dir) {
        mkdir $filtered_list_dir;
        `chmod g+w $filtered_list_dir`;
    }

    $self->date_completed(UR::Time->now);
    if (0) { # replace w/ actual check
        $self->event_status("Failed");
        return;
    }
    else {
        $self->event_status("Succeeded");
        return 1;
    }
}

1;

