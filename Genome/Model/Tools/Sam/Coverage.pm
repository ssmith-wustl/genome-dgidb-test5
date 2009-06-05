package Genome::Model::Tools::Sam::Coverage;

use strict;
use warnings;

use Genome;
use Command;
use IO::File;

class Genome::Model::Tools::Sam::Coverage {
    is  => 'Command',
    has => [
        pileup_file => {
            is  => 'String',
            doc => 'The input sam/bam pileup file.',
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
            doc => 'The output file containing metrics.',
        },
    ],
};


sub help_brief {
    'Calculate haploid coverage using a SAM pileup file.';
}

sub help_detail {
    return <<EOS
    Calculate haploid coverage using the SAM pileupfile.  
EOS
}


sub execute {
    my $self = shift;
    my $pileup_file = $self->pileup_file;
    my $output_file = $self->output_file;

    my $genome_size = 0;
    my $non_n_genome_size = 0;
    my $number_of_bases_covered = 0;
    my $number_of_bases_mapped = 0;
    my $haploid_coverage = 0;
    
    if (-s $pileup_file) {
        my $pileup_fh = Genome::Utility::FileSystem->open_file_for_reading($pileup_file) or return;
        
        
        while (my $line = $pileup_fh->getline) {
           
            my ($chr, $pos, $ref, $con, $qual, $snp_qual, $max_map_qual, $read_depth, $rest ) = split(/\s+/,$line);
           
            next if $ref eq '*'; #skip all indels e.g. lines with a '*' for $ref

            $genome_size++;
            next if $ref eq 'N'; #count N's via genome_size, but skip the rest of the metrics

            $non_n_genome_size++;
            $number_of_bases_covered++ if $read_depth > 0;
            $number_of_bases_mapped = $number_of_bases_mapped + $read_depth; 
            
        }
        $pileup_fh->close;

        $haploid_coverage = $number_of_bases_mapped / $non_n_genome_size;

        my $report_output;
        #print $out_fh "Average depth across all non-gap regions: $haploid_coverage\n";
        my $now = UR::Time->now();
        $report_output =  "Average depth across all non-gap regions: $haploid_coverage\n"
        . "Genome size: $genome_size\n"
        . "Non-N genome size: $non_n_genome_size\n"
        . "Number of bases covered: $number_of_bases_covered\n"
        . "Number of bases mapped: $number_of_bases_mapped\n"
        . "Input file: $pileup_file\n"
        . "Date and time calculated: $now\n";
        

        if (defined $self->output_file) {
            my $out_fh = Genome::Utility::FileSystem->open_file_for_writing($output_file) or return;
            print $out_fh $report_output;
            $out_fh->close;
        }
        
        if ($self->return_output) {
            return $report_output;
        }
    
    } else {
        $self->error_message('Provided pileup file does not exist: '.$pileup_file);
        return;
    }

    return 1; 
    

}


1;
