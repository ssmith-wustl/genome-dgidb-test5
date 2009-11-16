package Genome::ProcessingProfile::MetagenomicAssembly;

#:eclark 11/16/2009 Code review.

# Short term: There should be a better way to define the class than %HAS.
# Long term: See Genome::ProcessingProfile notes.

use strict;
use warnings;

use Genome;
use Data::Dumper;

my %PROPERTIES = &properties_hash;

class Genome::ProcessingProfile::MetagenomicAssembly{
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
                               ( exists $PROPERTIES{$_}->{valid_values} )
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
                                              valid_values => ['solexa'],
                                          },
                      assembler_name => {
                                         doc => 'The name of the assembler to use when assembling read sets',
                                         valid_values => ['velvet'],
                                     },
                      contaminant_database => {
                                         doc => 'The contaminant database to screen the reads against',
                                     },
                      contaminant_algorithm => {
                                                doc => 'The algorithm to use for screening reads against a contaminant database',
                                            }

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
    my %properties = @_;
    my $self = $class->SUPER::create(@_);
    unless ($self) {
        return;
    }
    my $class_object = $self->get_class_object;
    for my $property_name ( keys %PROPERTIES ) {
        next if $class_object->{has}->{$property_name}->{is_optional} && !$self->$property_name;
        next unless exists $PROPERTIES{$property_name}->{valid_values};
        unless ( $self->$property_name &&
                 (grep { $self->$property_name eq $_ } @{$PROPERTIES{$property_name}->{valid_values}}) ) {
            $self->error_message(
                sprintf(
                        'Invalid value (%s) for %s.  Valid values: %s',
                        $self->$property_name || '',
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

sub stages {
    my @stages = qw/
        contaminant_screen
        assemble
        verify_successful_completion
    /;
    return @stages;
}

sub contaminant_screen_job_classes {
    my @classes = qw/
            Genome::Model::Command::Build::MetagenomicAssembly::ContaminantScreen
    /;
    return @classes;
}

sub assemble_job_classes {
    my @classes = qw/
            Genome::Model::Command::Build::MetagenomicAssembly::Assemble
    /;
    return @classes;
}

sub contaminant_screen_objects {
    my $self = shift;
    my $model = shift;
    return $model->instrument_data;
}

sub assemble_objects {
    my $self = shift;
    my $model = shift;
    return 1;
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
                                 .') does not match the instrument data type ('. $lc_instrument_data_type .')');
            return;
        }
    }

    return 1;
}

1;

