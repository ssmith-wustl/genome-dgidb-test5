package Genome::Model::Command::Create::ProcessingProfile::MetaGenomicComposition;

use strict;
use warnings;

use Genome;

require Command;
use Data::Dumper;
require Genome::ProcessingProfile::MetaGenomicComposition;
require IO::String;
require UR::Object::Command::List;

my %PROPERTIES = Genome::Model::Command::Create::ProcessingProfile::resolve_property_hash_from_target_class(__PACKAGE__);

class Genome::Model::Command::Create::ProcessingProfile::MetaGenomicComposition {
    is => 'Genome::Model::Command::Create::ProcessingProfile',
    sub_classification_method_name => 'class',
    has => [ %PROPERTIES ],
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

sub execute {
    my $self = shift;

    $DB::single = $DB::stopper;
    unless ($self->_validate_execute_params) {
        $self->error_message("Failed to validate_execute_params!");
        return;
    }
    my %params = $self->_get_target_class_params;
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


1;

#$HeadURL$
#$Id$
