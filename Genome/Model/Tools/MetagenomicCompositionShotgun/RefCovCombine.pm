package Genome::Model::Tools::MetagenomicCompositionShotgun::RefCovCombine;

use strict;
use warnings;
use Genome;
use IO::File;

class Genome::Model::Tools::MetagenomicCompositionShotgun::RefCovCombine{
    is => ['Command'],
    has =>[
        refcov_output_file => {
            is => 'Text',
            doc => 'output from refcov to be organized by species',
        },
        taxonomy_file => {
            is => 'Text',
            doc => 'taxonomy file linking reference ids to species names',
        },
        viral_headers_file => {
            is => 'Text',
            doc => 'viral header file linking reference ids to descriptions',
        },
        reference_counts_file => {
            is => 'Text',
            doc => 'File containing reference names and read counts'
        },
        output => {
            is => 'Text',
            doc => 'output file',
        },
    ]
};

sub execute{
    my $self = shift;
    $DB::single = 1;
    my $input   =IO::File->new($self->refcov_output_file);
    my $db      =IO::File->new($self->taxonomy_file);
    my $viral_db=IO::File->new($self->viral_headers_file);
    my $rc      =IO::File->new($self->reference_counts_file);
    my $output  =IO::File->new("> ".$self->output);

    my $data;
    my %print_hash;
    my %header_hash;
    my $ref_data;

    while (my $line = $rc->getline) {
        chomp $line;
        next if ($line =~ /^Reference/);
        my @array=split(/\t/,$line);
        my $ref = $array[0];
        $ref = 'VIRL' if $ref =~/VIRL/;
        if ($ref eq 'VIRL'){
            $ref_data->{$ref}->{reads}+=$array[1];
        }else{
            $ref_data->{$ref}->{reads}=$array[1];
            $ref_data->{$ref}->{species}=$array[2];
            $ref_data->{$ref}->{phyla}=$array[3];
            $ref_data->{$ref}->{hmp}=$array[4];
        }
    }
    $rc->close;

    while (my $line = $db->getline)
    {
        chomp $line;
        my ($ref, $species) = split(/\t/,$line);
        my ($gi) = split(/\|/, $ref);
        ($gi) = $gi =~ /([^>]+)/;
        $header_hash{$gi}=$species;
    }
    $db->close;

    while (my $line = $viral_db->getline)
    {
        chomp $line;
        my ($gi, @species) = split(/\s+/,$line);
        my $species = "@species";
        $gi = "VIRL_$gi";
        $header_hash{$gi}=$species;
    }
    $viral_db->close;

    while(my $line = $input->getline)
    {
        chomp $line;
        my (@array)=split(/\t/,$line);
        my ($ref)  =split(/\|/, $array[0]);

        my $species = $header_hash{$ref};

        #Assuming that average coverage is calculated over the whole reference instead of just the covered reference. 
        my $cov=$array[2]*$array[5];#2 is total ref bases 5 is avg coverage

        #Refcov fields
        $data->{$ref}->{cov}+=$cov;
        $data->{$ref}->{tot_bp}+=$array[2];	    	
        $data->{$ref}->{cov_bp}+=$array[3];
        $data->{$ref}->{missing_bp}+=$array[4];
    }
    $input->close;

    print $output "Reference Name\tPhyla\tHMP flag\tAvg coverage\tPercent Covered\tTotal reference bases\tBases not covered\t#Reads\n";
    #foreach my $s (keys%{$data}){
    foreach my $s (sort {$a cmp $b} keys%{$data}){
        my $desc=$header_hash{$s};
        $desc ||= $s;
        next if $desc =~/^gi$/;
        my $phy;
        my $hmp;
        my $reads;
        if ( $ref_data->{$s}->{reads}){
            $phy=$ref_data->{$s}->{phyla};
            $hmp=$ref_data->{$s}->{hmp};
            $reads=$ref_data->{$s}->{reads};
        }
        $phy ||= '-';
        $hmp ||= 'N';
        $reads ||= 0;

        my $new_avg_cov=$data->{$s}->{cov}/$data->{$s}->{tot_bp};
        my $new_avg_breadth=$data->{$s}->{cov_bp}*100/$data->{$s}->{tot_bp};
        my $total_bp = $data->{$s}->{tot_bp};
        my $missing_bp = $data->{$s}->{missing_bp};
        print $output "$desc\t$phy\t$hmp\t$new_avg_cov\t$new_avg_breadth\t$total_bp\t$missing_bp\t$reads\n";
    }

    return 1;
}

1;
