package Genome::Model::Event::Build::DeNovoAssembly::Report;

use strict;
use warnings;

use Genome;

class Genome::Model::Event::Build::DeNovoAssembly::Report {
    is => 'Genome::Model::Event::Build::DeNovoAssembly',
};

sub execute {
    my $self = shift;
    $self->status_message('De novo assembly report...');

    #run stats
    my $tools_base_class = $self->processing_profile->tools_base_class;
    my $metrics_class;
    for my $subclass_name (qw/ Metrics Stats /) {
        $metrics_class = $tools_base_class.'::'.$subclass_name;
        my $meta = eval{ $metrics_class->__meta__; };
        last if $meta;
        undef $metrics_class;
    }
    if ( not $metrics_class ) {
        $self->error_message('Failed to find metrics/stats class for assembler: '.$self->processing_profile->assembler);
        return;
    }
    my $major_contig_length = ( $self->build->processing_profile->name =~ /PGA/ ? 300 : 500 );
    $self->status_message('Assembly directory: '.$self->build->data_directory);
    $self->status_message('Major contig length: '.$major_contig_length);
    my $metrics = $metrics_class->create(
        assembly_directory => $self->build->data_directory,
        major_contig_length => $major_contig_length,
    );
    if ( not $metrics ) {
        $self->error_message('Failed to create metrics tool: '.$metrics_class);
        return;
    }
    unless( $metrics->execute ) {
        $self->error_message("Failed to create stats");
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

    $self->status_message('De novo assembly report...OK');
    return 1;
}

1;

