package Genome::Utility::MetagenomicClassifier::PopulationComposition;

use strict;
use warnings;

use Carp 'confess';
use Data::Dumper 'Dumper';
use Regexp::Common;

sub new {
    my ($class, %params) = @_;

    my $self = bless {}, $class;

    if ( my $threshold = delete $params{confidence_threshold} ) {
        $self->_fatal_message(
            "Invalid confidence_threshold ($threshold) sent to 'new'"
        ) unless $threshold =~ /^$RE{num}{real}$/;
        $self->{confidence_threshold} = $threshold;
    }
    else {
        $self->{confidence_threshold} = 0.8;
    }

    $self->_fatal_message(
        "Unknown params sent to 'new': ".join(',', map { $_.' => '.$params{$_} } keys %params)
    ) if %params;
        
    $self->{_classifications} = [ [], [] ];
    
    # track stats?? would need to track when a classification is added, too
    
    return $self;
}

sub _fatal_message {
    my ($self, $msg) = @_;

    confess ref($self)." ERROR: $msg\n";
}
 
sub get_confidence_threshold {
    return $_[0]->{confidence_threshold};
}

sub add_classification {
    my ($self, $classification) = @_;

    my $i = ( ($classification->get_root_taxon->get_tag_values('confidence'))[0] >= $self->get_confidence_threshold ) 
    ? 1
    : 0;
    
    push @{$self->{_classifications}->[$i]}, $classification;
    
    return 1;
}

sub get_classifications {
    return map { @$_ } @{$_[0]->{_classifications}};
}

sub get_confident_classifications {
    return @{$_[0]->{_classifications}->[1]};
}

sub get_unconfident_classifications {
    return @{$_[0]->{_classifications}->[0]};
}

sub _get_genus_count_for_confident_domain {
    my ($self, $domain_name) = @_;

    my %genus_counts;
    for my $classification ( $self->get_confident_classifications ) {
        #print Dumper({ domain => [ $classification->get_domain_name_and_confidence ], genus => [ $classification->get_genus_name_and_confidence ]});
        next unless $classification->get_domain eq $domain_name;
        my ($genus, $conf) = $classification->get_genus_name_and_confidence 
                or next;
        $genus_counts{$genus}++ if $conf >= $self->get_confidence_threshold;
    }
    
    return \%genus_counts;
}

sub get_genus_count_for_confident_bacteria_domain {
    return $_[0]->_get_genus_count_for_confident_domain('Bacteria');
}

sub get_genus_count_for_confident_arch_domain {
    return $_[0]->_get_genus_count_for_confident_domain('Archaea');
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

