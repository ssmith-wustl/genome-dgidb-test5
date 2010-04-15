package Genome::InstrumentData::FlowCell::View::Status::Html;

use strict;
use warnings;
use Genome;
use Data::Dumper;
use XML::LibXML;
use XML::LibXSLT;

class Genome::InstrumentData::FlowCell::View::Status::Html {
    is => 'UR::Object::View::Default::Html',
    has => [
        _doc    => {
            is_transient => 1,
            doc => 'the XML::LibXML document object used to build the content for this view'
        },
    ],
    has_optional => [
        xsl_file => {
            is => 'Text',
            doc => "Parameter which allows the user to specify the XSL file to transform the output by.",
        }
    ],
};

sub _generate_content {
    my $self = shift;

    my $subject = $self->subject;
    return unless $subject;

    # get the xsl
    unless ($self->xsl_file) {
        $self->xsl_file(__FILE__ . '.xsl');
    }
    unless (-e $self->xsl_file) {
        die "Failed to find xsl file: " . $self->xsl_file;
    }
    my $parser = XML::LibXML->new;
    my $xslt = XML::LibXSLT->new;
    my $fh = Genome::Utility::FileSystem->open_file_for_reading($self->xsl_file);
    my $xsl_template = do { local( $/ ) ; <$fh> } ;
    $fh->close();

    # get the xml
    $DB::single = 1;
    my $xml_view = $subject->create_view(
        perspective => $self->perspective,
        toolkit => 'xml',

        # custom for this view
        instance_id => $self->instance_id,
        use_lsf_file => $self->use_lsf_file,
    );
    my $xml_content = $xml_view->_generate_content();

    # convert the xml
    my $source = $parser->parse_string($xml_content);
    my $style_doc = $parser->parse_string($xsl_template);
    my $stylesheet = $xslt->parse_stylesheet($style_doc);
    my $results = $stylesheet->transform($source);
    my $content = $stylesheet->output_string($results);

    return $content;
}

1;

