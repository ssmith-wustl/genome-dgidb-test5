package Genome::Model::Tools::Validation::CountContigs;

use strict;
use warnings;

use Genome;
use Genome::Info::IUB;
use IO::File;
use POSIX;

class Genome::Model::Tools::Validation::CountContigs {
    is => 'Command',
    has => [
    contig_fasta_file => {
        type => 'String',
        is_optional => 0,
        doc => 'File of contigs from gmt validation build-remapping-contigs.',
        default => '',
    },
    bam_file => {
        type => 'String',
        is_optional => 0,
        doc => 'File from which to retrieve reads. Must be indexed.',
    },
    samtools_version => {
        type => 'String',
        is_optional => 1,
        default => 'r783',
        doc => "The gsc version string for an installed version of samtools. You probably don't want to change this.",
    },
    _samtools_exec => {
        type => 'String',
        is_optional => 1,
    },
    maximum_clipping_fraction => {
        type => "Float",
        default => 0.25,
        doc => 'Maximum percentage of the read that has been soft-clipped in order for it to be counted',
        is_optional => 0,
    },

    ]
};

sub execute {
    my $self=shift;
    $DB::single = 1;
    my $file = $self->contig_fasta_file;

    #TODO Add checks on the files and architecture
    unless (POSIX::uname =~ /64/) {
        $self->error_message("This script requires a 64-bit system to run samtools");
        return;
    }

    #set the samtools executable path on the object
    $self->_samtools_exec(Genome::Model::Tools::Sam->path_for_samtools_version($self->samtools_version));

    unless(-e $self->bam_file && !-z $self->bam_file) {
        $self->error_message($self->bam_file . " does not exist or is of zero size");
        return;
    }

    my $fh = IO::File->new($file, "r");
    unless($fh) {
        $self->error_message("Couldn't open $file: $!"); 
        return;
    }

    #spit out a header, cause that's a good idea
    print join("\t",qw( contig_id contigs_overlapping total_reads_crossing_ref_pos total_q1_reads_crossing_ref_pos total_q1_reads_spanning_ref_pos total_reads_crossing_contig_pos total_q1_reads_crossing_contig_pos total_q1_reads_spanning_contig_pos )), "\n"; 
    #scan through all the fasta headers and grab counts based on each predicted variant and denoted reference
    while(my $line = $fh->getline) {
        next unless $line =~ /^>/;
        chomp $line;
        my @fields = split /\s+/,$line; #this should break down the fields
        $fields[0] =~ s/^>//;   #remove the leading bracket
        my ($pchr, $pstart, $pstop, $ptype, $contig_source) = split("_",$fields[0]);
        my ($has_overlap) = $fields[1] =~ /Overlap:(\d+)/;
        my ($ref_count_chr, $ref_count_start, $ref_count_stop) = $fields[2] =~ /Ref:([^.]+)[.]([0-9]+)[.]([0-9]+)/;
        if($ref_count_start > $ref_count_stop) {
            $self->error_message("Reference coordinates to count make no sense. Swapping start and stop.");
            print STDERR $line,"\n";
            ($ref_count_start,$ref_count_stop) = ($ref_count_stop, $ref_count_start);
        }
        #print STDOUT "$ref_count_chr\t$ref_count_start\t$ref_count_stop\n";

        my $contig_name = $fields[0];
        my ($contig_count_start, $contig_count_stop) = $fields[3] =~ /Con:([0-9]+)[.]([0-9]+)/;

        if($contig_count_start > $contig_count_stop) {
            $self->error_message("Contig coordinates to count make no sense. Swapping start and stop.");
            print STDERR $line, "\n";
            ($contig_count_start,$contig_count_stop) = ($contig_count_stop, $contig_count_start);
        }

        my $ref_count = $self->_count_across_range($self->bam_file,$ref_count_chr, $ref_count_start, $ref_count_stop);
        my $contig_count = $self->_count_across_range($self->bam_file,$contig_name, $contig_count_start, $contig_count_stop);

        print join("\t",$fields[0],$has_overlap,@$ref_count{ qw( total_reads total_reads_above_q1 spanning_reads_q1 ) }, @$contig_count{ qw( total_reads total_reads_above_q1 spanning_reads_q1 ) }), "\n";
    }

    return 1;
}


