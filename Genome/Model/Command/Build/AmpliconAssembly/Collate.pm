package Genome::Model::Command::Build::AmpliconAssembly::Collate;

use strict;
use warnings;

use Genome;

use Data::Dumper 'Dumper';

class Genome::Model::Command::Build::AmpliconAssembly::Collate {
    is => 'Genome::Model::Event',
};

sub execute {
    my $self = shift;

    my $amplicons = $self->build->get_amplicons
        or return;
    
    my @amplicon_fasta_types = $self->build->amplicon_fasta_types;

    $self->_open_build_fasta_and_qual_fhs(@amplicon_fasta_types)
        or return;

    for my $amplicon ( @$amplicons ) {
        for my $type ( @amplicon_fasta_types ) {
            $self->_collate_amplicon_fasta_and_qual($amplicon, $type);
        }
    }

    $self->_close_build_fasta_and_qual_fhs(@amplicon_fasta_types)
        or return;

    #print $self->build->data_directory,"\n"; <STDIN>;

    return 1;
}

#< FHs >#
sub _fasta_fh_key_for_type {
    return '_'.$_[0].'_fasta_fh';
}

sub _qual_fh_key_for_type {
    return '_'.$_[0].'_qual_fh';
}

sub _open_build_fasta_and_qual_fhs {
    my ($self, @types) = @_;

    for my $type ( @types ) {
        my $fasta_file = $self->build->fasta_file_for_type($type);
        unlink $fasta_file if -e $fasta_file;
        $self->{ _fasta_fh_key_for_type($type) } = Genome::Utility::FileSystem->open_file_for_writing($fasta_file)
            or return;

        my $qual_file = $self->build->qual_file_for_type($type);
        unlink $qual_file if -e $qual_file;
        $self->{ _qual_fh_key_for_type($type) } = Genome::Utility::FileSystem->open_file_for_writing($qual_file)
            or return;
    }

    return 1;
}

sub _close_build_fasta_and_qual_fhs {
    my ($self, @types) = @_;

    for my $type ( @types ) {
        $self->{ _fasta_fh_key_for_type($type) }->close;
        $self->{ _qual_fh_key_for_type($type) }->close;
    }

    return 1;
}

#< Collating the Amplicon Fastas >#
sub _collate_amplicon_fasta_and_qual {
    my ($self, $amplicon, $type) = @_;

    # FASTA
    my $fasta_file = $amplicon->fasta_file_for_type($type);
    return unless -s $fasta_file;
    #print "Found $fasta_file\n";
    my $fasta_fh = Genome::Utility::FileSystem->open_file_for_reading($fasta_file)
        or return;
    my $fasta_fh_key = _fasta_fh_key_for_type($type);
    while ( my $line = $fasta_fh->getline ) {
        $self->{$fasta_fh_key}->print($line);
    }

    #QUAL
    my $qual_file = $amplicon->qual_file_for_type($type);
    $self->fatal_msg(
        sprintf('Fasta file, but no qual file (%s) for amplicon (%s)', $qual_file, $amplicon->get_name)
    ) unless -e $qual_file;
    my $qual_fh = Genome::Utility::FileSystem->open_file_for_reading($qual_file)
        or return;
    my $qual_fh_key = _qual_fh_key_for_type($type);
    while ( my $line = $qual_fh->getline ) {
        $self->{$qual_fh_key}->print($line);
    }

    return 1;
}

1;

#$HeadURL$
#$Id$
