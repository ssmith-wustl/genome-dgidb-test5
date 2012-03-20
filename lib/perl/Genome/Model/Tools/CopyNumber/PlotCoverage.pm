package Genome::Model::Tools::CopyNumber::PlotCoverage;

use strict;
use Genome;
use IO::File;
use warnings;
use Cwd ('getcwd','abs_path');

class Genome::Model::Tools::CopyNumber::PlotCoverage{
    is => 'Command',
    has => [
	ROI  => {
	    is => 'String',
	    is_optional => 0,
	    doc => 'string that describe region of interest to graph chr:start-stop e.g. (9:10000-10001)',
	},

	somatic_id => {
	    is => 'String',
	    is_optional => 1,
	    doc => 'somatic variation model ID.  If not specified, must specify normal and tumor bam',
	},

        window_size => {
            is => 'String',
	    is_optional => 1,
	    doc => 'window size to average the coverage',
	    default => '1000'
        },

        output_file => {
	    is => 'String',
	    is_optional => 0,
	    doc => 'output file in PDF format',
        },

        plot_title => {
            is => 'String',
            is_optional => 1,
	    doc => 'Title of the plot (appended by normal or tumor)',
        },
        
        transcript_file => {
            is => 'String',
            is_optional => 1,
	    doc => '',
        },
        normal_bam => {
            is => 'String',
            is_optional => 1,
	    doc => 'full path to the BAM file designated as normal. Must specify if omit somatic_id',
        },
        tumor_bam => {
            is => 'String',
            is_optional => 1,
	    doc => 'full path to the BAM file designated as tumor Must specify if omit somatic_id',
        },

        ]
};

sub help_brief {
    "Plots the normalized coverage of tumor, normal and tumor-normal for a somatic model."
    
}

sub help_detail {
    "Plots the normalized coverage of tumor, normal and tumor-normal for a somatic model."
}
sub help_synopsis {

return <<EOS
Sample Usage:
specify normal and tumor BAM
EXAMPLE:  gmt copy-number plot-coverage --ROI=9:8114245-10692509 --plot-title "Gene X Coverage" --output-file=test.pdf --transcript-file --normal-bam=/gscmnt/gc7001/info/build_merged_alignments/merged-alignment-blade14-4-16.gsc.wustl.edu-apipe-builder-16602-114128395/114128395.bam --tumor-bam=/gscmnt/gc2002/info/build_merged_alignments/merged-alignment-blade13-3-1.gsc.wustl.edu-apipe-builder-13617-112064449/112064449.bam

specify somatic variation model
EXAMPLE: gmt copy-number plot-coverage --somatic-id=1234567 --ROI=9:8114245-10692509 --plot-title "Gene X Coverage" --output-file=test.pdf

EOS
}

sub help_detail {                           # this is what the user will see with the longer version of help. <---
return <<EOS
This tool can be used to plot the CN-separated SNV density plots that are known at GI as 'clonality plots'. Can be used for WGS or Capture data, but was mostly intended for Capture data, and hence the SNV file format is currently Varscan output. If no copy-number file is specified, it will draw a condensed plot with. 
EOS

}


