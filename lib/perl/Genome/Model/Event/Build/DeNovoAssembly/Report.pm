package Genome::Model::Event::Build::DeNovoAssembly::Report;

use strict;
use warnings;

use Genome;

class Genome::Model::Event::Build::DeNovoAssembly::Report {
    is => 'Genome::Model::Event::Build::DeNovoAssembly',
    #is_abstract => 1,
};

sub execute {
    my $self = shift;

    #run stats
    unless( $self->processing_profile->generate_stats( $self->build ) ) {
	$self->error_message("Failed to generate stats for report");
	return;
    }

    # generate
    my $generator = Genome::Model::DeNovoAssembly::Report::Summary->create(
        build_id => $self->build_id,
    );
    unless ( $generator ) {
        $self->error_message("Can't create summary report generator");
        return;
    }

    my $report = $generator->generate_report;
    unless ( $report ) {
        $self->error_message("Can't generate summary report");
        return;
    }

    # save
    unless ( $self->build->add_report($report) ) {
        $self->error_message("Can't save summary report");
    }

    # save html
    my $xsl_file = $generator->get_xsl_file_for_html;
    my $xslt = Genome::Report::XSLT->transform_report(
        report => $report,
        xslt_file => $xsl_file,
    );
    unless ( $xslt ) {
        $self->error_message("Can't transform report to html.");
        return;
    }
    my $html_file = $report->directory.'/report.html';
    my $fh = Genome::Sys->open_file_for_writing($html_file); # dies
    $fh->print( $xslt->{content} );
    $fh->close;

    return 1;
}

1;

#$HeadURL$
#$Id$
