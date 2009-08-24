
package Genome::Model::Tools::ViromeEvent::BlastN::CheckParseOutput;

use strict;
use warnings;

use Genome;
use Workflow;
use IO::File;
use File::Temp;

class Genome::Model::Tools::ViromeEvent::BlastN::CheckParseOutput{
    is => 'Genome::Model::Tools::ViromeEvent',
};

sub help_brief {
    return "gzhao's Blast N check parse output";
}

sub help_synopsis {
    return <<"EOS"
EOS
}

sub help_detail {
    return <<"EOS"
This script will check all .tblastx.parsed file in the .BNfiltered_TBLASTX
subdirectory of the given directory to make sure parsing blastn output 
file is finished for each file.

perl script <sample dir>
<sample dir> = full path to the folder holding files for a sample library 
	without last "/"
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
    $self->log_event("Blast N check parse output entered");
    my $dir = $self->dir;

    my @temp_dir_arr = split("/", $dir);
    my $lib_name = $temp_dir_arr[$#temp_dir_arr];
    my $com = "";


    my $allFinished = 1;
    my $have_input_file = 0;
    my $matches = 0;
    opendir(DH, $dir) or die "Can not open dir $dir!\n";
    foreach my $name (readdir DH) 
    {
        if ($name =~ /.HGfiltered_BLASTN$/) 
        { # blastn directory
	    my $full_path = $dir."/".$name;
	    opendir(SubDH, $full_path) or die "can not open dir $full_path!\n";
	    foreach my $file (readdir SubDH) 
            { 
	        if ($file =~ /\.blastn\.out$/) 
                {
		    $have_input_file = 1;
		    my $have_blastn_parsed = 0;
		    my $finished = 0;
		
		    my $temp_name = $file;
		    $temp_name =~ s/\.blastn\.out//;
		    my $blastn_parsed_file = $full_path."/".$temp_name.".blastn.parsed";
		    if (-s $blastn_parsed_file) 
                    {
		        $have_blastn_parsed = 1;
		        $finished = $self->check_blastnParsed_output($blastn_parsed_file);
		    }
		
		    if ((!$have_blastn_parsed)||(!$finished)) 
                    {
		        $allFinished = 0;
		        print $file, " does not have blastn.parsed or not finished! Resubmiting the job!\n\n";
		        $self->log_event("$file does not have blastn.parsed or not finished! Resubmiting the job!\n\n");
		    
		        #$com = '/gsc/var/tmp/virome/scripts/scripts2/Process454_S6_Blastn_2_parser.pl '.$full_path.' '.$file;
                        #system($com);

                        $self->run_parser($full_path, $file);

		        #use PP::LSF;
		        #my $job = PP::LSF->run ( pp_type => 'lsf',
			#		     command => $com,
			#		     J => 'BstNTprs',
			#		     q => 'long',
                        #                     R => "'select[type==LINUX64] span[hosts=1]'",);
		        #if (! $job) 
                        #{
			#    die("Failed to submit job:\n $com\n");
		        #}
		    }
	        }
	    }
        }
    }

#close BigJobFile;

    if ($have_input_file) 
    {
        if ( $allFinished) 
        {
	    $self->log_event("parsing blastn all finished!\n");
	    return 0;
        }
    }
    else 
    {
        die("$dir does not have input file!\n");
    }

    while (1) 
    {
        $self->log_event("Checking to see if MaskRepeats bjobs are done .. every 45 sec\n");
        sleep (45);
        my $all_done = 1;
        my @bjobs = `bjobs`;
        foreach my $job (@bjobs) 
        {
            next if $job =~ /^JOBID/;
	    my @tmp = split (/\s+/, $job);
        	if ($tmp[-4] =~ /BstNTprs/) 
                { #JOB NAME
	            $all_done = 0;
	        }
        }
        if ($all_done == 1) 
        {
	    $self->log_event("All jobs done");
        	#CHECK #OF *fa FILES AGAINST *masked TO VERIFY THAT THEY'RE THE SAME
            return 0;
        }


        $self->log_event("Blast N check parse output completed with $matches matches");
        return 1;
    }
}

sub check_blastnParsed_output {
	my ($self, $in_file ) = @_;
	my $have_summary_line = 0;
	my $line_count = 0;
	my $total_seq = 0;
	my $saved_seq = 0;
	my $num_undefined_taxon = 0;
	
	open (TEMP, "<$in_file") or die "can not open file $in_file!\n";
	while (my $line = <TEMP>) {
		$line_count++;
		if ($line =~ /# Summary: (\d+) out of (\d+)/) {
			$saved_seq = $1; 
			$total_seq = $2;
			$have_summary_line = 1;
		}
		if ($line =~ /undefined taxon/) {
			$num_undefined_taxon++;
		}
	}
	close TEMP;

	if (!$have_summary_line) {
		return 0;
	}

	# taxonomy record has to be equal or greater than the number of sequences get 
	# successful phylotyped because some sequence could be assigned multiple taxonomy
	# categories. Should have at least at least $num_phylotyped + 1 lines
	my $num_phylotyped = $total_seq - $saved_seq;	
	if ( $num_phylotyped == 0 ) { # every sequence is unassigned
		return 1;
	}
	# deal with situation where all records showed as undefined taxon and relative 
	# to humber of phylotyped sequences
	elsif ( $num_phylotyped <= $num_undefined_taxon) { 
		return 0;
	}

	if ( ($line_count - 1) == $num_undefined_taxon) { # deal with situation where all records showed as undefined taxon
		return 0;
	}

	# deal with old situation where some read was not recorded because of no 
	# record of gi-taxon record in the database 
	if ($num_phylotyped > ($line_count -1 ) ) {
		return 0;
	}

	return 1;
}

sub run_parser
{
    my ($self,$dir,$blastout) = @_;

    $self->log_event("run_parser entered");

    # cutoff value for having a good hit
    my $E_cutoff = 1e-10;

    # open a connection to mysql database

    my $dbh_sqlite = DBI->connect("dbi:SQLite:/gscmnt/sata835/info/medseq/virome/taxonomy_db");

    # create ouput file
    my $outFile = $blastout;
    $outFile =~ s/blastn\.out/blastn.parsed/;
    $outFile = $dir."/".$outFile;
    open (OUT, ">$outFile") or die "can not open file $outFile!\n";

    # get a Taxon from a Bio::DB::Taxonomy object
    my $tax_dir = File::Temp::tempdir (CLEANUP => 1);
    my $dbh = Bio::DB::Taxonomy->new(-source => 'flatfile',
				 -directory=> "$tax_dir",
				 -nodesfile=> '/gscmnt/sata835/info/medseq/virome/taxonomy/nodes.dmp',
				 -namesfile=> '/gscmnt/sata835/info/medseq/virome/taxonomy/names.dmp',);

    my @keep_for_tblastx = (); # query should be kept for further analysis
    my @known = (); # queries that are significantly similar to known sequences
    my $total_records = 0;

    $self->log_event("parsing blast output files...");

    my $input_file = $dir."/".$blastout;
    my $report = new Bio::SearchIO(-format => 'blast', -file => $input_file, -report_type => 'blastn');

    # Go through BLAST reports one by one        
    while(my $result = $report->next_result) {# next query output

	$total_records++;
	my $haveHit = 0;
	my $keep_for_tblastx = 1;
	my %assignment = ();

	# only take the best hits
	my $best_e = 100;
	my $hit_count = 0;
	

	while(my $hit = $result->next_hit) {
		# from hit name get hit gi number
		my $hit_name = $hit->name; # gi|num|database|accessionNum|
		my @temp_arr = split(/\|/, $hit_name);
		my $gi = $temp_arr[1];
		
		if ($temp_arr[2] eq "pdb") { # skip data from pdb database
			next;
		}
		$haveHit = 1;
		$hit_count++;
		if ($hit_count == 1) {
			$best_e = $hit->significance;
		}

		# check whether the hit should be kept
		if ($best_e <= $E_cutoff) { # similar to known, need Phylotyped
			$keep_for_tblastx = 0;

			if ($hit->significance == $best_e) { # only get best hits
				# from gi get taxonomy lineage
				my $sth = $dbh_sqlite->prepare("SELECT * FROM gi_taxid where gi = $gi");
				$sth->execute();
				my $ref = $sth->fetchrow_hashref();
				
				$sth->finish();
				my $taxID = $ref->{'taxid'};
				if ($taxID) { # some gi don't have record in gi_taxid_nucl
					my $taxon_obj = $dbh->get_taxon(-taxonid => $taxID);
					if (!(defined $taxon_obj)) {
						my $description = "undefined taxon ".$hit->description."\t".$hit->name."\t".$hit->significance;
						$assignment{"other"} = $description;
					}
					else {
						my $tree_function = Bio::Tree::Tree->new();
						my @lineage = $tree_function->get_lineage_nodes($taxon_obj);
						# each lineage node is a Bio::Tree::NodeI object
						if (scalar @lineage) {				
							$self->PhyloType(\@lineage,$hit, $best_e, $dbh_sqlite, $dbh, \%assignment);
						}
					}
				}	
				else { # for situations that gi does not have corresponding taxid
					my $desc = $hit->description."\t".$hit->name."\t".$hit->significance;
					$assignment{"other"} = $desc;
				} 
			}
			else {
				last;
			}
		} # finish phylotype for given hit
	}  # finish all hits

	# consolidate assignment
	# If a query is assigned both Homo and Primates, it will be reported as Homo only
	# If a query is assigned a real taxon name and "other" for reason like"other sequences;
	# artificial sequences", or no taxon id in taxon database it will be reported only as 
	# the real taxon name
	my $num_assignment = keys %assignment;
	if ($num_assignment > 1) { # have multiple assignment
		# handle the situation that assigned both a specific category and "other"
		# only specific category will be save.
		my $has_specific = 0;
		my $has_other = 0;
		if ((defined $assignment{"Bacteria"}) || (defined $assignment{"Fungi"}) || (defined $assignment{"Homo"}) || (defined $assignment{"Mus"}) || (defined $assignment{"Phage"}) || (defined $assignment{"Viruses"})) {
			$has_specific = 1;
		}
		if (defined $assignment{"other"}) {
			$has_other = 1;
		}
		if ($has_specific && $has_other) {
			delete $assignment{"other"}; 
		}
	}

	# print out assignment for this query
	foreach my $assign (keys %assignment) {
		print OUT $result->query_name, "\t", $result->query_length, "\t", $assign, "\t", $assignment{$assign}, "\n";

	}
	
	if ($keep_for_tblastx) {
		push @keep_for_tblastx, $result->query_name;
	}	
	else {		
		push @known, $result->query_name;
	}
    }
    print OUT "# Summary: ", scalar @keep_for_tblastx, " out of $total_records ", scalar @keep_for_tblastx/$total_records, " is saved for TBLASTX analysis.\n";

    close OUT;

    # generate a fasta file that contains all the sequences that do not match
    # to known sequences
    # read in blastn input sequences
    my $file = $blastout;
    $file =~ s/\.blastn\.out//;
    $file = $dir."/".$file.".fa";
    my %seq = $self->read_FASTA_data($file);

    $outFile = $blastout;
    $outFile =~ s/\.blastn\.out//;
    $outFile = $dir."/".$outFile.".BNfiltered.fa";
    open (OUT2, ">$outFile") or die "can not open file $outFile!\n";
    foreach my $seq_name (@keep_for_tblastx) {
	print OUT2 ">$seq_name\n";
	print OUT2 $seq{$seq_name}, "\n";
    }
    close OUT2;

    $dbh_sqlite->disconnect();
}

############################################################################
sub read_FASTA_data () {
    my ($self,$fastaFile) = @_;

    #keep old read seperator and set new read seperator to ">"
    my $oldseperator = $/;
    $/ = ">";
	 
    my %fastaSeq;	 
    open (fastaFile, $fastaFile) or die "Can't Open FASTA file: $fastaFile";

    while (my $line = <fastaFile>){
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
	    @rows = split (/\s/, $line);	
	    my $contigName = shift @rows;
	    my $contigSeq = join("", @rows);
	    $contigSeq =~ s/\s//g; #remove white space
	    $fastaSeq{$contigName} = $contigSeq;
	}
    }

    # execute right

    #reset the read seperator
    $/ = $oldseperator;
    
    return %fastaSeq;
}

	
############################################
sub PhyloType {
	my ($self,$lineage_ref, $hit_ref, $best_e, $dbh_sqlite, $dbh_taxonomy, $assignment_ref) = @_;
	my $description = "";
	my $node_id; 
	my $obj;
	my $name;
	my $assigned = 0;

	my $Lineage = "";
	for (my $i = 0; $i <= $#$lineage_ref; $i++) { 
		my $temp_node_id = $lineage_ref->[$i]->id;
		my $temp_obj = $dbh_taxonomy->get_taxon(-taxonid=>$temp_node_id);
		my $temp_name = $temp_obj->scientific_name;
		$Lineage .= $temp_name.";";
	}					

	# check to see if it is a human sequence
	if (scalar @{$lineage_ref} >= 4) {
		$node_id = $lineage_ref->[3]->id;
		$obj = $dbh_taxonomy->get_taxon(-taxonid=>$node_id);
		$name = $obj->scientific_name;
		if ($name eq "Metazoa") {
			# make assignment
			for (my $i = 0; $i <= $#$lineage_ref; $i++) { 
				my $temp_node_id = $lineage_ref->[$i]->id;
				my $temp_obj = $dbh_taxonomy->get_taxon(-taxonid=>$temp_node_id);
				my $temp_name = $temp_obj->scientific_name;
				if ($temp_name eq "Homo") {
					$description .= "Homo\t".$hit_ref->name."\t".$hit_ref->significance;
					$assignment_ref->{"Homo"} = $description;
					$assigned = 1;
					last;
				}
			}
			if (!$assigned) {
				for (my $i = 0; $i <= $#$lineage_ref; $i++) { 
					my $temp_node_id = $lineage_ref->[$i]->id;
					my $temp_obj = $dbh_taxonomy->get_taxon(-taxonid=>$temp_node_id);
					my $temp_name = $temp_obj->scientific_name;
	
					if ($temp_name eq "Mus") {
						$description .= "Mus\t".$hit_ref->name."\t".$hit_ref->significance;
						$assignment_ref->{"Mus"} = $description;
						$assigned = 1;
						last;
					}
				}
			}
			if (!$assigned) {
				$description .= $Lineage."\t".$hit_ref->name."\t".$hit_ref->significance;
				$assignment_ref->{"other"} = $description;
				$assigned = 1;
			}
		}
	}

	# check to see if it is bacteria sequence
	if ((scalar @{$lineage_ref} >= 2)&&(!$assigned)) {
		$node_id = $lineage_ref->[1]->id;
		$obj = $dbh_taxonomy->get_taxon(-taxonid=>$node_id);
		$name = $obj->scientific_name;
		if ($name eq "Bacteria") {
			$description = $Lineage."\t".$hit_ref->name."\t".$hit_ref->significance;
			$assignment_ref->{"Bacteria"} = $description;
			$assigned = 1;
		}
	}


	# check to see if it is a phage virus sequence
	if (!$assigned) {
		$node_id = $lineage_ref->[0]->id;
		$obj = $dbh_taxonomy->get_taxon(-taxonid=>$node_id);
		$name = $obj->scientific_name;
		if ($name eq "Viruses") {
			for (my $i = 0; $i <= $#$lineage_ref; $i++) { 
				my $temp_node_id = $lineage_ref->[$i]->id;
				my $temp_obj = $dbh_taxonomy->get_taxon(-taxonid=>$temp_node_id);
				my $temp_name = $temp_obj->scientific_name;
				$description .= $temp_name.";";
				if (($temp_name eq "Lipothrixviridae")||($temp_name eq "Caudovirales")||($temp_name eq "Corticoviridae")||($temp_name eq "Cystoviridae")||($temp_name eq "Inoviridae")||($temp_name eq "Leviviridae")||($temp_name eq "Microviridae")||($temp_name eq "Tectiviridae")||($temp_name =~ /phage/i)) {
					$description = $Lineage."\t".$hit_ref->name."\t".$hit_ref->significance;
					$assignment_ref->{"Phage"} = $description;
					$assigned = 1;
					last;
				}
			}
		}
	}


	# check to see if it is a virus sequence
	$description = "";
	if (!$assigned) {
		$node_id = $lineage_ref->[0]->id;
		$obj = $dbh_taxonomy->get_taxon(-taxonid=>$node_id);
		$name = $obj->scientific_name;
		if ($name eq "Viruses") {
			$description = $Lineage."\t".$hit_ref->name."\t".$hit_ref->significance;
			$assignment_ref->{"Viruses"} = $description;
			$assigned = 1;
		}
	}

	# check to see if it is a fungi sequence
	if ((scalar @{$lineage_ref} >= 4)&&(!$assigned)) {
		$node_id = $lineage_ref->[3]->id;
		$obj = $dbh_taxonomy->get_taxon(-taxonid=>$node_id);
		$name = $obj->scientific_name;
		if ($name eq "Fungi") {
			$description = $Lineage."\t".$hit_ref->name."\t".$hit_ref->significance;
			$assignment_ref->{"Fungi"} = $description;
			$assigned = 1;
		}
	}

	# if still not assigned, assigned to "other" category
	if (!$assigned) {
		$description = $Lineage."\t".$hit_ref->name."\t".$hit_ref->significance;
		$assignment_ref->{"other"} = $description;
		$assigned = 1;
	}
	
	return $assigned;
}
1;

