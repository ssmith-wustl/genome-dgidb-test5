#:eclark Shouldn't use Data::Dumper (since it doesnt actually use it) and there's 
# no reason to overload create, since we're not doing anything with it here.
package Genome::Model::ViromeScreen;

use strict;
use warnings;

use Genome;
use Data::Dumper;
require Genome::ProcessingProfile::ViromeScreen;

class Genome::Model::ViromeScreen {
    is => 'Genome::ModelDeprecated',
    has => [
        barcode_file => {
            doc => 'Barcode file that contains sequences to filter reads by',
            is => 'String',
            is_optional => 1,
        },
	    map { $_ => { via => 'processing_profile' } } 
            Genome::ProcessingProfile::ViromeScreen->params_for_class,

    ],
};

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_);

    unless (-s $self->barcode_file) {
        $self->error_message("Error: Uable to open file: ".$self->barcode_file);
        $self->delete;
        return;
    }

    $self->build->barcode_file($self->barcode_file);

    return $self;
}

1;

