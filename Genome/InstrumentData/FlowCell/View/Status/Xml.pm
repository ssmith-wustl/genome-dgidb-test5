package Genome::InstrumentData::FlowCell::View::Status::Xml;

use strict;
use warnings;
use Genome;
use Data::Dumper;
use XML::LibXML;
use XML::LibXSLT;

class Genome::InstrumentData::FlowCell::View::Status::Xml {
    is => 'UR::Object::View::Default::Xml',
        has => [
            _doc    => {
                is_transient => 1,
                doc => 'the XML::LibXML document object used to build the content for this view'
            },
        ],
            has_optional => [
                section => {
                    is => 'String',
                    doc => "NOT IMPLEMENTED YET.  The sub-section of the document to return.  Options are 'all', 'lanes', etc.",
                }
            ],
        };

# this is expected to return an XML string
# it has a "subject" property which is the flowcell we're viewing

sub _generate_content {
    my $self = shift;

    #create the XML doc and add it to the object
    my $doc = XML::LibXML->createDocument();
    $self->_doc($doc);

    my $subject = $self->subject;
    return unless $subject;

    my $flowcell_node = $doc->createElement('flow-cell');
    $flowcell_node->addChild( $doc->createAttribute('id', $subject->flow_cell_id) );

    my $production_node = $flowcell_node->addChild( $doc->createElement('production') );
    $production_node->addChild( $doc->createAttribute('date-started', $subject->production_started) );
    $production_node->addChild( $doc->createAttribute('run-name', $subject->run_name) );
    $production_node->addChild( $doc->createAttribute('run-type', $subject->run_type) );
    $production_node->addChild( $doc->createAttribute('group-name', $subject->group_name) );
    $production_node->addChild( $doc->createAttribute('machine-name', $subject->machine_name) );
    $production_node->addChild( $doc->createAttribute('team-name', $subject->team_name) );

    if ($subject->lane_info) {
        for my $lane ($subject->lane_info) {
            my $instrument_data_node = $flowcell_node->addChild( $doc->createElement('instrument-data') );

            $DB::single = 1;

            $instrument_data_node->addChild( $doc->createAttribute('id', ${$lane}{id}) );
            $instrument_data_node->addChild( $doc->createAttribute('lane', ${$lane}{lane}) );
            my $gerald_directory = ${$lane}{gerald_directory};
            $instrument_data_node->addChild( $doc->createAttribute('gerald-directory', $gerald_directory) )
                if ($gerald_directory and -e $gerald_directory);;

            for my $file (@{ $lane->{lane_reports} }) {
                my $report_node = $instrument_data_node->addChild( $doc->createElement('report'));
                $report_node->addChild( $doc->createAttribute('name', $file) );
            }
        }
    }

    #set the build status node to be the root
    $doc->setDocumentElement($flowcell_node);

    #generate the XML string
    return $doc->toString(1);

}
