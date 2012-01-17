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
        classifier => { is => 'Text', },
        classification_dir => { calculate => q| return $self->directory.'/classification'; |, },
    ],
    has_optional => [
        oriented_qual_file => { is => 'Text', },
        _amplicon_iterator => { is => 'Code', },
    ],
};

#< Amplicons >#
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
#<>#

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

sub _qual_file_for {
    my ($self, $type) = @_;
    my $fasta_file = $self->_fasta_file_for($type);
    return $fasta_file.'.qual';
}

sub seq_reader_for {
    my ($self, $type, $set_name) = @_;
    
    # Sanity checks - should not happen
    Carp::confess("No type given to get seq reader") unless defined $type;
        Carp::confess("Invalid type ($type) given to get seq reader") unless grep { $type eq $_ } (qw/ processed oriented /);

    my $fasta_file = $self->_fasta_file_for($type);
    my $qual_file = $self->_qual_file_for($type);
    return unless -e $fasta_file and -e $qual_file; # ok

    my %params = (
        file => $fasta_file,
        qual_file => $qual_file,
    );
    my $reader =  Genome::Model::Tools::Sx::PhredReader->create(%params);
    if ( not  $reader ) {
        $self->error_message("Failed to create phred reader for $type fasta file and amplicon set name ($set_name) for ".$self->description);
        return;
    }

    return $reader;
}

sub seq_writer_for {
    my ($self, $type) = @_;

    Carp::confess("No type given to get fasta and qual writer") unless defined $type;
    Carp::confess("Invalid type ($type) given to get fasta and qual writer") unless grep { $type eq $_ } (qw/ processed oriented /);

    my $fasta_file = $self->_fasta_file_for($type);
    my $qual_file = $self->_qual_file_for($type);
    unlink $fasta_file, $qual_file;

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

sub processed_qual_file {
    my $self = shift;
    return $self->_qual_file_for('processed');
}

sub oriented_fasta_file {
    my $self = shift;
    return $self->_fasta_file_for('oriented');
}

sub oriented_qual_file {
    my $self = shift;
    return $self->_qual_file_for('oriented');
}

sub classification_file {
    my $self = shift;

    return sprintf(
        '%s/%s%s.%s',
        $self->classification_dir,
        $self->file_base_name,
        ( $self->name eq '' ? '' : '.'.$self->name ),
        $self->classifier,
    );
}
#<>#

1;

