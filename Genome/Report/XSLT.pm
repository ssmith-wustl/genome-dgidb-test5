package Genome::Report::XSLT;

use strict;
use warnings;

use Genome;

use Carp 'confess';
use Data::Dumper 'Dumper';
use XML::LibXML;
use XML::LibXSLT;

class Genome::Report::XSLT {
    is => 'UR::Object',
    has => [
    report => { 
        is => 'Genome::Report',
        doc => 'Report to apply XSLT to',
    },
    xslt_file => {
        is => 'Text',
        doc => 'XSLT file',
    },
    ],
};

#< Get/Create >#
sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_)
        or return;

    unless ( $self->report ) {
        $self->error_message("Report is required to create");
        $self->delete;
        return;
    }

    unless ( $self->xslt_file ) {
        $self->error_message("XSLT file is required to create");
        $self->delete;
        return;
    }

    return $self;
}

#< XLST >#
sub transform_report {
    my $self = shift;

    my $string = "Content-Type: text/html; charset=ISO-8859-1\r\n\r\n";

    my $xml = XML::LibXML->new();
    my $xml_string = $xml->parse_string( $self->report->xml_string );
    my $style_doc = eval{ $xml->parse_file( $self->xslt_file ) };
    print "<pre>Continuing after error: $@</pre>" if $@;

    my $xslt = XML::LibXSLT->new();
    my $stylesheet = eval { $xslt->parse_stylesheet($style_doc) };
    print "<pre>Continuing after error: $@</pre>" if $@;

    my $transformed_xml = $stylesheet->transform($xml_string);

    return $stylesheet->output_string($transformed_xml);
}

1;

=pod

=head1 Name

Genome::Report::XSLT

=head1 Synopsis

=head1 Usage

 my $generator = Genome::Report::Generator->create(
    name => 'Happy', # required
    ..other params...
 );

 my $report = $generator->generate_report
    or die;

 $report->save('some_directory')
    or die;

=head1 Public Methods

=head2 generate_report

 my $report = $generator->generate_report
    or die;

=over

=item I<Synopsis>   Generates data and creates a Genome::Report

=item I<Arguments>  none

=item I<Returns>    Genome::Report

=back

=head1 Private Methods Implemented in Subclasses

=head2 _generate_data

=over

=item I<Synopsis>   Generates data and returns a hashref containing keys description, html (opt) and csv (opt)

=item I<Arguments>  none

=item I<Returns>    hashref 

=back

=head1 See Also

=head1 Disclaimer

Copyright (C) 2005 - 2008 Washington University Genome Sequencing Center

This module is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

=head1 Author(s)

B<Eddie Belter> I<ebelter@watson.wustl.edu>

=cut

#$HeadURL$
#$Id$
