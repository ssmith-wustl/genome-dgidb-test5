package Genome::ProcessingProfile::DeNovoAssembly;

use strict;
use warnings;

use Genome;

use Data::Dumper 'Dumper';
use Regexp::Common;

class Genome::ProcessingProfile::DeNovoAssembly{
    is => 'Genome::ProcessingProfile::Staged',
    has_param => [
	sequencing_platform => {
	    doc => 'The sequencing platform used to produce the reads.',
	    valid_values => [qw/ 454 solexa /],
	},
	coverage => {
	    is => 'Number',
	    is_optional => 1,
	    doc => 'Use genome size to limit the number of reads used in the assembly to obtain this coverage.',
	},
	# Assembler
	assembler_name => {
	    doc => 'Name of the assembler.',
	    valid_values => ['abyss parallel', 'velvet one-button', 'soap de-novo-assemble', 'soap import'],
	},
	assembler_version => {
	    doc => 'Version of assembler.',
	    #dacc for soap import
	},
	assembler_params => {
	    is_optional => 1,
	    doc => 'A string of parameters to pass to the assembler.',
	},
	# Read Coverage, Trimmer and Filter
	read_processor => {
	    is_optional => 1,
	    doc => "String of read trimmers, filters and sorters to use. Find processors in 'gmt fast-qual.' List each porocessor in order of execution as they would be run on the command line. Do not include 'gmt fast-qual', as this is assumed. List params starting w/ a dash (-), followed by the value. Separate processors by a pipe w/ a space on each side ( | ). The read processors will be validated. Ex:\n\ttrimmer bwa-style --trim-qual-length | filter by-length filter-length 70",
	},
	#post assemble tools to run
	post_assemble => {
	    is_optional => 1,
	    doc => 'String of things to run in post assembly stage .. by default already run WU post assemble process .. more later',
	},
    ],
};

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_);
    return unless $self;

    # Read coverage
    if ( defined $self->coverage ) {
        # Gotta be an int, gt 0 and even
        unless ( $self->coverage =~ /^$RE{num}{real}$/ 
                and $self->coverage > 0
                and $self->coverage <= 500
        ) { 
            # TODO pick a better number??
            $self->error_message(
                "Invalid coverage (".$self->coverage."). Coverage must be an integer greater than 0 and less than  501."
            );
            $self->delete;
            return;
        }
    }

    # Validate assembler & params
    unless ( $self->_validate_assembler_and_params ) {
        $self->status_message("Create failed - could not validate assembler and params");
        $self->delete;
        return;
    }

    # Validate read processor
    unless ( $self->_validate_read_processor ) {
        $self->status_message("Create failed - could not validate read processor");
        $self->delete;
        return;
    }

    #validate post assemble steps 
    if ( $self->post_assemble ) {
	unless ( $self->_validate_post_assemble_steps ) {
	    $self->status_message("Failed to validate post assemble steps");
	    $self->delete;
	    return;
	}
    }

    return $self;
}

sub assembler_accessor_name { #returns soap_de_novo_assemble from 'soap de-novo-assemble'
    my $self = shift;

    my $name = $self->assembler_name;
    $name =~ s/ |-/_/g;

    return $name;
}

sub assembler_class {
    my $self = shift;
    
    my $assembler_name = $self->assembler_name;
    my ($base, $subclass) = split (/\s+/, $assembler_name);

    $subclass =~ s/-/ /g;
    $subclass = Genome::Utility::Text::string_to_camel_case( $subclass );
    
    my $name = 'Genome::Model::Tools::'. ucfirst $base .'::'. $subclass;

    #TODO check makes sure it exists here??

    return $name;
}

sub tools_base_class {
    my $self = shift;
    my $base_name = $self->assembler_base_name;
    return 'Genome::Model::Tools::' . ucfirst $base_name;
}

sub assembler_base_name {
    my $self = shift;
    my @tmp = split(' ', $self->assembler_name);
    return $tmp[0];
}

sub assembler_params_as_hash {
    my $self = shift;

    #assembler params specified in pp
    my $params_string = $self->assembler_params;
    return unless $params_string; # ok 

    my %params = Genome::Utility::Text::param_string_to_hash($params_string);
    unless ( %params ) { # not 
        Carp::confess(
            $self->error_message("Malformed assembler params: $params_string")
        );
    }

    return %params;
}

