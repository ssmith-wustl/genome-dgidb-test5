package Genome::ProcessingProfile::Assembly;

use strict;
use warnings;

use Genome;

my %PROPERTIES = &properties_hash;

class Genome::ProcessingProfile::Assembly{
    is => 'Genome::ProcessingProfile',
    has => [
            map {
                $_ => {
                       via => 'params',
                       to => 'value',
                       where => [ name => $_ ],
                       is_optional => (
                                       ( exists $PROPERTIES{$_}->{is_optional} )
                                       ? $PROPERTIES{$_}->{is_optional}
                                       : 0
				       ),
                       is_mutable => 1,
                       doc => (
                               ( exists $PROPERTIES{$_}->{valid_valiues} )
                               ? sprintf('%s Valid values: %s.', $PROPERTIES{$_}->{doc}, join(', ', @{$PROPERTIES{$_}->{valid_values}}))
                               : $PROPERTIES{$_}->{doc}
                           ),
                   },
               } keys %PROPERTIES
        ],
};

sub properties_hash {
    my %properties = (
                      sequencing_platform => {
                                              doc => 'The sequencing platform used to produce the read sets to be assembled',
                                              valid_values => ['454', 'solexa'],
                                          },
                      assembler_name => {
                                         doc => 'The name of the assembler to use when assembling read sets',
                                         valid_values => ['newbler'],
                                     },
                      assembler_params => {
                                           doc => 'A string of parameters to pass to the assembler',
                                           is_optional => 1,
                                       },
		      assembler_version => {
			                     doc => 'Version of assembler to use',
					 },
                      read_trimmer_name => {
                                            doc => 'The name of the software to use when trimming read sets',
                                            is_optional => 1,
                                        },
                      read_trimmer_params => {
                                              doc => 'A string of parameters to pass to the read_trimmer',
                                              is_optional => 1,
                                          },
                      read_filter_name => {
                                           doc => 'The name of the software to use when filtering read sets',
                                           is_optional => 1,
                                       },
                      read_filter_params => {
                                             doc => 'A string of parameters to pass to the read_filter',
                                             is_optional => 1,
                                         },
		      );
    return %properties
}

sub params_for_class {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my %properties = &properties_hash;
    return keys %properties;
}

sub create {
    my $class = shift;
    my $self = $class->SUPER::create(@_);
    my $class_object = $self->get_class_object;
    for my $property_name ( keys %PROPERTIES ) {
        next if $class_object->{has}->{$property_name}->{is_optional} && !$self->$property_name;
        next unless exists $PROPERTIES{$property_name}->{valid_values};
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

sub instrument_data_is_applicable {
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

