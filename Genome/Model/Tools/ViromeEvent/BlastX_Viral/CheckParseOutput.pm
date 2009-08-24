
package Genome::Model::Tools::ViromeEvent::BlastX_Viral::CheckParseOutput;

use strict;
use warnings;

use Genome;
use Workflow;
use IO::File;
use Bio::SearchIO;
use Bio::Taxon;
use Bio::DB::Taxonomy;
use Bio::Tree::Tree;
use DBI();
use File::Temp;

class Genome::Model::Tools::ViromeEvent::BlastX_Viral::CheckParseOutput{
    is => 'Genome::Model::Tools::ViromeEvent',
};

sub help_brief {
    return "gzhao's Blast X Viral check parse output";
}

sub help_synopsis {
    return <<"EOS"
This script will check all .tblastx_ViralGenome.parsed file in the 
BNfiltered_TBLASTX_ViralGenome subdirectory of the given directory to make sure 
parsing tblastx output file is finished for each file.

perl script <sample dir>
<sample dir> = full path to the folder holding files for a sample library 
	without last /";
EOS
}

sub help_detail {
    return <<"EOS"
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
    $self->log_event("Blast X viral check parse output entered");
    my $dir = $self->dir;

    my @temp_dir_arr = split("/", $dir);
    my $lib_name = $temp_dir_arr[$#temp_dir_arr];
    my $directory_job_file = $dir."/".$lib_name.".job";

    my $allFinished = 1;
    my $have_tblastx_out = 0;
    my $matches = 0;
    opendir(DH, $dir) or die "Can not open dir $dir!\n";
    foreach my $name (readdir DH) 
    {
        if ($name =~ /TBXNTFiltered_TBLASTX_ViralGenome$/) 
        { # tblastx directory
            $matches++;
            $self->log_event("$name matches");
	    my $full_path = $dir."/".$name;
	    opendir(SubDH, $full_path) or die "can not open dir $full_path!\n";
	    foreach my $file (readdir SubDH) 
            { 
	        if ($file =~ /\.tblastx_ViralGenome\.out$/) 
                {
		    $have_tblastx_out = 1;
		    my $have_blast_parsed = 0;
		    my $finished = 0;
		
		    my $temp_name = $file;
		    $temp_name =~ s/\.tblastx_ViralGenome\.out//;
		    my $blast_parsed_file = $full_path."/".$temp_name.".tblastx_ViralGenome.parsed";
		    if (-s $blast_parsed_file) 
                    {
		        $have_blast_parsed = 1;
		        $finished = $self->check_tblastxParsed_output($blast_parsed_file);
		    }

		    if ((!$have_blast_parsed)||(!$finished)) 
                    {
		        $allFinished = 0;
		        $self->log_event($file, " does not have tblastx.parsed or not finished! Resubmit the job!\n");

		        my $com = "perl /gsc/var/tmp/virome/scripts/scripts2/Process454_S8_TBLASTX_ViralGenome_2_parser.pl $full_path $file";
                        $self->log_event("calling [$com] - by function");
                        $self->viral_genome_parse($full_path, $file);
		        #my $ec = system($com);
		        #if ($ec) 
                        #{
			#    $self->log_event("Failed system call:\n $com\n");
			#    my $ec = $self->clean_up_tmp_dir();
			#    $self->log_event("Failed to clean up tmp dir\n") if ! $ec;
			#    return 0;
		        #}
		    }
	        }
	    }
        }
    }

#close BigJobFile;

    if ($have_tblastx_out) 
    {
        if ($allFinished ) 
        {
    	    $self->log_event("Parsing tblastx all finished!\n");
	    my $ec = $self->clean_up_tmp_dir();
	    $self->log_event("Failed to clean up tmp dir\n") if ! $ec;
	   return 0; 
        }
    }
    else 
    {
        die("$dir does not have input file!\n");
    }
    $self->log_event("Blast  X viral check parse output completed with $matches matches");
    return 1;
}

sub check_tblastxParsed_output {
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

	# deal with situation where all records showed as undefined taxon
	my $num_phylogypted = $total_seq - $saved_seq; 
        if ( ($num_phylogypted ne 0) && ($num_phylogypted <= $num_undefined_taxon)) { 
		return 0;
        }


	# taxonomy record has to be equal or greater than the number of sequences get 
	# successful phylotyped because some sequence could be assigned multiple taxonomy
	# categories.
	# at this step, every sequence's assignment information should be there even with
	# unassigned. So record number has to be >+ total sequence
        if (($line_count -2 ) < $total_seq ) {
                return 0;
        }

        return 1;
}

sub clean_up_tmp_dir {
    my $path = '/tmp/' . $ENV{USER};
    unlink $path . 'nodes', $path . 'parents', $path . 'names2id', $path . 'id2names';
    return 1;
}

sub viral_genome_parse
{   
    #manual implementation of /gsc/var/tmp/virome/scripts/scripts2/Process454_S8_TBLASTX_ViralGenome_2_parser.pl
    my ($self,$dir, $blastout) = @_;
    $self->log_event("in viral genome parse");

    my $HOME = $ENV{HOME};
    my $E_cutoff = 1e-5;
    my $database_dir = "/srv/cgs/data/taxdump";

    my @unassigned = (); # query should be kept for further analysis
    my $total_records = 0;

    # open a connection to mysqls database
    my $dbh_sqlite = DBI->connect("dbi:SQLite:/gscmnt/sata835/info/medseq/virome/taxonomy_db");

    # create ouput file
    my $inFile = $dir."/".$blastout;
    my $outFile = $blastout;
    $outFile =~ s/tblastx_ViralGenome\.out/tblastx_ViralGenome.parsed/;
    $outFile = $dir."/".$outFile;
    open (OUT, ">$outFile") or die "can not open file $outFile!\n";

    # get a Taxon from a Bio::DB::Taxonomy object
    my $tax_dir = File::Temp::tempdir (CLEANUP => 1);
    my $dbh = Bio::DB::Taxonomy->new(-source => 'flatfile',
				 -directory=> "$tax_dir",
				 -nodesfile=> '/gscmnt/sata835/info/medseq/virome/taxonomy/nodes.dmp',
				 -namesfile=> '/gscmnt/sata835/info/medseq/virome/taxonomy/names.dmp',);

    $self->log_event("parsing blast output files...dbh:  $dbh\n");
    my $report = new Bio::SearchIO(-format => 'blast', -file => $inFile, -report_type => 'tblastx');


    print OUT "QueryName\tQueryLen\tAssignment\tlineage\tHit\tSignificance\n";

    # Go through BLAST reports one by one      
    while(my $result = $report->next_result) {# next query output
        $total_records++;
        my $haveHit = 0;
        my $have_significant_hit = 0;
        my %assignment = ();
        my $assigned = 0;
	
	# only take the best hits
        my $best_e = 100;
        my $hit_count = 0;
        my $determined = 0;
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

	    if ($hit->significance <= $E_cutoff){ # similar to known, need Phylotyped
	        my $have_significant_hit = 1;
	        if ($hit->significance == $best_e) {
		    # from gi get taxonomy lineage
		    my $sth = $dbh_sqlite->prepare("SELECT * FROM gi_taxid where gi = $gi");
		    $sth->execute();
		    my $ref = $sth->fetchrow_hashref();
		
		    $sth->finish();
		    my $taxID = $ref->{'taxid'};
		    if ($taxID) { # some gi don't have record in gi_taxid_nucl, this is for situation that has
		        my $taxon_obj = $dbh->get_taxon(-taxonid => $taxID);
		        if (!(defined $taxon_obj)) {
			    my $description .= "undefined taxon\t".$hit->name."\t".$hit->significance;
			    $assignment{"Viruses"} = $description;
		        }
		        else 
                        {
			    my $tree_function = Bio::Tree::Tree->new();
			    my @lineage = $tree_function->get_lineage_nodes($taxon_obj);
			    # each lineage node is a Bio::Tree::NodeI object
			    if (scalar @lineage) {				
			        $determined = 1;
			        $self->PhyloType(\@lineage,$hit, $best_e, $dbh_sqlite, $dbh, \%assignment);
			    }
		        }
		    }
		    else { # for situations that gi does not have corresponding taxid
		        my $desc = $hit->description."\t".$hit->name."\t".$hit->significance;
		        $determined = 1;
		        $assignment{"Viruses"} = $desc;
		    }
	        }
	        else { # significant but does not have the same e value as the first best hit
		    last; # skip the rest significant hits 
	        }
	    }
	    else { # E value is not significant enough
	        if($determined){ # skip the rest hits that are not significant
		    last;
	        }
	        else {
		    my $desc = "hit not significant\t".$hit->name."\t".$hit->significance;
		    $assignment{"unassigned"} = $desc;
		    last;
	        }
	    }
        } # end with all hits

        if (!$haveHit) {
	    $assignment{"unassigned"} = "no hit";
        }

	# print out assignment
        foreach my $assign (keys %assignment) {
	    if ($assign eq "unassigned") {
	        print OUT $result->query_name, "\t", $result->query_length, "\t", $assign, "\t", $assignment{$assign}, "\n";
	        push @unassigned, $result->query_name;
	    }
	    else {
	        print OUT $result->query_name, "\t", $result->query_length, "\t", $assign, "\t", $assignment{$assign}, "\n";
	    }
        }
    } # end of report parsing
    print OUT "# Summary: ", scalar @unassigned, " out of $total_records ", (scalar @unassigned)*100/$total_records, "% is unassigned.\n";


    $dbh_sqlite->disconnect();
}
		
############################################
sub PhyloType {
	my ($self,$lineage_ref, $hit_ref, $best_e, $dbh_sqlite, $dbh_taxonomy, $assignment_ref) = @_;
	my $description = "";
	my $node_id; 
	my $obj;
	my $name;
	my $assigned = 0;

        $self->log_event("in PhyloType");

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
					$description = "Homo\t".$hit_ref->name."\t".$hit_ref->significance;
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
						$description = "Mus\t".$hit_ref->name."\t".$hit_ref->significance;
						$assignment_ref->{"Mus"} = $description;
						$assigned = 1;
						last;
					}
				}
			}
			if (!$assigned) {
				$description = $Lineage."\t".$hit_ref->name."\t".$hit_ref->significance;
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


############################################################################
sub read_FASTA_data () {
    my ($self,$fastaFile) = @_;

    $self->log_event("in read_FASTA_data");

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

1;