sub execute {
    
    $DB::single=1;
    my $self = shift;
    my $somatic_ID = $self->somatic_id;
    my $ROI = $self->ROI;
    my $window_size = $self->window_size;
    my $output_file = abs_path($self->output_file);
    my $plot_title = $self->plot_title || $ROI;
    my $transcript_file = abs_path($self->transcript_file);

    my $user_normalBAM = $self->normal_bam;
    my $user_tumorBAM = $self->tumor_bam;

    #9:100-1001
    my ($chr,$positions) = split(/:/,$ROI);
    my ($start,$stop) = split(/\-/,$positions);
    #####code to make sure ROI is not weird###

    #########################################
   
    my($normalBAM,$tumorBAM);
    my($T_map_undup_reads,$N_map_undup_reads,$common_name,$ref_seq);
    if($somatic_ID) {
	my $somatic_model = Genome::Model->get($somatic_ID);
	die "Can't find valid somatic model for $somatic_ID\n" if(!$somatic_model);
	my $tumor_build = $somatic_model->tumor_model->last_succeeded_build;
	die "Can't find valid tumor build for $somatic_ID\n" if(!$tumor_build);
	my $normal_build = $somatic_model->normal_model->last_succeeded_build;
	die "Can't find valid normal build for $somatic_ID\n" if(!$normal_build);
	$common_name = $tumor_build->model->subject->source_common_name;
    
	#grab tumor and normal BAM file location as well as stats for normalization
	$ref_seq = $tumor_build->reference_sequence_build->full_consensus_path('fa'); #grab ref sequence path
	my $T_bam_stat = Genome::Model::Tools::Sam::Flagstat->parse_file_into_hashref($tumor_build->whole_rmdup_bam_flagstat_file);
	if(! $T_bam_stat) { die "Can't find the bam stat for tumor BAM\n"; }
	$T_map_undup_reads = $T_bam_stat->{'reads_mapped'} - $T_bam_stat->{'reads_marked_duplicates'};
	$tumorBAM = $tumor_build->whole_rmdup_bam_file;
    
	my $N_bam_stat = Genome::Model::Tools::Sam::Flagstat->parse_file_into_hashref($normal_build->whole_rmdup_bam_flagstat_file);
	if(! $N_bam_stat) { die "Can't find the bam stat for normal BAM\n"; }
	$N_map_undup_reads = $N_bam_stat->{'reads_mapped'} - $N_bam_stat->{'reads_marked_duplicates'};
	$normalBAM = $normal_build->whole_rmdup_bam_file;
    }elsif($user_normalBAM && $user_tumorBAM ) {
	$ref_seq = "/gscmnt/ams1102/info/model_data/2869585698/build106942997/all_sequences.fa";
	$common_name = "sample";
	my $T_bam_stat = Genome::Model::Tools::Sam::Flagstat->parse_file_into_hashref("$user_tumorBAM.flagstat");
	if(! $T_bam_stat) { die "Can't find the bam stat for tumor BAM\n"; }
	$T_map_undup_reads = $T_bam_stat->{'reads_mapped'} - $T_bam_stat->{'reads_marked_duplicates'};
	$tumorBAM = $self->tumor_bam;

	my $N_bam_stat = Genome::Model::Tools::Sam::Flagstat->parse_file_into_hashref("$user_normalBAM.flagstat");
	if(! $N_bam_stat) { die "Can't find the bam stat for normal BAM\n"; }
	$N_map_undup_reads = $N_bam_stat->{'reads_mapped'} - $N_bam_stat->{'reads_marked_duplicates'};
	$normalBAM = $self->normal_bam;
    }else {
	die "Must specify a somatic model or path to 2 BAM files\n";
    }

    my $n_t_ratio = $N_map_undup_reads/$T_map_undup_reads;
  
    #my $N_haplo = $normal_build->get_metric("haploid_coverage"); #won't work on failed builds
    #my $T_haplo = $tumor_build->get_metric("haploid_coverage");
  
    #using samtools mpileup to retrieve the depth of coverage in ROI
    my $cmd = "samtools mpileup -A -B -d 10000 -Q 0 -f $ref_seq -r $ROI $normalBAM $tumorBAM | cut -f 1,2,4,7";
    my @output = `$cmd`;

    #my $temp_file = "${chr}_${start}_${stop}_temp.reads.txt";
    #open(TEMPFILE, "> $temp_file") or die "Can't write to the temp file due to $0";
    my ($fh,$temp_file) = Genome::Sys->create_temp_file;	
    #print STDERR "temp_file location: $temp_file\n";
    for (@output) {
	chomp;
	my @list = split(/\t/,$_);
	my $n_count = $list[2];
	my $t_count = $list[3];
	$t_count = $t_count * $n_t_ratio; #adjust tumor reads based on the total number of reads in normal and tumor sample
	my $s = "$list[0]\t$list[1]\t$n_count\t$t_count\t$common_name";
	$fh->print("$s\n");
	my $x = 1;
    }
    #close TEMPFILE;
    $fh->close;

    print STDERR "Get mean depth using window size of $window_size\n";
    my $plot_input_file = abs_path("${chr}_${start}_${stop}_win${window_size}.depth");
    get_mean_depth($temp_file,$window_size,$plot_input_file);
    #unlink($temp_file); 

    my $plot_cmd;
    print STDERR "Rendering Plot\n";
    if($transcript_file) {
	$plot_cmd = qq{ plot_tumor_normal_read_depth(coverage_file="$plot_input_file",plot_title="$plot_title",output_file="$output_file",transcript.info="$transcript_file") };
    }
    else {
	$plot_cmd = qq{ plot_tumor_normal_read_depth(coverage_file="$plot_input_file",plot_title="$plot_title",output_file="$output_file") };
    }
    my $call = Genome::Model::Tools::R::CallR->create(command=>$plot_cmd, library=> "BamToCnaGraph.R");
    $call->execute;

}

sub get_mean_depth {

    my $datafile = shift;
    my $window = shift;
    my $mean_depth_output_file = shift;

    my $pos=1;
    my (@normal,@tumor);
    my $coordinate;
    my $chr;
    my $label;

    open(TEMPFILE, "$datafile") or die "Can't read the file $datafile due to $!";
    open(MEANDEPTH,"> $mean_depth_output_file") or die "Can't write to the file $mean_depth_output_file due to $!";
    while(<TEMPFILE>) {
	chomp;
	my @list = split(/\t/,$_);
	my $n_cov = $list[2];
	my $t_cov = $list[3]; 
	$coordinate = $list[1];
	$chr = $list[0];
	$label = $list[-1];
	
	push(@normal,$n_cov);
	push(@tumor,$t_cov);
	
	unless(scalar(@normal) == 0 || (scalar(@normal) % $window != 0)) {
	    my $avgN = get_mean(\@normal);
	    my $avgT = get_mean(\@tumor);
	    @normal=();
	    @tumor=();
	    my $start = $coordinate-($window-1);
	    print MEANDEPTH "$chr\t$start\t$coordinate\t$avgN\t$avgT\t$label\n";
	} 
	
	$pos++;
    }
    close TEMPFILE;
    if(scalar(@normal) > 0) {
	my $avgN = get_mean(\@normal);
	my $avgT = get_mean(\@tumor);
	
	my $start = $coordinate - (scalar(@normal)-1);
	print MEANDEPTH "$chr\t$start\t$coordinate\t$avgN\t$avgT\t$label\n";
    }
    close MEANDEPTH;
    

}

sub get_mean {

    my $list = shift;

    my $sum=0;
    for(@$list) {
	$sum+=$_;
    }

    my $avg = $sum/scalar(@$list);

    return $avg;
}





1;
