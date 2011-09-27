package Genome::Sample::View::EditNomenclature::Xml;

use strict;
use warnings;

use Genome;

class Genome::Sample::View::EditNomenclature::Xml {
    is => 'UR::Object::View::Default::Xml',
    has => [
        'nomenclature_id' => { is => 'Text' }
    ],
    has_constant => [
        default_aspects => {
            is => 'ARRAY',
            value => [
                'id',
                'name',
                {
                    name => 'attributes',
                    perspective => 'default',
                    toolkit => 'xml',
                    aspects => ['nomenclature_name','nomenclature_field_name','attribute_label','attribute_value','subject_id']
                }
            ]
        }
    ]
};


sub _generate_content {

    my ($self) = @_;

#    my $subject = $self->subject();

$DB::single = 1;
    my $view = $self->SUPER::_generate_content();
    my $doc = $view->_xml_doc();

    my $nom_element = $doc->createElement('nomenclature');
    $nom_element->addChild( $doc->createAttribute('name', 'shit') );

    return $doc->toString(1);
}




1;
