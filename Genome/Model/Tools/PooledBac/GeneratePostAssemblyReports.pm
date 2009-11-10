package Genome::Model::Tools::PooledBac::GeneratePostAssemblyReports;

use strict;
use warnings;

use Genome;
use Genome::Assembly::Pcap::Ace;
use Genome::Assembly::Pcap::Phd;
use Genome::Model::Tools::PooledBac::Utils;
use Genome::Utility::FileSystem;
use List::Util qw(max min);

class Genome::Model::Tools::PooledBac::GeneratePostAssemblyReports {
    is => 'Command',
    has => 
    [        
        project_dir =>
        {
            type => 'String',
            is_optional => 0,
            doc => "output dir for separate pooled bac projects"        
        },
        contig_map_file =>
        {
            type => 'String',
            is_optional => 1,
            doc => "this file contains a list of contigs and where they map to",
        }
    ]
};

sub help_brief {
    "Move Pooled BAC assembly into separate projects"
}   

sub help_synopsis { 
    return;
}
sub help_detail {
    return <<EOS 
    Move Pooled BAC Assembly into separate projects
EOS
}

sub print_assembly_size_report
{
    my ($self, $project_names, $report_name) = @_;
    my $fh = IO::File->new('>'.$report_name);
    $self->error_message("Failed to open $report_name for writing.")  and die unless defined $fh;
    foreach my $name (@{$project_names})
    {
        my $size = 0;        
        if (-e "$name/newbler_assembly/consed/edit_dir/$name.ace.1")
        {
            my $ao = Genome::Assembly::Pcap::Ace->new(input_file => "$name/newbler_assembly/consed/edit_dir/$name.ace.1", using_db => 1);
            my $contig_names = $ao->get_contig_names;
            
            foreach my $contig_name (@{$contig_names})
            {
                my $contig = $ao->get_contig($contig_name);
                my $length = length ($contig->unpadded_base_string);
                $size += $length;            
            }            
        }
        $fh->print ("$name $size\n");
    }
}

sub print_contig_size_report
{
    my ($self, $project_names, $report_name) = @_;
    my $fh = IO::File->new('>'.$report_name);
    $self->error_message("Failed to open $report_name for writing.")  and die unless defined $fh;
    foreach my $name (@{$project_names})
    {
        my $size = 0;
        $fh->print ("$name:\n");
        if (-e "$name/newbler_assembly/consed/edit_dir/$name.ace.1")
        {
            my $ao = Genome::Assembly::Pcap::Ace->new(input_file => "$name/newbler_assembly/consed/edit_dir/$name.ace.1", using_db => 1);
            my $contig_names = $ao->get_contig_names;
            
            foreach my $contig_name (@{$contig_names})
            {
                my $contig = $ao->get_contig($contig_name);
                my $size = length ($contig->unpadded_base_string);
                $fh->print("$contig_name $size\n");            
            }
        }
        else
        {
            $fh->print( "NO CONTIGS\n");
        }
        $fh->print("\n");        
    }
}

sub print_contigs_only_consensus_report
{
    my ($self, $project_names, $report_name) = @_;
    my $fh = IO::File->new('>'.$report_name);
    $self->error_message("Failed to open $report_name for writing.")  and die unless defined $fh;
    foreach my $name (@{$project_names})
    {
        my $size = 0;
        $fh->print ("$name:\n");
        if (-e "$name/newbler_assembly/consed/edit_dir/$name.ace.1")
        {
            my $ao = Genome::Assembly::Pcap::Ace->new(input_file=>"$name/newbler_assembly/consed/edit_dir/$name.ace.1", using_db => 1);
            my $contig_names = $ao->get_contig_names;
            foreach my $contig_name (@{$contig_names})
            {
                my $contig = $ao->get_contig($contig_name);
                my $read_hash = $contig->reads;
                my $consensus_only = 1;
                foreach my $read_name (keys %{$read_hash})
                {
                    unless($read_name =~ /.*\.c1$/)
                    {
                        $consensus_only = 0;
                        last;
                    }                
                }  
                if($consensus_only)
                {
                    $fh->print ($contig_name,"\n");
                }          
            }
            system "/bin/rm $name/newbler_assembly/consed/edit_dir/$name.ace.1.db" if -e "$name/newbler_assembly/consed/edit_dir/$name.ace.1.db";
        }
        else
        {
            $fh->print( "NO CONTIGS\n");
        }
        $fh->print("\n");        
    }
}

sub get_bac_names
{
    my ($self) = @_;
    my $fh = IO::File->new('ref_seq.fasta');
    $self->error_message("Failed to open ref_seq.fasta for reading.")  and die unless defined $fh;
    my @names;
    while (my $line = <$fh>)
    {
        chomp $line;
        my ($name) = $line =~ /^\>(.*)/;
        push @names,$name if defined $name;    
    }
    return \@names;
}


############################################################
sub execute { 
    my $self = shift;
    print "Generating Post Assembly Reports...\n";
    $DB::single = 1;
    my $project_dir = $self->project_dir;
    chdir($project_dir);
    my $reports_dir = $project_dir."/reports/";
    $self->error_message("Failed to create directory $reports_dir")  and die unless Genome::Utility::FileSystem->create_directory($reports_dir);
    
    my $ut = Genome::Model::Tools::PooledBac::Utils->create;
    $self->error_message("Genome::Model::Tools::PooledBac::Utils->create failed.\n") unless defined $ut;

    my $contig_map_file = $self->contig_map_file || "CONTIG_MAP";
    $contig_map_file = $project_dir.'/'.$contig_map_file;    
    my $contig_map = $ut->open_contig_map($contig_map_file);
    
    my $names = $self->get_bac_names;
    $self->print_assembly_size_report($names,$reports_dir."assembly_size_report");
    $self->print_contig_size_report($names, $reports_dir."contig_size_report");
    $self->print_contigs_only_consensus_report($names, $reports_dir."contigs_only_consensus");
    return 1;
}



1;
