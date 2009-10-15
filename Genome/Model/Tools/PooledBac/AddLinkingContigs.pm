package Genome::Model::Tools::PooledBac::AddLinkingContigs;

use strict;
use warnings;

use Genome;
use Genome::Assembly::Pcap::Ace;
use Genome::Assembly::Pcap::Phd;
use Genome::Utility::FileSystem;

class Genome::Model::Tools::PooledBac::AddLinkingContigs {
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
    return $a->{_frac_identical}->{total} <=> $b->{_frac_identical}->{total};
}

sub comp_hit_lists
{
    my $c = $a->[0];
    my $d = $b->[0];
    return $c->{HSP_LENGTH} <=> $d->{HSP_LENGTH} if($c->{HSP_LENGTH} != $d->{HSP_LENGTH});
    return $c->{_frac_identical}->{total} <=> $d->{_frac_identical}->{total};
    
}

sub get_matching_contigs_list
{
    my ($self, $out) = @_;
    #top sorted list of all contigs meeting cutoffs
    #sort by length, then percent identity
    #print contig name, bac name, length of match, percent identity
    #QUERY_NAME, HIT_NAME, HSP_LENGTH, _frac_identical->total
    my %match_contigs_list;
    #group by contig name
    foreach my $result (@{$out})
    {
        my @keys =  ('QUERY_NAME','HIT_NAME','HSP_LENGTH','_frac_identical');
        my %hash;
        %hash = map { $_ => $result->{$_} } @keys; 
        push @{$match_contigs_list{$result->{QUERY_NAME}}}, \%hash;    
    }
    #for each contig name sort multiple hits by length, percent identity
    foreach my $key (keys %match_contigs_list)
    {
        @{$match_contigs_list{$key}} = sort comp_hits @{$match_contigs_list{$key}} if (@{$match_contigs_list{$key}} > 1);
    }
    #sort all contig group by length and percent identity of best matching hit for each contig
    my @list = sort comp_hit_lists values %match_contigs_list;
    return \@list;
}

sub get_matching_contig_names
{
    my ($self, $list) = @_;
    my @matching_contigs;
    foreach my $result (@{$list})
    {
        push @matching_contigs, $result->[0]{QUERY_NAME};    
    }
    return \@matching_contigs;
}

sub get_orphan_contig_names
{
    my($self,$all_contigs, $matching_contigs) = @_;
    my %orphan_list;
    %orphan_list = map { $_, 1; } @{$all_contigs};
    foreach my $match_contig (@{$matching_contigs})
    {
        if(exists $orphan_list{$match_contig})
        {
            delete $orphan_list{$match_contig};
        }
    }
    return [keys %orphan_list];
}

############################################################
sub execute { 
    my $self = shift;
    $DB::single = 1;
    print "Adding Linking Contigs...\n";
    my $pooled_bac_dir = $self->pooled_bac_dir;
    my $project_dir = $self->project_dir;
    my $phd_dir_or_ball = $self->phd_file_name_or_dir;
    $phd_dir_or_ball = $pooled_bac_dir.'/consed/phdball_dir/phd.ball.1' unless $phd_dir_or_ball;
    my $blastfile = $project_dir."/bac_region_db.blast";
    my $reports_dir = $project_dir."/reports/";
    my $orphan_dir = $project_dir."/orphan_project/";
    $self->error_message("Failed to create directory $reports_dir\n") and die unless Genome::Utility::FileSystem->create_directory($reports_dir);
    my $out = Genome::Model::Tools::WuBlast::Parse->execute(blast_outfile => $blastfile, parse_outfile => $reports_dir."blast_report");
    

    my $ace_file = $pooled_bac_dir.'/consed/edit_dir/'.$self->ace_file_name;
    my $ao = Genome::Assembly::Pcap::Ace->new(input_file => $ace_file, using_db => 1);
    $self->error_message("Failed to create ace object.\n") and die unless defined $ao;
    my $po;
    if(-d $phd_dir_or_ball)
    {
        $po = Genome::Assembly::Pcap::Phd->new(input_directory => $phd_dir_or_ball);
    }
    elsif(-e $phd_dir_or_ball)
    {
        $po = Genome::Assembly::Pcap::Phd->new(input_file => $phd_dir_or_ball,using_db => 1);
    }
    $self->error_message("Failed to create phd object.\n") and die unless defined $po;
    my $list = $self->get_matching_contigs_list($out->{result});$out=undef;
    my $all_contig_names = $ao->get_contig_names;
    my $matching_contig_names = $self->get_matching_contig_names($list);
    
    my $orphan_contig_names = $self->get_orphan_contig_names($all_contig_names, $matching_contig_names);
    $self->create_orphan_dir($ao, $po, $orphan_contig_names,  $orphan_dir);   
    $self->import_contigs_with_links($ao, $po, $list, $orphan_contig_names,  $orphan_dir);  
}

