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
    $self->error_message("Failed to open $input_fasta") unless defined $input_fasta_fh;
    my $read_names_fh = IO::File->new(">read_names");
    $self->error_message("Filed to open read_name for writing") unless defined $read_names_fh;
    while(<$input_fasta_fh>) {
        next unless />/;
        chomp;
        last if /\.c1/;
        my ($name) = />(.+)/;
        print  $read_names_fh  "$name\n";
    } 
}

sub get_3730_read_names
{
    my @lines = `sffinfo -s pooledreads.sff | grep '>'`; 
    my %sff_names;
    foreach (@lines) { 
        my ($name) =$_=~ />(\S+)\s+/;
        $sff_names{$name} = 1;
    }
    my @all_read_names = `cat read_names`;
    chomp @all_read_names;
    my @read_names_3730;
    foreach my $name (@all_read_names)
    {
        if(! exists $sff_names{$name})
        {
            push @read_names_3730, $name;
        }    
    }
    return @read_names_3730;    
}

sub add_3730_reads
{
    my ($self) = @_;
    my $fh = IO::File->new(">3730_reads.fasta");
    my $qfh = IO::File->new(">3730_reads.fasta.qual");
    my @read_names = $self->get_3730_read_names;
    my %read_names = map {$_, 1} @read_names;
    my $seqio = Bio::SeqIO->new(-format => 'fasta', -file => 'pooledreads.fasta');
    my $qualio = Bio::SeqIO->new(-format => 'qual', -file => 'pooledreads.fasta.qual');
    while(my $seq = $seqio->next_seq)
    {
        my $bases = $seq->seq;
        my $quals = $qualio->next_seq->qual;
        my $name = $seq->display_id;
        if(exists $read_names{$name})
        {
            $fh->print(">$name\n");
            $qfh->print(">$name\n");
            $fh->print($bases,"\n");
            $qfh->print(join(' ',@{$quals}),"\n");
        }
    }
    $qfh->close;
    $fh->close;
}

############################################################
sub execute { 
    my ($self) = @_;
    my $project_dir = $self->project_dir;
    $DB::single = 1;
    chdir($project_dir);
    #my @sff_files = ('/gscmnt/232/finishing/projects/Fosmid_two_pooled_Combined/Fosmid_two_pooled70_combined_trim-1.0_090417.newb/Fosmid_two_pooled70_combined_Data/input_output_data/FSP3MSF01.sff',
    #                 '/gscmnt/232/finishing/projects/Fosmid_two_pooled_Combined/Fosmid_two_pooled70_combined_trim-1.0_090417.newb/Fosmid_two_pooled70_combined_Data/input_output_data/FSP3MSF02.sff');
    my @sff_files = ('/gscmnt/274/finishing/projects/Human_pool_1_combined_3730_454-1.0_090516.newb/sff/FR3TRLO01.sff',
                            '/gscmnt/274/finishing/projects/Human_pool_1_combined_3730_454-1.0_090516.newb/sff/FR3TRLO02.sff',
                            '/gscmnt/274/finishing/projects/Human_pool_1_combined_3730_454-1.0_090516.newb/sff/FUJGK1Y01.sff',
                            '/gscmnt/274/finishing/projects/Human_pool_1_combined_3730_454-1.0_090516.newb/sff/FUJGK1Y02.sff');
    my $sff_string = join ' ',@sff_files;
    
    my $seqio = Bio::SeqIO->new(-format => 'fasta', -file => 'ref_seq.fasta');
    $self->error_message("Failed to open $project_dir/ref_seq.fasta") unless defined $seqio;
    my @jobs;
    while (my $seq = $seqio->next_seq)
    {    
        my $name = $seq->display_id;
        next unless ((-e "$project_dir/$name") && (-d "$project_dir/$name"));
        next unless (-e "$project_dir/$name/core"||!(-e "$project_dir/$name/newbler_assembly/consed"));
        
        chdir($project_dir."/$name");        
        `/bin/rm core*` if -e 'core';
        print $project_dir."/$name","\n";
        $self->dump_sff_read_names("pooledreads.fasta");
        `sfffile -o pooledreads.sff -i read_names $sff_string`;
        $self->add_3730_reads;
        my $run_newbler = "mapasm runAssembly -o newbler_assembly -consed -rip -cpu 7 -vt /gscmnt/233/analysis/sequence_analysis/databases/genomic_contaminant.db.081104.fna reference_reads.fasta 3730_reads.fasta pooledreads.sff";
        my $command_fh = IO::File->new(">command.sh");
        print $command_fh "$run_newbler\n";
        system ("chmod 755 ./command.sh");
        my %job_params = (
            pp_type => 'lsf',
            q => 'long',
            command => './command.sh',
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
                else { $self->warning_message( "Job failed"); $_ = undef;#print Dumper $_; print "\n"; die "Job failed.\n"
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
