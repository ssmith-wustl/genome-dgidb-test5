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
           doc => 'A string of parameters to pass to the assembler.',
           is_optional => 1,
       },
       # Read Coverage, Trimmer and Filter
       read_trimmer_name => {
           doc => 'The name of the read trimmer.',
           is_optional => 1,
       },
       read_trimmer_params => {
           doc => 'A string of parameters to pass to the read trimmer',
           is_optional => 1,
       },
       read_filter_name => {
           doc => 'The name of the read filter.',
           is_optional => 1,
       },
       read_filter_params => {
           doc => 'A string of parameters to pass to the read filter.',
           is_optional => 1,
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
        $self->delete;
        return;
    }

      
    # Validate read filter & params
    unless ( $self->_validate_read_filter_and_params ) {
        # Error is in sub
        $self->delete;
        return;
    }

    # Validate read trimmer & params
    unless ( $self->_validate_read_trimmer_and_params ) {
        # Error is in sub
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

sub assembler_params_as_hash {
    my $self = shift;

    my %assembler_params = $self->_params_as_hash_for_operation('assembler');
    if ( defined $assembler_params{hash_sizes} ) { 
        $assembler_params{hash_sizes} = [ split(/\s+/, $assembler_params{hash_sizes}) ],
    }

    return %assembler_params;
}

sub _validate_assembler_and_params {
    my $self = shift;
    
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

    return 1;
}

#< Shared Operation Methods for Read Filter and Trimmer >#
sub _name_for_operation {
    my ($self, $operation) = @_;

    Carp::confess("No operation given to get name.") unless defined $operation;
    my $name_method = $operation.'_name';
    unless ( $self->can($name_method) ) { 
        Carp::confess("Invalid operation ($operation)");
    }
    return $self->$name_method;
}

sub _class_for_operation {
    my ($self, $operation) = @_;

    my $name = $self->_name_for_operation($operation) # undef ok, dies onn error
        or return;
    
    $operation =~ s/^read_//;
    my $class = 'Genome::Model::Tools::FastQual::'.
    Genome::Utility::Text::string_to_camel_case($operation).'::'.
    Genome::Utility::Text::string_to_camel_case($name);
    eval("use $class");
    if ( $@ ) {
        Carp::confess(
            $self->error_message("Can't find class ($class) for read $operation ($name)")
        );
    }

    return $class;
}

sub _params_as_hash_for_operation {
    my ($self, $operation) = @_;

    my $method = $operation.'_params';
    my $params_string = $self->$method;
    return unless $params_string; # ok 

    my %params = Genome::Utility::Text::param_string_to_hash($params_string);
    unless ( %params ) { # not ok
        Carp::confess(
            $self->error_message("Malformed $operation params: $params_string")
        );
    }

    return %params;
}

sub _object_for_operation {
    my ($self, $operation) = @_;

    my $name = $self->_name_for_operation($operation); # dies on error
    my %params = $self->_params_as_hash_for_operation($operation); # undef ok
    unless ( $name ) { # ok
        if ( %params ) { # not ok
            Carp::confess(
                $self->error_message("No $operation name, but params we're given. Please indicate a name for $operation, or do not indicate it's params.")
            );
        }
        return;
    }

    my $class = $self->_class_for_operation($operation); # dies on error
    my $obj = $class->create(%params);
    unless ( $obj ){ 
        Carp::confess(
            $self->error_message("Could not validate $operation params:\n".Dumper(\%params))
        );
    }
 
    return $obj;
}

sub _validate_operation_and_params {
    my ($self, $operation) = @_;

    my $obj;
    eval{ $obj = $self->_object_for_operation($operation); }; # dies on error
    
    if ( $@ ) {
        $self->error_message($@);
        return;
    }

    $obj->delete if $obj;

    return 1;
}

#< Read Filter >#
sub class_for_read_filter {
    return $_[0]->_class_for_operation('read_filter');
}

sub read_filter_params_as_hash {
    return $_[0]->_params_as_hash_for_operation('read_filter');
}

sub create_read_filter { 
    return $_[0]->_object_for_operation('read_filter');
}

sub _validate_read_filter_and_params {
    return $_[0]->_validate_operation_and_params('read_filter');
}

#< Read Trimmer #>
sub class_for_read_trimmer {
    return $_[0]->_class_for_operation('read_trimmer');
}

sub read_trimmer_params_as_hash {
    return $_[0]->_params_as_hash_for_operation('read_trimmer');
}

sub create_read_trimmer { 
    return $_[0]->_object_for_operation('read_trimmer');
}

sub _validate_read_trimmer_and_params {
    return $_[0]->_validate_operation_and_params('read_trimmer');
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
