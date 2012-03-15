package Genome::Model::Tools::Dgidb::Import::Go;

use strict;
use warnings;

use Genome;
use IO::File;
use XML::Simple;

my $high = 750000;
UR::Context->object_cache_size_highwater($high);

class Genome::Model::Tools::Dgidb::Import::Go {
    is => 'Genome::Model::Tools::Dgidb::Import::Base',
    has => {
        go_term_file => {
            is => 'Path',
            doc => '', #TODO: fill me in
        },
        tmp_dir => {
            is => 'Path',
            default => '/tmp',
            doc => '', #TODO: fill me in
        },
        genes_outfile => {
            is => 'Path',
            is_input => 1,
            default => '/tmp/GO_WashU_TARGETS.tsv',
            doc => 'PATH.  Path to .tsv file for genes (targets)',
        },
    },
    doc => 'Parse an XML database file from DrugBank',
};

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
    my $out_fh = IO::File->new($self->genes_outfile, 'w');
    my $xs = XML::Simple->new();

    my %xml_files = $self->import_go_category_xml_files;

    my $headers = join("\t", 'go_id', 'go_short_name', 'go_term', 'go_full_name', 'go_description', 'secondary_go_term', 'go_name', 'alternate_symbol_references');
    $out_fh->print($headers, "\n");

    for my $go_short_name_and_id (keys %xml_files){
        my $xml = $xs->XMLin($xml_files{$go_short_name_and_id}, KeyAttr => ['rdf:about']);
        my ($short_name, $go_id) = split("\t", $go_short_name_and_id);
        my %terms = %{$xml->{'rdf:RDF'}->{'go:term'}};
        for my $url (keys %terms){
            my $secondary_go_term;
            my @output_lines;
            if($terms{'rdf:about'}){
                $terms{'rdf:about'} =~ /.*GO:(\d+)/;
                $secondary_go_term = $1;
                @output_lines = $self->xml_term_to_output_lines(go_id => $go_id, short_name => $short_name, secondary_go_term => $secondary_go_term, term => \%terms);
            }elsif(ref($terms{$url})){
                $url =~ /.*GO:(\d+)/;
                $secondary_go_term = $1;
                @output_lines = $self->xml_term_to_output_lines(go_id => $go_id, short_name => $short_name, secondary_go_term => $secondary_go_term, term => $terms{$url});
            }
            $out_fh->print(join("\n", @output_lines), "\n") if @output_lines;
        }
    }

    $out_fh->close;
    return 1;
}

sub import_tsv {
    my $self = shift;
    my $genes_outfile = $self->genes_outfile;
    # $self->preload_objects; #TODO: Do we need these?
    my @genes = $self->import_genes($genes_outfile);
    return 1;
}

sub import_genes {
    my $self = shift;
    my $version = $self->version;
    my $genes_outfile = shift;
    my @genes;
    my @headers = qw/go_id go_short_name go_term go_full_name go_description secondary_go_term go_name alternate_symbol_references/;
    my $parser = Genome::Utility::IO::SeparatedValueReader->create(
        input => $genes_outfile,
        headers => \@headers,
        separator => "\t",
        is_regex => 1,
    );

    $parser->next; #eat the headers
    while(my $go_input = $parser->next){
        my $gene_name = $self->_create_gene_name_report($go_input->{'go_name'}, 'go_gene_name', 'GO', $version, '');
        my $alternate_symbol_references = $go_input->{'alternate_symbol_references'};
        my @alternates = split(/\|/, $alternate_symbol_references);
        for my $alternate (@alternates){
            my ($nomenclature, $identifier, $evidence_code) = split('/', $alternate);
            next unless $nomenclature;
            my $alternate_name_association = $self->_create_gene_alternate_name_report($gene_name, $identifier, $nomenclature, $evidence_code); #TODO: is pushing evidence_code into description the right thing to do
        }
        my $go_id_category = $self->_create_gene_category_report($gene_name, 'go_id', $go_input->{'go_id'}, $go_input->{'go_description'});
        my $secondary_go_term = $go_input->{'secondary_go_term'};
        if($go_input->{'go_id'} !~ /$secondary_go_term/ ){
            my $secondary_go_id_category = $self->_create_gene_category_report($gene_name, 'secondary_go_id', $secondary_go_term, '');
        }
    }

    return @genes;
}

