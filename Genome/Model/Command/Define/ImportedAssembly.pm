
package Genome::Model::Command::Define::ImportedAssembly;

use strict;
use warnings;

use Genome;
use GSCApp;
use Data::Dumper;

class Genome::Model::Command::Define::ImportedAssembly {
    is => 'Genome::Model::Command::Define',
    has_optional => [
        files   => {
	    is => 'Text',
	    is_many => 1,
	    is_optional => 1, 
            doc => 'a list of SFF files'
	},
	model_name => {
	    is => 'Text',
	    doc => 'model name',
	},
	assembly_directory => {
	    is => 'Text',
	    doc => 'Assembly directory to track',
	},
    ],
};

sub help_synopsis {
    return <<"EOS"
genome model define imported-assembly --subject-name <human> --subject-type <species_name>
genome model define imported-assembly --model-name <MY_MODEL_NAME> --subject-name <human> --subject-type <species_name>
genome model define imported-assembly --subject-name <human> --subject-type <species_name> --assembly-directory </path_to_assembly/>
genome model define imported-assembly --subject-name <unknown> --files <FULL_PATH_TO_SFF.1,FULL_PATH_TO_SFF2>
EOS
}
 
sub help_detail {
    return <<"EOS"
This defines a new genome model representing an assembly or group of assemblies of the same subject
EOS
}

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_)
	or return;

    return $self;
}

sub execute {
    my $self = shift;
    #VALIDATE ASSEMBLY DIRECTORY
    if ($self->assembly_directory) {
	unless (-d $self->assembly_directory) {
	    $self->error_message("Assembly directory does not exist: ".$self->assembly_directory);
	    return;
	}
    }
    #DEFINE MODEL
    if (my @files = $self->files) {
	#DEFINE MODEL BY INPUT DATA
	unless ($self->_define_from_files(@files)) {
	    $self->error_message("Failed to define model from sff files");
	    return;
	}
    }
    else {
	#DEFINE MODEL BY SUPPLIED SUBJECT TYPE AND SUBJECT NAME
	unless ($self->_define_from_attributes()) {
	    $self->error_message("Failed to define model with SUBJECT_NAME: ".$self->subject_name." SUBJECT TYPE: ".$self->subject_type);
	    return;
	}
    }
    #my $super = $self->super_can('_execute_body');
    #$super->($self,@_);
    return 1;
}

sub _define_from_attributes {
    my $self = shift;
    my $pp = $self->_validate_processing_profile();

    my $model;
    #HERE ALLOW MULTIPLE MODLES TO BE DEFINED WITH SAME SUBJECT NAME AND TYPE
    #$model = Genome::Model->get(
	#subject_name => $self->subject_name,
	#processing_profile_id => $pp->id,
	#);
    #if ($model) { #USE EXISTING MODEL
	#$self->status_message("\nModel with subject name ".$self->subject_name." already exists. ".
		#	      "Build will be assigned to this model:\n".
		#	      "\tMODEL ID: ".$model->id."\n\tSUBJECT NAME: ".$model->subject_name."\n\tMODEL NAME: ".$model->name."\n\n");
    #}
    #else { #DEFINE A NEW MODEL
	$self->status_message("\nDefining model with subject name: ".$self->subject_name." and subject type: ".$self->subject_type);
	my %model_params = (
	    processing_profile_id => $pp->id,
	    subject_name => $self->subject_name,
	    subject_type => $self->subject_type,
	    );
	#IF USER SUPPLIED MODEL NAME
	if ($self->model_name) {
	    $model_params{name} = $self->model_name;
	}
	$model = $self->_create_model( %model_params );
    #}
    #CREATE A BUILD IF ASSEMBLY DIRECTORY IS SPECIFIED
    if ($self->assembly_directory) {
	#CHECK FOR EXISTING BUILDS WITH SAME DIRECTORY
	my @existing_builds = $model->builds;
	foreach my $build (@existing_builds) {
	    if ($build->data_directory eq $self->assembly_directory) {
		$self->error_message("Build already exists for this model with directory: ".$self->data_directory);
		return;
	    }
	}
	my $build = $self->_create_build( $model );
	#CREATE AN EMPTY EVENT FOR THE BUILD
	my $event = $self->_create_event_for_build( $model, $build );
    }
    return 1;
}

