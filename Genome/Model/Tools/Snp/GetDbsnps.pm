package Genome::Model::Tools::Snp::GetDbsnps;

use strict;
use warnings;
use Genome;

class Genome::Model::Tools::Snp::GetDbsnps {
    is => 'Command',                    
    has => [ # specify the command's properties (parameters) <--- 
	     

	     out => {
		 type  =>  'String',
		 doc   =>  "provide a name for your output file or it will simply be printed as stdout",
		 is_optional  => 1,
	     },

	     chromosome => {
		 type  =>  'String',
		 doc   =>  "chromosome ie {1,2,...,22,X,Y,M}",
		 is_optional  => 1,
	     },
	     start => {
		 type  =>  'Number',
		 doc   =>  "build 36 start coordinate",
		 is_optional  => 1,
	     },
	     stop => {
		 type  =>  'Number',
		 doc   =>  "build 36 stop coordinate;",
		 is_optional  => 1,
	     },
	     ref => {
		 type  =>  'String',
		 doc   =>  "referance allele;",
		 is_optional  => 1,
	     },
	     var => {
		 type  =>  'String',
		 doc   =>  "variant allele;",
		 is_optional  => 1,
	     },

	     list => {
		 type  =>  'string',
		 doc   =>  "a list of positions with ref and variant alleles for match check",
		 is_optional  => 1,
	     },
	     gff => {
		 type  =>  'string',
		 doc   =>  "provide a name for the optional gff file of all dbsnps from your input coverage range",
		 is_optional  => 1,
	     },

	     ],
	
    
};


sub help_brief {
    return <<EOS
  This tool was design to retrieve dbsnp\'s for an individual site/range or list of sites and will check for an allele match to your variant if provided or it will simply state which sites on your list/input coords coinside with a dbsnp.
  EOS
}

sub help_synopsis {
    return <<EOS

gt snp get-dbsnps --list

the list is intended to be set up the same as with annotate transcript-variants

if the ref and var columns are omitted, then this script will still return dbsnps found in your input coordinates

using the --out option will allow your to get or list back in a file rather than as standard output to your screen 

chromosome start stop ref and var options will not be used if the list option is

EOS
}

sub help_detail {
    return <<EOS 

gt snp get-dbsnps --list file

your list should be a tab/space delimited file with five columns
chromosome   start   stop   ref_allele   variant_allele

or

running...
gt snp get-dbsnps --chromosome 1 --start 202785447 --stop 202785447 --ref A --var T

 will produce
      1 202785447 202785447 A T rs4252743:snp:1:'A/T':dbsnp_match

running...
gt snp get-dbsnps --chromosome 1 --start 202785447 --stop 202785447 --ref A --var G

 will produce
      1 202785447 202785447 A G rs4252743:snp:1:'A/T':no_match


when detirmining the validation status of a dbsnp this tool assumes that if the snp was ever entered in the database as being validated that it is still validated.


if a dbsnp coinsides with the coordinates and the reference and variant alleles are provided, this script will check to see if the dbsnp alleles match your variant 

use the gff option to get a gff like file of the dbsnps identified by your input coordinates 

EOS
}

my $list;
my $dbsnp;

sub execute {

    my $self = shift;

    my $out = $self->out;
    if ($out) {open(OUT,">$out");}

    my $file = $self->list;

    my $list;
    if ($file) {

	unless (-f $file) {system qq(gt snp get-dbsnps --help);print qq(Your list was not found.\t\n\tPlease check that your list is in place and try again.\n\n\n);return 0;}

	open(LIST,"$file");
	while (<LIST>) {
	    chomp;
	    my $line = $_;
	    my ($chr,$start,$stop,$ref,$var) = split(/[\s]+/,$line);
	    unless ($ref) {$ref = "na";}
	    unless ($var) {$var = "na";}
	    $list->{$chr}->{$start}->{$stop}->{ref}=$ref;
	    $list->{$chr}->{$start}->{$stop}->{var}=$var;
	}
	
    } else {
	
	my $chr = $self->chromosome;
	my $start = $self->start;
	my $stop = $self->stop;
	my $ref = $self->ref;
	my $var = $self->var;

	unless ($chr && $start && $stop) { system qq(gt snp get-dbsnps --help);return 0;}
	unless ($ref) {$ref = "na";}
	unless ($var) {$var = "na";}
	$list->{$chr}->{$start}->{$stop}->{ref}=$ref;
	$list->{$chr}->{$start}->{$stop}->{var}=$var;
	
    }

    $list = &getDBSNPS($list,$self);
    
    foreach my $chr (sort keys %{$list}) {
	foreach my $start (sort {$a<=>$b} keys %{$list->{$chr}}) {
	    foreach my $stop (sort {$a<=>$b} keys %{$list->{$chr}->{$start}}) {
		my $dbsnp_info = $list->{$chr}->{$start}->{$stop}->{dbsnp};
		unless ($dbsnp_info) {$dbsnp_info = "no_dbsnp_hit";}
		my $ref = $list->{$chr}->{$start}->{$stop}->{ref};
		my $var = $list->{$chr}->{$start}->{$stop}->{var};
		if ($out) {
		    print OUT qq($chr $start $stop $ref $var $dbsnp_info\n);
		} else {
		    print qq($chr $start $stop $ref $var $dbsnp_info\n);
		}
	    }
	}
    }
    return ($list);
}