sub import_contigs_with_links
{
    my ($self, $ao, $po, $match_list, $orphan_list, $orphan_dir) = @_;
    my $project_dir = $self->project_dir;
    my $orphans_without_links = $orphan_dir."orphan_contigs_without_links.ace.1";
    my $list_of_contigs = $orphan_list;
    if(-e $orphans_without_links)
    {
        my $temp_ao= Genome::Assembly::Pcap::Ace->new(input_file => $orphans_without_links);
        $self->error_message("Failed to open orphan ace file $orphans_without_links") and die unless defined $temp_ao;
        $orphan_list = $temp_ao->get_contig_names;        
    }
    my %orphan_list = map { $_,1; } @{$orphan_list};
    
    my %match_list_hash = map { $_->[0]{QUERY_NAME} => $_  } @{$match_list};
    foreach my $orphan (@{$orphan_list})
    {
        #find links based on contig name to start
        my ($sc_num, $ct_num) = $orphan =~ /Contig(\d+)\.(\d+)/;
        next unless (defined $sc_num && defined $ct_num);        
        my $pre_ctg = "Contig$sc_num.".($ct_num -1);
        my $aft_ctg = "Contig$sc_num.".($ct_num+1);
        if(exists $match_list_hash{$pre_ctg} && 
           exists $match_list_hash{$aft_ctg} &&
           $match_list_hash{$pre_ctg}[0]{HIT_NAME} eq $match_list_hash{$aft_ctg}[0]{HIT_NAME})        
        {
            my $bac_name = $match_list_hash{$pre_ctg}[0]{HIT_NAME};
            delete $orphan_list{$orphan};
            my $bac_dir = $project_dir."/$bac_name/";
            my $fasta_fn = $bac_dir."pooledreads_link.fasta";
            my $qual_fn = $bac_dir."pooledreads_link.fasta.qual";
            my $old_dir = `pwd`;
            chdir($bac_dir);
            print "orphan name is ",$orphan,"\n";
            $self->write_fasta_from_contig_names($ao, $fasta_fn, $qual_fn, $po, [$orphan]);             
            chdir($old_dir);            
        }    
    }
    my $out_ao = Genome::Assembly::Pcap::Ace->new;
    $self->error_message("Failed to create ace object.") and die unless defined $out_ao;
    foreach my $orphan (keys %orphan_list)
    {
        $out_ao->add_contig($ao->get_contig($orphan));
    }
    $out_ao->write_file(output_file => $orphans_without_links);
}

sub create_orphan_dir
{
    my ($self, $ao, $po, $orphan_list, $orphan_dir) = @_;
    $self->error_message("Failed to create $orphan_dir") and die unless Genome::Utility::FileSystem->create_directory($orphan_dir);
    #`mkdir -p $orphan_dir`;
    my $ace_file_name = $orphan_dir."orphan_contigs.ace.1";
    my $orphan_ao = Genome::Assembly::Pcap::Ace->new;
    $self->error_message("Failed to create ace object") and die unless defined $orphan_ao;
    foreach my $contig_name (@$orphan_list)
    {
        my $contig = $ao->get_contig($contig_name);
        $orphan_ao->add_contig($contig);    
    }
    $orphan_ao->write_file(output_file=> $ace_file_name);   
    
}

sub write_fasta_from_contig_names
{
    my ($self, $ao, $fasta_fn, $qual_fn, $po, $contig_names) = @_;

    my $fasta_fh = IO::File->new(">>$fasta_fn");
    $self->error_message("File $fasta_fn failed to open for writing.") and die unless $fasta_fh;
    my $qual_fh = IO::File->new(">>$qual_fn");
    $self->error_message("File $qual_fn failed to open for writing.") and die unless $qual_fh;
         
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
