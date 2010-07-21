package Genome::Model::Tools::Pindel::DumpReads;

use warnings;
use strict;

use Genome;
use Workflow;
use Carp;
use FileHandle;
use Data::Dumper;
use List::Util qw( max );

class Genome::Model::Tools::Pindel::DumpReads {
    is => ['Command'],
    has => [
        bam_file => { 
            is  => 'String',
            is_input=>1, 
            doc => 'The input tumor BAM file.',
        },
        output_sw_reads => {
            is  => 'String',
            is_input => '1',
            is_output => '1',
            doc => 'The somatic sniper SNP output file.',
        },
        output_single_reads => {
            is  => 'String',
            is_input => '1',
            is_output => '1',
            doc => 'The somatic sniper indel output file.',
        },
        skip_if_output_present => {
            is => 'Boolean',
            is_optional => 1,
            is_input => 1,
            default => 1,
            doc => 'enable this flag to shortcut through annotation if the output_file is already present. Useful for pipelines.',
        },
        # Make workflow choose 64 bit blades
        lsf_resource => {
            is_param => 1,
            default_value => 'rusage[mem=8000] select[type==LINUX64] span[hosts=1] -M 8589934592',
        },
        lsf_queue => {
            is_param => 1,
            default_value => 'long'
        }, 
    ],
};

sub help_brief {
    "Dumps single-end and smith-waterman reads for a given BAM file.";
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
gmt pindel dump-reads --bam-file sample.bam --output-single-reads single.out --output-sw-reads sw.out
gmt pindel dump-reads --bam sample.bam --output-single single.out --output-sw sw.out
EOS
}

sub help_detail {                           
    return <<EOS 
    Provide a BAM file and get dumped single-end and smith-waterman reads
EOS
}

sub execute {
    my $self = shift;
    $DB::single = $DB::stopper;

    # test architecture to make sure we can run
    unless (`uname -a` =~ /x86_64/) {
       $self->error_message("Must run on a 64 bit machine");
       die;
    }

    # Skip if output files exist
    if (($self->skip_if_output_present)&&(-s $self->output_sw_reads)&&(-s $self->output_single_reads)) {
        $self->status_message("Skipping execution: Output is already present and skip_if_output_present is set to true");
        return 1;
    }

    # Validate files
    unless ( Genome::Utility::FileSystem->validate_file_for_reading($self->bam_file) ) {
        $self->error_message("Could not validate bam file:  ".$self->bam_file );
        die;
    } 
    
    # BWA denotes smith waterman reads with the tag XT:A:M -- MAQ denotes smith waterman reads with the tag MF:i:130
    my $sw_dump_cmd= "samtools view " . $self->bam_file . ' | grep "XT:A:M\|MF:i:130" | cut -f1-5,9,10,13,15-18 > ' . $self->output_sw_reads;
    my $sw_result = Genome::Utility::FileSystem->shellcmd( cmd=>$sw_dump_cmd, input_files=>[$self->bam_file], output_files=>[$self->output_sw_reads],);
    
    # awk reads: check if one read or the mate is mapped, but not both (logical xor but we could not get gawk to play nice)
    my $single_dump_cmd= "samtools view " . $self->bam_file . " | gawk -F '\t' '( ( and(\$2, 4) && !and(\$2, 8) ) || ( !and(\$2, 4) && and(\$2, 8) ) )' | cut -f1-5,9,10,13,15-18 > " . $self->output_single_reads; 
    my $single_result = Genome::Utility::FileSystem->shellcmd( cmd=>$single_dump_cmd, input_files=>[$self->bam_file], output_files=>[$self->output_single_reads],);

    $self->status_message("ending execute");

    # Make sure both succeed in order to return 1
    return ($sw_result && $single_result); 
}

1;
