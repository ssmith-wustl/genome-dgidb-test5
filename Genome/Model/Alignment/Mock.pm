
package Genome::Model::Alignment::Mock;
use base 'Genome::Model::Alignment';

use warnings;
use strict;

sub new{
    my ($pkg, %params) = @_;
    
    die "You must pass in a read_bases_probability_vectors and a mismatch_code to use this Mock!"
        unless( defined($params{read_bases_probability_vectors}) && defined($params{mismatch_code}) );
    
    $pkg->SUPER::new(%params, reads_fh => '');
}

sub decode_match_string{
    return ('','');
}

sub get_current_mismatch_code{
    return shift->{mismatch_code};
}

1;