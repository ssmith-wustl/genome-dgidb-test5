package Genome::Model::Tools::Validation::CoverageCopynumberPlot;     # rename this when you give the module file a different name <--

#####################################################################################################################################
# FormatVcf - "Inputs of Varscan and Copynumber, Output of R plots"
#					
#	AUTHOR:		Will Schierding
#
#	CREATED:	03-Mar-2011 by W.S.
#	MODIFIED:	03-Mar-2011 by W.S.
#
#	NOTES:	
#			
#####################################################################################################################################

use strict;
use warnings;
use FileHandle;
use Genome;                                 # using the namespace authorizes Class::Autouse to lazy-load modules under it

class Genome::Model::Tools::Validation::CoverageCopynumberPlot {
	is => 'Command',                       
	
	has => [                                # specify the command's single-value properties (parameters) <--- 
		varscan_file	=> { is => 'Text', doc => "File of varscan validated calls, ex: ", is_optional => 0, is_input => 1 },
		cnvhmm_file	=> { is => 'Text', doc => "File of cnvhmm whole genome predictions", is_optional => 0, is_input => 1 },
		varscan_r_library	=> { is => 'Text', doc => "File of cnvhmm whole genome predictions", is_optional => 0, is_input => 1, default => '/gscmnt/sata423/info/medseq/analysis/CaptureValidationGraphs/VarScanGraphLib.R'},
		sample_id	=> { is => 'Text', doc => "Sample ID to be put on graphs", is_optional => 1, is_input => 1, default => 'unspecified' },
		r_script_output_file     => { is => 'Text', doc => "R script built and run by this module", is_optional => 0, is_input => 1},
		coverage_output_file     => { is => 'Text', doc => "PDF Coverage output file", is_optional => 0, is_input => 1, is_output => 1 },
		copynumber_output_file     => { is => 'Text', doc => "PDF Copynumber output file", is_optional => 0, is_input => 1, is_output => 1 },
		skip_if_output_is_present     => { is => 'Text', doc => "Skip if Output is Present", is_optional => 1, is_input => 1, default => 0},
	],
};

sub sub_command_sort_position { 1 }

sub help_brief {                            # keep this to just a few words <---
    "Inputs of Varscan and Copynumber, Output of R plots"                 
}

sub help_synopsis {
    return <<EOS
Inputs of Varscan and Copynumber, Output of R plots
EXAMPLE:	gmt validation coverage-copynumber-plot --varscan-file input.txt --cnvhmm-file input.cn --copynumber-output-file --coverage-output-file --r-script-output-file --varscan-file --sample-id
EXAMPLE:	gmt validation coverage-copynumber-plot --varscan-file /gscmnt/sata843/info/medseq/wschierd/MMY_Validation/Capture_Validation/MMY1/varscan/SNV_alltiers_manrev.txt --cnvhmm-file /gscmnt/sata843/info/medseq/wschierd/MMY_CopyNumber/MMY1_CNV.seg --copynumber-output-file /gscmnt/sata843/info/medseq/wschierd/MMY_Validation/Capture_Validation/MMY1/varscan/MMY1_SNV_alltiers_Copynumber.pdf --coverage-output-file /gscmnt/sata843/info/medseq/wschierd/MMY_Validation/Capture_Validation/MMY1/varscan/MMY1_SNV_alltiers_Coverage.pdf --r-script-output-file /gscmnt/sata843/info/medseq/wschierd/MMY_Validation/Capture_Validation/MMY1/varscan/R.input --sample-id MMY1

EOS
}

sub help_detail {                           # this is what the user will see with the longer version of help. <---
    return <<EOS 

EOS
}


################################################################################################
# Execute - the main program logic
#
################################################################################################

