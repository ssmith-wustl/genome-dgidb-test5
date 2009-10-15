package Genome::Model::Tools::PooledBac::GenerateReports;

use strict;
use warnings;

use Genome;
use Genome::Assembly::Pcap::Ace;
use Genome::Assembly::Pcap::Phd;
use List::Util qw(max min);
use Genome::Utility::FileSystem;

class Genome::Model::Tools::PooledBac::GenerateReports {
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
        @{$match_contigs_list{$key}} = reverse sort comp_hits @{$match_contigs_list{$key}} if (@{$match_contigs_list{$key}} > 1);
    }
    #sort all contig group by length and percent identity of best matching hit for each contig
    my @list = reverse sort comp_hit_lists values %match_contigs_list;
    return \@list;
}

sub print_matching_contigs_report
{
    my ($self, $list, $report_name) = @_;
    #print list
    my $fh = IO::File->new('>'.$report_name);
    $self->error_message("Failed to open $report_name for writing.") and die unless defined $fh;
    foreach my $result (@$list)
    {
        foreach my $res (@{$result})
        {
            $fh->print ($res->{QUERY_NAME}, ' ',$res->{HIT_NAME},' ',$res->{HSP_LENGTH},' ',$res->{_frac_identical}->{total},"\n");        
        }    
    }
}

sub print_multiple_hits_report
{
    my ($self, $list, $report_name) = @_;
    #print list
    my $fh = IO::File->new('>'.$report_name);
    $self->error_message("Failed to open $report_name for writing.")  and die unless defined $fh;
    foreach my $result (@$list)
    {
        next unless (@{$result} > 1);
        
        for(my $i=0;$i<@{$result};$i++)
        {
            my $res = $result->[$i];
            if($i==0)
            {
                $fh->print ($res->{QUERY_NAME});        
            }
            else
            {
                my $name = $res->{QUERY_NAME};
                $name =~ s/./ /g;
                $fh->print ($name);
            }
            $fh->print ("\t",$res->{HIT_NAME},' ',$res->{HSP_LENGTH},' ',$res->{_frac_identical}->{total},"\n");
        }    
    }
}

sub print_close_match_report
{
    my ($self, $list, $report_name) = @_;
    #print list
    my $l_pcutoff = 0.05;#length percent difference cutoff, if there is a 5% or less diff in length
    my $m_pcutoff = 0.05;#matching percent difference cutoff, if there is a 5% or less diff in identitiy
    my $fh = IO::File->new('>'.$report_name);
    $self->error_message("Failed to open $report_name for writing.")  and die unless defined $fh;
    foreach my $result (@$list)
    {
        next unless (@{$result} > 1);
        my $res0 = $result->[0];
        my $res1 = $result->[1];
        my $max_length = max($res0->{HSP_LENGTH},$res1->{HSP_LENGTH});
        my $l_pdiff = abs (($res0->{HSP_LENGTH}-$res1->{HSP_LENGTH})/$max_length);
        my $pid0 = $res0->{_frac_identical}->{total};
        my $pid1 = $res1->{_frac_identical}->{total};
        my $max_id = max($pid0,$pid1);
        my $m_pdiff = abs(($pid0-$pid1)/$max_id);
        next unless (($l_pdiff < $l_pcutoff) && ($m_pdiff < $m_pcutoff));
        for(my $i=0;$i<@{$result};$i++)
        {
            my $res = $result->[$i];
            if($i==0)
            {
                $fh->print ($res->{QUERY_NAME});        
            }
            else
            {
                my $name = $res->{QUERY_NAME};
                $name =~ s/./ /g;
                $fh->print ($name);
            }
            $fh->print ("\t",$res->{HIT_NAME},' ',$res->{HSP_LENGTH},' ',$res->{_frac_identical}->{total},"\n");
        }    
    }
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

sub print_orphan_contigs_report
{
    my ($self, $orphan_contigs, $report_name) = @_;
    my $fh = IO::File->new('>'.$report_name);
    $self->error_message("Failed to open $report_name for writing.")  and die unless defined $fh;
    foreach my $name (@{$orphan_contigs})
    {
        $fh->print ($name,"\n");
    } 
}


############################################################
sub execute { 
    my $self = shift;
    print "Generating Reports...\n";
    $DB::single = 1;
    my $pooled_bac_dir = $self->pooled_bac_dir;
    my $project_dir = $self->project_dir;
    my $phd_dir_or_ball = $self->phd_file_name_or_dir;
    $phd_dir_or_ball = $pooled_bac_dir.'/consed/phdball_dir/phd.ball.1' unless $phd_dir_or_ball;
    my $blastfile = $project_dir."/bac_region_db.blast";
    my $reports_dir = $project_dir."/reports/";
    $self->error_message("Failed to create directory $reports_dir")  and die unless Genome::Utility::FileSystem->create_directory($reports_dir);
    #`mkdir -p $reports_dir`;
    my $out = Genome::Model::Tools::WuBlast::Parse->execute(blast_outfile => $blastfile, parse_outfile => $reports_dir."blast_report");
   $self->error_message("Failed to parse $blastfile")  and die unless defined $out; 

    my $ace_file = $pooled_bac_dir.'/consed/edit_dir/'.$self->ace_file_name;
    $self->error_message("Ace file $ace_file does not exist")  and die unless (-e $ace_file);
    my $ao = Genome::Assembly::Pcap::Ace->new(input_file => $ace_file, using_db => 1);
    $self->error_message("Failed to open ace file")  and die unless defined $ao;
    my $po;
    if(-d $phd_dir_or_ball)
    {
        $po = Genome::Assembly::Pcap::Phd->new(input_directory => $phd_dir_or_ball);
    }
    elsif(-e $phd_dir_or_ball)
    {
        $po = Genome::Assembly::Pcap::Phd->new(input_file => $phd_dir_or_ball,using_db => 1);
    }
    $self->error_message("Failed to open phd object")  and die unless defined $po;
    my $list = $self->get_matching_contigs_list($out->{result});$out=undef;
    $self->print_matching_contigs_report($list, $reports_dir."matching_contigs");
    $self->print_close_match_report($list,$reports_dir."ambiguous_matching_contigs");
    $self->print_multiple_hits_report($list,$reports_dir."contigs_with_multiple_hits");
    my $all_contig_names = $ao->get_contig_names;
    my $matching_contig_names = $self->get_matching_contig_names($list);
    
    my $orphan_contig_names = $self->get_orphan_contig_names($all_contig_names, $matching_contig_names);
    $self->print_orphan_contigs_report($orphan_contig_names, $reports_dir."orphan_contigs");
    return 1;
}



1;
