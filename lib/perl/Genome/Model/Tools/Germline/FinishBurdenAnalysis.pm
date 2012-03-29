package Genome::Model::Tools::Germline::FinishBurdenAnalysis;

use warnings;
use strict;
use Carp;
use Genome;
use IO::File;
use POSIX qw( WIFEXITED );

class Genome::Model::Tools::Germline::FinishBurdenAnalysis {
  is => 'Genome::Model::Tools::Music::Base',
  has_input => [
    input_directory => { is => 'Text', doc => "Directory of Results of the Burden Analysis" },
    output_file => { is => 'Text', doc => "File with the Results of the Burden Analysis" },
    project_name => { is => 'Text', doc => "The name of the project", default => "Burden Analysis Results"},
    base_R_commands => { is => 'Text', doc => "The base R command library", default => '/gscuser/qzhang/gstat/burdentest/burdentest.R' },
  ],
};

sub sub_command_sort_position { 12 }

sub help_brief {                            # keep this to just a few words <---
    "Combine results from a burden analysis on germline (PhenotypeCorrelation) data"                 
}

sub help_synopsis {
    return <<EOS
Run a burden analysis on germline (PhenotypeCorrelation) data
EXAMPLE:	gmt germline finish-burden-analysis --help
EOS
}

sub help_detail {                           # this is what the user will see with the longer version of help. <---
  return (
<<"EOS"
Run a burden analysis on germline (PhenotypeCorrelation) data
EXAMPLE:	gmt germline finish-burden-analysis --help
EOS
    );
}


###############

