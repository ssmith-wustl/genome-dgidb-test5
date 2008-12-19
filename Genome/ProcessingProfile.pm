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
        name      => { is => 'VARCHAR2', len => 255, is_optional => 1, doc => 'Human readable name', },
        type_name => { is => 'VARCHAR2', len => 255, is_optional => 1, doc => 'The type of processing profile' },
    ],
    has_many_optional => [
        params => { is => 'Genome::ProcessingProfile::Param', reverse_id_by => 'processing_profile' },
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

#< SUBCLASSING >#
#
# This is called by the infrastructure to appropriately classify abstract processing profiles
# according to their type name because of the "sub_classification_method_name" setting
# in the class definiton...
sub _resolve_subclass_name {
    my $class = shift;
	
    my $type_name;
	if ( ref($_[0]) and $_[0]->isa(__PACKAGE__) ) {
		$type_name = $_[0]->type_name;
	}
    else {
        my %params = @_;
        $type_name = $params{type_name};
    }

    unless ( $type_name ) {
        my $rule = $class->get_rule_for_params(@_);
        $type_name = $rule->specified_value_for_property_name('type_name');
    }

    return ( defined $type_name ) 
    ? $class->_resolve_subclass_name_for_type_name($type_name)
    : undef;
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

#########################################
## FAKE PROCESSING PROFILE FOR TESTING ##
#########################################

package Genome::ProcessingProfile::Test; {
    use Genome;

    use strict;
    use warnings;

    my %HAS = (
        colour =>{ 
            doc => 'The colour of this profile',
        },
        shape => { 
            doc => 'The shape of this profile',
            is_optional => 1,
        },
    );

    class Genome::ProcessingProfile::Test {
        is => 'Genome::ProcessingProfile',
        has => [
        map(
            { 
                $_ => {
                    via => 'params',
                    to => 'value',
                    where => [ name => $_ ],
                    is_mutable => 1,
                    is_optional => ( exists $HAS{$_}->{is_optional} ? $HAS{$_}->{is_optional} : 0),
                    doc => (
                        ( exists $HAS{$_}->{valid_values} )
                        ? sprintf('%s. Valid values: %s.', $HAS{$_}->{doc}, join(', ', @{$HAS{$_}->{valid_values}}))
                        : $HAS{$_}->{doc}
                    ),
                },
            } keys %HAS
        ),
        ],
    };

    sub params_for_class {
        return keys %HAS;
    }
}

1;

#$HeadURL
#$Id
