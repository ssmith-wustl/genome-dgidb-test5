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

use Genome::Model::Command::Report::Variations;

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

    my $eval;
    eval
    {
        $eval = Genome::Model::Command::Report::Variations->execute
        (
            variant_file => $detail_file,
            report_file => sprintf('%s/%s.out', $reports_dir, File::Basename::basename($detail_file)),
            chromosome_name => $chromosome,
            # variant_type => 'snp',
            # flank_range => ??,
            # format => ??,
        );
    };

    $self->date_completed(UR::Time->now);

    unless ( $eval )
    { 
        $self->event_status("Failed");
        $self->error_message($@) if $@;
        return;
    }
    else 
    {
        $self->event_status("Succeeded");
        return 1;
    }
}

1;

#$HeadURL$
#$Id$
