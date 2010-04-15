package Genome::Model::Tools::CopyNumber::Graph;

use strict;
use Genome;
use Cwd 'abs_path';
use IO::File;
use Getopt::Long;
use Statistics::R;
use File::Temp;
use DBI;

class Genome::Model::Tools::CopyNumber::Graph {
    is => 'Command',
    has => [
    output_dir => {
        is => 'String',
        is_optional => 0,
        doc => 'Directory containing output graphs.',
    },
    name => {
        is => 'String',
        is_optional => 1,
        doc => 'Name of the data to be processed. Any name that you like to call the data.',
    },
    chromosome => {
        is => 'String',
        is_optional => 0,
        doc => 'Chromosome of the data to be processed.',
    },
    start => {
        is => 'Integer',
        is_optional => 0,
        doc => 'The start position of the region of interest in the chromosome.',
    },
    end => {
        is => 'Integer',
        is_optional => 0,
        doc => 'The end position of the region of interest in the chromosome.',
    },
    tumor_bam_file => {
        is => 'String',
        is_optional => 1,
        doc => 'The bam file of the tumor. Should include the whole path. One of tumor and normal bam file should be specified.',
    },	
    normal_bam_file => {
        is => 'String',
        is_optional => 1,
        doc => 'The bam file of the normal. Should include the whole path. One of tumor and normal bam file should be specified.',
    },	
    flanking_region => {
        is => 'Integer',
        is_optional => 1,
        default => 5,
        doc => 'How much longer the flanking region on each side should be as to the region of interest. By default it is set to be 5.',
    },	
    sliding_window => {
        is => 'Integer',
        is_optional => 1,
        default => 1000,
        doc => 'How many sites to count the read each time. By default it is set to be 1000.',
    },	
    ]
};

sub help_brief {
    "generate copy number graph via samtools given bam file and positions"
}

sub help_detail {
    "This script will call samtools and count the read per sliding-window for the region expanded to the flanking region, and draw the graph with the annotations (segmental duplication, repeat mask, dgv, gene) on the bottom. You can draw the normal and tumor separately, or you can draw both as long as their bam files are given."
}

