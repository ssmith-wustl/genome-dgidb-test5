package Genome::Model::Command::AddReads::AnnotateVariations;

use strict;
use warnings;

use above "Genome";
use Command; 

class Genome::Model::Command::AddReads::AnnotateVariations {
    is => ['Genome::Model::EventWithRefSeq'],
    sub_classification_method_name => 'class',
    has => [
    ]
};

sub sub_command_sort_position { 90 }

sub help_brief {
    "Generates basic annotation for the variations found."
}

sub help_synopsis {
    return <<"EOS"
    genome-model postprocess-alignments annotate-variations --model-id 5 --ref-seq-id 22 
EOS
}

sub help_detail {
    return <<"EOS"
This does simple automated annotation of discovered variants.  Complex comparision/reporting is done elsewhere.
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

    my ($reports_dir) = $model->_reports_dir();
    print "$reports_dir\n";
    unless (-d $reports_dir) {
        mkdir $reports_dir;
        `chmod g+w $reports_dir`;
    }

    # make files in that dir here...

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


