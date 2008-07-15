package Genome::Model::Command::AddReads::AnnotateVariations;

use strict;
use warnings;

use above "Genome";

use Command;
use Data::Dumper;
use Genome::Model::Command::Report::VariationsBatchToLsf;
use Genome::Model::EventWithRefSeq;
#use Genome::Utility::Parser;
use IO::File;

class Genome::Model::Command::AddReads::AnnotateVariations {
    is => [ 'Genome::Model::EventWithRefSeq' ],
    has => [
    _snv_metrics => {
        is => 'list',
        doc => "",
        is_transient => 1,
        is_optional =>1,
    },
    ],
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

#- PROPERTY METHODS -#
sub cleanup_transient_properties {
    my $self = shift;
    
    $self->_snv_metrics(undef);
}

#- SNP REPORTS -#
sub snp_report_file_base {
    my $self = shift;

    return sprintf('%s/%s_snp', ($self->model->_reports_dir)[0], $self->ref_seq_id);
}

sub snp_report_file {
    my $self = shift;

    return sprintf('%s.transcript', $self->snp_report_file_base);
}

sub snp_transcript_report_file {
    my $self = shift;

    return sprintf('%s.transcript', $self->snp_report_file_base);
}

sub snp_variation_report_file {
    my $self = shift;

    return sprintf('%s.variation', $self->snp_report_file_base);
}

sub snp_metrics_report_file {
    my $self = shift;

    return sprintf('%s.metrics', $self->snp_report_file_base);
}

#- INDEL REPORTS -#
sub indel_report_file_base {
    my $self = shift;

    return sprintf('%s/%s_indel', ($self->model->_reports_dir)[0], $self->ref_seq_id);
}

sub indel_report_file {
    my $self = shift;

    return sprintf('%s.transcript', $self->indel_report_file_base);
}

sub indel_transcript_report_file {
    my $self = shift;

    return sprintf('%s.transcript', $self->indel_report_file_base);
}

sub indel_variation_report_file {
    my $self = shift;

    return sprintf('%s.variation', $self->indel_report_file_base);
}

sub indel_metrics_report_file {
    my $self = shift;

    return sprintf('%s.metrics', $self->indel_report_file_base);
}

#- LOG FILES -#
sub snp_out_log_file {
    my $self = shift;

    return sprintf
    (
        '%s/%s.out', #'%s/%s_snp.out',
        $self->resolve_log_directory,
        ($self->lsf_job_id || $self->ref_seq_id),
    );
}

sub snp_err_log_file {
    my $self = shift;

    return sprintf
    (
        '%s/%s.err', #'%s/%s_snp.err',
        $self->resolve_log_directory,
        ($self->lsf_job_id || $self->ref_seq_id),
    );
}

sub indel_out_log_file {
    my $self = shift;
    return sprintf
    (
        '%s/%s.err', #'%s/%s_indel.err',
        $self->resolve_log_directory,
        ($self->lsf_job_id || $self->ref_seq_id),
    );
}

sub indel_err_log_file {
    my $self = shift;

    return sprintf
    (
        '%s/%s.out', #'%s/%s_indel.err',
        $self->resolve_log_directory,
        ($self->lsf_job_id || $self->ref_seq_id),
    );
}

#- EXECUTE -#
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

    # TODO run for each variant type
    my $success = Genome::Model::Command::Report::VariationsBatchToLsf->execute
    (
        variant_type => 'snp', 
        variant_file => $detail_file,
        report_file_base => $self->snp_report_file_base,
        out_log_file => $self->snp_out_log_file,
        error_log_file => $self->snp_err_log_file,
        # OTHER PARAMS:
        # flank_range => ??,
        # variant_range => ??,
        # format => ??,
    );

    $self->generate_metric( $self->snv_metric_names );

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
# total, snvs(score >= 15, rds > 2), distcint, dbsnp-127, watson, venter
sub snv_metrics
{
    my $self = shift;

    return $self->_snv_metrics if $self->_snv_metrics;

    my %metrics;
    foreach my $variant_type (qw/ snp /) #indel
    {
        my $metrics_report_file = $self->snp_metrics_report_file;
        $self->error_message("Can't compute metrics because the metrics file ($metrics_report_file) does not exist")
            and return unless -e $metrics_report_file;
        
        # TODO use Genome::Utility::Parser
        my $fh = IO::File->new("< $metrics_report_file");
        $self->error_message("Can't comput metrics because the metrics file ($metrics_report_file) cannot be opened: $!")
            and return unless $fh;
        $fh->getline;

        my @headers = Genome::Model::Command::Report::VariationsBatchToLsf->metrics_report_headers;

        while ( my $line = $fh->getline )
        {
            chomp $line;
            my $i = 0;
            for my $value ( split(/,/, $line) )
            {
                $metrics{$headers[$i]} += $value;
                $i++;
            }
        }
    }

    return $self->_snv_metrics(\%metrics);
}

#- METRIC NAMES -#
sub metrics_for_class {
    return (snv_metric_names(), hq_snp_metric_names());
}

sub snv_metric_names
{
    return 
    (qw/ 
        SNV_count
        SNV_in_dbSNP_count
        SNV_in_venter_count
        SNV_in_watson_count
        SNV_distinct_count
        /);
}

sub hq_snp_metric_names
{
    return 
    (qw/ 
        HQ_SNP_count
        HQ_SNP_reference_allele_count
        HQ_SNP_variant_allele_count
        HQ_SNP_both_allele_count
        /);
}

# snv count
sub SNV_count {
    my $self=shift;
    
    return $self->get_metric_value('SNV_count');
}

sub _calculate_SNV_count {
    my $self= shift;
    
    my $metrics = $self->snv_metrics
        or return;
    
    return $metrics->{confident};
}

# in dbSNP metric
sub SNV_in_dbSNP_count {
    my $self=shift;
    
    return $self->get_metric_value('SNV_in_dbSNP_count');
}

sub _calculate_SNV_in_dbSNP_count {
    my $self= shift;

    my $metrics = $self->snv_metrics
        or return;
 
    return $metrics->{'dbsnp-127'};
}

# in watson metric
sub SNV_in_watson_count {
    my $self=shift;
    
    return $self->get_metric_value('SNV_in_watson_count');
}

sub _calculate_SNV_in_watson_count {
    my $self= shift;

    my $metrics = $self->snv_metrics
        or return;
 
    return $metrics->{watson};
}

# in venter metric
sub SNV_in_venter_count {
    my $self=shift;

    return $self->get_metric_value('SNV_in_venter_count');
}

sub _calculate_SNV_in_venter_count {
    my $self= shift;
    
    my $metrics = $self->snv_metrics
        or return;
 
    return $metrics->{venter};
}

# distinct (not in any other db) snv count
sub SNV_distinct_count {
    my $self=shift;
    
    return $self->get_metric_value('SNV_distinct_count');
}

sub _calculate_SNV_distinct_count {
    my $self= shift;

    my $metrics = $self->snv_metrics
        or return;
 
    return $metrics->{distinct};
}

####################
####################
####################
# These HQ counts incorporate microarray data, move somewhere else?  

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
