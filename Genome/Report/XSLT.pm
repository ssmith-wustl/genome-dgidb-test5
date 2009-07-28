package Genome::Report::XSLT;

use strict;
use warnings;

use Genome;

use Carp 'confess';
use Data::Dumper 'Dumper';
use XML::LibXML;
use XML::LibXSLT;

class Genome::Report::XSLT {
};

sub transform_report {
    my ($class, %params) = @_;

    my $report = delete $params{report};
    unless ( $report ) {
        $class->error_message("Report is required to transform");
        return;
    }
               
    my $xslt_file = delete $params{xslt_file};
    Genome::Utility::FileSystem->validate_file_for_reading($xslt_file)
        or return;

    my $xml = XML::LibXML->new();
    my $xml_string = $xml->parse_string( $report->xml_string );
    my $style_doc = eval{ $xml->parse_file( $xslt_file ) };
    print "<pre>Continuing after error: $@</pre>" if $@;

    my $xslt = XML::LibXSLT->new();
    my $stylesheet = eval { $xslt->parse_stylesheet($style_doc) };
    print "<pre>Continuing after error: $@</pre>" if $@;

    my $transformed_xml = $stylesheet->transform($xml_string);

    return {
        content => $stylesheet->output_string($transformed_xml),
        encoding => $stylesheet->output_encoding,
        media_type => $stylesheet->media_type,
    };
}

1;

=pod

=head1 Name

Genome::Report::XSLT

=head1 Synopsis

=head1 Usage

 use Genome;
 
 # Get or generate a report...
 my $report = Genome::Report->create_report_from_directory(...);
 
 # Grab a xslt file
 my $xslt_file = ...;
 
 # Transform
 my $xslt = Genome::Report::XSLT->transform_report(
    report => $report, # required
    xslt_file => $xslt_file, #required
 );

 print "Content: ".$xslt->{content}."\n";

 ...
 
=head1 Public Methods

=head2 transform_report

 my $string = Genome::Report::XSLT->transform_report(report => $report, xslt_file => $xslt_file);

=over

=item I<Synopsis>   Takes a report and an xslt file (as a hash), and returns the transformed report as a string

=item I<Arguments>  report (Genome::Report), xslt_file (readable file)

=item I<Returns>    hashref with content, media_type, and encoding keys.

=back

=head1 Disclaimer

Copyright (C) 2009 Washington University Genome Sequencing Center

This module is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

=head1 Author(s)

B<Eddie Belter> I<ebelter@genome.wustl.edu>

=cut

#$HeadURL$
#$Id$
