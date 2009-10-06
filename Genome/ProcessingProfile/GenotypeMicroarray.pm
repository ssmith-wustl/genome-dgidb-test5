package Genome::ProcessingProfile::GenotypeMicroarray;

use Genome;
my %PROPERTIES = &properties_hash;

# TODO: nearly all of this is boilerplate copied from ReferenceAlignment.
# Pull the guts into the base class and improve the infrastructure so making new models types is easy.

class Genome::ProcessingProfile::GenotypeMicroarray {
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

# Currently all processing profiles must implement the stages() method.
# This is sad.  We have a workflowless simple build which want to do less.
# I believe Eric Clark is fixing this.
sub stages {
    return ();
}

sub properties_hash {
    my %properties = (
        input_format => {
            doc => 'file format, defaults to "wugc", which is currently the only format supported',
            valid_values => ['wugc'],
            default_value => 'wugc',
        },
        instrument_type => {
            doc => 'the type of microarray instrument',
            valid_values => ['illumina','affymetrix','unknown'],
        },
    );
    return %properties;
}

sub create {
    # TODO: stop going into the hashref of the class object
    # TODO: pull into the base class.
    my $class = shift;
    my $self = $class->SUPER::create(@_);
    my $class_object = $self->get_class_object;
    for my $property_name ( keys %PROPERTIES ) {
        next if $class_object->{has}->{$property_name}->{is_optional} && !defined($self->$property_name);
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

sub params_for_class {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my %properties = &properties_hash;
    return keys %properties;
}

1;