sub execute {
    $DB::single=1;
    my $self = shift;

    # process input arguments
    my $outputFigDir = $self->output_dir;
    `mkdir $outputFigDir` unless (-e "$outputFigDir");
    my $name = $self->name;
    my $chr = $self->chromosome;
    my $start = $self->start;
    my $end = $self->end;
    my $bam_tumor = $self->tumor_bam_file;
    my $bam_normal = $self->normal_bam_file;
    my $multiple_neighbor = $self->flanking_region;
    my $slide = $self->sliding_window;

    # Process options.
    die("Input not fulfill the conditions. Please type 'perl CNprocess.pl' to see the manual.\n") unless (-e "$bam_tumor" || -e "$bam_tumor");

    my $outputFigDir = abs_path($outputFigDir);
    
    # connect to database
    my $db = "ucsc";
    my $user = "mgg_admin";
    my $password = "c\@nc3r"; 
    my $dataBase = "DBI:mysql:$db:mysql2";
    my $dbh = DBI->connect($dataBase, $user, $password) || die "ERROR: Could not connect to database: $! \n";

    my $picName;
    my $table;

    # read the neighbors
    my $interval = int($end - $start);
    my $neighbor1_left = $start - $multiple_neighbor*$interval;
    my $neighbor1_right = $start - 1;
    my $neighbor2_left = $end + 1;
    my $neighbor2_right = $end + $multiple_neighbor*$interval;


    # Step 2: get samtools and write to a file

    # tumor
    my ($tmp_in, $tmp_outL, $tmp_outR);
    my $tmp_in_name = "NA";
    my $tmp_outL_name = "NA";
    my $tmp_outR_name = "NA";

    if(-e "$bam_tumor"){
        $tmp_in = File::Temp->new();
        $tmp_in_name = $tmp_in -> filename;
        $tmp_outL = File::Temp->new();
        $tmp_outL_name = $tmp_outL -> filename;
        $tmp_outR = File::Temp->new();
        $tmp_outR_name = $tmp_outR -> filename;
        #$tmp_in_name = "/gscuser/xfan/svn/perl_modules/Genome/Model/Tools/Xian/tmp_in.csv";
        #$tmp_outL_name = "/gscuser/xfan/svn/perl_modules/Genome/Model/Tools/Xian/tmp_outL.csv";
        #$tmp_outR_name = "/gscuser/xfan/svn/perl_modules/Genome/Model/Tools/Xian/tmp_outR.csv";
                
        write_read_count($bam_tumor, $chr, $start, $end, $tmp_in_name, $slide);
        write_read_count($bam_tumor, $chr, $neighbor1_left, $neighbor1_right, $tmp_outL_name, $slide);  
        write_read_count($bam_tumor, $chr, $neighbor2_left, $neighbor2_right, $tmp_outR_name, $slide);
    }

    # normal
    my ($tmp_in_n, $tmp_outL_n, $tmp_outR_n);
    my $tmp_in_name_n = "NA";
    my $tmp_outL_name_n = "NA";
    my $tmp_outR_name_n = "NA";

    if(-e "$bam_normal"){
        $tmp_in_n = File::Temp->new();
        $tmp_in_name_n = $tmp_in_n -> filename;
        $tmp_outL_n = File::Temp->new();
        $tmp_outL_name_n = $tmp_outL_n -> filename;
        $tmp_outR_n = File::Temp->new();
        $tmp_outR_name_n = $tmp_outR_n -> filename;
        #$tmp_in_name_n = "/gscuser/xfan/svn/perl_modules/Genome/Model/Tools/Xian/tmp_inN.csv";
        #$tmp_outL_name_n = "/gscuser/xfan/svn/perl_modules/Genome/Model/Tools/Xian/tmp_outLN.csv";
        #$tmp_outR_name_n = "/gscuser/xfan/svn/perl_modules/Genome/Model/Tools/Xian/tmp_outRN.csv";        

        write_read_count($bam_normal, $chr, $start, $end, $tmp_in_name_n, $slide);
        write_read_count($bam_normal, $chr, $neighbor1_left, $neighbor1_right, $tmp_outL_name_n, $slide);
        write_read_count($bam_normal, $chr, $neighbor2_left, $neighbor2_right, $tmp_outR_name_n, $slide);
    }

    # read the table and write to file temp_seg.csv
    # read annotation (segmentatl duplication), ready for printing in R
    $table = "genomicSuperDups";
    my $seg = File::Temp->new();
    my $seg_file = $seg -> filename;
    my $seg_geneTableQuery = "SELECT chrom, chromStart, chromEnd FROM $table";
    #my $seg_file = "/gscuser/xfan/svn/perl_modules/Genome/Model/Tools/Xian/tmp_seg.csv";    
    readTable($dbh, $table, $chr, $neighbor1_left, $neighbor2_right, $seg_file, $seg_geneTableQuery);  

    # repeat mask
    $table = "chr1_rmsk";
    my $rep = File::Temp->new();
    my $rep_file = $rep -> filename;
	my $rep_geneTableQuery = "SELECT genoName, genoStart, genoEnd FROM $table";
    #my $rep_file = "/gscuser/xfan/svn/perl_modules/Genome/Model/Tools/Xian/tmp_rep.csv";    
    readTable($dbh, $table, $chr, $neighbor1_left, $neighbor2_right, $rep_file, $rep_geneTableQuery); 

    # dgv
    $table = "dgv";
    my $dgv = File::Temp->new();
    my $dgv_file = $dgv -> filename;
    my $dgv_geneTableQuery = "SELECT chrom, chromStart, chromEnd FROM $table";    
    #my $dgv_file = "/gscuser/xfan/svn/perl_modules/Genome/Model/Tools/Xian/tmp_dgv.csv";        
    readTable($dbh, $table, $chr, $neighbor1_left, $neighbor2_right, $dgv_file, $dgv_geneTableQuery);

    # gene
    $table = "knownGene";
    my $gene = File::Temp->new();
    my $gene_file = $gene -> filename;
    my $gene_geneTableQuery = "SELECT chrom, txStart, txEnd FROM $table";
    #my $gene_file = "/gscuser/xfan/svn/perl_modules/Genome/Model/Tools/Xian/tmp_gene.csv";        
    readTable($dbh, $table, $chr, $neighbor1_left, $neighbor2_right, $gene_file, $gene_geneTableQuery);

    # disconnect DBI
    $dbh->disconnect();

    # write the information to a file
    if($name eq ""){
        $picName = $outputFigDir . "/Chr" . $chr . "_" . $start .  "_readcount_annotation.png";
    }
    else{
        $picName = $outputFigDir . "/". $name . "_chr" . $chr . "_" . $start .  "_readcount_annotation.png";
    }
    my $tmp_ = File::Temp->new();
    my $tmp_name = $tmp_ -> filename;
    #my $tmp_name = "/gscuser/xfan/svn/perl_modules/Genome/Model/Tools/Xian/tmp_name.csv";

    open FILE_name, ">", $tmp_name or die $!;
    print FILE_name "$tmp_in_name\t$tmp_outL_name\t$tmp_outR_name\t$tmp_in_name_n\t$tmp_outL_name_n\t$tmp_outR_name_n\n$name\t$picName\tchr$chr\t\t\t\n$start\t$end\t$neighbor1_left\t$neighbor1_right\t$neighbor2_left\t$neighbor2_right\n$seg_file\t$rep_file\t$dgv_file\t$gene_file\t\t\n";
    close FILE_name;
    # Step 3: Read the coverage depth using R 
    my $command = qq{readcount(name="$tmp_name")};
    my $library = "CN_graph.R";
    my $call = Genome::Model::Tools::R::CallR->create(command=>$command, library=>$library);
    $call -> execute;
    return 1;
}

