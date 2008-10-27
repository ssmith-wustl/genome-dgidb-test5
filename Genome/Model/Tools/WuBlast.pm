package Genome::Model::Tools::WuBlast;

use strict;
use warnings;

use Genome;

use Data::Dumper;
require Genome::Model::Tools::WuBlast::Xdformat::Verify;

#BLASTN: E, S, E2, S2, W, T, X, M, N, Y, Z, L, K, H, V, B
#BLASTP: E, S, E2, S2, W, T, X, M,    Y, Z, L, K, H, V, B
#BLASTX: E, S, E2, S2, W, T, X, M, C, Y, Z, L, K, H, V, B 
my %BASE_BLAST_PARAMS = (
    E => 'Expectation threshold for reporting database hits.',
    S => 'Score-equivalence threshold for reporting database hits',
    E2 => 'Expectation threshold for saving ungapped HSPs',
    S2 => 'Threshold for saving ungapped HSPs ',
    W => 'Seed word length for the ungapped BLAST algorithm',
    T => 'Neighborhood word score threshold for the ungapped BLAST algorithm',
    X => 'Drop-off score for the ungapped BLAST algorithm',
    M => 'Match score',
    Y => 'Effective length of the query sequence (in units of residues) used in statistical significance calculations',
    Z => 'Effective size of the database (database) used in statistical significance calculations',
    L => 'Use lambda for the value of the lambda parameter in the extreme value statistics (Karlin and Altschul, 1990) used in computing the statistics of ungapped alignments',
    K => 'Value for extreme value statistics K parameter (Karlin and Altschul, 1990) used in computing the statistics of ungapped alignments',
    H => 'Relative entropy when computing the statistics of ungapped alignments.',
    V => 'Number of one line summaries',
    B => 'Number of database hits to report',
    Q => 'Penalty score for a gap of length of one character',
    R => 'Penalty score for extending a gap by each letter after the first character',
);

class Genome::Model::Tools::WuBlast {
    is => 'Command',
    is_abstract => 1,
    has => [
    database => {
        type => 'String',
        is_input => 1,
        doc => 'The path to a blastable database (xdformat)',
    },
    ],
    has_optional => [
    output_file => {
        type => 'String',
        is_input => 1,
        doc => 'File name for the output.  Default is the database with an appended ".blast" extension',
    },
    map(
        {
            $_ => {
                type => 'String',
                doc => $BASE_BLAST_PARAMS{$_},
            }
        } keys %BASE_BLAST_PARAMS,
    ),
    ],
    has_many => [
    query_files => {
        type => 'String',
        is_input => 1,
        doc => 'Query files (comma separated from the command line)',
    },
    ],
};

#< Standard command methods >#
sub help_brief {
    return 'Wrapper for wu blast programs: blastn, blastp and blastx.';
}

sub help_detail {
    return help_brief();
}

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_);

    # Verify DB
    Genome::Model::Tools::WuBlast::Xdformat::Verify->execute(
        database => $self->database,
        db_type => $self->_blast_type,
    )
        or return;

    # Verify fasta files
    my @missing_query_files;
    for my $fasta_file ( $self->query_files ) {
        push @missing_query_files, $fasta_file unless -e $fasta_file;
    }

    if ( @missing_query_files ) {
        $self->error_message('Fasta files do not exist: '.join(',', @missing_query_files));
        return;
    }
    
    # Set output TODO move to class def and use calculate
    $self->output_file( $self->database.'.blast') unless defined $self->output_file;
    unlink $self->output_file if -e $self->output_file;

    return $self;
}

sub execute {
    my $self = shift;

    my $cmd = $self->_construct_blast_command
        or return;

    my $rv = system $cmd;
    if ( $rv ) {
        $self->error_message( sprintf('Running %s returned a non zero value (%s)', $self->_blast_command, $rv) );
        return;
    }

    return 1;
}

#< Sub class and derived methods >#
sub _sub_class {
    my $class = ref($_[0]) || $_[0];

    if ( $class eq __PACKAGE__ ) {
        $class->error_message(__PACKAGE__ . 'is abstract.  Use subclass.');
        return;
    }
    
    my ($sub_class) = $class =~ m#\:\:(Blast[npx])$#;
    unless ( $sub_class ) {
        $class->error_message("Can't determine subclass from class ($class)");
        return;
    }

    return $sub_class;
}

sub _blast_command {
    my $self = shift;

    my $sub_class = $self->_sub_class
        or return;

    return lc($sub_class);
}

sub _blast_type {
    my $self = shift;

    my $sub_class = $self->_sub_class
        or return;

    $sub_class =~ s#blast##i;

    return $sub_class;
}

sub _construct_blast_command {
    my $self = shift;

    my $blast_params = $self->_blast_params_and_values
        or return;

    my $cmd = sprintf(
        '%s %s %s %s > %s',
        $self->_blast_command,
        $self->database,
        join(' ', $self->query_files),
        join(' ', map({ sprintf('-%s %s', $_, $blast_params->{$_}) } keys %$blast_params)),
        $self->output_file,
    );

    return $cmd;
}

#< Blast params >#
sub _base_blast_params {
    return keys %BASE_BLAST_PARAMS;
}

sub _blast_params {
    my $self = shift;

    my @params = $self->_base_blast_params;
    if ( $self->can('_additional_blast_params') ) {
        push @params, $self->_additional_blast_params;
    }

    return @params;
}

sub _blast_params_and_values {
    my $self = shift;

    my %params;
    for my $param ( $self->_blast_params ) {
        my $val = $self->$param;
        next unless defined $val;
        $params{$param} = $val;
    }

    return \%params;
}

1;

#$HeadURL$
#$Id$
