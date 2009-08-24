
package Genome::Model::Tools::ViromeEvent::Assignment::Report;

use strict;
use warnings;

use Genome;
use Workflow;
use IO::File;
use Switch;
use Bio::SearchIO;

class Genome::Model::Tools::ViromeEvent::Assignment::Report{
    is => 'Genome::Model::Tools::ViromeEvent',
};

sub help_brief {
    "gzhao's reporting for virome"
}

sub help_synopsis {
    return <<"EOS"
EOS
}

sub help_detail {
    return <<"EOS"
This script will read corresponding files in the given director and 
generate a report. It will report in each library, for each category,
how many total sequence were assigned to this category, how many were 
assigned by BLASTN, how many were assigned by TBLASTX, the range of 
percent identity. It will also generate four fasta format files which 
contain viral reads from blastn, tblastx, all viral reads and reads
that can not be assigned to any category.

perl script <sample dir>
<sample dir> = full path to the directory holding files for the given 
               library
               e.g. .../S21_Rota_other
EOS
}

sub create {
    my $class = shift;
    my $self = $class->SUPER::create(@_);
    return $self;

}

sub execute
{
    my $self = shift;
    my $dir = $self->dir;

    $self->log_event("Assignment Reporting begun");

    # get all the viral read sequences
    my %viral_reads_blastn = ();
    my %viral_reads_tblastx_nt = ();
    my %viral_reads_tblastx_VG = ();

    my %best_e_blastn = (); # viral_read_ID => best_e value for this read in blastn
    my %best_e_tblastx_nt = (); # viral_read_ID => best_e value for this read in tblastx nt
    my %best_e_tblastx_VG = (); # viral_read_ID => best_e value for this read in tblastx viral genome

    my @blast_files_blastn = (); # all blastn.out files
    my @blast_files_tblastx_nt = (); # all tblastx.out files
    my @blast_files_tblastx_VG = (); # all tblast_ViralGenome.out files

    my @unassigned_reads = ();

    # read in original sequences
    my @temp = split("\/", $dir);
    my $lib_name = pop @temp;
    # print "lib is $lib_name\n";
    my $fasta_file = $dir."/".$lib_name.".fa.cdhit_out.masked.goodSeq";
    my %seq = $self->read_FASTA_data($fasta_file);

    my $out1 = $dir."/".$lib_name.".AssignmentReport";
    open (OUT1, ">$out1") or die "can not open file $out1!\n";
    my $OUT2 = $dir."/".$lib_name.".ViralReads_all.fa";
    open (OUT2, ">$OUT2") or die "can not open file $OUT2!\n";
    my $OUT3 = $dir."/".$lib_name.".unassigned.fa";
    open (OUT3, ">$OUT3") or die "can not open file $OUT3!\n";

    # category => num of sequence assigned to this category by blastn
    my %blastn = ("Homo" => 0,
		"Mus" => 0,
		"Bacteria" => 0,
		"Viruses" => 0,
		"Fungi" => 0,
		"unassigned" => 0,
		"other" => 0,
		"Phage" => 0,
		);

    # category => num of sequence assigned to this category by tblastx_nt
    my %tblastx_nt = ();
    foreach my $key (keys %blastn) {
        $tblastx_nt{$key} = 0;
    }

    # category => num of sequence assigned to this category by tblastx of viral genome
    my %tblastx_VG = ();
    foreach my $key (keys %blastn) {
        $tblastx_VG{$key} = 0;
    }

    # category => num of sequence assigned to this category by blastn of human genome
    my %blastn_HG = ();
    foreach my $key (keys %blastn) {
        $blastn_HG{$key} = 0;
    }

    # viral_lineage => number of reads assigned to this lineage in the library
    my %num_reads = ();
    my %blast_readinfo =();    # readID => information about this read
    my %lineage_blastn = ();    # lineage => [read ID]
    my %lineage_tblastx_nt = ();    # lineage => [read ID]
    my %lineage_tblastx_VG = (); # lineage => [read ID]

    opendir(DH, $dir) or die "Can not open dir $dir!\n";
    foreach my $name (readdir DH) 
    {
        # name is either file name or directory for splited files
        my $full_path = $dir."/".$name;
    
        # full_path= dir/goodSeq_HGblast
        if ($name =~ /goodSeq_HGblast$/) 
        { # human genome blast result
	    # enter subdirectory where blastn results resides
	    opendir (HGDIR, $full_path) or die "can not open dir $full_path!\n";
	    foreach my $blast_file (readdir HGDIR) 
            {
	        if ($blast_file =~ /HGblast\.parsed$/) 
                {
		    my $parsed = $full_path."/".$blast_file;
		    open (IN, $parsed) or die "can not open file $parsed!\n";
		    while (<IN>) 
                    {
		        if ($_ =~ /#/) 
                        { # skip comment line
			    next;
		        }
		        chomp;
		        my ($read_ID, $length, $category, $lineage, $hit_name, $e_value) = split("\t", $_);
		        $blastn_HG{"Homo"}++; 
		    }   	
		    close IN;
	        }
	    }
	    closedir HGDIR;
        } # finish .HGblast.parsed


        # full_path= dir/HGfiltered_BLASTN
        if ($name =~ /HGfiltered_BLASTN$/) 
        {
	    # enter subdirectory where blastn results resides
	    opendir (BNDIR, $full_path) or die "can not open dir $full_path!\n";
	    foreach my $blast_file (readdir BNDIR) 
            {
	        if ($blast_file =~ /blastn\.parsed$/) 
                {
		    my $blast_out = $blast_file;
		    $blast_out =~ s/\.blastn\.parsed/\.blastn\.out/;
		    $blast_out = $full_path."/".$blast_out;
		    push @blast_files_blastn, $blast_out;
		    my $parsed = $full_path."/".$blast_file;
		    $self->collect_information($parsed, \%blastn, \%viral_reads_blastn, \%best_e_blastn, \%lineage_blastn, \%num_reads, \@unassigned_reads);
	    }
	}
	closedir BNDIR;
    } # finish .blastn.parsed
    
    # full_path= dir/BNFiltered_TBLASTX_nt
    if ($name =~ /BNFiltered_TBLASTX_nt$/) 
    {
	# enter subdirectory where tblastx nt results resides
	opendir (TBLASTXDH, $full_path) or die "can not open dir $full_path!\n";
	foreach my $tblastx_file (readdir TBLASTXDH) 
        {
	    if ($tblastx_file =~ /tblastx\.parsed$/) 
            {
		my $tblastx_out = $tblastx_file;
		$tblastx_out =~ s/\.tblastx\.parsed/\.tblastx\.out/;
		$tblastx_out = $full_path."/".$tblastx_out;
		push @blast_files_tblastx_nt, $tblastx_out;
		
		my $parsed = $full_path."/".$tblastx_file;
		$self->collect_information($parsed, \%tblastx_nt, \%viral_reads_tblastx_nt, \%best_e_tblastx_nt, \%lineage_tblastx_nt, \%num_reads, \@unassigned_reads);
	    }
	}
	closedir TBLASTXDH;
    } # finish BNFiltered_TBLASTX subdirectory
    
    # full_path= dir/TBXNTFiltered_TBLASTX_ViralGenome
    if ($name =~ /TBXNTFiltered_TBLASTX_ViralGenome$/) 
    {
	# enter subdirectory where tblastxi Viral Genome results resides
	opendir (TBLASTXDHVG, $full_path) or die "can not open dir $full_path!\n";
	foreach my $tblastx_file (readdir TBLASTXDHVG) 
        {
	    if ($tblastx_file =~ /tblastx_ViralGenome\.parsed$/) 
            {
		my $tblastx_out = $tblastx_file;
		$tblastx_out =~ s/\.tblastx_ViralGenome\.parsed/\.tblastx_ViralGenome\.out/;
		$tblastx_out = $full_path."/".$tblastx_out;
		push @blast_files_tblastx_VG, $tblastx_out;
		
		my $parsed = $full_path."/".$tblastx_file;
		$self->collect_information($parsed, \%tblastx_VG, \%viral_reads_tblastx_VG, \%best_e_tblastx_VG, \%lineage_tblastx_VG, \%num_reads, \@unassigned_reads);
	    } # finish tblastx_ViralGenome.parsed
	}
	closedir TBLASTXDHVG;
    }
  } 

    close DH;

    # get detailed information about each viral read
    $self->get_viral_read_info( \@blast_files_blastn, "blastn", \%viral_reads_blastn, \%best_e_blastn, \%blast_readinfo);
    $self->get_viral_read_info( \@blast_files_tblastx_nt, "tblastx", \%viral_reads_tblastx_nt, \%best_e_tblastx_nt, \%blast_readinfo);
    $self->get_viral_read_info( \@blast_files_tblastx_VG, "tblastx", \%viral_reads_tblastx_VG, \%best_e_tblastx_VG, \%blast_readinfo);

    # print out report for this library
    print OUT1 $dir, "\n";
    printf OUT1 "%12s\t%7s\t%7s\t%7s\t%7s\t%7s\n", "category", "total", "BN_HG", "BN", "TBX_nt", "TBX_VG";

    foreach my $key (sort {$a cmp $b } keys %blastn) 
    {
	printf OUT1 "%12s\t%7d\t%7d\t%7d\t%7d\t%7d\n", $key, $blastn_HG{$key}+$blastn{$key}+$tblastx_nt{$key}+$tblastx_VG{$key}, $blastn_HG{$key}, $blastn{$key}, $tblastx_nt{$key}, $tblastx_VG{$key};
    }

    print OUT1 "\n###########################################################\n\n";

    foreach my $lineage (sort {$num_reads{$a} <=> $num_reads{$b}} keys %num_reads) 
    {
        print OUT1 $lineage, "\ttotal number of reads: ", $num_reads{$lineage}, "\n\n";
        print OUT1 "QueryName\tQuerylength\t         HitName       \tHitLen\t                             HitDesc                       \tAlnLen\t%ID\tHitStart\tHitEnd\te\n";
    
        if (defined $lineage_blastn{$lineage}) 
        {
	    if (scalar @{$lineage_blastn{$lineage}}) 
            {
	        print OUT1 "reads from blastn:\n";
	        foreach my $read (@{$lineage_blastn{$lineage}}) 
                {
		    print OUT1 $blast_readinfo{$read};
	        }
	    }
        }
        if (defined $lineage_tblastx_nt{$lineage}) 
        {
	    if (scalar @{$lineage_tblastx_nt{$lineage}}) 
            {
	        print OUT1 "\nreads from tblastx:\n";
	        foreach my $read (@{$lineage_tblastx_nt{$lineage}}) 
                {
		    print OUT1 $blast_readinfo{$read};
	        }
	    }	
        }
        if (defined $lineage_tblastx_VG{$lineage}) 
        {
	    if (scalar @{$lineage_tblastx_VG{$lineage}}) 
            {
	        print OUT1 "\nreads from tblastx of viral genome:\n";
	        foreach my $read (@{$lineage_tblastx_VG{$lineage}}) 
                {
		    print OUT1 $blast_readinfo{$read};
	        }
	    }	
        }
    
        print OUT1 "\n##################################################\n\n";
    }

    # get all the viral reads and put into output file:
    # ViralReads_blastn.fa, ViralReads_tblastx.fa, ViralReads_all.fa
    foreach my $lineage (keys %num_reads) 
    {
        foreach my $read (@{$lineage_blastn{$lineage}}) 
        {
	    print OUT2 ">$read\n";
	    print OUT2 $seq{$read}, "\n";
        }
        foreach my $read (@{$lineage_tblastx_nt{$lineage}}) 
        {
	    print OUT2 ">$read\n";
	    print OUT2 $seq{$read}, "\n";
        }
        foreach my $read (@{$lineage_tblastx_VG{$lineage}}) 
        {
	    print OUT2 ">$read\n";
	    print OUT2 $seq{$read}, "\n";
        }
    }   	

    # get all unassigned reads
    foreach my $read (@unassigned_reads) 
    {
        print OUT3 ">$read\n";
        print OUT3 $seq{$read}, "\n";
    }	

    $self->log_event("Assignment Reporting completed");

    return 1;
}

sub collect_information 
{
    my ($self,$infile, $category_hash_ref, $viral_reads_hash_ref, $best_e_hash_ref, $lineage_hash_ref, $num_reads_hash_ref, $unassigned_reads_arr_ref) = @_;
    
    open (IN, $infile) or die "can not open file $infile!\n";
    while (<IN>) {
	if ($_ =~ /#/) { # skip comment line
	    next;
	}
	chomp;
	my ($read_ID, $length, $category, $lineage, $hit_name, $e_value) = split("\t", $_);
	switch ($category ) {
	    case "Homo" { $category_hash_ref->{"Homo"}++ }
	    case "Mus" { $category_hash_ref->{"Mus"}++ }
	    case "Bacteria" { $category_hash_ref->{"Bacteria"}++	}
	    case "Viruses" { $category_hash_ref->{"Viruses"}++ }
	    case "Fungi" { $category_hash_ref->{"Fungi"}++ }
	    case "unassigned" {$category_hash_ref->{"unassigned"}++}
	    case "other" {$category_hash_ref->{"other"}++ }
	    case "Phage" {$category_hash_ref->{"Phage"}++ }
	}
	
	if ($category eq "Viruses") {
	    $viral_reads_hash_ref->{$read_ID} = 1;
	    $best_e_hash_ref->{$read_ID} = $e_value;
	    if (!(defined $lineage_hash_ref->{$lineage})) {
		$lineage_hash_ref->{$lineage} = [$read_ID];
	    }
	    else {
		push @{$lineage_hash_ref->{$lineage}}, $read_ID;
	    }
	    
	    if (defined $num_reads_hash_ref->{$lineage}) {
		$num_reads_hash_ref->{$lineage}++;
	    }
	    else {
		$num_reads_hash_ref->{$lineage} = 1;
	    }
	}			
	elsif ($category eq "unassigned") {
	    push @{$unassigned_reads_arr_ref}, $read_ID;
	}
    }
    close IN;
}

sub read_FASTA_data () 
{
    my ($self,$fastaFile) = @_;

    #keep old read seperator and set new read seperator to ">"
    my $oldseperator = $/;
    $/ = ">";
	 
    my %fastaSeq;	 
    open (FAfile, $fastaFile) or die "Can't Open FASTA file: $fastaFile";
    while (my $line = <FAfile>){
	# Discard blank lines
        if ($line =~ /^\s*$/) {
	    next;
		}
		# discard comment lines
		elsif ($line =~ /^\s*#/) {
	       next;
	   }
		# discard the first line which only has ">", keep the rest
		elsif ($line ne ">") {
		    chomp $line;
		    my @rows = ();
		    @rows = split (/\n/, $line);	
		    my $temp = shift @rows;
			my @temp = split(/\s+/, $temp);
			my $name = shift @temp;
		    my $Seq = join("", @rows);
		    $Seq =~ s/\s//g; #remove white space
		    $fastaSeq{$name} = $Seq;
		}
    }

    #reset the read seperator
    $/ = $oldseperator;
    close FAfile;

    return %fastaSeq;
}

sub get_viral_read_info {
    my ($self,$report_file_ref, $report_type, $viral_reads_hash_ref, $best_e_hash_ref, $blast_readinfo_hash_ref) = @_;
    my $report; # blast report object
    foreach my $file (@{$report_file_ref}) {
	$report = new Bio::SearchIO(-format => 'blast', -file => $file, -report_type => $report_type);
	# Go through BLAST reports one by one        
	while(my $result = $report->next_result) {# next query output
	    my $read_ID = $result->query_name;
	    if (defined $viral_reads_hash_ref->{$read_ID}) {
		my $desc = "";
		while (my $hit = $result->next_hit()) {
		    if ($hit->significance() == $best_e_hash_ref->{$read_ID}) {
			$desc .= $result->query_name()."\t";
			$desc .= $result->query_length()."\t";
			$desc .= $hit->name()."\t";
			$desc .= $hit->length()."\t";
			$desc .= $hit->description(60)."\t";
			while (my $hsp = $hit->next_hsp()) {
			    $desc .= $hsp->length('hit')."\t";
			    my $percent_id = sprintf("%4.1f", $hsp->percent_identity());
			    $desc .= $percent_id."\%\t[";
			    $desc .= $hsp->start('hit')."\t";
			    $desc .= $hsp->end('hit')."]\t";
			    $desc .= $hsp->evalue()."\n";
			    last;
			}
		    }
		}
		$blast_readinfo_hash_ref->{$read_ID} = $desc;
	    }
	}
    }
}
1;

