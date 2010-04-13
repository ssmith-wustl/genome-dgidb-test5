package Genome::Capture::Set::View::SearchResult::Xml;

use strict;
use warnings;

use Genome;

class Genome::Capture::Set::View::SearchResult::Xml {
    is => 'Genome::View::SearchResult::Xml',
    has_constant => [
        default_aspects => {
            is => 'ARRAY',
            default => [
                'id',
                'name',
                'status',
                'description',
            ]
        }
    ]
};

sub _generate_details_result_xml {
    my $self = shift;
    my $subject = $self->subject;
    my $result_node = $self->_result_node;
    
    my $xml_doc = $result_node->ownerDocument;
    
    my $status_node => $result_node->addChild( $xml_doc->createElement('status') );
    $status_node->addChild( $xml_doc->createTextNode($subject->status) );
    
    my $description_node => $result_node->addChild( $xml_doc->createElement('description') );
    $description_node->addChild( $xml_doc->createTextNode($subject->description) );
    
    return $result_node;
}

1;
