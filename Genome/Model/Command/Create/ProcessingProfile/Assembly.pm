
package Genome::Model::Command::Create::ProcessingProfile::Assembly;

use strict;
use warnings;

use Genome;

use File::Path;
use Data::Dumper;

my %PROPERTIES = Genome::Model::Command::Create::ProcessingProfile::resolve_property_hash_from_target_class(__PACKAGE__);

class Genome::Model::Command::Create::ProcessingProfile::Assembly {
    is => 'Genome::Model::Command::Create::ProcessingProfile',
    sub_classification_method_name => 'class',
    has => [ %PROPERTIES ],
};

sub help_brief {
    "create a new processing profile for denovo assembly"
}

sub help_synopsis {
    return <<"EOS"
genome-model processing-profile assembly create 
EOS
}

sub help_detail {
    return <<"EOS"
This defines a new processing profile for assembly.
EOS
}

sub target_class {
    return "Genome::ProcessingProfile::Assembly";
}

# TODO: refactor... this is copied from create/processingprofile.pm...
sub execute {
    my $self = shift;

    $DB::single = $DB::stopper;

    unless ($self->_validate_execute_params()) {
        $self->error_message("Failed to create processing_profile!");
        return;
    }

    # generic: abstract out
    my %params = %{ $self->_extract_command_properties_and_duplicate_keys_for__name_properties() };

    my $obj = $self->_create_target_class_instance_and_error_check( \%params );
    unless ($obj) {
        $self->error_message("Failed to create processing_profile!");
        return;
    }

    if (my @problems = $obj->invalid) {
        $self->error_message("Invalid processing_profile!");
        $obj->delete;
        return;
    }

    $self->status_message("created processing profile " . $obj->name);
    print $obj->pretty_print_text,"\n";

    return 1;
}

1;

