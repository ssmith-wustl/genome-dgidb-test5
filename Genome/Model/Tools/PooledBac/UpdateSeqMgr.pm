package Genome::Model::Tools::PooledBac::UpdateSeqMgr;

use strict;
use warnings;

use Genome;
use Genome::Model::Tools::Pcap::Assemble;
use Bio::SeqIO;
use Data::Dumper;
use GSCApp;
class Genome::Model::Tools::PooledBac::UpdateSeqMgr {
    is => 'Command',
    has => 
    [        
        project_dir =>
        {
            type => 'String',
            is_optional => 0,
            doc => "output dir for separate pooled bac projects"        
        } 
    ]
};

sub help_brief {
    "Assemble Pooled BAC Reads"
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
    print "Updating Seqmgr Projects...\n";
    my $project_dir = $self->project_dir;
    $DB::single = 1;
    chdir($project_dir);
    my $seqio = Bio::SeqIO->new(-format => 'fasta', -file => 'ref_seq.fasta');
    $self->error_message("Erroring opening ref_seq_fasta") and die unless defined $seqio;
    App->init;
    while (my $seq = $seqio->next_seq)
    {    
        my $clone_name = $seq->display_id;
        my $p=GSC::Project->get(name => $clone_name);
        $self->error_message("Error retrieving project for $clone_name")  and die unless defined $p;
    
        unless ((-e "$project_dir/$clone_name") && (-d "$project_dir/$clone_name"))
        {
            $self->warning_message("Directory for $clone_name at $project_dir/$clone_name does not exist!");
            next;
        }
        chdir($project_dir."/$clone_name");
        next if (-e 'core'||!(-e 'edit_dir'));
        $p->set_project_status('pooled_bac_done'); 
        
        my $seqmgr_link = $p->seqmgr_link;
        print "Updating $clone_name...\n";
        Genome::Utility::FileSystem->create_directory("$seqmgr_link/edit_dir");
        foreach my $ace_file (glob('edit_dir/*'))
        {
            system "/bin/cp -rfP $ace_file $seqmgr_link/edit_dir/.";
        }
        Genome::Utility::FileSystem->create_directory("$seqmgr_link/phd_dir");
        foreach my $phd_file (glob('phd_dir/*'))
        {        
            system "/bin/cp -rfP $phd_file $seqmgr_link/phd_dir/.";
        }
        Genome::Utility::FileSystem->create_directory("$seqmgr_link/chromat_dir");
        foreach my $chromat_file (glob('chromat_dir/*'))
        {
            system "/bin/cp -rfP $chromat_file $seqmgr_link/chromat_dir/.";
        }
        Genome::Utility::FileSystem->create_directory("$seqmgr_link/phdball_dir");
        foreach my $phdball_file (glob('phdball_dir/*'))
        {
            system "/bin/cp -rfP $phdball_file $seqmgr_link/phdball_dir/.";
        }
        Genome::Utility::FileSystem->create_directory("$seqmgr_link/sff_dir");
        foreach my $sff_file (glob('sff_dir/*'))
        {
            system "/bin/cp -rfP $sff_file $seqmgr_link/sff_dir/.";
        }

        #print $project_dir."/$clone_name","\n";
        #print "project name is ",$p->name,"\n";
        #print $p->project_status,"\n";
        #print $seqmgr_link,"\n";        exit;
    }
    return 1;
}

1;
