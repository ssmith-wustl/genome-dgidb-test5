package Genome::Model::Tools::CopyNumber::UTest;

use strict;
use Genome;
use Cwd 'abs_path';
use IO::File;
use Getopt::Long;
use Statistics::R;
use File::Temp;
use DBI;
require Genome::Utility::FileSystem;

class Genome::Model::Tools::CopyNumber::UTest {
    is => 'Command',
    has => [
    use_file_format => {
    	type => 'Boolean',
    	is_optional => 0,
    	default => 0,
    	doc => 'Whether to I/O the information by files or by command input and stdout.',
    },
    output_file => {
        is => 'String',
        is_optional => 1,
        doc => 'File name contain the U test P value in the form of "name,chromosome,start-position,end-position,sliding-window,tumor-p-value,normal-p-value,tumor-normal-p-value"',
    },
    input_file => {
    	is => 'String',
    	is_optional => 1,
    	doc => 'File name in the form of "name,tumor-bam-file,normal-bam-file,chromosome,start-position,end-position,plot-graph,graph-directory,flanking-region,sliding-window". Leave it blank if any item does not apply but please do not skip colon. No header needed.',
    },
    name => {
    	is => 'String',
    	is_optional => 1,
    	doc => 'Name of the data. Use when you have only one data, and do not want to generate an input file. It will read the information from the command. Same for the following input.'
    },
    chromosome => {
        is => 'String',
        is_optional => 1,
        doc => 'Chromosome of the data to be processed.',
    },
    start => {
        is => 'Integer',
        is_optional => 1,
        doc => 'The start position of the region of interest in the chromosome.',
    },
    end => {
        is => 'Integer',
        is_optional => 1,
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
    plot_graph => {
    	type => 'Boolean',    	
    	is_optional => 1,
    	default => 0,
    	doc => 'Whether to plot graph or not. If yes, the graph-directory should be given.',
    },
    graph_directory => {
    	is => 'String',
    	is_optional => 1,
    	doc => 'The directory of the graph. Must be given if plot-graph is true.',
    },
    flanking_region => {
        is => 'Integer',
        is_optional => 1,
        default => 2,
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
    "Do paired U test to for P value given the position of region of interest and bam file. It can call graph module if plot-graph is 1 for either the input file or the command input."
}

sub help_detail {
    "This script will do U test to compute P values for the region of interest (ROI) and the flanking region for both tumor and normal. It will also do U test to compare the ROI between tumor and normal. If user has only one data of interest, user does not have to generate the input file, but just use the input commands. If user has a bunch of data to process, for user's convenience, user can write the information according to the form stated in the input-file so that the job can be done once. Apart from the U test, this script will call graph module to draw a graph for each data if asked. The input graph-directory, flanking-region, sliding-window are needed only when user wants to draw the graph, but flanking-region and sliding-window are optional."
}

sub execute {
    my $self = shift;

    # process input arguments
    my $isFile = $self->use_file_format;
    my $outputFile = $self->output_file;
    my $inputFile = $self->input_file;
    
    my $name = $self->name;
    my $chr = $self->chromosome;
    my $start = $self->start;
    my $end = $self->end;
    my $bam_tumor = $self->tumor_bam_file;
    my $bam_normal = $self->normal_bam_file;
    my $isPlotGraph = $self->plot_graph;
    my $outputFigDir = $self->graph_directory;

    my $multiple_neighbor = $self->flanking_region;
    my $slide = $self->sliding_window;
    # choose big enough region as the flanking one for u test
    my $point_number = 50;
    my $interval = $point_number * $slide;
    
    # Process options.
    if($isFile == 1 && (! -e "$inputFile" || $outputFile !~/\S+/)){
	    die("Using file format but either the input or output file was not given, or the input file does not exist. Please type 'gmt copy-number u-test -h' to see the manual.\n");
	}
	if($isFile == 0 && ($chr !~/\S+/ || $start !~/\d+/ || $end !~/\d+/ || ($bam_tumor !~/\S+/ && $bam_normal !~/\S+/))){
	    die("Input file given but either the chromosome or positions or bam files are not given. Please type 'gmt copy-number u-test -h' to see the manual.\n");
	}
	if($isPlotGraph == 1 && $outputFigDir !~/\S+/){
		die("Plot graph is chosen but no graph-directory is given. Please type 'gmt copy-number u-test -h' to see the manual.\n");
	}
    if($isPlotGraph == 1){
	    `mkdir $outputFigDir` unless (-e "$outputFigDir");    
	}
    #test architecture to make sure bam-window program can run (req. 64-bit)
    unless (`uname -a` =~ /x86_64/) {
        $self->error_message("Must run on a 64 bit machine");
        die;
    }
   
    my $system_tmp = 1;
    my $tmp_in_tumor_name_normalized;
    my $tmp_in_normal_name_normalized;    
    if($system_tmp == 1){        
        my $tmp_in_tumor_normalized = File::Temp->new();
   	    $tmp_in_tumor_name_normalized = $tmp_in_tumor_normalized -> filename;
        my $tmp_in_normal_normalized = File::Temp->new();   	    
   	    $tmp_in_normal_name_normalized = $tmp_in_normal_normalized -> filename;
   	}
   	else{
   		$tmp_in_tumor_name_normalized = "/gscuser/xfan/svn/perl_modules/Genome/Model/Tools/Xian/tmp_tumor.csv";
   		$tmp_in_normal_name_normalized = "/gscuser/xfan/svn/perl_modules/Genome/Model/Tools/Xian/tmp_normal.csv";   		
   	}

	# deal with the name
   	if($name eq ""){
   		$name = $end;
   	}
	    	
    # use the file format
    if($isFile == 1){
    	open FILE_out, ">$outputFile" or die $!;
    	print FILE_out "name,chromosome,start-position,end-position,sliding-window,tumor-p-value,normal-p-value,tumor-normal-p-value\n";
    	close FILE_out;
    	open FILE_out, ">>$outputFile" or die $!;
    	open FILE, "<$inputFile" or die $!;
    	while (my $line = <FILE>) {
    		chomp $line;
	    	my ($name, $bam_tumor, $bam_normal, $chr, $start, $end, $isPlotGraph, $outputFigDir, $multiple_neighbor_, $slide_) = split(/\,/,$line); 

			if(($bam_tumor !~/\S+/ && $bam_normal !~/\S+/) || $chr !~/\S+/ || $start !~/\d+/ || $end !~/\d+/ || $isPlotGraph !~/\d+/){
			    die("Input file given but either the chromosome or positions or bam files are not given. Please type 'gmt copy-number u-test -h' to see the manual.\n");
			}
			if($isPlotGraph == 1 && $outputFigDir !~/\S+/){
				die("Plot graph is chosen but no graph-directory is given. Please type 'gmt copy-number u-test -h' to see the manual.\n");
			}
			if($multiple_neighbor_ =~/\S+/){
				$multiple_neighbor = $multiple_neighbor_;
			}
	    	if($slide_ =~/\S+/){
	    		$slide = $slide_;
   		        $interval = $point_number * $slide;   		        
	    	}
	    	print "$multiple_neighbor\t$slide\n";
	    	# deal with the rest by the function
	    	my $p1 = u_test($bam_tumor, $chr, $start, $end, $interval, $slide, $tmp_in_tumor_name_normalized);
	    	my $p2 = u_test($bam_normal, $chr, $start, $end, $interval, $slide, $tmp_in_normal_name_normalized);
	    	my $p3 = u_test_ROI($bam_tumor, $bam_normal, $tmp_in_tumor_name_normalized, $tmp_in_normal_name_normalized);
    	
			# write to the output file
			print FILE_out "$name,$chr,$start,$end,$slide,$p1,$p2,$p3\n";
			
			# deal with the plot
			if($isPlotGraph == 1){
				my $command = `gmt copy-number graph --output-dir $outputFigDir --tumor-bam-file $bam_tumor --normal-bam-file $bam_normal --chromosome $chr --start $start --end $end --flanking-region $multiple_neighbor --sliding-window $slide --name $name`;
				system($command);
			}
		}
		close FILE_out;
		#close FILE;	    	
    }
    else{
    	# deal with the rest by the function
    	my $p1 = u_test($bam_tumor, $chr, $start, $end, $interval, $slide, $tmp_in_tumor_name_normalized);
    	my $p2 = u_test($bam_normal, $chr, $start, $end, $interval, $slide, $tmp_in_normal_name_normalized);
    	my $p3 = u_test_ROI($bam_tumor, $bam_normal, $tmp_in_tumor_name_normalized, $tmp_in_normal_name_normalized);
    	
		# write to the standard out
		print "****************** The followings are the result summary ***************\nname:$name\nchromosome:$chr\nstart-position:$start\nend-position:$end\nsliding-window:$slide\ntumor-p-value:$p1\nnormal-p-value:$p2\ntumor-normal-p-value:$p3\n";
			
		# deal with the plot
		if($isPlotGraph == 1){
			my $command = `gmt copy-number graph --output-dir $outputFigDir --tumor-bam-file $bam_tumor --normal-bam-file $bam_normal --chromosome $chr --start $start --end $end --flanking-region $multiple_neighbor --sliding-window $slide --name $name`;
			system($command);
		}
    }
}

sub u_test{
	my ($bam, $chr, $start, $end, $interval, $slide, $tmp_in_name_normalized) = @_;
	if($bam eq ""){
		return;
	}
    # read the neighbors
    my $neighbor1_left = $start - $interval;
    my $neighbor1_right = $start - 1;
    my $neighbor2_left = $end + 1;
    my $neighbor2_right = $end + $interval;
    
    my $system_tmp = 0;
    my ($tmp_in_name, $tmp_out_name, $tmp_outAll_name);
    $tmp_in_name = "NA";
    $tmp_out_name = "NA";
    $tmp_outAll_name = "NA";
    
    if($system_tmp == 0){        
        my $tmp_in = File::Temp->new();
   	    $tmp_in_name = $tmp_in -> filename;
   	    my $tmp_out = File::Temp->new();
   	    $tmp_out_name = $tmp_out -> filename;
   	    my $tmp_outAll = File::Temp->new();
   	    $tmp_outAll_name = $tmp_outAll -> filename;
    }
    else{
   	    $tmp_in_name = "/gscuser/xfan/svn/perl_modules/Genome/Model/Tools/Xian/tmp_in.csv";
   	    $tmp_out_name = "/gscuser/xfan/svn/perl_modules/Genome/Model/Tools/Xian/tmp_out.csv";
  	    $tmp_outAll_name = "/gscuser/xfan/svn/perl_modules/Genome/Model/Tools/Xian/tmp_outAll.csv";
    }

    open FILE_tmp, ">$tmp_in_name" or die $!;
    close FILE_tmp;               
    write_read_count($bam, $chr, $start, $end, $tmp_in_name, $slide);
    open FILE_tmp, ">$tmp_out_name" or die $!;
    close FILE_tmp;
    write_read_count($bam, $chr, $neighbor1_left, $neighbor1_right, $tmp_out_name, $slide);  
    write_read_count($bam, $chr, $neighbor2_left, $neighbor2_right, $tmp_out_name, $slide);
    
    open FILE_tmp, ">$tmp_in_name_normalized" or die $!;
    close FILE_tmp;
    open FILE_tmp, ">$tmp_outAll_name" or die $!;
    close FILE_tmp;
        
    my $command = qq{utest(name1="$tmp_in_name",name2="$tmp_out_name",nameAll="$tmp_outAll_name",normalize=1,normalizedFile="$tmp_in_name_normalized")};
    my $library = "U_test.R";
    my $call = Genome::Model::Tools::R::CallR->create(command=>$command, library=>$library);
    $call -> execute;
    open FILE_tmp, "<$tmp_outAll_name" or die $!;
    my $line = <FILE_tmp>;
    close FILE_tmp;
    return $line;        
}
  
sub u_test_ROI{
	my ($bam_tumor, $bam_normal, $tmp_tumor_name, $tmp_normal_name) = @_;
	if($bam_tumor eq "" || $bam_normal eq ""){
		return;
	}
	
    my $tmp_outAll_name = "NA";
    my $system_tmp = 0;    
    if($system_tmp == 1){        
   	    my $tmp_outAll = File::Temp->new();
   	    $tmp_outAll_name = $tmp_outAll -> filename;
    }
    else{
  	    $tmp_outAll_name = "/gscuser/xfan/svn/perl_modules/Genome/Model/Tools/Xian/tmp_outAll.csv";
    }
    
    open FILE_tmp, ">$tmp_outAll_name" or die $!;
    close FILE_tmp;
                       
    my $command = qq{utest(name1="$tmp_tumor_name",name2="$tmp_normal_name",nameAll="$tmp_outAll_name",normalize=0,normalizedFile="")};
    my $library = "U_test.R";
    my $call = Genome::Model::Tools::R::CallR->create(command=>$command, library=>$library);
    $call -> execute;
    open FILE_tmp, "<$tmp_outAll_name" or die $!;
    my $line = <FILE_tmp>;
    return $line;        	
}
    
sub write_read_count {
    my ($bam, $chr, $start, $end, $tmp_in_name, $slide) = @_;
    my @command = `samtools view $bam $chr:$start-$end`;
#    open FILE_readcount, ">", $tmp_in_name or die $!;
#    close FILE_readcount;
    open FILE_readcount, ">>", $tmp_in_name or die $!;

    # write read count
    my $current_window = $start;
    my $readcount_num = 0;
    for(my $i = 0; $i < $#command; $i ++ ) {
        my $each_line = $command[$i];
        my ($tmp1, $tmp2, $chr_here, $pos_here, $end_here,) = split(/\t/, $each_line);
        if($pos_here > $current_window + $slide){
        	if($readcount_num != 0){
            	print FILE_readcount "$chr\t$current_window\t$readcount_num\n";
            }
            if($current_window + $slide > $end){
                last;
            }
            $current_window += $slide;
            if($pos_here > $current_window + 2*$slide){
            	$readcount_num = 0;
            }
            else{
	            $readcount_num = 1;
	        }
        }
        else{
            $readcount_num ++;
        }
    } 
    if($current_window + $slide < $end){
    	while($current_window + $slide < $end){
    		$current_window += $slide;
    		print FILE_readcount "$chr\t$current_window\t0\n";
    	}
    }
    close FILE_readcount;
    return;
}
    
    
