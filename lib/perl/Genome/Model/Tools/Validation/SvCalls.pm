package Genome::Model::Tools::Validation::SvCalls;

use strict;
use warnings;

use Cwd;
use Genome;
use List::Util qw(sum);

class Genome::Model::Tools::Validation::SvCalls {
    is => 'Command',
    has_input => [
    output_filename_prefix => {
        is => 'String',
        doc => 'path and prefix to specify output files (which will include *.csv, *.fasta, etc.)',
    },
    tumor_val_bam => {
        is => 'String',
        doc => 'path to tumor validation .bam file',
    },
    normal_val_bam => {
        is => 'String',
        doc => 'path to normal validation .bam file',
    },
    patient_id => {
        is => 'String',
        doc => 'string to describe patient, such as LUC5',
    },
    ],
    has_optional_input => [
    tumor_wgs_bam => {
        is => 'String',
        doc => 'path to tumor WGS .bam file',
    },
    normal_wgs_bam => {
        is => 'String',
        doc => 'path to normal WGS .bam file',
    },
    assembled_call_files => {
        is => 'String',
        doc => 'Comma-delimited list of assembled BreakDancer and/or SquareDancer callset filenames to assemble',
    },
    squaredancer_files => {
        is => 'String',
        doc => 'Comma-delimited list of SquareDancer files to assemble',
    },
    ref_seq => {
        is => 'String',
        doc => 'Optional reference sequence path (default: NCBI-human-build36)',
        default => '/gscmnt/gc4096/info/model_data/2741951221/build101947881/all_sequences.fa'
    },
    tumor_purity_file => { 
        is => 'Text',
        #doc => "File with two columns; patientId and fraction of tumor cells in tumor sample (1 is pure tumor).",
        doc => "Used only when there is tumor contamination in normal sample. File with two columns; patientId and tumor purity expressed as fraction of tumor cells in tumor sample (1 is pure tumor).",
        is_optional => 1 
    },
    tumor_in_normal_file => { 
        is => 'Text',
        #doc => "File with two columns; patientId and fraction of normal contamination in tumor (0 is no contamination)."
        doc => "Used only when there is tumor contamination in normal sample. File with two columns; patientId and amount of tumor contamination in normal (0 is no contamination)."
    },
    ],
    doc => 'Validate SV predictions. Period.',
};

sub help_detail {
    return <<EOS
    This tool combines SquareDancer and BreakDancer (assembled) predictions into one file and then feeds the calls into the 'gmt sv assembly-validation' script for producing assemblies based on validation .bam files. For BreakDancer files, which have an inner- and outer-start and stop position, all four combinations of these starts and stops are used to fabricate 4 separate combinatoric calls in the combined file. This usually leads to duplicate assembly contings, so all assemblies are then merged to produce final merged csv and fasta files. These output files are fed into 'gmt sv assembly-pipeline remap-reads' for evaluation of readcounts of support for the calls in each .bam file, and then subsequently fed into 'gmt sv assembly-pipeline classify-events', which will look at the readcounts in tumor and normal, and divide the events into four files which represent four call categories: 'somatic', 'germline', 'ambiguous', and 'no event'. Then, if WGS BAM files are provided, the somatic events from the validation BAMs are fed BACK through 'remap-reads' to obtain readcounts from the WGS BAMs. These readcounts are produced in a separate output file named '<readcounts-file>.somatic.wgs_readcounts'. This file is parsed and a new somatic file is created ('<readcounts-file>.somatic.wgs_readcounts.somatic'), which contains only those events that had 0 coverage in the normal WGS BAM file (because this is the greatest source of false positives). For more help, see Nathan Dees.
EOS
}

