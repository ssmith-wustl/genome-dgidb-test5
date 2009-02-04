package Genome::Utility::MetagenomicClassifier::SequenceClassification;

use strict;
use warnings;

use Carp 'confess';
use Data::Dumper 'Dumper';

sub new {
    my ($class, %params) = @_;

    my $self =  bless \%params, $class;

    for my $req (qw/ name classifier taxon /) {
        _fatal_message("Required parameter ($req) not found.") unless $params{$req};
    }

    $self->{complemented} = 0 unless $self->{complemented};

    return $self;
}

sub _fatal_message {
    my ($msg) = @_;

    confess __PACKAGE__." ERROR: $msg\n";
}
 
#< NAME >#
sub get_name {
    return $_[0]->{name};
}

#< COMPLEMENTED >#
sub get_complemented { 
    return $_[0]->{complemented};
}

sub is_complemented { 
    return $_[0]->{complemented};
}

#< CLASSIFIER TYPE >#
sub get_classifier {
    return $_[0]->{classifier};
}

#< TAXON >#
sub get_taxon {
    return $_[0]->{taxon};
}

sub get_taxa {
    my $self = shift;

    my @taxa;
    unless ( $self->{taxa} ) {
        my $taxon = $self->get_taxon;
        do { 
            push @taxa, $taxon;
            ($taxon) = $taxon->get_Descendents;
        } until not defined $taxon;
        $self->{taxa} = \@taxa;
    }

    return @{$self->{taxa}};
}

sub taxa_count { 
    return scalar($_[0]->get_taxa);
}

sub _get_taxon_for_rank {
    return (grep { $_->rank eq $_[1] } $_[0]->get_taxa)[0];
}

sub _get_taxon_name_for_rank {
    my $taxon = $_[0]->_get_taxon_for_rank($_[1])
        or return 'none';
    return $taxon->id;
}

sub get_root_taxon {
    return $_[0]->_get_taxon_for_rank('root');
}

sub get_root {
    return $_[0]->_get_taxon_name_for_rank('root');
}

sub get_domain_taxon {
    return $_[0]->_get_taxon_for_rank('domain');
}

sub get_domain {
    return $_[0]->_get_taxon_name_for_rank('domain');
}

sub get_kingdom_taxon {
    return $_[0]->_get_taxon_for_rank('kingdom');
}

sub get_kingdom {
    return $_[0]->_get_taxon_name_for_rank('kingdom');
}

sub get_phylum_taxon {
    return $_[0]->_get_taxon_for_rank('phylum');
}

sub get_phylum {
    return $_[0]->_get_taxon_name_for_rank('phylum');
}

sub get_class_taxon {
    return $_[0]->_get_taxon_for_rank('class');
}

sub get_class {
    return $_[0]->_get_taxon_name_for_rank('class');
}

sub get_order_taxon {
    return $_[0]->_get_taxon_for_rank('order');
}

sub get_order {
    return $_[0]->_get_taxon_name_for_rank('order');
}

sub get_family_taxon {
    return $_[0]->_get_taxon_for_rank('family');
}

sub get_family {
    return $_[0]->_get_taxon_name_for_rank('family');
}

sub get_genus_taxon {
    return $_[0]->_get_taxon_for_rank('genus');
}

sub get_genus {
    return $_[0]->_get_taxon_name_for_rank('genus');
}

sub get_species_taxon {
    return $_[0]->_get_taxon_for_rank('species');
}

sub get_species {
    return $_[0]->_get_taxon_name_for_rank('species');
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

