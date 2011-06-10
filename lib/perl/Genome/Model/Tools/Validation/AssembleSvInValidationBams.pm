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
    assembled_call_files => {
        is => 'String',
        doc => 'Comma-delimited list of assembled BreakDancer and/or SquareDancer callset filenames to assemble',
    },
    squaredancer_files => {
        is => 'String',
        doc => 'Comma-delimited list of SquareDancer files to assemble',
    },
    bam_files => {
        is => 'String',
        doc => 'Comma-delimited list of BAM files to assemble calls in',
    },
    bam_names => {
        is => 'String',
        doc => 'Comma-delimited list of labels for BAM files. MUST BE IN SAME ORDER AS BAM_FILES. Also, one of the names MUST have /normal/i in the name.',
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
    my @assembled_call_files = split(",",$self->assembled_call_files) if $self->assembled_call_files;
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
    if (@assembled_call_files) {
        for my $file (@assembled_call_files) {
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
    my $assembly_output_file = $file_prefix . ".assembly_output"; 
    my $assembly_fasta_file = $assembly_output_file . ".fasta";
    my $assembly_cm_file = $assembly_output_file . ".cm";
    my $assembly_intermediate_read_dir = $file_prefix . "_intermediate_read_dir/";
    #if read_dir exists, check to see that it's empty; otherwise, create it
    if (-e $assembly_intermediate_read_dir && -d $assembly_intermediate_read_dir) {
        my $glob = glob($assembly_intermediate_read_dir.'/*');
        if ($glob) {
            $self->error_message("Assembly intermediate read dir is not empty! Will not proceed.");
            return;
        }
    }
    else {
        mkdir $assembly_intermediate_read_dir or die "Unable to make assembly_intermediate_read_dir $assembly_intermediate_read_dir.\n";
    }
    my $bams = $self->bam_files;
    my $assembly_cmd = Genome::Model::Tools::Sv::AssemblyValidation->create(
        bam_files => $bams,
        output_file => $assembly_output_file,
        sv_file => $assembly_input,
        asm_high_coverage => 1,
        min_size_of_confirm_asm_sv => 10,
        breakpoint_seq_file => $assembly_fasta_file,
        cm_aln_file => $assembly_cm_file,
        intermediate_read_dir => $assembly_intermediate_read_dir,
    );
    $assembly_cmd->execute;

    #create index file
    my $index_file = $assembly_output_file . ".index";
    my $index_fh = new IO::File $index_file,"w";
    print $index_fh join("\t",$file_prefix,$assembly_output_file,$assembly_fasta_file."\n");
    $index_fh->close;

    #merge assembled calls
    my $merged_output_csv = $assembly_output_file . ".merged";
    my $merged_output_fasta = $assembly_fasta_file . ".merged";
    my $merge_cmd = "perl /gsc/scripts/opt/genome/current/pipeline/lib/perl/Genome/Model/Tools/Sv/MergeAssembledCallsets.pl -f $merged_output_fasta $index_file > $merged_output_csv";
    my $shell_return = Genome::Sys->shellcmd(
        cmd => "$merge_cmd",
    );

    unless ($shell_return) {
        $self->error_message("Failed to correctly execute $merge_cmd. Returned $shell_return");
        return;
    }

    #run JW's tool on the assembly files
    my $user = $ENV{USER};
    my $job_name = $file_prefix . "-jw-capture-val";
    my $stdout = $job_name . ".stdout";
    my $stderr = $job_name . ".stderr";
    my @bam_names = split(",",$self->bam_names);
    my @bam_files = split(",",$self->bam_files);
    my $jw_rc_output = $merged_output_csv . ".readcounts";
    my $jw_anno_output = $jw_rc_output . ".anno";
    my $jw_cmd = "\"/gscuser/jwallis/genome/lib/perl/Genome/Model/Tools/Sv/SV_assembly_pipeline/svCaptureValidation.pl -svFile $merged_output_csv -assemblyFile $merged_output_fasta";
    for my $i (0..$#bam_files) {
        $jw_cmd .= " -bamFiles " . $bam_names[$i] . "=" . $bam_files[$i];
    }
    $jw_cmd .= " > $jw_rc_output; /gscuser/jwallis/genome/lib/perl/Genome/Model/Tools/Sv/SV_assembly_pipeline/processSvReadRemapOutFiles.pl $jw_rc_output > $jw_anno_output\"";
    my $bsub = "bsub -q long -N -u $user\@genome.wustl.edu -J $job_name -M 8000000 -R 'select[mem>8000] rusage[mem=8000]' -oo $stdout -eo $stderr $jw_cmd";
    print "$bsub\n";
    print `$bsub`;

    return 1;
}

1;
