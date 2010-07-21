package Genome::Model::Tools::Fasta::Trim::LucyTest;

use strict;
use warnings;

use base 'Genome::Utility::TestBase';

use File::Compare 'compare';
use Test::More;

sub lucy {
    return $_[0]->{_object};
}

sub test_class {
    return 'Genome::Model::Tools::Fasta::Trim::Lucy';
}

sub params_for_test_class {
    my $self = shift;
    return (
        vector_name => 'pCR4-TOPO',
        fasta_file => $self->fasta_file,
        output_fasta_file => $self->tmp_dir.'/lucy.fasta',
    );
}

sub required_attrs {
    return (qw/ vector_name fasta_file /);
}

sub fasta_file {
    return $_[0]->dir.'/H_KM-aab04h11.reads.fasta';
}

sub vector_fasta_file {
    return $_[0]->dir.'/pCR4-TOPO.fasta';
}

sub flanking_fasta_file {
    return $_[0]->dir.'/pCR4-TOPO.flanking.fasta';
}

sub test01_execute : Tests {
    my $self = shift;

    my $lucy = $self->lucy;

    # execute
    ok($lucy->execute, 'Executed lucy');

    # vector files
    diag( $self->vector_fasta_file.' => '.$lucy->vector_fasta_file );
    is( compare($self->vector_fasta_file, $lucy->vector_fasta_file), 0, 'Vector fasta file matches');
    diag( $self->flanking_fasta_file.' => '.$lucy->flanking_fasta_file );
    is( compare($self->flanking_fasta_file, $lucy->flanking_fasta_file), 0, 'Flanking fasta file matches');
    
    #print 'lucy => '.$lucy->_tmpdir,"\n".'fasta => '.$self->tmp_dir,"\n"; <STDIN>;

    return 1;
}

#####################################################################

package Genome::Model::Tools::Fasta::Trim::LucyReaderTest;

use strict;
use warnings;

use base 'Genome::Utility::TestBase';

use Data::Dumper 'Dumper';
use Test::More;

sub test_class {
    return 'Genome::Model::Tools::Fasta::Trim::LucyReader';
}

sub test_class_sub_dir {
    return 'Genome-Model-Tools-Fasta-Trim-Lucy';
}
    
sub params_for_test_class {
    return (
        input => $_[0]->lucy_file,
    );
}

sub lucy_file {
        return $_[0]->dir.'/reader.debug.txt',
}

sub lucies_file {
        return $_[0]->dir.'/reader.lucies.stor',
}

sub test01_read_and_verify : Tests {
    my $self = shift;

    my @lucies = $self->{_object}->all;
    #print Dumper(\@lucies);
    #unlink $self->lucies_file; $self->store_file(\@lucies, $self->lucies_file);
    my $stored_lucies = $self->retrieve_file($self->lucies_file);
    is_deeply(\@lucies, $stored_lucies, 'Generated and stored lucies match');
    
    return 1;
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

