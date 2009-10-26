package Genome::Model::Tools::PooledBac::AssembleBacProjects;

use strict;
use warnings;

use Genome;
use Genome::Model::Tools::Pcap::Assemble;
use Bio::SeqIO;
use PP::LSF;
use Data::Dumper;
class Genome::Model::Tools::PooledBac::AssembleBacProjects {
    is => 'Command',
    has => 
    [        
        project_dir =>
        {
            type => 'String',
            is_optional => 0,
            doc => "output dir for separate pooled bac projects"        
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
        sff_files =>
        {
            type => 'String',
            is_optional => 1,
            doc => "This is the location of the pooled bac Sff Files",        
        },
        no_reference_sequence =>
        {
            type => 'Boolean',
            is_optional => 1,
            doc => "Use this option to determine whether fake reads generated from reference sequence are included in the assembly",
        },
        rerun => 
        {
            type => 'Boolean',
            is_optional => 1,
            doc => "This forces all of the newbler assemblies to be re-run from scratch, deleting any assemblies that have previously finished. This can be useful when changing options such as no-reference-sequence"        
        },
        #assembly_output_dir =>
        #{
        #    type => 'String',
        #    is_optional => 1,
        #    doc => "This is the output directory for each project's assembly.  It defaults to newbler_assembly."   
        #}
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
    $self->error_message("Failed to open $input_fasta") and die unless defined $input_fasta_fh;
    my $read_names_fh = IO::File->new(">read_names");
    $self->error_message("Filed to open read_name for writing") and die unless defined $read_names_fh;
    while(<$input_fasta_fh>) {
        next unless />/;
        chomp;
        last if /\.c1/;
        my ($name) = />(.+)/;
        print  $read_names_fh  "$name\n";
    } 
}

sub convert_454_reads_to_consed_reads
{
    my @dirs = `/bin/ls -aF -1`;
    chomp @dirs;
    @dirs = grep { /^H_\//; } @dirs;
    chop @dirs;#get rid of trailing /
    foreach (@dirs)
    {
        #print "fixing $_,\n";
        #print "Couldn't find $_/newbler_assembly, skipping...\n" and 
        next unless -d "$_/newbler_assembly";
        system "cat $_/newbler_assembly/consed/edit_dir/$_.ace.1 | perl -e 'foreach (<>) { s/_left/\.b1/g; s/_right/\.g1/g; print;}' > out";
        system "/bin/mv out $_/newbler_assembly/consed/edit_dir/$_.ace.1";
        system "cat $_/newbler_assembly/consed/phdball_dir/phd.ball.1 | perl -e 'foreach (<>) { s/_left/\.b1/g; s/_right/\.g1/g; print;}' > out";
        system "/bin/mv out $_/newbler_assembly/consed/phdball_dir/phd.ball.1";    
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
    $DB::single = 1;
    unless (`uname -m` =~ /64/) {
        $self->error_message('assemble-bac-projects must be run from a 64-bit architecture');
        return;
    }
    print "Creating Bac Projects...\n";
    my $project_dir = $self->project_dir;
    my $retry_count = $self->retry_count || 3;
    my $assembly_output_dir = 'newbler_assembly';#$self->assembly_output_dir || 'newbler_assembly';    

    chdir($project_dir);
    #my @sff_files = ('/gscmnt/232/finishing/projects/Fosmid_two_pooled_Combined/Fosmid_two_pooled70_combined_trim-1.0_090417.newb/Fosmid_two_pooled70_combined_Data/input_output_data/FSP3MSF01.sff',
    #                 '/gscmnt/232/finishing/projects/Fosmid_two_pooled_Combined/Fosmid_two_pooled70_combined_trim-1.0_090417.newb/Fosmid_two_pooled70_combined_Data/input_output_data/FSP3MSF02.sff');
    my $sff_string = $self->sff_files if(defined $self->sff_files && length $self->sff_files);
    $sff_string =~ tr/,/ / if (defined $sff_string);
    print "sff string is $sff_string\n" if defined $sff_string;

    my $seqio = Bio::SeqIO->new(-format => 'fasta', -file => 'ref_seq.fasta');
    $self->error_message("Failed to open $project_dir/ref_seq.fasta") and die unless defined $seqio;
    my @jobs;
    while (my $seq = $seqio->next_seq)
    {    
        my $name = $seq->display_id;
        `/bin/rm -rf $project_dir/$name/$assembly_output_dir` if($self->rerun && -d "$project_dir/$name/$assembly_output_dir");
        next unless ((-e "$project_dir/$name") && (-d "$project_dir/$name"));
        next unless (-e "$project_dir/$name/core"||!(-e "$project_dir/$name/$assembly_output_dir/consed"));
        
        chdir($project_dir."/$name");        
        `/bin/rm core*` if -e 'core';
        print "submitting job for clone ",$project_dir."$name","\n";
        my $run_newbler;
        if(defined $sff_string)
        {
            print "sff string is $sff_string\n";
            $self->dump_sff_read_names("pooledreads.fasta"); 
            `sfffile -o pooledreads.sff -i read_names $sff_string`;
            $self->add_3730_reads;
            $run_newbler = "mapasm runAssembly -o $assembly_output_dir -consed -rip -cpu 7 -vt /gscmnt/233/analysis/sequence_analysis/databases/genomic_contaminant.db.081104.fna 3730_reads.fasta pooledreads.sff";
        }
        else
        {
            $run_newbler = "mapasm runAssembly -o $assembly_output_dir -consed -rip -cpu 7 -vt /gscmnt/233/analysis/sequence_analysis/databases/genomic_contaminant.db.081104.fna pooledreads.fasta";
            $self->warning_message("No sff files are provided...\nAre you sure you want to run newbler without providing sff files?\n");
        }
        $run_newbler .= " reference_reads.fasta" unless($self->no_reference_sequence);
        my $command_fh = IO::File->new(">command.sh");
        $self->error_message("Failed to create file handle for $project_dir/$name/command.sh\n") and die unless defined $command_fh;
        print $command_fh "$run_newbler\n";
        print $command_fh "/bin/mv $project_dir/$name/$assembly_output_dir/consed/edit_dir/454Contigs.ace.1 $project_dir/$name/$assembly_output_dir/consed/edit_dir/$name.ace.1\n";
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
        my $job = {params => \%job_params, job => PP::LSF->create(%job_params), try => 0, dir => "$project_dir/$name"};
        $self->error_message("Can't create job: $!")
            and return unless $job->{job};
        push @jobs, $job;            
        chdir($project_dir);
    }
    foreach(@jobs)
    {
        $_->{job}->start;
    }
    print "Running jobs";
    while(1)
    {
        foreach my $job (@jobs)
        {
            if(defined $job->{job} && $job->{job}->has_ended){
                if($job->{job}->is_successful) {$job->{job} = undef;}
                else {                    
                    if($job->{try}<$retry_count)
                    {
                        chdir ($job->{dir});
                        $self->warning_message( "Job failed\n");
                        print "Restarting job\n";
                        print "Resubmitting command $job->{params}{command}\n";
                        $job->{try}++;
                        $job->{job} = PP::LSF->create(%{$job->{params}});
                        $self->error_message("Can't create job: $!")
                            and return unless $job->{job};

                        $job->{job}->start;
                        chdir($project_dir);
                    
                    }
                    else
                    {
                        print "Job failed after $retry_count tries\n";
                        print "Command for failed job is located at $job->{params}{command}\n";
                    }
                }                    
            }
        }
        foreach my $job (@jobs)
        {
            if(defined $job->{job}) { goto SLEEP;}
        }
        last; #if we're here then we're done
SLEEP:  
        print ".";    
        sleep 30;
    }
    chdir($project_dir);
    convert_454_reads_to_consed_reads();
    print "\nJobs finished\n";
    system "chmod 777 -R $project_dir";
    return 1;
}



1;