sub execute {                               # replace with real execution logic.
	my $self = shift;

	##inputs##
	my $varscan_file = $self->varscan_file;
	my $copynumber_file = $self->cnvhmm_file;
	my $sample_id = $self->sample_id;
	##outputs##
	my $r_script_output_file = $self->r_script_output_file;
	my $coverage_output_file = $self->coverage_output_file;
	my $copynumber_output_file = $self->copynumber_output_file;
	##options##
	my $r_library = $self->varscan_r_library;
	my $skip_if_output_is_present = $self->skip_if_output_is_present;

	my $outfile_varscan_plus_cn;
	if ($varscan_file =~ m/\.txt$/) {
		$outfile_varscan_plus_cn = $varscan_file;
		$outfile_varscan_plus_cn =~ s/\.txt$//;
		$outfile_varscan_plus_cn .= "_copynumber.txt";
	}
	else {
		$outfile_varscan_plus_cn = "$varscan_file"."_copynumber";
	}


	open(CN_VARSCAN_OUT, ">$outfile_varscan_plus_cn") or die "Can't open output file: $!\n";

	my %copynumber_hash=%{&build_hash($copynumber_file)};

	my $varscan_input = new FileHandle ($varscan_file);
	while (my $line2 = <$varscan_input>) {
		chomp($line2);
		my ($chr, $pos, $ref, $var, $normal_ref, $normal_var, $normal_var_pct, $normal_IUB, $tumor_ref, $tumor_var, $tumor_var_pct, $tumor_IUB, $varscan_call, $germline_pvalue, $somatic_pvalue, @otherstuff) = split(/\t/, $line2);
		my $varscan_cn=&get_cn($chr,$pos,$pos,\%copynumber_hash);
		print CN_VARSCAN_OUT "$line2\t$varscan_cn\n"
	}
	close(CN_VARSCAN_OUT);

	# Open Output
	unless (open(R_COMMANDS,">$r_script_output_file")) {
	    die "Could not open output file '$r_script_output_file' for writing";
	  }

#coverage
#	print R_COMMANDS 'options(echo = FALSE)'."\n";#suppress output to stdout
	print R_COMMANDS 'sink("/dev/null")'."\n";
	print R_COMMANDS "genome=\"$sample_id\";"."\n";
	print R_COMMANDS "source(\"$r_library\");"."\n"; #this contains R functions for loading and graphing VarScan files
	print R_COMMANDS 'library(fpc);'."\n";
	print R_COMMANDS "varscan.load_snp_output(\"$outfile_varscan_plus_cn\",header=F)->xcopy"."\n";
	print R_COMMANDS "varscan.load_snp_output(\"$outfile_varscan_plus_cn\",header=F,min_tumor_depth=100,min_normal_depth=100)->xcopy100"."\n";
	print R_COMMANDS 'z1=subset(xcopy, xcopy$V13 == "Somatic");'."\n";
	print R_COMMANDS 'z2=subset(xcopy100, xcopy100$V13 == "Somatic");'."\n";
	print R_COMMANDS 'covtum1=(z1$V9+z1$V10);'."\n";
	print R_COMMANDS 'covtum2=(z2$V9+z2$V10);'."\n";
	print R_COMMANDS 'maxx=max(c(covtum1,covtum2));'."\n";
	print R_COMMANDS 'covnorm1=(z1$V5+z1$V6);'."\n";
	print R_COMMANDS 'covnorm2=(z2$V5+z2$V6);'."\n";
	print R_COMMANDS 'maxx2=max(c(covnorm1,covnorm2));'."\n";
	print R_COMMANDS 'if (maxx >= 1000) {maxx = 1000};'."\n";
	print R_COMMANDS 'if (maxx2 >= 1000) {maxx2 = 1000};'."\n";
	print R_COMMANDS "pdf(file=\"$coverage_output_file\",width=10,height=7.5);"."\n";
	print R_COMMANDS 'par(mfrow=c(2,3));'."\n";
	print R_COMMANDS 'plot.default(x=z1$V7,y=z1$V11,xlab="Normal Variant Allele Frequency",ylab="Tumor Variant Allele Frequency", main=paste(genome," Allele Frequency"), type="p",pch=19,cex=0.4, col="#FF000039",xlim=c(0,100),ylim=c(0,100));'."\n";
	print R_COMMANDS 'plot.default(x=(z1$V5+z1$V6),y=z1$V7,xlab="Normal Coverage",ylab="Normal Variant Allele Frequency", main=paste(genome," Coverage"), type="p",pch=19,cex=0.4,col="#FF000039",xlim=c(0,maxx2),ylim=c(0,100));'."\n";
	print R_COMMANDS 'lines(c(20,20),c(1,100), col="black");'."\n";
	print R_COMMANDS 'lines(c(30,30),c(1,100), col="blue");'."\n";
	print R_COMMANDS 'lines(c(100,100),c(1,100), col="green4");'."\n";
	print R_COMMANDS 'legend(x="topright", title = "Coverage", c("20x", "30x", "100x"),col=c("black","blue","green4"),lty = c(1,1,1), lwd = 1);'."\n"; #top right will rarely have any points
	print R_COMMANDS 'plot.default(x=(z1$V9+z1$V10),y=z1$V11,xlab="Tumor Coverage",ylab="Tumor Variant Allele Frequency", main=paste(genome," Coverage"), type="p",pch=19,cex=0.4,col="#FF000039",xlim=c(0,maxx),ylim=c(0,100));'."\n";
	print R_COMMANDS 'lines(c(20,20),c(1,100), col="black");'."\n";
	print R_COMMANDS 'lines(c(30,30),c(1,100), col="blue");'."\n";
	print R_COMMANDS 'lines(c(100,100),c(1,100), col="green4");'."\n";
	print R_COMMANDS 'legend(x="topright", title = "Coverage", c("20x", "30x", "100x"),col=c("black","blue","green4"),lty = c(1,1,1), lwd = 1);'."\n"; #top right will rarely have any points
	print R_COMMANDS 'plot.default(x=z2$V7,y=z2$V11,xlab="Normal Variant Allele Frequency",ylab="Tumor Variant Allele Frequency", main=paste(genome," Allele Frequency"),type="p",pch=19,cex=0.4,col="#FF000039",xlim=c(0,100),ylim=c(0,100));'."\n";
	print R_COMMANDS 'mtext("Normal and Tumor Coverage > 100",cex=0.7, padj=-0.5);'."\n";
	print R_COMMANDS 'plot.default(x=(z2$V5+z2$V6),y=z2$V7,xlab="Normal Coverage",ylab="Normal Variant Allele Frequency", main=paste(genome," Coverage"), type="p",pch=19,cex=0.4,col="#FF000039",xlim=c(0,maxx2),ylim=c(0,100));'."\n";
	print R_COMMANDS 'mtext("Normal and Tumor Coverage > 100",cex=0.7, padj=-0.5);'."\n";
	print R_COMMANDS 'lines(c(20,20),c(1,100), col="black");'."\n";
	print R_COMMANDS 'lines(c(30,30),c(1,100), col="blue");'."\n";
	print R_COMMANDS 'lines(c(100,100),c(1,100), col="green4");'."\n";
	print R_COMMANDS 'legend(x="topright", title = "Coverage", c("20x", "30x", "100x"),col=c("black","blue","green4"),lty = c(1,1,1), lwd = 1);'."\n"; #top right will rarely have any points
	print R_COMMANDS 'plot.default(x=(z2$V9+z2$V10),y=z2$V11,xlab="Tumor Coverage",ylab="Tumor Variant Allele Frequency", main=paste(genome," Coverage"), type="p",pch=19,cex=0.4,col="#FF000039",xlim=c(0,maxx),ylim=c(0,100));'."\n";
	print R_COMMANDS 'mtext("Normal and Tumor Coverage > 100",cex=0.7, padj=-0.5);'."\n";
	print R_COMMANDS 'lines(c(20,20),c(1,100), col="black");'."\n";
	print R_COMMANDS 'lines(c(30,30),c(1,100), col="blue");'."\n";
	print R_COMMANDS 'lines(c(100,100),c(1,100), col="green4");'."\n";
	print R_COMMANDS 'legend(x="topright", title = "Coverage", c("20x", "30x", "100x"),col=c("black","blue","green4"),lty = c(1,1,1), lwd = 1);'."\n"; #top right will rarely have any points
	print R_COMMANDS 'devoff <- dev.off();'."\n";
#copy number
	print R_COMMANDS "pdf(file=\"$copynumber_output_file\",width=10,height=7.5);"."\n";
	print R_COMMANDS 'par(mfrow=c(2,2));'."\n";
	print R_COMMANDS 'cov1=(z1$V20);'."\n";
	print R_COMMANDS 'cov2=(z2$V20);'."\n";
	print R_COMMANDS 'maxx3=max(c(cov1,cov2));'."\n";
	print R_COMMANDS 'if (maxx <= 4) {maxx = 4};'."\n";
	print R_COMMANDS 'plot.default(x=z1$V7,y=z1$V11,xlab="Normal Variant Allele Frequency",ylab="Tumor Variant Allele Frequency", main=paste(genome," Allele Frequency"), type="p",pch=19,cex=0.4,col="#FF000055",xlim=c(0,100),ylim=c(0,100));'."\n";
	print R_COMMANDS 'plot.default(x=z1$V20,y=z1$V11,xlab="Copy Number",ylab="Tumor Variant Allele Frequency", main=paste(genome," Copy Number"), type="p",pch=19,cex=0.4,col="#FF000055",xlim=c(0,maxx3),ylim=c(0,100));'."\n";
	print R_COMMANDS 'plot.default(x=z2$V7,y=z2$V11,xlab="Normal Variant Allele Frequency",ylab="Tumor Variant Allele Frequency", main=paste(genome," Allele Frequency"), type="p",pch=19,cex=0.4,col="#FF000055",xlim=c(0,100),ylim=c(0,100));'."\n";
	print R_COMMANDS 'mtext("Normal and Tumor Coverage > 100",cex=0.7, padj=-0.5);'."\n";
	print R_COMMANDS 'plot.default(x=z2$V20,y=z2$V11,xlab="Copy Number",ylab="Tumor Variant Allele Frequency", main=paste(genome," Copy Number"), type="p",pch=19,cex=0.4,col="#FF000055",xlim=c(0,maxx3),ylim=c(0,100));'."\n";
	print R_COMMANDS 'mtext("Normal and Tumor Coverage > 100",cex=0.7, padj=-0.5);'."\n";
	print R_COMMANDS 'devoff <- dev.off();'."\n";
	print R_COMMANDS "q()\n";

	close R_COMMANDS;

	my $cmd = "R --vanilla --slave \< $r_script_output_file";
	my $return = Genome::Sys->shellcmd(
           cmd => "$cmd",
           output_files => [$coverage_output_file, $copynumber_output_file],
           skip_if_output_is_present => $skip_if_output_is_present,
	   );
	unless($return) { 
		$self->error_message("Failed to execute: Returned $return");
		die $self->error_message;
	}
	return $return;
}

sub get_cn
{
    my ($chr,$start,$stop,$hashref)=@_;
    my %info_hash=%{$hashref};
    my $cn;
    foreach my $ch (sort keys %info_hash)
    {
	next unless ($chr eq $ch);
	foreach my $region (sort keys %{$info_hash{$ch}})
	{
	    my ($reg_start,$reg_stop)=split/\_/,$region;
	    if ($reg_start<=$start && $reg_stop>=$stop)
	    {
		$cn=$info_hash{$ch}{$region};
		last;
		
	    }
	}
    }

    $cn=2 unless ($cn);
    return $cn;
}


sub build_hash
{
    my ($file)=@_;
    my %info_hash;
    my $fh=new FileHandle($file);
    while(my $line = <$fh>)
    {
	chomp($line);
	unless ($line =~ /^\w+\t\d+\t\d+\t/) { next;}
	my ($chr,$start,$end,$size,$nmarkers,$cn,$adjusted_cn,$score)=split(/\t/, $line);
	my $pos=$start."_".$end;
	$info_hash{$chr}{$pos}=$adjusted_cn;
    }
    return \%info_hash;
}




