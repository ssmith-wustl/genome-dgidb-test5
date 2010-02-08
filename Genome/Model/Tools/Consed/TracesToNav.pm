package Genome::Model::Tools::Consed::TracesToNav;

use strict;
use warnings;
use Genome;
use GSCApp;
use IPC::Run;

class Genome::Model::Tools::Consed::TracesToNav {
    is => 'Command',                    
    has => [ # specify the command's properties (parameters) <--- 
	     ace              => {
		 type         => 'String',
		 doc          => "the full path to and including the ace file you want to navigate",
	     },
	     list             => {
		 type         => 'String',
		 doc          => "provide a comma delimited list of sample sites to review",
	     },
	     name_nav          => {
		 type         => 'String',
		 doc          => "allows you to provide a descriptive name for the manual review spreadsheet defaults is sites_for_review.date",
		 is_optional  => 1,
	     },
	     convert_coords   => {
		 type         => 'String',
		 doc          => "if the coordinates on your list are genomic, you may use this option by providing the refseq fasta file to get the refseq coordinate to navigate", 
		 is_optional  => 1,
	     },
	     unpaired         => {
		 type         => 'Boolean',
		 doc          => "if your list does not included paired sample info use use this option", 
		 is_optional  => 1,
	     },
	     
	     
	     ],
    
    
};


sub help_brief {                            # keep this to just a few words <---
    "This tool will make a consed ace navigator from a list of samples and coordinates"     
}

sub help_synopsis {                         # replace the text below with real examples <---
    return <<EOS
gmt consed traces-to-nav --ace --list

running...

gmt consed traces-to-nav --ace /gsc/var/cache/testsuite/data/Genome-Model-Tools-Consed-TracesToConsed/10_126008345_126010576/edit_dir/10_126008345_126010576.ace.1 --convert-coords /gsc/var/cache/testsuite/data/Genome-Model-Tools-Consed-TracesToConsed/10_126008345_126010576/edit_dir/10_126008345_126010576.c1.refseq.fasta --unpaired --name-nav test.traces.to.nav --list /gsc/var/cache/testsuite/data/Genome-Model-Tools-Consed-TracesToConsed/10_126008345_126010576/edit_dir/Nav.list

will produce a navigator ==> test.traces.to.nav.date.nav
and a spreadsheet ==> test.traces.to.nav.date.csv

EOS
}

sub help_detail {                           # this is what the user will see with the longer version of help. <---
    return <<EOS 


Formating Your List
     Your list should be a comma delimited plain text file in one of the following two formats

          if you want to navigate paired samples
	     sample,pos,paired_sample,comment

          if you do not want to navigate paired samples
	     sample,pos,comment

The spreadsheet test.traces.to.nav.date.csv will be a tab delimited file in this format
refpos  sample  reads   note    manual_genotype comments

where manual_genotype and comments are left blank

The comment is what ever was supplied in the list and should not contain any commas


EOS
}


my $self; # = shift;
my $ace;
my $list;
my $name_nav;
my $csv;


my $edit_dir;


my $sites_to_nav;
my $samples_pos_info;
my $notinnavigator;
my $printed;

my $nav_select;
my $tumor_samples;
my $paired_samples;
my $genotypes;
my $naved;

my $gene;

my $date_tag;
my $refseq_info;


