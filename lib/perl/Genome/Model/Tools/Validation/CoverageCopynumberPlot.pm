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

	my %copynumber_hash_tumor=%{&build_hash($copynumber_file,'tumor')};
	my %copynumber_hash_normal=%{&build_hash($copynumber_file,'normal')};

	my $varscan_input = new FileHandle ($varscan_file);
	while (my $line2 = <$varscan_input>) {
		chomp($line2);
		my ($chr, $pos, $ref, $var, $normal_ref, $normal_var, $normal_var_pct, $normal_IUB, $tumor_ref, $tumor_var, $tumor_var_pct, $tumor_IUB, $varscan_call, $germline_pvalue, $somatic_pvalue, @otherstuff) = split(/\t/, $line2);
		my $varscan_cn_tumor=&get_cn($chr,$pos,$pos,\%copynumber_hash_tumor);
		my $varscan_cn_normal=&get_cn($chr,$pos,$pos,\%copynumber_hash_normal);
		print CN_VARSCAN_OUT "$line2\t$varscan_cn_tumor\t$varscan_cn_normal\n"
	}
	close(CN_VARSCAN_OUT);

	# Open Output
	unless (open(R_COMMANDS,">$r_script_output_file")) {
	    die "Could not open output file '$r_script_output_file' for writing";
	  }

=cut
# Add boxplots to a scatterplot
par(fig=c(0,0.8,0,0.8), new=TRUE)
plot(mtcars$wt, mtcars$mpg, xlab="Miles Per Gallon",
  ylab="Car Weight")
par(fig=c(0,0.8,0.55,1), new=TRUE)
boxplot(mtcars$wt, horizontal=TRUE, axes=FALSE)
par(fig=c(0.65,1,0,0.8),new=TRUE)
boxplot(mtcars$mpg, axes=FALSE)
mtext("Enhanced Scatterplot", side=3, outer=TRUE, line=-3) 
=cut

#coverage
#	print R_COMMANDS 'options(echo = FALSE)'."\n";#suppress output to stdout
#	print R_COMMANDS 'sink("/dev/null")'."\n";
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
	print R_COMMANDS 'maxx = 800;'."\n";
	print R_COMMANDS 'maxx2 = 800;'."\n";

	print R_COMMANDS 'cn1minus=subset(z1, z1$V20 >= 0 & z1$V20 <= 1.75);'."\n";
	print R_COMMANDS 'cn2=subset(z1, z1$V20 >= 1.75 & z1$V20 <= 2.25);'."\n";
	print R_COMMANDS 'cn3=subset(z1, z1$V20 >= 2.25 & z1$V20 <= 3.5);'."\n";
	print R_COMMANDS 'cn4plus=subset(z1, z1$V20 >= 3.5);'."\n";
	print R_COMMANDS 'cn1minus100x=subset(z2, c(z2$V20 >= 0, z2$V20 <= 1.75));'."\n";
	print R_COMMANDS 'cn2100x=subset(z2, c(z2$V20 >= 1.75, z2$V20 <= 2.25));'."\n";
	print R_COMMANDS 'cn3100x=subset(z2, c(z2$V20 >= 2.25, z2$V20 <= 3.5));'."\n";
	print R_COMMANDS 'cn4plus100x=subset(z2, z2$V20 >= 3.5);'."\n";

	print R_COMMANDS 'cov20x=subset(z1, (z1$V9+z1$V10) <= 20);'."\n";
	print R_COMMANDS 'cov50x=subset(z1, (z1$V9+z1$V10) >= 20 & (z1$V9+z1$V10) <= 50);'."\n";
	print R_COMMANDS 'cov100x=subset(z1, (z1$V9+z1$V10) >= 50 & (z1$V9+z1$V10) <= 100);'."\n";
	print R_COMMANDS 'cov100xplus=subset(z1, (z1$V9+z1$V10) >= 100);'."\n";

	print R_COMMANDS "pdf(file=\"$coverage_output_file\",width=10,height=7.5);"."\n";
	print R_COMMANDS 'par(mfrow=c(2,3));'."\n";
