package Genome::ProcessingProfile::DeNovoAssembly;

#:eclark 11/16/2009 Code review.

# Short term: There should be a better way to define the class than %HAS.
# Long term: See Genome::ProcessingProfile notes.

use strict;
use warnings;

use Genome;

class Genome::ProcessingProfile::DeNovoAssembly{
    is => 'Genome::ProcessingProfile::Staged',
    has_param => [
                  #SHARED PARAMS
		  sequencing_platform => {
		      doc => 'The sequencing platform used to produce the read sets to be assembled',
		      valid_values => [qw/ 454 solexa sanger /],
		  },
		  assembler_name => {
		      doc => 'The name of the assembler to use when assembling read sets',
		      valid_values => [qw/ velvet newbler /],
		  },
		  assembler_version => {
		      doc => 'Version of assembler to use',
		      is_optional => 1,
#		      valid_values => [qw//], #LONG LIST OF VALID VALUES FOR NEWBLER
		  },
                  #SHARED PROCESSING PARAMS
		  assembler_params => {
		      doc => 'A string of parameters to pass to the assembler',
		      is_optional => 1,
		  },
                  prepare_instrument_data_params => {
		      doc => 'A string of parameters to pass to prepare instrument data step',
		      is_optional => 1,
                  },
                  assembly_preprocess_params => {
		      doc => 'A string of parameters to pass to assembly preprocess step',
		      is_optional => 1,
                  },
                  #NEWBLER SPECIFIC PARAMS
            version_subdirectory => {
		      doc => '454 version subdirectory name',
		      valid_values => ['offInstrumentApps','mapasm454_source'],
		      is_optional => 1,
                  },
                  read_trimmer_name => {
		      doc => 'The name of the software to use when trimming read sets',
		      is_optional => 1,
                  },
                  read_trimmer_params => {
		      doc => 'A string of parameters to pass to the read_trimmer',
		      is_optional => 1,
                  },
                  read_filter_name => {
		      doc => 'The name of the software to use when filtering read sets',
		      is_optional => 1,
                  },
                  read_filter_params => {
		     doc => 'A string of parameters to pass to the read_filter',
		     is_optional => 1,
                  },
    ],
};

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_);

    unless ($self) {
        return;
    }

    #ADDITIONAL PARAMS FOR ASSEMBLER, PREPARE_INSTRUMENT_DATA AND ASSEMBLY_PREPROCESS PARAMS
    foreach my $step ('assemble', 'prepare_instrument_data', 'preprocess') {
	my $params_method =  'get_'.$step.'_params';
	my $params = $self->$params_method;# or return;
	#SKIP STEPS THAT ARE NOT APPLICABLE TO A BUILD
	next unless $params;
	#VALIDATE PARAMS
	unless ($self->_validate_params_for_step($step, $params)) {#, $self->assembler_name)) {
	    $self->error_message("Failed to validate $step params");
	    return;
	}
    }
    return $self;
}

sub get_param_string_as_hash {
    my ($self, $param_string) = @_;

    my %params;
    return \%params unless $param_string;

    #MAKE SURE FIRST ELEMENT IS A PARAM THAT STARTS WITH A -
    unless ($param_string =~ /^-/) {
	$self->error_message("Parameter must start with a dash: $param_string");
	return;
    }

    my @tokens = split(/\s+/, $param_string);
    unless ( @tokens ) {
	$self->error_message("Can not split param string by blank space");
	return;
    }

    while ( @tokens ) {
	my $key = shift @tokens;
	unless ($key =~ s/^-//) {
	    $self->error_message("Invalid param ($key). Shouild start with a '-'");
	    return;
	}
	$params{$key} = 1;
	#IF NEXT ELEMENT BEGINS WITH - OR DOESN'T EXIST, PARAM IS BOOLEAN
	next if not @tokens or $tokens[0] =~ /^-/;
	$params{$key} = shift @tokens;
    }

    #print Dumper(\%params);
    return \%params;
}

sub _validate_params_for_step {
    my ($self, $step, $params) = @_;
    #GET FooBar FROM  foo_bar
    my $step_name = join '', map {ucfirst $_} split '_', $step;
    my $stage = 'Genome::Model::Command::Build::DeNovoAssembly';
    unless ($stage->validate_params($step_name, $params, ucfirst $self->assembler_name) ) {
	$self->error_message("Failed to validate params for $stage");
	return;
    }

    return 1;
}

sub get_assemble_params {
    my $self = shift;
    return $self->get_param_string_as_hash ($self->assembler_params);
}

sub get_prepare_instrument_data_params {
    my $self = shift;
    return $self->get_param_string_as_hash ($self->prepare_instrument_data_params);
}

sub get_preprocess_params {
    my $self = shift;
    return $self->get_param_string_as_hash ($self->assembly_preprocess_params);
}

#< Stages >#
sub stages {
    return (qw/
        assemble
    /);
}

sub assemble_job_classes {
    return (qw/
            Genome::Model::Command::Build::DeNovoAssembly::PrepareInstrumentData
            Genome::Model::Command::Build::DeNovoAssembly::Preprocess
            Genome::Model::Command::Build::DeNovoAssembly::Assemble
	    /);  
}

sub assemble_objects {
    return 1;
}

sub instrument_data_is_applicable {
    my $self = shift;
    my $instrument_data_type = shift;
    my $instrument_data_id = shift;
    my $subject_name = shift;

    my $lc_instrument_data_type = lc($instrument_data_type);
    if ($self->sequencing_platform) {
        unless ($self->sequencing_platform eq $lc_instrument_data_type) {
            $self->error_message('The processing profile sequencing platform ('. $self->sequencing_platform
                                 .') does not match the instrument data type ('. $lc_instrument_data_type .')');
            return;
        }
    }

    return 1;
}

1;