sub _validate_assembler_and_params {
    my $self = shift;

    $self->status_message("Validating assembler and params...");

    my $assembler_accessor_name = $self->assembler_accessor_name;

    #validate instrument data platform - returns arryref of valid platforms
    my $valid_platform_method = 'valid_'.$assembler_accessor_name.'_seq_platforms';
    my $valid_platforms = $self->$valid_platform_method;
    unless ( grep {$self->sequencing_platform eq $_ } @$valid_platforms ) {
	$self->error_message("Sequencing platform: ".$self->sequencing_platform." is not supported for assembler: ".$self->assembler_name);
	return;
    }
    
    my $assembler_class = $self->assembler_class;
    
    my %assembler_params;
    $assembler_params{version} = $self->assembler_version;

    #below params are needed for assembly but must be derived/calculated from instrument data
    #at the time of build so fake values are plugged in here to get eval to work

    my $add_param_method = $assembler_accessor_name.'_fake_params_for_eval';

    if ( $self->can( $add_param_method ) ) {
        my %fake_addl_params = $self->$add_param_method;
	#adds ins_length to 'velvet one-button' params
        %assembler_params = ( %assembler_params, %fake_addl_params );
    }

    my $clean_up_param_method = $assembler_accessor_name.'_clean_up_params_for_eval';
    if ( $self->can( $clean_up_param_method ) ) {
	#removes insert_size params from 'soap de-novo-assemble' params
	%assembler_params = $self->$clean_up_param_method( %assembler_params );
    }

    my $assembler;
    eval{
        $assembler = $assembler_class->create( %assembler_params, );
    };

    unless ( $assembler ) { 
        $self->error_message("$@\n\nCould not validate assembler params: ".$self->assembler_params);
        return;
    }

    $assembler->delete;

    $self->status_message("Assembler and params OK");

    return 1;
}

#< methods to determine supported instrument data for assembler >#

sub valid_soap_de_novo_assemble_seq_platforms {
    return ['solexa'];
}

sub valid_soap_import_seq_platforms {
    return ['solexa'];
}

sub valid_velvet_one_button_seq_platforms {
    return ['solexa'];
}

sub valid_abyss_parallel_seq_platforms {
    return ['solexa'];
}

#< methods to derive assembler params >#
#soap de-novo-assemble
sub soap_de_novo_assemble_params {
    my ($self, $build) = @_;

    my %params;

    #pp specified assembler params
    if ( $self->assembler_params_as_hash ) {
	%params = $self->assembler_params_as_hash;
    }

    #additional params needed from pp
    $params{version} = $self->assembler_version;

    #note if using user defined insert size
    if ( exists $params{insert_size} ) {
	$self->status_message("Using user defined insert size, will ignore calculated insert size defined in instrument data");
    }

    #params needed to be derived from build
    my $cpus = $self->get_number_of_cpus;
    $params{cpus} = $cpus;

    my $config_file = $build->create_config_file; #make it soap specific
    $params{config_file} = $config_file;

    #insert size param needed for config file creation only
    delete $params{insert_size};

    my $output_dir_and_file_prefix = $build->soap_output_dir_and_file_prefix;
    $params{output_dir_and_file_prefix} = $output_dir_and_file_prefix;
    
    return %params;
}

#soap import params
sub soap_import_params {
    my ($self, $build) = @_;

    my %params;

    #pp specified assembler params
    if ( $self->assembler_params_as_hash ) {
	%params = $self->assembler_params_as_hash;
    }

    #additional params needed from pp
    $params{version} = $self->assembler_version;

    my $output_dir_and_file_prefix = $build->soap_output_dir_and_file_prefix;
    $params{output_dir_and_file_prefix} = $output_dir_and_file_prefix;

    my $location = '/WholeMetagenomic/03-Assembly/PGA/'. $build->model->subject_name.'_'.$build->model->center_name;
    $params{import_location} = $location;

    return %params;
}

sub abyss_parallel_params {
    my ($self, $build) = @_;

    my %params;
    
    #pp specified assembler params
    if ( $self->assembler_params_as_hash ) {
	%params = $self->assembler_params_as_hash;
    }

    #additional params needed from pp
    $params{version} = $self->assembler_version;

    #params that need to be derived
    
    ($params{fastq_a}, $params{fastq_b}) = $build->fastq_input_files;

    my $output_dir = $build->data_directory;
    $params{output_directory} = $output_dir;

    return %params;
}

