package Genome::Model::Tools::PooledBac::CreateBacProjects;

use strict;
use warnings;

use Genome;
use Genome::Model::Tools::Pcap::Assemble;
use Bio::SeqIO;
use PP::LSF;
use Data::Dumper;
class Genome::Model::Tools::PooledBac::CreateBacProjects {
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

sub dump_sff_read_names
{
    my ($self, $input_fasta) = @_;
    my $input_fasta_fh = IO::File->new("$input_fasta");
    my $read_names_fh = IO::File->new(">read_names");
    #print `pwd`,"\n";
    #print $input_fasta,"\n";
    while(<$input_fasta_fh>) {
        next unless />/;
        chomp;
        last if /\.c1/;
        my ($name) = />(.+)/;
        print  $read_names_fh  "$name\n";
    } 
}
############################################################
sub execute { 
    my ($self) = @_;
    my $project_dir = $self->project_dir;
    $DB::single = 1;
    chdir($project_dir);
    my @sff_files = ('/gscmnt/232/finishing/projects/Fosmid_two_pooled_Combined/Fosmid_two_pooled70_combined_trim-1.0_090417.newb/Fosmid_two_pooled70_combined_Data/input_output_data/FSP3MSF01.sff',
                     '/gscmnt/232/finishing/projects/Fosmid_two_pooled_Combined/Fosmid_two_pooled70_combined_trim-1.0_090417.newb/Fosmid_two_pooled70_combined_Data/input_output_data/FSP3MSF02.sff');
    
    #('/gscmnt/sata601/production/96211313/R_2009_03_17_15_50_42_FLX03080333_adminrig_96211313/D_2009_03_18_04_10_38_blade9-2-6_fullProcessing/sff/FSP3MSF02.sff',
                     #        '/gscmnt/sata601/production/96211313/R_2009_03_17_15_50_42_FLX03080333_adminrig_96211313/D_2009_03_18_04_10_23_blade9-4-10_fullProcessing/sff/FSP3MSF01.sff');
    my $sff_string = join ' ',@sff_files;
    
    my $seqio = Bio::SeqIO->new(-format => 'fasta', -file => 'ref_seq.fasta');
    my @jobs;
    while (my $seq = $seqio->next_seq)
    {    
        my $name = $seq->display_id;
        my $date = `date +%m%d%y`;
        chomp $date;
        next unless ((-e "$project_dir/$name") && (-d "$project_dir/$name"));
        chdir($project_dir."/$name");
        next unless (-e 'core'||!(-e 'newbler_assembly/consed'));
        `/bin/rm core*` if -e 'core';
        print $project_dir."/$name","\n";
        
        $self->dump_sff_read_names("pooledreads.fasta");
        my $create_sff = "sfffile -o pooledreads.sff -i read_names $sff_string";
        my $run_newbler = "mapasm runAssembly -o newbler_assembly -consed -rip -cpu 7 -vt /gscmnt/233/analysis/sequence_analysis/databases/genomic_contaminant.db.081104.fna reference_reads.fasta pooledreads.sff";
        my $command_fh = IO::File->new(">command.sh");
        print $command_fh "$create_sff\n$run_newbler\n";
        my %job_params = (
            pp_type => 'lsf',
            q => 'bigmem',
            command => 'source ./command.sh',
            o => "newbler_bsub.log",
            M => 16000000,
            rusage => ['mem=16000'],
            select => ['type==LINUX64','mem>16000']
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
                else { print "Job failed\n"; $_ = undef;#print Dumper $_; print "\n"; die "Job failed.\n"
                }                    
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
