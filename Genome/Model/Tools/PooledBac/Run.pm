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
        no_reference_sequence =>
        {
            type => 'Boolean',
            is_optional => 1,
            doc => "Use this option to determine whether fake reads generated from reference sequence are included in assemblies generated by create-bac-projects",
        },
        ref_qual_value =>
        {
            type => 'String',
            is_optional => 1,
            doc => "This is the quality value that is used when creating reference .qual files, the default is 37",        
        },
        percent_overlap => 
        {
            type => 'String',
            is_optional => 1,
            doc => "this is the percent overlap, default is 50%",
        },
        percent_identity =>
        {
            type => 'String',
            is_optional => 1,
            doc => "this is the percent identity, default is 85%",
        },
        blast_params =>
        {
            type => 'String',
            is_optional => 1,
            doc => "Use this option to override the default blast params, the default param string is:\n M=1 N=-3 R=3 Q=3 W=30 wordmask=seg lcmask hspsepsmax=1000 golmax=0 B=1 V=1 topcomboN=1 -errors -notes -warnings -cpus 4 2>/dev/null",        
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
#    unless (`uname -m` =~ /64/) {
#        $self->error_message('Pooled bac pipeline must be run from a 64-bit architecture');
#        return;
#    }
    my $project_dir = $self->project_dir;
    my $pooled_bac_dir = $self->pooled_bac_dir;
    my $ace_file_name = $self->ace_file_name || 'Pcap.454Contigs.ace.1';
    my $ref_seq_coords_file = $self->ref_seq_file;
    my $phd_ball = $self->phd_ball_name;
    my $sff_files = $self->sff_files;
    my $queue_type = $self->queue_type;
    my $retry_count = $self->retry_count;
    #my $contig_map = $self->contig_map_file;
    my $no_reference_sequence = $self->no_reference_sequence;
    my $ref_qual_value = $self->ref_qual_value;
    my $percent_overlap = $self->percent_overlap;
    my $percent_identity = $self->percent_identity;
    my $blast_params = $self->blast_params;
    
    $self->error_message("Error running run-blast")  and die unless
    Genome::Model::Tools::PooledBac::RunBlast->execute(ref_sequence=>$ref_seq_coords_file, ref_qual_value => $ref_qual_value, pooled_bac_dir=>$pooled_bac_dir,pooled_bac_ace_file => $ace_file_name, project_dir => $project_dir, blast_params => $blast_params);

    $self->error_message("Error running map-contigs-to-assembly")  and die unless
    Genome::Model::Tools::PooledBac::MapContigsToAssembly->execute(pooled_bac_dir=>$pooled_bac_dir,ace_file_name => $ace_file_name, project_dir => $project_dir, percent_overlap => $percent_overlap, percent_identity => $percent_identity);

    $self->error_message("Error running add-linking-contigs")  and die unless
    Genome::Model::Tools::PooledBac::AddLinkingContigs->execute( project_dir => $project_dir);

    $self->error_message("Error generating reports")  and die unless
    Genome::Model::Tools::PooledBac::GenerateReports->execute( project_dir => $project_dir);

    $self->error_message("Error creating project directories")  and die unless
    Genome::Model::Tools::PooledBac::CreateProjectDirectories->execute(pooled_bac_dir=>$pooled_bac_dir,ace_file_name => $ace_file_name,phd_file_name_or_dir => $phd_ball, project_dir => $project_dir);

    $self->error_message("Error running add-reference-reads")  and die unless
    Genome::Model::Tools::PooledBac::AddReferenceReads->execute(project_dir => $project_dir);

    $self->error_message("Error assembling bac projects")  and die unless
    Genome::Model::Tools::PooledBac::AssembleBacProjects->execute(project_dir => $project_dir, sff_files => $sff_files, queue_type => $queue_type, retry_count => $retry_count, no_reference_sequence => $no_reference_sequence);

    $self->error_message("Error generating post assembly reports")  and die unless
    Genome::Model::Tools::PooledBac::GeneratePostAssemblyReports->execute( project_dir => $project_dir);

#    $self->error_message("Error updating seqmgr") unless
#    Genome::Model::Tools::PooledBac::UpdateSeqMgr->execute(project_dir => $project_dir);
    return 1;
}



1;
