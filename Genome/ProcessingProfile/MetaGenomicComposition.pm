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
    ribosomal_subunit => {
        doc => 'Ribsosomal subunit',
        valid_values => [qw/ 16 18 /],
    },
    assembly_size => {
        doc => 'Estimated assembly size, used for metrics and such',
    },
    subject_location => {
        doc => 'The location whence the original sample was collected', 
    },
    #####
    #TODO remove these props from the db
    #amplification_forward_primer => { doc => 'Primer used for amplification in the forward (5\') direction', },
    #amplification_reverse_primer => { doc => 'Primer used for amplification in the reverse (3\') direction', },
);
my %HAS_MANY = (
    sense_primer_sequences => {
        doc => 'Sense (5\' direction) primer sequences that can be used for to orient assemblies',
    },
    anti_sense_primer_sequences => { doc => 'Anti-sense (3\' direction) primer sequences that can be used for to orient assemblies', },
);
my %PROPERTIES = ( %HAS );
# FIXME
#my %PROPERTIES = ( %HAS, %HAS_MANY );

class Genome::ProcessingProfile::MetaGenomicComposition {
    is => 'Genome::ProcessingProfile',
    has => [
    map { 
        $_ => {
            via => 'params',
            to => 'value',
            where => [ name => $_ ],
            is_mutable => 1,
            doc => (
                ( exists $HAS{$_}->{valid_values} )
                ? sprintf('%s Valid values: %s.', $HAS{$_}->{doc}, join(', ', @{$HAS{$_}->{valid_values}}))
                : $HAS{$_}->{doc}
            ),
        },
    } keys %HAS
    ],
    # FIXME not working
    #  has_many => [ map { $_ => { %{$HAS_MANY{$_}}, via => 'params', to => 'value', where => [ name => $_ ], is_mutable => 1, }, } keys %HAS_MANY ],
};

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_);

    for my $property_name ( keys %PROPERTIES ) {
        next unless exists $PROPERTIES{$property_name}->{valid_values};
        unless ( grep { $self->$property_name eq $_ } @{$PROPERTIES{$property_name}->{valid_values}} ) {
            $self->error_message( 
                sprintf(
                    'Invalid value (%s) for %s.  Valid values: %s',
                    $self->$property_name,
                    $property_name,
                    join(', ', @{$PROPERTIES{$property_name}->{valid_values}}),
                ) 
            );
            $self->delete;
            return;
        }
    }

    return $self;
}

sub params_for_class { 
    return keys %PROPERTIES;
}

#< Primer Seq >#
my %iub2bases = (qw/
    R   AG  
    Y   CT  
    K   GT  
    M   AC  
    S   GC  
    W   AT  
    B   CGT 
    D   AGT 
    H   ACT 
    V   ACG 
    N   AGCT 
    /);
sub get_sense_primer_sequences {
    my $self = shift;

    my $primer;
    my @new_primers;
    for my $primer_base ( split(//, $primer) ) {
        my @new_bases;
        if ( exists $iub2bases{$primer_base} ) {
            for my $iub_base ( split(//, $iub2bases{$primer_base}) ) {
                push @new_bases, $iub_base;
                # add to  new primers
            }
        }
        else {
            @new_bases = ($primer_base);
        }

        for my $new_primer ( @new_primers ) {
            for my $new_base ( @new_bases ) {
                $primer .= $new_base;
            }
        }
    }

    return;
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