#velvet one-button params
sub velvet_one_button_params {
    my ($self, $build) = @_;

    my %params;
    
    #pp specified assembler params
    if ( $self->assembler_params_as_hash ) {
	%params = $self->assembler_params_as_hash;
    }
    
    #params that need to be cleaned up
    if ( defined $params{hash_sizes} ) { 
        $params{hash_sizes} = [ split(/\s+/, $params{hash_sizes}) ],
    }

    #additional params needed from pp
    $params{version} = $self->assembler_version;

    #die if these params are specified
    for my $calculated_param (qw/genome_len ins_length/) {
	if ( exists $params{$calculated_param} ) {
	    Carp::confess (
		$self->error_message("Can't specify $calculated_param as assembler_param .. it will be derived from input data")
	    );
	}
    }

    #params that need to be derived
    my $collated_fastq_file = $build->collated_fastq_file;
    $params{file} = $collated_fastq_file;

    my $genome_len = $build->genome_size;
    $params{genome_len} = $genome_len;

    my $ins_length = $build->calculate_average_insert_size;
    $params{ins_length} = $ins_length if defined $ins_length;

    my $output_dir = $build->data_directory;
    $params{output_dir} = $output_dir;

    return %params;
}

#< temp params updates needed for successful eval of assembler class >#

sub velvet_one_button_fake_params_for_eval {
    my $self = shift;
    my %params = (
	ins_length => '280',
    );
    return %params;
}

sub soap_de_novo_assemble_clean_up_params_for_eval {
    my ($self, %params) = @_;
    delete $params{insert_size};
    return %params;
}

#< Read Processor >#

sub _validate_read_processor {
    my $self = shift;

    my $read_processor = $self->read_processor;
    unless ( defined $read_processor ) { # ok
        return 1;
    }

    $self->status_message("Validating read processor...");

    my @read_processor_parts = split(/\s+\|\s+/, $read_processor);
    unless ( @read_processor_parts ) {
        $self->error_message("Could not find read processors in string: $read_processor");
        return;
    }

    for my $read_processor_part ( @read_processor_parts ) {
        my $read_processor_is_ok = Genome::Model::Tools::FastQual::Pipe->validate_command($read_processor_part);
        if ( not $read_processor_is_ok ) {
            $self->error_message("Cannot validate read processor ($read_processor_part). See above error(s)");
            return;
        }
        $self->status_message("Read processor part OK: $read_processor_part");
    }

    $self->status_message("Read processor OK");

    return 1;
}

#< Stages >#
sub stages {
    return (qw/
        assemble
        /);
}

sub assemble_job_classes {
    my $self = shift;

    my @classes;

    if ( $self->assembler_name !~ /import/ ) {
	push @classes, 'Genome::Model::Event::Build::DeNovoAssembly::PrepareInstrumentData';
    }

    push @classes, 'Genome::Model::Event::Build::DeNovoAssembly::Assemble';

    if ( $self->post_assemble ) {
	push @classes, 'Genome::Model::Event::Build::DeNovoAssembly::PostAssemble';
    }

    #TODO - report needs some of the post-assemble outputs and these
    #will be blank if post-assemble is not run
    push @classes, 'Genome::Model::Event::Build::DeNovoAssembly::Report';

    return @classes;
}

sub assemble_objects {
    return 1;
}

#< post assemble steps >#

sub _validate_post_assemble_steps {
    my $self = shift;

    $self->status_message("Validating post assemble steps");

    foreach my $post_assemble_part ( $self->post_assemble_parts ) {
	my ($tool_name) = $post_assemble_part =~ /^(\S+)/;
	my ($param_string) = $post_assemble_part =~ /\S+\s+(.*)/;

	$tool_name =~ s/-/ /g;
	
	my $class_name = Genome::Utility::Text::string_to_camel_case( $tool_name );
	my $base_class = $self->tools_base_class; #return G:M:T:Velvet, Soap, etc

	my $class = $base_class . '::' . $class_name;
	
	my $class_meta;
	eval { $class_meta = $class->get_class_object; };
	unless ( $class_meta ) {
	    $self->error_message("Can't validate tool: $class_name, this tool does not exist: $class");
	    return;
	}

	my %params;
	if ( $param_string ) {
	    %params = Genome::Utility::Text::param_string_to_hash( $param_string );
	}

	unless ( $self->validate_post_assemble_class_params( $class_meta, %params ) ) {
	    $self->error_message("Failed to validate params for class: $class");
	    return;
	}
    }

    $self->status_message("Validated post assemble steps");

    return 1;
}

