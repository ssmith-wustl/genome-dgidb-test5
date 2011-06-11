package Genome::Model::Tools::Music::Proximity;

use warnings;
use strict;
use IO::File;
use Genome;

our $VERSION = $Genome::Model::Tools::Music::VERSION;

class Genome::Model::Tools::Music::Proximity {
    is => 'Command::V2',                       
    has_input => [
        maf_file => {
            is => 'Text',
            doc => "List of mutations (MAF)",
        },
        reference_sequence => {
            is => 'Text',
            doc => "Path to reference sequence in FASTA format",
        },
        output_file => {
            is => 'Text',
            doc => "Output file for proximity report",
        },
        max_proximity => {
            is => 'Text',
            doc => "Maximum AA distance between 2 mutations [10]",
            default => 10,
            is_optional => 1,
        },
    ],
    doc => "Perform a proximity analysis on a list of mutations."                 
};

sub help_detail {
    return <<EOS
This module first calculates the amino acid position of each mutation in the MAF file within its respective transcript. Then, for each mutation, two values are calculated: 1) the number of other mutations on the same transcript within the proximity limit set by the max-proximity input parameter, and 2) the distance to the closest other mutation in this nearby set. Only mutations which have another mutation within close proximity are reported in the output-file. The output consists of the folowing columns:

    1. Gene 
    2. Transcipt
    3. AA_position
    4. Chr 
    5. Genomic_start 
    6. Genomic_stop 
    7. Ref
    8. Var
    9. Sample 
   10. #_Close_Mutations 
   11. AA_distance_to_closest_mutation

EOS
}

sub help_synopsis {
    return <<EOS 
 ... music proximity \\
        --maf-file myMAF.tsv \\
        --max-proximity 10 \\
        --reference-sequence "path_to_reference_sequence" \\
        --output-file myMAF.tsv.proximity_analysis
EOS
}

sub _doc_authors {
    return <<EOS
 Nathan D. Dees, Ph.D.
 Dan Koboldt, M.S.
EOS
}

