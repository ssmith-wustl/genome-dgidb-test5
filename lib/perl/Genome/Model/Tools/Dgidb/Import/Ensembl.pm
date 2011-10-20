package Genome::Model::Tools::Dgidb::Import::Ensembl;

use strict;
use warnings;

use Genome;

my $high = 750000;
UR::Context->object_cache_size_highwater($high);

class Genome::Model::Tools::Dgidb::Import::Ensembl {
    is => 'Genome::Model::Tools::Dgidb::Import::Base',
    has => [
        genes_outfile => {
            is => 'Path',
            is_input => 1,
            default => '/tmp/Ensembl_WashU_TARGETS.tsv',
            doc => 'PATH.  Path to .tsv file for genes (targets)',
        },
    ],
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
gmt dgidb import ensembl --version 3
HELP
}

sub help_detail {
#TODO: make this accurate
    my $summary = <<HELP
WRITE ME
HELP
}

sub execute {
    my $self = shift;
    $self->input_to_tsv();
    $self->import_tsv();
    return 1;
}

sub input_to_tsv {
    my $self = shift;
    my $genes_outfile_path = $self->genes_outfile;  
    #TODO: Take in the input ensembl file, make a tsv file at $genes_outfile_path  
}

sub import_tsv {
    my $self = shift;
    my $genes_outfile_path = $self->genes_outfile;
    #TODO: Take in the $genes_outfile_path, parse it, make the db objects;
}

1;
