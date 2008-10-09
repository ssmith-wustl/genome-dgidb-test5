package Genome::Model::Command::Create::ProcessingProfile::MetaGenomicComposition;

use strict;
use warnings;

use Genome;

require Command;
use Data::Dumper;
require Genome::ProcessingProfile::MetaGenomicComposition;
require IO::String;
require UR::Object::Command::List;

# Derive properties from processing profile class we are creating.
# Abstract out, put in a method
my %processing_profile_properties;
for my $property ( __PACKAGE__->target_class->get_class_object->get_property_objects ) {
    $processing_profile_properties{ $property->property_name } = {
        type => $property->property_name,
        is_optional => $property->is_optional,
        doc => $property->doc,
    };
}

class Genome::Model::Command::Create::ProcessingProfile::MetaGenomicComposition {
    is => 'Genome::Model::Command::Create::ProcessingProfile',
    sub_classification_method_name => 'class',
    has => [ %processing_profile_properties ],
    
};

sub target_class {
    return "Genome::ProcessingProfile::MetaGenomicComposition";
}

sub help_brief {
    return 'Define a new meta genomic composition processing profile'
}

sub help_detail {
    return <<"EOS"
    Define a new meta genomic composition processing profile
EOS
}

sub _shell_args_property_meta {
    # exclude this class' commands from shell arguments
    return grep { 
        $_->property_name ne 'model_id'
        #not ($_->via and $_->via ne 'run') && not ($_->property_name eq 'run_id')
    } shift->SUPER::_shell_args_property_meta(@_);
}

sub _validate_execute_params {
    my $self = shift;
    
    unless ( $self->SUPER::_validate_execute_params ) {
        $self->error_message('_validate_execute_params failed for SUPER');
        return;                        
    }

    return 1;
}

sub execute {
    my $self = shift;

    $DB::single = $DB::stopper;

    # Check extra command line params
    $self->_validate_execute_params 
        or return;

    # Check if name exists
    if ( my $existing_pp = $self->target_class->get(name => $self->profile_name) ) {
        $self->error_message("Processing profile already exists with the same name:");
        $self->_pretty_print_processing_profile($existing_pp);
        return;
    }
    
    # Get the params for the processing profile, sans name
    my %params = $self->_get_target_class_params;

    # Check if the same profile params exist, w/ different name
    my @all_pp = $self->target_class->get;
    for my $existing_pp ( @all_pp ) {
        my $existing_properties = grep { $params{$_} eq $existing_pp->$_ } grep { defined $existing_pp->$_ } keys %params;
        next unless keys %params == $existing_properties;
        $self->error_message("Processing profile already exists with the same params:");
        $self->_pretty_print_processing_profile($existing_pp);
        return;
    }

    # Add name to processing profile params
    $params{name} = $self->profile_name;

    # Create processing profile
    my $processing_profile = $self->target_class->create(%params);
    unless ( $processing_profile ) {
        $self->error_message("Failed to create processing profile");
        return;
    }
    
    # TODO Check problems from processing profile??
    
    $self->status_message('Created processing profile:');
    $self->_pretty_print_processing_profile($processing_profile);
    
    return 1;
}

sub _get_target_class_params {
    my $self = shift;
    
    my %params;
    for my $property_name ( keys %processing_profile_properties ) {
        my $value = $self->$property_name;
        next unless defined $value;
        $params{$property_name} = $value;
    }

    return %params;
}

sub _pretty_print_processing_profile {
    my $self = shift;

    for my $pp ( @_ ) {
        UR::Object::Command::List->execute(
            filter => 'id=' . $pp->id,
            subject_class_name => $self->target_class,
            style => 'pretty',
            show => sprintf(
                'id,name,type_name,%s', 
                join(',', keys %processing_profile_properties),
            ),
            #output => IO::String->new(),
        );
    }

    return 1;
}


1;

#$HeadURL$
#$Id$
