package Genome::Model::Tools::Bmr::CalculateBmr;

use strict;
use warnings;

use Genome;
use IO::File;
use Bit::Vector;

class Genome::Model::Tools::Bmr::CalculateBmr {
    is => 'Genome::Command::OO',
    has_input => [
    refseq_build_name => {
        is => 'String',
        is_optional => 1,
        default => 'NCBI-human-build36',
        doc => 'The reference sequence build, used to gather and generate bitmask files for base masking and sample coverage.',
    },
    roi_bedfile => {
        type => 'String',
        is_optional => 0,
        doc => 'BED file used to limit background regions of interest when calculating background mutation rate',
    },
    mutation_maf_file => {
        type => 'String',
        is_optional => 0,
        doc => 'List of mutations used to calculate background mutation rate',
    },
    wiggle_file_dir => {
        type => 'String',
        is_optional => 0,
        doc => 'Wiggle files detailing genome-wide coverage of each sample in dataset',
    },
    output_file => {
        type => 'String',
        is_optional => 0,
        doc => 'File to contain results table.',
    },
    rejected_mutations => {
        type => 'String',
        is_optional => 1,
        doc => 'File to catch mutations that fall in the ROI list location-wise, but have a gene name which does not match any of the genes in the ROI list. Default operation is to print to STDOUT.',
    },
    ]
};

sub help_brief {
    "Calculate the background mutation rate in genomic regions of interest."
}

sub help_detail {
    "This script calculates and prints the background mutation rate found in each gene or region-of-interest found in the input ROI list. Mutation rates are calculated independently for each class of mutation (transitions, transversions, indels, e.g.). The input mutation list provides the number of non-synonomous mutations (missense, nonsense, nonstop, splice-site) found in the sample set for each mutation class. Then, this number of mutations is divided by the total coverage across each base category (A&T, CpG islands, C&G not in CpG islands) that could lead to that mutation type in each ROI. Data output is of this format: [Gene  Mutation_Class  Coverage  #Mutations  BMR] for each gene, for each class of mutation."
}