1;

sub help_brief {
    "Scans a file of contigs, parses information about where they need to be counted and then spits out info."
}

sub help_detail {
    <<'HELP';
HELP
}


#This grabs the reads overlapping the positions and counts whether they span the region of interest
sub _count_across_range {
    my ($self, $alignment_file, $chr, $pos1, $pos2) = @_;

    my $samtools_exec = $self->_samtools_exec;
    unless(open(SAMTOOLS, "$samtools_exec view -F 0x404 $alignment_file $chr:$pos1-$pos2 |")) { #this requires that they be unique
        $self->error_message("Unable to open pipe to samtools view");
        return;
    }

    my %stats;
    $stats{total_reads_above_q1} = 0;
    $stats{total_reads} = 0;
    $stats{spanning_reads_q1} = 0;

    while( <SAMTOOLS> ) {
        chomp;
        my ($qname, $flag, $rname, $pos_read, $mapq, $cigar, $mrnm, $mpos, $isize, $seq, $qual, $RG, $MF, @rest_of_fields) = split /\t/;

        my (@bases_clipped) = $cigar =~ /(\d+)S/;   #assumes only one softclipped op in a row, generally true
        my $read_length = length($seq); #should work unless hard clipped
        my $total_clipped_bases = 0;
        for my $bases (@bases_clipped) {
            $total_clipped_bases += $bases;
        }
        next if( $total_clipped_bases / $read_length > $self->maximum_clipping_fraction);

        
        $stats{'total_reads'}+= 1;
        next if($mapq == 0); #only count q1 and above
        $stats{'total_reads_above_q1'}+= 1;


        my $spans_range = $self->_spans_range($pos1, $pos2, $pos_read, $cigar);

        #check that mate maps to the same chromosome
        #this will not work for NT chromosome names.
        my ($mate_chr, $read_chr);

        if($rname =~ /_/) {
            ($read_chr) = $rname =~ /^(\S+?)_/;
        }
        else {
            $read_chr = $rname;
        }
        if($mrnm =~ /_/) {
            ($mate_chr) = $mrnm =~ /^(\S+?)_/;
        }
        else {
            $mate_chr = $mrnm eq '=' ? $read_chr : $mrnm;
        }


        if($spans_range && $mate_chr eq $read_chr) {
            $stats{'spanning_reads_q1'}+=1;
        }
    }
    unless(close(SAMTOOLS)) {
        $self->error_message("Error running samtools");
        return;
    }
    else {
        return \%stats;
    }

}

    
sub _spans_range { 
    my $self = shift;
    my $pos1 = shift;
    my $pos2 = shift;
    my $read_pos = shift;
    my $cigar = shift;
    my $current_offset=0;
    my $current_pos=$read_pos;
    my @ops = $cigar =~ m/([0-9]+)([MIDNSHP])/g; 
    OP:
    while(my ($cigar_len, $cigar_op) =  splice @ops, 0, 2 ) {
        my $new_offset;
        my $last_pos=$current_pos;
        if($cigar_op eq 'M') {
            $current_pos+=$cigar_len;
            $current_offset+=$cigar_len;
        }
        elsif($cigar_op eq 'I') {
            $current_offset+=$cigar_len;
        }
        elsif($cigar_op eq 'D') {
            $current_pos+=$cigar_len;

        }
        elsif($cigar_op eq 'N') {
            #this is the same as a deletion for returning a base from the read
            $current_pos += $cigar_len;
        }
        elsif($cigar_op eq 'S') {
            #soft clipping means the bases are in the read, but the position (I think) of the read starts at the first unclipped base
            #Functionally this is like an insertion at the beginning of the read
            $current_offset+=$cigar_len;
        }
        elsif($cigar_op eq 'H') {
            #hard clipping means the bases are not in the read and the position of the read starts at the first unclipped base
            #Shouldn't do anything in this case, but ignore it
        }
        else {
            die("CIGAR operation $cigar_op currently unsupported by this module");
        }
        if($pos1 < $current_pos && $pos1 >= $last_pos && $pos2 < $current_pos && $pos2 >= $last_pos) {
            if($cigar_op eq 'M') {
                return 1;
            }
            else {
                return;
            }
        }
    }
    #position didn't cross the read
    return; 
}