sub _define_from_files {
    my ($self, @sffs) = @_;
    #VALIDATE PROCESSING PROFILE
    my $pp = $self->_validate_processing_profile();

    #GET LIBRARY NAMES FROM EACH SFF FILE
    my $library_names = {}; #HASH TO STORE UNIQ LIB NAMES
    foreach my $sff_file (@sffs) {
	unless (-s $sff_file) {
	    $self->error_message("Invalid sff file or file does not exist: $sff_file");
	    return;
	}
	my $library_name = $self->_get_library_name($sff_file);
	$library_names->{$library_name} = 1;
    }

    my $lib_name_string;
    foreach (keys %$library_names) {
	$lib_name_string .= "\t".$_."\n";
    }
    $self->status_message("\nFound the following library names\n".$lib_name_string);

    #GET SAMPLE NAMES FROM EACH LIBRARY NAME
    my $sample_names = {};
    foreach my $lib_name (keys %$library_names) {
	my @names = $self->_get_sample_names($lib_name);
	foreach (@names) {
	    chomp $_;
	    $sample_names->{$_} = 1;
	}
    }

    my $sample_name_string;
    foreach (keys %$sample_names) {
	$sample_name_string .= "\t".$_."\n";
    }
    $self->status_message("\nFound the following sample names\n".$sample_name_string);

    #DEFINE SUBJECT NAME AND SUBJECT TYPE
    my $subject_name;
    my $subject_type;
    if (scalar keys %$sample_names == 1) {
	#IF SINGLE SAMPLE NAME .. DEFINE MODEL USING SAMPLE NAME AS SUBJECT
	($subject_name) = map {$_} keys %$sample_names; #JUST ONE ELEMENT HERE ..
	$subject_type = 'sample_name';
    }
    elsif (scalar keys %$sample_names > 1) {#MULTIPLE SAMPLE NAMES .. USE SPECIES NAME AS SUBJECT
	my $species_names = {};
	#GET SPECIES NAME FOR EACH SAMPLE NAME
	foreach my $sample_name (keys %$sample_names) {
	    my $species_name = $self->_get_species_name($sample_name);
	    unless ($species_name) {
		$self->error_message("Failed to get species name for a sample name: $sample_name");
		return;
	    }
	    $species_names->{$species_name} = 1;
	}
	#DIE IF MULTIPLE SPECIES NAMES
	#TODO - HOW TO PROPERLY DEFINE A MODEL IF SAMPLES FROM MULTIPLE SPECIES ARE USED
	if (scalar keys %$species_names > 1) {
	    $self->error_message("Multiple spceies names found ".map {"\t".$_."\n"} keys %$species_names);
	    return;
	}
	($subject_name) = map {$_} keys %$species_names; #SINGLE ELEMENT HASH
	$subject_type = 'species_name';
    }
    else { #SHOULD NEVER GET HERE
	$self->error_message("Unable to define s subject name for the model");
	return;
    }

    #CHECK IF A MODEL WITH THIS SUBJECT NAME ALREADY EXISTS
    my $model;
    $model = Genome::Model->get(
	subject_name => $subject_name,
	processing_profile_id => $pp->id,
    );

    if ($model) { #EXISTING MODEL
	$self->status_message("\nModel with subject name $subject_name already exists. ".
			      "Build will be assigned to this model:\n".
			      "\tMODEL ID: ".$model->id."\n\tSUBJECT NAME: ".$model->subject_name."\n\tMODEL NAME: ".$model->name."\n\n");
    }
    else { #CREATE A NEW MODEL
	$self->status_message("\nDefining model with subject name: $subject_name and subject type: $subject_type");
	my %model_params = (
	    subject_name => $subject_name,
	    subject_type => $subject_type,
	    processing_profile_id => $pp->id,
	    );
	if ($self->model_name) { #IF USER DEFINED MODEL NAME
	    $model_params{name} = $self->model_name;
	}
	$model = $self->_create_model( %model_params );
    }
    #CREATE A BUILD
    if ($self->assembly_directory) {
	#CHECK FOR EXISTING BUILDS WITH SAME DIRECTORY
	my @existing_builds = $model->builds;
	foreach my $b (@existing_builds) {
	    if ($b->data_directory eq $self->assembly_directory) {
		$self->status_message("Build with assembly directory already exists:".
				      "\n\tBUILD ID: ".$b->build_id."\n\tDATA DIRECTORY: ".$self->assembly_directory);
		return 1;
	    }
	}
	my $build = $self->_create_build( $model );
	#CREATE AN EMPTY EVENT FOR THE BUILD
	my $event = $self->_create_event_for_build( $model, $build );
    }
    return 1;
}

