package Genome::ProcessingProfile::Command::Create;

#REVIEW fdu 11/23/2009
#3. List all the models using supersedse pp name if supersedse option given

use strict;
use warnings;

use Genome;
use Carp 'confess';
use Regexp::Common;

class Genome::ProcessingProfile::Command::Create {
    is => 'Command::DynamicSubCommands',
    is_abstract => 1,
    has => [
        name => {
            is => 'Text',
            len => 255, 
            doc => 'Human readable name.', 
        },
        based_on => {
            is => 'Text',
            len => '255',
            doc => "The name or ID of another profile which is used to specify default values for this new one. To qualify a the based on profile must have params, and at least one must be different. Use --param-name='UNDEF' to indicate that a param that is defined for the based on profile should not be for the new profile.",
            is_optional => 1,
        },
        supersedes => {
            is => 'Text',
            len => '255',
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

sub _sub_commands_from { 'Genome::ProcessingProfile' }

sub sub_command_sort_position { 1 }

# Overriding this method from Command::DynamicSubCommands so parameters from each of the
# processing profiles are carried over into the create command
sub _build_sub_command {
    my $self = shift;
    my ($suggested_class_name,$delegator_class_name,$target_class_name) = @_;
    
    my $profile_string = $target_class_name;
    $profile_string =~ s/Genome::ProcessingProfile:://;
    $profile_string = Genome::Utility::Text::camel_case_to_string($profile_string);
    $profile_string =~ s/:://;

    class {$suggested_class_name} { 
        is => $delegator_class_name, 
        subclassify_by => 'class',
        has => [
            __PACKAGE__->_properties_for_class($target_class_name),
        ],
        doc => "Create a new profile for $profile_string"
    };

    return ($suggested_class_name);
}

sub help_synopsis {
    my $self = $_[0];
    my $profile_class_name = _get_subclass(@_) or return;
    $profile_class_name = 'Genome::ProcessingProfile::' . $profile_class_name; 
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
    my $profile_class_name = _get_subclass(@_) or return;
    $profile_class_name = 'Genome::ProcessingProfile::' . $profile_class_name; 
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
    if (my $based_on = $self->based_on) {
        my $target_class = $self->_target_class;
        my $other_profile;
        if ($based_on =~ /^$RE{num}{int}$/) { # id
            $other_profile = $target_class->get($based_on);
        }
        else {
            $other_profile = $target_class->get(name => $based_on);
        }
        unless ($other_profile) {
            $self->error_message("Failed to find a processing profile of class $target_class with name or ID '$based_on'!");
            return;
        }
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

    my $target_class = $self->_target_class;
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
            processing_profile_id => $processing_profile->id,
        );
        $describer->execute;
    }

    return 1;
}

# Get only the subclass portion of the package name
sub _get_subclass {
    my $class = ref($_[0]) || $_[0];
    return if $class eq __PACKAGE__;
    $class =~ s/Genome::ProcessingProfile::Command::Create:://;
    return $class;
}

# Figure out the particular processing profile subclass name
sub _target_class {
    my $subclass = _get_subclass(@_) or return;
    return 'Genome::ProcessingProfile::'.$subclass;
}

sub _properties_for_class {
    my ($self, $class) = @_;

    my $class_meta = $class->get_class_object;
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
    my %properties = $self->_properties_for_class( $self->_target_class ) or return;
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

#$HeadURL$
#$Id$
