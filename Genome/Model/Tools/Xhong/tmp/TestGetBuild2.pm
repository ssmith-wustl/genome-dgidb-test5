package Genome::Model::Tools::Xhong::TestGetBuild2;

#This is Nate's example script
use strict;
use warnings;
use Genome;

class Genome::Model::Tools::Xhong::TestGetBuild2 {
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

my $somatic_build_id = 123456
my $somatic_build = Genome::Model::Build->get($somatic_build_id);

method 1 (probably the preferred method):
#gives you the value of the sniper_snp_output workflow parameter
my $sniper_snp_output_file = $somatic_build->somatic_workflow_input("sniper_snp_output");
my $snp_filter_output_file = $somatic_build->somatic_workflow_input("snp_filteroutput");
my $filter_ceu_yri_output_file = $somatic_build->somatic_workflow_input("filter_ceu_yri_output");
my $adaptor_output_snp_file = $somatic_build->somatic_workflow_input("adaptor_output_snp");
my $dbsnp_output_file = $somatic_build->somatic_workflow_input("dbsnp_output");
my $loh_output_file = $somatic_build->somatic_workflow_input("loh_output_file");
my $loh_fail_output_file = $somatic_build->somatic_workflow_input("loh_fail_output_file");
my $annotate_output_snp = $somatic_build->somatic_workflow_input("annotate_output_snp");
my $ucsc_output = $somatic_build->somatic_workflow_input("ucsc_output");
my $ucsc_unannotated_output = $somatic_build->somatic_workflow_input("ucsc_unannotated_output");
my $tier_1_snp_file = $somatic_build->somatic_workflow_input("tier_1_snp_file");
my $tier_2_snp_file = $somatic_build->somatic_workflow_input("tier_2_snp_file");
my $tier_3_snp_file = $somatic_build->somatic_workflow_input("tier_3_snp_file");
my $tier_4_snp_file = $somatic_build->somatic_workflow_input("tier_4_snp_rile");
my $tier_1_snp_high_confidence_file = $somatic_build->somatic_workflow_input("tier_1_snp_high_confidence_file");
my $tier_2_snp_high_confidence_file = $somatic_build->somatic_workflow_input("tier_2_snp_high_confidence_file");
my $tier_3_snp_high_confidence_file = $somatic_build->somatic_workflow_input("tier_3_snp_high_confidence_file");
my $tier_4_snp_high_confidence_file = $somatic_build->somatic_workflow_input("tier_4_snp_high_confidence_file");

qx(wc -l $tier_1_high_confidence_file);
#my $ = $somatic_build->somatic_workflow_input("");
#my $ = $somatic_build->somatic_workflow_input("");


method 2:
# gives you a hashref with all available workflow inputs
#my $workflow_inputs = $somatic_build->somatic_workflow_inputs;
#my $sniper_snp_output_file = $workflow_input->{sniper_snp_output};
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
    my $somatic_build = $self->somatic_build_id;
    my $tumor_build = $self->tumor_build_id;
    my $normal_build = $self->normal_build_id;

    print qq($somatic build\n);

    my $gender = $self->gender;

# Get the data diretory for te somatic build


# Get the normal and tumor alignment build    
    my $tumor_build_obj = Genome::Model::Build::Somatic->tumor_build;
    my $normal_build_obj = Genome::Model::Build::Somatic->normal_build;
    print "$tumor_build_obj\n";
    print "$normal_build_obj\n";

    my $snps_all_sequences_file = $tumor_build_obj->_snv_file_unfiltered;
    my $filtered_indelpe_snps_file = $tumor_build_obj->filtered_snp_file;

# Get the somatic data file 
# Gabe will work on the methods to added in G::M::B::Somatic to get following files. Hopefullly it will be done by this Friday.
	
    my $dbsnp_output_out_file;
    my $loh_output_file_out_file;
    my $ucsc_out_put_out_file;
    my $tire1_file; 
    my $tire1_highconfidence_file; 
    my $tire1_lowconfidence_file;

    print "snps_all: $snps_all_sequences_file\n";
    print "filtered: $filtered_indelpe_snps_file\n";
}











