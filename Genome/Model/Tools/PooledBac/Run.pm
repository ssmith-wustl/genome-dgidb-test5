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
        sff_files =>
        {
            type => 'String',
            is_optional => 1,
            doc => "location of sff_files used in the original 454 assembly",
        },
        queue_type =>        
        {
            type => 'String',
            is_optional => 1,
            doc => "can be either short, big_mem, or long, default is long",     
            valid_values => ['long','bigmem','short']   
        },
        retry_count =>
        {
            type => 'String',
            is_optional => 1,
            doc => "This is the number of retries for a failed job.  The default is 1.",        
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
    my $sff_files = $self->sff_files;
    my $queue_type = $self->queue_type;
    my $retry_count = $self->retry_count;

    $self->error_message("Error running map-contigs-to-assembly")  and die unless
    Genome::Model::Tools::PooledBac::MapContigsToAssembly->execute(ref_sequence=>$ref_seq_coords_file,pooled_bac_dir=>$pooled_bac_dir,pooled_bac_ace_file => $ace_file_name, project_dir => $project_dir);
    
    $self->error_message("Error creating project directories")  and die unless
    Genome::Model::Tools::PooledBac::CreateProjectDirectories->execute(pooled_bac_dir=>$pooled_bac_dir,ace_file_name => $ace_file_name,phd_file_name_or_dir => $phd_ball, project_dir => $project_dir);

   $self->error_message("Error generating reports")  and die unless
    Genome::Model::Tools::PooledBac::GenerateReports->execute(pooled_bac_dir=>$pooled_bac_dir,ace_file_name => $ace_file_name,phd_file_name_or_dir => $phd_ball, project_dir => $project_dir);

    $self->error_message("Error running add-linking-contigs")  and die unless
    Genome::Model::Tools::PooledBac::AddLinkingContigs->execute(pooled_bac_dir=>$pooled_bac_dir,ace_file_name => $ace_file_name,phd_file_name_or_dir => $phd_ball, project_dir => $project_dir);

## change to add reference reads
    $self->error_message("Error running add-overlapping-reads")  and die unless
    Genome::Model::Tools::PooledBac::AddOverlappingReads->execute(project_dir => $project_dir);

# change to assemble bac projects
    $self->error_message("Error assembling bac projects")  and die unless
    Genome::Model::Tools::PooledBac::CreateBacProjects->execute(project_dir => $project_dir, sff_files => $sff_files, queue_type => $queue_type, retry_count => $retry_count);

#    $self->error_message("Error updating seqmgr") unless
#    Genome::Model::Tools::PooledBac::UpdateSeqMgr->execute(project_dir => $project_dir);
    return 1;
}



1;
