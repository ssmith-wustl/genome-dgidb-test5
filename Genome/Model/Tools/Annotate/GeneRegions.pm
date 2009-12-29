package Genome::Model::Tools::Annotate::GeneRegions;

use strict;
use warnings;
use Genome;

class Genome::Model::Tools::Annotate::GeneRegions {
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
	list => {
	    type  =>  'String',
	    doc   =>  "input list tab/space delimited with chromosome ie {1,2,...,22,X,Y,M}, Start coordinate, Stop coordinate",
	},
    ], 
};


sub help_synopsis {
    return <<EOS

gmt annotate gene-region -h

EOS
}

sub help_detail {
    return <<EOS 

will get find all genes and transripts along with region types that intersect your list
EOS
}

sub execute {

    my $self = shift;

    my $organism = $self->organism;
    my $version = $self->version;
    unless ($version) {	
	if ($organism eq "mouse") {
	    $version = "54_37g" ;
	} elsif ($organism eq "human") { 
	    $version = "54_36p" ;
	} else { 
	    die "organism is restricted to mouse or human\n";
	}
    }
    my $output = $self->output;
    
    my $list;
    my $targets;
    my $file = $self->list;
    
    unless (-f $file) {system qq(gmt annotate gene-regions --help);print qq(Your list was not found.\t\n\tPlease check that your list is in place and try again.\n\n\n);return 0;}
    open(LIST,"$file") || die "\nCould not open $file\n";
    while (<LIST>) {
	chomp;
	my $line = $_;
	my ($chr,$start,$stop) = split(/[\s]+/,$line);

	my $target = "$chr:$start:$stop";
	$targets->{$target}->{id}=1;

	unless ($chr =~ /^(1|2|3|4|5|6|7|8|9|10|11|12|13|14|15|16|17|18|19|20|21|22|X|Y|M)$/ && $start =~ /^[\d]+$/ && $stop =~ /^[\d]+$/) {print qq($line does not represent valid coordinates\n);}
	next unless $chr =~ /^(1|2|3|4|5|6|7|8|9|10|11|12|13|14|15|16|17|18|19|20|21|22|X|Y|M)$/ && $start =~ /^[\d]+$/ && $stop =~ /^[\d]+$/;

	for my $n ($start..$stop) {
	    my $p1 = $list->{$chr}->{$n};
	    if ($p1) {
		unless ($p1 =~ /$target/) {
		    $list->{$chr}->{$n}="$p1\|\|$target";
		}
	    } else {
		$list->{$chr}->{$n}="$target";
	    }
	}
    } close(LIST);
    
    my ($ncbi_reference) = $version =~ /\_([\d]+)/;
    my $eianame = "NCBI-" . $organism . ".ensembl";
    my $gianame = "NCBI-" . $organism . ".genbank";
    my $build_source = "$organism build $ncbi_reference version $version";
    
    my $ensembl_build = Genome::Model::ImportedAnnotation->get(name => $eianame)->build_by_version($version);
    unless ($ensembl_build) { die qq(Couldn't get ensembl build info for $build_source\n);}
    
    my $ensembl_data_directory = $ensembl_build->annotation_data_directory;
    
    my $genbank_build = Genome::Model::ImportedAnnotation->get(name => $gianame)->build_by_version($version);
    my $genbank_data_directory = $genbank_build->annotation_data_directory;
    
    my (@et) = Genome::Transcript->get(data_directory => $ensembl_data_directory);
    my (@gt) = Genome::Transcript->get(data_directory => $genbank_data_directory);
    
    my @join_array = (@et,@gt);
    
    my $transcript_number = 0;
    
    for my $t (@join_array) {
	
	my $chrom_name = $t->chrom_name;
	next unless $list->{$chrom_name};
	
	my $g_id = $t->gene_id;
	my @gid = split(/[\s]+/,$g_id);
	my ($gene_id) = $gid[0];
	
	my $source = $t->source;
	my $transcript_status = $t->transcript_status;
	my $strand = $t->strand;
	my $transcript_name = $t->transcript_name;
	my $transcript_id = $t->transcript_id;
	my $transcript_start = $t->transcript_start;
	my $transcript_stop = $t->transcript_stop;
	
	for my $n ($transcript_start..$transcript_stop) {
	    
	    my $target_region = $list->{$chrom_name}->{$n};

	    if ($target_region) {
		
		my $gene = $t->gene;
		my $hugo_gene_name = $gene->hugo_gene_name;
		unless ($hugo_gene_name) {$hugo_gene_name = "unknown";}
		my @substructures = $t->ordered_sub_structures;
		my $total_substructures = @substructures;
		my $t_n = 0; #substructure counter
		$transcript_number++;
		my $n_ss = $total_substructures - 2;#subtracting out the flanking regions
		
		my $ss_n = 0;
		if (@substructures) {
		    
		    while ($t_n < $total_substructures) {
			my $t_region = $substructures[$t_n];
			$t_n++;
			
			my $structure_type = $t_region->{structure_type};
			unless ($structure_type eq "flank") {
			    $ss_n++;
			    my $tr_start = $t_region->{structure_start};
			    my $tr_stop = $t_region->{structure_stop};
			    
			    for my $sn ($tr_start..$tr_stop) {
				my $targeted = $list->{$chrom_name}->{$sn};
				next unless $targeted;

				my @targeteds = split(/\|\|/,$targeted);
				for my $target (@targeteds) {
				    
				    if ($target) {

					my $i1 = $targets->{$target}->{hugo_gene_name};
					my $i2 = $targets->{$target}->{transcript_name};
					my $i3 = $targets->{$target}->{structure_type};
					
					if ($i1 && $i2 && $i3) {
					    unless ($i1 =~ /$hugo_gene_name/) {$targets->{$target}->{hugo_gene_name}="$i1,$hugo_gene_name";}
					    unless ($i2 =~/$transcript_name/) {$targets->{$target}->{transcript_name}="$i2,$transcript_name";}
					    unless ($i3 =~ /$structure_type/) {$targets->{$target}->{structure_type}="$i3,$structure_type";}
					} else {
					    $targets->{$target}->{hugo_gene_name} = $hugo_gene_name;
					    $targets->{$target}->{transcript_name} = $transcript_name;
					    $targets->{$target}->{structure_type} = $structure_type;
					}
				    }
				}
			    }
			}
		    }
		}
	    }
	}
    }
    
    if ($output) {open(COV,">$output") || die "couldn't open the output file $output\n";}

    foreach my $target (sort keys %{$targets}) {
	#unless ($bases_covered) {$bases_covered = 0;}
	my $i1 = $targets->{$target}->{hugo_gene_name};
	my $i2 = $targets->{$target}->{transcript_name};
	my $i3 = $targets->{$target}->{structure_type};
	
	unless ($i1) {$i1 = "not_found";}
	unless ($i2) {$i2 = "not_found";}
	unless ($i3) {$i3 = "not_found";}
	
	my ($chr,$start,$stop) = split(/\:/,$target);
	if ($output) {print COV qq($chr\t$start\t$stop\t$i1\t$i2\t$i3\n);}else{print qq($chr\t$start\t$stop\t$i1\t$i2\t$i3\n);}
    }
    if ($output) {close (COV);print qq(see your results in $output\n);}
}

1;
