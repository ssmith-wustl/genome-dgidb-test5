package Genome::Model::Command::RunPooledBAC;

use strict;
use warnings;

use Genome;
use Genome::Model::Tools::Pcap::Assemble;
use Bio::SeqIO;
use PP::LSF;
use Data::Dumper;
class Genome::Model::Command::RunPooledBAC {
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

    Genome::Model::Tools::PooledBac::MapContigsToAssembly->execute(ref_sequence=>$ref_seq_coords_file,pooled_bac_dir=>$pooled_bac_dir,pooled_bac_ace_file => $ace_file_name, project_dir => $project_dir);
    Genome::Model::Tools::PooledBac::CreateProjectDirectories->execute(pooled_bac_dir=>$pooled_bac_dir,ace_file_name => $ace_file_name,phd_file_name_or_dir => $phd_ball, project_dir => $project_dir);
    Genome::Model::Tools::PooledBac::AddOverlappingReads->execute(project_dir => $project_dir);
    Genome::Model::Tools::PooledBac::CreateBACProjects->execute(project_dir => $project_dir);
    return 1;
}



1;
