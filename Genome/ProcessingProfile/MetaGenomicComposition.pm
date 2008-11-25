package Genome::ProcessingProfile::MetaGenomicComposition;

use strict;
use warnings;

use Genome;

my %HAS = (
    sequencing_center => {
        doc => 'Place from whence the reads have come.',
        valid_values => [qw/ gsc broad baylor nisc /],
    },
    sequencing_platform => {
        doc => 'Platform (machine) from whence the reads where created.',
        valid_values => [qw/ sanger 454 solexa solid /],
    },
    assembler => {
        doc => 'Assembler type for assembling said reads.',
        valid_values => [qw/ maq newbler pcap phredphrap /],
    },
    assembly_size => {
        doc => 'Estimated assembly size, used for metrics and such',
    },
    #####
    #TODO remove these props from the db
    #amplification_forward_primer => { doc => 'Primer used for amplification in the forward (5\') direction', },
    #amplification_reverse_primer => { doc => 'Primer used for amplification in the reverse (3\') direction', },
    #subject_location => { doc => 'The location whence the original sample was collected', },
    #ribosomal_subunit => { doc => 'Ribsosomal subunit', valid_values => [qw/ 16 18 /], },
);
#my @PRIMER_TYPES = (qw/ sense anti_sense /);

class Genome::ProcessingProfile::MetaGenomicComposition {
    is => 'Genome::ProcessingProfile',
    has => [
    map(
        { 
            $_ => {
                via => 'params',
                to => 'value',
                where => [ name => $_ ],
                is_mutable => 1,
                doc => (
                    ( exists $HAS{$_}->{valid_values} )
                    ? sprintf('%s. Valid values: %s.', $HAS{$_}->{doc}, join(', ', @{$HAS{$_}->{valid_values}}))
                    : $HAS{$_}->{doc}
                ),
            },
        } keys %HAS
    ),
    #   map( { sprintf('%s_primer_sequences', $_) => { via => 'params', where => [ name => sprintf('%s_primer_sequences', $_) ], to => 'value', is_many => 1, is_mutable => 1, doc => sprintf('%s primer sequences that can be used for to orient assemblies', ucfirst $_), } } @PRIMER_TYPES),
    ],
};

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_);

    for my $property_name ( keys %HAS ) {
        next unless exists $HAS{$property_name}->{valid_values};
        unless ( grep { $self->$property_name eq $_ } @{$HAS{$property_name}->{valid_values}} ) {
            $self->error_message( 
                sprintf(
                    'Invalid value (%s) for %s.  Valid values: %s',
                    $self->$property_name,
                    $property_name,
                    join(', ', @{$HAS{$property_name}->{valid_values}}),
                ) 
            );
            $self->delete;
            return;
        }
    }

    return $self;
}

sub params_for_class { 
    return keys %HAS;
    #return (keys %HAS, map { sprintf('%s_primer_sequences', $_) } @PRIMER_TYPES);
}

#< Primers >#
sub primer_fasta_directory {
    return '/gscmnt/839/info/medseq/meta-genomic-composition/primers';
}

sub sense_primer_fasta {
    return sprintf('%s/%s.sense.fasta', $_[0]->primer_fasta_directory, join('_', split(/\s+/, $_[0]->name)));
}

sub anti_sense_primer_fasta {
    return sprintf('%s/%s.anti_sense.fasta', $_[0]->primer_fasta_directory, join('_', split(/\s+/, $_[0]->name)));
}

#################################################################
##FIXME needed?
sub instrument_data_is_applicable { 
    my $self = shift;
    my $instrument_data_type = shift;
    my $instrument_data_id = shift;
    my $subject_name = shift;

    my $lc_instrument_data_type = lc($instrument_data_type);
    if ($self->sequencing_platform) {
        unless ($self->sequencing_platform eq $lc_instrument_data_type) {
            $self->error_message('The processing profile sequencing platform ('. $self->sequencing_platform
                .') does not match the instrument data type ('. $lc_instrument_data_type);
            return;
        }
    }

    return 1;
}

1;

#$HeadURL$
#$Id$