sub xml_term_to_output_lines {
    my ($self,  %params) = @_;
    my $go_id = $params{'go_id'};
    my $short_name = $params{'short_name'};
    my $secondary_go_term = $params{'secondary_go_term'};
    my $term = $params{'term'};
    my @output_lines;

    my $go_name = $term->{'go:name'};
    my @associations = ( ref($term->{'go:association'}) eq 'ARRAY' ? @{$term->{'go:association'}} : ($term->{'go:association'}));
    my @negative_associations = ( ref($term->{'go:negative_association'}) eq 'ARRAY' ? @{$term->{'go:negative_association'}} : ($term->{'go:negative_association'})); #TODO: these should be filtered out.  Possibly counted
    my $go_accession = $term->{'go:accession'};
    my $go_definition = $term->{'go:definition'};
    if(@associations and defined($associations[0])){
        for my $association (@associations){
            my $gene_name = $association->{'go:gene_product'}->{'go:name'};
            my $alternate_symbol_references = "";
            my $evidence_ref = $association->{'go:evidence'};
            if($evidence_ref){
                if(ref($evidence_ref) eq 'HASH'){
                    $alternate_symbol_references = join("|", $alternate_symbol_references, join("/", $evidence_ref->{'go:dbxref'}->{'go:database_symbol'}, $evidence_ref->{'go:dbxref'}->{'go:reference'}, $evidence_ref->{'evidence_code'}));
                }elsif(ref($evidence_ref) eq 'ARRAY'){
                    $alternate_symbol_references = join("|", $alternate_symbol_references, map{join("/", $_->{'go:dbxref'}->{'go:database_symbol'}, $_->{'go:dbxref'}->{'go:reference'}, $_->{'evidence_code'})} @$evidence_ref);
                }
            }

            my $product_ref = $association->{'go:gene_product'}->{'go:dbxref'};
            if($product_ref){
                $alternate_symbol_references = join("|", $alternate_symbol_references, join("/", $product_ref->{'go:database_symbol'}, $product_ref->{'go:reference'}));
            }

            my $output_line = join("\t", $go_id, $short_name, $go_accession, $go_name, $go_definition, $secondary_go_term, $gene_name, $alternate_symbol_references);
            push @output_lines, $output_line;
        }
    }

    return @output_lines;
}

sub import_go_category_xml_files {
    my $self = shift;
    my $go_term_file = $self->go_term_file;
    my $tmp_dir = $self->tmp_dir;

    unless(-e $tmp_dir and -d $tmp_dir){
        $self->error_message("$tmp_dir does not exist");
        return;
    }

    #Import the target GO names and GO term IDs
    my %go_terms;
    my $go_fh = IO::File->new($go_term_file, 'r');
    unless($go_fh){
        $self->error_message("Could not open input file: $go_term_file");
        return;
    }
    my $header = 1;
    while(my $line = <$go_fh>){
        chomp($line);
        my @line_parts= split("\t", $line);
        if ($header == 1){
            $header = 0;
            next();
        }
        my $go_id = $line_parts[2];
        $go_terms{$go_id}{short_name} = $line_parts[0];
        $go_terms{$go_id}{long_name} = $line_parts[1];

        my $go_digits;
        if ($go_id =~ /GO(\d+)/){
            $go_digits = $1;
        }else{
            $self->error_message("Could not extract GO digits from go ID: $go_id");
            return;
        }
        $go_terms{$go_id}{go_digits} = $go_digits;
    }
    $go_fh->close;

    # my %tsv_files;
    my %xml_files;

    foreach my $go_id (sort keys %go_terms){
        print "Retrieving $go_id files";
        my $go_digits = $go_terms{$go_id}{go_digits};
        my $short_name_and_id = join("\t", $go_terms{$go_id}{short_name}, $go_id);

#Get XML file
#wget "http://amigo.geneontology.org/cgi-bin/amigo/term-assoc.cgi?gptype=all&speciesdb=all&taxid=9606&evcode=all&term_assocs=all&term=GO%3A0016301&action=filter&format=rdfxml" -O KinaseActivity_GO0016301.xml
        my $go_outfile_xml = $go_terms{$go_id}{short_name} . "_" . $go_id . ".xml";
        my $wget_cmd_xml = "wget \"http://amigo.geneontology.org/cgi-bin/amigo/term-assoc.cgi?gptype=all&speciesdb=all&taxid=9606&evcode=all&term_assocs=all&term=GO%3A$go_digits&action=filter&format=rdfxml\" -O $tmp_dir/$go_outfile_xml";
        system($wget_cmd_xml);
        $xml_files{$short_name_and_id} = "$tmp_dir/$go_outfile_xml";
    }
    
    return %xml_files;
}

1;
