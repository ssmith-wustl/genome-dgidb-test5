
package Genome::Model::Command::ProcessingProfile::ShortRead::Create;

use strict;
use warnings;

use above "Genome";
use Command; 
use Genome::Model;
use File::Path;
use Data::Dumper;

class Genome::Model::Command::ProcessingProfile::ShortRead::Create {
    is => ['Genome::Model::Event'],
    sub_classification_method_name => 'class',
    has => [
		model		=> {is_optional => 1}, # should this be here? needs to be to run
        profile_name 			     => { is => 'VARCHAR2', len => 255, is_optional => 1 ,
										doc => 'The human readable name for the processing profile'},
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
		prior_ref_seq                => { is => 'VARCHAR2', len => 255, is_optional => 1,
										doc => ""},
		read_aligner                 => { is => 'VARCHAR2', len => 255, is_optional => 1,
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

The properties of the model determine what will happen when the add-reads command is run.
EOS
}

sub target_class{
    return "Genome::ProcessingProfile::ShortRead";
}

sub command_properties{
    my $self = shift;
    
    return
        grep { $_ ne 'id' and $_ ne 'bare_args'}         
            map { $_->property_name }
                $self->_shell_args_property_meta;
}

sub execute {
    my $self = shift;

$DB::single=1;

    # genome model specific

    unless ($self->prior_ref_seq) {
        $self->prior_ref_seq('none');
    }

    $self->_validate_execute_params(); 

    # generic: abstract out
    my %params = %{ $self->_extract_command_properties_and_duplicate_keys_for__name_properties() };
    
    my $obj = $self->_create_target_class_instance_and_error_check( \%params );
    unless ($obj) {
        $self->error_message("Failed to create model!");
        return;
    }
    
    if (my @problems = $obj->invalid) {
        $self->error_message("Invaild model!");
        $obj->delete;
        return;
    }
    
    $self->status_message("created model " . $obj->name);
    print $obj->pretty_print_text,"\n";
    
	# this should probably still be built when the model is
    #unless ($self->_build_model_filesystem_paths($obj)) {
    #    $self->error_message('filesystem path creation failed');
    #    $obj->delete;
    #    return;
    #}
    
    return 1;
}

# TODO: remove
# this should probably still be build when the model is
sub _build_model_filesystem_paths {
    my $self = shift;
    my $model = shift;
    
    my $base_dir = $model->data_directory;
    
    eval {mkpath("$base_dir");};
    
    if ($@) {
        $self->error_message("model base dir $base_dir could not be successfully created");
        return;
    }
    
    return 1;
    
}

sub _extract_command_properties_and_duplicate_keys_for__name_properties{
    my $self = shift;
    
    my $target_class = $self->target_class; 
    my %params;
    
    for my $command_property ($self->command_properties) {
        my $value = $self->$command_property;
        next unless defined $value;

        # This is an ugly hack just for creating Genome::Model objects
        # Command-derived objects gobble up the --name parameter as part of the
        # UR framework initialization, so we're stepping around that by
        # knowing that Genome::Model's have names, and the related Command
        # param is called "model_name"
		# Also used for creating Genome::ProcessingProfile objects now
        if ($command_property eq 'profile_name') {
            if ($target_class->can('name')) {
                $params{'name'} = $value; 
            }
        } else {
            my $object_property = $command_property;
            if ($target_class->can($command_property . "_name")) {
                $object_property .= "_name";
            }
           	$params{$object_property} = $value;
        }
    }

	# set the type name property
	$params{'type_name'} = 'short read';
    # TODO: remove
	# The sequence is not set up at the moment in the db... so this module will
	# not work until it is
	# $params{'id'} = 42;

    return \%params;
}

sub _validate_execute_params{
    my $self = shift;
    
    unless ($self->reference_sequence) {
        if ($self->prior_ref_seq eq "none") {
            $self->error_message("No reference sequence set.  This is required w/o a prior.");
            $self->usage_message($self->help_usage);
            return;
        }
        $self->reference_sequence($self->prior_ref_seq);
    }

    if (my @args = @{ $self->bare_args }) {
        $self->error_message("extra arguments: @args");
        $self->usage_message($self->help_usage);
        return;
    }
}

sub _create_target_class_instance_and_error_check{
    my ($self, $params_in) = @_;
    
    my %params = %{$params_in};
    
    my $target_class = $self->target_class;    
    my $target_class_meta = $target_class->get_class_object; 
    my $type_name = $target_class_meta->type_name;

    $self->set(
        date_scheduled  => $self->_time_now(),
        date_completed  => undef,
        event_status    => 'Scheduled',
        event_type      => $self->command_name,
        lsf_job_id      => undef, 
        user_name       => $ENV{USER}, 
    );

    my $obj = $target_class->create(%params);
    if (!$obj) {
        $self->error_message(
            "Error creating $type_name: " 
            . $target_class->error_message
        );
        return;
    }

    $self->model($obj); 

    if (my @problems = $obj->invalid) {
        $self->error_message("Error creating $type_name:\n\t"
            . join("\n\t", map { $_->desc } @problems)
            . "\n");
        $obj->delete;
        return;
    }   

    $self->date_completed($self->_time_now());
    unless($obj) {
        $self->event_status('Failed');
        $self->error_message("Failed to create genome model: " . $obj->error_message);
        print Dumper(\%params);
        return;
    }
    
    $self->event_status('Succeeded');
    return $obj;
}

1;

