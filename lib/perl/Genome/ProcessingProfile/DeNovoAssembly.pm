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
	    is => 'Integer',
	    is_optional => 1,
	    doc => 'Use genome size to limit the number of reads used in the assembly to obtain this coverage.',
	},
	# Assembler
	assembler_name => {
	    doc => 'Name of the assembler.',
	    valid_values => [qw/ velvet newbler soap /],
	},
	assembler_version => {
	    doc => 'Version of assembler.',
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

#< Assembler >#
my %supported_assemblers = (
    newbler => {
        platforms => [qw/ 454 /],
    },
    velvet => {
        platforms => [qw/ solexa /],
        class => 'Genome::Model::Tools::Velvet::OneButton',
    },
    soap => {
	platforms => [qw/ solexa /],
	class => 'Genome::Model::Tools::Soap::DeNovoAssemble',
    },
);

sub supported_sequencing_platforms_for_assembler {
    my $self = shift;

    my $assembler_name = $self->assembler_name;
    unless ( defined $assembler_name ) {
        Carp::confess(
            $self->error_message("Can't get supported sequencing platforms: No assembler name set.")
        );
    }

    my $platforms = $supported_assemblers{$assembler_name}->{platforms};
    unless ( $platforms ) {
        Carp::confess(
            $self->error_message("Can't get supported sequencing platforms: Unsupported assembler ($assembler_name).")
        );
    }

    return $platforms;
}

sub class_for_assembler {
    my $self = shift;
    
    my $assembler_name = $self->assembler_name;
    unless ( defined $assembler_name ) {
        Carp::confess(
            $self->error_message("Can't get class for assembler: No assembler name set.")
        );
    }

    my $class = $supported_assemblers{$assembler_name}->{class};
    unless ( $class ) {
        Carp::confess(
            $self->error_message("Unsupported assembler ($assembler_name)")
        );
    }

    return $class;
}

# FIXME need a validator for each assembler!
sub assembler_params_as_hash {
    my $self = shift;

    my $params_string = $self->assembler_params;
    return unless $params_string; # ok 

    my %params = Genome::Utility::Text::param_string_to_hash($params_string);
    unless ( %params ) { # not ok
        Carp::confess(
            $self->error_message("Malformed assembler params: $params_string")
        );
    }

    if ( defined $params{hash_sizes} ) { 
        $params{hash_sizes} = [ split(/\s+/, $params{hash_sizes}) ],
    }

    return %params;
}

sub _validate_assembler_and_params {
    my $self = shift;

    $self->status_message("Validating assembler and params...");
    
    # Assembler and seq platform combo
    my $supported_sequencing_platforms_for_assembler = $self->supported_sequencing_platforms_for_assembler;
    unless ( grep { $self->sequencing_platform eq $_ } @$supported_sequencing_platforms_for_assembler ) {
        $self->error_message(
            "Invalid  name (".$self->assembler_name.") and (".$self->sequencing_platform.") combination."
        );
        return;
    }

    my $assembler_class = $self->class_for_assembler;
    my %assembler_params = $self->assembler_params_as_hash;

    for my $calculated_param (qw/ genome_len ins_length /) { # only for velvet, may need a method
        next unless exists $assembler_params{$calculated_param};
        $self->error_message("Assembler param ($calculated_param) is a calculated parameter, and cannot be set on the processing profile.");
        return;
    }

    %assembler_params = $self->_filter_non_assembler_params(%assembler_params);
    
    my $assembler;
    eval{
        $assembler = $assembler_class->create(
            version => $self->assembler_version,
            %assembler_params,
        );
    };
    unless ( $assembler ) { 
        $self->error_message("$@\n\nCould not validate assembler params: ".$self->assembler_params);
        return;
    }

    $assembler->delete;

    $self->status_message("Assembler and params OK");

    return 1;
}

sub _filter_non_assembler_params {
    my ($self, %params)  = @_;
    
    if ($self->assembler_name eq 'soap' and exists $params{'insert_size'}) {
	delete $params{'insert_size'};
    }
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

    my $assembler_subclass = Genome::Utility::Text::string_to_camel_case($self->assembler_name);

    my @classes = 'Genome::Model::Event::Build::DeNovoAssembly::PrepareInstrumentData';

    push @classes, map { $_.'::'.$assembler_subclass } (qw/
        Genome::Model::Event::Build::DeNovoAssembly::Assemble
        /);

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

	my $class = 'Genome::Model::Tools::' . ucfirst $self->assembler_name . '::' . $class_name;

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

    my @post_assemble_parts = split (/\;\s+?/, $self->post_assemble);

    unless ( @post_assemble_parts ) {
	$self->error_message("Could not find any parts to run in string: ".$self->post_assemble);
	$self->delete;
    }

    return @post_assemble_parts;
}

1;

#$HeadURL$
#$Id$
