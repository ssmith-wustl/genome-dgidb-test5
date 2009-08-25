package Genome::ProcessingProfile;

use strict;
use warnings;

use Genome;

require Carp;
use Data::Dumper;

class Genome::ProcessingProfile {
    type_name => 'processing profile',
    table_name => 'PROCESSING_PROFILE',
    is_abstract => 1,
    sub_classification_method_name => '_resolve_subclass_name',
    id_by => [
        id => { is => 'NUMBER', len => 11 },
    ],
    has => [
        name      => { is => 'VARCHAR2', is_optional => 1, len => 255, doc => 'Human readable name', },
        type_name => { is => 'VARCHAR2', is_optional => 1, len => 255, is_optional => 1, doc => 'The type of processing profile' },
    ],
    has_many_optional => [
        params => { is => 'Genome::ProcessingProfile::Param', reverse_id_by => 'processing_profile' },
        models => { is => 'Genome::Model', reverse_id_by => 'processing_profile' },
    ],
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
};

sub params_for_class {
    my $class = shift;
    warn("params_for_class not implemented for class '$class':  $!");
    return;
}

sub create {
    my ($class, %params) = @_;

    if ( defined $params{type_name} ) {
        my $type_name = $class->_resolve_type_name_for_class;
        if ( defined $type_name and $type_name ne $params{type_name} ) {
            Carp::confess(
                "Resolved type_name ($type_name) does not match given type_name ($params{type_name}) in params to create $class"
            );
            return;
        }
    }
    else {
        Carp::confess(
            __PACKAGE__." is a abstract base class, and no type name was provided to resolve to the appropriate subclass"
        ) if $class eq __PACKAGE__;
        $params{type_name} = $class->_resolve_type_name_for_class;
    }

    my $self = $class->SUPER::create(%params)
        or return;

    unless ( $self->name ) {
        # TODO resolve??
        $self->error_message("No name provided for processing profile");
        $self->delete;
        return;
    }

    return $self;
}

sub param_summary {
    my $self = shift;
    my @params = $self->params_for_class();
    my $summary;
    for my $param (@params) {
        my @values;
        eval { @values = $self->$param(); };

        if (@values == 0) {
            next;
        }
        elsif (not defined $values[0] or $values[0] eq '') {
            next; 
        };

        if (defined $summary) {
            $summary .= ' '
        }
        else {
            $summary = ''
        }

        $summary .= $param . '=';
        if ($@) {
            $summary .= '!ERROR!';
        } 
        elsif (@values > 1) {
            $summary .= join(",",@values)
        } 
        elsif ($values[0] =~ /\s/) {
            $summary .= '"$values[0]"'
        }
        else {
            $summary .= $values[0]
        }
    }
    return $summary;
}

sub delete {
    my $self = shift;
    
    # Check if there are models connected with this pp
    if ( Genome::Model->get(processing_profile_id => $self->id) ) {
        $self->error_message(
            sprintf(
                'Processing profile (%s <ID: %s>) has existing models and cannot be removed.  Delete the models first, then remove this processing profile',
                $self->name,
                $self->id,
            )
        );
        return;
    }
 
    # Delete params
    for my $param ( $self->params ) {
        unless ( $param->delete ) {
            $self->error_message(
                sprintf(
                    'Can\'t delete param (%s: %s) for processing profile (%s <ID: %s>), ',
                    $param->name,
                    $param->value,
                    $self->name,
                    $self->id,
                )
            );
            for my $param ( $self->params ) {
                $param->resurrect if $param->isa('UR::DeletedRef');
            }
            return;
        }
    }   

    $self->SUPER::delete
        or return;

    return 1;
}

sub stages {
    my $class = shift;
    $class = ref($class) if ref($class);
    die("Please implement stages in class '$class'");
}

sub classes_for_stage {
    my $self = shift;
    my $stage_name = shift;
    my $classes_method_name = $stage_name .'_job_classes';
    #unless (defined $self->can('$classes_method_name')) {
    #    die('Please implement '. $classes_method_name .' in class '. $self->class);
    #}
    return $self->$classes_method_name;
}

sub objects_for_stage {
    my $self = shift;
    my $stage_name = shift;
    my $model = shift;
    my $objects_method_name = $stage_name .'_objects';
    #unless (defined $self->can('$objects_method_name')) {
    #    die('Please implement '. $objects_method_name .' in class '. $self->class);
    #}
    return $self->$objects_method_name($model);
}

sub verify_successful_completion_job_classes {
    my @sub_command_classes= qw/
        Genome::Model::Command::Build::VerifySuccessfulCompletion
    /;
    return @sub_command_classes;
}

sub verify_successful_completion_objects {
    my $self = shift;
    return 1;
}

#< SUBCLASSING >#
#
# This is called by the infrastructure to appropriately classify abstract processing profiles
# according to their type name because of the "sub_classification_method_name" setting
# in the class definiton...
sub _resolve_subclass_name {
    my $class = shift;

    my $type_name;
    if ( ref($_[0]) and $_[0]->can('type_name') ) {
        $type_name = $_[0]->type_name;
    } else {
        my %params = @_;
        $type_name = $params{type_name};
    }

    unless ( $type_name ) {
        my $rule = $class->get_rule_for_params(@_);
        $type_name = $rule->specified_value_for_property_name('type_name');
    }

    if ( defined $type_name ) {
        my $subclass_name = $class->_resolve_subclass_name_for_type_name($type_name);
        my $sub_classification_method_name = $class->get_class_object->sub_classification_method_name;
        if ($sub_classification_method_name) {
            if ( $subclass_name->can($sub_classification_method_name)
                 eq $class->can($sub_classification_method_name)) {
                return $subclass_name;
            } else {
                return $subclass_name->$sub_classification_method_name(@_);
            }
        } else {
            return $subclass_name;
        }
    } else {
        return undef;
    }
}

sub _resolve_subclass_name_for_type_name {
    my ($class,$type_name) = @_;
    my @type_parts = split(' ',$type_name);
	
    my @sub_parts = map { ucfirst } @type_parts;
    my $subclass = join('',@sub_parts);
	
    my $class_name = join('::', 'Genome::ProcessingProfile' , $subclass);
    return $class_name;
}

sub _resolve_type_name_for_class {
    my $class = shift;

    my ($subclass) = $class =~ /^Genome::ProcessingProfile::([\w\d]+)$/;
    return unless $subclass;

    return lc join(" ", ($subclass =~ /[a-z\d]+|[A-Z\d](?:[A-Z\d]+|[a-z]*)(?=$|[A-Z\d])/gx));
    
    my @words = $subclass =~ /[a-z\d]+|[A-Z\d](?:[A-Z\d]+|[a-z]*)(?=$|[A-Z\d])/gx;
    return lc(join(" ", @words));
}

1;

#$HeadURL
#$Id
