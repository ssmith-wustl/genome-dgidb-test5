package Genome::Model::Tools::Fasta::CoordsToFasta;

use strict;
use warnings;
use Genome;
use GSCApp;

class Genome::Model::Tools::Fasta::CoordsToFasta {
    is => 'Command',                    
    has => [ # specify the command's properties (parameters) <--- 
	     

	     out => {
		 type  =>  'String',
		 doc   =>  "provide a name for you output fasta file or it will simply be printed as stdout",
		 is_optional  => 1,
	     },
	     name => {
		 type  =>  'String',
		 doc   =>  "provide a string that will appear in the fasta header",
		 is_optional  => 1,
	     },
	     chromosome => {
		 type  =>  'String',
		 doc   =>  "chromosome ie {1,2,...,22,X,Y}",
		 is_optional  => 1,
	     },
	     start => {
		 type  =>  'Number',
		 doc   =>  "build 36 start coordinate of the variation",
		 is_optional  => 1,
	     },
	     stop => {
		 type  =>  'Number',
		 doc   =>  "build 36 stop coordinate of the variation; default will be equal to the start coordinate",
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
		 doc   =>  "use this option if you want softmasked sequence rather than the default softmasked sequence",
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

running...

gt fasta coords-to-fasta --list 
 
...will provide you with a fasta file of sequence from you list of coordinates

gt fasta coords-to-fasta --chromosome --start --stop
...will provide you with a sequence from your specified input

EOS
}

sub help_detail {
    return <<EOS 



EOS
}


sub execute {

    my $self = shift;

    my $genome = GSC::Sequence::Genome->get(sequence_item_name => 'NCBI-human-build36');

    my $out = $self->out;
    if ($out) {open(OUT,">$out");}
    
    my $list = $self->list;
    if ($list) {
	open(LIST,"$list");
	while (<LIST>) {
	    chomp;
	    my $line = $_;
	    my ($chr,$start,$stop,$name) = split(/[\s]+/,$line);
	    $chr =~ s/chr([\S]+)/\U$1/;

	    my $seq = &get_ref_base($chr,$start,$stop,$self);
	    $chr =~ s/chr//;
	    my $chromosome = $genome->get_chromosome($chr);

	    if ($self->masked) {
		
		my $masked_seq = $chromosome->mask_snps_and_repeats(begin_position       => $start, 
								    end_position         => $stop,
								    sequence_base_string => $seq);
		$seq = $masked_seq;
	    } 
	    
	    if ($out) {
		print OUT qq(\>$name\n$seq\n);
	    } else {
		print qq(\>$name\n$seq\n);
	    }
	} close (LIST);
	close (OUT);
    } else {
	my $chr = $self->chromosome;
	my $chromosome = $genome->get_chromosome($chr);
	
	
	my $start = $self->start;
	unless ($start =~ /^[\d]+$/) {$self->error_message("please provide the Build 36 start coordinate"); return 0; }
	my $stop = $self->stop;
	unless ($stop =~ /^[\d]+$/) {$self->error_message("please provide the Build 36 start coordinate"); return 0; }
	
	my $seq = &get_ref_base($chromosome,$start,$stop,$self);
	
	if ($self->masked) {
	    
	    my $masked_seq = $chromosome->mask_snps_and_repeats(begin_position       => $start, 
								end_position         => $stop,
								sequence_base_string => $seq);
	    $seq = $masked_seq;
	} 
	my $name = $self->name;
	unless ($name) { $name = "chr$chr:$start:$stop"; }
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

    use Bio::DB::Fasta;
    my $RefDir = "/gscmnt/sata180/info/medseq/biodb/shared/Hs_build36_mask1c/";
    my $refdb = Bio::DB::Fasta->new($RefDir);

    my ($chr_name,$chr_start,$chr_stop,$self) = @_;
    my $seq = $refdb->seq($chr_name, $chr_start => $chr_stop);



    if ($self->unmasked) {
	$seq =~ s/([\S]+)/\U$1/;
    }
    
    if ($seq =~ /N/) {warn "your sequence has N in it\n";}

    return $seq;
    
}

1;
