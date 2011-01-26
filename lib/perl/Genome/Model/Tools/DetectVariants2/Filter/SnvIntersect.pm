package Genome::Model::Tools::DetectVariants2::Filter::SnvIntersect;

use warnings;
use strict;

use Genome;
use Workflow;
use Carp;
use FileHandle;
use Data::Dumper;
use List::Util qw( max );

class Genome::Model::Tools::DetectVariants2::Filter::SnvIntersect {
    is  => ['Genome::Model::Tools::DetectVariants2::Filter'],
};

#sniper_snp_file is variant_file, while tumor_snp_file is
#control_variant_file

sub help_brief {
    return "Gets intersection of SNPs from somatic sniper and maq";
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
    gmt filter-variants snv-intersect --sniper-snp-file=[pathname] --tumor-snp-file=[pathname] --output-file=[pathname]
EOS
}

sub help_detail {                           
    return <<EOS 
    Calls `gmt filter-variants intersect` on the tumor snp file from the last maq build and the snp file from somatic sniper.
    (Outputs lines from the somatic sniper file.)
EOS
}

sub execute {
    my ($self) = @_;
    $DB::single=1;

    if (($self->skip_if_output_present)&&(-s $self->output_file)) {
        $self->status_message("Skipping execution: Output is already present and skip_if_output_present is set to true");
        return 1;
    }

    my $tumor_snp_file = $self->control_variant_file;
    if ( ! Genome::Sys->validate_file_for_reading($tumor_snp_file) ) {
        die 'cant read from: ' . $tumor_snp_file;
    }

    my $sniper_snp_file = $self->variant_file();
    my $sniper_snp_file_sorted = Genome::Sys->create_temp_file_path("snipers.sorted");
    if ( ! Genome::Sys->validate_file_for_reading($sniper_snp_file) ) {
        die 'cant read from: ' . $sniper_snp_file;
    }
    
    # Should use command object->execute(), but would clutter with the grep required for imported bams.
    my $sort_cmd = "gmt snp sort $sniper_snp_file | grep -v \"^chr.*_random\" > $sniper_snp_file_sorted";
    my $result = Genome::Sys->shellcmd(
        cmd          => $sort_cmd,
        input_files  => [ $sniper_snp_file ],
        output_files => [ $sniper_snp_file_sorted ],
        skip_if_output_is_present => 0
    );

    # Should use command object->execute(), but would clutter with the grep required for imported bams.
    my $tumor_snp_file_sorted = Genome::Sys->create_temp_file_path("tumors.sorted");
    $sort_cmd = "gmt snp sort $tumor_snp_file | grep -v \"^chr.*_random\" > $tumor_snp_file_sorted";
    
    $result = Genome::Sys->shellcmd(
        cmd          => $sort_cmd,
        input_files  => [ $tumor_snp_file ],
        output_files => [ $tumor_snp_file_sorted ],
        skip_if_output_is_present => 0
    );

    my $output_file = $self->output_file;
    if ( ! Genome::Sys->validate_file_for_writing_overwrite($output_file) ) {
        die 'cant write to: ' . $output_file;
    }

    my $intersect_cmd = Genome::Model::Tools::Snp::IntersectChromPos->create(
        file1 => $sniper_snp_file_sorted,
        file2 => $tumor_snp_file_sorted,
        intersect_output => $output_file,
        f1_only_output => '/dev/null', #TODO IntersectChromPos claims this is optional, but dies without it
        f2_only_output => '/dev/null', #TODO IntersectChromPos claims this is optional, but dies without it
        ignore_sorting => 1,
    );

    unless($intersect_cmd) {
        die "Couldn't instantiate Genome::Model::Tools::Snp::IntersectChromPos";
    }

    $result = $intersect_cmd->execute;

    unless($result) {
        $self->error_message('Failed to execute Genome::Model::Tools::Snp::IntersectChromPos');
    }

    return $result;
}

1;
