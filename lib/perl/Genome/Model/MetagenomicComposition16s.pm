package Genome::Model::MetagenomicComposition16s;

use strict;
use warnings;

use Genome;

class Genome::Model::MetagenomicComposition16s {
    is => 'Genome::Model',
    has => [
    map({
            $_ => {
                via => 'processing_profile',
            }
        } Genome::ProcessingProfile::MetagenomicComposition16s->params_for_class
    ),
    ],
};

sub build_subclass_name {
    return 'metagenomic-16s-composition';
}

sub _additional_parts_for_default_model_name {
    my $self = shift;

    my @parts;
    my $subject = $self->subject;
    if ( $subject->isa('Genome::Sample') and defined $subject->tissue_desc ) {
        push @parts, $subject->tissue_desc;
    }

    return @parts;
}

1;

