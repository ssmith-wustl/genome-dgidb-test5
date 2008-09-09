
package Genome::Model::Command::Create::ProcessingProfile::MicroArrayIllumina;

use strict;
use warnings;

use Genome;
use Command; 
use Genome::Model;
use File::Path;
use Data::Dumper;

class Genome::Model::Command::Create::ProcessingProfile::MicroArrayIllumina{
    is => ['Genome::Model::Event', 'Genome::Model::Command::Create::ProcessingProfile'],
    sub_classification_method_name => 'class',
    has => [
        model                        => { is => 'Genome::Model', is_optional => 1, doc => 'Not used as a parameter' },
        profile_name                 => { is => 'VARCHAR2', len => 255, is_optional => 0 ,
                                          doc => 'The human readable name for the processing profile'},
    ],
    schema_name => 'Main',
};

sub _shell_args_property_meta {
    # exclude this class' commands from shell arguments
    return grep { 
            $_->property_name ne 'model_id'
            #not ($_->via and $_->via ne 'run') && not ($_->property_name eq 'run_id')
        } shift->SUPER::_shell_args_property_meta(@_);
}


sub sub_command_sort_position {
    3
}

sub help_brief {
    "create a new processing profile for micro array for illumina"
}

sub help_synopsis {
    return <<"EOS"
genome-model processing-profile micro-array-illumina create 
                                            --profile-name test5 
EOS
}

sub help_detail {
    return <<"EOS"
This defines a new processing profile for micro array for illumina.
EOS
}

sub target_class{
    return "Genome::ProcessingProfile::MicroArrayIllumina";
}

sub _validate_execute_params {
    my $self = shift;
    
    unless($self->SUPER::_validate_execute_params) {
        $self->error_message('_validate_execute_params failed for SUPER');
        return;                        
    }

    return 1;
}

# TODO: refactor... this is copied from create/processingprofile.pm...
sub execute {
    my $self = shift;

    $DB::single = $DB::stopper;

    # genome model specific


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

