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

	## Build temp file for positions where readcounts are needed ##
	my ($tfh,$temp_path) = Genome::Sys->create_temp_file;
	unless($tfh) {
		$self->error_message("Unable to create temporary file $!");
		die;
	}
	$temp_path =~ s/\:/\\\:/g;

	my %copynumber_hash_tumor=%{&build_hash($copynumber_file,'tumor')};
	my %copynumber_hash_normal=%{&build_hash($copynumber_file,'normal')};

	my $varscan_input = new FileHandle ($varscan_file);
	while (my $line2 = <$varscan_input>) {
		chomp($line2);
		my ($chr, $pos, $ref, $var, $normal_ref, $normal_var, $normal_var_pct, $normal_IUB, $tumor_ref, $tumor_var, $tumor_var_pct, $tumor_IUB, $varscan_call, $germline_pvalue, $somatic_pvalue, @otherstuff) = split(/\t/, $line2);
		my $varscan_cn_tumor=&get_cn($chr,$pos,$pos,\%copynumber_hash_tumor);
		my $varscan_cn_normal=&get_cn($chr,$pos,$pos,\%copynumber_hash_normal);
		print $tfh "$line2\t$varscan_cn_tumor\t$varscan_cn_normal\n"
	}
	$tfh->close;

	# Open Output
	unless (open(R_COMMANDS,">$r_script_output_file")) {
	    die "Could not open output file '$r_script_output_file' for writing";
	  }

#coverage
        my $readcount_cutoff = 100;
        my $R_command = <<"_END_OF_R_";
