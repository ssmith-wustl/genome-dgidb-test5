package Genome::Model::Tools::PooledBac::CreateProjectDirectories;

use strict;
use warnings;

use Genome;
use GSC::IO::Assembly::Ace;

class Genome::Model::Tools::PooledBac::CreateProjectDirectories {
    is => 'Command',
    has => 
    [        
        pooled_bac_dir =>
        {
            type => 'String',
            is_optional => 0,
            doc => "Pooled BAC Assembly Directory",    
        },
        ace_file_name =>
        {
            type => 'String',
            is_optional => 0,
            doc => "Ace file containing pooled bac contigs"
        },
        phd_file_name_or_dir =>
        {
            type => 'Sring',
            is_optional => 1,
            doc => "Phd file or dir containing read bases and quals"       
        },
        project_dir =>
        {
            type => 'String',
            is_optional => 0,
            doc => "output dir for separate pooled bac projects"        
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

############################################################
sub execute { 
    my $self = shift;
    $DB::single = 1;
    my $pooled_bac_dir = $self->pooled_bac_dir;
    my $project_dir = $self->project_dir;
    my $phd_dir_or_ball = $self->phd_file_name_or_dir;
    $phd_dir_or_ball = $pooled_bac_dir.'/consed/phdball_dir/phd.ball.1' unless $phd_dir_or_ball;
    my $blastfile = $project_dir."/bac_region_db.blast";
    my $out = Genome::Model::Tools::WuBlast::Parse->execute(blast_outfile => $blastfile);#, parse_outfile => $lbast_outfile.".report");
    my $ace_file = $pooled_bac_dir.'/consed/edit_dir/'.$self->ace_file_name;
    my $ao = GSC::IO::Assembly::Ace->new(input_file => $ace_file);
    my $po;
    if(-d $phd_dir_or_ball)
    {
        $po = Finishing::Assembly::Phd->new(input_directory => $phd_dir_or_ball);
    }
    elsif(-e $phd_dir_or_ball)
    {
        $po = Finishing::Assembly::Phd->new(input_file => $phd_dir_or_ball);
    }
    my %bac_contigs;
    foreach my $result (@{$out->{result}})
    {
        my $hit_name = $result->{HIT_NAME};
        my $query_name = $result->{QUERY_NAME};        
        $bac_contigs{$hit_name}->{$query_name} = 1;
    }

    foreach my $hit_name(keys %bac_contigs)
    {
        my $bac_dir = $project_dir."/$hit_name/";
        my @contig_names = keys %{$bac_contigs{$hit_name}};
        system("mkdir -p $bac_dir");
        my $old_dir = `pwd`;
        chdir($bac_dir);
        write_fasta_from_contig_names($ao,$bac_dir."/pooledreads.fasta",$bac_dir."/pooledreads.fasta.qual",$po, \@contig_names);    
        chdir($old_dir);
    }    
}

sub write_fasta_from_contig_names
{
    my ($ao, $fasta_fn, $qual_fn, $po, $contig_names) = @_;

    my $fasta_fh = IO::File->new(">$fasta_fn");
    my $qual_fh = IO::File->new(">$qual_fn");
         
    foreach my $contig_name (@{$contig_names})
    {
        write_reads_to_fasta($ao, $fasta_fh, $qual_fh, $po, $contig_name);
    }
    $fasta_fh->close;
    $qual_fh->close;

}

sub write_reads_to_fasta
{
    my ($ao, $fasta_fh, $qual_fh, $po, $contig_name) = @_;
    my %phd_names = get_phd_names($ao,$contig_name);
    
    foreach my $read_name (keys %phd_names)
    {
        my $phd = $po->get_phd($phd_names{$read_name});
        $fasta_fh->print(">$read_name\n");
        $qual_fh->print(">$read_name\n");
        $fasta_fh->print($phd->unpadded_base_string,"\n");
        $qual_fh->print(join ' ',@{$phd->unpadded_base_quality}, "\n");    
    }
}


sub get_phd_names
{
    my ($ao, $contig_name) = @_;   
   
    my $co = $ao->get_contig($contig_name);
    my $reads = $co->reads;
    #print $co->name,"\n";
    my %phd_names;
    foreach (values %{$reads})
    {
        $phd_names{$_->name}= $_->phd_file;
    }
    return %phd_names; 

}

1;