sub validate_post_assemble_class_params {
    my ($self, $class_meta, %params) = @_;

    foreach my $key ( keys %params ) {
        my $property = $class_meta->property_meta_for_name( $key );
        unless ( $property ) {
            $self->error_message("Failed to validate param, $key in class, " . $class_meta->class_name);
            return;
        }

        my $value = $params{$key};
        #check value against list of valid values
        if ( $property->valid_values ) {
            unless ( grep (/^$value$/, @{$property->valid_values}) ) {
		my $valid_values;
		for my $valid_value ( @{$property->valid_values} ) {
		    $valid_values .= "$valid_value ";
		}
                $self->error_message("Failed to find param $key value $value in the list of valid values: $valid_values");
                return;
            }
        }
        if ( $property->data_type eq 'Integer' ) {
            unless ( $value =~ /^$RE{num}{int}$/ ) {
                $self->error_message("Expected property data type of Integer for param, $key but got $value");
                return;
            }
        }
        elsif ( $property->data_type eq 'Boolean' ) {
            unless ( $value == 1 or $value == 0 ) { #not sure if this is the best way to check
                $self->error_message("Expected property data type of Boolean for param, $key, but got $value");
                return;
            }
        }
        elsif ( $property->data_type eq 'Number' ) {
            unless ( $value =~ /^$RE{num}{real}$/ ) {
                $self->error_message("Expected property data type of Number of param, $key, but got $value");
                return;
            }
        }
        #else is text or string.. need to check
    }

    #check for missing required param
    for my $property ( $class_meta->properties ) {
        if ( not $property->is_optional ) {

            my $property_name = $property->property_name;

	    #exceptions .. since we don't know at this point where the assembly will end up
	    if ( $property_name eq 'assembly_directory' ) {
		$self->status_message("assembly_directory is a required param for tool,". $class_meta->class_name .", it will be assigned build data_directory");
		next;
	    }
	    #if other required param is missing, quit
            if ( not exists $params{$property_name} ) {
                $self->error_message("Failed to get required param: $property_name for class, ".$class_meta->class_name);
                return;
            }
        }
    }

    return 1
}

sub post_assemble_parts {
    my $self = shift;

    my @post_assemble_parts = split (/\;\s+|\;/, $self->post_assemble);

    unless ( @post_assemble_parts ) {
	$self->error_message("Could not find any parts to run in string: ".$self->post_assemble);
	$self->delete;
    }

    return @post_assemble_parts;
}

sub after_assemble_methods_to_run {
    my ($self, $build) = @_;

    my $method = $self->assembler_accessor_name.'_after_assemble_methods_to_run';
    if ( $self->can( $method ) ) {
	$self->$method( $build );
    }

    return 1;
}

#sub velvet_after_assemble_methods_to_run {
sub velvet_one_button_after_assemble_methods_to_run {
    my ($self, $build) = @_;

    if ( not $self->remove_unnecessary_velvet_files( $build ) ) {
	$self->error_message("Failed to remove unnecessary velvet files");
	return;
    }

    return 1;
}

#< bsub usage >#

sub bsub_usage {
    my $self = shift;
    my $method = $self->assembler_accessor_name.'_bsub_rusage';
    if ( $self->can( $method ) ) {
        my $usage = $self->$method;
        return $usage;
    }
    $self->status_message( "bsub rusage not set for ".$self->assembler_name );
    return;
}

sub soap_de_novo_assemble_bsub_rusage {
    my $mem = 30000;
    return "-q bigmem -n 4 -R 'span[hosts=1] select[type==LINUX64 && mem>$mem] rusage[mem=$mem]' -M $mem".'000';
}

sub soap_import_bsub_rusage {
    return "-R 'select[type==LINUX64] rusage[internet_download_mbps=100] span[hosts=1]'";
}

sub velvet_one_button_bsub_rusage {
    return "-q bigmem -R 'select[type==LINUX64 && mem>30000] rusage[mem=30000] span[hosts=1]' -M 30000000";
}

