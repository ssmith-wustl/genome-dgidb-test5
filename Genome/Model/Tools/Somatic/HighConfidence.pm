package Genome::Model::Tools::Somatic::HighConfidence;

use strict;
use warnings;

use Genome;
use Command;
use IO::File;
use Readonly;
use Genome::Info::IUB;

class Genome::Model::Tools::Somatic::HighConfidence {
    is => 'Command',
    has => [
       'sniper_file' => {
           type => 'String',
           is_input => 1,
           doc => 'somatic sniper or pileup output',
       },
       'output_file' => {
           type => 'String',
           is_input => 1,
           is_output => 1,
           doc => 'File name in which to write output',
       },
       'tumor_bam_file' => {
            type => 'String',
            doc => 'Tumor bam file in which to examine reads',
            is_optional => 1,
       },
       'min_mapping_quality' => {
            type => 'String',
            default => '70',
            is_optional => 1,
            is_input => 1,
            doc => 'minimum average mapping quality threshold for high confidence call',
       },
       'min_somatic_quality' => {
            type => 'String',
            default => '40',
            is_optional => 1,
            is_input => 1,
            doc => 'minimum somatic quality threshold for high confidence call',
       },
       # Make workflow choose 64 bit blades
       lsf_resource => {
            is_param => 1,
            default_value => 'rusage[mem=4000] select[type==LINUX64] span[hosts=1]',
       },
       lsf_queue => {
            is_param => 1,
            default_value => 'long',
       },
       skip => {
           is => 'Boolean',
           default => '0',
           is_input => 1,
           is_optional => 1,
           doc => "If set to true... this will do nothing! Fairly useless, except this is necessary for workflow.",
       },
    ]
};

sub help_brief {
    return "This module takes in somatic sniper output and filters it to high confidence variants";
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
    genome model tools somatic high-confidence --sniper-file sniper,out --tumor-bam somefile.bam 
EOS
}

sub help_detail {                           
    return <<EOS 
This module takes in somatic sniper output and filters it to high confidence variants
EOS
}

sub execute {
    my $self = shift;
    $DB::single=1;

    if ($self->skip) {
        $self->status_message("Skip flag set. Skipping execution.");
        return 1;
    }
    #test architecture to make sure we can run read count program
    #copied from G::M::T::Maq""Align.t 
    unless (`uname -a` =~ /x86_64/) {
        $self->error_message(`uname -a`); #FIXME remove
       $self->error_message("Must run on a 64 bit machine");
       die;
    }

    #check on BAM file
    unless(-e $self->tumor_bam_file) {
        $self->error_message("Tumor bam file: " . $self->tumor_bam_file . " does not exist");
        die;
    }

    unless(-e $self->tumor_bam_file . ".bai") {
        $self->error_message("Tumor bam must be indexed");
        die;
    }
    
    my $fh = IO::File->new($self->sniper_file, "r");
    unless($fh) {
        $self->error_message("Unable to open " . $self->sniper_file . ". $!");
        die;
    }
    
    my $ofh = IO::File->new($self->output_file, "w");
    unless($ofh) {
        $self->error_message("Unable to open " . $self->output_file . " for writing. $!");
        die;
    }
    $self->status_message("Opened " . $self->output_file . " for writing"); #FIXME remove

    my ($tfh,$temp_path) = Genome::Utility::FileSystem->create_temp_file;
    unless($tfh) {
        $self->error_message("Unable to create temporary file $!");
        die;
    }
    $temp_path =~ s/\:/\\\:/g;
    system("cp $temp_path output.txt");

    print $temp_path, "\n";

   
    #read sniper and skip indels
    my $somatic_threshold = $self->min_somatic_quality;
    
    my @sniper_lines;
    while(my $line = $fh->getline) {
        chomp $line;
        my ($chr, $start, $stop, $ref, $iub, $type, $somatic_score, @annotation_columns) = split /\t/, $line;
        next if $ref eq "*";
        if($somatic_score >= $somatic_threshold) {
            print $tfh "$chr\t$start\t$stop\n";
            push @sniper_lines, $line
        }
    }
    $tfh->close;

    my $mapping_quality_threshold = $self->min_mapping_quality;
    
    my $current_variant = shift @sniper_lines;
    #this will be used in the loop below to evaluate readcount output with input
    return 1 unless $current_variant;
    my ($vchr, $vstart, $vstop, $vref, $viub) = split /\t/, $current_variant;

    my $readcount_command = sprintf("%s -q 1 -l %s %s |",$self->readcount_program, $temp_path, $self->tumor_bam_file);
    $self->status_message("Running: $readcount_command");
    my $readcounts = IO::File->new($readcount_command);
    while(my $count_line = $readcounts->getline) {
        chomp $count_line;
        my ($chr, $pos, $ref, $depth, @base_stats) = split /\t/, $count_line;

        my %bases;
        for my $base_stat (@base_stats) {
            my ($base,$reads,$avg_mq, $avg_bq) = split /:/, $base_stat;
            #Leaving bases coded as '=' unhandled
            next if($base eq "=");
            $bases{$base} = $avg_mq;
        }
        #it should be possible that readcount program does not return a line, but not that the readcount program receives a variant not in our array
        while($vchr ne $chr && $vstart != $pos && @sniper_lines) {
            $current_variant = shift @sniper_lines;
            #this will be used in the loop below to evaluate readcount output with input
            $self->status_message("Skipped $current_variant");
            last unless $current_variant;
            ($vchr, $vstart, $vstop, $vref, $viub) = split /\t/, $current_variant;
        }
            #then we have the site
            my @vars = Genome::Info::IUB->variant_alleles_for_iub($vref,$viub);
            foreach my $var (@vars) {
                if(exists($bases{$var}) && $bases{$var} >= $mapping_quality_threshold) {
                    print $ofh $current_variant, "\n";
                    last;
                }
            }
            #Skip this variant assuming it wasn't reported by the C prog
            $current_variant = shift @sniper_lines;
            last unless $current_variant;
            ($vchr, $vstart, $vstop, $vref, $viub) = split /\t/, $current_variant;
    }
    unless($readcounts->close()) {
        $self->error_message("Error running " . $self->readcount_program);
        die;
    }

    
    return 1;
}

1;

sub readcount_program {
    return "bam-readcount";
}
