package Genome::Model::Tools::Validation::BuildRemappingContigs;

use strict;
use warnings;

use Genome;
use Command;
use Genome::Utility::FileSystem;    #for file parsing etc
use POSIX; #for rounding

class Genome::Model::Tools::Validation::BuildRemappingContigs {
    is => 'Command',
    has => [
        tumor_assembly_breakpoints_file => {
            type => 'String',
            is_optional => 0,
            doc => 'The file of normal breakpoints picked by assembly in fasta format',
        },
        normal_assembly_breakpoints_file => {
            type => 'String',
            is_optional => 0,
            doc => 'The file of tumor breakpoints picked by assembly in fasta format',
        },
        reference_sequence => {
            type => 'String',
            is_optional => 0,
            default => '/gscmnt/839/info/medseq/reference_sequences/NCBI-human-build36/all_sequences.fa',
            doc => 'The samtools indexed fasta sequence of the reference the indels were predicted against. Defaults to GC standard Build36'
        },
        output_file => {
            type => 'String',
            is_optional => 0,
            doc => 'File to dump all of the contigs to',
        },
        contig_size => {
            type => 'Integer',
            is_optional => 0,
            default => 150, #force 100bp reads to align across the variant
            doc => 'The intended size of the contigs. If contigs overlap then they may be merged',
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
    ]
};


sub execute {
    my $self=shift;
    $DB::single = 1;


    #we will need to handle the following
    #Reading in of contigs
    #   * make sure to account for strand
    #normal assembly contigs - what will this mean if   1) they are the same
    #                                                   2) they are different
    #                                                   3) they don't exist or exist in a different order    
    #uniform contig size
    #detection and merging of overlapping contigs
    #then spit out contigs for matching
    #   * contig names should contain all info necessary to count the variant in question

    #check that we are on a 64bit system and can run samtools
    
    unless (POSIX::uname =~ /64/) {
        $self->error_message("This script requires a 64bit system");
        return;
    }

   
    #check that the reference exists before doing anything
    Genome::Utility::FileSystem->validate_file_for_reading($self->reference_sequence); #this should croak if the file is invalid

    #set the same executable path on the object
    $self->_samtools_exec(Genome::Model::Tools::Sam->path_for_samtools_version($self->samtools_version));

    #check files
    my $tumor_breakpoints = $self->tumor_assembly_breakpoints_file;
    my $normal_breakpoints = $self->normal_assembly_breakpoints_file;

    my %contigs;

    my $tumor_contigs = $self->read_in_breakpoints($tumor_breakpoints);
    unless($tumor_contigs) {
        $self->error_message("Unable to parse $tumor_breakpoints");
        return;
    }

    for my $contig (@$tumor_contigs) {
        if(exists($contigs{$contig->{pred_chr1}}{$contig->{pred_pos1}}{tumor})) {
            $self->error_message(sprintf "Multiple tumor variants assembled at %s:%d. Duplicates are assumed to be the same and are overwritten regardless of content.",$contig->{pred_chr1},$contig->{pred_pos1});
        }
        $self->resize_contig($contig); #this edits the contig in place to reach a desired size
        print STDERR "> resized contig\n",$contig->{'sequence'},"\n";
        $contigs{$contig->{pred_chr1}}{$contig->{pred_pos1}}{tumor} = $contig;
    }
    undef $tumor_contigs;



    my $normal_contigs = $self->read_in_breakpoints($normal_breakpoints);
    unless($normal_contigs) {
        $self->error_message("Unable to parse $normal_breakpoints");
        return;
    }

    for my $contig (@$normal_contigs) {
        if(exists($contigs{$contig->{pred_chr1}}{$contig->{pred_pos1}}{normal})) {
            $self->error_message(sprintf "Multiple normal contigs generated for variant predicted at %s:%d. Duplicates are assumed to be the same and are overwritten regardless of content.",$contig->{pred_chr1},$contig->{pred_pos1});
        }
        $contigs{$contig->{pred_chr1}}{$contig->{pred_pos1}}{normal} = $contig;
    }
    undef $normal_contigs;

    #now should have a single hash with all the contigs that were available. 
    #next, pad out/trim each contig and reverse complement the sequence if necessary




        
    return 1;

}

sub read_in_breakpoints {
    my ($self, $breakpoint_file) = @_;
    my $fh = Genome::Utility::FileSystem->open_file_for_reading($breakpoint_file);
    if($fh) {
        my @contigs;
        my $current_contig = {};
        my $current_contig_sequence = "";
        while(my $line = $fh->getline) {
            chomp $line;
            if($line =~ /^>/) { #it's a header line
                #resolve last contig
                if(%$current_contig) {
                    $current_contig->{'sequence'} = $current_contig_sequence;
                    #adjust strand
                    if($current_contig->{'strand'} ne '+') {
                        print STDERR "> original contig\n$current_contig_sequence\n";
                        $current_contig->{'sequence'} =~ tr/ACGTacgt/TGCAtgca/;
                        $current_contig->{'sequence'} = reverse $current_contig->{'sequence'};
                        $current_contig->{'strand'} = '+';

                        #also need to swap the genomic coordinates
                        ($current_contig->{'contig_start'},$current_contig->{'contig_stop'}) = ($current_contig->{'contig_stop'},$current_contig->{'contig_start'});

                        #lastly need to adjust the position of the indel
                        #roughly this is: the length of the contig - (the old position - 1) equals the new position in the reversed contig. The last base of the indel is: contig_location + size - 1 if an insertion and contig_location - 1 if deletion
                        my $type_size_toggle_var = $current_contig->{'assem_type'} eq 'DEL' ? 0 : 1;
                        my $temp_var_location = $current_contig->{'contig_location_of_variant'};
                        $current_contig->{'contig_location_of_variant'} = $current_contig->{'length'} - $current_contig->{'microhomology_contig_endpoint'} + 1;
                        $current_contig->{'microhomology_contig_endpoint'} = $current_contig->{'length'} - $temp_var_location + 1;
                        print STDERR "> reverse complemented contig\n",$current_contig->{'sequence'},"\n";
                    }
                        
                    push @contigs, $current_contig;
                }
                $current_contig = $self->parse_breakpoint_contig_header($line);
                $current_contig_sequence = "";
            }
            else {
                $current_contig_sequence .= $line;
            }
        }
        return \@contigs;
    }
    else {
        #propagate to caller
        return;
    }
}

#this parses the header into a hash containing the relevant info
#contig "objects" should be better defined and there needs to be some sort of determination that the header is actually generating a valid object

sub parse_breakpoint_contig_header {
    my ($self, $header_line) = @_;
    my %contig;
    $header_line =~ s/^.//;    #remove the caret
    my @header_fields = split ",", $header_line;
    for my $field (@header_fields) {
        my ($tag,$entry) = $field =~ /(\w+):*(\S*)/;
        if($tag =~ /^ID/) {
            #this contains info about the original call
            @contig{ qw( pred_chr1 pred_pos1 pred_chr2 pred_pos2 pred_type pred_size pred_orientation) } = split /\./, $entry;
        }
        elsif($tag =~ /^Var/) {
            #this contains info about what the crossmatch parsing thing thought was the variant
            #remember that the reported coordinates include any microhomology
            #In the future Ken says variant supporting reads would be reads that overlap this region with at least N bases of overlap where N is the microhomology size
            @contig{ qw( assem_chr1 assem_pos1 assem_chr2 assem_pos2 assem_type assem_size assem_orientation) } = split /\./, $entry;
        }
        elsif($tag =~ /^Strand/) {
            #the strand of the contig. If minus then it needs to be reverse complemented
            $contig{'strand'} = $entry;
        }
        elsif($tag =~ /^Length/) {
            #the reported length of the contig sequence
            $contig{'length'} = $entry;
        }
        elsif($tag =~ /^Ins/) {
            #the microhomology of the breakpoint
            #eg 23-24 means 2 bp of microhomology in the contig itself. 
            #   200-- means no microhomology
            my ($start, $stop) = $entry =~ /(\d+)\-(\d*)/;
            if($stop) {
                #then there IS microhomology
                $contig{'microhomology_contig_endpoint'} = $stop;  #the last base of microhomology on the contig
            }
            else {
                #this is the first base of the variant
                #this will ONLY ever happen for deletions
                $contig{'microhomology_contig_endpoint'} = $start;
            }

            #set the location of the variant in the contig
            $contig{'contig_location_of_variant'} = $start;
        }
        elsif($tag =~ /ref_start_point/) {
            #this is the position of the contig on the reference
            #note that this might not correspond to the first base of the contig. For now we're going to include mismatching bases as insertions/mismatches
            $contig{'contig_start'} = $entry;
        }
        elsif($tag =~ /ref_end_point/) {
            #this is the end position of the contig on the reference
            #note that this might not correspond to the last base of the contig. For now we're going to include mismatching bases as insertions/mismatches
            $contig{'contig_stop'} = $entry;
        }
        else {
            #we'll ignore all other fields for now
        }    
    }
    return \%contig;
}

sub resize_contig {
    my ($self, $contig) = @_;

    my $desired_size = $self->contig_size;

    #the leftmost position of the variant should be available as well as the length. For contigs where the ratio of variant sequence to contig is high, this MAY be biased towards having variants extend into the rightmost flank so we will need to do the math and appropriately trim
    #calculations that will be needed for padding or trimming
    my $contig_length = $contig->{'length'};
    my $indel_size = $contig->{'assem_size'};
    my $type_size_toggle_var = $contig->{'assem_type'} eq 'DEL' ? 0 : 1;
    my $left_flank_size = $contig->{'contig_location_of_variant'} - 1; #the number of bases of the contig preceeding the variant
    my $right_flank_size = $contig_length - $contig->{'contig_location_of_variant'} - $indel_size * $type_size_toggle_var + 1; #the number of bases of the contig succeeding the variant
    
    my $chr = $contig->{'assem_chr1'};
    my $contig_start = $contig->{'contig_start'};
    my $contig_stop = $contig->{'contig_stop'};

    my $desired_left_flank_size = ceil(($desired_size - $indel_size * $type_size_toggle_var) / 2);   #round up to preferentially add to the left flank
    my $desired_right_flank_size = floor(($desired_size - $indel_size * $type_size_toggle_var) / 2); #round down to preferentially shorten at the right flank

    if($contig_length < $desired_size) {
        #pad up to the proper size using the reference sequence. We don't really know if this will work, but it should come close
        my $bases_to_add_to_left_flank = $desired_left_flank_size - $left_flank_size;
        my $bases_to_add_to_right_flank = $desired_right_flank_size - $right_flank_size;

        my $lstart = $contig_start - $bases_to_add_to_left_flank;
        my $lend = $contig_start - 1;
        my $additional_lseq = $self->fetch_flanking_sequence($chr,$lstart,$lend);
        unless(defined $additional_lseq) {
            $self->error_message("Unable to fetch additional sequence for padding the left flanking sequence");
            return;
        }

        my $rstart = $contig_stop + 1;
        my $rend = $contig_stop + $bases_to_add_to_right_flank;
        my $additional_rseq = $self->fetch_flanking_sequence($chr,$rstart,$rend);
        unless(defined $additional_rseq) {
            $self->error_message("Unable to fetch additional sequence for padding the right flanking sequence");
            return;
        }

        #otherwise, pad the contig
        $contig->{'sequence'} = join("",$additional_lseq, $contig->{'sequence'}, $additional_rseq);

        #TODO update coordinates to match new contig
    }
    elsif($contig_length > $desired_size) {
        #need to trim the contig
        my $bases_to_remove_from_left_flank = $left_flank_size - $desired_left_flank_size;
        my $bases_to_remove_from_right_flank = $right_flank_size - $desired_right_flank_size;
        #trim the existing contig
        substr($contig->{'sequence'},0,$bases_to_remove_from_left_flank,"");
        substr($contig->{'sequence'},-$bases_to_remove_from_right_flank, $bases_to_remove_from_right_flank,"");
        #TODO update coordinates to match new contig
    }
}

sub fetch_flanking_sequence {
    my ($self,$chr,$start,$stop) = @_;

    my $sam_executable_path = $self->_samtools_exec;
    my $refseq = $self->reference_sequence;
    my $cmd = "$sam_executable_path faidx $refseq $chr:$start-$stop";

    my ($header,@seq) = `$cmd`;
    unless(defined $header) {
        $self->error_message("Error fetching sequence for $chr:$start-$stop");
        return;
    }
    else {
        return join("",map { chomp; $_; } @seq); #this should change the sequence into a single string regardless of length
    }
}



1;

sub help_brief {
    "generates contigs from assembly results for remapping of reads"
}

sub help_detail {
    <<'HELP';
This commmand attempts to generate a reference sequence containing variant contigs appropriate for read remapping to determine validation status
HELP
}
