package Genome::Model::Command::AddReads::AnnotateVariations;

use strict;
use warnings;

use above "Genome";

use Genome::Model::Command::Report::VariationsBatchToLsf;
use Genome::Model::EventWithRefSeq;

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

sub snp_report_file {
    my $self = shift;

    return $self->_report_file('snp');
}

sub indel_report_file {
    my $self = shift;

    return $self->_report_file('indel');
}

sub _report_file {
    my ($self, $type) = @_;

    return sprintf('%s/variant_report_for_chr_%s', ($self->model->_reports_dir)[0], $self->ref_seq_id);
    return sprintf('%s/%s_report_%s', $type, ($self->model->_reports_dir)[0], $self->ref_seq_id);
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
        #report_file => $self->snp_report_file,
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

###Metrics-------------------------------

sub metrics_for_class {
    my $class = shift;

    my @metric_names = qw(
                          SNV_count
                          SNV_in_dbSNP_count
                          SNV_in_venter_count
                          SNV_in_watson_count
                          SNV_distinct_count
                          HQ_SNP_count
                          HQ_SNP_reference_allele_count
                          HQ_SNP_variant_allele_count
                          HQ_SNP_both_allele_count
    );

    return @metric_names;
}

sub SNV_count {
    my $self=shift;
    return $self->get_metric_value('SNV_count');
}

##########THESE METHODS SHOULD PROLLY CLOSE THEIR FILE HANDLES TOO, YO#######
sub _calculate_SNV_count {
    $DB::single=1;
    my $self=shift;
    my $snp_file = $self->snp_report_file;
    my $c = 0;
    my $fh = IO::File->new($snp_file);
    while ($fh->getline) {
        $c++
    }
    return $c;
}

sub SNV_in_dbSNP_count {
    my $self=shift;
    return $self->get_metric_value('SNV_in_dbSNP_count');
}

sub _calculate_SNV_in_dbSNP_count {
    my $self=shift;
    my $snp_file = $self->snp_report_file;
    my $c = 0;
    my $fh = IO::File->new($snp_file);
    while (my $line=$fh->getline) {
        $c++ if ($line =~ /^1/);
    }
    return $c;
}

sub SNV_in_watson_count {
    my $self=shift;
    return $self->get_metric_value('SNV_in_watson_count');
}

sub _calculate_SNV_in_watson_count {
    my $self=shift;
    my $snp_file = $self->snp_report_file;
    my $c = 0;
    my $fh = IO::File->new($snp_file);
    while (my $line=$fh->getline) {
        $c++ if ($line =~ /watson/i);
    }
    return $c;
}

sub SNV_in_venter_count {
    my $self=shift;
    return $self->get_metric_value('SNV_in_venter_count');
}

sub _calculate_SNV_in_venter_count {
    my $self=shift;
    my $snp_file = $self->snp_report_file;
    my $c = 0;
    my $fh = IO::File->new($snp_file);
    while (my $line=$fh->getline) {
        $c++ if ($line =~ /venter/i);
    }
    return $c;
}

sub SNV_distinct_count {
    my $self=shift;
    return $self->get_metric_value('SNV_distinct_count');
}

sub _calculate_SNV_distinct_count {
    my $self=shift;
    my $snp_file = $self->snp_report_file;
    my $c = 0;
    my $fh = IO::File->new($snp_file);
    while (my $line=$fh->getline) {
        $c++ if ($line !~ /venter/i && $line !~ /watson/i  && $line !~/^1/);
    }
    return $c;
}

sub HQ_SNP_count {
    my $self=shift;
    return $self->get_metric_value('HQ_SNP_count');
}

sub _calculate_HQ_SNP_count {
    my $self=shift;
    ###how do i do this? I don't know. I should probably word count the filtered snp file, but maybe not.
}

sub HQ_SNP_reference_allele_count {
    my $self=shift;
    return $self->get_metric_value('HQ_SNP_reference_allele_count');
}

sub _calculate_HQ_SNP_reference_allele_count {
    my $self=shift;
    ###how do i do this? I don't know. I should probably word count the filtered snp file then do something else, but maybe not.
}

sub HQ_SNP_variant_allele_count {
    my $self=shift;
    return $self->get_metric_value('HQ_SNP_variant_allele_count');
}

sub _calculate_HQ_SNP_variant_allele_count {
    my $self=shift;
    ###how do i do this? I don't know. I should probably word count the filtered snp file then do something else, but maybe not.
}

sub HQ_SNP_both_allele_count {
    my $self=shift;
    return $self->get_metric_value('HQ_SNP_both_allele_count');
}

sub _calculate_HQ_SNP_both_allele_count {
    my $self=shift;
    ###how do i do this? I don't know. I should probably word count the filtered snp file then do something else, but maybe not.
}



1;

#$HeadURL$
#$Id$
