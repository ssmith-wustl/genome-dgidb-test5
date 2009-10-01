package Genome::Model::Tools::Somatic::SnpFilter;

use warnings;
use strict;

use Genome;
use Workflow;
use Carp;
use FileHandle;
use Data::Dumper;
use List::Util qw( max );

class Genome::Model::Tools::Somatic::SnpFilter {

    is  => ['Command'],
    has => [
        tumor_snp_file => {
            is       => 'String',
            is_input => '1',
            doc         => 'The snp filter output file from maq.',
        },
        sniper_snp_file => {
            is       => 'String',
            is_input => '1',
            doc      => 'The snp output file from somatic sniper.',
        },
        output_file => {
            is        => 'String',
            is_input  => '1',
            is_output => '1',
            doc       => 'The somatic sniper output file.',
        },
        # Make workflow choose 64 bit blades
        lsf_resource => {
            is_param => 1,
            default_value => 'rusage[mem=2000] select[type==LINUX64 & mem > 2000] span[hosts=1]',
        }, 
        lsf_queue => {
            is_param => 1,
            default_value => 'long'
        }
    ],
};

sub help_brief {
    return "Gets intersection of SNPs from somatic sniper and maq";
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
    gmt somatic snpfilter --sniper_snp_file=[pathname] --output_file=[pathname]
EOS
}

sub help_detail {                           
    return <<EOS 
    Calls `gmt snp intersect` on the tumor snp file from the last maq build and the snp file from somatic sniper.
    (Outputs lines from the somatic sniper file.)
EOS
}

sub execute {
    my ($self) = @_;
    $DB::single=1;

    # FIXME shortcutting... should we do this or not post-testing?
    if (-s $self->output_file) {
        $self->status_message("Previous output detected, shortcutting");
        return 1;
    }

    my $tumor_snp_file = $self->tumor_snp_file();
    if ( ! Genome::Utility::FileSystem->validate_file_for_reading($tumor_snp_file) ) {
        die 'cant read from: ' . $tumor_snp_file;
    }

    my $sniper_snp_file = $self->sniper_snp_file();
    my $sniper_snp_file_sorted = "/tmp/snipers.sorted";
    if ( ! Genome::Utility::FileSystem->validate_file_for_reading($sniper_snp_file) ) {
        die 'cant read from: ' . $sniper_snp_file;
    }
    #my $sort_cmd = "sort -k1,1 -k2,2n $sniper_snp_file  > $sniper_snp_file_sorted";
    my $sort_cmd = "gmt snp sort $sniper_snp_file  > $sniper_snp_file_sorted";
    my $result = Genome::Utility::FileSystem->shellcmd(
        cmd          => $sort_cmd,
        input_files  => [ $sniper_snp_file ],
        output_files => [ $sniper_snp_file_sorted ],
        skip_if_output_is_present => 0
    );
    
    my $tumor_snp_file_sorted = "/tmp/tumors.sorted";
    #$sort_cmd = "sort -k1,1 -k2,2n $tumor_snp_file  > $tumor_snp_file_sorted";
    $sort_cmd = "gmt snp sort $tumor_snp_file  > $tumor_snp_file_sorted";
    $result = Genome::Utility::FileSystem->shellcmd(
        cmd          => $sort_cmd,
        input_files  => [ $tumor_snp_file ],
        output_files => [ $tumor_snp_file_sorted ],
        skip_if_output_is_present => 0
    );
    
    my $output_file = $self->output_file();
    if ( ! Genome::Utility::FileSystem->validate_file_for_writing_overwrite($output_file) ) {
        die 'cant write to: ' . $sniper_snp_file;
    }
    

    # passing sniper snp file in first makes it the default output
    #my $cmd = "gmt snp intersect-chrom-pos -file1=$sniper_snp_file_sorted -file2=$tumor_snp_file_sorted --intersect-output=$output_file --f1-only=/dev/null --f2-only=/dev/null";
    my $cmd = "gmt snp intersect $sniper_snp_file_sorted $tumor_snp_file_sorted > $output_file";
    $result = Genome::Utility::FileSystem->shellcmd(
        cmd          => $cmd,
        input_files  => [ $sniper_snp_file_sorted, $tumor_snp_file_sorted ],
        output_files => [ $output_file ],
        skip_if_output_is_present => 0
    );
    #system("grep ^MT $sniper_snp_file >> $output_file");
    unlink($sniper_snp_file_sorted);
    unlink($tumor_snp_file_sorted);
    return $result;
}

1;
