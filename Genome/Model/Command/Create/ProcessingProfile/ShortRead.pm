
package Genome::Model::Command::Create::ProcessingProfile::ShortRead;

use strict;
use warnings;

use above "Genome";
use Command; 
use Genome::Model;
use File::Path;
use Data::Dumper;

class Genome::Model::Command::Create::ProcessingProfile::ShortRead {
    is => ['Genome::Model::Event', 'Genome::Model::Command::Create::ProcessingProfile'],
    sub_classification_method_name => 'class',
    has => [
		# This will probably never be specified since processing profiles are used for many models
		# this shouldnt even be here except that we need to override this to be not required
        model                  		 => { is => 'Genome::Model', is_optional => 1, doc => 'Not used as a parameter' },
		align_dist_threshold         => { is => 'VARCHAR2', len => 255, is_optional => 1,
										doc => ""},
		dna_type                     => { is => 'VARCHAR2', len => 64, is_optional => 1,
										doc => "The type of dna used in the reads for this model, probably 'genomic dna' or 'cdna'"},
		genotyper	                 => { is => 'VARCHAR2', len => 255, is_optional => 1,
										doc => "Name of the genotyper for this model"},
		genotyper_params             => { is => 'VARCHAR2', len => 255, is_optional => 1,
										doc => "command line args used for the genotyper"},
		indel_finder                 => { is => 'VARCHAR2', len => 255, is_optional => 1,
										doc => "Name of the indel finder for this model"},
		indel_finder_params          => { is => 'VARCHAR2', len => 255, is_optional => 1,
										doc => "command line args for the indel finder"},
		multi_read_fragment_strategy => { is => 'VARCHAR2', len => 255, is_optional => 1,
										doc => ""},
		prior		                 => { is => 'VARCHAR2', len => 255, sql => 'prior_ref_seq', is_optional => 1,
										doc => ""},
		read_aligner                 => { is => 'VARCHAR2', len => 255, is_optional => 0,
										doc => "alignment program used for this model"},
		read_aligner_params          => { is => 'VARCHAR2', len => 255, is_optional => 1,
										doc => "command line args for the aligner"},
		read_calibrator              => { is => 'VARCHAR2', len => 255, is_optional => 1,
										doc => ""},
		read_calibrator_params       => { is => 'VARCHAR2', len => 255, is_optional => 1,
										doc => ""},
		reference_sequence           => { is => 'VARCHAR2', len => 255, is_optional => 1,
										doc => "Identifies the reference sequence used in the model"},
		sequencing_platform          => { is => 'VARCHAR2', len => 255, is_optional => 1, 
										doc => "The sequencing platform. Always 'solexa' at the moment"},
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
    1
}

sub help_brief {
    "create a new processing profile for short reads"
}

sub help_synopsis {
    return <<"EOS"
genome-model processing-profile short-read create 
					--profile-name test5 
					--align-dist-threshold 0 
					--dna-type "genomic dna" 
					--genotyper maq0_6_3 
					--indel-finder maq0_6_3 
					--read-aligner maq0_6_3 
					--reference-sequence NCBI-human-build36 
					--sequencing-platform solexa
EOS
}

sub help_detail {
    return <<"EOS"
This defines a new processing profile for short reads.

The properties of the processing profile determine what will happen when the add-reads command is run.
EOS
}

sub target_class{
    return "Genome::ProcessingProfile::ShortRead";
}

sub _validate_execute_params {
    my $self = shift;
    
    unless($self->SUPER::_validate_execute_params) {
        $self->error_message('_validate_execute_params failed for SUPER');
        return;                        
    }

    unless ($self->reference_sequence) {
        if ($self->prior eq "none") {
            $self->error_message("No reference sequence set.  This is required w/o a prior.");
            $self->usage_message($self->help_usage);
            return;
        }
        $self->reference_sequence($self->prior);
    }
    unless ($self->_validate_dna_type) {
        $self->error_message(
            'DNA Type is invalid... must be "genomic dna" or "cdna"');
        return;                        
    }

    unless ($self->verify_params) {
        $self->error_message(
            "One or more modules could not be found for the supplied parameters");
        return;                        
    }

    return 1;
}

sub _validate_dna_type {
    my $self = shift;
    
    unless (($self->dna_type() eq "genomic dna")||($self->dna_type() eq "cdna")) {
        return undef;    
    }

    return 1;
}

# TODO: copied from create processingprofile... refactor
sub execute {
    my $self = shift;

    $DB::single=1;

    # genome model specific

    unless ($self->prior) {
        $self->prior('none');
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