sub execute {
    my $self = shift;

    #resolve refseq
    my $ref_build_name = $self->refseq_build_name;
    my ($ref_model_name,$ref_build_version) = $ref_build_name =~ /^(\S+)-build(\S*)$/;
    my $ref_model = Genome::Model->get(name=>$ref_model_name);
    my $ref_build = $ref_model->build_by_version($ref_build_version);
    
    #load ROIs into a hash %ROIs -> chr -> gene -> start = stop;
    my %ROIs;
    my $roi_bedfile = $self->roi_bedfile;
    my $bed_fh = new IO::File $roi_bedfile,"r";
    while (my $line = $bed_fh->getline) {
        chomp $line;
        my ($chr,$start,$stop,$exon_id) = split /\t/,$line;
        (my $gene = $exon_id) =~ s/^([^\.]+)\..+$/$1/;
        if ($chr eq "M") { $chr = "MT"; } #for broad roi lists
        if (exists $ROIs{$chr}{$gene}{$start}) {
            next if $stop < $ROIs{$chr}{$gene}{$start};
        }
        $ROIs{$chr}{$gene}{$start} = $stop;
    }
    $bed_fh->close;

    #load bitmasks
    my $at_bitmask_file = $ref_build->data_directory . "/all_sequences.AT_bitmask";
    my $cpg_bitmask_file = $ref_build->data_directory . "/all_sequences.CpG_bitmask";
    my $cg_bitmask_file = $ref_build->data_directory . "/all_sequences.CG_bitmask";
    my $at_bitmask = $self->read_genome_bitmask($at_bitmask_file);
    my $cpg_bitmask = $self->read_genome_bitmask($cpg_bitmask_file);
    my $cg_bitmask = $self->read_genome_bitmask($cg_bitmask_file);

    #make sure bitmasks were loaded
    unless ($at_bitmask) {
        $self->error_message("AT bitmask was not loaded.");
        return;
    }
    unless ($cpg_bitmask) {
        $self->error_message("CpG bitmask was not loaded.");
        return;
    }
    unless ($cg_bitmask) {
        $self->error_message("CG bitmask was not loaded.");
        return;
    }

    #Create an ROI bitmask
    my $roi_bitmask = $self->create_empty_genome_bitmask($ref_build);
    for my $chr (keys %ROIs) {
        for my $gene (keys %{$ROIs{$chr}}) {
            for my $start (keys %{$ROIs{$chr}{$gene}}) {
                my $stop = $ROIs{$chr}{$gene}{$start};
                $roi_bitmask->{$chr}->Interval_Fill($start,$stop);
            }
        }
    }

    #Parse wiggle file directory to obtain the path to wiggle files
    my $wiggle_dir = $self->wiggle_file_dir;
    opendir(WIG,$wiggle_dir) || die "Cannot open directory $wiggle_dir";
    my @wiggle_files = readdir(WIG);
    closedir(WIG);
    @wiggle_files = grep { !/^(\.|\.\.)$/ } @wiggle_files;
    @wiggle_files = map { $_ = "$wiggle_dir/" . $_ } @wiggle_files;

    #Loop through samples to build BMR hash %BMR -> gene -> class -> coverage, mutations, bmr
    my %BMR;
    my $bitmask_conversion = Genome::Model::Tools::Bmr::WtfToBitmask->create(
        reference_index => $ref_build->full_consensus_sam_index_path,
    );

    for my $file (@wiggle_files) {

        #create sample coverage bitmask;
        $bitmask_conversion->wtf_file($file);
        if ($bitmask_conversion->is_executed) {
            $bitmask_conversion->is_executed('0');
        }
        $bitmask_conversion->execute;

        unless ($bitmask_conversion) {
            $self->error_message("Not seeing a bitmask object for file $file.");
            return;
        }
        my $cov_bitmask = $bitmask_conversion->bitmask;
        unless ($cov_bitmask) {
            $self->error_message("Not seeing cov_bitmask from bitmask_cov->bitmask.");
            return;
        }

        #find intersection of ROIs and sample's coverage
        for my $chr (keys %$cov_bitmask) {
            $cov_bitmask->{$chr}->And($cov_bitmask->{$chr},$roi_bitmask->{$chr});
        }

        #loop through ROIs to calculate coverage of each class in this sample
        my @classes = ('CG.transit','CG.transver','AT.transit','AT.transver','CpG.transit','CpG.transver','Indels');
        for my $chr (keys %ROIs) {

            my $testvector = $cov_bitmask->{$chr}->Shadow();

            for my $gene (keys %{$ROIs{$chr}}) {

                unless (grep {/^$gene$/} keys %BMR) {
                    for my $class (@classes) {
                        $BMR{$gene}{$class}{'coverage'} = 0;
                        $BMR{$gene}{$class}{'mutations'} = 0;
                    }
                }

                for my $start (keys %{$ROIs{$chr}{$gene}}) {

                    my $stop = $ROIs{$chr}{$gene}{$start};
                    my $bits;

                    #indels
                    $bits = $self->count_bits($cov_bitmask->{$chr},$start,$stop);
                    $BMR{$gene}{'Indels'}{'coverage'} += $bits;

                    #AT
                    $testvector->And($cov_bitmask->{$chr},$at_bitmask->{$chr});
                    $bits = $self->count_bits($testvector,$start,$stop);
                    $BMR{$gene}{'AT.transit'}{'coverage'} += $bits;
                    $BMR{$gene}{'AT.transver'}{'coverage'} += $bits;

                    #CG
                    $testvector->And($cov_bitmask->{$chr},$cg_bitmask->{$chr});
                    $bits = $self->count_bits($testvector,$start,$stop);
                    $BMR{$gene}{'CG.transit'}{'coverage'} += $bits;
                    $BMR{$gene}{'CG.transver'}{'coverage'} += $bits;

                    #CpG
                    $testvector->And($cov_bitmask->{$chr},$cpg_bitmask->{$chr});
                    $bits = $self->count_bits($testvector,$start,$stop);
                    $BMR{$gene}{'CpG.transit'}{'coverage'} += $bits;
                    $BMR{$gene}{'CpG.transver'}{'coverage'} += $bits;
                }#end, for my $start
            }#end, for my $gene
        }#end, for my $chr

        undef $cov_bitmask; #clean up any memory

    }#end, for my wiggle file

    #clean up the object memory
    $bitmask_conversion->delete;
    undef $bitmask_conversion;

    #Loop through mutations, assign them to a gene and class in %BMR
    my $mutation_file = $self->mutation_maf_file;
    my $mut_fh = new IO::File $mutation_file,"r";
    
    #print rejected mutations to a file or to STDOUT
    my $rejects_file = $self->rejected_mutations;
    my $rejects_fh;
    if ($rejects_file) {
        $rejects_fh = new IO::File $rejects_file,"w";
    }
    else {
        open $rejects_fh, ">&STDOUT";
    }

    while (my $line = $mut_fh->getline) {
        chomp $line;
        my ($gene,$geneid,$center,$refbuild,$chr,$start,$stop,$strand,$mutation_class,$mutation_type,$ref,$var1,$var2) = split /\t/,$line;
        #highly-mutated genes to ignore
        next if $gene =~ /TP53|BRCA1|BRCA2/;
        #using WU only for the initial test set
        next if $center !~ /wustl/;
        #make sure mutation is inside the ROIs
        next unless ($self->count_bits($roi_bitmask->{$chr},$start,$stop));


        #SNVs
        if ($mutation_type =~ /snp|dnp/i) {
            #if this mutation is non-synonymous
            if ($mutation_class =~ /missense|nonsense|nonstop|splice_site/i) {
                #and if this gene is listed in the ROI list since it is listed in the MAF and passed the bitmask filter
                if (grep { /^$gene$/ } keys %BMR) {

                    #determine the classification for ref A's and T's
                    if ($ref eq 'A') {
                        #is it a transition?
                        if ($var1 eq 'G' || $var2 eq 'G') {
                            $BMR{$gene}{'AT.transit'}{'mutations'}++;
                        }
                        #else, it must be a transversion
                        elsif ($var1 =~ /C|T/ || $var2 =~ /C|T/) {
                            $BMR{$gene}{'AT.transver'}{'mutations'}++;
                        }
                        #otherwise, classification is impossible - quit.
                        else {
                            $self->error_message("Unable to determine classification of this mutation: $line");
                            return;
                        }
                    }#end, if ref = A

                    if ($ref eq 'T') {
                        #is it a transition?
                        if ($var1 eq 'C' || $var2 eq 'C') {
                            $BMR{$gene}{'AT.transit'}{'mutations'}++;
                        }
                        #else, it must be a transversion
                        elsif ($var1 =~ /G|A/ || $var2 =~ /G|A/) {
                            $BMR{$gene}{'AT.transver'}{'mutations'}++;
                        }
                        #otherwise, classification is impossible - quit.
                        else {
                            $self->error_message("Unable to determine classification of this mutation: $line");
                            return;
                        }
                    }#end, if ref = T

                    #determine the classification for ref C's and G's
                    if ($ref eq 'C') {
                        #is it a transition?
                        if ($var1 eq 'T' || $var2 eq 'T') {
                            #is it inside a CpG island?
                            if ($self->count_bits($cpg_bitmask->{$chr},$start,$stop)) {
                                $BMR{$gene}{'CpG.transit'}{'mutations'}++;
                            }
                            else {
                                $BMR{$gene}{'CG.transit'}{'mutations'}++;
                            }
                        }
                        #if not a transition, is it a transversion?
                        elsif ($var1 =~ /G|A/ || $var2 =~ /G|A/) {
                            #is it inside a CpG island?
                            if ($self->count_bits($cpg_bitmask->{$chr},$start,$stop)) {
                                $BMR{$gene}{'CpG.transver'}{'mutations'}++;
                            }
                            else {
                                $BMR{$gene}{'CG.transver'}{'mutations'}++;
                            }
                        }
                        #otherwise, classification is impossible - quit.
                        else {
                            $self->error_message("Unable to determine classification of this mutation: $line");
                            return;
                        }
                    }#end, if ref = C

                    if ($ref eq 'G') {
                        #is it a transition?
                        if ($var1 eq 'A' || $var2 eq 'A') {
                            #is it inside a CpG island?
                            if ($self->count_bits($cpg_bitmask->{$chr},$start,$stop)) {
                                $BMR{$gene}{'CpG.transit'}{'mutations'}++;
                            }
                            else {
                                $BMR{$gene}{'CG.transit'}{'mutations'}++;
                            }
                        }
                        #if not a transition, is it a transversion?
                        elsif ($var1 =~ /T|C/ || $var2 =~ /T|C/) {
                            #is it inside a CpG island?
                            if ($self->count_bits($cpg_bitmask->{$chr},$start,$stop)) {
                                $BMR{$gene}{'CpG.transver'}{'mutations'}++;
                            }
                            else {
                                $BMR{$gene}{'CG.transver'}{'mutations'}++;
                            }
                        }
                        #otherwise, classification is impossible - quit.
                        else {
                            $self->error_message("Unable to determine classification of this mutation: $line");
                            return;
                        }
                    }#end, if ref = G
                }#end, if ROI and MAF genes match 

                #if the ROI list and MAF file do not match, quit.
                else {
                    print $rejects_fh "Cannot find this mutation's gene in the ROI hash:\n$line\n";
                    next;
                }
            }#end, if mutation is non-synonymous
        }#end, if mutation is a SNV

        #Indels
        if ($mutation_type =~ /ins|del/i) {
            #verify this gene is listed in the ROI list since it is listed in the MAF and passed the bitmask filter
            if (grep { /^$gene$/ } keys %BMR) {
                $BMR{$gene}{'Indels'}{'mutations'}++;
            }
            else {
                print $rejects_fh "Cannot find this mutation's gene in the ROI hash:\n$line\n";
                next;
            }
        }#end, if mutation is an indel
    }#end, loop through MAF

    #Loop through BMR hash and calculate BMRs (recall %BMR -> gene -> class -> coverage, mutations, bmr)
    for my $gene (keys %BMR) {
        for my $class (keys %{$BMR{$gene}}) {
            my $rate;
            if ($BMR{$gene}{$class}{'coverage'}) {
                $rate = $BMR{$gene}{$class}{'mutations'} / $BMR{$gene}{$class}{'coverage'};
            }
            else {
                $rate = "No Coverage";
            }
            $BMR{$gene}{$class}{'bmr'} = $rate;
        }
    }

    #Print results
    my $output_file = $self->output_file;
    my $out_fh = new IO::File $output_file,"w";
    print $out_fh "Gene\tClass\tBases_Covered\tNon-Syn_Mutations\tBMR\n";
    for my $gene (keys %BMR) {
        for my $class (keys %{$BMR{$gene}}) {
            print $out_fh "$gene\t$class\t";
            print $out_fh $BMR{$gene}{$class}{'coverage'} . "\t";
            print $out_fh $BMR{$gene}{$class}{'mutations'} . "\t";
            print $out_fh $BMR{$gene}{$class}{'bmr'} . "\n";
        }
    }

    return 1;
}

