package Genome::Model::Command::MetaGenomicComposition::CollateFasta;

use strict;
use warnings;

use Genome;

use Data::Dumper;
#require Genome::Model::Tools::Fasta::Collate;
require IO::Dir;
require IO::File;

class Genome::Model::Command::MetaGenomicComposition::CollateFasta { 
    is => 'Genome::Model::Command',
    has => [
    map {
        $_ => {
            type => 'Boolean',
            is_optional => 1,
            default => 1,
            doc => 'assemblies',
        }
    } fasta_and_qual_types(),
    ],
};

sub help_brief {
    return '(collate ';
}

sub help_detail {
    return help_brief();
}

sub fasta_and_qual_types {
    return (qw/ assembled pre_process_input assembly_input /);
}

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_);

    unless ( $self->model ) {
        $self->error_message( sprintf('Can\'t get model for id (%s)', $self->model_id) );
        $self->delete;
        return;
    }

    return $self;
}

sub DESTROY { 
    my $self = shift;

    $self->close_output_fhs;
    $self->SUPER::DESTROY;

    return 1;
}

sub execute {
    my $self = shift;

    my $subclones = $self->model->subclones_and_traces_for_assembly
        or return;

    $self->_open_output_fhs
        or return;

    while ( my ($subclone) = each %$subclones ) {
        $self->status_message("<=== Grabbing Fasta and Qual for $subclone ===>");
        for my $type ( $self->fasta_and_qual_types ) {
            next unless $self->$type;
            my $method = sprintf('_add_%s_fasta_and_qual', $type);
            $self->$method($subclone);
        }
    }

    return $self->_close_output_fhs;
}

sub _open_output_fhs {
    my $self = shift;

    for my $type ( $self->fasta_and_qual_types ) {
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
        $self->{ sprintf('_%s_fasta_fh', $type) }->close if $self->{ sprintf('_%s_fasta_fh', $type) };
        $self->{ sprintf('_%s_qual_fh', $type) }->close if $self->{ sprintf('_%s_qual_fh', $type) };
    }

    return 1;
}

sub _add_assembled_fasta_and_qual {
    my ($self, $subclone) = @_;

    # FASTA
    my $ctgs_fasta_file = sprintf('%s/%s.fasta.contigs', $self->model->consed_directory->edit_dir, $subclone);
    unless ( -s $ctgs_fasta_file ) {
        $self->status_message("subclone ($subclone) did not assemble");
        return 1;
    }

    my $header = $self->model->header_for_subclone($subclone)
        or return;
    
    my $ctgs_fasta_fh = IO::File->new("< $ctgs_fasta_file")
        or $self->fatal_msg("Can't open file ($ctgs_fasta_file) for reading");
    my $header_cnt = 0;
    FASTA: while ( my $line = $ctgs_fasta_fh->getline ) {
        if ( $line =~ /(Contig\d+)/ ) {
            last FASTA if ++$header_cnt > 1; # skip other contigs
            $line = $header;
        }
        $self->{_assembled_fasta_fh}->print($line);
    }
    $self->{_assembled_fasta_fh}->print("\n");

    #QUAL
    my $ctgs_qual_file = sprintf('%s.qual', $ctgs_fasta_file);
    $self->fatal_msg(
        sprintf('No contigs qual file (%s) for subclone (%s)', $ctgs_qual_file, $subclone)
    ) unless -e $ctgs_qual_file;
    my $ctgs_qual_fh = IO::File->new("< $ctgs_qual_file")
        or $self->fatal_msg("Can't open file ($ctgs_qual_file) for reading");
    $header_cnt = 0;
    QUAL: while ( my $line = $ctgs_qual_fh->getline ) {
        if ( $line =~ /(Contig\d+)/ ) {
            last QUAL if ++$header_cnt > 1; # skip other contigs
            $line = $header;
        }
        $self->{_assembled_qual_fh}->print($line);
    }
    $self->{_assembled_qual_fh}->print("\n");

    return 1;
}

sub _add_pre_process_input_fasta_and_qual {
    my ($self, $subclone) = @_;

    # FASTA
    my $fasta_file = sprintf('%s/%s.fasta.pre_processing', $self->model->consed_directory->edit_dir, $subclone);
    return 1 unless -s $fasta_file;
    unless ( -s $fasta_file ) {
        $self->error_message("No pre processing file ($fasta_file) for subclone ($subclone)");
        return;
    }
    my $fasta_fh = IO::File->new($fasta_file, 'r')
        or $self->fatal_msg("Can't open file ($fasta_file) for reading");
    while ( my $line = $fasta_fh->getline ) {
        $self->{_pre_process_input_fasta_fh}->print($line);
    }
    $self->{_pre_process_input_fasta_fh}->print("\n");

    #QUAL
    my $qual_file = sprintf('%s.qual', $fasta_file);
    $self->fatal_msg(
        sprintf('No contigs qual file (%s) for subclone (%s)', $qual_file, $subclone)
    ) unless -e $qual_file;
    my $qual_fh = IO::File->new("< $qual_file")
        or $self->fatal_msg("Can't open file ($qual_file) for reading");
    while ( my $line = $qual_fh->getline ) {
        $self->{_pre_process_input_qual_fh}->print($line);
    }
    $self->{_pre_process_input_qual_fh}->print("\n");

    return 1;
}

sub _add_assembly_input_fasta_and_qual {
    my ($self, $subclone) = @_;

    # FASTA
    my $fasta_file = sprintf('%s/%s.fasta', $self->model->consed_directory->edit_dir, $subclone);
    return 1 unless -s $fasta_file;
    my $fasta_fh = IO::File->new("< $fasta_file")
        or $self->fatal_msg("Can't open file ($fasta_file) for reading");
    while ( my $line = $fasta_fh->getline ) {
        $self->{_assembly_input_fasta_fh}->print($line);
    }
    $self->{_assembly_input_fasta_fh}->print("\n");

    #QUAL
    my $qual_file = sprintf('%s.qual', $fasta_file);
    $self->fatal_msg(
        sprintf('No contigs qual file (%s) for subclone (%s)', $qual_file, $subclone)
    ) unless -e $qual_file;
    my $qual_fh = IO::File->new("< $qual_file")
        or $self->fatal_msg("Can't open file ($qual_file) for reading");
    while ( my $line = $qual_fh->getline ) {
        $self->{_assembly_input_qual_fh}->print($line);
    }
    $self->{_assembly_input_qual_fh}->print("\n");

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
