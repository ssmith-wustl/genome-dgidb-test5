package Genome::Nomenclature::View::Detail::Json;

use strict;
use warnings;
require UR;

use XML::Simple;
use JSON;

class Genome::Nomenclature::View::Detail::Json {
    is => 'UR::Object::View::Default::Json',
    has_constant => [
        toolkit     => { value => 'json' },
    ],
    has_optional => [
        encode_options => { is => 'ARRAY', default_value => ['ascii', 'pretty', 'allow_nonref', 'canonical'], doc => 'Options to enable on the JSON object; see the documentation for the JSON Perl module' },
    ],
};


sub _generate_content {
    my $self = shift;


    my $obj = $self->subject();

    if (!$obj) {
        Carp::confess('This JSON view couldnt get the subject of the view. class='
                    , $self->subject_class_name
                    . ' id='
                    . $self->subject_id);
    }

##        perspective => $self->perspective(),
#    my %view_args = (
#        subject_class_name => $self->subject_class_name,
#        perspective => 'detail',
#        toolkit => 'xml'
#    );
#    my $xml_view = $obj->create_view(%view_args);
#    my $xml = $xml_view->content();
#    my $hash = XMLin($xml);

    my $hash = {};
    my $nomenclature = $obj;

    $hash->{name} = $nomenclature->name;
    $hash->{fields} = [];

    for my $field ($nomenclature->fields) {
        my $f = {}; 
        $f->{name} = $field->name;
        $f->{type} = $field->type;
        $f->{enumerated_values} = [map {$_->value} $field->enumerated_values];
    
        push @{$hash->{fields}}, $f;
    }

    return $self->_json->encode($hash);
}



1;
