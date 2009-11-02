package Genome::Model::Tools::MapToCna;

## This script analyzes a pair of tumor and normal map files
##  in a configuration file (similar to BreakDancer)
## and outputs chromosomal based copy number alteration

use strict;
use warnings;
use Genome;
use Statistics::Descriptive;
use Statistics::R;
require Genome::Utility::FileSystem;

class Genome::Model::Tools::MapToCna {
    is => 'Command',
    has => [
    tumor_bam_file => {
        type => 'String',
        is_optional => 0,
        doc => 'Location of tumor bam file.'
    },
    normal_bam_file => {
        type => 'String',
        is_optional => 0,
        doc => 'Location of normal bam file.'
    },
    output_file => {
        type => 'String',
        is_optional => 0,
        doc => 'Copy number analysis output file (full path).'
    },
    window_size => {
        type => 'Number',
        is_optional => 1,
        default => 10000,
        doc => 'Window size (bp) for counting reads contributing to copy number in that window (resolution, default = 10000 bp).'
    },
    maq_quality_cutoff => {
        type => 'Number',
        is_optional => 1,
        default => 35,
        doc => 'MAQ mapping quality cutoff for contributing reads (default = 35).'
    },
    ratio => {
        type => 'Number',
        is_optional => 1,
        default => 0.25,
        doc => 'Ratio diverged from median, used to find copy number neutral region (default = 0.25).'
    },
    chromosome_list => {
        type => 'String',
        is_optional => 1,
        default => '',
        doc => 'List of chromosomes (comma separated) to use for calculation of median coverage (default = all).'
    },
    tumor_downsample_percentage => {
        type => 'Number',
        is_optional => 1,
        default => 1,
        doc => 'Percent of reads (value x 100%) to use in calculations (max & default = 1).'
    },
    normal_downsample_percentage => {
        type => 'Number',
        is_optional => 1,
        default => 1,
        doc => 'Percent of reads (value x 100%) to use in calculations (max,default = 1).'
    }
    ]
};

sub help_brief {
    "This tool analyzes a tumor and normal bam file and outputs chromosomal-based copy number alteration."
}

sub help_detail {
    return<<EOS
    This tool analyzes a tumor and normal bam file and outputs chromosomal-based copy number alteration in the form of an output file which displays \"chromosome, position, tumor cn, normal cn, difference\". Also, the tool plots a grid of copy number graphs, one for each chromosome, on a single .png image the size of one full page using an embedded R script.
EOS
}

