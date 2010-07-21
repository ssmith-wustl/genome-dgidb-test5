
package Genome::Model::Tools::Db::EnsemblTranscriptDownload;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::Db::EnsemblTranscriptDownload {
    is => 'Command',                       
    has_optional => [
        source => { is => 'Text' },
        version => { is => 'Text' },
        dev => { is => 'Boolean' }
    ],
};

sub sub_command_sort_position { 3 }

sub help_brief {     
    "export transcript and sub-structure data from Ensembl into file/db formats used by the annotation system"
}

sub help_synopsis { 
    return <<EOS
gmt db ensembl-transcript-download
EOS
}

sub help_detail {  
    return <<EOS 
This is a modularized version of Xiaoqi's script, formerly at:
/gscmnt/sata180/info/medseq/xshi/work/ensembldb/load_sd_ensembl.pl

It needs to be modified to put data directly into the file formats usd by the annotator.  Currently those files came from a DB dump done by the DBAs.
EOS
}

sub execute {      
    my $self = shift;
    print "NOT IMPLEMENTED.  FIX ME\n";   
    ## when this module is fixed please change $ARGV[0] to use
    #  a shell_args_position property instead.
    return;
    eval qq|
        use lib '/gsc/scripts/share/ensembl-45/ensembl/modules';
        use lib '/gsc/scripts/share/ensembl-45/ensembl-external/modules';
        use lib '/gsc/scripts/share/ensembl-45/ensembl-variation/modules';

        use Getopt::Long;
        use Carp;

        use Bio::EnsEMBL::Registry;
        use Bio::EnsEMBL::DBSQL::DBAdaptor;

        use MPSampleData::DBI;
        use MPSampleData::Gene;
        # use MPSampleData::Transcript;
        # use MPSampleData::Protein;
        # use MPSampleData::ProteinFeature;
        # use MPSampleData::TranscriptSubStructure;
    |;

# TODO: INDENT ME

MPSampleData::DBI::myinit("dbi:Oracle:dwrac","mguser_prd");
 
my $ensembl_host         = 'mysql2';
my $ensembl_user         = 'mse';
my $ensembl_release      = '45_36g';
my $registry = 'Bio::EnsEMBL::Registry';

my %options = (
                'source'         => undef,
                'dev'         => undef,
              );
my $verbose = undef;

$registry->load_registry_from_db(
    -host => $ensembl_host,
    -user => $ensembl_user,
#     -pass => 'c@nc3r'
);

    $options{source} = $self->source if defined $self->source;
    $options{dev} = $self->dev if defined $self->dev;
    $verbose = $self->version;
 
# example command line:
# load_sd_ensembl.pl --source ensembl/vega
# this should work --dev db_test
 
my $database_source;
$database_source='Core' if($options{'source'} eq 'ensembl');
$database_source='Vega' if($options{'source'} eq 'vega');
my $gene_adaptor =   $registry->get_adaptor('Human',$database_source,'Gene');
my $tr_adaptor =   $registry->get_adaptor('Human',$database_source,'Transcript');

#     my @transcript_ids = @{ $tr_adaptor->list_dbIDs };
#    print  scalar(@transcript_ids),"\n";
open (IN, "<$ARGV[0]") or die "Can't open $ARGV[0]. $!";
while(<IN>){
	chomp();
     my @transcripts = $tr_adaptor->fetch_by_stable_id($_); 
#start from number 4010-2 
#       my $count=0;
#          foreach (@transcript_ids){
#       $count++;
#     	print "\nnumber:$count\t";
#   next if($count<29968);
 
     foreach my $tr(@transcripts){
    
#            my $tr = $tr_adaptor->fetch_by_dbID($_); 
 
    my $biotype=$tr->biotype();
    if(!defined($biotype)) {$biotype="";}
    print "$biotype\t";
     if($biotype=~/pseudogene/) {print "\npesudotranscript\n"; next;}
# 	next unless($biotype=~/miRNA/);
#upload gene table
     my $gene = $gene_adaptor->fetch_by_transcript_id($tr->dbID);
     my $chromosome=$gene->slice()->seq_region_name();
     my ($gene_local_id)=$gene->stable_id;
      if($options{'source'} eq 'vega'){
      	my ($ensembl_tr)=$tr->get_all_DBLinks('ENST');
      	next  if(defined(@$ensembl_tr));
      }
 print "chro $chromosome strand",$gene->strand," gene:$gene_local_id \n";


       my $entrez_genes=$tr->get_all_DBLinks('EntrezGene');
       my ($hugo_name,$entrez_id);
       if(defined(@$entrez_genes)) {$hugo_name=@$entrez_genes[0]->display_id;$entrez_id=@$entrez_genes[0]->primary_id;}

     my $gene_db_id;
	
     $hugo_name=$gene_local_id;
     if(defined $hugo_name){
		my ($g)=MPSampleData::Gene->search("hugo_gene_name"=>$hugo_name);
		if(defined $g) {
			$gene_db_id=$g->gene_id;
		}
		else{	
			 my ($egi) = MPSampleData::ExternalGeneId->search("id_value"=>$hugo_name);
			 if(defined $egi){
				$gene_db_id=$egi->gene_id ;
			}
		}

	}
     unless(defined $gene_db_id){
		my %query=("hugo_gene_name"=>$hugo_name ,"strand"=>$gene->strand);
		my ($g)=MPSampleData::Gene->insert(\%query);
     		$gene_db_id=$g->gene_id;
	} 
=cut
     my ($egi) = MPSampleData::ExternalGeneId->find_or_create(
 			"gene_id"=>$gene_db_id,
 			"id_type"=>$options{'source'},	
 	);	
       $egi->set(
 			"id_value"=>$gene_local_id,
 	);
       $egi->update();
=cut
      my ($chrom)=MPSampleData::Chromosome->search("chromosome_name"=>$chromosome);
#upload transcript talbe
      my ($tscrpt) = MPSampleData::Transcript->search(
    			"transcript_name"=>$tr->stable_id,
  			"gene_id"=>$gene_db_id,
  			"source"=> $options{'source'},
  		       ); 
 
    	$tscrpt->set(
  			"transcript_start"=>$tr->start,
  			"transcript_stop"=>$tr->end,
    			"transcript_status"=>lc($tr->status),
     			"strand"=>$tr->strand,
  			"chrom_id"=>$chrom->chrom_id,
         			);
          $tscrpt->update();

#  my ($tscrpt)=MPSampleData::Transcript->search("transcript_name"=>$tr->stable_id); 
#  next if(defined $tscrpt->transcript_status  && $tscrpt->transcript_status eq "unknown");

#  $tscrpt->set("transcript_status"=>lc($tr->status));
#  $tscrpt->update();
  
#    print  lc($tr->status)." transcript: $chromosome\t",$tr->stable_id,"\t",$biotype,"\t",$tr->strand,"\t",$tr->start,"\t",$tr->end,"\n";
   print  lc($tr->status)." transcript: ",$tscrpt->chrom_id,"\t",$biotype,"\t",$tscrpt->strand,"\t",$tscrpt->transcript_start,"\t",$tscrpt->transcript_stop,"\n";
# print $tr->seq->seq(),"\n";
#load exon substructure table
    my (@cds,$ordinal);
    $ordinal->{'ord'}=();
    my @exons = @{$tr->get_all_Exons()};
#  add flanking region
     trss_insert($tscrpt->transcript_id,"flank",$tr->start-50000,$tr->start-1,1); 
     print "flank ",$tr->start-50000,",",$tr->start-1,"\n";
     trss_insert($tscrpt->transcript_id,"flank",$tr->end+1,$tr->end+50000,2); 
     print "flank ",$tr->end+1,",",$tr->end+50000,"\n";
   my $phase=0;
    while (my $exon=shift @exons){
	my $start=$exon->coding_region_start($tr);
	my $end=$exon->coding_region_end($tr);
	my $exon_seq=$exon->seq->seq;
	my $sequence;
#   	print $exon->start,"-",$exon->end," $start-$end\n",$exon->seq->seq(),"\n";
        unless(defined($start)||defined($end)) {
    		trss_insert($tscrpt->transcript_id,"utr_exon",$exon->start,$exon->end,ordcount($ordinal,"utrexon"),$exon_seq); 
      		print "1utr_exon", $ordinal->{utrexon}, " ",$exon->start,",",$exon->end,":";
		next;
	}
        if($start>$exon->start) {
		$sequence=substr($exon_seq,0,$start-$exon->start);	 
		$sequence=substr($exon_seq,0-($start-$exon->start)) if($tr->strand==-1);
    		trss_insert($tscrpt->transcript_id,"utr_exon",$exon->start,$start-1,ordcount($ordinal,"utrexon"), $sequence);	 
      		print "2utr_exon ", $ordinal->{utrexon}, " ",$exon->start,",",$start-1 ,"<>1,",$start-$exon->start,":";
	}
	if($end<$exon->end) {
		$sequence=substr($exon_seq,0-($exon->end-$end));	 
		$sequence=substr($exon_seq,0,$exon->end-$end) if($tr->strand==-1);
     		trss_insert($tscrpt->transcript_id,"utr_exon",$end+1,$exon->end,ordcount($ordinal,"utrexon"),$sequence );
      		print "3utr_exon ", $ordinal->{utrexon}, " ",$end+1,",",$exon->end,"<>",$end+2-$exon->start,",",$exon->end-$exon->start+1,":";	
	}
	
        $sequence=substr($exon_seq,$start-$exon->start,$end-$start+1) ;
 	$sequence=substr($exon_seq,$exon->end-$end,$end-$start+1) if($tr->strand==-1);
	print "   phase different :",$exon->phase," <>  $phase  ";
	if($exon->phase==-1) {  $exon->phase($phase);}
 	trss_insert($tscrpt->transcript_id,"cds_exon",$start,$end,ordcount($ordinal,"cdsexon"),$sequence,$phase);
	$phase=($phase+($end-$start+1))%3;
 	print substr($exon_seq,-($end-$start+1)),"\n\n";
      	print "cdsexon ", $ordinal->{cdsexon}, " ",$start,",",$end,"<>",$start+1-$exon->start,",",$end-$exon->start+1,":";
	}
	MPSampleData::DBI->dbi_commit(); 
=cut
#load intron substructure table    
    @cds=();
    my @introns = @{$tr->get_all_Introns()};
    while (my $intron=shift @introns){
	my  $start=$intron->start;
	my  $end=$intron->end;
 	trss_insert($tscrpt->transcript_id,"intron",$start,$end,ordcount($ordinal,"intron"),$intron->seq);
	}
# load protein table
      my $translation=$tr->translation();
      next if(!defined $translation);
     print "\nprotein:",$translation->stable_id,"  \n";
     my ($pro) = MPSampleData::Protein->search(
   			"transcript_id"=>$tscrpt->transcript_id ,
 			"protein_name"=>$translation->stable_id,
 		       ); 
 	$pro->set("amino_acid_seq"=> $translation->seq);
 	$pro->update;
# load protein feature table
     my $proteinfeature=$translation->get_all_ProteinFeatures('pfam');
     foreach my $pf (@$proteinfeature) {
     my $proftype=lc($pf->analysis->gff_feature);
     print "pro featuretype:$proftype\t";
     unless ($proftype=~/domain/) {$proftype="other";}
     my ($external)=$pf->interpro_ac=~/(\d*)$/;
     my ($prof) = MPSampleData::ProteinFeature->search(
   			"protein_id"=>$pro->protein_id ,
 			"feature_name"=>$pf->idesc,
 			"feature_type"=> $proftype,
 		       );
 	$prof->set(	"external_feature_id"=> $external,
 			"protein_start"=> $pf->start,
 			"protein_end"=> $pf->end,);
 	$prof->update; 
      }
     print "\n";
=cut
}

}
close(IN);

return 1;

}

# END OF EXECUTE()

sub ordcount {
	my $ord=shift;
	my $type=shift;
	 
	if( !defined $ord->{$type} ) {$ord->{$type}=1;}
	else {$ord->{$type}++;}
	 
	return ($ord->{$type});
}

sub trss_insert {
    my @trsub=@_;

    my ($tss) = MPSampleData::TranscriptSubStructure->search(
            "transcript_id"=>$trsub[0],
            "structure_type"=> $trsub[1],
            "ordinal"=>  $trsub[4],
            );  
      if(!defined($tss)) {
          $tss = MPSampleData::TranscriptSubStructure->insert(
              {"transcript_id"=>$trsub[0],
              "structure_type"=> $trsub[1],
              "ordinal"=>  $trsub[4],
              });  
      }
    $tss->set(
            "structure_start"=> $trsub[2],
            "structure_stop"=> $trsub[3],
            "nucleotide_seq"=> $trsub[5],
            "phase"=>$trsub[6],
            );
    $tss->update();
	 
#     print STDERR "Added/Found transcript_structure_id: ".$tss->transcript_structure_id."\n";
    return 1; 

}