sub execute {                               # replace with real execution logic.
	my $self = shift;

    my $input_directory = $self->input_directory;
    my $base_R_commands = $self->base_R_commands;
    my $project_name = $self->project_name;

    my $output_file = $self->output_file;
    my $fh_outfile = new IO::File $output_file,"w";
    unless ($fh_outfile) {
        die "Failed to create output file $output_file!: $!";
    }

    opendir DIR, $input_directory or die "cannot open dir $input_directory: $!";
    my @files = grep { $_ ne '.' && $_ ne '..'} readdir DIR;
    closedir DIR;

    my @results_files;
    my @null_files;
    my @rarevariant_files;
    foreach my $file (@files) {
        if ($file =~ m/burden/) {
            push(@results_files,$file);
        }
        elsif ($file =~ m/null/) {
            push(@null_files,$file);
        }
        elsif ($file =~ m/single/) {
            push(@rarevariant_files,$file);
        }
        elsif ($file =~ m/err/) {
            die "Error file found $file, please resolve and/or re-run burden analysis for this variant-phenotype combination\n";
        }
    }


    foreach my $file (@null_files) {
        $file =~ s/.null$//;
        my ($pheno, $gene)  = split(/_/, $file);
        print "Null: $pheno\t$gene\n";
    }

    my %gene_variant_hash;
    foreach my $file (@rarevariant_files) {
        my $infh = new IO::File "$input_directory/$file","r";
        $file =~ s/.single.csv$//;
        my ($pheno, $gene)  = split(/_/, $file);
        my $header = $infh->getline;
        chomp($header);
        while (my $line = $infh->getline) {
            chomp($line);
            #Variant,Beta,SE,t,P
            my ($variant_name, $beta, $SE, $t, $P) = split(/,/, $line);
            my ($chr, $pos, $ref, $var) = split(/_/, $variant_name);
            unless ($chr =~ m/X/i || $chr =~ m/Y/i) {
                $chr =~ s/^\D+//;
            }
            else {
                $chr =~ s/^\D+X//;
                $chr =~ s/^\D+Y//;
            }
            my $chrpos = "$chr:$pos";
            $gene_variant_hash{$gene}{$chrpos}++;
        }
    }

    my $first = 1;
    foreach my $file (@results_files) {
        my $infh = new IO::File "$input_directory/$file","r";
        $file =~ s/.burden.csv$//;
        my ($pheno, $gene)  = split(/_/, $file);
        my $header = $infh->getline;
        chomp($header);
        if ($first) {
            print $fh_outfile "$header,Average_Position\n";
            $first = 0;
        }
        while (my $line = $infh->getline) {
            chomp($line);
            #heightRES,PSRC1,4384,5,0.01,0.958703922888546,0.9575,0.8092,0.9572,0.5614,0.6765,0.4057,0.4339
            my ($Trait,$Gene,$N,$V,$MAF,$CMC,$pCMC,$WSS,$aSum,$PWST,$SPWST,$SPWST_up,$SPWST_down) = split(/,/, $line);
            my @chrpositions = (sort keys %{$gene_variant_hash{$Gene}});
            my $average_position = 0;
            my $chr;
            foreach my $chrpos (@chrpositions) {
                ($chr, my $pos) = split(/:/, $chrpos);
                $average_position += $pos;
            }
            $average_position /= scalar(@chrpositions);
            print $fh_outfile "$line,$average_position\n";
        }
    }

    my $final_file = $output_file."_FDR";
    my $plot_file = $output_file.".pdf";

    my $R_burden_finisher_file = "$input_directory/Burden_Finisher.R";
    my $fh_R_finisher = new IO::File $R_burden_finisher_file,"w";
    unless ($fh_R_finisher) {
        die "Failed to create R options file $R_burden_finisher_file!: $!";
    }
    #-------------------------------------------------
    my $R_command_finisher = <<"_END_OF_R_";
### This is option file for finishing the analysis of burdentest.R ###

missing.data=c("NA",".","");

x<-read.table("$output_file", sep = ",", header = TRUE);

x\$CMC_log10=-log10(x\$CMC);
x\$pCMC_log10=-log10(x\$pCMC);
x\$WSS_log10=-log10(x\$WSS);
x\$aSum_log10=-log10(x\$aSum);
x\$PWST_log10=-log10(x\$PWST);
x\$SPWST_log10=-log10(x\$SPWST);
x\$SPWST.up_log10=-log10(x\$SPWST.up);
x\$SPWST.down_log10=-log10(x\$SPWST.down);
rownames(x) <- paste(x\$Trait,x\$Gene);

#Select -log10 > 1.5 for text labels below
x2 <- subset(x,x\$CMC_log10 > 1.5 | x\$pCMC_log10 > 1.5 | x\$WSS_log10 > 1.5 | x\$aSum_log10 > 1.5 | x\$PWST_log10 > 1.5 | x\$SPWST_log10 > 1.5 | x\$SPWST.up_log10 > 1.5 | x\$SPWST.down_log10 > 1.5, select=c(CMC_log10,pCMC_log10,WSS_log10,aSum_log10,PWST_log10,SPWST_log10,SPWST.up_log10,SPWST.down_log10));
x3 <- subset(x,x\$CMC_log10 > 1.5 | x\$pCMC_log10 > 1.5 | x\$WSS_log10 > 1.5 | x\$aSum_log10 > 1.5 | x\$PWST_log10 > 1.5 | x\$SPWST_log10 > 1.5 | x\$SPWST.up_log10 > 1.5 | x\$SPWST.down_log10 > 1.5, select=c(Average_Position));

#BEGIN PLOTTING IMAGE
pdf(file=\"$plot_file\",width=10,height=7.5,bg=\"white\");
avg_pos <- x\$Average_Position;
colors <- rainbow(8);
ymax <- max(x\$CMC_log10,x\$pCMC_log10,x\$WSS_log10,x\$aSum_log10,x\$PWST_log10,x\$SPWST_log10,x\$SPWST.up_log10,x\$SPWST.down_log10,na.rm = TRUE);

#BEGIN PLOTTING -LOG10 P-VALUES
plot(avg_pos,x\$CMC_log10,type="p",pch=16,cex=0.8,col=colors[1],main=\"Burden Test Results by Average Gene-Snp Position\",xlab=\"Average Chromosomal Position For the Rare SNVs in the Gene\",ylab=\"-log10\(p-value\)\",ylim=c(0,ymax*1.25), xaxt="n");
points(avg_pos,x\$pCMC_log10,type="p",pch=16,cex=0.8,col=colors[2]);
points(avg_pos,x\$WSS_log10,type="p",pch=16,cex=0.8,col=colors[3]);
points(avg_pos,x\$aSum_log10,type="p",pch=16,cex=0.8,col=colors[4]);
points(avg_pos,x\$PWST_log10,type="p",pch=16,cex=0.8,col=colors[5]);
points(avg_pos,x\$SPWST_log10,type="p",pch=16,cex=0.8,col=colors[6]);
points(avg_pos,x\$SPWST.up_log10,type="p",pch=16,cex=0.8,col=colors[7]);
points(avg_pos,x\$SPWST.down_log10,type="p",pch=16,cex=0.8,col=colors[8]);
for(i in 1:length(x2)) {
text(cbind(x3,x2[i]),lab=paste(rownames(x2[i])), cex=0.3, pos=4);
}
axis(1, at=unique(x\$Average_Position), lab=paste(unique(round(x\$Average_Position)),\"\\n\",unique(x\$Gene)), cex.axis=0.5, las=2)

plot_types <- c("CMC","pCMC","WSS","aSum","PWST","SPWST","SPWST.up","SPWST.down");
legend(x=\"topright\", title = \"Burden Tests\", legend=plot_types,col=colors,pch=16,ncol=2);


x_log10 <- subset(x, select=c(CMC_log10,pCMC_log10,WSS_log10,aSum_log10,PWST_log10,SPWST_log10,SPWST.up_log10,SPWST.down_log10));

#Q-Q Plots
for(i in 1:length(plot_types)) {
    index <- seq(1, nrow(x_log10[i]));
    uni <- index/nrow(x_log10[i]);
    loguni <- -log10(uni);
    x_plot <- t(sort(loguni));
    x_plot_label = paste(colnames(x_log10[i]),"_uniform");

    y_plot <- sort(t(x_log10[i]));
    y_plot_label <- colnames(x_log10[i]);

    maxplot <- max(x_plot, y_plot, na.rm = TRUE);
    qqplot(x=x_plot,y=y_plot, xlab=x_plot_label,ylab=y_plot_label, xlim=c(0,maxplot),ylim=c(0,maxplot));
    abline(a=0,b=1);
}

for(i in 1:(length(plot_types) - 1)) {
    x_plot = x_log10[i];
    x_plot_label = colnames(x_log10[i]);
    for(j in (i+1):(length(plot_types))) {
        y_plot = x_log10[j];
        y_plot_label = colnames(x_log10[j]);
        maxplot <- max(x_plot, y_plot, na.rm = TRUE);
        qqplot(x=t(x_plot),y=t(y_plot), xlab=x_plot_label,ylab=y_plot_label, xlim=c(0,maxplot), ylim=c(0,maxplot));
        abline(a=0,b=1);
    }
}

dev.off();

x\$CMC_FDR=p.adjust(x\$CMC,method="fdr");
x\$pCMC_FDR=p.adjust(x\$pCMC,method="fdr");
x\$WSS_FDR=p.adjust(x\$WSS,method="fdr");
x\$aSum_FDR=p.adjust(x\$aSum,method="fdr");
x\$PWST_FDR=p.adjust(x\$PWST,method="fdr");
x\$SPWST_FDR=p.adjust(x\$SPWST,method="fdr");
x\$SPWST.up_FDR=p.adjust(x\$SPWST.up,method="fdr");
x\$SPWST.down_FDR=p.adjust(x\$SPWST.down,method="fdr");

write.table(x, "$final_file",quote=FALSE,row.names=FALSE,sep="\t");



out.dir="$input_directory";
if (!file.exists(out.dir)==T) dir.create(out.dir);

q();

_END_OF_R_
    #-------------------------------------------------

    print $fh_R_finisher "$R_command_finisher\n";

    my $cmd = "R --vanilla --slave \< $R_burden_finisher_file";
    my $return = Genome::Sys->shellcmd(
        cmd => "$cmd",
    );
    unless($return) { 
        $self->error_message("Failed to execute: Returned $return");
        die $self->error_message;
    }


    return 1;
}