sub execute {
    my $self = shift;

    my $version="Map2CNA-0.0.2r1";
    my @maps = ($self->tumor_bam_file,$self->normal_bam_file);
    my @samples = ("tumor","normal");
    my @downratios = ($self->tumor_downsample_percentage,$self->normal_downsample_percentage);
    my $outfile = $self->output_file;
    
    #test architecture to make sure bam-window program can run (req. 64-bit)
    unless (`uname -a` =~ /x86_64/) {
        $self->error_message("Must run on a 64 bit machine");
        die;
    }
                                      
    ####################### Compute read counts in sliding windows ########################
    my %data;
    my @statistics;

    for(my $if=0;$if<=1;$if++){
        my $cmd = sprintf("/gscuser/dlarson/src/c-code/src/bamsey/window/trunk/bam-window -w %d -q %d -s -p -d %f %s |", $self->window_size, $self->maq_quality_cutoff, $downratios[$if], $maps[$if]);
        open(MAP,$cmd) || die "unable to open $maps[$if]\n";
        $statistics[$if] = Statistics::Descriptive::Sparse->new();

        my ($pchr,$idx)=(0,0);
        while(<MAP>){
            chomp;
            my ($chr,$pos,$nread) = split /\t/;
            $idx = 0 if($chr ne $pchr);
            ${$data{$if}{$chr}}[$idx++]=$nread;
            $pchr = $chr;
            $statistics[$if]->add_data($nread);
        }
        close(MAP);
    }

    my @chrs;
    unless($self->chromosome_list) {
        @chrs=(1..22,'X');
    }
    else {
        @chrs = split /,/, $self->chromosome_list;
    }

    #Estimate genome-wide tumor/normal 2X read count
    my @medians;
    for(my $if=0;$if<=1;$if++){
        my $median=Statistics::Descriptive::Full->new();
        foreach my $chr(@chrs){
            next unless (defined $data{$if}{$chr});
            my $md = $self->get_median($data{$if}{$chr});
            $median->add_data($md);
        }
        push @medians,$median->median();
    }

    @chrs = (1..22,'X');
    my %num_CN_neutral_pos;
    my %NReads_CN_neutral;
    foreach my $chr(@chrs){
        next unless (defined $data{0}{$chr} && $data{1}{$chr});
        my $Nwi=($#{$data{0}{$chr}}<$#{$data{0}{$chr}})?$#{$data{0}{$chr}}:$#{$data{0}{$chr}};

        for(my $i=0;$i<=$Nwi;$i++){
            my $f2x=1;
            next unless (defined ${$data{0}{$chr}}[$i] && defined ${$data{1}{$chr}}[$i]);
            for(my $if=0;$if<=1;$if++){
                $f2x=0 if(${$data{$if}{$chr}}[$i]<$medians[$if]*(1-$self->ratio) || ${$data{$if}{$chr}}[$i]>$medians[$if]*(1+$self->ratio));
            }
            next if(! $f2x);
            $num_CN_neutral_pos{$chr}++;
            $num_CN_neutral_pos{'allchr'}++;
            for(my $if=0;$if<=1;$if++){
                $NReads_CN_neutral{$chr}{$if}+=${$data{$if}{$chr}}[$i];
                $NReads_CN_neutral{'allchr'}{$if}+=${$data{$if}{$chr}}[$i];
            }
        }
    }

    #subtract the normal from the tumor
    open(OUT, ">$outfile") || die "Unable to open output file $outfile: $!";
    my %depth2x;
    foreach my $chr(@chrs,'allchr'){
        printf OUT "#Chr%s median read count",$chr;
        for(my $if=0;$if<=$#maps;$if++){
            if($num_CN_neutral_pos{$chr}>10){
                $depth2x{$chr}{$if}=$NReads_CN_neutral{$chr}{$if}/$num_CN_neutral_pos{$chr};
            }
            else{  # Sample < 10, backoff to genome-wide estimation
                $depth2x{$chr}{$if}=$NReads_CN_neutral{'allchr'}{$if}/$num_CN_neutral_pos{'allchr'};
            }
            printf OUT "\t%s\:%d",$samples[$if],$depth2x{$chr}{$if};
        }
        print OUT "\n";
    }
    print OUT "CHR\tPOS\tTUMOR\tNORMAL\tDIFF\n";

    for my $chr(1..22,'X'){
        next unless (defined $data{0}{$chr} && $data{1}{$chr});
        my $cov_ratio=$NReads_CN_neutral{$chr}{0}/$NReads_CN_neutral{$chr}{1};
        my $Nwi=($#{$data{0}{$chr}}<$#{$data{0}{$chr}})?$#{$data{0}{$chr}}:$#{$data{0}{$chr}};

        for(my $i=0;$i<=$Nwi;$i++){
            next unless (defined ${$data{0}{$chr}}[$i] && defined ${$data{1}{$chr}}[$i]);
            my $cna_unadjusted=(${$data{0}{$chr}}[$i]-$cov_ratio*${$data{1}{$chr}}[$i])*2/$depth2x{$chr}{0};
            my $poschr=$i*$self->window_size;
            #printf OUT "%s\t%d\t%d\t%d\t%.6f\n",$chr,$poschr,${$data{0}{$chr}}[$i]*2/$depth2x{$chr}{0},${$data{1}{$chr}}[$i]*2/$depth2x{$chr}{1},$diff_copy;
            printf OUT "%s\t%d\t%d\t%d\t%.6f\n",$chr,$poschr,${$data{0}{$chr}}[$i],${$data{1}{$chr}}[$i],$cna_unadjusted;
        }
    }
    close(OUT);
    $self->plot_output($outfile);

    return 1;
}

sub get_median {
    my $self = shift;
    my $rpole = shift;
    my @pole = @$rpole;
    my $ret;

    @pole=sort(@pole);
    if( (@pole % 2) == 1 ) {
        $ret = $pole[((@pole+1) / 2)-1];
    } else {
        $ret = ($pole[(@pole / 2)-1] + $pole[@pole / 2]) / 2;
    }
    return $ret;
}

sub plot_output {
    my $self = shift;
    my $datafile = shift;
    my $Routfile = $datafile.".png";
    my $tempdir = Genome::Utility::FileSystem->create_temp_directory();
    my $R = Statistics::R->new(tmp_dir => $tempdir);
    $R->startR();
    $R->send(qq{
        bitmap('$Routfile', height = 8.5, width=11, res=200);
        par(mfrow=c(4,6));
        x=read.table('$datafile',comment.char='#',header=TRUE);
        for (i in c(1:22,'X')) { y=subset(x,CHR==i); plot( y\$POS, y\$DIFF, main=paste('chr.',i), xlab='mb', ylab='cn', type='p', col=rgb(0,0,0), pch='.', ylim=c(-4,4) ) };
        dev.off();
    });
    $R->stopR();
}

1;
