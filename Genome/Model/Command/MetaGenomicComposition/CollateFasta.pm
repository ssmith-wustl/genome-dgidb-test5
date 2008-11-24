package Genome::Model::Command::MetaGenomicComposition::CollateFasta;

use strict;
use warnings;

use Genome;

use Data::Dumper;
require IO::Dir;
require IO::File;

my $_fasta_and_qual_types = {
    pre_processing => '%s/%s.fasta.pre_processing',
    assembly_input => '%s/%s.fasta',
};

class Genome::Model::Command::MetaGenomicComposition::CollateFasta { 
    is => 'Genome::Model::Command::MetaGenomicComposition',
    has_optional => [
    all => {
        type => 'Boolean',
        default => 0,
        doc => 'Get all FASTA and Qual types ('.join(', ', fasta_and_qual_types()).') for each subclone',
    },
    map(
        {
            $_ => {
                type => 'Boolean',
                default => 0,
                doc => 'Get '.join(' ', split(/_/, $_)).' FASTA and Qual for each subclone',
            }
        } fasta_and_qual_types()
    ),
    ],
};

#<>#
sub help_brief {
    return 'Collate the FASTAs and Quality files for all assemblies in a MGC model.';
}

sub help_detail {
    return help_brief();
}

#<>#
sub fasta_and_qual_types {
    return keys %$_fasta_and_qual_types;
}

sub fasta_and_qual_types_as_strings {
    return map { join(' ', split(/_/)) } keys %$_fasta_and_qual_types;
}

sub _subclone_fasta_file_for_type {
    my ($self, $type, $subclone) = @_;

    return sprintf(
        $_fasta_and_qual_types->{$type},
        $self->model->consed_directory->edit_dir, 
        $subclone
    );
}

sub _verify_fasta_and_qual_types {
    my $self = shift;

    if ( $self->all ) {
        for my $type ( $self->fasta_and_qual_types ) {
            $self->$type(1);
        }
    }
    
    unless ( grep { $self->$_ } $self->fasta_and_qual_types ) {
        $self->error_message( 
            sprintf('Please select type of Fasta to get: %s', join(', ', 'all', $self->fasta_and_qual_types)) 
        );
        return;
    }

    return $self;
}

#<>#
sub DESTROY { 
    my $self = shift;

    $self->close_output_fhs;
    $self->SUPER::DESTROY;

    return 1;
}

sub execute {
    my $self = shift;

    $self->_verify_fasta_and_qual_types
        or return
    
    $self->_verify_mgc_model
        or return;
    
    my $subclones = $self->model->subclones
        or return;

    $self->_open_output_fhs
        or return;

    for my $subclone ( @$subclones ) {
        for my $type ( $self->fasta_and_qual_types ) {
            next unless $self->$type;
            $self->_add_fasta_and_qual($type, $subclone);
        }
    }

    return $self->_close_output_fhs;
}

sub _open_output_fhs {
    my $self = shift;

    for my $type ( $self->fasta_and_qual_types ) {
        next unless $self->$type;
        my $file_method = sprintf('all_%s_fasta', $type);
        my $fasta_file = $self->model->$file_method;
        unlink $fasta_file if -e $fasta_file;
        my $fasta_fh = IO::File->new($fasta_file, 'w');
        unless ( $fasta_fh ) {
            $self->error_message("Can't open file ($fasta_file): $!");
            return;
        }
        $self->{ sprintf('_%s_fasta_fh', $type) } = $fasta_fh;

        my $qual_file = $fasta_file . '.qual';
        unlink $qual_file if -e $qual_file;
        my $qual_fh = IO::File->new($qual_file, 'w');
        unless ( $qual_fh ) {
            $self->error_message("Can't open file ($qual_file): $!");
            return;
        }
        $self->{ sprintf('_%s_qual_fh', $type) } = $qual_fh;
    }

    return 1;
}

sub _close_output_fhs {
    my $self = shift;

    for my $type ( $self->fasta_and_qual_types ) {
        next unless $self->$type;
        $self->{ sprintf('_%s_fasta_fh', $type) }->close;
        $self->{ sprintf('_%s_qual_fh', $type) }->close;
    }

    return 1;
}

sub _add_fasta_and_qual {
    my ($self, $type, $subclone) = @_;

    my $edit_dir = $self->model->consed_directory->edit_dir;
    
    # FASTA
    my $fasta_file = $self->_subclone_fasta_file_for_type($type, $subclone);
    return 1 unless -s $fasta_file;
    my $fasta_fh = IO::File->new($fasta_file, 'r')
        or $self->fatal_msg("Can't open file ($fasta_file) for reading");
    my $fasta_fh_key = sprintf('_%s_fasta_fh', $type);
    while ( my $line = $fasta_fh->getline ) {
        $self->{$fasta_fh_key}->print($line);
    }
    $self->{$fasta_fh_key}->print("\n");

    #QUAL
    my $qual_file = sprintf('%s.qual', $fasta_file);
    $self->fatal_msg(
        sprintf('No contigs qual file (%s) for subclone (%s)', $qual_file, $subclone)
    ) unless -e $qual_file;
    my $qual_fh = IO::File->new("< $qual_file")
        or $self->fatal_msg("Can't open file ($qual_file) for reading");
    my $qual_fh_key = sprintf('_%s_qual_fh', $type);
    while ( my $line = $qual_fh->getline ) {
        $self->{$qual_fh_key}->print($line);
    }
    $self->{$qual_fh_key}->print("\n");

    return 1;
}

1;

=pod

=head1 Disclaimer

Copyright (C) 2007 Washington University Genome Sequencing Center

This script is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

=head1 Author(s)

B<Eddie Belter> <ebelter@watson.wustl.edu>

=cut

#$HeadURL$
#$Id$
