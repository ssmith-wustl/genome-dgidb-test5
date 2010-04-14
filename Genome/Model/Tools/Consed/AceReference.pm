package Genome::Model::Tools::Consed::AceReference;

use strict;
use warnings;
use Genome;

class Genome::Model::Tools::Consed::AceReference {
    is => 'Command',                       
    has => [ 
	ace_file => {
            type  =>  'String',
            doc  => "manditory; ace file name",
	},

	name_and_number => {
            type  =>  'Boolean',
            doc  => "gets the name and number of the contig with your reference sequence in it; reference defined by a read ending in .c1",
  	    is_optional  => 1,
	},
	], 
};

sub help_brief {                            

"A tool to get info about your reference contig"

}

sub help_synopsis { 

    return <<EOS

	gmt consed ace-reference -h

EOS
}
sub help_detail {
    return 'This tool was designed to get information about ace files that were assembled by aligning reads under a reference sequence "a fake trace ending .c1 derived from a slice out of a reference geneome"';
}


sub execute {

    my $self = shift;

    my $ace_reference;
    if ($self->name_and_number) {

	($ace_reference) = &name_and_number($self,$ace_reference);
	my $Contig_number = $ace_reference->{Contig_number};
	my $reseqid = $ace_reference->{reseqid};

	print qq(Contig_number => $Contig_number, Refseq_id => $reseqid\n);

    }

    return unless $ace_reference;
    return $ace_reference;

}


sub name_and_number {

    use Genome::Assembly::Pcap::Ace;

    my ($self,$ace_reference) = @_;
    
    my $ace_file = $self->ace_file;
    unless (-f $ace_file) {$self->error_message("could see the ace file");return;}
    my $ao = new Genome::Assembly::Pcap::Ace(input_file => $ace_file);
    
    my $ace_ref;
    my @number;
    my @name;
    
    foreach my $contig_number (@{ $ao->get_contig_names }) {
	my $contig = $ao->get_contig($contig_number);
	
	if (grep { /\.c1$/ } keys %{ $contig->reads }) {
	    push(@number,$contig_number);
	}
	
	foreach my $read_name (keys %{ $contig->reads }) {
	    if ($read_name =~ /(\S+\.c1)$/) {
		push(@name,$read_name);
	    }
	}
    }

    unless (@name && @number) {$self->error_message("couldn't find the contig name and number");return;}

    if (@name > 1) {$self->error_message("there is more than one reference sequence in your assembly");}
    if (@number > 1) {$self->error_message("there is more than one contig with a reference sequence in your assembly");}
    
    my $name = join 'name' , @name;
    my $number = join 'number' , @number;
    
    $ace_reference->{Contig_number}=$number;
    $ace_reference->{reseqid}=$name;

    return ($ace_reference);

}

1;
