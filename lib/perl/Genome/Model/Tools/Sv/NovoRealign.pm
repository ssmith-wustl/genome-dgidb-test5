#ReAlign BreakDancer SV supporting reads using novoalign and produce a bam file
package Genome::Model::Tools::Sv::NovoRealign;

use strict;
use warnings;
use Genome;
use File::Basename;

=cut

my %opts = (
	    n=>"/gscuser/kchen/bin/novoalign-2.05.13",
	    i=>"/gscuser/kchen/sata114/kchen/Hs_build36/all_fragments/Hs36_rDNA.fa.k14.s3.ndx",
	    t=>"/gscuser/kchen/1000genomes/analysis/scripts/novo2sam.pl",
	    f=>"SLX"
	   );
getopts('n:i:f:t:',\%opts);
die("
Usage:   novoRealign.pl <breakdancer configure file>\n
Options:
         -n STRING  Path to novoalign executable
         -i STRING  Path to novoalign reference sequence index
         -t STRING  Path to novo2sam.pl
         -f STRING  Specify platform [$opts{f}]
\n"
) unless (@ARGV);

=cut

class Genome::Model::Tools::Sv::NovoRealign {
    is  => 'Genome::Model::Tools::Sv',
    has => [
        config_file => {
            type => 'String',
            doc  => 'breakdancer config file',
            is_input => 1,
        },
    ],
    has_optional => [
        output_file => {
            type => 'String',
            doc  => 'output novo config file',
            is_output => 1,
        },
        novoalign_path => {
            type => 'String',
            doc  => 'novoalign executeable path to use',
            default_value => '/gscuser/kchen/bin/novoalign-2.05.13',
        },
        novoalign_ref_index => {
            type => 'String',
            doc  => 'Path to novoalign reference sequence index',
            default_value => '/gscuser/kchen/sata114/kchen/Hs_build36/all_fragments/Hs36_rDNA.fa.k14.s3.ndx',
        },
        novo2sam_path => {
            type => 'String',
            doc  => 'Path to novoalign reference sequence index',
            default_value => '/gscuser/kchen/1000genomes/analysis/scripts/novo2sam.pl',
        },
        platform => {
            type => 'String',
            doc  => 'Path to novoalign reference sequence index',
            default_value => 'SLX',
        },
    ],
};


sub execute {
    my $self     = shift;
    my $cfg_file = $self->config_file;
    my (%mean_insertsize, %std_insertsize, %readlens);

    my $fh = Genome::Sys->open_file_for_reading($cfg_file) or die "unable to open config file: $cfg_file";
    while (my $line = $fh->getline) {
        next unless $line =~ /\S+/;
        chomp $line;
        my ($mean)   = $line =~ /mean\w*\:(\S+)\b/i;
        my ($std)    = $line =~ /std\w*\:(\S+)\b/i;
        my ($lib)    = $line =~ /lib\w*\:(\S+)\b/i;
        my ($rd_len) = $line =~ /readlen\w*\:(\S+)\b/i;

        ($lib) = $line =~ /samp\w*\:(\S+)\b/i unless defined $lib;
        $mean_insertsize{$lib} = int($mean + 0.5);
        $std_insertsize{$lib}  = int($std  + 0.5);
        $readlens{$lib}        = $rd_len;
    }
    $fh->close;

    my %fastqs;
    my $dir = dirname $cfg_file;

    opendir (DIR, $dir || '.');
    my $prefix;
    for my $fastq (grep{/\.fastq/} readdir(DIR)){
        for my $lib (keys %mean_insertsize) {
            #if ($fastq =~/^(\S+)\.\S+${lib}\.\S*([12])\.fastq/) {
            if ($fastq =~/^(\S+)\.${lib}\.\S*([12])\.fastq/) {
                $prefix = $1;
                my $id  = $2;
                #push @{$fastqs{$lib}{$id}}, $fastq if defined $id;
                push @{$fastqs{$lib}{$id}}, $dir.'/'.$fastq if defined $id;
                last;
            }
        }
    }
    closedir(DIR);

    $prefix = $dir . "/$prefix";

    my @bams2remove; 
    my @librmdupbams;
    my @novoaligns;
    my %headerline;

    my $novo_path    = $self->novoalign_path;
    my $novosam_path = $self->novo2sam_path;

    for my $lib (keys %fastqs) {
        my @read1s = @{$fastqs{$lib}{1}};
        my @read2s = @{$fastqs{$lib}{2}};
        my $line   = sprintf "\@RG\tID:%s\tPU:%s\tLB:%s", $lib, $self->platform, $lib;
        $headerline{$line} = 1;
        my @bams;
        my $cmd;
        for (my $i=0; $i<=$#read1s; $i++) {
            my $fout_novo = "$prefix.$lib.$i.novo";
            $cmd = $novo_path. ' -d '.$self->novoalign_ref_index." -f $read1s[$i] $read2s[$i] -i $mean_insertsize{$lib} $std_insertsize{$lib} > $fout_novo";

            $self->_run_cmd($cmd);
            push @novoaligns,$fout_novo;
            
            my $sort_prefix = "$prefix.$lib.$i";
            $cmd = $novosam_path . " -g $lib -f ".$self->platform." -l $lib $fout_novo | samtools view -b -S - -t /gscuser/kchen/reference_sequence/in.ref_list | samtools sort - $sort_prefix";
            $self->_run_cmd($cmd);
            push @bams, $sort_prefix.'.bam';
            push @bams2remove, $sort_prefix.'.bam';
        }
    
        if ($#bams>0) {
            $cmd = "samtools merge $prefix.$lib.bam ". join(' ', @bams);
            $self->_run_cmd($cmd);
            push @bams2remove, "$prefix.$lib.bam";
        }
        else {
            `mv $bams[0] $prefix.$lib.bam`;
        }

        $cmd = "samtools rmdup $prefix.$lib.bam $prefix.$lib.rmdup.bam";
        $self->_run_cmd($cmd);
        push @librmdupbams, "$prefix.$lib.rmdup.bam";
    }

    my $header_file = $prefix . '.header';
    my $header = Genome::Sys->open_file_for_writing($header_file) or die "fail to open $header_file for writing\n";
    for my $line (keys %headerline) {
        $header->print("$line\n");
    }
    $header->close;

    my $cmd = "samtools merge -h $header_file $prefix.novo.rmdup.bam ". join(' ', @librmdupbams);
    $self->_run_cmd($cmd);
    
    my $out_file = $self->output_file || "$prefix.novo.cfg";
    $self->output_file($out_file);

    my $novo_cfg = Genome::Sys->open_file_for_writing($out_file) or die "failed to open $out_file for writing\n";
    for my $lib (keys %fastqs) {
        $novo_cfg->print("map:$prefix.novo.rmdup.bam\tmean:%s\tstd:%s\treadlen:%s\tsample:%s\texe:samtools view\n",$mean_insertsize{$lib},$std_insertsize{$lib},$readlens{$lib},$lib);
    }
    $novo_cfg->close;

    unlink (@bams2remove,@librmdupbams,@novoaligns);
    return 1;
}

sub _run_cmd {
    my ($self, $cmd) = @_;
    
    unless (Genome::Sys->shellcmd(
        cmd => $cmd,
    )) {
        $self->error_message("Failed to run $cmd");
        die $self->error_message;
    }
    return 1;
}


