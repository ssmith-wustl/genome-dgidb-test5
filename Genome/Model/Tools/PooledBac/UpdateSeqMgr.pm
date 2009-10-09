package Genome::Model::Tools::PooledBac::UpdateSeqMgr;

use strict;
use warnings;

use Genome;
use Genome::Model::Tools::Pcap::Assemble;
use Bio::SeqIO;
use PP::LSF;
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
    my $project_dir = $self->project_dir;
    $DB::single = 1;
    chdir($project_dir);
    my $seqio = Bio::SeqIO->new(-format => 'fasta', -file => 'ref_seq.fasta');
    $self->error_message("Erroring opening ref_seq_fasta") unless defined $seqio;
    App->init;
    while (my $seq = $seqio->next_seq)
    {    
        my $clone_name = $seq->display_id;
        my $p=GSC::Project->get(name => $clone_name);
        $self->error_message("Error retrieving project for $clone_name") unless defined $p;
    
        unless ((-e "$project_dir/$clone_name") && (-d "$project_dir/$clone_name"))
        {
            $self->warning_message("Directory for $clone_name at $project_dir/$clone_name does not exist!");
            next;
        }
        chdir($project_dir."/$clone_name");
        next if (-e 'core'||!(-e 'newbler_assembly/consed'));
        $p->set_project_status('pooled_bac_done'); 
        
        my $seqmgr_link = $p->seqmgr_link;
        system "/bin/cp -rf newbler_assembly/consed/edit_dir $seqmgr_link/$clone_name/.";
        system "/bin/cp -rf newbler_assembly/consed/phd_dir $seqmgr_link/$clone_name/.";
        system "/bin/cp -rf newbler_assembly/consed/chromat_dir $seqmgr_link/$clone_name/.";
        system "/bin/cp -rf newbler_assembly/consed/phdball_dir $seqmgr_link/$clone_name/.";

#        print $project_dir."/$clone_name","\n";
#        print "project name is",$p->name,"\n";
#        print $p->project_status,"\n";
#        print $seqmgr_link,"\n";        
    }
    return 1;
}

1;
