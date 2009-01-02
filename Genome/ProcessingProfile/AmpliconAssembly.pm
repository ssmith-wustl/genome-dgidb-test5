package Genome::ProcessingProfile::AmpliconAssembly;

use strict;
use warnings;

use Genome;

use Data::Dumper;

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
    region_of_interest => {
        doc => 'The name of the region being targeted',
    },
    purpose => { 
        doc => 'Purpose of these amplicon assemblies.',
        valid_values => [qw/ reference composition /],
    },
    primer_amp_forward => {
        doc => 'Primer used for amplification in the forward (5\') direction.  Enter both the name and sequence of the primer, separated by a colon as "NAME:SEQUENCE".  This will be used for naming the profile as well as orientation of the assemblies.', 
    },
    primer_amp_reverse => {
        doc => 'Primer used for amplification in the reverse (3\') direction.  Enter both the name and sequence of the primer, separated by a colon as "NAME:SEQUENCE".  This will be used for naming the profile as well as orientation of the assemblies.', 
    },
    primer_seq_forward => { 
        doc => 'Primer used for *internal* sequencing in the forward (5\') direction.  Enter both the name and sequence of the primer, separated by a colon as "NAME:SEQUENCE".  This will be used for naming the profile as well as orientation of the assemblies.', 
        is_optional => 1,
    },
    primer_seq_reverse => { 
        is_optional => 1,
        doc => 'Primer used for *internal* sequencing in the reverse (3\') direction.  Enter both the name and sequence of the primer, separated by a colon as "NAME:SEQUENCE".  This will be used for naming the profile as well as orientation of the assemblies.', 
    },
);
my %PRIMER_SENSES = (
    sense => 'forward',
    anti_sense => 'reverse',
);

class Genome::ProcessingProfile::AmpliconAssembly {
    is => 'Genome::ProcessingProfile',
    has => [
    map(
        { 
            $_ => {
                via => 'params',
                to => 'value',
                where => [ name => $_ ],
                is_mutable => 1,
                is_optional => ( exists $HAS{$_}->{is_optional} ? $HAS{$_}->{is_optional} : 0),
                doc => (
                    ( exists $HAS{$_}->{valid_values} )
                    ? sprintf('%s. Valid values: %s.', $HAS{$_}->{doc}, join(', ', @{$HAS{$_}->{valid_values}}))
                    : $HAS{$_}->{doc}
                ),
            },
        } keys %HAS
    ),
    ],
};

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_)
        or return;

    # Check valid values
    for my $property ( keys %HAS ) {
        my $value = $self->$property;
        unless ( $HAS{$property}->{is_optional} ) { 
            unless ( defined $value ) {
                $self->error_message("Property ($property) is required");
                $self->delete;
                return;
            }
        }
        next unless exists $HAS{$property}->{valid_values};
        unless ( grep { $self->$property eq $_ } @{$HAS{$property}->{valid_values}} ) {
            $self->error_message( 
                sprintf(
                    'Invalid value (%s) for %s.  Valid values: %s',
                    $self->$property,
                    $property,
                    join(', ', @{$HAS{$property}->{valid_values}}),
                ) 
            );
            $self->delete;
            return;
        }
    }

    # Check primers, create sense fastas and create name
    for my $sense ( sort { $b cmp $a } keys %PRIMER_SENSES ) {
        my $file_method = sprintf('%s_primer_fasta', $sense);
        my $file = $self->$file_method;
        unlink $file if -e $file;
        my $bioseq_io = Bio::SeqIO->new(
            '-file' => ">$file",
            '-format' => 'Fasta',
        );
        for my $primer_purpose (qw/ amp seq /) {
            my $method = sprintf('primer_%s_%s', $primer_purpose, $PRIMER_SENSES{$sense});
            my $primer = $self->$method;
            next unless defined $primer;
            my ($primer_name, $primer_seq) = split(/:/, $primer);
            unless ( $primer =~ /^([\w\d\-\.\_]+):([ATCGMRWSYKVHDBN]+)$/i ) {
                $self->error_message("Invlaid format for primer ($primer).  Please use 'NAME:SEQUENCE'");
                $self->delete;
                return;
            }
            $bioseq_io->write_seq( 
                Bio::PrimarySeq->new( 
                    '-id' => $1,
                    '-seq' => $2,
                    '-alphabet' => 'dna',
                )
            );
        }
    }

    return $self;
}

sub delete {
    my $self = shift;

    # Remove primer files
    for my $sense ( keys %PRIMER_SENSES ) {
        my $file_method = sprintf('%s_primer_fasta', $sense);
        my $file = $self->$file_method;
        unlink $file if -e $file;
    }

    return $self->SUPER::delete;
}

#< Properties >#
sub params_for_class { 
    return keys %HAS;
}

#< Primers >#
sub primer_fasta_directory {
    return '/gscmnt/839/info/medseq/processing_profile_data/amplicon_assembly';
}

sub sense_primer_fasta {
    return sprintf('%s/%s.sense.fasta', $_[0]->primer_fasta_directory, $_[0]->id);
}

sub anti_sense_primer_fasta {
    return sprintf('%s/%s.anti_sense.fasta', $_[0]->primer_fasta_directory, $_[0]->id);
}

# TODO map sense to f/r
#sub sense_primer_names {
#} # etc...

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
