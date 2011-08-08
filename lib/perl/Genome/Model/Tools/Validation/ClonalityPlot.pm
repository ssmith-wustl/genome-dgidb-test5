package Genome::Model::Tools::Validation::ClonalityPlot;

use strict;
use warnings;
use FileHandle;
use Genome;

class Genome::Model::Tools::Validation::ClonalityPlot {
    is => 'Command',                       

    has => [
    varscan_file	=> { is => 'Text', doc => "File of varscan validated calls, ex: ", is_optional => 0, is_input => 1 },
    cnvhmm_file	=> { is => 'Text', doc => "File of cnvhmm whole genome predictions", is_optional => 0, is_input => 1 },
    varscan_r_library	=> { is => 'Text', doc => "File of cnvhmm whole genome predictions", is_optional => 0, is_input => 1, default => '/gscmnt/sata423/info/medseq/analysis/CaptureValidationGraphs/VarScanGraphLib.R'},
    sample_id	=> { is => 'Text', doc => "Sample ID to be put on graphs", is_optional => 1, is_input => 1, default => 'unspecified' },
    analysis_type      => { is => 'Text', doc => "Either \'wgs\' for somatic pipeline output or \'capture\' for validation pipeline output", is_optional => 1, is_input => 1, default => 'capture'},
    chr_highlight      => { is => 'Text', doc => "Choose a Chromosome to Highlight with Purple Circles on Plot", is_optional => 1, is_input => 1, default => 'X'},
    positions_highlight      => { is => 'Text', doc => "A tab-delim file list of positions chr\\tposition to highlight on plots", is_optional => 1, is_input => 1},
    r_script_output_file     => { is => 'Text', doc => "R script built and run by this module", is_optional => 0, is_input => 1},
    output_image     => { is => 'Text', doc => "PDF Coverage output file", is_optional => 0, is_input => 1, is_output => 1 },
    skip_if_output_is_present     => { is => 'Text', doc => "Skip if Output is Present", is_optional => 1, is_input => 1, default => 0},
    ],
};

sub sub_command_sort_position { 1 }

sub help_brief {
    "Plot CN-separated SNV density plots"
}

sub help_synopsis {
    #gmt validation clonality-plot --cnvhmm-file /gscmnt/sata872/info/medseq/luc_wgs/CNV/cnaseg/LUC1.cnaseg --output-image LUC1.clonality.pdf --analysis-type capture --r-script-output-file LUC1.R --varscan-file /gscmnt/sata872/info/medseq/luc_wgs/LUC1/validation/varscan/t123_targeted.pvalue_filtered.somatic --sample-id "LUC1" --positions-highlight test.X.sites
    return <<EOS
Inputs of Varscan and copy-number segmentation data, Output of R plots.
EXAMPLE:	gmt validation clonality-plot --analysis-type 'capture' --varscan-file snvs.txt --cnaseg-file cnaseg.txt --output-image clonality.pdf --sample-id 'Sample'
EXAMPLE:	gmt validation clonality-plot --analysis-type 'capture' --varscan-file snvs.txt --cnaseg-file cnaseg.txt --output-image clonality.pdf --sample-id 'Sample' --r-script-output-file Sample.R --positions-highlight chr.pos.txt
EOS
}

sub help_detail {                           # this is what the user will see with the longer version of help. <---
    return <<EOS
    This tool can be used to plot the CN-separated SNV density plots that are known at GI as 'clonality plots'. Can be used for WGS or Capture data, but was mostly intended for Capture data, and hence the SNV file format is currently Varscan output. 
EOS
}

