
package Genome::Model::Command::Create::ProcessingProfile::ReferenceAlignment;

use strict;
use warnings;

use Genome;

use File::Path;
use Data::Dumper;

my %PROPERTIES = Genome::Model::Command::Create::ProcessingProfile::resolve_property_hash_from_target_class(__PACKAGE__);

class Genome::Model::Command::Create::ProcessingProfile::ReferenceAlignment {
    is => 'Genome::Model::Command::Create::ProcessingProfile',
    sub_classification_method_name => 'class',
    has => [ %PROPERTIES ],
};

sub help_brief {
    "create a new processing profile for reference alignment"
}

sub help_synopsis {
'genome-model processing-profile reference-alignment create --'.
    join(' --',keys %PROPERTIES);

}

sub help_detail {
    return <<"EOS"
This defines a new processing profile for reference alignment.

The properties of the processing profile determine what will happen when the add-reads command is run.
EOS
}

sub target_class{
    return "Genome::ProcessingProfile::ReferenceAlignment";
}

sub _validate_execute_params {
    my $self = shift;

    unless($self->SUPER::_validate_execute_params) {
        $self->error_message('_validate_execute_params failed for SUPER');
        return;
    }

    unless ($self->reference_sequence_name) {
        if ($self->prior_ref_seq eq "none") {
            $self->error_message("No reference sequence set.  This is required w/o a prior_ref_seq.");
            $self->usage_message($self->help_usage);
            return;
        }
        $self->reference_sequence_name($self->prior_ref_seq);
    }

    return 1;
}


# TODO: copied from create processingprofile... refactor
sub execute {
    my $self = shift;

    # genome model specific

    unless ($self->prior_ref_seq) {
        $self->prior_ref_seq('none');
    }

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