sub execute {
    my $self = shift;

    #parse input arguments
    my $maf_file = $self->maf_file;
    my $reference_sequence = $self->reference_sequence;
    my $max_proximity = $self->max_proximity;
    my $outfile = $self->output_file;

    #argument checks
    unless (-s $maf_file) {
        $self->error_message("MAF file is not found.");
        return;
    }
    my $maf_fh = new IO::File $maf_file,"r";
    unless (defined $maf_fh) {
        $self->error_message("Couldn't open MAF file: $!");
        return;
    }
    my $out_fh = new IO::File $outfile,"w";
    unless (defined $out_fh) {
        $self->error_message("Couldn't open output file: $!");
        return;
    }

    #parse MAF header
    my $maf_header = $maf_fh->getline;
    while ($maf_header =~ /^#/) {
        $maf_header = $maf_fh->getline;
    }   
    my %maf_columns;
    if ($maf_header =~ /Chromosome/) {
        #header exists. determine columns containing gene name and sample name.
        my @header_fields = split /\t/,$maf_header;
        for (my $col_counter = 0; $col_counter <= $#header_fields; $col_counter++) {
            $maf_columns{$header_fields[$col_counter]} = $col_counter;
        }   
    }   
    else {
        $self->error_message("MAF does not seem to contain a header!");
        return;
    }

    #run a check on the MAF header fields
    my @required_headers = qw(Hugo_Symbol Tumor_Sample_Barcode Chromosome Start_position End_position Reference_Allele Tumor_Seq_Allele Variant_Type trv_type c_position amino_acid_change transcript_name);
    for my $header (@required_headers) {
        unless (scalar grep { /^$header/ } keys %maf_columns) {
            $self->error_message("MAF does not contain column with header equal to $header.");
            return;
        }
    }

    #a hash to store statuses, and a hash to store variants and AA positions
    my %status;
    my $status = \%status;
    my %aa_mutations;

    #load relevant data from MAF into hash
    while (my $line = $maf_fh->getline) {
        chomp $line;
        my @fields = split /\t/,$line;

        my $gene = $fields[$maf_columns{'Hugo_Symbol'}];
        my $sample = $fields[$maf_columns{'Tumor_Sample_Barcode'}];
        my $chr = $fields[$maf_columns{'Chromosome'}];
        my $start = $fields[$maf_columns{'Start_position'}];
        my $stop = $fields[$maf_columns{'End_position'}];
        my $ref_allele = $fields[$maf_columns{'Reference_Allele'}];
        my $var_allele = $fields[$maf_columns{'Tumor_Seq_Allele2'}];
        $var_allele = $fields[$maf_columns{'Tumor_Seq_Allele1'}] if ($var_allele eq $ref_allele);
        my $var_type = $fields[$maf_columns{'Variant_Type'}];
        my $trv_type = $fields[$maf_columns{'trv_type'}];
        my $c_position = $fields[$maf_columns{'c_position'}];
        my $aa_change = $fields[$maf_columns{'amino_acid_change'}];
        my $transcript = $fields[$maf_columns{'transcript_name'}];

        #create variant key
        my $variant_key = join("\t",$gene,$chr,$start,$stop,$ref_allele,$var_allele,$sample);

        #determine amino acid position and load into hash
        my @mutated_aa_positions;

        if($trv_type ne "silent" && $trv_type ne "rna" && $trv_type ne "intronic" && $trv_type ne "5_prime_flanking_region" && $trv_type ne "3_prime_flanking_region") 
        {
            @mutated_aa_positions = $self->get_amino_acid_pos($variant_key,$trv_type,$c_position,$aa_change,$status);
        }
        else 
        {
            $status{synonymous_mutations_skipped}++;
        }

        #record data in hash if mutated aa position found

        if (@mutated_aa_positions) {
            push @{$aa_mutations{$transcript}{$variant_key}{mut_AAs}}, @mutated_aa_positions;
        }

    }#end of reading MAF file
    $maf_fh->close;

    #evaluate proximity of mutated amino acids

    #for each transcript,
    for my $transcript (keys %aa_mutations) {

        #for each variant hitting that transcript
        for my $variant (keys %{$aa_mutations{$transcript}}) {

            #initialize the search
            my @affected_amino_acids = @{$aa_mutations{$transcript}{$variant}{mut_AAs}};
            my $mutations_within_proximity = 0; #variable for summing # of mutations within proximity
            my $min_proximity = $max_proximity + 1; #current minimum proximity

            #for each OTHER variant hitting the transcript
            for my $other_variant (keys %{$aa_mutations{$transcript}}) {

                #ignore the current mutation
                next if $variant eq $other_variant;

                #get affected amino acids from OTHER variant
                my @other_affected_amino_acids = @{$aa_mutations{$transcript}{$other_variant}{mut_AAs}};

                #compare distances between amino acids
                my $found_close_one = 0;
                for my $other_variant_aa (@other_affected_amino_acids) {
                    for my $variant_aa (@affected_amino_acids) {
                        my $distance = abs($other_variant_aa - $variant_aa);

                        #if distance is within range
                        if ($distance <= $max_proximity) {   
                            $found_close_one++;
                            $min_proximity = $distance if $distance < $min_proximity;
                        }

                    }
                }

                #note that this variant is within proximity if applicable
                $mutations_within_proximity++ if $found_close_one;

            }#end of analyzing this other variant

            #now, save results in hash if there are any
            if ($mutations_within_proximity) {
                $aa_mutations{$transcript}{$variant}{muts_within_range} = $mutations_within_proximity;
                $aa_mutations{$transcript}{$variant}{min_proximity} = $min_proximity;
            }
        }#end of comparing this variant to rest of variants
    }#end of investigating all variants

    #print header
    my $header = join("\t",qw[Mutations_Within_Proximity Nearest_Mutation Gene Transcript Affected_Amino_Acid(s) Chromosome Start Stop Ref_Allele Var_Allele Sample]);
    print $out_fh "$header\n";

    #print results
    for my $transcript (keys %aa_mutations) {
        for my $variant (keys %{$aa_mutations{$transcript}}) {
            if (exists $aa_mutations{$transcript}{$variant}{muts_within_range}) {

                my ($gene,$chr,$start,$stop,$ref_allele,$var_allele,$sample) = split /\t/,$variant;
                my $affected_amino_acids = join(",",sort @{$aa_mutations{$transcript}{$variant}{mut_AAs}});
                my $outline = join("\t",$aa_mutations{$transcript}{$variant}{muts_within_range},$aa_mutations{$transcript}{$variant}{min_proximity},$gene,$transcript,$affected_amino_acids,$chr,$start,$stop,$ref_allele,$var_allele,$sample);
                print $out_fh "$outline\n";
            }
        }
    }

    return(1);
}