sub _create_model {
    my ($self, %p) = @_;
    my $model = Genome::Model->create( %p );
    unless ($model) {
	$self->error_message("Failed to create model for subject_name: ".$p{subject_name});
	return;
    }
    $self->status_message("Created model:\n"."\tMODEL ID: ".$model->id."\n\tSUBJECT NAME: ".$model->subject_name."\n\tMODEL NAME: ".$model->name."\n\n");
    return $model;
}

sub _validate_processing_profile {
    my $self = shift;
    my $pp = Genome::ProcessingProfile->get(name => $self->processing_profile_name);
    unless ($pp) {
	$self->error_message("Could not find processing profile with name ".$self->processing_profile_name);
	return;
    };
    return $pp;
}

sub _create_build {
    my $self = shift;
    my $model = shift;
    my $build = Genome::Model::Build->create(
	data_directory => $self->assembly_directory,
	model_id => $model->id,
	);
    unless ($build) {
	$self->error_message("Build failed for ".$self->assembly_directory);
	return;
    }
    $self->status_message("Created build: BUILD ID: ".$build->build_id."\tDATA DIRECTORY: ".$self->assembly_directory);
    return $build;
}

sub _create_event_for_build {
    my $self = shift;
    my $model = shift;
    my $build = shift;
    my $event = Genome::Model::Event::Build->create (
	event_type => 'genome model build',
	model_id => $model->id,
	build_id => $build->id,
	date_scheduled => UR::Time->now, #MUST SET THESE FOR BUILD TO HAVE SUCCEEDED STATUS
	event_status => 'Succeeded',
	date_completed => UR::Time->now,
	);
    unless ($event) {
	$self->error_message("Failed to create event");
	return;
    }
    $self->status_message("Created event for build");
    return $event;
}

sub _get_species_name {
    my $self = shift;
    my $sample_name = shift;
    my $sample = Genome::Sample->get(name => $sample_name);
    unless ($sample and $sample->species_name) {
	$self->error_message("Failed to get species name for sample name: $sample_name");
	return;
    }
    return $sample->species_name;
}

sub _get_sample_names {
    my $self = shift;
    my $lib_name = shift;

    #THIS IS INCONSISTANT .. DOESN'T ALWAYS FINE SAMPLE NAMES
    #my $lib = Genome::Library->get(name => $lib_name);
    #my $sample_name = $lib->sample->name;
    #$sample_names->{$sample_name} = 1;

    my $query = 'genome instrument-data list 454 --filter library_name=\''.$lib_name.
	        '\' --show sample_name --noheaders';
    my @sample_names = `$query`;
    unless (@sample_names) {
	$self->error_message("Failed to find sample name for $lib_name");
	return;
    }
    return @sample_names;
}

sub _get_library_name {
    my $self = shift;
    my $sff_file = shift;

    my @tmp = split('/', $sff_file);

    #$tmp[-1] = sff file name
    #$tmp[5] = run name
    #$tmp[6] = analysis name

    my ($region_number) = $tmp[-1] =~ /\w*(\d\d)\.sff$/;

    my $rr_454 = GSC::RunRegion454->get(
	run_name => $tmp[5],
	analysis_name => $tmp[6],
	region_number => $region_number,
    );
    
    unless ($rr_454 and $rr_454->library_name) {
	$self->error_message("Failed to get library name for following data:\n$sff_file");
	return;
    }

    return $rr_454->library_name;
}

1;

