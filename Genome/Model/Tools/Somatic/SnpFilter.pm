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
        tumor_model => {
            is          => 'Genome::Model',
            id_by       => 'tumor_model_id',
            is_optional => 1,
        },
        tumor_model_id => { 
            is_input    => 1, 
            is          => 'integer', 
            is_optional => 0 
        },
        tumor_snp_file => {
            calculate_from => 'tumor_model',
            calculate      => q{
                my $build = $tumor_model->last_complete_build || die 'no completed build';
                return $build->filtered_snp_file();
            },
            is_optional => 1,
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
    my $sort_cmd = "sort -k1,1 -k2,2n $sniper_snp_file | grep -v ^MT > $sniper_snp_file_sorted";
    my $result = Genome::Utility::FileSystem->shellcmd(
        cmd          => $sort_cmd,
        input_files  => [ $sniper_snp_file ],
        output_files => [ $sniper_snp_file_sorted ],
        skip_if_output_is_present => 0
    );
    
    my $tumor_snp_file_sorted = "/tmp/tumors.sorted";
    $sort_cmd = "sort -k1,1 -k2,2n $tumor_snp_file | grep -v ^MT > $tumor_snp_file_sorted";
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
    my $cmd = "gmt snp intersect-chrom-pos -file1=$sniper_snp_file_sorted -file2=$tumor_snp_file_sorted --intersect-output=$output_file --f1-only=/dev/null --f2-only=/dev/null";
    $result = Genome::Utility::FileSystem->shellcmd(
        cmd          => $cmd,
        input_files  => [ $sniper_snp_file_sorted, $tumor_snp_file_sorted ],
        output_files => [ $output_file ],
        skip_if_output_is_present => 0
    );
    system("grep ^MT $sniper_snp_file >> $output_file");
    unlink($sniper_snp_file_sorted);
    unlink($tumor_snp_file_sorted);
    return $result;
}

1;
