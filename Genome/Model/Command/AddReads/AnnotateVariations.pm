package Genome::Model::Command::AddReads::AnnotateVariations;

use strict;
use warnings;

use above "Genome";

use Genome::Model::Command::Report::VariationsBatchToLsf;

class Genome::Model::Command::AddReads::AnnotateVariations {
    is => [ 'Genome::Model::EventWithRefSeq' ],
    sub_classification_method_name => 'class',
};

#########################################################

sub sub_command_sort_position { 90 } # TODO needed?

# TODO Add doc
sub help_brief {
    "Automates variant annotation reporting during add reads"
}

sub help_synopsis {
    return;
}

sub help_detail {
    return <<"EOS"
This module implements the automation of annotating variants discovered during the add reads pipeline.
For the actual annotation process see: 
Genome::SnpAnnotator
For the report process (which runs the annotator) see:
Genome::Model::Command::Report::Variations 
Genome::Model::Command::Report::VariationsBatchToLsf
EOS
}

sub execute {
    my $self = shift;
    
    my $chromosome_name = $self->ref_seq_id;
    my $model = $self->model;
    my ($detail_file) = $model->_variant_detail_files($chromosome_name);
    my $log_dir = $self->resolve_log_directory;

    $DB::single = 1; # when debugging, stop here...

    my ($reports_dir) = $model->_reports_dir();
    print "$reports_dir\n";
    unless (-d $reports_dir) {
        mkdir $reports_dir;
        `chmod g+w $reports_dir`;
    }

    my $success = Genome::Model::Command::Report::VariationsBatchToLsf->execute
    (
        chromosome_name => $chromosome_name,
        variation_type => 'snp', # TODO run for each type
        variant_file => $detail_file,
        report_file => sprintf('%s/snp_report_%s', $reports_dir, $chromosome_name),
        out_log_file => sprintf('%s/%s.out', $log_dir, $self->lsf_job_id || $chromosome_name),
        error_log_file => sprintf('%s/%s.err', $log_dir, $self->lsf_job_id || $chromosome_name),
        # OTHER PARAMS:
        # flank_range => ??,
        # variant_range => ??,
        # format => ??,
    );

    if ( $success )
    { 
        $self->event_status("Succeeded");
    }
    else 
    {
        $self->event_status("Failed");
    }

    $self->date_completed( UR::Time->now );

    return $success;
}

1;

#$HeadURL$
#$Id$
