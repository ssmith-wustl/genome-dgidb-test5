package Genome::Model::Tools::Sam::Coverage;

use strict;
use warnings;

use Genome;
use Command;
use IO::File;

my $SAM_DEFAULT = Genome::Model::Tools::Sam->default_samtools_version;

class Genome::Model::Tools::Sam::Coverage {
    is  => 'Command',
    has => [
        aligned_reads_file => {
            is  => 'String',
            doc => 'The input sam/bam file.',
        },
        reference_file => {
            is  => 'String',
            doc => 'The reference file used in the production of the aligned reads file.',
        },
        return_output => {
            is => 'Integer',
            doc => 'Flag to allow the return of the coverage report string.',
            default_value => 1,
        }, 
    ],
    has_optional => [
        output_file => {
            is =>'String',
            doc => 'The output file containing metrics.  If no file is provided a temporary file is created.',
        },
        coverage_command => {
            is =>'String',
            doc => 'The coverage command tool path.',
        },

    ],
};


sub help_brief {
    'Calculate haploid coverage using a BAM file.';
}

sub help_detail {
    return <<EOS
    Calculate haploid coverage using a BAM file.  
EOS
}


sub execute {
    my $self = shift;
    my $reference = $self->reference_file;
    my $aligned_reads = $self->aligned_reads_file;

    my $coverage_cmd;
    if (defined $self->coverage_command) {
       $coverage_cmd = $self->coverage_command;
    } else { 
        #Switch this when wu350 is deployed 
        #my $samtools_cmd = Genome::Model::Tools::Sam->path_for_samtools_version($SAM_DEFAULT);
        my $samtools_cmd = "/gscuser/dlarson/samtools/r350wu1/samtools"; 
        $coverage_cmd = "$samtools_cmd mapcheck"; 
    }

    my $output_file;
    if (defined $self->output_file) {
        $output_file = $self->output_file;
    } else {
        $output_file = Genome::Utility::FileSystem->create_temp_file_path('mapcheck_coverage_results');
    }
 
    #my $cmd = "/gscuser/charris/c-src-BLECH/trunk/samtool2/samtools mapcheck /gscuser/jpeck/bam/map-TESTINGLIBRARY.bam -f /gscmnt/839/info/medseq/reference_sequences/NCBI-human-build36/all_sequences.fa";
    my $cmd = "$coverage_cmd $aligned_reads -f $reference > $output_file";

    $self->status_message("Mapcheck coverage command: ".$cmd);
    my $report_rv = Genome::Utility::FileSystem->shellcmd(cmd=>$cmd,output_files=>[$output_file],input_files=>[$aligned_reads,$reference]);
    
    my @output_text;
    my $return_text; 
    if ($self->return_output) {
        my $out_fh = Genome::Utility::FileSystem->open_file_for_reading($output_file);
        if ($out_fh) {
            @output_text = $out_fh->getlines;
        } 
        $out_fh->close;
        $return_text = join("",@output_text);
        return $return_text;
    } 

    return 1; 

}


1;
