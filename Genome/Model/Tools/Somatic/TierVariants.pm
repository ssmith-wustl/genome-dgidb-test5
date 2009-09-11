package Genome::Model::Tools::Somatic::TierVariants;

use warnings;
use strict;

use Genome;
use Carp;
use FileHandle;
use Data::Dumper;
use List::Util qw( max );
use Genome::Info::IUB;

class Genome::Model::Tools::Somatic::TierVariants{
    is => 'Command',
    has => [
        ucsc_file => {
            is  => 'String',
            is_input  => 1,
            is_optional => 1,
            doc => 'The output of the ucsc annotation',
        },
        transcript_annotation_file => {
            is  => 'String',
            is_input  => 1,
            doc => 'The output of transcript annotation',
        },
        variant_file => {
            is  => 'String',
            is_input  => 1,
            doc => 'The list of variants to be tiered',
        },
        only_tier_1 => {
            type => 'Boolean',
            default => 0,
            is_input => 1,
            is_optional => 1,
            doc=> 'If set to true (defaults to false), do only tier 1 annotation. This eliminates the need for a ucsc file.',
        },
        tier1_file => {
            is => 'String',
            doc => 'tier1 output file',
            is_input => 1,
            is_output => 1,
        },
        tier2_file => {
            is => 'String',
            doc => 'tier2 output file -- this must be set unless running only_tier_1',
            is_input => 1,
            is_output => 1,
            is_optional => 1,
        },
        tier3_file => {
            is => 'String',
            doc => 'tier3 output file -- this must be set unless running only_tier_1',
            is_input => 1,
            is_output => 1,
            is_optional => 1,
        },
        tier4_file => {
            is => 'String',
            doc => 'tier4 output file -- this must be set unless running only_tier_1',
            is_input => 1,
            is_output => 1,
            is_optional => 1,
        },
    ],
};

sub help_brief {
    "tiers variants",
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
genome-model tools tier-variants...    
EOS
}

sub help_detail {                           
    return <<EOS 
tiers variants 
EOS
}

