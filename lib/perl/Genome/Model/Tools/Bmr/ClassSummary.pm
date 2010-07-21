package Genome::Model::Tools::Bmr::ClassSummary;

use strict;
use warnings;

use Genome;
use IO::File;
use Bit::Vector;

class Genome::Model::Tools::Bmr::ClassSummary {
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
        doc => 'Output file containing BMR for 7 classes for this group of regions, mutations, and wiggle files.',
    },
#    rejected_mutations => {
#        type => 'String',
#        is_optional => 1,
#        doc => 'File to catch mutations that fall in the ROI list location-wise, but have a gene name which does not match any of the genes in the ROI list. Default operation is to print to STDOUT.',
#    },
    ]
};

sub help_brief {
    "Calculate the background mutation rate for a group of wiggle files."
}

sub help_detail {
    "This script calculates and prints the background mutation rate for transitions, transversions, and indel classes given a set of wiggle files (denoting specific coverage regions), given a specific set of mutations, and given specific regions of interest. The input mutation list provides the number of non-synonomous mutations (missense, nonsense, nonstop, splice-site) found in the sample set for each mutation class. Then, this number of mutations is divided by the total coverage across each base category (A&T, CpG islands, C&G not in CpG islands) that could lead to that mutation type in each ROI. Data output is of this format: [Mutation_Class  BMR  Coverage  #_of_Mutations]."
}

sub execute {
    my $self = shift;
    $DB::single=1;

    #resolve refseq
    my $ref_build_name = $self->refseq_build_name;
    my ($ref_model_name,$ref_build_version) = $ref_build_name =~ /^(\S+)-build(\S*)$/;
    my $ref_model = Genome::Model->get(name=>$ref_model_name);
    my $ref_build = $ref_model->build_by_version($ref_build_version);

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

    #Create an initial ROI bitmask
    my $roi_bitmask = $self->create_empty_genome_bitmask($ref_build);
    for my $chr (keys %ROIs) {
        for my $gene (keys %{$ROIs{$chr}}) {
            for my $start (keys %{$ROIs{$chr}{$gene}}) {
                my $stop = $ROIs{$chr}{$gene}{$start};
                $roi_bitmask->{$chr}->Interval_Fill($start,$stop);
            }
        }
    }

    #quickly scan through MAF to count mutations per gene
    my $mutation_file = $self->mutation_maf_file;
    my $mut_fh = new IO::File $mutation_file,"r";
    my %mutation_counts;

    while (my $line = $mut_fh->getline) {
        chomp $line;

        #skip header
        next if ($line =~ /^Hugo/);

        my ($gene,$geneid,$center,$refbuild,$chr,$start,$stop,$strand,$mutation_class,$mutation_type,$ref,$var1,$var2) = split /\t/,$line;

        #fix broad chromosome name
        if ($chr =~ /^chr/) {
            $chr =~ s/^chr(.+$)/$1/;
        }

        #using WU only for now
        #next if $center !~ /wustl/i;
        #make sure mutation is inside the ROIs
        next unless ($self->count_bits($roi_bitmask->{$chr},$start,$stop));
        #make sure gene is listed in the roi list
        unless (grep { /^$gene$/ } keys %{$ROIs{$chr}}) {
            $self->status_message("Gene $gene not found in ROI hash. Check this mutation's gene in ROI list:\n$line");
            next;
        }

        #make sure mutation is a correct type (if SNV)
        if ($mutation_type =~ /snp|dnp|onp|tnp/i) {
            #if this mutation is non-synonymous
            if ($mutation_class =~ /missense|nonsense|nonstop|splice_site/i) {
                $mutation_counts{$gene}++;
                next;
            }
        }
        #make sure mutation is a correct type (if Indel)
        if ($mutation_type =~ /ins|del/i) {
            $mutation_counts{$gene}++;
            next;
        }
    }
    undef $mut_fh;

    #loop through mutation_count hash to see which genes to ignore (>5 mutations)
    my @to_ignore;
    for my $gene (keys %mutation_counts) {
        if ($mutation_counts{$gene} > 5) {
            push @to_ignore,$gene;
        }
    }

    #now that we know which genes to ignore, create a new, more accurate ROI info
    undef %ROIs;
    undef $roi_bitmask;

    #load ROIs into a new ROI hash %ROIs -> chr -> gene -> start = stop;
    $bed_fh = new IO::File $roi_bedfile,"r";
    while (my $line = $bed_fh->getline) {
        chomp $line;
        my ($chr,$start,$stop,$exon_id) = split /\t/,$line;
        (my $gene = $exon_id) =~ s/^([^\.]+)\..+$/$1/;
        next if (scalar grep { /^$gene$/ } @to_ignore);
        if ($chr eq "M") { $chr = "MT"; } #for broad roi lists
        if (exists $ROIs{$chr}{$gene}{$start}) {
            next if $stop < $ROIs{$chr}{$gene}{$start};
        }
        $ROIs{$chr}{$gene}{$start} = $stop;
    }
    $bed_fh->close;

    #Create an new ROI bitmask
    $roi_bitmask = $self->create_empty_genome_bitmask($ref_build);
    for my $chr (keys %ROIs) {
        for my $gene (keys %{$ROIs{$chr}}) {
            #juse in case...
            next if (scalar grep { /^$gene$/ } @to_ignore);
            for my $start (keys %{$ROIs{$chr}{$gene}}) {
                my $stop = $ROIs{$chr}{$gene}{$start};
                $roi_bitmask->{$chr}->Interval_Fill($start,$stop);
            }
        }
    }

    #Parse wiggle file directory to obtain the paths to wiggle files
    my $wiggle_dir = $self->wiggle_file_dir;
    opendir(WIG,$wiggle_dir) || die "Cannot open directory $wiggle_dir";
    my @wiggle_files = readdir(WIG);
    closedir(WIG);
    @wiggle_files = grep { !/^(\.|\.\.)$/ } @wiggle_files;
    @wiggle_files = map { $_ = "$wiggle_dir/" . $_ } @wiggle_files;

    #Initiate COVMUTS hash for recording coverage and mutations: %COVMUTS -> class -> coverage,mutations
    my %COVMUTS;
    my @classes = ('CG.transit','CG.transver','AT.transit','AT.transver','CpG.transit','CpG.transver','Indels');
    for my $class (@classes) {
        $COVMUTS{$class}{'coverage'} = 0;
        $COVMUTS{$class}{'mutations'} = 0;
    }

    #loop through samples to calculate class coverages
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

        #find intersection of sample's coverage in ROIs and mutation class regions
        for my $chr (keys %$cov_bitmask) {

            my $tempvector = $cov_bitmask->{$chr}->Clone();
            my $bits_on = $tempvector->Norm();

            #Indels
            $COVMUTS{'Indels'}{'coverage'} += $bits_on;

            #AT
            $tempvector->And($cov_bitmask->{$chr},$at_bitmask->{$chr});
            $bits_on = $tempvector->Norm();
            $COVMUTS{'AT.transit'}{'coverage'} += $bits_on;
            $COVMUTS{'AT.transver'}{'coverage'} += $bits_on;

            #CG
            $tempvector->And($cov_bitmask->{$chr},$cg_bitmask->{$chr});
            $bits_on = $tempvector->Norm();
            $COVMUTS{'CG.transit'}{'coverage'} += $bits_on;
            $COVMUTS{'CG.transver'}{'coverage'} += $bits_on;

            #CpG
            $tempvector->And($cov_bitmask->{$chr},$cpg_bitmask->{$chr});
            $bits_on = $tempvector->Norm();
            $COVMUTS{'CpG.transit'}{'coverage'} += $bits_on;
            $COVMUTS{'CpG.transver'}{'coverage'} += $bits_on;
        }

        undef $cov_bitmask; #clean up any memory

    }#end, for my wiggle file

    #clean up the object memory
    $bitmask_conversion->delete;
    undef $bitmask_conversion;

    #Loop through mutations, assign them to a gene and class in %COVMUTS
    $mut_fh = new IO::File $mutation_file,"r";

