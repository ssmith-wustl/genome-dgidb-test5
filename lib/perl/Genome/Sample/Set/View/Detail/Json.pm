package Genome::Sample::Set::View::Detail::Json;

use strict;
use warnings;
require UR;

use XML::Simple;
use JSON;

class Genome::Sample::Set::View::Detail::Json {
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

    my $set = $self->subject();

    if (!$set) {
        Carp::confess('This JSON view couldnt get the subject of the view. class='
                    . $self->subject_class_name
                    . ' id='
                    . $self->subject_id);
    }

    my $h = {};
    for my $sample ($set->members()) {

        my $sample_name = $sample->name();
        $h->{'aaData'}->{$sample_name}->{'id'} = $sample->id();

        for my $a ($sample->attributes()) {
            push @{ $h->{'aaData'}->{$sample_name}->{'attr'} }, {
                nomenclature_name       => $a->nomenclature_name(),
                nomenclature_field_name => $a->nomenclature_field_name(),
                attribute_value         => $a->attribute_value()
                };
        }
    }

    return $self->_json->encode($h);
}



1;