#< soap specific methods to run during build >#

sub get_number_of_cpus {
    my $self = shift;

    return 1 if not defined $ENV{LSB_MCPU_HOSTS};

    my @tokens = split(/\s/, $ENV{LSB_MCPU_HOSTS});
    my $cpus = 0;
    if ( not @tokens ) {
        $self->error_message('Could not split LSB_MCPU_HOSTS: '.$ENV{LSB_MCPU_HOSTS});
        return;
    }

    for ( my $i = 1; $i <= @tokens; $i += 2 ) {
        if ( $tokens[$i] !~ /^$RE{num}{int}$/ ) {
            $self->error_message('Error parsing LSB_MCPU_HOSTS ('.$ENV{LSB_MCPU_HOSTS}.'), number of cpus is not an int: '.$tokens[$i]);
            return;
        }
        $cpus += $tokens[$i];
    }

    if ( $cpus == 0 ) {
        $self->error_message('Could not get the number of cpus from LSB_MCPU_HOSTS: '.$ENV{LSB_MCPU_HOSTS});
        return;
    }

    return $cpus;
}

#< velvet specific methods to run during build >#

sub remove_unnecessary_velvet_files {
    my ($self, $build) = @_;

    # contigs fasta files
    my @contigs_fastas_to_remove = glob($build->data_directory.'/*contigs.fa');
    unless ( @contigs_fastas_to_remove ) { # error here??
        $self->error_message("No contigs fasta files produced from running one button velvet.");
        return;
    }
    my $final_contigs_fasta = $build->contigs_fasta_file;
    for my $contigs_fasta_to_remove ( @contigs_fastas_to_remove ) {
        next if $contigs_fasta_to_remove eq $final_contigs_fasta;
        unless ( unlink $contigs_fasta_to_remove ) {
            $self->error_message(
                "Can't remove unnecessary contigs fasta ($contigs_fasta_to_remove): $!"
            );
            return;
        }
    }

    # log and timing files
    for my $glob (qw/ logfile timing /) {
        for my $file ( glob($build->data_directory.'/*-'.$glob) ) {
            unless ( unlink $file ) {
                $self->error_message("Can't remove unnecessary file ($glob => $file): $!");
                return;
            }
        }
    }

    return 1;
}

#< ASSEMBLE >#

sub assemble_build {
    my ($self, $build) = @_;

    my $assembler_name = $self->assembler_name;
    my $assembler_accessor_name = $self->assembler_accessor_name;
    
    #validate instrument data - returns arryref of ins data types
    my $ins_data_method = 'valid_'.$assembler_accessor_name.'_seq_platforms';
    my $ins_data = $self->$ins_data_method;
    unless ( grep {$self->sequencing_platform eq $_ } @$ins_data ) {
	$self->error_message("Sequencing platform: ".$self->sequencing_platform." is not supported for assembler: ".$self->assembler_name);
	return;
    }

    my %assembler_params;

    #TODO: there must be 'assembler_name'.'_params' for each assembler
    my $param_method = $assembler_accessor_name.'_params';

    if ( %assembler_params = $self->$param_method( $build ) ) {
	$self->status_message("Got params for assembler: $assembler_name");
    }
    else { #no params needed?
	$self->status_message("No params found for $assembler_name, that's okay if no params are needed");
    }
   
    #run assemble
    $self->status_message("Running $assembler_name");
    
    my $assemble_tool = $self->assembler_class;
    my $assemble = $assemble_tool->create( %assembler_params );

    unless ($assemble) {
        $self->error_message("Failed to create de-novo-assemble");
        return;
    }
    unless ($assemble->execute) {
        $self->error_message("Failed to execute de-novo-assemble execute");
        return;
    }
    $self->status_message("$assembler_name finished successfully");
    
    #methods to run after assembling .. not post assemble stage
    $self->after_assemble_methods_to_run( $build );
    
    return 1;
}

#< STATS FROM REPORT >#

sub generate_stats {
    my ($self, $build) = @_;

    my $class = 'Genome::Model::Tools::'.ucfirst $self->assembler_base_name.'::Stats';
    my $stats = $class->create( assembly_directory => $build->data_directory );
    unless( $stats->execute ) {
	$self->error_message("Failed to create stats");
	return;
    }

    return 1;
}

1;
