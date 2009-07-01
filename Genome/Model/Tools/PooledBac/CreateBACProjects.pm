package Genome::Model::Tools::PooledBac::CreateBACProjects;

use strict;
use warnings;

use Genome;
use Genome::Model::Tools::Pcap::Assemble;
use Bio::SeqIO;
use PP::LSF;
use Data::Dumper;
class Genome::Model::Tools::PooledBac::CreateBACProjects {
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
    #my $qualio = Bio::SeqIO->new(-format => 'qual', -file => 'out.fasta.qual');
    my @jobs;
    while (my $seq = $seqio->next_seq)
    {    
        my $name = $seq->display_id;
        my $date = `date +%m%d%y`;
        chomp $date;
        chdir($project_dir."/$name");
        
        #this brain damage is due to how Kyung sets up the data
        `mkdir -p $project_dir/$name/Pooled_Bac_Projects-1.0_$date.pcap/edit_dir`;
        `gzip *`;
        `/bin/cp -f *.gz Pooled_Bac_Projects-1.0_$date.pcap/edit_dir/.`;
        
#        `bsub gt pcap assemble --project_name 'Pooled_Bac_Projects' --disk_location=$project_dir/$name --parameter_setting='NORMAL' --assembly_version='1.0' --assembly_date=$date --existing_data_only='YES' --pcap_run_type='NORMAL'`;

#        my $obj = Genome::Model::Tools::Pcap::Assemble->create
#        (
#            project_name       => 'Pooled_Bac_Projects',
#            disk_location      => $project_dir."/$name",
#            parameter_setting  => 'RELAXED',
#            assembly_version   => '1.0',
#            assembly_date      => $date,
#            #read_prefixes      => 'PPBA',
#            existing_data_only  => 'YES',
#            pcap_run_type      => 'RAW_454',#'NORMAL'
#        );
#
#        $obj->execute_pcap;
        my $command = "bsub gt pcap assemble --project_name 'Pooled_Bac_Projects' --disk_location=$project_dir/$name --parameter_setting='RELAXED' --assembly_version='1.0' --assembly_date=$date --existing_data_only='YES' --pcap_run_type='RAW_454'";
        my %job_params = (
            pp_type => 'lsf',
            q => 'short',
            command => $command,
            o => "pcap_bsub.log",
        );
        my $job = PP::LSF->create(%job_params);
        $self->error_message("Can't create job: $!")
            and return unless $job;
        push @jobs, $job;            
        chdir($project_dir);
    }    
    foreach(@jobs)
    {
        $_->start;
    }
    print "Running jobs";
    while(1)
    {
        foreach(@jobs)
        {
            if(defined $_ && $_->has_ended){
                if($_->is_successful) {$_ = undef;}
                else { print Dumper $_; print "\n"; die "Job failed.\n"}                    
            }
        }
        foreach(@jobs)
        {
            if(defined $_) { goto SLEEP;}
        }
        last; #if we're here then we're done
SLEEP:  
        print ".";    
        sleep 30;
    }
    print "\nJobs finished\n";
    return 1;
}



1;
