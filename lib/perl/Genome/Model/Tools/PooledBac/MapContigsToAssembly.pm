package Genome::Model::Tools::PooledBac::MapContigsToAssembly;

use strict;
use warnings;

use Genome;
use Genome::Assembly::Pcap::Ace;
use Genome::Assembly::Pcap::Phd;
use List::Util qw(max min);

class Genome::Model::Tools::PooledBac::MapContigsToAssembly {
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
        },
        percent_overlap => 
        {
            type => 'String',
            is_optional => 1,
            doc => "this is the percent overlap, default is 50%",
        },
        percent_identity =>
        {
            type => 'String',
            is_optional => 1,
            doc => "this is the percent identity, default is 85%",
        },
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
    print "Finding Matching Contigs...\n";
    $DB::single = 1;
    my $pooled_bac_dir = $self->pooled_bac_dir;
    my $project_dir = $self->project_dir;
    my $blastfile = $project_dir."/bac_region_db.blast";
    $self->error_message("$blastfile does not exist") and die unless (-e $blastfile);
    my $out = Genome::Model::Tools::WuBlast::Parse->execute(blast_outfile => $blastfile);   
    $self->error_message("Failed to parse $blastfile") and die unless defined $out;
    my $percent_overlap = $self->percent_overlap || 50;
    my $percent_identity = $self->percent_identity || 85;

    my $ace_file = $pooled_bac_dir.'/consed/edit_dir/'.$self->ace_file_name;
    $self->error_message("Ace file $ace_file does not exist") and die unless (-e $ace_file);    

    my $ut = Genome::Model::Tools::PooledBac::Utils->create;
    $self->error_message("Genome::Model::Tools::PooledBac::Utils->create failed.\n") unless defined $ut;

    my $contig_map_file = $self->contig_map_file || "CONTIG_MAP";
    $contig_map_file = $project_dir.'/'.$contig_map_file;
    my $list = $ut->get_matching_contigs_list($out->{result});$out=undef;

    my %contig_map;
    my $contig_names = $ut->get_contig_names($ace_file);
    foreach my $contig (@{$contig_names})
    {
        $contig_map{$contig} = {maps_to => 'orphan_project', module => 'MapContigsToAssembly'};        
    }
    foreach my $item (@{$list})
    {
        my $bac_name = $item->[0]{HIT_NAME};
        my $contig_name = $item->[0]{QUERY_NAME}; 
        my $hsp_length = $item->[0]{HSP_LENGTH};
        my $contig_length = $item->[0]{QUERY_LENGTH};
        my $hsp_identical = $item->[0]{IDENTICAL};
        my $perc_identity = ($hsp_identical/$hsp_length)*100.00;
        my $perc_overlap = ($hsp_length/$contig_length)*100.00;
        if(($perc_identity >= $percent_identity) &&
           ($perc_overlap >= $percent_overlap))
        {
            $contig_map{$contig_name}->{maps_to} = $bac_name;
        }
        #else
        #{
        #    print "rejected $contig_name, with $contig_length, $hsp_identical, $hsp_length, $perc_identity, $perc_overlap\n";
        #}
    }
    $ut->write_contig_map(\%contig_map, $contig_map_file);
    return 1;

}



1;
