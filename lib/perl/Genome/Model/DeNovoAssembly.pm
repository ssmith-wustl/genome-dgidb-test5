package Genome::Model::DeNovoAssembly;

use strict;
use warnings;

use Genome;
use Genome::ProcessingProfile::DeNovoAssembly;

class Genome::Model::DeNovoAssembly {
    is => 'Genome::Model',
    has => [
        center_name => {
            is => 'Text',
            via => 'inputs',
            to => 'value_id',
            where => [ name => 'center_name', value_class_name => 'UR::Value' ],
            is_mutable => 1,
            doc => 'Center name',
        },
	    map({
                $_ => {
                    via => 'processing_profile',
                }
            } Genome::ProcessingProfile::DeNovoAssembly->params_for_class
        ),
    ],
};

sub build_subclass_name {
    return 'de-novo-assembly';
}

sub default_model_name {
    my $self = shift;

    my $subject = $self->subject;
    if ( not defined $subject ) {
        $self->error_message('No subject to get default model name for de novo assembly model.');
        return;
    }
    my @name_parts = ( $subject->name );

    if ( $subject->isa('Genome::Sample') and defined $subject->tissue_desc ) {
        my $tissue_name_part = $self->_get_name_part_from_tissue_desc($subject->tissue_desc);
        push @name_parts, $tissue_name_part if defined $tissue_name_part;
    }

    my $center_name = $self->center_name;
    if ( not $center_name ) {
        $self->error_message('No center name to get default model name for de novo assembly model.');
        return;
    }
    if ( $center_name ne 'WUGC' ) {
        push @name_parts, $center_name;
    }

    push @name_parts, $self->processing_profile->name;

    return join(' ', @name_parts);
}

sub _get_name_part_from_tissue_desc {
    my ($self, $tissue_desc) = @_;

    if ( $tissue_desc =~ /dna_/i ) {
        # zs5_g_dna_r_retroauricular crease
        my @tokens = split(/\_/, $tissue_desc);
        return if not @tokens;
        return Genome::Utility::Text::capitalize_words($tokens[$#tokens]);
    }

    return if $tissue_desc =~ /^\d/; # starts w/ number
    return if $tissue_desc =~ /^\w\d+$/; # starts w/ one letter then numbers

    $tissue_desc =~ s/,//g;
    return Genome::Utility::Text::capitalize_words($tissue_desc);
}

1;

