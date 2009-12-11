package Genome::Model::Tools::Annotate::TranscriptRegions;

use strict;
use warnings;
use Genome;

class Genome::Model::Tools::Annotate::TranscriptRegions {
    is => 'Command',                       
    has => [ 
	organism => {
	    type  =>  'String',
	    doc   =>  "provide the organism either mouse or human; default is human",
	    is_optional  => 1,
	    default => 'human',
	},
	version => {
	    type  =>  'String',
	    doc   =>  "provide the imported annotation version; default for human is 54_36p and for mouse is 54_37g",
	    is_optional  => 1,
	},
	   output => {
	    type  =>  'String',
	    doc   =>  "provide a file name to write you transcript information to .txt will be appended to it. Default is to print to stdout.",
	    is_optional  => 1,
	},
	chromosome => {
	    type  =>  'String',
	    doc   =>  "chromosome ie {1,2,...,22,X,Y,M}",
	},
	start => {
	    type  =>  'Number',
	    doc   =>  "Start coordinate",
	},
	stop => {
	    type  =>  'Number',
	    doc   =>  "Stop coordinate;",
	},
    ], 
};


sub help_synopsis {
    return <<EOS

gmt annotate transcript-region -h

EOS
}

sub help_detail {
    return <<EOS 

will provide the transcript substructures in your range of specified coordinates from both the ensembl and genbank annotation.

EOS
}


sub execute {

    my $self = shift;

    my $chromosome = $self->chromosome;
    my $start = $self->start;
    my $stop = $self->stop;
    my $organism = $self->organism;
    my $version = $self->version;

    unless ($version) {	if ($organism eq "mouse") { $version = "54_37g" ; } elsif ($organism eq "human") { $version = "54_36p" ; } }
    else { die "organism is restricted to mouse or human\n"; }

    my $output = $self->output;

    my ($ncbi_reference) = $version =~ /\_([\d]+)/;
    my $eianame = "NCBI-" . $organism . ".ensembl";
    my $gianame = "NCBI-" . $organism . ".genbank";
    my $build_source = "$organism build $ncbi_reference version $version";
    
    my $ensembl_build = Genome::Model::ImportedAnnotation->get(name => $eianame)->build_by_version($version);
    my $ensembl_data_directory = $ensembl_build->annotation_data_directory;
    
    my $genbank_build = Genome::Model::ImportedAnnotation->get(name => $gianame)->build_by_version($version);
    my $genbank_data_directory = $genbank_build->annotation_data_directory;
    
    my (@et) = Genome::Transcript->get(data_directory => $ensembl_data_directory);
    my (@gt) = Genome::Transcript->get(data_directory => $genbank_data_directory);
    
    my @join_array = (@et,@gt);
    

    if ($output) {
	open(OUT,">$output") || die "couldn't open the output file $output\n";
        print OUT qq(chromosome,tr_start,tr_stop,source,organism,version,hugo_gene_name,gene_id,strand,transcript_name,transcript_status,structure_type\n);
    }
    print qq(chromosome,tr_start,tr_stop,source,organism,version,hugo_gene_name,gene_id,strand,transcript_name,transcript_status,structure_type\n);
    
    for my $t (@join_array) {
	
	my $chrom_name = $t->chrom_name;
	
	next unless $chromosome eq $chrom_name;
	
	my $g_id = $t->gene_id;
	my @gid = split(/[\s]+/,$g_id);
	my ($gene_id) = $gid[0];
	
	my $source = $t->source;
	my $transcript_status = $t->transcript_status;
	my $strand = $t->strand;
	my $transcript_name = $t->transcript_name;
	my $transcrpt_id = $t->transcript_id;
	my $transcript_start = $t->transcript_start;
	my $transcript_stop = $t->transcript_stop;
	
	next unless $transcript_start >= $start && $transcript_start <= $stop ||
	    $transcript_start <= $start && $transcript_start >= $stop ||
	    $transcript_stop <= $start && $transcript_stop >= $stop ||
	    $transcript_stop <= $start && $transcript_stop >= $stop;
	
	
	my $gene = $t->gene;
	my $hugo_gene_name = $gene->hugo_gene_name;
	unless ($hugo_gene_name) {$hugo_gene_name = "unknown";}
	my @substructures = $t->ordered_sub_structures;
	my $total_substructures = @substructures;
	my $t_n = 0; #substructure counter
	
	if (@substructures) {
	    
	    while ($t_n < $total_substructures) {
		my $t_region = $substructures[$t_n];
		$t_n++;
		
		my $tr_start = $t_region->{structure_start};
		my $tr_stop = $t_region->{structure_stop};
		
		
		next unless $tr_start >= $start && $tr_start <= $stop ||
		    $tr_start <= $start && $tr_start >= $stop ||
		    $tr_stop <= $start && $tr_stop >= $stop ||
		    $tr_stop <= $start && $tr_stop >= $stop;
		
		my $range = "$tr_start\-$tr_stop";
		my $structure_type = $t_region->{structure_type};
		#unless ($structure_type eq "intron" || $structure_type eq "flank") {

		if ($output) {
		    print OUT qq($chromosome,$tr_start,$tr_stop,$source,$organism,$version,$hugo_gene_name,$gene_id,$strand,$transcript_name,$transcript_status,$structure_type\n);
		}
		print qq($chromosome,$tr_start,$tr_stop,$source,$organism,$version,$hugo_gene_name,$gene_id,$strand,$transcript_name,$transcript_status,$structure_type\n);
		
	    }
	}
    }
}
