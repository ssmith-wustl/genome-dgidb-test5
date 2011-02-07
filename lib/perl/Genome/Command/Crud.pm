package Genome::Command::Crud;

use strict;
use warnings;

use Genome;
      
require Carp;
use Data::Dumper 'Dumper';
require File::Basename;
require Genome::Utility::Text;
require Lingua::EN::Inflect;

class Genome::Command::Crud {
    doc => 'Class for dynamically building CRUD commands',
};

our %inited;
sub init_sub_commands {
    my ($class, %incoming_config) = @_;

    # target class, namespace
    Carp::confess('No target class given to init_sub_commands') if not $incoming_config{target_class};
    my %config;
    $config{target_class} = delete $incoming_config{target_class};
    $config{namespace} = ( exists $incoming_config{namespace} )
    ? delete $incoming_config{namespace}
    : $config{target_class}.'::Command';

    # Ok if we inited already
    return 1 if $inited{ $config{namespace} };

    # name for objects
    my $target_name = ( defined $incoming_config{target_name} )
    ? delete $incoming_config{target_name}
    : join(' ', map { Genome::Utility::Text::camel_case_to_string($_) } split('::', $config{target_class}));
    $config{name_for_objects} = Lingua::EN::Inflect::PL($target_name);
    $config{name_for_objects_ub} = $config{name_for_objects};
    $config{name_for_objects_ub} =~ s/ /_/;

    my @namespace_sub_command_names = map {
        s/$config{namespace}:://; $_ = lc($_); $_;
    } $config{namespace}->sub_command_classes;
    my @sub_commands = (qw/ create update list delete /);
    my @sub_classes;
    for my $sub_command ( @sub_commands ) {
        # config for this sub command
        my $sub_command_config = ( exists $incoming_config{$sub_command} )
        ? delete $incoming_config{$sub_command}
        : {};

        # skip existing sub commands
        if ( grep { $sub_command eq $_ } @namespace_sub_command_names ) {
            next if not %$sub_command_config;
            #Carp::confess("Subcommand '$sub_command' for namespace '$config{namespace}' already exists, but there is CRUD config for it. Please correct.");
            next;
        }

        # skip if requested not to init
        next if delete $sub_command_config->{do_not_init};

        # build the sub class
        my $method = '_build_'.$sub_command.'_sub_class';
        my $sub_class = $class->$method(%config, %$sub_command_config);
        if ( not $sub_class ) {
            Carp::confess('Cannot dynamically create class for sub command name: '.$sub_command);
        }
        push @sub_classes, $sub_class;
    }

    # Note inited
    $inited{ $config{namespace} } = 1;

    # Check for left over config
    Carp::confess('Unknown config for CRUD commands: '.Dumper(\%incoming_config)) if %incoming_config;

    # Overload sub command classes to return these in memory ones, plus ones in the directory
    my @sub_command_classes = ( 
        @sub_classes,
        $config{namespace}->sub_command_classes,
    );
    no strict;
    *{ $config{namespace}.'::sub_command_classes' } = sub{ return @sub_command_classes; };
    
    return 1;
}

sub _build_create_sub_class {
    my ($class, %config) = @_;

    # get the properties for creating
    my @properties = $class->_command_properties_for_target_class($config{target_class});

    # define class
    my $sub_class = $config{namespace}.'::Create';
    UR::Object::Type->define(
        class_name => $sub_class,
        is => 'Genome::Command::Create',
        has => [ map { $_->{property_name} => $_ } @properties ],
        doc => 'create '.$config{name_for_objects},
    );

    no strict;
    *{ $sub_class.'::_name_for_objects' } = sub{ return $config{name_for_objects}; };
    *{ $sub_class.'::_target_class' } = sub{ return $config{target_class}; };
    use strict;

    return $sub_class;
}

sub _build_list_sub_class {
    my ($class, %config) = @_;

    my @has =  (
        subject_class_name  => {
            is_constant => 1,
            value => $config{target_class},
        },
    );
    if ( $config{show} ) {
        push @has, show => { default_value => $config{show}, };
    }

    my $sub_class = $config{namespace}.'::List';
    UR::Object::Type->define(
        class_name => $sub_class,
        is => 'UR::Object::Command::List',
        has => \@has,
    );

    return $sub_class;
}
   
