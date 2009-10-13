package Genome::Model::Tools::PooledBac::AddOverlappingReads;

use strict;
use warnings;

use Genome;
use GSC::IO::Assembly::Ace::Reader;
use IO::File;
use Bio::SeqIO;
use Data::Dumper;
use Cwd;

class Genome::Model::Tools::PooledBac::AddOverlappingReads {
    is => 'Command',
    has => 
    [ 
        project_dir => 
        {
            type => 'String',
            is_optional => 0,
            doc => "Directory containing pooled BAC fasta",
        },            
    ]    
};

sub help_brief {
    "The third step creates overlapping fake reads from the original reference sequence"
}

sub help_synopsis { 
    return;
}
sub help_detail {
    return <<EOS 
    Creates fake reads from the reference sequence
EOS
}

############################################################
sub execute { 
    my $self = shift;
    print "Adding Overlapping Reads...\n";
    $DB::single = 1;
    my $project_dir = $self->project_dir;
    chdir($self->project_dir);
    
    my $seqio = Bio::SeqIO->new(-format => 'fasta', -file => 'ref_seq.fasta');
    $self->error_message("Failed to open fasta file ref_seq.fasta") unless defined $seqio;
    my $qualio = Bio::SeqIO->new(-format => 'qual', -file => 'ref_seq.fasta.qual');
    $self->error_message("Failed to open qual file ref_seq.fasta.qual") unless defined $qualio;
    my $old_dir = getcwd;
    while (my $seq = $seqio->next_seq)
    {
        my $bases = $seq->seq;
        my $qual = $qualio->next_seq->qual;
        
        my $name = $seq->display_id;
        chdir($name);
        my $base_frags = create_base_frags($bases,1000,800);
        my $qual_frags = create_qual_frags($qual,1000,800);
        
        my $fasta_fh  = IO::File->new(">reference_reads.fasta");
        $self->error_message("Failed to open file $project_dir/$name/reference_reads.fasta") unless defined $fasta_fh;
        my $qual_fh = IO::File->new(">reference_reads.fasta.qual");
        $self->error_message("Failed to open file $project_dir/$name/reference_reads.fasta.qual") unless defined $qual_fh;
        for(my $i = 0;$i<@{$base_frags};$i++)
        {
            my $base_frag = $base_frags->[$i];
            my $qual_frag = $qual_frags->[$i];
            $fasta_fh->print(">$name","_$i.c1\n");
            $fasta_fh->print($base_frag,"\n");

            $qual_fh->print(">$name","_$i.c1\n");
            $qual_fh->print(join (' ',@{$qual_frag}),"\n");        
        }
        $fasta_fh->close;
        $qual_fh->close;
        
        chdir($old_dir);
        
    }
    
    
        
    return 1;
}

sub create_base_frags
{
    my ($bases, $length, $overlap) = @_;
    my $t_length = length($bases);
    my @overlaps;
    my $temp_bases = $bases;
    while(length($temp_bases)>$length)
    {
        push @overlaps, substr($temp_bases, 0, $length);
        $temp_bases = substr($temp_bases, $length-$overlap,length($temp_bases)-($length-$overlap));    
    }
    push @overlaps, $temp_bases;
    
    return \@overlaps;

}

sub create_qual_frags
{
    my ($quals, $length, $overlap) = @_;
    my $t_length = @{$quals};
    my @overlaps;
    my @temp_quals = @{$quals};
    while(@temp_quals>$length)
    {
        push @overlaps, [@temp_quals[0..($length-1)]];
        splice(@temp_quals,0,$length-$overlap); 
    }
    push @overlaps, \@temp_quals;
    
    return \@overlaps;
}
1;
