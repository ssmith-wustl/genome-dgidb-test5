package Genome::Model::Tools::AmpliconAssembly::Assemble;

use strict;
use warnings;

use Genome;

use Data::Dumper 'Dumper';

class Genome::Model::Tools::AmpliconAssembly::Assemble{
    is => 'Genome::Model::Tools::AmpliconAssembly',
    has => [
    assembler => {
        is => 'Text',
        doc => 'The assembler to use.  Currently supported assemblers: '.join(', ', valid_assemblers()),
    },
    ],
    has_optional => [ 
    assembler_params => {
        is => 'Text',
        doc => 'String of parameters for the assembler',
    },
    ],
};

#< Assemblers >#
sub valid_assemblers {
    return (qw/ phred_phrap /);
}

#< Command >#
sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_)
        or return;

    unless ( $self->assembler ) {
        $self->error_message('No assembler given');
        $self->delete;
        return;
    }

    unless ( grep { $self->assembler eq $_ } valid_assemblers() ) {
        $self->error_message('Invalid assembler: '.$self->assembler);
        $self->delete;
        return;
    }

    unless ( $self->_get_hashified_assembler_params ) {
        # this may not be necessary for all assemblers, but handle that later
        $self->delete;
        return;
    }

    return $self;
}

sub execute {
    my $self = shift;

    my $amplicons = $self->get_amplicons
        or return;

    my $method = '_assemble_amplicon_with_'.$self->assembler;
    
    for my $amplicon ( @$amplicons ) {
        $self->$method($amplicon)
            or return;
    }

    return 1;
}

#< Assembling >#
sub _assemble_amplicon_with_phred_phrap {
    my ($self, $amplicon) = @_;

    my $fasta_file = $amplicon->processed_fasta_file;
    return 1 unless -s $fasta_file; # ok
    my $phred_phrap_params = $self->_get_hashified_assembler_params;
    
    my $phrap = Genome::Model::Tools::PhredPhrap::Fasta->create(
        fasta_file => $fasta_file,
        %$phred_phrap_params,
    );

    unless ( $phrap ) { # bad
        $self->error_message("Can't create phrap command.");
        return;
    }

    $phrap->execute;

    return 1;
}

sub _get_hashified_assembler_params {
    my $self = shift;

    return {} unless $self->assembler_params; # ok
    
    unless ( $self->{_hashified_assembler_params} ) {
        my %params = Genome::Utility::Text::param_string_to_hash( $self->assembler_params );
        unless ( %params ) {
            $self->error_message('Malformed assembler params: '.$self->assembler_params);
            return;
        }
        $self->{_hashified_assembler_params} = \%params;

    }

    return $self->{_hashified_assembler_params};
}

1;

#$HeadURL$
#$Id$
