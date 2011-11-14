package Genome::ProcessingProfile::Command::Create::Base;

use strict;
use warnings;

use Genome;
use Carp 'confess';
use Regexp::Common;

class Genome::ProcessingProfile::Command::Create::Base {
    is => 'Command::V2',
    has => [
        name => {
            is => 'Text',
            len => 255, 
            doc => 'Human readable name.', 
        },
        based_on => {
            is => 'Genome::ProcessingProfile',
            doc => "Another profile which is used to specify default values for this new one. To qualify a the based on profile must have params, and at least one must be different. Use --param-name='UNDEF' to indicate that a param that is defined for the based on profile should not be for the new profile.",
            is_optional => 1,
        },
        supersedes => {
            is => 'Text',
            doc => 'The processing profile name that this replaces',
            is_optional => 1,
        },
        describe => {
            is => 'Boolean',
            doc => 'Display the output of `genome processing-profile describe` for the processing profile that is created',
            default => 1,
            is_optional => 1,
        }
    ],
};

sub help_synopsis {
    my $self = $_[0];
    my $profile_class_name = $self->_target_class_name;
    if ($profile_class_name->can("help_synopsis_for_create")) {
        my $help = $profile_class_name->help_synopsis_for_create();
        return $help;
    }
    else {
        return;
    }
}

sub help_detail {
    my $self = $_[0];
    my $profile_class_name = $self->_target_class_name;
    if ($profile_class_name->can("help_detail_for_create")) {
        my $help = $profile_class_name->help_detail_for_create();
        return $help;
    }
    else {
        return $self->help_brief;
    }
}

sub create {
    my $class = shift;
    my $self = $class->SUPER::create(@_);
    return unless $self;

    my %defaults;
    my $other_profile = $self->based_on;
    if ($other_profile) {
        my @params = $other_profile->params;
        if (not @params) {
            $self->error_message("In order for a processing profile to used as a 'based on', it must have params that can be copied and at least one of them changed. The based on processing profile (".$other_profile->id." ".$other_profile->name.") does not have any params, and cannot be used.");
            return;
        }
        for my $param (@params) {
            my $name = $param->name;
            if ($self->can($name)) {
                my $specified_value = $self->$name;
                if (not defined $specified_value or not length $specified_value) {
                    $self->$name($param->value);
                }
                elsif ( $specified_value eq 'UNDEF' ) { # allow the undef-ing of params, cannot be done from the command line
                    $self->$name(undef);
                }
            } else {
                $self->warning_message("Skipping parameter '$name'; It does not exist on " . $self->class . " perhaps '$name' was deprecated or replaced.");
            }
        }
    }

    return $self;
}

#< Execute and supporters >#
sub execute {
    my $self = shift;

    my $target_class = $self->_target_class_name;
    my %target_params = (
        name => $self->name,
        $self->_get_target_class_params,
    );
    if ($self->supersedes) {
        $target_params{'supersedes'} = $self->supersedes;
    }

    my $processing_profile = $target_class->create(%target_params);

    unless ($processing_profile) {
        $self->error_message("Failed to create processing profile.");
        return;
    }

    if (my @problems = $processing_profile->__errors__) {
        $self->error_message("Error(s) creating processing profile\n\t".  join("\n\t", map { $_->desc } @problems));
        return;
    }

    $self->status_message('Created processing profile:');
    if($self->describe) {
        my $describer = Genome::ProcessingProfile::Command::Describe->create(
            processing_profiles => [ $processing_profile] ,
        );
        $describer->execute;
    }

    return 1;
}

sub _properties_for_class {
    my ($self, $class) = @_;

    my $class_meta = $class->__meta__;
    unless ( $class_meta ) {
        $self->error_message("Can't get class meta object for class ($class)");
        return;
    }

    my %properties;
    for my $param ( $class->params_for_class ) {
        my $property = $class_meta->property_meta_for_name($param);
        unless ( $property ){
            $self->error_message("Can't get property for processing profile param ($param)");
            return;
        }
        my $property_name = $property->property_name;
        $properties{ $property_name } = {
            is => exists $property->{data_type} ? $property->{data_type} : 'Text',
            is_optional => $property->is_optional,
            doc => $property->doc,
        };
        if (defined $property->default_value) {
            $properties{ $property_name }->{'default_value'} = $property->default_value;
        }
    }

    return %properties;
}

sub _target_class_property_names {
    my $self = shift;
    my %properties = $self->_properties_for_class( $self->_target_class_name ) or return;
    return keys %properties;
}

sub _get_target_class_params {
    my $self = shift;

    my %params;
    for my $property_name ( $self->_target_class_property_names ) {
        my $value = $self->$property_name;
        next unless defined $value;
        $params{$property_name} = $value;
    }

    return %params;
}

1;
