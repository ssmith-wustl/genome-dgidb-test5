package Genome::ProcessingProfile::Command::Create;

use strict;
use warnings;

use Genome;

use Data::Dumper;
use Genome::ProcessingProfile;
require UR::Object::Command::List;

class Genome::ProcessingProfile::Command::Create {
    is => 'Command',
    is_abstract => 1,
    has => [
    name => {
        is => 'VARCHAR2',
        len => 255, 
        doc => 'Human readable name', 
    },
    ],
};

#< Auto generate the subclasses >#
our @SUB_COMMAND_CLASSES;
my $module = __PACKAGE__;
$module =~ s/::/\//g;
$module .= '.pm';
my $pp_path = $INC{$module};
$pp_path =~ s/$module//;
$pp_path .= 'Genome/ProcessingProfile';
for my $target ( glob("$pp_path/*pm") ) {
    $target =~ s#$pp_path/##;
    $target =~ s/\.pm//;
    my $target_class = 'Genome::ProcessingProfile::' . $target;
    my $target_meta = $target_class->get_class_object;
    unless ( $target_meta ) {
        eval("use $target_class;");
        die "$@\n" if $@;
        $target_meta = $target_class->get_class_object;
    }
    next unless $target_class->isa('Genome::ProcessingProfile');
    next if $target_class->get_class_object->is_abstract;
    my $subclass = 'Genome::ProcessingProfile::Command::Create::' . $target;
    #print Dumper({mod=>$module, path=>$pp_path, target=>$target, target_class=>$target_class,subclass=>$subclass});

    no strict 'refs';
    class {$subclass} {
        is => __PACKAGE__,
        sub_classification_method_name => 'class',
        has => [ 
        __PACKAGE__->_properties_for_class($target_class),
        ],
    };
    push @SUB_COMMAND_CLASSES, $subclass;
}

sub sub_command_dirs {
    my $class = ref($_[0]) || $_[0];
    return ( $class eq __PACKAGE__ ? 1 : 0 );
}

sub sub_command_classes {
    my $class = ref($_[0]) || $_[0];
    return ( $class eq __PACKAGE__ ? @SUB_COMMAND_CLASSES : 0 );
}

sub help_brief {
    my $profile_name = $_[0]->_profile_name;

    return ( $profile_name )
    ? "Create a new pp for $profile_name"
    : "Create a new processing profile";
}

sub help_detail {
    return $_[0]->help_brief();
}

#< Execute and supporters >#
sub execute {
    my $self = shift;

    my $target_class = $self->_target_class;

    # Ensure name is unique
    if ( my $existing_pp = $target_class->get(name => $self->name) ) {
        $self->_pretty_print_processing_profile($existing_pp);
        $self->error_message('Processing profile (above) with same name already exists');
        return;
    }

    # Get params to create.  Make sure we're not duplicating the same params
    my %params = $self->_get_target_class_params;
    if ( %params and my $existing_pp = $target_class->get(%params) ) {
        #if ( $target_class->get_class_object->get_property_objects and my $existing_pp = $target_class->get(%params) ) {
        $self->_pretty_print_processing_profile($existing_pp);
        $self->error_message('Identical processing profile (above) already exists');
        return;
    }

    # Create processing profile
    my $processing_profile = $target_class->create(
        name => $self->name,
        %params
    );
    unless ( $processing_profile ) {
        $self->error_message("Failed to create processing profile");
        return;
    }

    # TODO Check problems from processing profile??
    $self->status_message('Created processing profile:');
    $self->_pretty_print_processing_profile($processing_profile);

    return 1;
}

#< Target class methods >#
sub _get_subclass {
    my $class = ref($_[0]) || $_[0];

    return if $class eq __PACKAGE__;
    
    $class =~ s/Genome::ProcessingProfile::Command::Create:://;

    return $class;
}

sub _target_class {
    my $subclass = _get_subclass(@_)
        or return;
    
    return 'Genome::ProcessingProfile::'.$subclass;
}

sub _profile_name {
    my $profile_name = _get_subclass(@_)
        or return;
    my @words = $profile_name =~ /([A-Z](?:[A-Z]*(?=$|[A-Z][a-z])|[a-z]*))/g;
    return $profile_name = join(' ', map { lc } @words);
}

sub _properties_for_class {
    my ($self, $class) = @_;

    my $class_meta = $class->get_class_object;
    unless ( $class_meta ) {
        $self->error_message("Can't get class meta object for class ($class)");
        return;
    }

    my %properties;
    for my $property ( $class_meta->get_property_objects ) {
        $properties{ $property->property_name } = {
            type => $property->property_name,
            is_optional => $property->is_optional,
            doc => $property->doc,
        };
    };

    return %properties;
}

sub _target_class_property_names {
    my $self = shift;

    my %properties = $self->_properties_for_class( $self->_target_class )
        or return;

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

#< Pretty print >#
sub _pretty_print_processing_profile {
    my $self = shift;

    my @defined_property_names = $self->_target_class_property_names;
    for my $pp ( @_ ) {
        UR::Object::Command::List->execute(
            filter => 'id=' . $pp->id,
            subject_class_name => $self->_target_class,
            style => 'pretty',
            show => sprintf(
                            'id,name,type_name,%s',
                            join(',', @defined_property_names),
                        ),
            #output => IO::String->new(),
        );
    }

    return 1;
}

###############################


sub unique_processing_profile_name {
    my $self = shift;
    if ( my $existing_pp = $self->_target_class->get(name => $self->name) ) {
        $self->error_message("Processing profile already exists with the same name:");
        $self->_pretty_print_processing_profile($existing_pp);
        return;
    }
    return 1;
}

sub unique_processing_profile_params {
    my $self = shift;

    # Get the params for the processing profile, sans name
    my %params = $self->_get_target_class_params;

    # Check if the same profile params exist, w/ different name
    my @all_pp = $self->_target_class->get;
    for my $existing_pp ( @all_pp ) {
        my $existing_properties = grep { $params{$_} eq $existing_pp->$_ } grep { defined $existing_pp->$_ } keys %params;
        next unless keys %params == $existing_properties;
        $self->error_message("Processing profile already exists with the same params:");
        $self->_pretty_print_processing_profile($existing_pp);
        return;
    }
    return 1;
}

1;

#$HeadURL$
#$Id$