=cut
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
=cut

	print R_COMMANDS 'plot.default(x=cn1minus$V7,y=cn1minus$V11,xlab="Normal Variant Allele Frequency",ylab="Tumor Variant Allele Frequency", main=paste(genome," Variant Allele Frequency"), type="p",pch=19,cex=0.4,col="#FF000055",xlim=c(0,100),ylim=c(0,100));'."\n";
	print R_COMMANDS 'points(x=cn2$V7,y=cn2$V11, type="p",pch=19,cex=0.4,col="#00FF0055");'."\n";
	print R_COMMANDS 'points(x=cn3$V7,y=cn3$V11, type="p",pch=19,cex=0.4,col="#0000FF55");'."\n";
	print R_COMMANDS 'points(x=cn4plus$V7,y=cn4plus$V11, type="p",pch=19,cex=0.4,col="#FFA500FF");'."\n";
	print R_COMMANDS 'legend(x="topright", title = "Copy Number", c("1", "2", "3", "4+"),col=c("#FF0000","#00FF00","#0000FF","#FFA500"),pch=19);'."\n"; #top right will rarely have any points
	print R_COMMANDS 'plot.default(x=(cn1minus$V5+cn1minus$V6),y=(cn1minus$V7),xlab="Normal Coverage",ylab="Normal Variant Allele Frequency", main=paste(genome," Coverage"), type="p",pch=19,cex=0.4,col="#FF000039",xlim=c(0,maxx2),ylim=c(0,100));'."\n";
	print R_COMMANDS 'points(x=(cn2$V5+cn2$V6),y=(cn2$V7), type="p",pch=19,cex=0.4,col="#00FF0055");'."\n";
	print R_COMMANDS 'points(x=(cn3$V5+cn3$V6),y=(cn3$V7), type="p",pch=19,cex=0.4,col="#0000FF55");'."\n";
	print R_COMMANDS 'points(x=(cn4plus$V5+cn4plus$V6),y=(cn4plus$V7), type="p",pch=19,cex=0.4,col="#FFA500FF");'."\n";
	print R_COMMANDS 'lines(c(20,20),c(1,100), col="black");'."\n";
	print R_COMMANDS 'lines(c(30,30),c(1,100), col="blue");'."\n";
	print R_COMMANDS 'lines(c(100,100),c(1,100), col="green4");'."\n";
	print R_COMMANDS 'legend(x="topright", title = "Copy Number", c("1", "2", "3", "4+"),col=c("#FF0000","#00FF00","#0000FF","#FFA500"),pch=19);'."\n"; #top right will rarely have any points
	print R_COMMANDS 'legend(x="right", title = "Coverage", c("20x", "30x", "100x"),col=c("black","blue","green4"),lty = c(1,1,1), lwd = 1);'."\n"; #top right will rarely have any points
	print R_COMMANDS 'plot.default(x=(cn1minus$V9+cn1minus$V10),y=(cn1minus$V11),xlab="Tumor Coverage",ylab="Tumor Variant Allele Frequency", main=paste(genome," Coverage"), type="p",pch=19,cex=0.4,col="#FF000039",xlim=c(0,maxx),ylim=c(0,100));'."\n";
	print R_COMMANDS 'points(x=(cn2$V9+cn2$V10),y=(cn2$V11), type="p",pch=19,cex=0.4,col="#00FF0055");'."\n";
	print R_COMMANDS 'points(x=(cn3$V9+cn3$V10),y=(cn3$V11), type="p",pch=19,cex=0.4,col="#0000FF55");'."\n";
	print R_COMMANDS 'points(x=(cn4plus$V9+cn4plus$V10),y=(cn4plus$V11), type="p",pch=19,cex=0.4,col="#FFA500FF");'."\n";
	print R_COMMANDS 'lines(c(20,20),c(1,100), col="black");'."\n";
	print R_COMMANDS 'lines(c(30,30),c(1,100), col="blue");'."\n";
	print R_COMMANDS 'lines(c(100,100),c(1,100), col="green4");'."\n";
	print R_COMMANDS 'legend(x="topright", title = "Copy Number", c("1", "2", "3", "4+"),col=c("#FF0000","#00FF00","#0000FF","#FFA500"),pch=19);'."\n"; #top right will rarely have any points
	print R_COMMANDS 'legend(x="bottomright", title = "Coverage", c("20x", "30x", "100x"),col=c("black","blue","green4"),lty = c(1,1,1), lwd = 1);'."\n"; #top right will rarely have any points
	print R_COMMANDS 'plot.default(x=cn1minus100x$V7,y=cn1minus100x$V11,xlab="Normal Variant Allele Frequency",ylab="Tumor Variant Allele Frequency", main=paste(genome," Allele Frequency"),type="p",pch=19,cex=0.4,col="#FF000039",xlim=c(0,100),ylim=c(0,100));'."\n";
	print R_COMMANDS 'points(x=cn2100x$V7,y=cn2100x$V11, type="p",pch=19,cex=0.4,col="#00FF0055");'."\n";
	print R_COMMANDS 'points(x=cn3100x$V7,y=cn3100x$V11, type="p",pch=19,cex=0.4,col="#0000FF55");'."\n";
	print R_COMMANDS 'points(x=cn4plus100x$V7,y=cn4plus100x$V11, type="p",pch=19,cex=0.4,col="#FFA500FF");'."\n";
	print R_COMMANDS 'legend(x="topright", title = "Copy Number", c("1", "2", "3", "4+"),col=c("#FF0000","#00FF00","#0000FF","#FFA500"),pch=19);'."\n"; #top right will rarely have any points
	print R_COMMANDS 'mtext("Normal and Tumor Coverage > 100",cex=0.7, padj=-0.5);'."\n";
	print R_COMMANDS 'plot.default(x=(cn1minus100x$V5+cn1minus100x$V6),y=(cn1minus100x$V7),xlab="Normal Coverage",ylab="Normal Variant Allele Frequency", main=paste(genome," Coverage"), type="p",pch=19,cex=0.4,col="#FF000039",xlim=c(0,maxx2),ylim=c(0,100));'."\n";
	print R_COMMANDS 'points(x=(cn2100x$V5+cn2100x$V6),y=(cn2100x$V7), type="p",pch=19,cex=0.4,col="#00FF0055");'."\n";
	print R_COMMANDS 'points(x=(cn3100x$V5+cn3100x$V6),y=(cn3100x$V7), type="p",pch=19,cex=0.4,col="#0000FF55");'."\n";
	print R_COMMANDS 'points(x=(cn4plus100x$V5+cn4plus100x$V6),y=(cn4plus100x$V7), type="p",pch=19,cex=0.4,col="#FFA500FF");'."\n";
	print R_COMMANDS 'mtext("Normal and Tumor Coverage > 100",cex=0.7, padj=-0.5);'."\n";
	print R_COMMANDS 'lines(c(20,20),c(1,100), col="black");'."\n";
	print R_COMMANDS 'lines(c(30,30),c(1,100), col="blue");'."\n";
	print R_COMMANDS 'lines(c(100,100),c(1,100), col="green4");'."\n";
	print R_COMMANDS 'legend(x="topright", title = "Copy Number", c("1", "2", "3", "4+"),col=c("#FF0000","#00FF00","#0000FF","#FFA500"),pch=19);'."\n"; #top right will rarely have any points
	print R_COMMANDS 'legend(x="right", title = "Coverage", c("20x", "30x", "100x"),col=c("black","blue","green4"),lty = c(1,1,1), lwd = 1);'."\n"; #top right will rarely have any points
	print R_COMMANDS 'plot.default(x=(cn1minus100x$V9+cn1minus100x$V10),y=(cn1minus100x$V11),xlab="Tumor Coverage",ylab="Tumor Variant Allele Frequency", main=paste(genome," Coverage"), type="p",pch=19,cex=0.4,col="#FF000039",xlim=c(0,maxx),ylim=c(0,100));'."\n";
	print R_COMMANDS 'points(x=(cn2100x$V9+cn2100x$V10),y=(cn2100x$V11), type="p",pch=19,cex=0.4,col="#00FF0055");'."\n";
	print R_COMMANDS 'points(x=(cn3100x$V9+cn3100x$V10),y=(cn3100x$V11), type="p",pch=19,cex=0.4,col="#0000FF55");'."\n";
	print R_COMMANDS 'points(x=(cn4plus100x$V9+cn4plus100x$V10),y=(cn4plus100x$V11), type="p",pch=19,cex=0.4,col="#FFA500FF");'."\n";
	print R_COMMANDS 'mtext("Normal and Tumor Coverage > 100",cex=0.7, padj=-0.5);'."\n";
	print R_COMMANDS 'lines(c(20,20),c(1,100), col="black");'."\n";
	print R_COMMANDS 'lines(c(30,30),c(1,100), col="blue");'."\n";
	print R_COMMANDS 'lines(c(100,100),c(1,100), col="green4");'."\n";
	print R_COMMANDS 'legend(x="topright", title = "Copy Number", c("1", "2", "3", "4+"),col=c("#FF0000","#00FF00","#0000FF","#FFA500"),pch=19);'."\n"; #top right will rarely have any points
	print R_COMMANDS 'legend(x="bottomright", title = "Coverage", c("20x", "30x", "100x"),col=c("black","blue","green4"),lty = c(1,1,1), lwd = 1);'."\n"; #top right will rarely have any points
	print R_COMMANDS 'devoff <- dev.off();'."\n";
