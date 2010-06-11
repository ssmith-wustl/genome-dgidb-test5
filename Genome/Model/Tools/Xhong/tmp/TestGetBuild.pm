package Genome::Model::Tools::Xhong::TestGetBuild;

#This is Nate's example script
use strict;
use warnings;
use Genome;

class Genome::Model::Tools::Xhong::TestGetBuild {
    is => 'Command',
    has => [
    build_id => {
        type => 'String',
        is_optional => 0,
        doc => 'Build id of Model to calculate snp tree for.'
    },
    gender => {
        type => 'String',
        is_optional => 0,
        doc => 'Gender of the patient (used to determine if chr Y is a valid location for snps/indels.'
    },
    ]
};

sub help_brief {
    "This tool does line counts, etc., on a build to determine the snp flow chart from the number of all initial calls down to the tiered calls and high-confidence calls."
}

sub help_detail {
    return<<EOS
    This tool does line counts, etc., on a build to determine the snp flow chart from the number of all initial calls down to the tiered calls and high-confidence calls.
EOS
}

sub execute {
    my $self = shift;
    my $build = $self->build_id;
    print qq($build\n);

    my $gender = $self->gender;
#    my $build_obj = Genome::Model::Build->get(build_id => $build);

#    my $snps_all_sequences_file = $build_obj->_snv_file_unfiltered;
#    my $filtered_indelpe_snps_file = $build_obj->filtered_snp_file;

    my $build_model_obj = Genome::Model::Build::Somatic->model;
    my $normal_model_obj=$build_model_obj->normal_model;
    my $tumor_model_obj=$build_model_obj->tumor_model;

# get the data directory for the somatic build
    my $somatic_data_directory;
    my $tumor_data_directory = $tumor_model_obj->resolve_data_directory;
    my $norma_model_directory = $normal_model_obj->resolve_data_directory;

# Get the normal alignment build
    my $normal_alignment_build = $build_obj->normal_build;
    my $tumor_alignment_build = $build_obj->tumor_build;
	
    my $dbsnp_output_out_file;
    my $loh_output_file_out_file;
    my $ucsc_out_put_out_file;
    my $tire1_file; 
    my $tire1_highconfidence_file; 
    my $tire1_lowconfidence_file;

    print "snps_all: $snps_all_sequences_file\n";
    print "filtered: $filtered_indelpe_snps_file\n";
}