sub execute {
    
    $DB::single = 1;
    my $self = shift;

    #parse input params
    my @assembled_call_files = split(",",$self->assembled_call_files) if $self->assembled_call_files;
    my @sd_files = split(",",$self->squaredancer_files) if $self->squaredancer_files;
    my $ref_seq = $self->ref_seq;
    my $file_prefix = $self->output_filename_prefix;
    my $assembly_input = $file_prefix . ".assembly_input";
    my $patient_id = $self->patient_id;
    my $tumor_val_bam = $self->tumor_val_bam;
    my $normal_val_bam = $self->normal_val_bam;
    my $tumor_wgs_bam = $self->tumor_val_bam;
    my $normal_wgs_bam = $self->normal_val_bam;

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

#Intermediate read directories take a lot of space and are probably only needed for special applications.    
=cut
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
=cut

    my $bams = join(",",$tumor_val_bam,$normal_val_bam);
    my $assembly_cmd = Genome::Model::Tools::Sv::AssemblyValidation->create(
        bam_files => $bams,
        output_file => $assembly_output_file,
        sv_file => $assembly_input,
        asm_high_coverage => 1,
        min_size_of_confirm_asm_sv => 10,
        breakpoint_seq_file => $assembly_fasta_file,
        cm_aln_file => $assembly_cm_file,
        reference_file => $ref_seq,
        #intermediate_read_dir => $assembly_intermediate_read_dir,
    );
    $assembly_cmd->execute;
    $assembly_cmd->delete;


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

    #run JW's RemapReads on validation .bam files to obtain readcounts for tumor and normal
    #perl -I ~/git/genome/lib/perl/ `which gmt` sv assembly-pipeline remap-reads --assembly-file TEST.assembly_output.fasta.merged --normal-bam mel2n.9.bam --tumor-bam mel2t.9.bam --sv-file TEST.assembly_output.merged --output-file new.tool.test.REMAP --patient-id TEST
    my $val_patient_id = "VAL." . $patient_id;
    my $rc_output = $merged_output_csv . ".readcounts";
    my $val_remap_cmd = Genome::Model::Tools::Sv::AssemblyPipeline::RemapReads->create(
        assembly_file => $merged_output_fasta,
        sv_file => $merged_output_csv,
        tumor_bam => $tumor_val_bam,
        normal_bam => $normal_val_bam,
        patient_id => $val_patient_id,
        output_file => $rc_output,
    );
    $val_remap_cmd->execute;
    $val_remap_cmd->delete;

    #run JW's ClassifyEvents to make calls for events using the readcounts output
    #perl -I ~/git/genome/lib/perl/ `which gmt` sv assembly-pipeline classify-events --readcount-file new.tool.test.RE
    my $classify_cmd = Genome::Model::Tools::Sv::AssemblyPipeline::ClassifyEvents->create(
        readcount_file => $rc_output,
        tumor_purity_file => $self->tumor_purity_file,
        tumor_in_normal_file => $self->tumor_in_normal_file,        
    );
    $classify_cmd->execute;

    #Somatic events in this case will end up in the following file:
    my $somatics = $rc_output . ".somatic";

    #OPTIONAL STEPS if WGS BAMS are present
    if (defined $tumor_wgs_bam && defined $normal_wgs_bam) {

        #Create readcounts in the WGS BAMs to see if a germline event might have sneaked through (look for coverage in normal wgs .bam)
        my ($wgs_patient_id, $wgs_rc_output);
        $wgs_patient_id = "WGS." . $patient_id;
        $wgs_rc_output = $somatics . ".wgs_readcounts";
        my $wgs_remap_cmd = Genome::Model::Tools::Sv::AssemblyPipeline::RemapReads->create(
            assembly_file => $merged_output_fasta,
            sv_file => $somatics,
            tumor_bam => $tumor_wgs_bam,
            normal_bam => $normal_wgs_bam,
            patient_id => $wgs_patient_id,
            output_file => $wgs_rc_output,
        );
        $wgs_remap_cmd->execute;
        $wgs_remap_cmd->delete;

        #Use the WGS readcounts to re-determine somatic status
        my $new_somatics = $wgs_rc_output . ".somatic";
        my $new_somatics_fh = new IO::File $new_somatics,"w";
        my $wgs_rc_fh = new IO::File $wgs_rc_output,"r";
        while (my $line = $wgs_rc_fh->getline) {
            if ( $line =~ /^#/ ) { print $new_somatics_fh $line; next; }
            if ( $line =~ /no\s+fasta\s+sequence/ ) { next; }
            if ( $line =~ /$wgs_patient_id.normal.svReadCount\:(\d+)/i ) {
                my ($normal_sv_readcount) = $line =~ /$wgs_patient_id.normal.svReadCount\:(\d+)/i;
                if ($normal_sv_readcount > 0) { next; }
                else { print $new_somatics_fh $line; next; }
            }
        }
        $wgs_rc_fh->close;
        $new_somatics_fh->close;
    }

    return 1;
}

1;
