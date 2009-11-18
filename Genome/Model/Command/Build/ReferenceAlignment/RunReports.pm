package Genome::Model::Command::Build::ReferenceAlignment::RunReports;

#REVIEW fdu 11/18/2009
#Missing ReferenceCoverage report for cDNA or RNA. Either ask jwalker
#to implement it or drop those codes.

use strict;
use warnings;

use Genome;

class Genome::Model::Command::Build::ReferenceAlignment::RunReports {
    is => [ 'Genome::Model::Event' ],
    has => [
    ],
};

#########################################################


# TODO Add doc
sub help_brief {
    "generate standard reports"
}

sub help_synopsis {
    return;
}

sub help_detail {
    return <<"EOS"
Generates GoldSnp report, etc
EOS
}

my %REPORT_TYPES = (
    Mapcheck           => 'Mapcheck',
    DbSnpConcordance   => 'dbSNP_Concordance',
    GoldSnpConcordance => 'Gold_SNP_Concordance',
    InputBaseCounts   => 'Input_Base_Counts'
);


sub execute {
    my $self  = shift;
    my $model = $self->model;
    my $build = $self->build;
    
    #my $gt = $build->model->genotyper_name;
    #unless ($gt =~ /maq/i) {
    #    $self->status_message('For now turn off mapcheck for non-maq based pipeline');
    #    delete $REPORT_TYPES{Mapcheck};
    #}

    if ($model->read_aligner_name =~ /^Imported$/i) {
        $self->status_message("This build uses Imported as alinger so skip InputBaseCounts");
        delete $REPORT_TYPES{InputBaseCounts};
    }

    my $gold_snp_path = $build->gold_snp_path;
    unless ($gold_snp_path and -s $gold_snp_path) {
        $self->status_message("No gold_snp_path provided for the build, skip its report");
        delete $REPORT_TYPES{GoldSnpConcordance};
    }
    unless ( ($model->dna_type eq 'cdna' || $model->dna_type eq 'rna') && $model->reference_sequence_name eq 'XStrans_adapt_smallRNA_ribo' ) {
        delete $REPORT_TYPES{ReferenceCoverage};
    }
    unless ($self->create_directory($build->resolve_reports_directory) ) {
	    die('Could not create reports directory at: '. $build->resolve_reports_directory);
    }

    for my $report_type (keys %REPORT_TYPES) {
        my $report_class = 'Genome::Model::ReferenceAlignment::Report::' . $report_type;
        my $report_name = 'unknown';
        $self->status_message("Starting $report_type report.");

        my $report_def = $report_class->create(build_id => $build->id);
        unless ($report_def) {
            $self->error_message("Error creating report $report_class!: " . $report_class->error_message());
            die($self->error_message);
        }
        $report_name = $report_def->name;
        $self->status_message("Defined report with name $report_name");
        my $report = $report_def->generate_report;
        unless ($report) {
            $self->error_message("Error generating $report_name ($report_class)!: " . $report_class->error_message());
            $report_def->delete;
            die($self->error_message);
        } else {
            $self->status_message("Successfully generated report: $report_name");
        }
        $self->status_message("About to add report: $report_name to build: ".$self->build->id);
        if ($build->add_report($report)) {
            $self->status_message('Saved report: '.$report);
        } else {
            $self->error_message('Error saving '.$report.'. Error: '. $self->build->error_message);
            die($self->error_message);
        }
    }

    ##############################################
    #Summary Report

    $self->status_message('Starting report summary.');
    my $r = Genome::Model::ReferenceAlignment::Report::Summary->create( build_id => $build->id );

    my @templates = $r->report_templates;
    $self->status_message("Using report templates: ". join(",",@templates));

    my $summary_report = $r->generate_report;
    unless ($summary_report->save($build->resolve_reports_directory)) {
        $self->error_message("Failed to save report: ". $summary_report->name .' to '. $build->resolve_reports_directory);
        return;
    }
    $self->status_message('Report summary complete.');

    ###################################################
    #Send user email

    my $mail_dest = ($build->id < 0 ? Genome::Config->user_email() . ',jpeck@genome.wustl.edu' : 'apipe-run@genome.wustl.edu');
    $self->status_message('Sending summary e-mail to ' . $mail_dest);
    my $mail_rv = Genome::Model::Command::Report::Mail->execute(
        model => $self->model,
        build => $build,
        report_name => "Summary",
        to => $mail_dest,
    );
    $self->status_message("E-mail command executed.  Return value: $mail_rv");

=cut

    ###############################################
    #Clean up big consensus file
    my $consensus_file = $build->bam_pileup_file_path;
    if (-s $consensus_file) {
        if (Genome::Utility::FileSystem->bzip($consensus_file) ) {
            $self->status_message("Converted consesnsus file to bzip format.");
        } else {
            $self->error_message("Could NOT convert consensus file to bzip format.  Continuing anyway.");
        }
    }
    #################################################3 
    
=cut

    return $self->verify_successful_completion;
}

sub verify_successful_completion {
    my $self = shift;
    my $model = $self->model;
    my $build = $self->build;
    unless ($build) {
        $self->error_message('Failed verify_successful_completion of RunReports step. Build is undefined.');
        return;
    }

    my $report_dir = $build->resolve_reports_directory;
    
    my $gold_snp_path = $self->build->gold_snp_path;
    delete $REPORT_TYPES{GoldSnpConcordance} unless $gold_snp_path and -s $gold_snp_path;

    delete $REPORT_TYPES{InputBaseCounts} if $model->read_aligner_name =~ /^Imported$/i;

    unless ( ($model->dna_type eq 'cdna' || $model->dna_type eq 'rna') && $model->reference_sequence_name eq 'XStrans_adapt_smallRNA_ribo' ) {
        delete $REPORT_TYPES{ReferenceCoverage};
    }
        
    my @sub_dirs = (values %REPORT_TYPES, 'Summary');  
   
    for my $sub_directory (@sub_dirs) {
        unless (-d $report_dir .'/'. $sub_directory) {
            $self->error_message('Failed verify_successful_completeion of RunReports step.  Failed to find directory: '. $report_dir .'/'. $sub_directory);
            return;
        }
    }
    return 1;
}

1;

#$HeadURL$
#$Id$
