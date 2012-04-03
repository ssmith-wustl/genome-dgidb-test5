package Genome::Model::Tools::Dgidb::Import::PubChem;

use strict;
use warnings;

use Genome;

my $high = 750000;
UR::Context->object_cache_size_highwater($high);

class Genome::Model::Tools::Dgidb::Import::PubChem {
    is => 'Genome::Model::Tools::Dgidb::Import::Base',
    has => [
        download_url => {
            is => 'URL',
            default => 'ftp://ftp.ncbi.nlm.nih.gov/pubchem/Compound/Extras/CID-Synonym-filtered.gz',
            doc => 'Location of a 2 columns flat file.  First column is a PubChem CID, the second is a single drug name.  Sorted by CID, then popularity of the single drug name',
        },
        tmp_dir => {
            is => 'Path',
            default => '/tmp',
            doc => 'Directory where the pubchem flatfile will be downloaded',
        },
        drugs_outfile => {
            is => 'Path',
            is_input => 1,
            default => '/tmp/PubChem_WashU_DRUGS.tsv',
            doc => 'PATH.  Path to .tsv file for drugs',
        },
    ],
    doc => 'Download and parse a PubChem flatfile',
};


sub _doc_copyright_years {
    (2012);
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

sub input_to_tsv {
    my $self = shift;
    my $download_url = $self->download_url;
    my $drugs_outfile = $self->drugs_outfile;
    my $wget_cmd = "wget $download_url -O $drugs_outfile.gz";
    system($wget_cmd);
    system("gunzip $drugs_outfile.gz");
    return 1;
}

sub import_tsv {
    my $self = shift;
    my $version = $self->version;
    my $drugs_outfile = $self->drugs_outfile;
    my @headers = qw/ cid name /;
    my $parser = Genome::Utility::IO::SeparatedValueReader->create(
        input => $drugs_outfile,
        headers => \@headers,
        separator => "\t",
        is_regex => 1,
    );

    my $last_cid = "-1";
    my $last_drug;
    my @drugs;

    while(my $pubchem = $parser->next) {
        my $cid = $pubchem->{'cid'};
        my $name = $pubchem->{'name'};
        if ($cid == $last_cid){
            #alternate_name
            my $alternate_name = $self->_create_drug_alternate_name_report($last_drug, $name, 'pubchem_alternate_name', '');
        }else{
            #new drug, make it so
            my $drug = $self->_create_drug_name_report($name, 'pubchem_primary_name', 'pubchem', $version, '');
            push @drugs, $drug;
            $last_drug = $drug;
            $last_cid = $cid;
        }
    }

    return @drugs;
}

1;