sub execute {
    my $self = shift;
    $DB::single=1;

    my $ucsc_file = $self->ucsc_file;
    my $transcript_annotation_file = $self->transcript_annotation_file;
    my $variant_file = $self->variant_file;

    # Open filehandles of plenty
    my $trans_anno_fh = new FileHandle;
    $trans_anno_fh->open($transcript_annotation_file,"r") or croak "Couldn't open $transcript_annotation_file";

    # make sure we're either only running tier 1 or that tier 2-4 files have been provided
    unless ( ($self->only_tier_1) || ($self->tier2_file && $self->tier3_file && $self->tier4_file) ) {
        $self->error_message("Tier 2-4 filenames must be provided unless only_tier_1 is set");
        die;
    }

    my $ucsc_fh = new FileHandle;
    if (defined $ucsc_file and -e $ucsc_file) {
        $ucsc_fh->open($ucsc_file,"r") or croak "Couldn't open $ucsc_file";
    }

    my $variant_fh = new FileHandle;
    $variant_fh->open($variant_file,"r") or croak "Couldn't open $variant_file";

    my $tier1 = new FileHandle;
    $tier1->open($self->tier1_file,"w") or croak "Couldn't write tier1 file";

    my $tier2 = new FileHandle;
    my $tier3 = new FileHandle;
    my $tier4 = new FileHandle;

    unless ($self->only_tier_1) {
        $tier2->open($self->tier2_file,"w") or croak "Couldn't write tier2 file";
        $tier3->open($self->tier3_file,"w") or croak "Couldn't write tier3 file";
        $tier4->open($self->tier4_file,"w") or croak "Couldn't write tier4 file";
    }
    
    my %exonic_at;
    my %variant_at;
    
    while(my $line = $trans_anno_fh->getline) {
        chomp $line;
        my @columns = split "\t", $line;
        my ($chr, $start, $stop, $allele1, $allele2, $variation_type, $gene, $transcript, $species, $transcript_source, $transcript_version, $strand, $transcript_status, $type, $aa_string) = @columns;
        $type = lc($type);
        if(defined($type) && ($type eq 'silent' || $type eq 'splice_site_del' || $type eq 'splice_site_ins' || $type eq 'in_frame_del' || $type eq 'frame_shift_del' || $type eq 'rna' || $type eq 'frame_shift_ins' || $type eq 'in_frame_ins'|| $type eq 'missense'|| $type eq 'nonsense'|| $type eq 'nonstop'|| $type eq 'splice_site')) {
            $exonic_at{$chr}{$start}{$stop}{$allele1}{$allele2} = $type;
        }
    }

    while(my $line = $variant_fh->getline) {
        chomp $line;
        # DETERMINE TYPE HERE TODO
        my $type = $self->infer_variant_type_from_line ($line);

        if ($type =~ /del|ins/i) {
            my %indel1;
            my %indel2;
            my ($chr,
                $start_pos,
                $star, 
                $somatic_score,
            );
            ($chr,
                $start_pos,
                $star, 
                $somatic_score,
                $indel1{'sequence'},
                $indel2{'sequence'}, 
                $indel1{'length'},
                $indel2{'length'},
            ) = split /\s+/, $line; 
            my @indels;
            push(@indels, \%indel1);
            push(@indels, \%indel2);
            for my $indel(@indels) {

                if ($indel->{'sequence'} eq '*') { next; }
                my $hash;
                my $stop_pos;
                my $start;
                if($indel->{'length'} < 0) {
                    #it's a deletion!
                    $hash->{variation_type}='DEL';
                    $start= $start_pos+1;
                    $stop_pos = $start_pos + abs($indel->{'length'});
                    $hash->{reference}=$indel->{'sequence'};
                    $hash->{variant}=0;
                }
                else {
                    #it's an insertion
                    $hash->{variation_type}='INS';
                    $start=$start_pos;
                    $stop_pos = $start_pos+1;
                    $hash->{reference}=0;
                    $hash->{variant}=$indel->{'sequence'};

                }
                if(exists($exonic_at{$chr}{$start}{$stop_pos}{$hash->{reference}}{$hash->{variant}})) {
                    print $tier1 $line,"\n";
                    next;
                }
                $variant_at{$chr}{$start}{$stop_pos}{$hash->{reference}}{$hash->{variant}} = $line;
            }
        } elsif ($type =~ /snp/i) {
            my ($chr, $start, $reference, $genotype) = split /\t/, $line;
            $DB::single=1;
            my @variant_alleles = Genome::Info::IUB::variant_alleles_for_iub($reference, $genotype);
            my $stop = $start;
            my $assigned_position_to_tier = 0;
            foreach my $variant (@variant_alleles) {
                if(exists($exonic_at{$chr}{$start}{$stop}{$reference}{$variant})) {
                    print $tier1 $line, "\n";
                    $assigned_position_to_tier = 1;
                    last; #skip
                }
                $variant_at{$chr}{$start}{$stop}{$reference}{$variant} = $line;
            }
            if($assigned_position_to_tier) {
                foreach my $variant (@variant_alleles) {
                    delete $exonic_at{$chr}{$start}{$stop}{$reference}{$variant};
                }
            }
            
        } else {
            $self->error_message("Type $type not implemented");
            die;
        }
    }

    if ($self->only_tier_1) {
        $self->status_message("only_tier_1 flag is set. Skipping tiers 2-4. Exiting.");
        return 1;
    }

    unless (-e $ucsc_file) {
        $self->status_message("ucsc file $ucsc_file does not exist. Skipping tiers 2-4. Exiting.");
        return 1;
    }

    my %totals;
    while(my $line = $ucsc_fh->getline) {
        chomp $line;
        my @fields = split /\t/, $line;
        map { $_ ='' if($_ eq '-')} @fields;
        my ( $chr,$start,$stop,
            $decodeMarshfield, #recombination rates
            $repeatMasker,
            $selfChain,
            $cnpLocke,
            $cnpSebat2,
            $cnpSharp2,
            $cpgIslandExt,
            $delConrad2,
            $dgv,
            $eponine,
            $firstEF,
            $gad, #disease associations
            $genomicSuperDups,
            $microsat,
            $phastConsElements17way,
            $phastConsElements28way,
            $polyaDb,
            $polyaPredict,
            $simpleRepeat,
            $switchDbTss,
            $targetScanS,
            $tfbsConsSites,
            $vistaEnhancers,
            $wgEncodeGisChipPet,
            $wgEncodeGisChipPetHes3H3K4me3,
            $wgEncodeGisChipPetMycP493,
            $wgEncodeGisChipPetStat1Gif,
            $wgEncodeGisChipPetStat1NoGif,
            $cnpIafrate2,
            $cnpRedon,
            $cnpTuzun,
            $delHinds2,
            $delMccarroll,
            $encodeUViennaRnaz,
            $exaptedRepeats,
            $laminB1,
            $oreganno,
            $regPotential7X,
            $uppsalaChipH3acSignal,
            $uppsalaChipUsf1Signal,
            $uppsalaChipUsf2Signal,
            $wgEncodeUcsdNgTaf1Signal,
            $wgEncodeUcsdNgTaf1ValidH3K4me,
            $wgEncodeUcsdNgTaf1ValidH3ac,
            $wgEncodeUcsdNgTaf1ValidRnap,
            $wgEncodeUcsdNgTaf1ValidTaf,
            $knownGenes,
            $HUGO,) = @fields; 

        if(exists($variant_at{$chr}{$start}{$stop})) {
            #check selfChain and repeatMAsker to filter out crap that is unlikely to validate
            #if($selfChain && max(split /\s/, $selfChain) > 0 && $repeatMasker =~ /^(Simple_repeat|Satellite)/) {
            #    print $tier5 $variant_at{$chr}{$start}{$stop}, "\n";
            #}
            #Tier1 exonic genes were printed when the snp file was read in
            #
            #Tier2 Conserved Blocks
            if(($phastConsElements28way && $phastConsElements28way >= 500) || ($phastConsElements17way && $phastConsElements17way >= 500)) {
                for my $reference (keys %{$variant_at{$chr}{$start}{$stop}}) {
                    for my $variant(keys %{$variant_at{$chr}{$start}{$stop}{$reference}}) {
                        print $tier2 $variant_at{$chr}{$start}{$stop}{$reference}{$variant}, "\n";
                    }
                }
            }
            elsif($repeatMasker || $microsat || $simpleRepeat || $exaptedRepeats) {
                #Tier 5 repeats everything else!!!
                for my $reference (keys %{$variant_at{$chr}{$start}{$stop}}) {
                    for my $variant(keys %{$variant_at{$chr}{$start}{$stop}{$reference}}) {
                        print $tier4 $variant_at{$chr}{$start}{$stop}{$reference}{$variant}, "\n";
                    }
                }
            }
            elsif($targetScanS || $oreganno || $tfbsConsSites || $vistaEnhancers || $eponine || $firstEF 
                || $wgEncodeUcsdNgTaf1ValidTaf 
                #|| $wgEncodeGisChipPet 
                #|| $wgEncodeGisChipPetHes3H3K4me3 
                #|| $wgEncodeGisChipPetMycP493 
                #|| $wgEncodeGisChipPetStat1Gif 
                #|| $wgEncodeGisChipPetStat1NoGif 
                #|| $wgEncodeUcsdNgTaf1Signal 
                || $wgEncodeUcsdNgTaf1ValidRnap 
                || $wgEncodeUcsdNgTaf1ValidH3ac 
                || $wgEncodeUcsdNgTaf1ValidH3K4me 
                #|| $regPotential7X 
                    || $polyaPredict || $polyaDb || $switchDbTss 
                    #|| $uppsalaChipUsf2Signal || $uppsalaChipUsf1Signal || $uppsalaChipH3acSignal 
                    || $encodeUViennaRnaz || $laminB1 || $cpgIslandExt) {
                my %reg_hash;
                @reg_hash{('targetScanS','oreganno','tfbsConsSites','vistaEnhancers','eponine','firstEF','wgEncodeUcsdNgTaf1ValidTaf','wgEncodeGisChipPet','wgEncodeGisChipPetHes3H3K4me3','wgEncodeGisChipPetMycP493','wgEncodeGisChipPetStat1Gif','wgEncodeGisChipPetStat1NoGif','wgEncodeUcsdNgTaf1Signal','wgEncodeUcsdNgTaf1ValidRnap','wgEncodeUcsdNgTaf1ValidH3ac','wgEncodeUcsdNgTaf1ValidH3K4me','regPotential7X','polyaPredict','polyaDb','switchDbTss','uppsalaChipUsf2Signal','uppsalaChipUsf1Signal','uppsalaChipH3acSignal','encodeUViennaRnaz','laminB1','cpgIslandExt')} = ($targetScanS,$oreganno,$tfbsConsSites,$vistaEnhancers,$eponine,$firstEF,$wgEncodeUcsdNgTaf1ValidTaf,$wgEncodeGisChipPet,$wgEncodeGisChipPetHes3H3K4me3,$wgEncodeGisChipPetMycP493,$wgEncodeGisChipPetStat1Gif,$wgEncodeGisChipPetStat1NoGif,$wgEncodeUcsdNgTaf1Signal,$wgEncodeUcsdNgTaf1ValidRnap,$wgEncodeUcsdNgTaf1ValidH3ac,$wgEncodeUcsdNgTaf1ValidH3K4me,$regPotential7X,$polyaPredict,$polyaDb,$switchDbTss,$uppsalaChipUsf2Signal,$uppsalaChipUsf1Signal,$uppsalaChipH3acSignal,$encodeUViennaRnaz,$laminB1,$cpgIslandExt);
                foreach my $col (keys %reg_hash) {
                    if($reg_hash{$col}) {
                        $totals{$col} += 1;
                    }
                }
                #TIER3 Regulatory regions
                for my $reference (keys %{$variant_at{$chr}{$start}{$stop}}) {
                    for my $variant(keys %{$variant_at{$chr}{$start}{$stop}{$reference}}) {
                        print $tier2 $variant_at{$chr}{$start}{$stop}{$reference}{$variant}, "\n";
                    }
                }

            }
            else {
                #Tier 5 repeats everything else!!!
                for my $reference (keys %{$variant_at{$chr}{$start}{$stop}}) {
                    for my $variant(keys %{$variant_at{$chr}{$start}{$stop}{$reference}}) {
                        print $tier3 $variant_at{$chr}{$start}{$stop}{$reference}{$variant}, "\n";
                    }
                }
            }

        }
    }

    foreach my $col (keys %totals) {
        print STDOUT "$col: ",$totals{$col},"\n";
    }
}

sub infer_variant_type_from_line {
    my $self = shift;
    my $line = shift;

    # FIXME ... totally need a better method here but indels have stars in the lines
    if ($line =~ m/\*/) {
        my @columns = split "\t", $line;

        my ($reference, $variant) = @columns[6,7];

        if (($reference eq '-')||($reference eq '0')) {
            return 'INS';
        } elsif (($variant eq '-')||($variant eq '0')) {
            return 'DEL';
        } else {
            $self->error_message("Could not determine variant type from variant:");
            $self->error_message(Dumper($variant));
            die;
        }
    } else {
        return 'SNP';
    }
}