=cut
    #print rejected mutations to a file or to STDOUT
    my $rejects_file = $self->rejected_mutations;
    my $rejects_fh;
    if ($rejects_file) {
        $rejects_fh = new IO::File $rejects_file,"w";
    }
    else {
        open $rejects_fh, ">&STDOUT";
    }
=cut

    while (my $line = $mut_fh->getline) {
        next if ($line =~ /^Hugo/);
        chomp $line;
        my ($gene,$geneid,$center,$refbuild,$chr,$start,$stop,$strand,$mutation_class,$mutation_type,$ref,$var1,$var2) = split /\t/,$line;

        #fix broad chromosome name
        if ($chr =~ /^chr/) {
            $chr =~ s/^chr(.+$)/$1/;
        }
        #highly-mutated genes to ignore
        next if (scalar grep { /^$gene$/ } @to_ignore);
        #using WU only for the initial test set
        #next if $center !~ /wustl/i;
        #make sure mutation is inside the ROIs
        next unless ($self->count_bits($roi_bitmask->{$chr},$start,$stop));

        #SNVs
        if ($mutation_type =~ /snp|dnp|onp|tnp/i) {
            #if this mutation is non-synonymous
            if ($mutation_class =~ /missense|nonsense|nonstop|splice_site/i) {
                #and if this gene is listed in the ROI list since it is listed in the MAF and passed the bitmask filter
                if (scalar grep { /^$gene$/ } keys %{$ROIs{$chr}}) {

                    #determine the classification for ref A's and T's
                    if ($ref eq 'A') {
                        #is it a transition?
                        if ($var1 eq 'G' || $var2 eq 'G') {
                            $COVMUTS{'AT.transit'}{'mutations'}++;
                        }
                        #else, it must be a transversion
                        elsif ($var1 =~ /C|T/ || $var2 =~ /C|T/) {
                            $COVMUTS{'AT.transver'}{'mutations'}++;
                        }
                        #otherwise, classification is impossible - quit.
                        else {
                            $self->error_message("Unable to determine classification of this mutation:\n$line");
                            return;
                        }
                    }#end, if ref = A

                    if ($ref eq 'T') {
                        #is it a transition?
                        if ($var1 eq 'C' || $var2 eq 'C') {
                            $COVMUTS{'AT.transit'}{'mutations'}++;
                        }
                        #else, it must be a transversion
                        elsif ($var1 =~ /G|A/ || $var2 =~ /G|A/) {
                            $COVMUTS{'AT.transver'}{'mutations'}++;
                        }
                        #otherwise, classification is impossible - quit.
                        else {
                            $self->error_message("Unable to determine classification of this mutation:\n$line");
                            return;
                        }
                    }#end, if ref = T

                    #determine the classification for ref C's and G's
                    if ($ref eq 'C') {
                        #is it a transition?
                        if ($var1 eq 'T' || $var2 eq 'T') {
                            #is it inside a CpG island?
                            if ($self->count_bits($cpg_bitmask->{$chr},$start,$stop)) {
                                $COVMUTS{'CpG.transit'}{'mutations'}++;
                            }
                            else {
                                $COVMUTS{'CG.transit'}{'mutations'}++;
                            }
                        }
                        #if not a transition, is it a transversion?
                        elsif ($var1 =~ /G|A/ || $var2 =~ /G|A/) {
                            #is it inside a CpG island?
                            if ($self->count_bits($cpg_bitmask->{$chr},$start,$stop)) {
                                $COVMUTS{'CpG.transver'}{'mutations'}++;
                            }
                            else {
                                $COVMUTS{'CG.transver'}{'mutations'}++;
                            }
                        }
                        #otherwise, classification is impossible - quit.
                        else {
                            $self->error_message("Unable to determine classification of this mutation:\n$line");
                            return;
                        }
                    }#end, if ref = C

                    if ($ref eq 'G') {
                        #is it a transition?
                        if ($var1 eq 'A' || $var2 eq 'A') {
                            #is it inside a CpG island?
                            if ($self->count_bits($cpg_bitmask->{$chr},$start,$stop)) {
                                $COVMUTS{'CpG.transit'}{'mutations'}++;
                            }
                            else {
                                $COVMUTS{'CG.transit'}{'mutations'}++;
                            }
                        }
                        #if not a transition, is it a transversion?
                        elsif ($var1 =~ /T|C/ || $var2 =~ /T|C/) {
                            #is it inside a CpG island?
                            if ($self->count_bits($cpg_bitmask->{$chr},$start,$stop)) {
                                $COVMUTS{'CpG.transver'}{'mutations'}++;
                            }
                            else {
                                $COVMUTS{'CG.transver'}{'mutations'}++;
                            }
                        }
                        #otherwise, classification is impossible - quit.
                        else {
                            $self->error_message("Unable to determine classification of this mutation:\n$line");
                            return;
                        }
                    }#end, if ref = G
                }#end, if ROI and MAF genes match 

                #if the ROI list and MAF file do not match, record this with a status message.
                else {
                    $self->status_message("Cannot find this mutation's gene in the ROI hash:\n$line");
                    next;
                }
            }#end, if mutation is non-synonymous
        }#end, if mutation is a SNV

        #Indels
        if ($mutation_type =~ /ins|del/i) {
            #verify this gene is listed in the ROI list since it is listed in the MAF and passed the bitmask filter
            if (scalar grep { /^$gene$/ } keys %{$ROIs{$chr}}) {
                $COVMUTS{'Indels'}{'mutations'}++;
            }
            else {
                $self->status_message("Cannot find this mutation's gene in the ROI hash:\n$line");
                next;
            }
        }#end, if mutation is an indel
    }#end, loop through MAF
    $mut_fh->close;

    #Loop through COVMUTS hash and tabulate group BMRs into %BMR hash (%BMR -> class = bmr)
    my %BMR;
    for my $class (keys %COVMUTS) {
        my $rate;
        if ($COVMUTS{$class}{'coverage'}) {
            $rate = $COVMUTS{$class}{'mutations'} / $COVMUTS{$class}{'coverage'};
        }
        else {
            $rate = 'No Coverage';
        }
        $BMR{$class} = $rate;
    }

    #Loop through %BMR to print summary file
    my $output_file = $self->output_file;
    my $out_fh = new IO::File $output_file,"w";
    print $out_fh "Class\tBMR\tCoverage(Bases)\tNon_Syn_Mutations\n";

    for my $class (sort keys %BMR) {
        print $out_fh "$class\t$BMR{$class}\t$COVMUTS{$class}{'coverage'}\t$COVMUTS{$class}{'mutations'}\n";
    }
    $out_fh->close;

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
#%COVMUTS->gene->class->(coverage,#mutations)
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
