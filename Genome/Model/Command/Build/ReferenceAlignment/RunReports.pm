package Genome::Model::Command::Build::ReferenceAlignment::RunReports;

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

my @REPORT_TYPES = qw/
        Mapcheck
        DbSnpConcordance
        GoldSnpConcordance
    /;

sub execute {
    my $self = shift;

    my $build = $self->build;
    unless ($self->create_directory($build->resolve_reports_directory) ) {
	die('Could not create reports directory at: '. $build->resolve_reports_directory);
    }

    for my $report_type (@REPORT_TYPES) {
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
        #print $build->resolve_reports_directory,"\n";<STDIN>;
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

    my $mail_dest = ($build->id < 0 ? Genome::Config->user_email() . ',charris@genome.wustl.edu' : 'apipe-run@genome.wustl.edu');
    $self->status_message('Sending summary e-mail to ' . $mail_dest);
    my $mail_rv = Genome::Model::Command::Report::Mail->execute(
        model => $self->model,
        build => $build,
        report_name => "Summary",
        to => $mail_dest,
    );
    $self->status_message("E-mail command executed.  Return value: $mail_rv");

    ###############################################

    return $self->verify_successful_completion;
}

sub verify_successful_completion {
    my $self = shift;

    my $build = $self->build;
    unless ($build) {
        $self->error_message('Failed verify_successful_completion of RunReports step. Build is undefined.');
        return;
    }
    my $report_dir = $build->resolve_reports_directory;

    for my $sub_directory ( 'Mapcheck', 'dbSNP_Concordance', 'Gold_SNP_Concordance', 'Summary') {
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