sub write_read_count {
    my ($bam, $chr, $start, $end, $tmp_in_name, $slide) = @_;
    my @command = `samtools view $bam $chr:$start-$end`;
    open FILE_readcount, ">", $tmp_in_name or die $!;
    close FILE_readcount;
    open FILE_readcount, ">>", $tmp_in_name or die $!;

    # write read count
    my $current_window = $start;
    my $readcount_num = 0;
    for(my $i = 0; $i < $#command; $i ++ ) {
        my $each_line = $command[$i];
        my ($tmp1, $tmp2, $chr_here, $pos_here, $end_here,) = split(/\t/, $each_line);
        if($pos_here > $current_window + $slide){
            print FILE_readcount "$chr\t$current_window\t$readcount_num\n";
            if($current_window + $slide > $end){
                last;
            }
            $current_window += $slide;
            $readcount_num = 1;
        }
        else{
            $readcount_num ++;
        }
    } 
    close FILE_readcount;
    return;
}

sub readTable {
    my ($dbh, $table, $myChr, $myStart, $myStop, $myAnoFile, $geneTableQuery) = @_;
    # query
    # my $geneTableQuery = "SELECT chrom, chromStart, chromEnd FROM $table";
    my $geneStatement = $dbh->prepare($geneTableQuery) || die "Could not prepare statement '$geneTableQuery': $DBI::errstr \n";

    # execute query
    my ($chr, $chrStart, $chrStop);
    
    my $subString = ",";

    open FILE, ">", $myAnoFile or die $!;
    print FILE "Start\tEnd\n";
    close FILE;
    open FILE, ">>", $myAnoFile or die $!;
    $geneStatement->execute() || die "Could not execute statement for table knownGene: $DBI::errstr \n";
    while ( ($chr, $chrStart, $chrStop) = $geneStatement->fetchrow_array() ) {
        if($chr eq "chr".$myChr && $chrStart <= $myStop && $chrStop >= $myStart){ # overlap
            if($chrStart < $myStart){
                #$chrStart = $myStart;
                my $iIndex = index($myStart, $subString);
                if($iIndex >= 1){
                	$chrStart = substr($myStart, 0, $iIndex-1);
                }
                else{
                	$chrStart = $myStart;
                }
            }
            if($chrStop > $myStop){
                $chrStop = $myStop;
            }
            print FILE "$chrStart\t$chrStop\n";
        }
    }
    close FILE;
}