#copy number
	print R_COMMANDS "pdf(file=\"$copynumber_output_file\",width=10,height=7.5);"."\n";
	print R_COMMANDS 'par(mfrow=c(2,2));'."\n";
	print R_COMMANDS 'cov1=(z1$V20);'."\n";
	print R_COMMANDS 'cov2=(z2$V20);'."\n";
	print R_COMMANDS 'maxx3=max(c(cov1,cov2));'."\n";
	print R_COMMANDS 'if (maxx <= 4) {maxx = 4};'."\n";
=cut
	print R_COMMANDS 'plot.default(x=z1$V7,y=z1$V11,xlab="Normal Variant Allele Frequency",ylab="Tumor Variant Allele Frequency", main=paste(genome," Allele Frequency"), type="p",pch=19,cex=0.4,col="#FF000055",xlim=c(0,100),ylim=c(0,100));'."\n";
	print R_COMMANDS 'plot.default(x=z1$V20,y=z1$V11,xlab="Copy Number",ylab="Tumor Variant Allele Frequency", main=paste(genome," Tumor Copy Number"), type="p",pch=19,cex=0.4,col="#FF000055",xlim=c(0,maxx3),ylim=c(0,100));'."\n";
#	print R_COMMANDS 'plot.default(x=z1$V21,y=z1$V7,xlab="Copy Number",ylab="Normal Variant Allele Frequency", main=paste(genome," Normal Copy Number"), type="p",pch=19,cex=0.4,col="#FF000055",xlim=c(0,maxx3),ylim=c(0,100));'."\n";
	print R_COMMANDS 'plot.default(x=z2$V7,y=z2$V11,xlab="Normal Variant Allele Frequency",ylab="Tumor Variant Allele Frequency", main=paste(genome," Allele Frequency"), type="p",pch=19,cex=0.4,col="#FF000055",xlim=c(0,100),ylim=c(0,100));'."\n";
	print R_COMMANDS 'mtext("Normal and Tumor Coverage > 100",cex=0.7, padj=-0.5);'."\n";
	print R_COMMANDS 'plot.default(x=z2$V20,y=z2$V11,xlab="Copy Number",ylab="Tumor Variant Allele Frequency", main=paste(genome," Tumor Copy Number"), type="p",pch=19,cex=0.4,col="#FF000055",xlim=c(0,maxx3),ylim=c(0,100));'."\n";
	print R_COMMANDS 'mtext("Normal and Tumor Coverage > 100",cex=0.7, padj=-0.5);'."\n";
