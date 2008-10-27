package Genome::Model::Tools::Fasta;

use strict;
use warnings;

use Genome;
use Data::Dumper;

class Genome::Model::Tools::Fasta {
    is => 'Command',
    has => [
        fasta_file => {
            type => 'String',
            is_optional => 0,
            doc => 'FASTA file. Quality file (if appropriate) will be named <fasta_file>\'.qual\'',
        },
    ],
};

sub help_brief {
    "tools for working with FASTA files"
}

sub help_detail {
    "Tools to work with fasta format sequence files";
}

sub create { 
    my $class = shift;

    my $self = $class->SUPER::create(@_);
    $self->{_cwd} = Cwd::getcwd();
    $self->fasta_file( Cwd::abs_path( $self->fasta_file ) );
    my ($base, $directory) = File::Basename::fileparse( $self->fasta_file );
    chdir $directory
        or ( $self->error_message("Can't access directory ($directory): $!") and return );
    $self->{_fasta_base} = $base;

    return $self;
}

sub DESTROY {
    my $self = shift;

    chdir $self->_cwd;
    
    return 1;
}

sub _cwd {
    return shift->{_cwd};
}

sub _fasta_base {
    return shift->{_fasta_base};
}

sub fasta_file_with_new_extension { # Silly, but it mirrors the qual method below
    my ($self, $ext) = @_;

    return sprintf('%s.%s', $self->fasta_file, $ext);
}

sub qual_base {
    my $self = shift;

    return sprintf('%s.qual', $self->_fasta_base);
}

sub qual_file {
    my $self = shift;

    return sprintf('%s.qual', $self->fasta_file);
}

sub have_qual_file {
    my $self = shift;

    return -e $self->qual_file;
}

sub qual_file_with_new_extension {
    my ($self, $ext) = @_;

    return sprintf('%s.qual.%s', $self->fasta_file, $ext);
}

#< Back Up >#
sub default_back_up_extension {
    return 'bak';
}

sub fasta_back_up_file {
    my ($self, $ext) = @_;

    return sprintf(
        '%s.%s', 
        $self->fasta_file,
        ( defined $ext ? $ext : $self->default_back_up_extension ),
    );
}

sub qual_back_up_file {
    my ($self, $ext) = @_;

    return sprintf(
        '%s.qual.%s',
        $self->fasta_file, 
        ( defined $ext ? $ext : $self->default_back_up_extension ),
    );
}

sub back_up_fasta_and_qual_files {
    my ($self, $ext) = @_;

    $ext = $self->default_back_up_extension unless defined $ext;

    my $fasta_bak = $self->back_up_fasta_file($ext)
        or return;

    my $qual_bak = $self->back_up_qual_file($ext)
        or return;

    return ( $fasta_bak, $qual_bak );
}

sub back_up_fasta_file {
    my ($self, $ext) = @_;

    my $fasta_bak = $self->fasta_back_up_file($ext);
    unlink $fasta_bak if -e $fasta_bak;

    unless ( File::Copy::copy($self->fasta_file, $fasta_bak) ) {
        $self->error_message( sprintf('Can\'t copy %s to %s', $self->fasta_file, $fasta_bak) );
        return;
    }

    return $fasta_bak;
}

sub back_up_qual_file {
    my ($self, $ext) = @_;

    my $qual_bak = $self->qual_back_up_file($ext);
    unlink $qual_bak if -e $qual_bak;

    unless ( File::Copy::copy($self->qual_file, $qual_bak) ) {
        $self->error_message( sprintf('Can\'t copy %s to %s', $self->qual_file, $qual_bak) );
        return;
    }

    return $qual_bak;
}

#< Bio::SeqIO stuff >#
sub get_fasta_reader {
    return _get_bioseq_reader(@_, 'Fasta');
}

sub get_qual_reader {
    return _get_bioseq_reader(@_, 'qual');
}

sub _get_bioseq_reader {
    return _get_bioseq(@_, '<');
}

sub get_fasta_writer {
    return _get_bioseq_writer(@_, 'Fasta');
}

sub get_qual_writer {
    return _get_bioseq_writer(@_, 'qual');
}

sub _get_bioseq_writer {
    return _get_bioseq(@_, '>');
}

sub _get_bioseq {
    my ($self, $file, $format, $rw) = @_;

    # TODO error check
    
    return Bio::SeqIO->new(
        '-file' => $rw.' '.$file,
        '-format' => $format,
    );
}


1;

=pod

=head1 Name

ModuleTemplate

=head1 Synopsis

=head1 Usage

=head1 Methods

=head2 

=over

=item I<Synopsis>

=item I<Arguments>

=item I<Returns>

=back

=head1 See Also

=head1 Disclaimer

Copyright (C) 2005 - 2008 Washington University Genome Sequencing Center

This module is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

=head1 Author(s)

B<Eddie Belter> I<ebelter@watson.wustl.edu>

=cut

#$HeadURL$
#$Id$

