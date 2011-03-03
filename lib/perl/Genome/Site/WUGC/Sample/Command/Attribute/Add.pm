package Genome::Sample::Command::Attribute::Add;

use strict;
use warnings;

use Genome;

class Genome::Sample::Command::Attribute::Add {
    is => 'Genome::Command::Base',
    has => [
        sample => { 
            is => 'Genome::Sample',
            doc => 'The sample for which to add an attribute',
            shell_args_position => 1,
        },
        name => {
            is => 'Text',
            doc => 'The name of the attribute',
        },
        value => {
            is => 'Text',
            doc => 'The value of the attribute',
        },
        nomenclature => {
            is => 'Text',
            doc => 'The source of the information',
            default_value => 'WUGC',
        },
    ],
};

sub help_brief {
    "Add an attribute to a sample.",
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
 genome sample attribute add --name 'example_attribute_name' --value 'example attribute value' --nomenclature 'WUGC' 12345
EOS
}

sub help_detail {                           
    return <<EOS 
Add an attribute to a sample.  This command will not allow updating an existing attribute.
EOS
}

sub execute {
    my $self = shift;

    my $existing_attribute = Genome::Sample::Attribute->get(
        sample_id => $self->sample->id,
        nomenclature => $self->nomenclature,
        name => $self->name,
    );
    if($existing_attribute) {
        if($existing_attribute->value eq $self->value) {
            $self->warning_message('The requested attribute ' . $self->name . ' already exists with the requested value ' . $self->value . ' for sample ' . $self->sample->name . '.');
            return $existing_attribute;
        } else {
            $self->error_message('Found existing attribute for that name, sample, and nomenclature. Existing attributes for this sample:');

            my $filter = 'sample_id=' . $self->sample->id;
            Genome::Sample::Command::Attribute::List->execute( filter => $filter );
            return;
        }
    }

    my $attribute = Genome::Sample::Attribute->create(
        sample_id => $self->sample->id,
        nomenclature => $self->nomenclature,
        name => $self->name,
        value => $self->value,
    );

    return $attribute;
}

1;
