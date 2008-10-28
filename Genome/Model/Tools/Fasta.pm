package Genome::Model::Tools::Fasta;

use strict;
use warnings;

use Genome;
use Data::Dumper;
use Bio::Seq;

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
    return "Tools for working with FASTA and Qual files"
}

sub help_detail {
    return help_brief();
}

sub create { 
    my $class = shift;

    my $self = $class->SUPER::create(@_);
    $self->{_cwd} = Cwd::getcwd();
    $self->fasta_file( Cwd::abs_path( $self->fasta_file ) );

    my ($basename, $directory, $suffix) = File::Basename::fileparse($self->fasta_file, '.fasta');
    unless ( $suffix ) {
        $self->error_message( sprintf('FASTA file (%s) needs to have a ".fasta" suffix.', $self->fasta_file) );
        return;
    }

    chdir $directory
        or ( $self->error_message("Can't access directory ($directory): $!") and return );

    $self->{_fasta_basename} = $basename;

    return $self;
}

sub DESTROY {
    my $self = shift;

    chdir $self->_cwd;
    
    return 1;
}

sub _cwd {
    return $_[0]->{_cwd};
}

#< FASTA base #>
sub _fasta_basename {
    return $_[0]->{_fasta_basename};
}

sub fasta_base {
    return sprintf('%s.fasta', $_[0]->{_fasta_basename});
}

#< Qual file >#
sub qual_base {
    return sprintf('%s.qual', $_[0]->fasta_base);
}

sub qual_file {
    return sprintf('%s/%s', $_[0]->{_cwd}, $_[0]->qual_base);
}

sub have_qual_file {
    return -s $_[0]->qual_file;
}

#< New file names >#
sub fasta_file_with_new_suffix { 
    my ($self, $ext) = @_;

    return sprintf('%s.%s.fasta', $self->{_fasta_basename}, $ext);
}

sub qual_file_with_new_suffix {
    my ($self, $ext) = @_;

    return sprintf('%s.qual', $self->fasta_file_with_new_suffix($ext));
}

#< Back Up >#
sub default_back_up_suffix {
    return 'bak';
}

sub fasta_back_up_file {
    my ($self, $ext) = @_;

    return $self->fasta_file_with_new_suffix( defined $ext ? $ext : $self->default_back_up_suffix );
}

sub qual_back_up_file {
    my ($self, $ext) = @_;

    return $self->qual_file_with_new_suffix( defined $ext ? $ext : $self->default_back_up_suffix );
}

sub back_up_fasta_and_qual_files {
    my ($self, $ext) = @_;

    $ext = $self->default_back_up_suffix unless defined $ext;

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