#	print R_COMMANDS 'plot.default(x=z2$V7,y=z2$V21,xlab="Copy Number",ylab="Normal Variant Allele Frequency", main=paste(genome," Normal Copy Number"), type="p",pch=19,cex=0.4,col="#FF000055",xlim=c(0,maxx3),ylim=c(0,100));'."\n";
#	print R_COMMANDS 'mtext("Normal and Tumor Coverage > 100",cex=0.7, padj=-0.5);'."\n";

=cut
	print R_COMMANDS 'den1 <- density(cn1minus$V11, bw=4, from=0,to=100,na.rm=TRUE);'."\n";
	print R_COMMANDS 'den2 <- density(cn2$V11, bw=4, from=0,to=100,na.rm=TRUE);'."\n";
	print R_COMMANDS 'den3 <- density(cn3$V11, bw=4, from=0,to=100,na.rm=TRUE);'."\n";
	print R_COMMANDS 'den4 <- density(cn4plus$V11, bw=4, from=0,to=100,na.rm=TRUE);'."\n";
	print R_COMMANDS 'den1100x <- density(cn1minus100x$V11, bw=4, from=0,to=100,na.rm=TRUE);'."\n";
	print R_COMMANDS 'den2100x <- density(cn2100x$V11, bw=4, from=0,to=100,na.rm=TRUE);'."\n";
	print R_COMMANDS 'den3100x <- density(cn3100x$V11, bw=4, from=0,to=100,na.rm=TRUE);'."\n";
	print R_COMMANDS 'den4100x <- density(cn4plus100x$V11, bw=4, from=0,to=100,na.rm=TRUE);'."\n";

	print R_COMMANDS 'plot.default(((den2$y * 100)+30),den2$x,xlab="Normal Variant Allele Frequency",ylab="Tumor Variant Allele Frequency",  main=paste(genome," Variant Allele Frequency"),xlim=c(0,100),ylim=c(0,100),col="#00FF0055", type="p",pch=19,cex=0.4);'."\n";
	print R_COMMANDS 'points(((den1$y * 100)+20),den1$x,col="#FF000055", type="p",pch=19,cex=0.4);'."\n";
	print R_COMMANDS 'points(((den3$y * 100)+40),den3$x,col="#0000FF55", type="p",pch=19,cex=0.4);'."\n";
	print R_COMMANDS 'points(((den4$y * 100)+50),den4$x,col="#FFA500FF", type="p",pch=19,cex=0.4);'."\n";
	print R_COMMANDS 'points(x=cn1minus$V7,y=cn1minus$V11, type="p",pch=19,cex=0.4,col="#FF000055");'."\n";
	print R_COMMANDS 'points(x=cn2$V7,y=cn2$V11, type="p",pch=19,cex=0.4,col="#00FF0055");'."\n";
	print R_COMMANDS 'points(x=cn3$V7,y=cn3$V11, type="p",pch=19,cex=0.4,col="#0000FF55");'."\n";
	print R_COMMANDS 'points(x=cn4plus$V7,y=cn4plus$V11, type="p",pch=19,cex=0.4,col="#FFA500FF");'."\n";
	print R_COMMANDS 'legend(x="topright", title = "Copy Number", c("1", "2", "3", "4+"),col=c("#FF0000","#00FF00","#0000FF","#FFA500"),pch=19);'."\n"; #top right will rarely have any points
	print R_COMMANDS 'legend(x="bottomright", title = "Copy Number Density", c("1", "2", "3", "4+"),col=c("#FF0000","#00FF00","#0000FF","#FFA500"),lty = c(1,1,1), lwd = 1);'."\n"; #top right will rarely have any points

	print R_COMMANDS 'plot.default(x=cn1minus100x$V7,y=cn1minus100x$V11,xlab="Normal Variant Allele Frequency",ylab="Tumor Variant Allele Frequency", main=paste(genome," Variant Allele Frequency"), type="p",pch=19,cex=0.4,col="#FF000055",xlim=c(0,100),ylim=c(0,100));'."\n";
	print R_COMMANDS 'points(x=cn2100x$V7,y=cn2100x$V11, type="p",pch=19,cex=0.4,col="#00FF0055");'."\n";
	print R_COMMANDS 'points(x=cn3100x$V7,y=cn3100x$V11, type="p",pch=19,cex=0.4,col="#0000FF55");'."\n";
	print R_COMMANDS 'points(x=cn4plus100x$V7,y=cn4plus100x$V11, type="p",pch=19,cex=0.4,col="#FFA500FF");'."\n";
	print R_COMMANDS 'points(((den1100x$y * 100)+20),den1100x$x,col="#FF000055", type="p",pch=19,cex=0.4);'."\n";
	print R_COMMANDS 'points(((den2100x$y * 100)+30),den2100x$x,col="#00FF0055", type="p",pch=19,cex=0.4);'."\n";
	print R_COMMANDS 'points(((den3100x$y * 100)+40),den3100x$x,col="#0000FF55", type="p",pch=19,cex=0.4);'."\n";
	print R_COMMANDS 'points(((den4100x$y * 100)+50),den4100x$x,col="#FFA500FF", type="p",pch=19,cex=0.4);'."\n";
	print R_COMMANDS 'legend(x="topright", title = "Copy Number", c("1", "2", "3", "4+"),col=c("#FF0000","#00FF00","#0000FF","#FFA500"),pch=19);'."\n"; #top right will rarely have any points
	print R_COMMANDS 'legend(x="bottomright", title = "Copy Number Density", c("1", "2", "3", "4+"),col=c("#FF0000","#00FF00","#0000FF","#FFA500"),lty = c(1,1,1), lwd = 1);'."\n"; #top right will rarely have any points
	print R_COMMANDS 'mtext("Normal and Tumor Coverage > 100",cex=0.7, padj=-0.5);'."\n";

	print R_COMMANDS 'plot.default(x=((cn1minus$V7*cn1minus$V21)-100),y=((cn1minus$V11*cn1minus$V20)-100),xlab="Normal Variant Allele Frequency (CN Corrected)",ylab="Tumor Variant Allele Frequency (CN Corrected)", main=paste(genome," Copy Number"), type="p",pch=19,cex=0.4,col="#FF000055",xlim=c(-100,100),ylim=c(-100,100));'."\n";
	print R_COMMANDS 'points(x=((cn2$V7*cn2$V21) - 100),y=((cn2$V11*cn2$V20)-100), type="p",pch=19,cex=0.4,col="#00FF0055");'."\n";
	print R_COMMANDS 'points(x=((cn3$V7*cn3$V21)-100),y=((cn3$V11*cn3$V20)-100), type="p",pch=19,cex=0.4,col="#0000FF55");'."\n";
	print R_COMMANDS 'points(x=((cn4plus$V7*cn4plus$V21)-100),y=((cn4plus$V11*cn4plus$V20)-100), type="p",pch=19,cex=0.4,col="#FFA500FF");'."\n";
	print R_COMMANDS 'legend(x="topright", title = "Copy Number", c("1", "2", "3", "4+"),col=c("#FF0000","#00FF00","#0000FF","#FFA500"),pch=19);'."\n"; #top right will rarely have any points

	print R_COMMANDS 'plot.default(x=((cn1minus100x$V7*cn1minus100x$V21)-100),y=((cn1minus100x$V11*cn1minus100x$V20)-100),xlab="Normal Variant Allele Frequency (CN Corrected)",ylab="Tumor Variant Allele Frequency (CN Corrected)", main=paste(genome," Copy Number"), type="p",pch=19,cex=0.4,col="#FF000055",xlim=c(-100,100),ylim=c(-100,100));'."\n";
	print R_COMMANDS 'points(x=((cn2100x$V7*cn2100x$V21) - 100),y=((cn2100x$V11*cn2100x$V20)-100), type="p",pch=19,cex=0.4,col="#00FF0055");'."\n";
	print R_COMMANDS 'points(x=((cn3100x$V7*cn3100x$V21)-100),y=((cn3100x$V11*cn3100x$V20)-100), type="p",pch=19,cex=0.4,col="#0000FF55");'."\n";
	print R_COMMANDS 'points(x=((cn4plus100x$V7*cn4plus100x$V21)-100),y=((cn4plus100x$V11*cn4plus100x$V20)-100), type="p",pch=19,cex=0.4,col="#FFA500FF");'."\n";
	print R_COMMANDS 'legend(x="topright", title = "Copy Number", c("1", "2", "3", "4+"),col=c("#FF0000","#00FF00","#0000FF","#FFA500"),pch=19);'."\n"; #top right will rarely have any points
	print R_COMMANDS 'mtext("Normal and Tumor Coverage > 100",cex=0.7, padj=-0.5);'."\n";


	print R_COMMANDS 'par(mfrow=c(1,1));'."\n";
	print R_COMMANDS 'library(scatterplot3d);'."\n";
	print R_COMMANDS 's3d <- scatterplot3d(x=cov100xplus$V7,z=cov100xplus$V11,y=cov100xplus$V20, type="p", angle=55, scale.y=0.7, cex.symbols=0.4, pch=19,xlab="Normal Variant Allele Frequency",zlab="Tumor Variant Allele Frequency",ylab="Copy Number",xlim=c(0,100),zlim=c(0,100),ylim=c(0,5),color="#00FF00FF",box=FALSE);'."\n";
	print R_COMMANDS 's3d$points3d(x=cov20x$V7,z=cov20x$V11,y=cov20x$V20, type="p",pch=19,cex=0.4,col="#FF0000FF");'."\n";
	print R_COMMANDS 's3d$points3d(x=cov50x$V7,z=cov50x$V11,y=cov50x$V20, type="p",pch=19,cex=0.4,col="#0000FFFF");'."\n";
	print R_COMMANDS 's3d$points3d(x=cov100x$V7,z=cov100x$V11,y=cov100x$V20, type="p",pch=19,cex=0.4,col="#FFA500FF");'."\n";
	print R_COMMANDS 'legend(x="topright", title = "Coverage", c("0-20x", "20-50x", "50-100x", "100+x"),col=c("#FF0000","#0000FF","#FFA500","#00FF00"),pch=19);'."\n"; #top right will rarely have any points

	print R_COMMANDS 'cn1cov = (cn1minus$V9+cn1minus$V10);'."\n";
	print R_COMMANDS 'cn2cov = (cn2$V9+cn2$V10);'."\n";
	print R_COMMANDS 'cn3cov = (cn3$V9+cn3$V10);'."\n";
	print R_COMMANDS 'cn4cov = (cn4plus$V9+cn4plus$V10);'."\n";
	print R_COMMANDS 's3d <- scatterplot3d(x=cn2$V7,z=cn2$V11,y=cn2cov, type="p", angle=55, scale.y=0.7, cex.symbols=0.4, pch=19,xlab="Normal Variant Allele Frequency",zlab="Tumor Variant Allele Frequency",ylab="Coverage",xlim=c(0,100),zlim=c(0,100),ylim=c(0,maxx),color="#00FF00FF",box=FALSE);'."\n";
	print R_COMMANDS 's3d$points3d(x=cn1minus$V7,z=cn1minus$V11,y=cn1cov, type="p",pch=19,cex=0.4,col="#FF0000FF");'."\n";
	print R_COMMANDS 's3d$points3d(x=cn3$V7,z=cn3$V11,y=cn3cov, type="p",pch=19,cex=0.4,col="#0000FFFF");'."\n";
	print R_COMMANDS 's3d$points3d(x=cn4plus$V7,z=cn4plus$V11,y=cn4cov, type="p",pch=19,cex=0.4,col="#FFA500FF");'."\n";
	print R_COMMANDS 'legend(x="topright", title = "Copy Number", c("1", "2", "3", "4+"),col=c("#FF0000","#00FF00","#0000FF","#FFA500"),pch=19);'."\n"; #top right will rarely have any points

