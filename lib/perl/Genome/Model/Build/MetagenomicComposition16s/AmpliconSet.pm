package Genome::Model::Build::MetagenomicComposition16s::AmpliconSet;

use strict;
use warnings;

use Genome;

class Genome::Model::Build::MetagenomicComposition16s::AmpliconSet {
    is => 'UR::Object',
    has => [
        name => { is => 'Text', },
        primers => { is => 'Text', is_many => 1, is_optional => 1, },
        file_base_name => { is => 'Text', },
        directory => { is => 'Text', },
        fasta_dir => { calculate => q| return $self->directory.'/fasta'; |, },
        classification_dir => { 
            is => 'Text',
        },
        classification_file => { 
            is => 'Text',
        },
        oriented_fasta_file => { is => 'Text', },
    ],
    has_optional => [
        oriented_qual_file => { is => 'Text', },
        _amplicon_iterator => { is => 'Code', },
    ],
};

sub has_amplicons {
    my $self = shift;

    # Does the iterator exist?
    return 1 if $self->{_amplicon_iterator};

    # Do the fasta/qual files exist?
    my $fasta_file = $self->processed_fasta_file;
    my $qual_file = $self->processed_qual_file;
    return 1 if -e $fasta_file and -e $qual_file;

    return;
}

sub next_amplicon {
    my $self = shift;
    my $amplicon_iterator = $self->amplicon_iterator;
    return if not $amplicon_iterator;
    return $amplicon_iterator->();
}

sub amplicon_iterator {
    my $self = shift;

    return $self->{_amplicon_iterator} if $self->{_amplicon_iterator};

    my $fasta_file = $self->processed_fasta_file;
    my $qual_file = $self->processed_qual_file;
    return unless -e $fasta_file and -e $qual_file;
    my $reader =  Genome::Model::Tools::Sx::PhredReader->create(
        file => $fasta_file,
        qual_file => $qual_file,
    );
    if ( not  $reader ) {
        $self->error_message('Failed create phred reader');
        return;
    }

    my $classification_file = $self->classification_file;
    my ($classification_io, $classification_line);
    if ( -s $classification_file ) {
        $classification_io = eval{ Genome::Sys->open_file_for_reading($classification_file); };
        if ( not $classification_io ) {
            $self->error_message('Failed to open classification file: '.$classification_file);
            return;
        }
        $classification_line = $classification_io->getline;
        chomp $classification_line;
    }

    my $amplicon_iterator = sub{
        my $seq = $reader->read;
        return unless $seq;  #<-- HERER

        my %amplicon = (
            name => $seq->{id},
            reads => [ $seq->{id} ],
            reads_processed => 1,
            seq => $seq,
        );

        return \%amplicon if not $classification_line;

        my @classification = split(';', $classification_line); # 0 => id | 1 => ori
        if ( not defined $classification[0] ) {
            Carp::confess('Malformed classification line: '.$classification_line);
        }
        if ( $seq->{id} ne $classification[0] ) {
            return \%amplicon;
        }

        $classification_line = $classification_io->getline;
        chomp $classification_line if $classification_line;

        $amplicon{classification} = \@classification;
        return \%amplicon;
    };

    return $self->{_amplicon_iterator} = $amplicon_iterator;
}

#< FILES >#
sub _fasta_file_for {
    my ($self, $type) = @_;

    Carp::confess("No type given to get fasta (qual) file") unless defined $type;
    
    return sprintf(
        '%s/%s%s.%s.fasta',
        $self->fasta_dir,
        $self->file_base_name,
        ( $self->name eq '' ? '' : '.'.$self->name ),
        $type,
    );
}

sub seq_writer_for {
    my ($self, $type) = @_;

    # Sanity checks - should not happen
    die "No type given to get fasta and qual writer" unless defined $type;
    die "Invalid type ($type) given to get fasta and qual writer" unless grep { $type eq $_ } (qw/ processed oriented /);

    # Get method and fasta file
    my $fasta_method = $type.'_fasta_file';
    my $fasta_file = $self->$fasta_method;
    my $qual_method = $type.'_qual_file';
    my $qual_file = $self->$qual_method;
    unlink $fasta_file, $qual_file;

    # Create writer, return
    my $writer =  Genome::Model::Tools::Sx::PhredWriter->create(
        file => $fasta_file,
        qual_file => $qual_file,
    );
    unless ( $writer ) {
        $self->error_message("Can't create phred writer for $type fasta file and amplicon set name (".$self->name.')');
        return;
    }

    return $writer;
}

sub processed_fasta_file {
    my $self = shift;
    return $self->_fasta_file_for('processed');
}

sub processed_qual_file { # returns them as a string (legacy)
    my $self = shift;
    return $self->processed_fasta_file.'.qual';
}
#<>#

1;

