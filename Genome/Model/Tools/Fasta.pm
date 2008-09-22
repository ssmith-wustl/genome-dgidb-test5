package Genome::Model::Tools::Fasta;

use strict;
use warnings;

use Genome;

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

use Data::Dumper;

sub create { 
    my $class = shift;

    my $self = $class->SUPER::create;
    $self->{_cwd} = Cwd::getcwd();
    $self->fasta_file( Cwd::abs_path( $self->fasta_file ) );
    my ($base, $directory) = File::Basename::fileparse( $self->fasta_file );
    chdir $directory
        or ( $self->error_message("Can't access directory ($directory): $!") and return );
    $self->{_fasta_base} = $base;

    return 1;
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

sub qual_base {
    my $self = shift;

    return sprintf('%s.qual', $self->_fasta_base);
}

sub qual_file {
    my $self = shift;

    return sprintf('%s.qual', $self->fasta_file);
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