sub create_empty_genome_bitmask {
    my $self = shift;
    my $ref_build = shift;
    my %genome;
    my $ref_index_file = $ref_build->full_consensus_sam_index_path;
    my $ref_fh = new IO::File $ref_index_file,"r";
    while (my $line = $ref_fh->getline) {
        chomp $line;
        my ($chr,$length) = split /\t/,$line;
        $genome{$chr} = Bit::Vector->new($length + 1); #adding 1 for 1-based coordinates
    }
    $ref_fh->close;
    return \%genome;
}

sub read_genome_bitmask {
    my ($self,$filename) = @_;
    unless($filename) {
        $self->error_message("File $filename not found.");
        return;
    }
    #do some stuff to read this from a file without making it suck
    my $in_fh = IO::File->new($filename,"<:raw");
    unless($in_fh) {
        $self->error_message("Unable to read from " . $filename);
        return;
    }
    my $read_string;
    sysread $in_fh, $read_string, 4;
    my $header_length = unpack "N", $read_string;
    sysread $in_fh, $read_string, $header_length;
    my $header_string = unpack "a*",$read_string;
    my %genome = split /\t/, $header_string; #each key is the name, each value is the size in bits

    #now read in each one
    foreach my $chr (sort keys %genome) {
        $genome{$chr} = Bit::Vector->new($genome{$chr}); #this throws an exception if it fails. Probably should be trapped at some point in the future
        sysread $in_fh, $read_string, 4;
        my $chr_byte_length = unpack "N", $read_string;
        my $chr_read_string;
        sysread $in_fh, $chr_read_string, $chr_byte_length;
        $genome{$chr}->Block_Store($chr_read_string);
    }
    $in_fh->close;
    return \%genome;
}



sub count_bits {
    my ($self,$vector,$start,$stop) = @_;
    my $count = 0;
    for my $pos ($start..$stop) {
        if ($vector->bit_test($pos)) {
            $count++;
        }
    }
    return $count;
}

1;



#more specific hash structure
#%BMR->gene->class->(coverage,#mutations,BMR)
#
#classes
#
#CG.C.transit.T   CG.G.transit.A
#CG.C.transver.A CG.G.transver.T
#CG.C.transver.G CG.G.transver.C
#
#CpG.C.transit.T   CpG.G.transit.A
#CpG.C.transver.A CpG.G.transver.T
#CpG.C.transver.G CpG.G.transver.C
#
#AT.A.transit.G   AT.T.transit.C
#AT.A.transver.T AT.T.transver.A
#AT.A.transver.C AT.T.transver.G
#
#and Indels
