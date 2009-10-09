package Genome::Model::Tools::PooledBac::Run;

use strict;
use warnings;

use Genome;
use Genome::Model::Tools::Pcap::Assemble;
use Bio::SeqIO;
use PP::LSF;
use Data::Dumper;
class Genome::Model::Tools::PooledBac::Run {
    is => 'Command',
    has => 
    [        
        project_dir =>
        {
            type => 'String',
            is_optional => 0,
            doc => "location of the finished pooled BAC projects"        
        },
        pooled_bac_dir =>
        {
            type => 'String',
            is_optional => 0,
            doc => "location of the input pooled BAC assembly"        
        },
        ref_seq_file =>
        {
            type => 'String',
            is_optional => 0,
            doc => "location of the reference sequence"        
        },
        ace_file_name =>
        {
            type => 'String',
            is_optional => 1,
            doc => "location of the finished pooled BAC projects"        
        },
        phd_ball_name =>
        {
            type => 'String',
            is_optional => 1,
            doc => "location of the finished pooled BAC projects"        
        },
         
    ]
};

sub help_brief {
    "Run Pooled BAC Pipeline"
}

sub help_synopsis { 
    return;
}
sub help_detail {
    return <<EOS 
    Assemble Pooled BAC Reads
EOS
}

############################################################
sub execute { 
    my ($self) = @_;
$DB::single =1;
    my $project_dir = $self->project_dir;
    my $pooled_bac_dir = $self->pooled_bac_dir;
    my $ace_file_name = $self->ace_file_name || 'Pcap.454Contigs.ace.1';
    my $ref_seq_coords_file = $self->ref_seq_file;
    my $phd_ball = $self->phd_ball_name;

    $self->error_message("Error running map-contigs-to-assembly") unless
    Genome::Model::Tools::PooledBac::MapContigsToAssembly->execute(ref_sequence=>$ref_seq_coords_file,pooled_bac_dir=>$pooled_bac_dir,pooled_bac_ace_file => $ace_file_name, project_dir => $project_dir);
    
    $self->error_message("Error creating project directories") unless
    Genome::Model::Tools::PooledBac::CreateProjectDirectories->execute(pooled_bac_dir=>$pooled_bac_dir,ace_file_name => $ace_file_name,phd_file_name_or_dir => $phd_ball, project_dir => $project_dir);

   $self->error_message("Error generating reports") unless
    Genome::Model::Tools::PooledBac::GenerateReports->execute(pooled_bac_dir=>$pooled_bac_dir,ace_file_name => $ace_file_name,phd_file_name_or_dir => $phd_ball, project_dir => $project_dir);

    $self->error_message("Error running add-linking-contigs") unless
    Genome::Model::Tools::PooledBac::AddLinkingContigs->execute(pooled_bac_dir=>$pooled_bac_dir,ace_file_name => $ace_file_name,phd_file_name_or_dir => $phd_ball, project_dir => $project_dir);

## change to add reference reads
    $self->error_message("Error running add-overlapping-reads") unless
    Genome::Model::Tools::PooledBac::AddOverlappingReads->execute(project_dir => $project_dir);

# change to assemble bac projects
    $self->error_message("Error assembling bac projects") unless
    Genome::Model::Tools::PooledBac::CreateBacProjects->execute(project_dir => $project_dir);

#    $self->error_message("Error updating seqmgr") unless
#    Genome::Model::Tools::PooledBac::UpdateSeqMgr->execute(project_dir => $project_dir);
    return 1;
}



1;
