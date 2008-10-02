package Genome::ProcessingProfile::MetaGenomicComposition;

use strict;
use warnings;

use Genome;

my %PROPERTIES = (
    sequencing_center => {
        doc => 'Place from whence the reads have come.',
        valid_values => [qw/ gsc broad baylor nisc /],
    },
    sequencing_platform => {
        doc => 'Platform (machine) from whence the reads where created.',
        valid_values => [qw/ 3730 454 solexa solid /],
    },
    assembler => {
        doc => 'Assembler type for assembling said reads.',
        valid_values => [qw/ maq newbler pcap phredphrap /],
    },
);

class Genome::ProcessingProfile::MetaGenomicComposition {
    is => 'Genome::ProcessingProfile',
    has => [
    map { 
        $_ => {
            via => 'params',
            to => 'value',
            where => [ name => $_ ],
            is_optional => 0,
            is_mutable => 1,
            doc => sprintf(
                '%s Valid values: %s.', 
                $PROPERTIES{$_}->{doc},
                join(', ', @{$PROPERTIES{$_}->{valid_values}}),
            ),
        },
    } keys %PROPERTIES
    ],
};

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_);

    for my $property_name ( keys %PROPERTIES ) {
        unless ( grep { $self->$property_name eq $_ } @{$PROPERTIES{$property_name}->{valid_values}} ) {
            $self->error_message( 
                sprintf(
                    'Invalid value (%s) for %s.  Valid values: %s',
                    $self->$property_name,
                    $property_name,
                    join(', ', @{$PROPERTIES{$property_name}->{valid_values}}),
                ) 
            );
            $self->delete;
            return;
        }
    }

    return $self;
}

sub params_for_class { 
    return keys %PROPERTIES;
}

sub instrument_data_is_applicable { #FIXME needed?
    my $self = shift;
    my $instrument_data_type = shift;
    my $instrument_data_id = shift;
    my $subject_name = shift;

    my $lc_instrument_data_type = lc($instrument_data_type);
    if ($self->sequencing_platform) {
        unless ($self->sequencing_platform eq $lc_instrument_data_type) {
            $self->error_message('The processing profile sequencing platform ('. $self->sequencing_platform
                                 .') does not match the instrument data type ('. $lc_instrument_data_type);
            return;
        }
    }

    return 1;
}

1;

#$HeadURL$
#$Id$