#	print R_COMMANDS 'plot.default(den,xlab="Normal Variant Allele Frequency",ylab="Tumor Variant Allele Frequency",  main=paste(genome," Variant Allele Frequency"));'."\n";
#	print R_COMMANDS 'library(lattice);'."\n";
#	print R_COMMANDS 'cloud(cn1minus$V20 ~ cn1minus$V7 * cn1minus$V11);'."\n";
#	print R_COMMANDS 'cloud(cn2$V20 ~ cn2$V7 * cn2$V11);'."\n";
#	print R_COMMANDS 'cloud(cn3$V20 ~ cn2$V7 * cn3$V11);'."\n";
#	print R_COMMANDS 'cloud(cn4plus$V20 ~ cn4plus$V7 * cn4plus$V11);'."\n";
=cut

cloud(Sepal.Length ~ Petal.Length * Petal.Width, data = iris,
groups = Species, screen = list(z = 20, x = -70),
perspective = FALSE,
key = list(title = "Iris Data", x = .15, y=.85, corner = c(0,1),
border = TRUE,
points = Rows(trellis.par.get("superpose.symbol"), 1:3),
text = list(levels(iris$Species))))
%$%


library(scatterplot3d)
s3d <- scatterplot3d(trees, type="h", highlight.3d=TRUE,
angle=55, scale.y=0.7, pch=16, main="scatterplot3d - 5")
# Now adding some points to the "scatterplot3d"
s3d$points3d(seq(10,20,2), seq(85,60,-5), seq(60,10,-10),
col="blue", type="h", pch=16)
# Now adding a regression plane to the "scatterplot3d"
attach(trees)
my.lm <- lm(Volume ~ Girth + Height)
s3d$plane3d(my.lm)
=cut
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
    my ($file, $tumnor)=@_;
    my %info_hash;
    my $fh=new FileHandle($file);
    while(my $line = <$fh>)
    {
	chomp($line);
	unless ($line =~ /^\w+\t\d+\t\d+\t/) { next;}
	my ($chr,$start,$end,$size,$nmarkers,$cn,$adjusted_cn,$cn_normal,$adjusted_cn_normal,$score)=split(/\t/, $line);
	my $pos=$start."_".$end;
	if ($tumnor eq 'tumor') {
		$info_hash{$chr}{$pos}=$adjusted_cn;
	}
	elsif ($tumnor eq 'normal') {
		$info_hash{$chr}{$pos}=$adjusted_cn_normal;
	}
    }
    return \%info_hash;
}