################################################################################

=head2 get_amino_acid_pos

This subroutine deducts the amino acid position within the transcript using the c_position and amino_acid_position columns in the MAF.

=cut

################################################################################

sub get_amino_acid_pos {

    #parse arguments
    my $self = shift;
    my ($variant_key,$trv_type,$c_position,$aa_change,$status) = @_;

    #initialize variables
    my $tx_start = my $tx_stop = 0;
    my $aa_position_start = my $aa_position_stop = 0;
    my $inferred_aa_start = my $inferred_aa_stop = 0;
    my $aa_pos = my $inferred_aa_pos = 0;


    #amino acid position determination
    if($aa_change && $aa_change ne "NULL" && substr($aa_change, 0, 1) ne "e")
    {
        $aa_pos = $aa_change;
        $aa_pos =~ s/[^0-9]//g;
    }

    ## Parse out c_position if applicable ##

    if($c_position && $c_position ne "NULL")
    {
        ## If multiple results, parse both ##

        if($c_position =~ '_' && !($trv_type =~ 'splice'))
        {
            ($tx_start, $tx_stop) = split(/\_/, $c_position);
            $tx_start =~ s/[^0-9]//g;
            $tx_stop =~ s/[^0-9]//g;

            if($tx_stop < $tx_start)
            {
                $inferred_aa_start = $tx_stop / 3;
                $inferred_aa_start = sprintf("%d", $inferred_aa_start) + 1 if($tx_stop % 3);
                $inferred_aa_stop = $tx_start / 3;
                $inferred_aa_stop = sprintf("%d", $inferred_aa_stop) + 1 if($tx_start % 3);							
            }
            else
            {
                $inferred_aa_start = $tx_start / 3;
                $inferred_aa_start = sprintf("%d", $inferred_aa_start) + 1 if($tx_start % 3);
                $inferred_aa_stop = $tx_stop / 3;							
                $inferred_aa_stop = sprintf("%d", $inferred_aa_stop) + 1 if($tx_stop % 3);
            }

        }
        else
        {
            (my $tx_pos) = split(/[\+\-\_]/, $c_position);
            $tx_pos =~ s/[^0-9]//g;

            $tx_start = $tx_stop = $tx_pos;

            if($tx_pos)
            {
                $inferred_aa_pos = $tx_pos / 3;
                $inferred_aa_pos = sprintf("%d", $inferred_aa_pos) + 1 if($tx_pos % 3);
                $inferred_aa_start = $inferred_aa_stop = $inferred_aa_pos;
            }
        }

    }


    ## If we inferred aa start stop, proceed with it ##
    if($inferred_aa_start && $inferred_aa_stop)
    {
        $aa_position_start = $inferred_aa_start;
        $aa_position_stop = $inferred_aa_stop;
        $status->{aa_position_inferred}++;
    }

    ## Otherwise if we inferred aa position ##
    elsif($aa_pos)
    {
        $aa_position_start = $aa_pos;
        $aa_position_stop = $aa_pos;
        $status->{c_position_not_available}++;
    }

    ## Otherwise we were unable to infer the info ##
    else{
        $status->{aa_position_not_found}++;
        $self->status_message("Amino acid position not found for variant: $variant_key");
        return;
    }

    ## Proceed if we have aa_position_start and stop ##
    my %mutated_aa_positions;

    if($aa_position_start && $aa_position_stop)
    {
        for(my $this_aa_pos = $aa_position_start; $this_aa_pos <= $aa_position_stop; $this_aa_pos++)
        {
            $mutated_aa_positions{$this_aa_pos}++;
        }
    }

    my @mutated_aa_positions = keys %mutated_aa_positions;
    return @mutated_aa_positions;
}

1;
