package Genome::Model::Tools::Dgidb::Import::PubChem;

use strict;
use warnings;

use Genome;

my $high = 750000;
UR::Context->object_cache_size_highwater($high);

class Genome::Model::Tools::Dgidb::Import::PubChem {
    is => 'Genome::Model::Tools::Dgidb::Import::Base',
    has => [
        
    ],
    doc => '',
};


sub _doc_copyright_years {
    (2011);
}

sub _doc_license {
    my $self = shift;
    my (@y) = $self->_doc_copyright_years;  
    return <<EOS
Copyright (C) $y[0] Washington University in St. Louis.

It is released under the Lesser GNU Public License (LGPL) version 3.  See the 
associated LICENSE file in this distribution.
EOS
}

sub _doc_authors {
    return <<EOS
 Malachi Griffith, Ph.D.
 Jim Weible
EOS
}

=cut
sub _doc_credits {
    return ('','None at this time.');
}
=cut

sub _doc_see_also {
    return <<EOS
B<gmt>(1)
EOS
}

sub _doc_manual_body {
    my $help = shift->help_detail;
    $help =~ s/\n+$/\n/g;
    return $help;
}

sub help_synopsis {
    return <<HELP
HELP
}

sub help_detail {
#TODO: Fix this up
    my $summary = <<HELP
HELP
}

sub execute {
    my $self = shift;
    $self->input_to_tsv();
    $self->import_tsv();
    return 1;
}

sub import_tsv {
    my $self = shift;
    #TODO: write me
    return 1;
}

sub input_to_tsv {
    my $self = shift;
    #TODO: write me
    return 1;
}

1;