sub getDBSNPS {

    my ($list,$self) = @_;   

    my $gff = $self->gff;
    if ($gff) {open(GFF,">$gff");}

    my $g = GSC::Sequence::Genome->get(sequence_item_name => 'NCBI-human-build36');

    foreach my $chr (sort keys %{$list}) {
	my $c = $g->get_chromosome($chr);
	
	foreach my $start (sort {$a<=>$b} keys %{$list->{$chr}}) {
	    foreach my $stop (sort {$a<=>$b} keys %{$list->{$chr}->{$start}}) {

		for my $pos ($start..$stop) {
		    
		    my @t = $c->get_tags( begin_position => {  operator => 'between', value => [$pos,$pos] },);
		    for my $t (@t) {
			next unless $t->sequence_item_type eq 'variation sequence tag';
			my $variation_type = $t->variation_type;
			my $ref_id = $t->ref_id;
			my $allele_description = $t->allele_description;
			my $validated = $t->is_validated;
			my $seq_length = $t->seq_length;
			my $stag_id = $t->stag_id;

			my $unzipped_base_string = $t->unzipped_base_string;

			my $end = $pos + ($seq_length - 1);

			unless ($validated) { $validated = 0; }

			my ($vt,$v,$ad);
			if ($dbsnp->{$chr}->{$pos}->{$ref_id}) {
			    ($vt,$v,$ad) = split(/\:/,$dbsnp->{$chr}->{$pos}->{$ref_id});
			}

			if ($validated == 1) {
			    $dbsnp->{$chr}->{$pos}->{$ref_id}="$variation_type\:$validated\:$allele_description";
			} elsif ($vt && $v && $ad) {
			    if ($v == 1) {$dbsnp->{$chr}->{$pos}->{$ref_id}="$vt\:$v\:$ad";}
			} else {
			    $dbsnp->{$chr}->{$pos}->{$ref_id}="$variation_type\:$validated\:$allele_description";
			}


			#$dbsnp->{$chr}->{$pos}->{$ref_id}="$variation_type\:$validated\:$allele_description";

			if ($self->gff) {
			    print GFF qq(Chromosome$chr\tDB\t$variation_type\t$pos\t$end\t.\t+\t.\t$stag_id\t$ref_id \; Alleles $allele_description \; Validation $validated\n);
			}
		    }
		}
		
		my $ref = $list->{$chr}->{$start}->{$stop}->{ref};
		my $var = $list->{$chr}->{$start}->{$stop}->{var};

		foreach my $ref_id (sort keys %{$dbsnp->{$chr}->{$start}}) {
		    my ($variation_type,$validated,$allele_description) = split(/\:/,$dbsnp->{$chr}->{$start}->{$ref_id});
		    my $match = &check_match($ref,$var,$allele_description);
		    unless ($match) {$match="no_match";}
		    my $snpfo = $list->{$chr}->{$start}->{$stop}->{dbsnp};
		    
		    if ($snpfo) {
			unless ($snpfo =~ /$variation_type\:$validated\:$allele_description\:$match/) {
			    $list->{$chr}->{$start}->{$stop}->{dbsnp}="$snpfo\:\:$ref_id\:$variation_type\:$validated\:$allele_description\:$match";
			}
		    } else {
			$list->{$chr}->{$start}->{$stop}->{dbsnp}="$ref_id\:$variation_type\:$validated\:$allele_description\:$match";
		    }
		}
		my $snpfo = $list->{$chr}->{$start}->{$stop}->{dbsnp};
		unless ($snpfo) {$list->{$chr}->{$start}->{$stop}->{dbsnp} = "no_dbsnp_hit"};
	    }
	}
    }
    return $list;
}


sub check_match {
    my ($ref,$var,$allele_description) = @_;
    
    $allele_description =~ s/\'//gi;

    my @dbsnp_allele_array = split(/\//,$allele_description);
    my $array_n = @dbsnp_allele_array;


    my ($rm,$vm);
    for my $n (1..$array_n) {
	my $m = $n - 1;
	my $dbsnp_allele = $dbsnp_allele_array[$m];
	if ($ref eq $dbsnp_allele) {
	    $rm = 1;
	} elsif ($var eq $dbsnp_allele) {
	    $vm = 1;
	}
    }

    unless ($rm) {
	for my $n (1..$array_n) {
	    my $m = $n - 1;
	    my $dbsnp_allele = $dbsnp_allele_array[$m];
	    my $rev_dbsnp_allele = &reverse_complement_allele ($dbsnp_allele); 
	    if ($ref eq $rev_dbsnp_allele) {
		$rm = 1;
	    } elsif ($var eq $rev_dbsnp_allele) {
		$vm = 1;
	    }
	}
    }
    
    my $dbsnp_match;
    if ($rm && $vm) {
	$dbsnp_match = "dbsnp_match";
    } else {    
	$dbsnp_match = "no_match";
    }
    return ($dbsnp_match);
}	    




sub reverse_complement_allele {
    my ($allele_in) = @_;

    if ($allele_in =~ /[\-\+X]/) {
	return $allele_in;
    } else {

	if ($allele_in =~ /[ACGT]/) {
	    my $seq_1 = new Bio::Seq(-seq => $allele_in);
	    my $revseq_1 = $seq_1->revcom();
	    my $rev1 = $revseq_1->seq;
	    return $rev1;
	} else {
	    return $allele_in;
	}
    }
}


1;