sub execute {                               # replace with real execution logic.

    $self = shift;
    $ace = $self->ace;
    $list = $self->list;
    $name_nav = $self->name_nav;
    #$csv = $self->csv;
    
    my @subdir = split(/\//,$ace);
    my $ace_name = pop(@subdir);
    $edit_dir = join('/',@subdir);
    chdir $edit_dir;
    
    $date_tag = &get_date_tag();
    


    my $refseq = $self->convert_coords;
    if ($refseq) {
	&parse_ref($refseq);
    }
    
    &get_sites_to_nav($list); #read in list
    &get_reads_to_nav; #find the reads for samples from the list
    &make_read_nav; #write the navigator and if desired the spreadsheet
    
    
}


sub get_sites_to_nav {
    
    open(LIST,"$list");
    while (<LIST>) {
	chomp;
	
	my ($line) = $_;
	#my ($Gene,$pos,$note,$sample,$sample_gt,$pair,$pair_gt,$somatic_status)= split(/\,/,$line);
	
	my ($sample,$pos,$pair,$note);
	if ($self->unpaired) {
	    ($sample,$pos,$note) = split(/\,/,$line);
	    $pair = $sample;
	} else {
	    ($sample,$pos,$pair,$note) = split(/\,/,$line);
	}
	
	if ($self->convert_coords) {
	    $pos = &get_refpos($pos);
	}
	
	
	unless ($note) {$note="no comment";}
	
	$tumor_samples->{$sample}=$pair;
	$paired_samples->{$sample}=$pair;
	$paired_samples->{$pair}=$sample;
	
	#$genotypes->{$pos}->{$sample}=$sample_gt;
	#$genotypes->{$pos}->{$pair}=$pair_gt;
	
	
	$sites_to_nav->{$pos}->{$sample}->{comment}=$note;
	$sites_to_nav->{$pos}->{$pair}->{comment}=$note;
#	$sites_to_nav->{$pos}->{$sample}->{somatic_status}=$somatic_status;
#	$sites_to_nav->{$pos}->{$pair}->{somatic_status}=$somatic_status;
	$samples_pos_info->{$pos}->{comment}=$note;
	
    }
}



my $main_contig;


sub get_reads_to_nav {
    
    use GSC::IO::Assembly::Ace;
    my $ao = GSC::IO::Assembly::Ace->new(input_file => $ace);
    
    foreach my $name (@{ $ao->get_contig_names }) {
	my $contig = $ao->get_contig($name);
	if (grep { /\.c1$/ } keys %{ $contig->reads }) {
	    $main_contig = $name;
	}
    }
    
    my %base_pad_count;
    my @hhh;
    
    my $p;
    my $q;
    my @con_seq;
    
    open (ACE_file, "$ace") || die ("Could not open the ace file\n");
    my @seq_line = ();
    my @file = <ACE_file>;
    my $file_n = @file;
    close (ACE_file);
    $p = 0;
    
    
    while ($file_n >= $p){
	$q = 1;
	if ($file[$p]) {
	    if ($file[$p] =~ /CO $main_contig\s/) { 
		until ($file[$p + $q] =~ /BQ/){
		    chomp $file[$p + $q];
		    #print ("$file[$p + $q]");
		    @seq_line = split(//, $file[$p + $q]);
		    chomp @seq_line;
		    push @con_seq, @seq_line;
		    
		    $q++;
		}
	    }
	}
	$p++;
    }
    my $pad_count = 0;
    my $base_number = 0;
    foreach my $base (@con_seq){
	#$base_number++;
	if ($base =~ /\*/) { 
	    $pad_count++;
	} else {
	    $base_number++;
	    $base_pad_count{$base_number} = $pad_count;
	}
    }
    
    @hhh = %base_pad_count;
    
    
#	&Count_pads; #count the pads in the consensus
    %base_pad_count = @hhh; # 
    
    
    
    foreach my $pos (sort {$a<=>$b} keys %{$sites_to_nav}) {
	
	foreach my $name (@{ $ao->get_contig_names }) {
	    
	    if ($name eq $main_contig) {
		my $contig = $ao->get_contig($name);
		my $info = $contig->reads;
		
		foreach my $read (keys %{ $contig->reads }) {
		    unless ($read =~ /\c1$/) {
			
			my ($id);
			
			foreach my $sample (sort keys %{$sites_to_nav->{$pos}}) {
			    if ($read =~ /$sample/) {
				#my $sample = substr($read,$pretty_source_1,$pretty_source_2);
				$id = $sample;
			    }
			}
			
			if ($id) {
			    if ($sites_to_nav->{$pos}->{$id}) {
				
				my $q1 = $info->{$read}->qual_clip_start;
				my $q2 = $info->{$read}->qual_clip_end;
				my $position = $info->{$read}->position;
				
				if ($position) {
				    
				    my $length = $info->{$read}->length;
				    my $align_clip_start = $info->{$read}->align_clip_start;
				    my $align_clip_end = $info->{$read}->align_clip_end;
				    my $position2 = $position + $length - 1;
				    my $p1 = ($position  - $base_pad_count{$position});
				    my $p2 = $p1 + $length;
				    my $padded_pos = $pos + $base_pad_count{$pos};
				    my $comment = $sites_to_nav->{$pos}->{$id}->{comment};
				    my $diff = "$pos $pos";
				    my $ref_q1 = $position + $align_clip_start + 1;
				    my $bases_clipped_off_end = $length - $align_clip_end;
				    my $ref_q2 = $position2 - $bases_clipped_off_end;
				    
				    if (($padded_pos >= $ref_q1)  && ($padded_pos  <= $ref_q2)) {
					
					print qq($read $p1 $position - $base_pad_count{$position} $length $diff pos\n);
					
					$nav_select->{$pos}->{$id}->{$read}->{nav} = "BEGIN_REGION\nTYPE: READ\nCONTIG: $name\nREAD: $read\nUNPADDED_CONS_POS: $diff\nCOMMENT: $comment\nEND_REGION\n\n";
					
					if ($sites_to_nav->{$pos}->{$id}->{nav}) {
					    unless ($sites_to_nav->{$pos}->{$id}->{nav} =~ /$read/) {
						my $read1 = $sites_to_nav->{$pos}->{$id}->{nav};
						$sites_to_nav->{$pos}->{$id}->{nav} = "$read1:$read";
					    }
					} else {
					    
					    $sites_to_nav->{$pos}->{$id}->{nav} = $read;
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
    
    foreach my $pos (sort {$a<=>$b} keys %{$sites_to_nav}) {
	unless ($nav_select->{$pos}) {
	    $notinnavigator->{$pos}=1;
	    $nav_select->{$pos}->{notinnavigator}=1;
	}
    }
}
####################################################################


sub make_read_nav {
    
    my $filename;
    if ($name_nav) {
        $filename = "$edit_dir/$name_nav.$date_tag.nav";
	#open (NAV,">$edit_dir/$name_nav.$date_tag.nav");
    } else {
        $filename = "$edit_dir/sites_for_review.$date_tag.nav";
	#open (NAV,">$edit_dir/sites_for_review.$date_tag.nav");
    }
    unless (open(NAV, ">$filename")) {
        die "Can't open $filename for writing: $!";
        return;
    }
    
    print NAV qq(TITLE:\n\n);
    
    foreach my $pos (sort {$a<=>$b} keys %{$nav_select}) {
	foreach my $t_id (sort keys %{$nav_select->{$pos}}) {
	    if ($t_id eq "notinnavigator") {
		my $comment = $samples_pos_info->{$pos}->{comment};
		my $nav_line =  "BEGIN_REGION\nTYPE: CONSENSUS\nCONTIG: $main_contig\nUNPADDED_CONS_POS: $pos $pos\nCOMMENT: $comment\nEND_REGION\n\n";
		print NAV qq($nav_line);
		
	    } else {
		
		if ($tumor_samples->{$t_id}) {
		    my $n_id = $tumor_samples->{$t_id};
		    my @array;
		    if ($t_id eq $n_id) {
			@array=($t_id);
		    } else {
			@array=($t_id,$n_id);
		    }
		    
		    for my $id (@array) { 
			
			foreach my $read (sort keys %{$nav_select->{$pos}->{$id}}) {
			    
			    if ($nav_select->{$pos}->{$id}->{$read}->{nav}) {
				my $nav_line = $nav_select->{$pos}->{$id}->{$read}->{nav};
				
				unless ($naved->{$pos}->{$id}->{$read}) {
				    print NAV qq($nav_line);
				    $naved->{$pos}->{$id}->{$read}=1;
				}
			    }
			}
		    }
		}
	    }
	}
    }
    
    
    #if ($csv) {
	
	if ($name_nav) {
	    open (CSV,">$edit_dir/$name_nav.$date_tag.csv");
	} else {
	    open(CSV,">$edit_dir/sites_for_review.$date_tag.csv"); #the_rest_
	}
	
	#print CSV qq(Gene\trefpos\tsample\tnote\tpair\treads\trefseq_orientation\tprettybase_genotype\tmanual_genotype\tsomatic_status\tcomments\n);
	#my ($sample,$pos,$pair,$note);
	if ($self->unpaired) {
	    #($sample,$pos,$note) = split(/\,/,$line);
	    print CSV qq(refpos\tsample\treads\tnote\tmanual_genotype\tcomments\n);
	} else {
	    #($sample,$pos,$pair,$note) = split(/\,/,$line);
	    print CSV qq(refpos\tsample\treads\tnote\tmanual_genotype\tsomatic_status\tcomments\n);
	}
	
	
	foreach my $pos (sort {$a<=>$b} keys %{$sites_to_nav}) {
	    foreach my $t_id (sort keys %{$sites_to_nav->{$pos}}) {
		
		if ($tumor_samples->{$t_id}) {
		    my $n_id = $tumor_samples->{$t_id};
		    
		    my @array;
		    if ($t_id eq $n_id) {
			@array=($t_id);
		    } else {
			@array=($t_id,$n_id);
		    }
		    
		    for my $id (@array) { 
			
			unless ($printed->{$pos}->{$id}) {
			    
			    #my $somatic_status = $sites_to_nav->{$pos}->{$id}->{somatic_status};
			    my $pair = $paired_samples->{$id};
			    
			    if ($sites_to_nav->{$pos}->{$id}->{comment} && $sites_to_nav->{$pos}->{$id}->{nav}) {
				#my $genotype = $genotypes->{$pos}->{$id};
				#unless ($genotype) { $genotype = "no_gt"; }
				
				my $note = $sites_to_nav->{$pos}->{$id}->{comment};
				my $reads = $sites_to_nav->{$pos}->{$id}->{nav};
				
				$printed->{$pos}->{$id}=1;
				print CSV qq($pos\t$id\t$reads\t$note\t\n);
				
			    } else {
				#my $genotype = $genotypes->{$pos}->{$id};
				#unless ($genotype) { $genotype = "no_gt"; }
				
				my $comment = $sites_to_nav->{$pos}->{$id}->{comment};
				print qq(not in navigator $id,$comment\n);
				
				my $chrom_pos = $sites_to_nav->{$pos}->{$id}->{gc};
				my $note = $sites_to_nav->{$pos}->{$id}->{comment};
				my $reads = $sites_to_nav->{$pos}->{$id}->{nav};
				unless ($reads) {$reads='';}
				
				$printed->{$pos}->{$id}=1;
				print CSV qq($pos\t$id\tnot in navigator\t$note\t\n);
				
				#print CSV qq($gene\t$pos\t$id\t$note\t$pair\tnot in navigator\t$genotype-$somatic_status\t$genotype\n);
				
			    }
			}
		    }
		}
	    }
	}
    #}
}


####################################################################
####################################################################
sub make_cons_nav {
    
    if ($name_nav) {
	open (NAV3,">$edit_dir/$name_nav.$date_tag.consensus.nav");
    } else {
	open (NAV3,">$edit_dir/sites_for_review.$date_tag.consensus.nav"); #the_rest_
    }
    print NAV3 qq(TITLE:\n\n);
    
    foreach my $pos (sort {$a<=>$b} keys %{$nav_select}) {
	
	my $comment = $samples_pos_info->{$pos}->{comment};
	my $nav_line =  "BEGIN_REGION\nTYPE: CONSENSUS\nCONTIG: $main_contig\nUNPADDED_CONS_POS: $pos $pos\nCOMMENT: $comment\nEND_REGION\n\n";
	print NAV3 qq($nav_line);
	
    }
}



sub get_newest {
    my ($file) = @_;
    $file  = `ls $file`;
    chomp($file);
    my @file_array = ();
    @file_array = split(/\n/, $file);
    
    if($file_array[1])
    {
	@file_array = sort byDateDesc @file_array;
    }	
    
    $file = $file_array[0];
    #my @f_array = split(/\//,$file);
    #$file = pop(@f_array);
    
    return $file;
}


sub byDateDesc
{
    my @fileStats = stat $a;
    my $mtime_a = $fileStats[9];
    
    @fileStats = stat $b;
    my $mtime_b = $fileStats[9];	
    
    $mtime_b <=> $mtime_a;
}



sub get_date_tag {
    
    my $time=`date`;
    #my ($handle) = getpwuid($<);
    my $date = `date +%D`;
    (my $new_date) = $date =~ /(\d\d)\/(\d\d)\/(\d\d)/ ;
    my $date_tag = "$3$1$2" ;
    return $date_tag;
}

sub parse_ref {
    
    
    my ($refseq) = @_;
    my $orientation;
    my $genomic_coord;
    
    open(REF,"$refseq") || die "couldn\'t open the refseq\n";
    while (<REF>) {
	chomp; 
	my $line = $_;
	
	if ($line =~ /\>/) {
	    #my ($roi) = $line =~ /^\S+\.(\S+)\.c1\.refseq\.fasta\:\>/;
	    #my ($gene) = $line =~ /GeneName:(\S+)\,/;
	    #my ($chromosome) = $line =~ /Chr\:([\S]+)\,/;
	    
	    if ($line=~ /Ori\s+\(\+\)/) {
		my ($fisrt_coord)=$line =~ /Coords\s+(\d+)\S\d+/;
		$orientation="plus";
		$genomic_coord = $fisrt_coord - 1;
	    } elsif ($line=~ /Ori\s+\(\-\)/) {
		my ($second_coord)=$line =~ /Coords\s+\d+\S(\d+)/;
		$orientation="minus";
		$genomic_coord = $second_coord + 1;
	    }
	}
    }
    close(REF);
    $refseq_info->{orientation}=$orientation;
    $refseq_info->{genomic_coord}=$genomic_coord;
    
}

sub get_refpos {
    my ($genpos) = @_;
    my $orientation = $refseq_info->{orientation};
    my $genomic_coord = $refseq_info->{genomic_coord};
    
    my $ref_pos;
    
    if ($orientation eq "plus") {
	$ref_pos = $genpos - $genomic_coord;
	
    } elsif ($orientation eq "minus") {
	$ref_pos = $genomic_coord - $genpos;
    }
    return $ref_pos;
}

1;

