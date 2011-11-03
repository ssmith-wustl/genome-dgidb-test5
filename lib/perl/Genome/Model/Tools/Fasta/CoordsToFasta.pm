package Genome::Model::Tools::Fasta::CoordsToFasta;

use strict;
use warnings;
use Genome;

use Bio::Seq;
use Bio::DB::Fasta;

class Genome::Model::Tools::Fasta::CoordsToFasta {
    is => 'Command',                    
    has => [ # specify the command's properties (parameters) <--- 
	     

	     out => {
		 type  =>  'String',
		 doc   =>  "provide a name for your output fasta file or it will simply be printed as stdout",
		 is_optional  => 1,
	     },
	     name => {
		 type  =>  'String',
		 doc   =>  "provide a string that will appear in the fasta header",
		 is_optional  => 1,
	     },
	     format_header => {
		 type  =>  'Boolean',
		 doc   =>  "using this option will write a string that will appear in the fasta header and will supersede the name option",
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
	     list => {
		 type  =>  'string',
		 doc   =>  "a list of positions from which to retrieve sequence",
		 is_optional  => 1,
	     },
	     masked => {
		 type  =>  'Boolean',
		 doc   =>  "use this option if you want masked sequence rather than the default softmasked sequence",
		 is_optional  => 1,
	     },
	     unmasked => {
		 type  =>  'Boolean',
		 doc   =>  "use this option if you want unmasked sequence rather than the default softmasked sequence",
		 is_optional  => 1,
	     },
	     reverse_complement => {
		 type  =>  'Boolean',
		 doc   =>  "use this option if you reverse completemented sequence rather than the default positively oriented sequence",
		 is_optional  => 1,
	     },
	     organism => {
		 type  =>  'String',
		 doc   =>  "provide the organism either mouse or human; default is human",
		 is_optional  => 1,
		 default => 'human',
	     },
	     ref_dir           => {
		 type         => 'string',
		 doc          => "use this option if you want to provide your own genomic reference to excise the reference sequence fasta file from. Masking will not work with this option.",
		 is_optional  => 1,
	     },
             HS37  => {
		 type  =>  'Boolean',
		 doc   =>  "Default human sequence falls on Build 36. Use this option if you want sequence from Human Build 37.",
		 is_optional  => 1,
	     },

	
    	     ],

};

sub help_brief {
    return <<EOS
  This tool was design to retrieve sequence from NCBI Human Build 36, sequence from an individual or list of coordinates.
EOS
}

sub help_synopsis {
    return <<EOS

running with optional minimum input...

gmt fasta coords-to-fasta --list 
 
...will provide you with a fasta file of sequence from you list of coordinates

gmt fasta coords-to-fasta --chromosome --start --stop
...will provide you with a sequence from your specified input

EOS
}

sub help_detail {
    return <<EOS 

If you would like a fasta file for one genomic range you may find it simplest to get in this fashion

 gmt fasta coords-to-fasta --chromosome chr3 --start 103057567 --stop 103057936

 your output will be printed to your screen like this

>chr3:103057567:103057936
TGGGTGGTTAAGAAGCCCAGAAttttttttttttttgagacagagtctcactgtgtcgcccaggctggaatgcagtggtgcgatcttggctcactgcaacctccgactccctggttcaagcgattctcctgcctcagcctgcccagtagctgggactacaggtgcctaccaccacacccagctaattttttgtatttttagtagagacggggtttcaccatgttagccaggatggtctcgatctcctgacctcgtgatctgcccgcctcggcctcccgaagtgctgggattacaggcgtgagccaccgcgcccggccAAGAAGCCCAGATTTTAACAGATCATTTCATGTGTTTTCTTGATTTGCTTTAA


as you can see this is the soft masked sequence by default use the --unmasked option if you want all caps in your sequence

 gmt fasta coords-to-fasta --chromosome chr3 --start 103057567 --stop 103057936 --unmasked
>chr3:103057567:103057936
TGGGTGGTTAAGAAGCCCAGAATTTTTTTTTTTTTTGAGACAGAGTCTCACTGTGTCGCCCAGGCTGGAATGCAGTGGTGCGATCTTGGCTCACTGCAACCTCCGACTCCCTGGTTCAAGCGATTCTCCTGCCTCAGCCTGCCCAGTAGCTGGGACTACAGGTGCCTACCACCACACCCAGCTAATTTTTTGTATTTTTAGTAGAGACGGGGTTTCACCATGTTAGCCAGGATGGTCTCGATCTCCTGACCTCGTGATCTGCCCGCCTCGGCCTCCCGAAGTGCTGGGATTACAGGCGTGAGCCACCGCGCCCGGCCAAGAAGCCCAGATTTTAACAGATCATTTCATGTGTTTTCTTGATTTGCTTTAA

use the masked option if you want masked sequence. The masked sequence comes from our database and will take longer to obtain than sequence from the other two option which come from an indexed sequence of NCBI Build36

 gmt fasta coords-to-fasta --chromosome chr3 --start 103057567 --stop 103057936 --masked

>chr3:103057567:103057936
TGGGTGGTTAAGAAGCCCAGAANNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNAAGAAGCCCANATTTTAACAGATCATTTCATGTGTTTTCTTGATTTGCTTTAA

if you would like to write a more discriptive refseq header use the --name option

 gmt fasta coords-to-fasta --chromosome chr3 --start 103057567 --stop 103057936 --name "chr3:103057567:103057936.refseq.fasta Chr:3, Coords 103057567-103057936, Ori (+), comment"


>chr3:103057567:103057936.refseq.fasta Chr:3, Coords 103057567-103057936, Ori (+), comment
TGGGTGGTTAAGAAGCCCAGAAttttttttttttttgagacagagtctcactgtgtcgcccaggctggaatgcagtggtgcgatcttggctcactgcaacctccgactccctggttcaagcgattctcctgcctcagcctgcccagtagctgggactacaggtgcctaccaccacacccagctaattttttgtatttttagtagagacggggtttcaccatgttagccaggatggtctcgatctcctgacctcgtgatctgcccgcctcggcctcccgaagtgctgggattacaggcgtgagccaccgcgcccggccAAGAAGCCCAGATTTTAACAGATCATTTCATGTGTTTTCTTGATTTGCTTTAA

a refseq header of this sort will work in junction with some of the other tools such as convert-consed-coords

if you would like to write your output to a file use the --out option

 gmt fasta coords-to-fasta --chromosome chr3 --start 103057567 --stop 103057936 --name "chr3:103057567:103057936.refseq.fasta Chr:3, Coords 103057567-103057936, Ori (+), comment" --out chr3:103057567:103057936.refseq.fasta

will produce the file chr3:103057567:103057936.refseq.fasta with the same content as the above example



+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++


If you would like to produce a fasta of fastas you can use the --list option 

    The list should be a (space or tab) delimited file in this order
          chromosome start stop name
	  the name is optional in the list. Other options and defaults are the same as above 

	  see this list file for some acceptable/unacceptable list line configurations, and run this as an example 

  gmt fasta coords-to-fasta --list /gsc/var/cache/testsuite/data/Genome-Model-Tools-Fasta-CoordsToFasta/CoordsToFasta.test.list


+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

If you are retrieving mitochondrial sequence please note that masked sequence is not available


EOS
}


sub execute {

    my $self = shift;
    my $organism = $self->organism;

    my $build;
    if ($organism eq "human") {
	$build = 36;
	if ($self->HS37) {
	    $build = 37;
	}
    } elsif ($organism eq "mouse") {
	$build = 37;
    } else {
	$build = "UNK";
    }

    my $genome;
    if ($self->masked) {
	if ($organism eq "human") {
	    $genome = GSC::Sequence::Genome->get(sequence_item_name => 'NCBI-human-build36');
	    if ($self->HS37) {
		$genome = GSC::Sequence::Genome->get(sequence_item_name => 'NCBI-human-build37');
	    }
	} elsif ($organism eq "mouse") {
	    $genome = GSC::Sequence::Genome->get(sequence_item_name => 'NCBI-mouse-buildC57BL6J');
	}
    }
    
    my $ori = "+";
    if ($self->reverse_complement) {
	$ori = "-";
    }

    my $out = $self->out;
    if ($out) {open(OUT,">$out");}
    
    my $list = $self->list;

    if ($list) {
	open(LIST,"$list");
	while (<LIST>) {
	    chomp;
	    my $line = $_;
	    my ($chr,$start,$stop,$name) = split(/[\s]+/,$line);
	    if ($line =~ /\"([\S\s]+)\"/) {
		$name = $1;
	    }

	    unless ($chr && $start && $stop) { $self->error_message("chromosome start and stop was not found in $line. This line will be skipped"); next;}
	    if (($start =~ /\D/) || ($stop =~ /\D/)) { $self->error_message("chromosome start and stop was not found in $line. This line will be skipped"); next;}


	    unless($name) {$name = "$chr\:$start\:$stop";}
	    $chr =~ s/chr([\S]+)/\U$1/;

	    if ($chr =~ /M/ || $chr =~ /m/) { $chr = "M"; }

	    if ($self->format_header) {
		if ($organism eq "human") {
		    if ($out) {
			$name = "$out NCBI Human Build $build, Chr:$chr, Coords $start-$stop, Ori ($ori)";
		    } else {
			$name = "$chr\:$start\:$stop NCBI Human Build $build, Chr:$chr, Coords $start-$stop, Ori ($ori)";
		    }
		} else {
		    if ($out) {
			$name = "$out NCBI Mouse Build $build, Chr:$chr, Coords $start-$stop, Ori ($ori)";
		    } else {
			$name = "$chr\:$start\:$stop NCBI Mouse Build $build, Chr:$chr, Coords $start-$stop, Ori ($ori)";
		    }
		}
		if ($self->ref_dir) {
		    if ($out) {
			$name = "$out $organism, Chr:$chr, Coords $start-$stop, Ori ($ori)";
		    } else {
			$name = "$chr\:$start\:$stop $organism, Chr:$chr, Coords $start-$stop, Ori ($ori)";
		    }
		}
	    }
	    my $seq = &get_ref_base($chr,$start,$stop,$self);
	    
	    unless ($seq) {$self->error_message("the sequence was not found from the info $line. This line will be skipped"); next;}

	    $chr =~ s/chr//;

	    if ($self->masked && $genome) {
		unless ($chr eq "M") {
		    my $chromosome = $genome->get_chromosome($chr);
		    my $masked_seq = $chromosome->mask_snps_and_repeats(begin_position       => $start, 
									end_position         => $stop,
									sequence_base_string => $seq);
		    $seq = $masked_seq;
		} 
	    }
	    if ($self->reverse_complement) { my $rev_seq = &reverse_complement_allele($seq); $seq = $rev_seq;}
	    if ($out) {
		print OUT qq(\>$name\n$seq\n);
	    } else {
		print qq(\>$name\n$seq\n);
	    }
	} close (LIST);
	close (OUT);
    } else {

	my $chr = $self->chromosome;
	my $start = $self->start;
	my $stop = $self->stop;

	unless ($chr && $start && $stop) { system qq(gmt fasta coords-to-fasta --help); return 0;}

	unless ($start =~ /^[\d]+$/) {$self->error_message("please provide the start coordinate"); return 0; }
	unless ($stop =~ /^[\d]+$/) {$self->error_message("please provide the stop coordinate"); return 0; }

	if ($chr =~ /M/ || $chr =~ /m/) { $chr = "M"; }

	my $seq = &get_ref_base($chr,$start,$stop,$self);

	$chr =~ s/chr//;

	
	if ($self->masked && $genome) {
#	    unless ($chr eq "M" || $self->ref_dir) {
	    unless ($chr eq "M") {
		
#if($chr eq M || MT there isn't any masked mit chr here so step around
		
		my $chromosome = $genome->get_chromosome($chr);
		my $masked_seq = $chromosome->mask_snps_and_repeats(begin_position       => $start, 
								    end_position         => $stop,
								    sequence_base_string => $seq);
		$seq = $masked_seq;
	    } 
	}
	if ($self->reverse_complement) { my $rev_seq = &reverse_complement_allele($seq); $seq = $rev_seq;}
	
	my $name = $self->name;
	unless ($name) { $name = "chr$chr:$start:$stop"; }

	if ($self->format_header) {
	    if ($organism eq "human") {
		if ($out) {
		    $name = "$out NCBI Human Build $build, Chr:$chr, Coords $start-$stop, Ori ($ori)";
		} else {
		    $name = "$chr\:$start\:$stop NCBI Human Build $build, Chr:$chr, Coords $start-$stop, Ori ($ori)";
		}
	    } else {
		if ($out) {
		    $name = "$out NCBI Mouse Build $build, Chr:$chr, Coords $start-$stop, Ori ($ori)";
		} else {
		    $name = "$chr\:$start\:$stop NCBI Mouse Build $build, Chr:$chr, Coords $start-$stop, Ori ($ori)";
		}
	    }
	    if ($self->ref_dir) {
		if ($out) {
		    $name = "$out $organism, Chr:$chr, Coords $start-$stop, Ori ($ori)";
		} else {
		    $name = "$chr\:$start\:$stop $organism, Chr:$chr, Coords $start-$stop, Ori ($ori)";
		}
	    }
	}
	
	if ($out) {
	    print OUT qq(\>$name\n$seq\n);
	} else {
	    print qq(\>$name\n$seq\n);
	}
    } close (LIST);
    close (OUT);
}

###########################

sub reverse_complement_allele {
    my ($allele_in) = @_;
    my $seq_1 = new Bio::Seq(-seq => $allele_in);
    my $revseq_1 = $seq_1->revcom();
    my $rev1 = $revseq_1->seq;
    return $rev1;
}

sub get_ref_base {
    my ($chr_name,$chr_start,$chr_stop,$self) = @_;

    my $organism = $self->organism;

    my $chr = $chr_name;

    $chr =~ s/([\S]+)/\U$1/;
    $chr =~ s/CHR/chr/;
    unless ($chr =~ /chr/) {$chr = "chr$chr";}

    use Bio::DB::Fasta;
    my $RefDir = $self->ref_dir;

    my $seq;
    if ($RefDir) {
	my $refdb = Bio::DB::Fasta->new($RefDir);
	$seq = $refdb->seq($chr_name, $chr_start => $chr_stop);
    } else {
	if ($self->HS37) {
	    $RefDir = "/gscmnt/200/medseq/analysis/software/resources/HS37";
	} elsif ($organism eq "human"){
	    $RefDir = "/gscmnt/sata180/info/medseq/biodb/shared/Hs_build36_mask1c/";
	} else {
	    $RefDir = "/gscmnt/200/medseq/analysis/software/resources/MouseB37/";
	}
	my $refdb = Bio::DB::Fasta->new($RefDir);
	$seq = $refdb->seq($chr, $chr_start => $chr_stop);
    }
    unless ($seq) {return(0);}
    
    if ($self->unmasked) {
	$seq =~ s/([\S]+)/\U$1/;
    }
    
    if ($seq =~ /N/) {warn "your sequence has N in it\n";}
    
    return $seq;
}

1;