sub execute {
    my $self = shift;

    ##inputs##
    my $varscan_file = $self->varscan_file;
    my $copynumber_file = $self->cnvhmm_file;
    my $sample_id = $self->sample_id;
    my $readcount_cutoff;
    my $chr_highlight = $self->chr_highlight;
    my $positions_highlight = $self->positions_highlight;
    ##outputs##
    my $r_script_output_file = $self->r_script_output_file;
    my $output_image = $self->output_image;
    ##options##
    my $r_library = $self->varscan_r_library;
    my $skip_if_output_is_present = $self->skip_if_output_is_present;
    my $analysis_type = $self->analysis_type;
    if ($analysis_type eq 'wgs') {
        $readcount_cutoff = 20;
    }
    elsif ($analysis_type eq 'capture') {
        $readcount_cutoff = 100;
    }
    else {
        die "analysis type: $analysis_type not supported, choose either wgs or capture";
    }
    my $position_added = 0;
    my %position_highlight_hash;
    if ($positions_highlight && -s $positions_highlight) {
        my $positions_input = new FileHandle ($positions_highlight);
        while (my $line2 = <$positions_input>) {
            $position_added++;
            chomp($line2);
            my ($chr, $pos) = split(/\t/, $line2);
            my $matcher = "$chr\t$pos";
            $position_highlight_hash{$matcher}++;
        }
    }

    ## Build temp file for positions where readcounts are needed ##
    my ($tfh,$temp_path) = Genome::Sys->create_temp_file;
    unless($tfh) {
        $self->error_message("Unable to create temporary file $!");
        die;
    }
    $temp_path =~ s/\:/\\\:/g;

    ## Build temp file for extra positions to highlight ##
    my ($tfh2,$temp_path2) = Genome::Sys->create_temp_file;
    unless($tfh2) {
        $self->error_message("Unable to create temporary file $!");
        die;
    }
    $temp_path2 =~ s/\:/\\\:/g;

    my %copynumber_hash_tumor=%{&build_hash($copynumber_file,'tumor')};
    my %copynumber_hash_normal=%{&build_hash($copynumber_file,'normal')};
    my $varscan_input = new FileHandle ($varscan_file);
    while (my $line2 = <$varscan_input>) {
        chomp($line2);
        my ($chr, $pos, $ref, $var, $normal_ref, $normal_var, $normal_var_pct, $normal_IUB, $tumor_ref, $tumor_var, $tumor_var_pct, $tumor_IUB, $varscan_call, $germline_pvalue, $somatic_pvalue, @otherstuff) = split(/\t/, $line2);
        my $varscan_cn_tumor=&get_cn($chr,$pos,$pos,\%copynumber_hash_tumor);
        my $varscan_cn_normal=&get_cn($chr,$pos,$pos,\%copynumber_hash_normal);
        print $tfh "$line2\t$varscan_cn_tumor\t$varscan_cn_normal\n";
        if ($positions_highlight && -s $positions_highlight) {
            my $matcher = "$chr\t$pos";
            if (defined $position_highlight_hash{$matcher}) {
                $position_added--;
                my $depth = $tumor_ref + $tumor_var;
                my $varallelefreq = $tumor_var_pct;
                $varallelefreq =~ s/%//;
                print $tfh2 "$varscan_cn_tumor\t$varallelefreq\t$depth\n";
            }
        }
    }
    $tfh->close;
    $tfh2->close;

    if ($positions_highlight) {
        unless($position_added == 0) {
            warn "There are positions in positions_highlight file that aren't present in varscan file...check files for accuracy for missing positions";
        }
    }

    # Open Output
    unless (open(R_COMMANDS,">$r_script_output_file")) {
        die "Could not open output file '$r_script_output_file' for writing";
    }

#coverage
    #set defined cutoffs for graphs
    my $maxx = my $absmaxx = 0;
    if ($analysis_type eq 'wgs') {
        $maxx = 200;
        $absmaxx = 500;
    }
    elsif ($analysis_type eq 'capture') {
        $maxx = 1000;
        $absmaxx = 5000;
    }

    my $R_command = <<"_END_OF_R_";
#options(echo = FALSE);#suppress output to stdout
#sink("/dev/null");
genome=\"$sample_id\";
source(\"$r_library\"); #this contains R functions for loading and graphing VarScan files
library(fpc);
library(scatterplot3d);
varscan.load_snp_output(\"$temp_path\",header=F)->xcopy;
varscan.load_snp_output(\"$temp_path\",header=F,min_tumor_depth=$readcount_cutoff,min_normal_depth=$readcount_cutoff)->xcopy100;

additional_plot_points = 0;
_END_OF_R_
    print R_COMMANDS "$R_command\n";
    if ($positions_highlight && -s $positions_highlight && 1 && 1) { #these &&1 mean nothing, they just make my text editor color things correctly (it hates -s without being s///)
        $R_command = <<"_END_OF_R_";
additional_plot_points <- read.table(\"$temp_path2\", header = FALSE, sep = "\t");
additional_plot_points_cn1=subset(additional_plot_points, additional_plot_points\$V1 >= 0 & additional_plot_points\$V1 <= 1.75);
additional_plot_points_cn2=subset(additional_plot_points, additional_plot_points\$V1 >= 1.75 & additional_plot_points\$V1 <= 2.25);
additional_plot_points_cn3=subset(additional_plot_points, additional_plot_points\$V1 >= 2.25 & additional_plot_points\$V1 <= 3.5);
additional_plot_points_cn4=subset(additional_plot_points, additional_plot_points\$V1 >= 3.5);
_END_OF_R_
        print R_COMMANDS "$R_command\n";
    }
    $R_command = <<"_END_OF_R_";

z1=subset(xcopy, xcopy\$V13 == "Somatic");
z2=subset(xcopy100, xcopy100\$V13 == "Somatic");
xchr=subset(z1,z1\$V1 == "$chr_highlight");
xchr100=subset(z2,z2\$V1 == "$chr_highlight");
covtum1=(z1\$V9+z1\$V10);
covtum2=(z2\$V9+z2\$V10);
absmaxx=maxx=max(c(covtum1,covtum2));
covnorm1=(z1\$V5+z1\$V6);
covnorm2=(z2\$V5+z2\$V6);
absmaxx2=maxx2=max(c(covnorm1,covnorm2));

#if (maxx >= 1200) {maxx = 1200};
#if (maxx2 >= 1200) {maxx2 = 1200};
#if (maxx <= 800) {maxx = 800};
#if (maxx2 <= 800) {maxx2 = 800};
#if (absmaxx <= 5000) {absmaxx = 5000};
#if (absmaxx2 <= 5000) {absmaxx2 = 5000};

maxx = $maxx;
maxx2 = $maxx;
absmaxx = $absmaxx;
absmaxx2 = $absmaxx;

cn1minus=subset(z1, z1\$V20 >= 0 & z1\$V20 <= 1.75);
cn2=subset(z1, z1\$V20 >= 1.75 & z1\$V20 <= 2.25);
cn3=subset(z1, z1\$V20 >= 2.25 & z1\$V20 <= 3.5);
cn4plus=subset(z1, z1\$V20 >= 3.5);
cn1minus100x=subset(z2, z2\$V20 >= 0 & z2\$V20 <= 1.75);
cn2100x=subset(z2, z2\$V20 >= 1.75 & z2\$V20 <= 2.25);
cn3100x=subset(z2, z2\$V20 >= 2.25 & z2\$V20 <= 3.5);
cn4plus100x=subset(z2, z2\$V20 >= 3.5);

cn1xchr=subset(xchr, xchr\$V20 >= 0 & xchr\$V20 <= 1.75);
cn2xchr=subset(xchr, xchr\$V20 >= 1.75 & xchr\$V20 <= 2.25);
cn3xchr=subset(xchr, xchr\$V20 >= 2.25 & xchr\$V20 <= 3.5);
cn4xchr=subset(xchr, xchr\$V20 >= 3.5);
cn1xchr100=subset(xchr100, xchr100\$V20 >= 0 & xchr100\$V20 <= 1.75);
cn2xchr100=subset(xchr100, xchr100\$V20 >= 1.75 & xchr100\$V20 <= 2.25);
cn3xchr100=subset(xchr100, xchr100\$V20 >= 2.25 & xchr100\$V20 <= 3.5);
cn4xchr100=subset(xchr100, xchr100\$V20 >= 3.5);

cov20x=subset(z1, (z1\$V9+z1\$V10) <= 20);
cov50x=subset(z1, (z1\$V9+z1\$V10) >= 20 & (z1\$V9+z1\$V10) <= 50);
cov100x=subset(z1, (z1\$V9+z1\$V10) >= 50 & (z1\$V9+z1\$V10) <= 100);
cov100xplus=subset(z1, (z1\$V9+z1\$V10) >= 100);

den1 <- 0;
den2 <- 0;
den3 <- 0;
den4 <- 0;
den1100x <-  0;
den2100x <-  0;
den3100x <-  0;
den4100x <-  0;

den1factor = 0; den2factor = 0; den3factor = 0; den4factor = 0;
den1factor100 = 0; den2factor100 = 0; den3factor100 = 0; den4factor100 = 0;

N = dim(z1)[1];
N100 = dim(z2)[1];

if(dim(cn1minus)[1] < 2) {den1\$x = den1\$y=1000;} else {den1 <- density(cn1minus\$V11, from=0,to=100,na.rm=TRUE); den1factor = dim(cn1minus)[1]/N * den1\$y;};
if(dim(cn2)[1] < 2) {den2\$x = den2\$y=1000;} else {den2 <- density(cn2\$V11, from=0,to=100,na.rm=TRUE); den2factor = dim(cn2)[1]/N * den2\$y;};
if(dim(cn3)[1] < 2) {den3\$x = den3\$y=1000;} else {den3 <- density(cn3\$V11, from=0,to=100,na.rm=TRUE); den3factor = dim(cn3)[1]/N * den3\$y;};
if(dim(cn4plus)[1] < 2) {den4\$x = den4\$y=1000;} else {den4 <- density(cn4plus\$V11, from=0,to=100,na.rm=TRUE); den4factor = dim(cn4plus)[1]/N * den4\$y;};
if(dim(cn1minus100x)[1] < 2) {den1100x\$x = den1100x\$y=1000} else {den1100x <- density(cn1minus100x\$V11, from=0,to=100,na.rm=TRUE); den1factor100 = dim(cn1minus100x)[1]/N100 * den1100x\$y;};
if(dim(cn2100x)[1] < 2) {den2100x\$x = den2100x\$y=1000} else {den2100x <- density(cn2100x\$V11, from=0,to=100,na.rm=TRUE);den2factor100 = dim(cn2100x)[1]/N100 * den2100x\$y;};
if(dim(cn3100x)[1] < 2) {den3100x\$x = den3100x\$y=1000} else {den3100x <- density(cn3100x\$V11, from=0,to=100,na.rm=TRUE);den3factor100 = dim(cn3100x)[1]/N100 * den3100x\$y;};
if(dim(cn4plus100x)[1] < 2) {den4100x\$x = den4100x\$y=1000} else {den4100x <- density(cn4plus100x\$V11, from=0,to=100,na.rm=TRUE);den4factor100 = dim(cn4plus100x)[1]/N100 * den4100x\$y;};

dennormcov <- density((z1\$V5+z1\$V6), bw=4, from=0,to=maxx,na.rm=TRUE);
dentumcov <- density((z1\$V9+z1\$V10), bw=4, from=0,to=maxx,na.rm=TRUE);
dennormcov100x <- density((z2\$V5+z2\$V6), bw=4, from=0,to=maxx,na.rm=TRUE);
dentumcov100x <- density((z2\$V9+z2\$V10), bw=4, from=0,to=maxx,na.rm=TRUE);

#find inflection points (peaks)
#den2diff = diff(den2\$y);

peaks<-function(series,span=3)
{
z <- embed(series, span);
s <- span%/%2;
v<- max.col(z) == 1 + s;
result <- c(rep(FALSE,s),v);
result <- result[1:(length(result)-s)];
result;
} 

#labels to use for density plot values
if(dim(cn1minus)[1] < 2) {cn1peaks = cn1peakpos = cn1peakheight = 0;} else {cn1peaks = peaks(den1factor); cn1peaks = append(cn1peaks,c("FALSE","FALSE"),after=length(cn1peaks)); cn1peakpos = subset(den1\$x,cn1peaks==TRUE & den1\$y > 0.001); cn1peakheight = subset(den1factor,cn1peaks==TRUE & den1\$y > 0.001);}
if(dim(cn2)[1] < 2) {cn2peaks = cn2peakpos = cn2peakheight = 0;} else {cn2peaks = peaks(den2factor); cn2peaks = append(cn2peaks,c("FALSE","FALSE"),after=length(cn2peaks)); cn2peakpos = subset(den2\$x,cn2peaks==TRUE & den2\$y > 0.001); cn2peakheight = subset(den2factor,cn2peaks==TRUE & den2\$y > 0.001);}
if(dim(cn3)[1] < 2) {cn3peaks = cn3peakpos = cn3peakheight = 0;} else {cn3peaks = peaks(den3factor); cn3peaks = append(cn3peaks,c("FALSE","FALSE"),after=length(cn3peaks)); cn3peakpos = subset(den3\$x,cn3peaks==TRUE & den3\$y > 0.001); cn3peakheight = subset(den3factor,cn3peaks==TRUE & den3\$y > 0.001);}
if(dim(cn4plus)[1] < 2) {cn4peaks = cn4peakpos = cn4peakheight = 0;} else {cn4peaks = peaks(den4factor); cn4peaks = append(cn4peaks,c("FALSE","FALSE"),after=length(cn4peaks)); cn4peakpos = subset(den4\$x,cn4peaks==TRUE & den4\$y > 0.001); cn4peakheight = subset(den4factor,cn4peaks==TRUE & den4\$y > 0.001);}
if(dim(cn1minus100x)[1] < 2) {cn1peaks100 = cn1peakpos100 = cn1peakheight100 = 0;} else {cn1peaks100 = peaks(den1factor100); cn1peaks100 = append(cn1peaks100,c("FALSE","FALSE"),after=length(cn1peaks100)); cn1peakpos100 = subset(den1100x\$x,cn1peaks100==TRUE & den1100x\$y > 0.001); cn1peakheight100 = subset(den1factor100,cn1peaks100==TRUE & den1100x\$y > 0.001);}
if(dim(cn2100x)[1] < 2) {cn2peaks100 = cn2peakpos100 = cn2peakheight100 = 0;} else {cn2peaks100 = peaks(den2factor100); cn2peaks100 = append(cn2peaks100,c("FALSE","FALSE"),after=length(cn2peaks100)); cn2peakpos100 = subset(den2100x\$x,cn2peaks100==TRUE & den2100x\$y > 0.001); cn2peakheight100 = subset(den2factor100,cn2peaks100==TRUE & den2100x\$y > 0.001);}
if(dim(cn3100x)[1] < 2) {cn3peaks100 = cn3peakpos100 = cn3peakheight100 = 0;} else {cn3peaks100 = peaks(den3factor100); cn3peaks100 = append(cn3peaks100,c("FALSE","FALSE"),after=length(cn3peaks100)); cn3peakpos100 = subset(den3100x\$x,cn3peaks100==TRUE & den3100x\$y > 0.001); cn3peakheight100 = subset(den3factor100,cn3peaks100==TRUE & den3100x\$y > 0.001);}
if(dim(cn4plus100x)[1] < 2) {cn4peaks100 = cn4peakpos100 = cn4peakheight100 = 0;} else {cn4peaks100 = peaks(den4factor100); cn4peaks100 = append(cn4peaks100,c("FALSE","FALSE"),after=length(cn4peaks100)); cn4peakpos100 = subset(den4100x\$x,cn4peaks100==TRUE & den4100x\$y > 0.001); cn4peakheight100 = subset(den4factor100,cn4peaks100==TRUE & den4100x\$y > 0.001);}

maxden100 = max(c(den1factor100,den2factor100,den3factor100,den4factor100));
_END_OF_R_

    print R_COMMANDS "$R_command\n";


    #open up image for plotting
    if ($output_image =~ /.pdf/) {
        print R_COMMANDS "pdf(file=\"$output_image\",width=3.3,height=7.5,bg=\"white\");"."\n";
    }
    elsif ($output_image =~ /.png/) {
        print R_COMMANDS "png(file=\"$output_image\",width=400,height=800);"."\n";
    }
    else {
        die "unrecognized coverage output file type...please append .pdf or .png to the end of your coverage output file\n";
    }

    print R_COMMANDS "par(mfcol=c(5,1),mar=c(0.5,3,1,1.5),oma=c(3,0,4,0),mgp = c(3,1,0));"."\n";

    if ($analysis_type eq 'capture') {

        $R_command = <<"_END_OF_R_";

#final figure format
finalfactor = 25 / maxden100;

plot.default(x=c(1:10),y=c(1:10),ylim=c(0,28),xlim=c(0,100),axes=FALSE, ann=FALSE,col="#00000000",xaxs="i",yaxs="i");
rect(0, 0, 100, 28, col = "#00000011",border=NA); #plot bg color
#lines(c(10,100),c(25,25),lty=2,col="black");
axis(side=2,at=c(0,25),labels=c(0,sprintf("%.3f", maxden100)),las=1,cex.axis=0.6,hadj=0.6,lwd=0.5,lwd.ticks=0.5,tck=-0.01);
lines(den2100x\$x,(finalfactor * den2factor100),col="#67B32EAA",lwd=2);
lines(den1100x\$x,(finalfactor * den1factor100),col="#1C3660AA",lwd=2);
lines(den3100x\$x,(finalfactor * den3factor100),col="#F49819AA",lwd=2);
lines(den4100x\$x,(finalfactor * den4factor100),col="#E52420AA",lwd=2);
text(x=cn1peakpos100,y=(finalfactor * cn1peakheight100)+1.7,labels=signif(cn1peakpos100,3),cex=0.7,srt=0,col="#1C3660AA");
text(x=cn3peakpos100,y=(finalfactor * cn3peakheight100)+1.7,labels=signif(cn3peakpos100,3),cex=0.7,srt=0,col="#F49819AA");
text(x=cn4peakpos100,y=(finalfactor * cn4peakheight100)+1.7,labels=signif(cn4peakpos100,3),cex=0.7,srt=0,col="#E52420AA");
text(x=cn2peakpos100,y=(finalfactor * cn2peakheight100)+1.7,labels=signif(cn2peakpos100,3),cex=0.7,srt=0,col="#67B32EAA");

axis(side=3,at=c(0,20,40,60,80,100),labels=c(0,20,40,60,80,100),cex.axis=0.6,lwd=0.5,lwd.ticks=0.5,padj=1.4);
mtext("Tumor Variant Allele Frequency",adj=0.5,padj=-3.1,cex=0.5,side=3);
mtext(genome,adj=0,padj=-3.2,cex=0.65,side=3);


#rect(par("usr")[1], par("usr")[3], par("usr")[2], par("usr")[4], col = "#00000055"); #plot bg color
#mtext("Normal and Tumor Coverage > 100",cex=0.7, padj=-0.5);
#legend(x="topright",horiz=TRUE,xjust=0, c("1", "2", "3", "4+","Chr $chr_highlight"),col=c("#1C3660","#67B32E","#F49819","#E52420","#A020F0"),pch=c(19,19,19,19,2),cex=0.6);


#cn1plot
plot.default(x=(z1\$V11),y=(z1\$V9+z1\$V10),log="y", type="p",pch=19,cex=0.4,col="#00000000",xlim=c(-1,101),ylim=c(95,absmaxx+5),axes=FALSE, ann=FALSE,xaxs="i",yaxs="i");
points(y=(cn1minus100x\$V9+cn1minus100x\$V10),x=(cn1minus100x\$V11),type="p",pch=19,cex=0.4,col="#1C366044");
points(y=(cn1xchr100\$V9+cn1xchr100\$V10),x=(cn1xchr100\$V11),type="p",pch=2,cex=0.8,col="#1C366044");
#add in highlight of points selected for by script input
if(length(additional_plot_points) > 1) {
        points(x=additional_plot_points_cn1\$V2,y=additional_plot_points_cn1\$V3,type="p",pch=7,cex=0.8,col="#555555FF");
}
axis(side=2,las=1,tck=0,lwd=0,cex.axis=0.6,hadj=0.5);
for (i in 2:length(axTicks(2)-1)) {
        lines(c(-1,101),c(axTicks(2)[i],axTicks(2)[i]),col="#00000022");
}
rect(-1, 95, 101, axTicks(2)[length(axTicks(2))]*1.05, col = "#00000011",border=NA); #plot bg color
#add cn circle
points(x=c(97),y=c((absmaxx+5)*0.70),type="p",pch=19,cex=3,col="#1C3660FF");
text(c(97),y=c((absmaxx+5)*0.70), labels=c(1), cex=1, col="#FFFFFFFF") 

#cn2plot
plot.default(x=(z1\$V11),y=(z1\$V9+z1\$V10),log="y", type="p",pch=19,cex=0.4,col="#00000000",xlim=c(-1,101),ylim=c(95,absmaxx+5),axes=FALSE, ann=FALSE,xaxs="i",yaxs="i");
points(y=(cn2100x\$V9+cn2100x\$V10),x=(cn2100x\$V11),type="p",pch=19,cex=0.4,col="#67B32E44");
points(y=(cn2xchr100\$V9+cn2xchr100\$V10),x=(cn2xchr100\$V11),type="p",pch=2,cex=0.8,col="#67B32E44");
#add in highlight of points selected for by script input
if(length(additional_plot_points) > 1) {
        points(x=additional_plot_points_cn2\$V2,y=additional_plot_points_cn2\$V3,type="p",pch=7,cex=0.8,col="#555555FF");
}
axis(side=2,las=1,tck=0,lwd=0,cex.axis=0.6,hadj=0.5);
for (i in 2:length(axTicks(2)-1)) {
        lines(c(-1,101),c(axTicks(2)[i],axTicks(2)[i]),col="#00000022");
}
rect(-1, 95, 101, axTicks(2)[length(axTicks(2))]*1.05, col = "#00000011",border=NA); #plot bg color
#add cn circle
points(x=c(97),y=c((absmaxx+5)*0.70),type="p",pch=19,cex=3,col="#67B32EFF");
text(c(97),y=c((absmaxx+5)*0.70), labels=c(2), cex=1, col="#FFFFFFFF") 

#cn3plot
plot.default(x=(z1\$V11),y=(z1\$V9+z1\$V10),log="y", type="p",pch=19,cex=0.4,col="#00000000",xlim=c(-1,101),ylim=c(95,absmaxx+5),axes=FALSE, ann=FALSE,xaxs="i",yaxs="i");
points(y=(cn3100x\$V9+cn3100x\$V10),x=(cn3100x\$V11),type="p",pch=19,cex=0.4,col="#F4981999");
points(y=(cn3xchr100\$V9+cn3xchr100\$V10),x=(cn3xchr100\$V11),type="p",pch=2,cex=0.8,col="#F4981955");
#add in highlight of points selected for by script input
if(length(additional_plot_points) > 1) {
        points(x=additional_plot_points_cn3\$V2,y=additional_plot_points_cn3\$V3,type="p",pch=7,cex=0.8,col="#555555FF");
}
axis(side=2,las=1,tck=0,lwd=0,cex.axis=0.6,hadj=0.5);
for (i in 2:length(axTicks(2)-1)) {
        lines(c(-1,101),c(axTicks(2)[i],axTicks(2)[i]),col="#00000022");
}
rect(-1, 95, 101, axTicks(2)[length(axTicks(2))]*1.05, col = "#00000011",border=NA); #plot bg color
#add cn circle
points(x=c(97),y=c((absmaxx+5)*0.70),type="p",pch=19,cex=3,col="#F49819FF");
text(c(97),y=c((absmaxx+5)*0.70), labels=c(3), cex=1, col="#FFFFFFFF") 

#cn4plot
plot.default(x=(z1\$V11),y=(z1\$V9+z1\$V10),log="y", type="p",pch=19,cex=0.4,col="#00000000",xlim=c(-1,101),ylim=c(95,absmaxx+5),axes=FALSE, ann=FALSE,xaxs="i",yaxs="i");
points(y=(cn4plus100x\$V9+cn4plus100x\$V10),x=(cn4plus100x\$V11),type="p",pch=19,cex=0.4,col="#E5242044");
points(y=(cn4xchr100\$V9+cn4xchr100\$V10),x=(cn4xchr100\$V11),type="p",pch=2,cex=0.8,col="#E5242044");
#add in highlight of points selected for by script input
if(length(additional_plot_points) > 1) {
        points(x=additional_plot_points_cn4\$V2,y=additional_plot_points_cn4\$V3,type="p",pch=7,cex=0.8,col="#555555FF");
}
axis(side=2,las=1,tck=0,lwd=0,cex.axis=0.6,hadj=0.5);
for (i in 2:length(axTicks(2)-1)) {
        lines(c(-1,101),c(axTicks(2)[i],axTicks(2)[i]),col="#00000022");
}
rect(-1, 95, 101, axTicks(2)[length(axTicks(2))]*1.05, col = "#00000011",border=NA); #plot bg color
#add cn circle
points(x=c(97),y=c((absmaxx+5)*0.70),type="p",pch=19,cex=3,col="#E52420FF");
text(c(97),y=c((absmaxx+5)*0.70), labels=c(4), cex=1, col="#FFFFFFFF") 

axis(side=1,at=c(0,20,40,60,80,100),labels=c(0,20,40,60,80,100),cex.axis=0.6,lwd=0.5,lwd.ticks=0.5,padj=-1.2);
mtext("Tumor Variant Allele Frequency",adj=0.5,padj=3.2,cex=0.5,side=1);

_END_OF_R_

print R_COMMANDS "$R_command\n";
    }
    elsif ($analysis_type eq 'wgs') {


        $R_command = <<"_END_OF_R_";

#all coverage points plotted
    finalfactor = 25 / maxden;

    plot.default(x=c(1:10),y=c(1:10),ylim=c(0,28),xlim=c(0,100),axes=FALSE, ann=FALSE,col="#00000000",xaxs="i",yaxs="i");
    rect(0, 0, 100, 28, col = "#00000011",border=NA); #plot bg color
#lines(c(10,100),c(25,25),lty=2,col="black");
    axis(side=2,at=c(0,25),labels=c(0,sprintf("%.3f", maxden)),las=1,cex.axis=0.6,hadj=0.6,lwd=0.5,lwd.ticks=0.5,tck=-0.01);
    lines(den2\$x,(finalfactor * den2factor),col="#67B32EAA",lwd=2);
    lines(den1\$x,(finalfactor * den1factor),col="#1C3660AA",lwd=2);
    lines(den3\$x,(finalfactor * den3factor),col="#F49819AA",lwd=2);
    lines(den4\$x,(finalfactor * den4factor),col="#E52420AA",lwd=2);
    text(x=cn1peakpos,y=(finalfactor * cn1peakheight)+1.7,labels=signif(cn1peakpos,3),cex=0.7,srt=0,col="#1C3660AA");
    text(x=cn3peakpos,y=(finalfactor * cn3peakheight)+1.7,labels=signif(cn3peakpos,3),cex=0.7,srt=0,col="#F49819AA");
    text(x=cn4peakpos,y=(finalfactor * cn4peakheight)+1.7,labels=signif(cn4peakpos,3),cex=0.7,srt=0,col="#E52420AA");
    text(x=cn2peakpos,y=(finalfactor * cn2peakheight)+1.7,labels=signif(cn2peakpos,3),cex=0.7,srt=0,col="#67B32EAA");

    axis(side=3,at=c(0,20,40,60,80,100),labels=c(0,20,40,60,80,100),cex.axis=0.6,lwd=0.5,lwd.ticks=0.5,padj=1.4);
    mtext("Tumor Variant Allele Frequency",adj=0.5,padj=-3.1,cex=0.5,side=3);
    mtext(genome,adj=0,padj=-3.2,cex=0.65,side=3);


#rect(par("usr")[1], par("usr")[3], par("usr")[2], par("usr")[4], col = "#00000055"); #plot bg color
#mtext("Normal and Tumor Coverage > 100",cex=0.7, padj=-0.5);
#legend(x="topright",horiz=TRUE,xjust=0, c("1", "2", "3", "4+","Chr $chr_highlight"),col=c("#1C3660","#67B32E","#F49819","#E52420","#A020F0"),pch=c(19,19,19,19,2),cex=0.6);


#cn1plot
    plot.default(x=(z1\$V11),y=(z1\$V9+z1\$V10),log="y", type="p",pch=19,cex=0.4,col="#00000000",xlim=c(-1,101),ylim=c(5,absmaxx+5),axes=FALSE, ann=FALSE,xaxs="i",yaxs="i");
    points(y=(cn1minus\$V9+cn1minus\$V10),x=(cn1minus\$V11),type="p",pch=19,cex=0.4,col="#1C366044");
    points(y=(cn1xchr\$V9+cn1xchr\$V10),x=(cn1xchr\$V11),type="p",pch=2,cex=0.8,col="#1C366044");
#add in highlight of points selected for by script input
    if(length(additional_plot_points) > 1) {
        points(x=additional_plot_points_cn1\$V2,y=additional_plot_points_cn1\$V3,type="p",pch=7,cex=0.8,col="#555555FF");
    }
    axis(side=2,las=1,tck=0,lwd=0,cex.axis=0.6,hadj=0.5);
    for (i in 2:length(axTicks(2)-1)) {
        lines(c(-1,101),c(axTicks(2)[i],axTicks(2)[i]),col="#00000022");
    }
    rect(-1, 5, 101, axTicks(2)[length(axTicks(2))]*1.05, col = "#00000011",border=NA); #plot bg color
#add cn circle
    points(x=c(97),y=c((absmaxx+5)*0.70),type="p",pch=19,cex=3,col="#1C3660FF");
    text(c(97),y=c((absmaxx+5)*0.70), labels=c(1), cex=1, col="#FFFFFFFF") 

#cn2plot
    plot.default(x=(z1\$V11),y=(z1\$V9+z1\$V10),log="y", type="p",pch=19,cex=0.4,col="#00000000",xlim=c(-1,101),ylim=c(5,absmaxx+5),axes=FALSE, ann=FALSE,xaxs="i",yaxs="i");
    points(y=(cn2\$V9+cn2\$V10),x=(cn2\$V11),type="p",pch=19,cex=0.4,col="#67B32E44");
    points(y=(cn2xchr\$V9+cn2xchr\$V10),x=(cn2xchr\$V11),type="p",pch=2,cex=0.8,col="#67B32E44");
#add in highlight of points selected for by script input
    if(length(additional_plot_points) > 1) {
        points(x=additional_plot_points_cn2\$V2,y=additional_plot_points_cn2\$V3,type="p",pch=7,cex=0.8,col="#555555FF");
    }
    axis(side=2,las=1,tck=0,lwd=0,cex.axis=0.6,hadj=0.5);
    for (i in 2:length(axTicks(2)-1)) {
        lines(c(-1,101),c(axTicks(2)[i],axTicks(2)[i]),col="#00000022");
    }
    rect(-1, 5, 101, axTicks(2)[length(axTicks(2))]*1.05, col = "#00000011",border=NA); #plot bg color
#add cn circle
    points(x=c(97),y=c((absmaxx+5)*0.70),type="p",pch=19,cex=3,col="#67B32EFF");
    text(c(97),y=c((absmaxx+5)*0.70), labels=c(2), cex=1, col="#FFFFFFFF") 

#cn3plot
    plot.default(x=(z1\$V11),y=(z1\$V9+z1\$V10),log="y", type="p",pch=19,cex=0.4,col="#00000000",xlim=c(-1,101),ylim=c(5,absmaxx+5),axes=FALSE, ann=FALSE,xaxs="i",yaxs="i");
    points(y=(cn3\$V9+cn3\$V10),x=(cn3\$V11),type="p",pch=19,cex=0.4,col="#F4981999");
    points(y=(cn3xchr\$V9+cn3xchr\$V10),x=(cn3xchr\$V11),type="p",pch=2,cex=0.8,col="#F4981955");
#add in highlight of points selected for by script input
    if(length(additional_plot_points) > 1) {
        points(x=additional_plot_points_cn3\$V2,y=additional_plot_points_cn3\$V3,type="p",pch=7,cex=0.8,col="#555555FF");
    }
    axis(side=2,las=1,tck=0,lwd=0,cex.axis=0.6,hadj=0.5);
    for (i in 2:length(axTicks(2)-1)) {
        lines(c(-1,101),c(axTicks(2)[i],axTicks(2)[i]),col="#00000022");
    }
    rect(-1, 5, 101, axTicks(2)[length(axTicks(2))]*1.05, col = "#00000011",border=NA); #plot bg color
#add cn circle
    points(x=c(97),y=c((absmaxx+5)*0.70),type="p",pch=19,cex=3,col="#F49819FF");
    text(c(97),y=c((absmaxx+5)*0.70), labels=c(3), cex=1, col="#FFFFFFFF") 

#cn4plot
    plot.default(x=(z1\$V11),y=(z1\$V9+z1\$V10),log="y", type="p",pch=19,cex=0.4,col="#00000000",xlim=c(-1,101),ylim=c(5,absmaxx+5),axes=FALSE, ann=FALSE,xaxs="i",yaxs="i");
    points(y=(cn4plus\$V9+cn4plus\$V10),x=(cn4plus\$V11),type="p",pch=19,cex=0.4,col="#E5242044");
    points(y=(cn4xchr\$V9+cn4xchr\$V10),x=(cn4xchr\$V11),type="p",pch=2,cex=0.8,col="#E5242044");
#add in highlight of points selected for by script input
    if(length(additional_plot_points) > 1) {
        points(x=additional_plot_points_cn4\$V2,y=additional_plot_points_cn4\$V3,type="p",pch=7,cex=0.8,col="#555555FF");
    }
    axis(side=2,las=1,tck=0,lwd=0,cex.axis=0.6,hadj=0.5);
    for (i in 2:length(axTicks(2)-1)) {
        lines(c(-1,101),c(axTicks(2)[i],axTicks(2)[i]),col="#00000022");
    }
    rect(-1, 5, 101, axTicks(2)[length(axTicks(2))]*1.05, col = "#00000011",border=NA); #plot bg color
#add cn circle
    points(x=c(97),y=c((absmaxx+5)*0.70),type="p",pch=19,cex=3,col="#E52420FF");
    text(c(97),y=c((absmaxx+5)*0.70), labels=c(4), cex=1, col="#FFFFFFFF") 

    axis(side=1,at=c(0,20,40,60,80,100),labels=c(0,20,40,60,80,100),cex.axis=0.6,lwd=0.5,lwd.ticks=0.5,padj=-1.2);
    mtext("Tumor Variant Allele Frequency",adj=0.5,padj=3.2,cex=0.5,side=1);

_END_OF_R_

        print R_COMMANDS "$R_command\n";
    }

    $R_command = <<"_END_OF_R_";
devoff <- dev.off();
q();
_END_OF_R_
        print R_COMMANDS "$R_command\n";

        close R_COMMANDS;

        my $cmd = "R --vanilla --slave \< $r_script_output_file";
        my $return = Genome::Sys->shellcmd(
            cmd => "$cmd",
            output_files => [$output_image],
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




