package Genome::Model::Tools::Validation::AssembleSvInValidationBams;

use strict;
use warnings;

use Cwd;
use Genome;
use List::Util qw(sum);

class Genome::Model::Tools::Validation::AssembleSvInValidationBams {
    is => 'Command',
    has_input => [
    output_filename_prefix => {
        is => 'String',
        doc => 'path and prefix to specify output files (which will include *.csv, *.fasta, etc.)',
    },
    ],

    has_optional_input => [
    breakdancer_files => {
        is => 'String',
        doc => 'Comma-delimited list of BreakDancer files to assemble',
    },
    squaredancer_files => {
        is => 'String',
        doc => 'Comma-delimited list of SquareDancer files to assemble',
    },
    bam_files => {
        is => 'String',
        doc => 'Comma-delimited list of BAM files to assemble calls in',
    },


    ],
    doc => 'Assemble SV predictions in validation .bam files.',
};

sub help_detail {
    return <<EOS
    This tool combines SquareDancer and BreakDancer predictions into one file, annotates this file with BreakAnnot.pl, and then feeds the calls into the 'gmt sv assembly-validation' script for producing assemblies based on validation .bam files.

    For BreakDancer files, which have an inner- and outer-start and stop position, all four combinations of these starts and stopsare used to fabricate 4 separate calls in the combined file. This usually leads to duplicate assembly contings, so all assemblies are later merged to produce final output files. These output files may be fed into John Wallis' svCaptureValidation.pl for final evaluation of the real-ness of the calls.
EOS
}

sub execute {
    
    $DB::single = 1;
    my $self = shift;

    #parse input params
    my @bd_files = split(",",$self->breakdancer_files) if $self->breakdancer_files;
    my @sd_files = split(",",$self->squaredancer_files) if $self->squaredancer_files;
    my $file_prefix = $self->output_filename_prefix;
    my $assembly_input = $file_prefix . ".assembly_input";

    #concatenate calls for assembly input
    #my $ass_in_fh = Genome::Sys->open_file_for_writing($assembly_input);
    my $ass_in_fh = new IO::File $assembly_input,"w";
    unless ($ass_in_fh) {
        $self->error_message("Unable to open file $assembly_input for writing");
        return;
    }

    #print header
    print $ass_in_fh join("\t",qw(#Chr1 Pos1 Orientation1 Chr2 Pos2 Orientation2 Type Size Score)),"\n";

    #add in SD calls
    if (@sd_files) {
        for my $file (@sd_files) {
            my $in_fh = new IO::File $file,"r";
            while (my $line = $in_fh->getline) {
                next if $line =~ /^#/;
                my @fields = split /\t/,$line;
                print $ass_in_fh join("\t",@fields[0..8]),"\n";
            }
            $in_fh->close;
        }
    }

    #add in BD calls (combinatorically using all combinations, due to the possibility of having 2 different start and 2 different stop coordinates)
    #expected breakdancer input format:
    #ID     CHR1    OUTER_START     INNER_START     CHR2    INNER_END       OUTER_END       TYPE    ORIENTATION     MINSIZE MAXSIZE SOURCE  SCORES  Copy_Number
    #20.7    20      17185907        17185907        22      20429218        20429218        CTX     ++      332     332     tumor22 750     NA      NA      NA
    if (@bd_files) {
        for my $file (@bd_files) {
            my $in_fh = new IO::File $file,"r";
            while (my $line = $in_fh->getline) {
                next if $line =~ /^#/;
                my @F = split /\t/,$line;
                my @combinatoric_lines;
                my $mean_size = sum($F[9],$F[10]) / 2;
                push @combinatoric_lines, join("\t",@F[1,2,8],@F[4,5,8],$F[7],$mean_size,"99");
                push @combinatoric_lines, join("\t",@F[1,3,8],@F[4,5,8],$F[7],$mean_size,"99");
                push @combinatoric_lines, join("\t",@F[1,2,8],@F[4,6,8],$F[7],$mean_size,"99");
                push @combinatoric_lines, join("\t",@F[1,3,8],@F[4,6,8],$F[7],$mean_size,"99");
                my %printed_lines;
                for my $line (@combinatoric_lines) {
                    next if $printed_lines{$line};
                    $printed_lines{$line} = 1;
                    print $ass_in_fh $line,"\n";
                }
            }
            $in_fh->close;
        }
    }
    $ass_in_fh->close;

    


    #execute assembly command
    my $user = $ENV{USER};
    my $job_name = 
    my $stdout = $file_prefix . ".stdout";
    my $stderr = $file_prefix . ".stderr";
    my $assembly_fasta_file = $file_prefix . ".fasta";
    my $assembly_cm_file = $file_prefix . ".cm";
    my $assembly_intermediate_read_dir = $file_prefix . "_inter_read_dir/";
    unless (-e $assembly_intermediate_read_dir && -d 

    

    my $bams = $self->bam_files;
    my $assembly_cmd = "gmt sv assembly-validation --bam-files $bams --breakpoint-seq-file $assembly_fasta_file --cm-aln-file $assembly_cm_file --intermediate-read-dir
    my $bsub = "bsub -q long -N -u $user\@genome.wustl.edu -J $job_name -M 8000000 -R 'select[mem>8000] rusage[mem=8000]' -oo $stdout -eo $stderr $assembly_cmd";


    return 1;
}

1;
