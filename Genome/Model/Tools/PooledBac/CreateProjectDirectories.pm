package Genome::Model::Tools::PooledBac::CreateProjectDirectories;

use strict;
use warnings;

use Genome;
use Genome::Assembly::Pcap::Ace;
use Genome::Assembly::Pcap::Phd;
use List::Util qw(max min);

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

sub comp_hits
{
    return $a->{HSP_LENGTH} <=> $b->{HSP_LENGTH} if($a->{HSP_LENGTH} != $b->{HSP_LENGTH});
    return ($a->{IDENTICAL}/$a->{HSP_LENGTH} )<=> ($b->{IDENTICAL}/$b->{HSP_LENGTH});
}

sub comp_hit_lists
{
    my $c = $a->[0];
    my $d = $b->[0];
    return $c->{HSP_LENGTH} <=> $d->{HSP_LENGTH} if($c->{HSP_LENGTH} != $d->{HSP_LENGTH});
    return ($c->{IDENTICAL}/$c->{HSP_LENGTH} )<=> ($d->{IDENTICAL}/$d->{HSP_LENGTH});
    
}

sub get_matching_contigs_list
{
    my ($self, $out) = @_;
    #top sorted list of all contigs meeting cutoffs
    #sort by length, then percent identity
    #print contig name, bac name, length of match, percent identity
    #QUERY_NAME, HIT_NAME, HSP_LENGTH, IDENTICAL
    my %match_contigs_list;
    #group by contig name
    foreach my $result (@{$out})
    {
        my @keys =  ('QUERY_NAME','HIT_NAME','HSP_LENGTH','IDENTICAL');
        my %hash;
        %hash = map { $_ => $result->{$_} } @keys; 
        push @{$match_contigs_list{$result->{QUERY_NAME}}}, \%hash;    
    }
    #for each contig name sort multiple hits by length, percent identity
    foreach my $key (keys %match_contigs_list)
    {
        @{$match_contigs_list{$key}} = reverse sort comp_hits @{$match_contigs_list{$key}} if (@{$match_contigs_list{$key}} > 1);
    }
    #sort all contig group by length and percent identity of best matching hit for each contig
    my @list = reverse sort comp_hit_lists values %match_contigs_list;
    return \@list;
}


############################################################
sub execute { 
    my $self = shift;
    print "Creating Project Directories...\n";
    $DB::single = 1;
    my $pooled_bac_dir = $self->pooled_bac_dir;
    my $project_dir = $self->project_dir;
    my $phd_dir_or_ball = $self->phd_file_name_or_dir;
    $phd_dir_or_ball = $pooled_bac_dir.'/consed/phdball_dir/phd.ball.1' unless $phd_dir_or_ball;
    my $blastfile = $project_dir."/bac_region_db.blast";
    $self->error_message("$blastfile does not exist") and die unless (-e $blastfile);
    my $out = Genome::Model::Tools::WuBlast::Parse->execute(blast_outfile => $blastfile);   
    $self->error_message("Failed to parse $blastfile") and die unless defined $out;

    my $ace_file = $pooled_bac_dir.'/consed/edit_dir/'.$self->ace_file_name;
    $self->error_message("Ace file $ace_file does not exist") and die unless (-e $ace_file);
    my $ao = Genome::Assembly::Pcap::Ace->new(input_file => $ace_file, using_db => 1);
    $self->error_message("Failed to open ace file") and die unless defined $ao;
    my $po;
    if(-d $phd_dir_or_ball)
    {
        $po = Genome::Assembly::Pcap::Phd->new(input_directory => $phd_dir_or_ball);
    }
    elsif(-e $phd_dir_or_ball)
    {
        $po = Genome::Assembly::Pcap::Phd->new(input_file => $phd_dir_or_ball,using_db => 1);
    }
    $self->error_message("Failed to open phd object") unless defined $po;
    
    my $list = $self->get_matching_contigs_list($out->{result});$out=undef;
    my %bac_contigs;
    foreach my $item (@{$list})
    {
        my $hit_name = $item->[0]{HIT_NAME};
        my $query_name = $item->[0]{QUERY_NAME}; 
        push @{$bac_contigs{$hit_name}},$query_name;
    }
    
    foreach my $hit_name (keys %bac_contigs)
    {
        my $bac_dir = $project_dir."/$hit_name/";
        my @contig_names = @{$bac_contigs{$hit_name}};
        $self->error_message("Error creating directory $bac_dir") and die unless Genome::Utility::FileSystem->create_directory($bac_dir);
        my $old_dir = `pwd`;
        chdir($bac_dir);
        $self->write_fasta_from_contig_names($ao,$bac_dir."/pooledreads.fasta",$bac_dir."/pooledreads.fasta.qual",$po, \@contig_names);    
        chdir($old_dir);
    }
}

sub write_fasta_from_contig_names
{
    my ($self, $ao, $fasta_fn, $qual_fn, $po, $contig_names) = @_;

    my $fasta_fh = IO::File->new(">$fasta_fn");
    $self->error_message("File $fasta_fn failed to open for writing.") and die unless defined $fasta_fh;
    my $qual_fh = IO::File->new(">$qual_fn");
    $self->error_message("File $qual_fn failed to open for writing.") and die unless defined $qual_fh;     
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