#options(echo = FALSE);#suppress output to stdout
sink("/dev/null");
genome=\"$sample_id\";
source(\"$r_library\"); #this contains R functions for loading and graphing VarScan files
library(fpc);
library(scatterplot3d);
varscan.load_snp_output(\"$temp_path\",header=F)->xcopy;
varscan.load_snp_output(\"$temp_path\",header=F,min_tumor_depth=$readcount_cutoff,min_normal_depth=$readcount_cutoff)->xcopy100;
z1=subset(xcopy, xcopy\$V13 == "Somatic");
z2=subset(xcopy100, xcopy100\$V13 == "Somatic");
covtum1=(z1\$V9+z1\$V10);
covtum2=(z2\$V9+z2\$V10);
maxx=max(c(covtum1,covtum2));
covnorm1=(z1\$V5+z1\$V6);
covnorm2=(z2\$V5+z2\$V6);
maxx2=max(c(covnorm1,covnorm2));
if (maxx >= 1000) {maxx = 1000};
if (maxx2 >= 1000) {maxx2 = 1000};
maxx = 800;
maxx2 = 800;

cn1minus=subset(z1, z1\$V20 >= 0 & z1\$V20 <= 1.75);
cn2=subset(z1, z1\$V20 >= 1.75 & z1\$V20 <= 2.25);
cn3=subset(z1, z1\$V20 >= 2.25 & z1\$V20 <= 3.5);
cn4plus=subset(z1, z1\$V20 >= 3.5);
cn1minus100x=subset(z2, z2\$V20 >= 0 & z2\$V20 <= 1.75);
cn2100x=subset(z2, z2\$V20 >= 1.75 & z2\$V20 <= 2.25);
cn3100x=subset(z2, z2\$V20 >= 2.25 & z2\$V20 <= 3.5);
cn4plus100x=subset(z2, z2\$V20 >= 3.5);

cov20x=subset(z1, (z1\$V9+z1\$V10) <= 20);
cov50x=subset(z1, (z1\$V9+z1\$V10) >= 20 & (z1\$V9+z1\$V10) <= 50);
cov100x=subset(z1, (z1\$V9+z1\$V10) >= 50 & (z1\$V9+z1\$V10) <= 100);
cov100xplus=subset(z1, (z1\$V9+z1\$V10) >= 100);

den1 <- 0;
den2 <- 0;
den3 <- 0;
den4 <- 0;
den1factor = 0; den2factor = 0; den3factor = 0; den4factor = 0;
den1factor100 = 0; den2factor100 = 0; den3factor100 = 0; den4factor100 = 0;
N = dim(z1)[1];
N100 = dim(z2)[1];

den1100x <-  0;
den2100x <-  0;
den3100x <-  0;
den4100x <-  0;

if(dim(cn1minus)[1] < 2) {den1\$x = den1\$y=1000;} else {den1 <- density(cn1minus\$V11, from=0,to=100,na.rm=TRUE); den1factor = dim(cn1minus)[1]/N * den1\$y;};
if(dim(cn2)[1] < 2) {den2\$x = den2\$y=1000;} else {den2 <- density(cn2\$V11, from=0,to=100,na.rm=TRUE); den2factor = dim(cn2)[1]/N * den2\$y;};
if(dim(cn3)[1] < 2) {den3\$x = den3\$y=1000;} else {den3 <- density(cn3\$V11, from=0,to=100,na.rm=TRUE); den3factor = dim(cn3)[1]/N * den3\$y;};
if(dim(cn4plus)[1] < 2) {den4\$x = den4\$y=1000;} else {den4 <- density(cn4plus\$V11, from=0,to=100,na.rm=TRUE); den4factor = dim(cn4plus)[1]/N * den4\$y;};

if(dim(cn1minus100x)[1] < 2) {den1100x\$x = den1100x\$y=1000} else {den1100x <- density(cn1minus100x\$V11, from=0,to=100,na.rm=TRUE); den1factor100 = dim(cn1minus100x)[1]/N100 * den1100x\$y;};
if(dim(cn2100x)[1] < 2) {den2100x\$x = den2100x\$y=1000} else {den2100x <- density(cn2100x\$V11, from=0,to=100,na.rm=TRUE);den2factor100 = dim(cn2100x)[1]/N100 * den2100x\$y;};
if(dim(cn3100x)[1] < 2) {den3100x\$x = den3100x\$y=1000} else {den3100x <- density(cn3100x\$V11, from=0,to=100,na.rm=TRUE);den3factor100 = dim(cn3100x)[1]/N100 * den3100x\$y;};
if(dim(cn4plus100x)[1] < 2) {den4100x\$x = den4100x\$y=1000} else {den4100x <- density(cn4plus100x\$V11, from=0,to=100,na.rm=TRUE);den4factor100 = dim(cn4plus100x)[1]/N100 * den4100x\$y;};

dennormcov <- density((z1\$V5+z1\$V6), bw=4, from=0,to=800,na.rm=TRUE);
dennormcov100x <- density((z2\$V5+z2\$V6), bw=4, from=0,to=800,na.rm=TRUE);
dentumcov <- density((z1\$V9+z1\$V10), bw=4, from=0,to=600,na.rm=TRUE);
dentumcov100x <- density((z2\$V9+z2\$V10), bw=4, from=0,to=600,na.rm=TRUE);

_END_OF_R_
        print R_COMMANDS "$R_command\n";


        #open up image for plotting
        if ($coverage_output_file =~ /.pdf/) {
            print R_COMMANDS "pdf(file=\"$coverage_output_file\",width=10,height=7.5,bg=\"white\");"."\n";
        }
        elsif ($coverage_output_file =~ /.png/) {
            print R_COMMANDS "png(file=\"$coverage_output_file\",width=1200,height=800);"."\n";
        }
        else {
            die "unrecognized coverage output file type...please append .pdf or .png to the end of your coverage output file\n";
        }

        $R_command = <<"_END_OF_R_";

par(mfrow=c(2,3));

        #NORMAL COVERAGE PLOT
plot.default(x=(cn1minus\$V5+cn1minus\$V6),y=(cn1minus\$V7),xlab="Normal Coverage",ylab="Normal Variant Allele Frequency", main=paste(genome," Coverage"), type="p",pch=19,cex=0.4,col="#FF000039",xlim=c(0,maxx2),ylim=c(0,100));
points(x=(cn2\$V5+cn2\$V6),y=(cn2\$V7), type="p",pch=19,cex=0.4,col="#00FF0055");
points(x=(cn3\$V5+cn3\$V6),y=(cn3\$V7), type="p",pch=19,cex=0.4,col="#0000FF55");
points(x=(cn4plus\$V5+cn4plus\$V6),y=(cn4plus\$V7), type="p",pch=19,cex=0.4,col="#FFA500FF");
points(dennormcov\$x,((dennormcov\$y * 1000)+20),col="#0000000F", type="p",pch=19,cex=0.4);
lines(c(20,20),c(1,100), col="black");
lines(c(30,30),c(1,100), col="blue");
lines(c(100,100),c(1,100), col="green4");
legend(x="topright", title = "Copy Number", c("1", "2", "3", "4+"),col=c("#FF0000","#00FF00","#0000FF","#FFA500"),pch=19);
legend(x="right", title = "Coverage", c("20x", "30x", "100x", "N"),col=c("black","blue","green4","#00000055"),lty = c(1,1,1,1), lwd = c(1,1,1,2));

        #TUMOR CN PLOT
maxden = max(c(den1factor,den2factor,den3factor,den4factor));
finalfactor = 40 / maxden;
plot.default(x=cn1minus\$V7,y=cn1minus\$V11,xlab="Variant Allele Frequency in Normal",ylab="Variant Allele Frequency in Tumor", main=paste(genome,"Variant Allele Frequency"), type="p",pch=19,cex=0.4,col="#FF000055",xlim=c(0,100),ylim=c(0,110));
points(x=cn2\$V7,y=cn2\$V11, type="p",pch=19,cex=0.4,col="#00FF0055");
points(x=cn3\$V7,y=cn3\$V11, type="p",pch=19,cex=0.4,col="#0000FF55");
points(x=cn4plus\$V7,y=cn4plus\$V11, type="p",pch=19,cex=0.4,col="#FFA500FF");
lines(c(60,60),c(10,100),lty=2,col="black");
lines((100-(finalfactor * den1factor)),den1\$x,col="#FF0000AA",lwd=2);
lines((100-(finalfactor * den2factor)),den2\$x,col="#00FF00AA",lwd=2);
lines((100-(finalfactor * den3factor)),den3\$x,col="#0000FFAA",lwd=2);
lines((100-(finalfactor * den4factor)),den4\$x,col="#FFA500AA",lwd=2);
par(mgp = c(0, -1.4, 0));
axis(side=3,at=c(60,100),labels=c(sprintf("%.3f", maxden),0),col="black",tck=0.01);
mtext("CN Density         ",adj=1, cex=0.7, padj=-0.5);
par(mgp = c(3,1,0));
#par(mar=c(5,4,4,2) + 0.1);
legend(x="topleft",horiz=TRUE,xjust=0, c("1", "2", "3", "4+"),col=c("#FF0000","#00FF00","#0000FF","#FFA500"),pch=19,cex=0.9);

        #TUMOR COVERAGE PLOT
plot.default(x=(cn1minus\$V9+cn1minus\$V10),y=(cn1minus\$V11),xlab="Tumor Coverage",ylab="Tumor Variant Allele Frequency", main=paste(genome," Coverage"), type="p",pch=19,cex=0.4,col="#FF000039",xlim=c(0,maxx),ylim=c(0,110));
points(x=(cn2\$V9+cn2\$V10),y=(cn2\$V11), type="p",pch=19,cex=0.4,col="#00FF0055");
points(x=(cn3\$V9+cn3\$V10),y=(cn3\$V11), type="p",pch=19,cex=0.4,col="#0000FF55");
points(x=(cn4plus\$V9+cn4plus\$V10),y=(cn4plus\$V11), type="p",pch=19,cex=0.4,col="#FFA500FF");
points(dentumcov\$x,((dentumcov\$y * 1000)),col="#0000000F", type="p",pch=19,cex=0.4);
lines(c(20,20),c(1,100), col="black");
lines(c(30,30),c(1,100), col="blue");
lines(c(100,100),c(1,100), col="green4");
legend(x="topleft",horiz=TRUE,xjust=0, c("1", "2", "3", "4+"),col=c("#FF0000","#00FF00","#0000FF","#FFA500"),pch=19,cex=0.9);
legend(x="topright", title = "Coverage", c("20x", "30x", "100x", "N"),col=c("black","blue","green4","#00000055"),lty = c(1,1,1,1), lwd = c(1,1,1,2));
        #BEGIN COVERAGE > 100 PLOTS
        #SNP DROPOFF PLOT
        #code for making snp inclusion dropoff picture
rc_cutoffs = 1:800; snps_passed_cutoff = NULL;
for (i in rc_cutoffs) { snps_passed_cutoff[i] = dim(z1[(z1\$V9+z1\$V10) >= i & (z1\$V5+z1\$V6) >= i,])[1]; }
	
plot.default(x=rc_cutoffs,y=snps_passed_cutoff,xlab="Read-count Cut-off",ylab="Number of SNVs", main=paste(genome,"SNVs Passing Read Depth Filter"),cex=0.4);
lines(c($readcount_cutoff,$readcount_cutoff),c(0,snps_passed_cutoff[1]), col=\"blue\");
legend(x="topright", paste("Filter","Cut-off",sep=" "),col=c("blue"),lty = c(1,1,1), lwd = 1);
        #TUMOR CN PLOT
maxden = max(c(den1factor100,den2factor100,den3factor100,den4factor100));
finalfactor = 40 / maxden;
plot.default(x=cn1minus100x\$V7,y=cn1minus100x\$V11,xlab="Normal Variant Allele Frequency",ylab="Tumor Variant Allele Frequency", main=paste(genome," Allele Frequency"),type="p",pch=19,cex=0.4,col="#FF000039",xlim=c(0,100),ylim=c(0,110));
points(x=cn2100x\$V7,y=cn2100x\$V11, type="p",pch=19,cex=0.4,col="#00FF0055");
points(x=cn3100x\$V7,y=cn3100x\$V11, type="p",pch=19,cex=0.4,col="#0000FF55");
points(x=cn4plus100x\$V7,y=cn4plus100x\$V11, type="p",pch=19,cex=0.4,col="#FFA500FF");
lines(c(60,60),c(10,100),lty=2,col="black");
lines((100-(finalfactor * den1factor100)),den1100x\$x,col="#FF0000AA",lwd=2);
lines((100-(finalfactor * den2factor100)),den2100x\$x,col="#00FF00AA",lwd=2);
lines((100-(finalfactor * den3factor100)),den3100x\$x,col="#0000FFAA",lwd=2);
lines((100-(finalfactor * den4factor100)),den4100x\$x,col="#FFA500AA",lwd=2);
par(mgp = c(0, -1.4, 0));
axis(side=3,at=c(60,100),labels=c(sprintf("%.3f", maxden),0),col="black",tck=0.01);
#mtext("CN Density         ",adj=1, cex=0.7, padj=-0.5);
par(mgp = c(3,1,0));
#par(mar=c(5,4,4,2) + 0.1);
legend(x="topleft",horiz=TRUE,xjust=0, c("1", "2", "3", "4+"),col=c("#FF0000","#00FF00","#0000FF","#FFA500"),pch=19,cex=0.9);
mtext("Normal and Tumor Coverage > 100",cex=0.7, padj=-0.5);

        #TUMOR COVERAGE PLOT
#plot.default(x=cn1minus100x\$V7,y=cn1minus100x\$V11,xlab="Normal Variant Allele Frequency",ylab="Tumor Variant Allele Frequency", main=paste(genome," Allele Frequency"),type="p",pch=19,cex=0.4,col="#FF000039",xlim=c(0,100),ylim=c(0,100));
#points(x=cn2100x\$V7,y=cn2100x\$V11, type="p",pch=19,cex=0.4,col="#00FF0055");
#points(x=cn3100x\$V7,y=cn3100x\$V11, type="p",pch=19,cex=0.4,col="#0000FF55");
#points(x=cn4plus100x\$V7,y=cn4plus100x\$V11, type="p",pch=19,cex=0.4,col="#FFA500FF");
#points(((den1100x\$y * 100)+20),den1100x\$x,col="#FF000055", type="p",pch=19,cex=0.4);
#points(((den2100x\$y * 100)+30),den2100x\$x,col="#00FF0055", type="p",pch=19,cex=0.4);
#points(((den3100x\$y * 100)+40),den3100x\$x,col="#0000FF55", type="p",pch=19,cex=0.4);
#points(((den4100x\$y * 100)+50),den4100x\$x,col="#FFA500FF", type="p",pch=19,cex=0.4);
#legend(x="bottomright", title = "CN Density", c("1", "2", "3", "4+"),col=c("#FF0000","#00FF00","#0000FF","#FFA500"),lty = c(1,1,1), lwd = 1);
#legend(x="topright", title = "Copy Number", c("1", "2", "3", "4+"),col=c("#FF0000","#00FF00","#0000FF","#FFA500"),pch=19);
#mtext("Normal and Tumor Coverage > 100",cex=0.7, padj=-0.5);
        #NORMAL COVERAGE PLOT
#plot.default(x=(cn1minus100x\$V5+cn1minus100x\$V6),y=(cn1minus100x\$V7),xlab="Normal Coverage",ylab="Normal Variant Allele Frequency", main=paste(genome," Coverage"), type="p",pch=19,cex=0.4,col="#FF000039",xlim=c(0,maxx2),ylim=c(0,100));
#points(x=(cn2100x\$V5+cn2100x\$V6),y=(cn2100x\$V7), type="p",pch=19,cex=0.4,col="#00FF0055");
#points(x=(cn3100x\$V5+cn3100x\$V6),y=(cn3100x\$V7), type="p",pch=19,cex=0.4,col="#0000FF55");
#points(x=(cn4plus100x\$V5+cn4plus100x\$V6),y=(cn4plus100x\$V7), type="p",pch=19,cex=0.4,col="#FFA500FF");
#points(dennormcov100x\$x,((dennormcov100x\$y * 1000)+20),col="#0000000F", type="p",pch=19,cex=0.4);
#mtext("Normal and Tumor Coverage > 100",cex=0.7, padj=-0.5);
#lines(c(20,20),c(1,100), col="black");
#lines(c(30,30),c(1,100), col="blue");
#lines(c(100,100),c(1,100), col="green4");
#legend(x="topright", title = "Copy Number", c("1", "2", "3", "4+"),col=c("#FF0000","#00FF00","#0000FF","#FFA500"),pch=19);
#legend(x="right", title = "Coverage", c("20x", "30x", "100x", "N"),col=c("black","blue","green4","#00000055"),lty = c(1,1,1,1), lwd = c(1,1,1,2));

        #TUMOR COVERAGE PLOT
plot.default(x=(cn1minus100x\$V9+cn1minus100x\$V10),y=(cn1minus100x\$V11),xlab="Tumor Coverage",ylab="Tumor Variant Allele Frequency", main=paste(genome," Coverage"), type="p",pch=19,cex=0.4,col="#FF000039",xlim=c(0,maxx),ylim=c(0,110));
points(x=(cn2100x\$V9+cn2100x\$V10),y=(cn2100x\$V11), type="p",pch=19,cex=0.4,col="#00FF0055");
points(x=(cn3100x\$V9+cn3100x\$V10),y=(cn3100x\$V11), type="p",pch=19,cex=0.4,col="#0000FF55");
points(x=(cn4plus100x\$V9+cn4plus100x\$V10),y=(cn4plus100x\$V11), type="p",pch=19,cex=0.4,col="#FFA500FF");
points(dentumcov100x\$x,((dentumcov100x\$y * 1000)),col="#0000000F", type="p",pch=19,cex=0.4);
mtext("Normal and Tumor Coverage > 100",cex=0.7, padj=-0.5);
lines(c(20,20),c(1,100), col="black");
lines(c(30,30),c(1,100), col="blue");
lines(c(100,100),c(1,100), col="green4");
legend(x="topleft",horiz=TRUE,xjust=0, c("1", "2", "3", "4+"),col=c("#FF0000","#00FF00","#0000FF","#FFA500"),pch=19,cex=0.9);
legend(x="topright", title = "Coverage", c("20x", "30x", "100x", "N"),col=c("black","blue","green4","#00000055"),lty = c(1,1,1,1), lwd = c(1,1,1,2));
devoff <- dev.off();

#copy number
pdf(file=\"$copynumber_output_file\",width=10,height=7.5);
par(mfrow=c(2,2));
cov1=(z1\$V20);
cov2=(z2\$V20);
maxx3=max(c(cov1,cov2));
if (maxx <= 4) {maxx = 4};

plot.default(((den2\$y * 100)+30),den2\$x,xlab="Normal Variant Allele Frequency",ylab="Tumor Variant Allele Frequency",  main=paste(genome," Variant Allele Frequency"),xlim=c(0,100),ylim=c(0,100),col="#00FF0055", type="p",pch=19,cex=0.4);
points(((den1\$y * 100)+20),den1\$x,col="#FF000055", type="p",pch=19,cex=0.4);
points(((den3\$y * 100)+40),den3\$x,col="#0000FF55", type="p",pch=19,cex=0.4);
points(((den4\$y * 100)+50),den4\$x,col="#FFA500FF", type="p",pch=19,cex=0.4);
points(x=cn1minus\$V7,y=cn1minus\$V11, type="p",pch=19,cex=0.4,col="#FF000055");
points(x=cn2\$V7,y=cn2\$V11, type="p",pch=19,cex=0.4,col="#00FF0055");
points(x=cn3\$V7,y=cn3\$V11, type="p",pch=19,cex=0.4,col="#0000FF55");
points(x=cn4plus\$V7,y=cn4plus\$V11, type="p",pch=19,cex=0.4,col="#FFA500FF");
legend(x="topright", title = "Copy Number", c("1", "2", "3", "4+"),col=c("#FF0000","#00FF00","#0000FF","#FFA500"),pch=19);
legend(x="bottomright", title = "Copy Number Density", c("1", "2", "3", "4+"),col=c("#FF0000","#00FF00","#0000FF","#FFA500"),lty = c(1,1,1), lwd = 1);

plot.default(x=cn1minus100x\$V7,y=cn1minus100x\$V11,xlab="Normal Variant Allele Frequency",ylab="Tumor Variant Allele Frequency", main=paste(genome," Variant Allele Frequency"), type="p",pch=19,cex=0.4,col="#FF000055",xlim=c(0,100),ylim=c(0,100));
points(x=cn2100x\$V7,y=cn2100x\$V11, type="p",pch=19,cex=0.4,col="#00FF0055");
points(x=cn3100x\$V7,y=cn3100x\$V11, type="p",pch=19,cex=0.4,col="#0000FF55");
points(x=cn4plus100x\$V7,y=cn4plus100x\$V11, type="p",pch=19,cex=0.4,col="#FFA500FF");
points(((den1100x\$y * 100)+20),den1100x\$x,col="#FF000055", type="p",pch=19,cex=0.4);
points(((den2100x\$y * 100)+30),den2100x\$x,col="#00FF0055", type="p",pch=19,cex=0.4);
points(((den3100x\$y * 100)+40),den3100x\$x,col="#0000FF55", type="p",pch=19,cex=0.4);
points(((den4100x\$y * 100)+50),den4100x\$x,col="#FFA500FF", type="p",pch=19,cex=0.4);
legend(x="topright", title = "Copy Number", c("1", "2", "3", "4+"),col=c("#FF0000","#00FF00","#0000FF","#FFA500"),pch=19);
legend(x="bottomright", title = "Copy Number Density", c("1", "2", "3", "4+"),col=c("#FF0000","#00FF00","#0000FF","#FFA500"),lty = c(1,1,1), lwd = 1);
mtext("Normal and Tumor Coverage > 100",cex=0.7, padj=-0.5);

plot.default(x=((cn1minus\$V7*cn1minus\$V21)-100),y=((cn1minus\$V11*cn1minus\$V20)-100),xlab="Normal Variant Allele Frequency (CN Corrected)",ylab="Tumor Variant Allele Frequency (CN Corrected)", main=paste(genome," Copy Number"), type="p",pch=19,cex=0.4,col="#FF000055",xlim=c(-100,100),ylim=c(-100,100));
points(x=((cn2\$V7*cn2\$V21) - 100),y=((cn2\$V11*cn2\$V20)-100), type="p",pch=19,cex=0.4,col="#00FF0055");
points(x=((cn3\$V7*cn3\$V21)-100),y=((cn3\$V11*cn3\$V20)-100), type="p",pch=19,cex=0.4,col="#0000FF55");
points(x=((cn4plus\$V7*cn4plus\$V21)-100),y=((cn4plus\$V11*cn4plus\$V20)-100), type="p",pch=19,cex=0.4,col="#FFA500FF");
legend(x="topright", title = "Copy Number", c("1", "2", "3", "4+"),col=c("#FF0000","#00FF00","#0000FF","#FFA500"),pch=19);

plot.default(x=((cn1minus100x\$V7*cn1minus100x\$V21)-100),y=((cn1minus100x\$V11*cn1minus100x\$V20)-100),xlab="Normal Variant Allele Frequency (CN Corrected)",ylab="Tumor Variant Allele Frequency (CN Corrected)", main=paste(genome," Copy Number"), type="p",pch=19,cex=0.4,col="#FF000055",xlim=c(-100,100),ylim=c(-100,100));
points(x=((cn2100x\$V7*cn2100x\$V21) - 100),y=((cn2100x\$V11*cn2100x\$V20)-100), type="p",pch=19,cex=0.4,col="#00FF0055");
points(x=((cn3100x\$V7*cn3100x\$V21)-100),y=((cn3100x\$V11*cn3100x\$V20)-100), type="p",pch=19,cex=0.4,col="#0000FF55");
points(x=((cn4plus100x\$V7*cn4plus100x\$V21)-100),y=((cn4plus100x\$V11*cn4plus100x\$V20)-100), type="p",pch=19,cex=0.4,col="#FFA500FF");
legend(x="topright", title = "Copy Number", c("1", "2", "3", "4+"),col=c("#FF0000","#00FF00","#0000FF","#FFA500"),pch=19);
mtext("Normal and Tumor Coverage > 100",cex=0.7, padj=-0.5);

par(mfrow=c(1,1));
s3d <- scatterplot3d(x=cov100xplus\$V7,z=cov100xplus\$V11,y=cov100xplus\$V20, type="p", angle=55, scale.y=0.7, cex.symbols=0.4, pch=19,xlab="Normal Variant Allele Frequency",zlab="Tumor Variant Allele Frequency",ylab="Copy Number",xlim=c(0,100),zlim=c(0,100),ylim=c(0,5),color="#00FF00FF",box=FALSE);
s3d\$points3d(x=cov20x\$V7,z=cov20x\$V11,y=cov20x\$V20, type="p",pch=19,cex=0.4,col="#FF0000FF");
s3d\$points3d(x=cov50x\$V7,z=cov50x\$V11,y=cov50x\$V20, type="p",pch=19,cex=0.4,col="#0000FFFF");
s3d\$points3d(x=cov100x\$V7,z=cov100x\$V11,y=cov100x\$V20, type="p",pch=19,cex=0.4,col="#FFA500FF");
legend(x="topright", title = "Coverage", c("0-20x", "20-50x", "50-100x", "100+x"),col=c("#FF0000","#0000FF","#FFA500","#00FF00"),pch=19);

cn1cov = (cn1minus\$V9+cn1minus\$V10);
cn2cov = (cn2\$V9+cn2\$V10);
cn3cov = (cn3\$V9+cn3\$V10);
cn4cov = (cn4plus\$V9+cn4plus\$V10);
s3d <- scatterplot3d(x=cn2\$V7,z=cn2\$V11,y=cn2cov, type="p", angle=55, scale.y=0.7, cex.symbols=0.4, pch=19,xlab="Normal Variant Allele Frequency",zlab="Tumor Variant Allele Frequency",ylab="Coverage",xlim=c(0,100),zlim=c(0,100),ylim=c(0,maxx),color="#00FF00FF",box=FALSE);
s3d\$points3d(x=cn1minus\$V7,z=cn1minus\$V11,y=cn1cov, type="p",pch=19,cex=0.4,col="#FF0000FF");
s3d\$points3d(x=cn3\$V7,z=cn3\$V11,y=cn3cov, type="p",pch=19,cex=0.4,col="#0000FFFF");
s3d\$points3d(x=cn4plus\$V7,z=cn4plus\$V11,y=cn4cov, type="p",pch=19,cex=0.4,col="#FFA500FF");
legend(x="topright", title = "Copy Number", c("1", "2", "3", "4+"),col=c("#FF0000","#00FF00","#0000FF","#FFA500"),pch=19);

#plot.default(den,xlab="Normal Variant Allele Frequency",ylab="Tumor Variant Allele Frequency",  main=paste(genome," Variant Allele Frequency"));
#library(lattice);
#cloud(cn1minus\$V20 ~ cn1minus\$V7 * cn1minus\$V11);
#cloud(cn2\$V20 ~ cn2\$V7 * cn2\$V11);
#cloud(cn3\$V20 ~ cn2\$V7 * cn3\$V11);
#cloud(cn4plus\$V20 ~ cn4plus\$V7 * cn4plus\$V11);

devoff <- dev.off();

q();

_END_OF_R_
        print R_COMMANDS "$R_command\n";

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