sub _build_update_sub_class {
    my ($class, %config) = @_;

    my @properties = $class->_update_command_properties_for_target_class($config{target_class});
    my $sub_class = $config{namespace}.'::Update';
    UR::Object::Type->define(
        class_name => $sub_class,
        is => 'Genome::Command::Update',
        has => [ 
            $config{name_for_objects_ub} => {
                is => $config{target_class},
                is_many => 1,
                shell_args_position => 1,
                doc => ucfirst($config{name_for_objects}).' to update, resolved via text string.',
            },
            ( map { $_->{property_name} => $_ } @properties ),
        ],
        doc => 'update '.$config{name_for_objects},
    );

    my $only_if_null = $config{only_if_null};
    if ( not $only_if_null ) {
        $only_if_null = [];
    }
    elsif ( $only_if_null eq 1 ) { # use all props
        $only_if_null = [ map { $_->{property_name} } @properties ];
    }
    else {
        my $ref = ref $only_if_null;
        Carp::confess("Unknown data type ($ref) for config param 'only_if_null'") if $ref ne 'ARRAY';
    }

    no strict;
    *{ $sub_class.'::_name_for_objects' } = sub{ return $config{name_for_objects}; };
    *{ $sub_class.'::_name_for_objects_ub' } = sub{ return $config{name_for_objects_ub}; };
    *{ $sub_class.'::_only_if_null' } = sub{ return $only_if_null; };
    use strict;

    return $sub_class;
}

sub _build_delete_sub_class {
    my ($class, %config) = @_;

    my $sub_class = $config{namespace}.'::Delete';
    UR::Object::Type->define(
        class_name => $sub_class,
        is => 'Genome::Command::Delete',
        has => [ 
            $config{name_for_objects_ub} => {
                is => $config{target_class},
                is_many => 1,
                shell_args_position => 1,
                require_user_verify => 1, # needed?
                doc => ucfirst($config{name_for_objects}).' to delete, resolved via text string.',
            },
        ],
        doc => 'delete '.$config{name_for_objects},
    );

    no strict;
    *{ $sub_class.'::_name_for_objects' } = sub{ return $config{name_for_objects}; };
    *{ $sub_class.'::_name_for_objects_ub' } = sub{ return $config{name_for_objects_ub}; };
    use strict;

    return $sub_class;
}

sub _command_properties_for_target_class {
    my ($class, $target_class) = @_;

    Carp::confess('No target class given to get properties') if not $target_class;

    my $target_meta = $target_class->__meta__;
    my @properties;
    my @seen_properties;
    for my $target_property ( $target_meta->property_metas ) {
        my $property_name = $target_property->property_name;
        push @seen_properties, $property_name;

        next if $target_property->class_name eq 'UR::Object';
        next if $property_name =~ /^_/;
        next if grep { $target_property->$_ } (qw/ is_id is_calculated is_constant is_transient /);
        next if grep { not $target_property->$_ } (qw/ is_mutable /);

        my %property = (
            property_name => $property_name,
            singular_name => $target_property->singular_name,
            plural_name => $target_property->plural_name,
            data_type => $target_property->data_type,
            is_many => $target_property->is_many,
            is_optional => $target_property->is_optional,
            is_mutable => $target_property->is_mutable,
            valid_values => $target_property->valid_values,
            default_value => $target_property->default_value,
            doc => $target_property->doc,
        );
        push @properties, \%property;

        if ( $property_name =~ s/_id$// ) {
            my $object_meta = $target_meta->property_meta_for_name($property_name);
            if ( $object_meta ) {
                push @seen_properties, $property_name;
                $property{property_name} = $property_name;
                $property{data_type} = $object_meta->data_type;
                $property{doc} = $object_meta->doc if $object_meta->doc;
            }
        }
    }

    if ( not @properties ) {
        Carp::confess('No properties found for target class: '.$target_class);
    }

    return @properties;
}

sub _update_command_properties_for_target_class {
    my $class = shift;

    my @properties = $class->_command_properties_for_target_class(@_);
    return if not @properties;

    my @update_properties;
    for my $property ( @properties ) {
        $property->{is_optional} = 1;
        delete $property->{default_value};
        my $is_mutable = delete $property->{is_mutable};
        next if not $is_mutable;

        if ( not $property->{is_many} ) {
            push @update_properties, $property;
            next;
        }

        for my $function (qw/ add remove /) { 
            my $property_name = $property->{property_name};
            push @update_properties, {
                property_name => $function.'_'.$property->{singular_name},
                data_type => $property->{data_type},
                is_many => $property->{is_many},
                is_many => 0,
                is_optional => 1,
                valid_values => $property->{valid_values},
                doc => ucfirst($function).' '.$property->{singular_name},
                is_add_remove => 1,
            };
        }
    }

    return @update_properties;
}

1;

