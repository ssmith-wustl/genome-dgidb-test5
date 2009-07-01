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
            is_optional => 0,
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
    my $blastfile = $project_dir."/bac_region_db.blast";
    my $out = Genome::Model::Tools::WuBlast::Parse->execute(blast_outfile => $blastfile);#, parse_outfile => $lbast_outfile.".report");
    my $ace_file = $pooled_bac_dir.'/consed/edit_dir/'.$self->ace_file_name;
    my $ao = GSC::IO::Assembly::Ace->new(input_file => $ace_file);
    my $aout = GSC::IO::Assembly::Ace->new(output_file => "pbtest.ace");
    my $temp = `pwd`;
    chomp $temp;
    $temp .= '/phd_dir';
    `mkdir -p $temp`;
    my $pout = Finishing::Assembly::Phd->new(input_directory => $temp);
    
    my $po;
    if(-d $phd_dir_or_ball)
    {
        #$po = Finishing::Assembly::Phd->new(input_directory => $phd_dir_or_ball);
    }
    elsif(-e $phd_dir_or_ball)
    {
        #$po = Finishing::Assembly::Phd->new(input_file => $phd_dir_or_ball);
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
        write_fasta_from_contig_names($ao,$po, $aout, $pout,\@contig_names);            
    }
    $aout->write_file("pbtest.ace");    
}

sub write_fasta_from_contig_names
{
    my ($ao, $po, $aout, $pout, $contig_names) = @_;

         
    foreach my $contig_name (@{$contig_names})
    {
    my $co = $ao->get_contig($contig_name);
    $aout->add_contig($co);
        #write_reads_to_fasta($ao, $po, $aout, $pout, $contig_name);
    }


}

sub write_reads_to_fasta
{
    my ($ao, $po, $aout, $pout, $contig_name) = @_;
    my %phd_names = get_phd_names($ao,$aout, $contig_name);
    
    foreach my $read_name (keys %phd_names)
    {
        my $phd = $po->get_phd($phd_names{$read_name});
        $pout->add_phd($phd);
    }
}


sub get_phd_names
{
    my ($ao, $aout, $contig_name) = @_;   
   
    my $co = $ao->get_contig($contig_name);
    $aout->add_contig($co);
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
