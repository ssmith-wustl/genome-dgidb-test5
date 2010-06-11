#! /usr/local/perl

my ($sample, $type, $RT, $varscan)=@ARGV;

if ($#ARGV <3){
    print "supply following information in order: SAMPLEID, type(SNV/Indel), validationRT, Varscan output!\n";
    exit;
}else{
    print "Input as following:\n$sample\n$type\n$RT\n$varscan\n";
}

# my $sample="LUC-2";
# my $type ="SNV";
# my $RT="RT55210";
# my $varscan="";
my $ROIlist=$sample."_ROIlist.txt";

my $cmd="sqlrun \"select distinct roi_set_name from amplification_roi_set where roi_set_type = \'roi_set\'\" | grep $sample > $ROIlist";

print "$cmd\n";
system ("$cmd");

open (FH, "<$ROIlist");
#print while grep $type <FH>;
my $number =0;
my @lines = <FH>;
for my $line (@lines){
    if ($line =~ m/$type/){
	$line =~ s/\n//;
	$number++;
	$file1 = $sample."_".$type."_".$RT."_".$number.".csv";
	print "============\n$line\n$file1\n";
	$cmd="sqlrun \"select roi_set_name, region_of_interest_name, amplicon_stag_id from amplification_roi ar join amplification_roi_set ars on ars.amplification_roi_id=ar.amplification_roi_id join amplification_target at on at.amplification_roi_id = ar.amplification_roi_id left outer join amplification_target_amplicon ata on ata.amplification_target_id = at.amplification_target_id join setup s on s.setup_id = ar.htmp_project_id join sequence_tag\@dw st on st.stag_id = at.target_stag_id join sequence_correspondence\@dw scr on scr.scrr_id = st.stag_id join sequence_item\@dw chr on chr.seq_id = scr.seq2_id where roi_set_name like \'$line'\" > $file1";
	print "$cmd\n";
	system ("$cmd");
	$file2= $sample."_".$type."_".$RT."_".$number."_sites.csv";
	if ($type eq "SVN" || $type eq "Indel"){
	    $cmd= "perl /gscuser/xhong/svn/perl_modules/Genome/Model/Tools/Xhong/sql_snp.pl $file1 $file2";
	    print "$cmd\n";
	    system ("$cmd");
	    $file2= $sample."_".$type."_".$RT."_".$number."_sites.csv";
	    $file3= $sample."_".$type."_".$RT."_".$number."_sites_validation.csv";
	    $file3f= $sample."_".$type."_".$RT."_".$number."_sites_validation.fail.csv";
	    $file3s= $sample."_".$type."_".$RT."_".$number."_sites_validation_somatic.csv";
	    $cmd="java -classpath \~dkoboldt/Software/VarScan net.sf.varscan.VarScan limit $varscan --positions-file $file2 --output-file $file3";
	    print "$cmd\n";
	    system ("$cmd");
	    $cmd="perl failed_validation.pl $file2 $file3";
	    $cmd="cat $file3 | grep Somatic > $file3s";
	    print "$cmd\n";
	    system ("$cmd");
	    $file4= $sample."_".$type."_".$RT."_".$number."_sites_validation_before_annotation.csv";
	    $cmd="awk '{OFS=\"\\t\"} {print \$1,\$2,\$2,\$3,\$4}' $file3 > $file4";
	    print "$cmd\n";
	    system ("$cmd");
	    $file5= $sample."_".$type."_".$RT."_".$number."_sites_validation_after_annotation.csv";
	    $cmd="gmt annotate transcript-variants --variant-file $file4 --output-file $file5 --annotation-filter top";
	    print "$cmd\n\n";
	    system ("$cmd");
	    print "\n";
	}else{
	    print "Cannot work with SV or other type yet! exit now\n";
	    exit;
	}
    }else{
	next;
    }
}

close FH;
