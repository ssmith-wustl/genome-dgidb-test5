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
           valid_values => [qw/ velvet newbler /],
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
        my ($class, $params) = $self->_get_class_and_params_from_read_processor_part($read_processor_part)
            or return;
        my %converted_params;
        for my $key ( keys %$params ) {
            if ( $key =~ /_/ ) { # underscores not allowed
                $self->error_message("Param ($key) for read processor part ($read_processor_part) params has an underscore. Use dashes (-) instead");
                return;
            }
            my $new_key = $key; 
            $new_key =~ s/\-/_/g; # sub - for _ to create processor
            $converted_params{$new_key} = $params->{$key};
        }
        my $obj; 
        eval{
            $obj = $class->create(%converted_params);
        };
        unless ( $obj ) {
            $self->error_message("Can't validate read processor ($read_processor_part) using class ($class): $@.");
            return;
        }
        $self->status_message("Read processor part OK: $read_processor_part");
        $obj->delete;
    }

    $self->status_message("Read processor OK");
    
    return 1;
}

sub _get_class_and_params_from_read_processor_part {
    my ($self, $read_processor_part) = @_;

    $DB::single = 1;
    my @tokens = split(/\s+/, $read_processor_part);
    my @subclass_parts;
    while ( my $token = shift @tokens ) {
        if ( $token =~ /^\-/ ) {
            unshift @tokens, $token;
            last;
        }
        push @subclass_parts, $token;
    }

    unless ( @subclass_parts ) {
        $self->error_message("Could not get class from read processor part: $read_processor_part");
        return;
    }

    my $class = 'Genome::Model::Tools::FastQual::'.
    join(
        '::', 
        map { Genome::Utility::Text::string_to_camel_case($_) }
        map { s/\-/ /; $_; }
        @subclass_parts
    );

    my %params;
    if ( @tokens ) {
        my $params_string = join(' ', @tokens);
        eval{
            %params = Genome::Utility::Text::param_string_to_hash(
                $params_string
            );
        };
        unless ( %params ) {
            $self->error_message("Can't get params from params string: $params_string");
            return;
        }
    }

    return ($class, \%params);
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

    my @classes = map { $_.'::'.$assembler_subclass }
    (qw/
        Genome::Model::Event::Build::DeNovoAssembly::PrepareInstrumentData
        Genome::Model::Event::Build::DeNovoAssembly::Assemble
        Genome::Model::Event::Build::DeNovoAssembly::PostAssemble

        /);
    push @classes, 'Genome::Model::Event::Build::DeNovoAssembly::Report';

    return @classes;
}

sub assemble_objects {
    return 1;
}

1;

#$HeadURL$
#$Id$
