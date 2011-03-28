package Genome::Model::Tools::DetectVariants2::Filter::PindelReadSupport;

use warnings;
use strict;

use Genome;

my %positions;

class Genome::Model::Tools::DetectVariants2::Filter::PindelReadSupport{
    is => 'Genome::Model::Tools::DetectVariants2::Filter',
    has => [
    min_variant_support => {
        is => 'String',
        is_optional => 1,
        default => '0',
        doc => 'Required number of variant-supporting reads. Note: Pindel doesn\'t actually report the indel if var-support < 3.',
    },
    var_to_ref_read_ratio => {
        is => 'String',
        is_optional => 1,
        default => '0.2',
        doc => 'This ratio determines what ratio of variant supporting reads to reference supporting reads to allow',
    },
    remove_single_stranded => {
        is => 'Boolean',
        is_optional => 1,
        default => 1,
        doc => 'enable this to filter out variants which have exclusively pos or neg strand supporting reads.',
    },
    sw_ratio => {
        is => 'String',
        is_optional => 1,
        is_input => 1,
        default => '0.25',
        doc => 'Throw out indels which have a normalized ratio of normal smith waterman reads to tumor smith waterman reads (nsw/(nsw+tsw)) at or below this amount.',
    },
    ],
    has_constant => [
    use_old_pindel => {
        is => 'Number',
        default => 1,
        doc => 'This will be updated when more than one version of pindel, 0.2,  is available',
    },
    _variant_type => {
        type => 'String',
        default => 'indels',
        doc => 'variant type that this module operates on, overload this in submodules accordingly',
    },
    ],

};

sub _filter_variants {
    my $self = shift;
    $DB::single=1;
    my $read_support_file = $self->_temp_staging_directory."/indels.hq.read_support.bed";
    my $output_file = $self->_temp_staging_directory."/indels.hq.v2.bed";
    my $output_lq_file = $self->_temp_staging_directory."/indels.lq.bed";
    my $indel_file = $self->input_directory."/indels.hq.bed";

    $self->calculate_read_support($indel_file, $read_support_file);

    $self->filter_read_support($read_support_file,$output_file,$output_lq_file);
    return 1;
}

sub calculate_read_support {
    my $self = shift;
    my $indel_file = shift;
    my $read_support_file = shift;
    my $output = Genome::Sys->open_file_for_writing($read_support_file);
    my %indels;
    my %answers;

    # Read the input file into the positions and indels hashes
    my $fh = Genome::Sys->open_file_for_reading($indel_file);
    while (my $line = $fh->getline){
        chomp $line;
        my ($chr,$start,$stop,$refvar) = split /\t/, $line;
        #$positions{$chr}{$start}{$stop}=$refvar;
        my ($ref,$var) = split "/", $refvar;
        $indels{$chr}{$start} = $refvar;
    }

    for my $chr (sort(keys(%indels))){
        my %indels_by_chr = %{$indels{$chr}};
        $self->process_file($chr, \%indels_by_chr, $output);

    }

    $output->close;

}

sub process_file {
    my $self = shift;
    my $chr = shift;
    my $indels_by_chrom = shift;
    my $output = shift;

    # This is the directory containing the raw pindel output
    my $dir = $self->detector_directory;
    my $filename = $dir."/".$chr."/indels_all_sequences";
    my $pindel_output = Genome::Sys->open_file_for_reading($filename); 

    # Get the BAMs from the DetectVariants API
    my $tumor_bam = $self->aligned_reads_input;
    my $normal_bam = $self->control_aligned_reads_input if defined($self->control_aligned_reads_input);

    my %events;

    # Read in the raw output from pindel
    while(my $line = $pindel_output->getline){
        my $normal_support=0;
        my $read = 0;

        unless($line =~ m/^#+$/){
            next;
        }

        my $call = $pindel_output->getline;

        if($call =~ m/^Chr/){
            while(1) {
                $line = $pindel_output->getline;
                if($line =~ m/#####/) {
                    $call = $pindel_output->getline;
                } 
                if($call !~ m/^Chr/) {
                    last;
                }          
            }
        }
        my $reference = $pindel_output->getline;
        my @call_fields = split /\s/, $call;
        my $type = $call_fields[1];
        my $size = $call_fields[2];   #12

        my $pos_strand = 0;
        my $neg_strand = 0;

        my $mod = ($call =~ m/BP_range/) ? 2: -1;

        my $support;

        if($self->use_old_pindel){
            $support = ($type eq "I") ? $call_fields[10+$mod] : $call_fields[12+$mod];
        } else {
            $support = $call_fields[12+$mod];
        }
        unless(defined($support)){
            print "No support. Call was:   ".$call."\n";
            die;
        }

        # Read info for all the supporting reads
        for (1..$support){
            $line = $pindel_output->getline;
            if($line =~ m/normal/) {
                $normal_support=1;
            }
            if($line =~ m/\+/){
                $pos_strand++;
            }else{
                $neg_strand++;
            }
            $read=$line;
        }

        # Parse the call for its chr start stop
        my ($chr,$start,$stop);
        if($self->use_old_pindel){
            $chr = ($type eq "I") ? $call_fields[4] : $call_fields[6];
            $start= ($type eq "I") ? $call_fields[6] : $call_fields[8];
            $stop = ($type eq "I") ? $call_fields[7] : $call_fields[9];
        } else {
            $chr = $call_fields[6];
            $start= $call_fields[8];
            $stop = $call_fields[9];
        }

        # Skip this call if it is not found in the input_file ( this could mean it was filtered by pindel-somatic-calls)
        unless(exists $indels_by_chrom->{$start}){
            next;
        }

        # Convert the call info into bed format
        my @bed_line = $self->parse($call, $reference, $read);

        unless((@bed_line)&& scalar(@bed_line)==4){
            next;
        }

        ($chr,$start) = @bed_line;

        my $type_and_size = $type."/".$size;
        $events{$chr}{$start}{$type_and_size}{'neg'}=$neg_strand;
        $events{$chr}{$start}{$type_and_size}{'pos'}=$pos_strand;
        $events{$chr}{$start}{$type_and_size}{'bed'}=join("\t",@bed_line);
        if($normal_support){
            $events{$chr}{$start}{$type_and_size}{'normal'}=$normal_support;
        }
    }

    my ($chrom,$pos,$size,$type);

    for $chrom (sort {$a cmp $b} (keys(%events))){
        for $pos (sort{$a <=> $b} (keys( %{$events{$chrom}}))){
            for my $type_and_size (sort(keys( %{$events{$chrom}{$pos}}))){
                my $pos_strand = $events{$chrom}{$pos}{$type_and_size}{'pos'};
                my $neg_strand = $events{$chrom}{$pos}{$type_and_size}{'neg'};
                my $pos_percent=0;
                if($neg_strand==0){
                    $pos_percent = 1.0;
                } else {
                    $pos_percent = sprintf("%.2f", $pos_strand / ($pos_strand + $neg_strand));
                }
                my $answer = "neg = ".$neg_strand."\tpos = ".$pos_strand." which gives % pos str = ".$pos_percent."\n";
                my $reads = $pos_strand + $neg_strand;
                #my @stop = keys(%{$positions{$chrom}{$pos}});
                my ($type,$size) = split /\//, $type_and_size;
                my $stop = $pos;

                # Call samtools over the variant start-stop to get overlapping reads
                my @results = `samtools view $tumor_bam $chrom:$pos-$stop`;
                my $tumor_read_support=0;
                my $tumor_read_sw_support=0;
                for my $result (@results){
                    chomp $result;
                    my @details = split /\t/, $result;
                    # Parse overlapping reads for cigar strings containing insertions or deletions
                    if($details[5] =~ m/[ID]/){
                        $tumor_read_sw_support++;
                    }
                    else {
                        $tumor_read_support++;
                    }
                }

                # Call samtools over the variant start-stop in the normal bam to get overlapping reads
                @results = `samtools view $normal_bam $chrom:$pos-$stop`;
                my $normal_read_support=0;
                my $normal_read_sw_support=0;

                for my $result (@results){
                    chomp $result;
                    my @details = split /\t/, $result;
                    # Parse overlapping reads for insertions or deletions
                    if($details[5] =~ m/[ID]/){
                        $normal_read_sw_support++;
                    }
                    else {
                        $normal_read_support++;
                    }

                }
                my $p_value = Genome::Statistics::calculate_p_value($normal_read_support, $normal_read_sw_support, $tumor_read_support, $tumor_read_sw_support); 
                if($p_value eq '1') {
                    $p_value = Genome::Statistics::calculate_p_value($normal_read_sw_support, $normal_read_support, $tumor_read_sw_support, $tumor_read_support); 
                } 
                my $bed_output = $events{$chrom}{$pos}{$type_and_size}{'bed'}."\t$reads\t$tumor_read_support\t$tumor_read_sw_support\t$normal_read_support\t$normal_read_sw_support\t$pos_percent\t$p_value\n";

                print $output $bed_output;

            }
        }
    }
}

sub parse {
    my $self = shift;
    my $reference_fasta = $self->reference_sequence_input;
    my ($call, $reference, $first_read) = @_;
    #parse out call bullshit
    chomp $call;
    my @call_fields = split /\s+/, $call;
    my $type = $call_fields[1];
    my $size = $call_fields[2];
    my ($chr,$start,$stop);
    if($self->use_old_pindel){
        $chr = ($type eq "I") ? $call_fields[4] : $call_fields[6];
        $start= ($type eq "I") ? $call_fields[6] : $call_fields[8];
        $stop = ($type eq "I") ? $call_fields[7] : $call_fields[9];
    } else {
        $chr = $call_fields[6];
        $start= $call_fields[8];
        $stop = $call_fields[9];
    }
    my $support = $call_fields[-1];
    my ($ref, $var);
    if($type =~ m/D/) {
        $var =0;
        ###Make pindels coordinates(which seem to be last undeleted base and first undeleted base) 
        ###conform to our annotators requirements

        ###also deletions which don't contain their full sequence should be dumped to separate file
        $stop = $stop - 1;
        my $allele_string;
        my $start_for_faidx = $start+1;
        my $sam_default = Genome::Model::Tools::Sam->path_for_samtools_version;
        my $faidx_cmd = "$sam_default faidx " . $reference_fasta . " $chr:$start_for_faidx-$stop";
        #my $faidx_cmd = "$sam_default faidx " . $reference_fasta . " $chr:$start-$stop";
        my @faidx_return= `$faidx_cmd`;
        shift(@faidx_return);
        chomp @faidx_return;
        $allele_string = join("",@faidx_return);

        $ref = $allele_string;
    }
    elsif($type =~ m/I/) {
        $stop = $stop - 1;
        $ref=0;
        my ($letters_until_space) =   ($reference =~ m/^([ACGTN]+) /);
        my $offset_into_first_read = length($letters_until_space);
        $var = substr($first_read, $offset_into_first_read, $size);
    }
    if($size >= 100) {
        #my $big_fh = $self->_big_output_fh;
        #$big_fh->print("$chr\t$start\t$stop\t$size\t$support\n");
        return undef;
    }
    my $refvar = "$ref/$var";
    return ($chr,$start,$stop,$refvar);
}

sub filter_read_support {
    my $self = shift;
    my $read_support_file = shift;
    my $output_file = shift;
    my $output_lq_file = shift;

    unless(-e $read_support_file) {
        $self->error_message($self->read_support_file . " is not found or is empty.");
        die $self->error_message;
    }

    my $input = Genome::Sys->open_file_for_reading( $read_support_file );
    my $output = Genome::Sys->open_file_for_writing( $output_file );
    my $output_lq = Genome::Sys->open_file_for_writing( $output_lq_file );

    while( my $line = $input->getline){
        chomp $line;
        my ($chr,$start,$stop,$refvar,$pindel_reads,$t_reads,$t_sw_reads,$n_reads,$n_sw_reads,$ps, $p_value) = split "\t", $line;
        my $hq=0;
        if($p_value <= .15) { #assuming significant smith waterman support, trust the fishers exact test to make a germline determination
            $hq=1;
        }
        if(($t_sw_reads + $t_reads < 10) && ($pindel_reads > $t_sw_reads)) { #low coverage area, and pindel found more reads than were smith waterman mapped available-- rescue this from pvalue filter
            $hq=1;
        }

        if($hq==1){
            print $output join("\t", ($chr,$start,$stop,$refvar,'-','-'))."\n";
        }
        else {
            print $output_lq join("\t", ($chr,$start,$stop,$refvar,'-','-'))."\n";
        }
    }

    $input->close;
    $output->close;
    $output_lq->close;

    return 1;
}

sub _check_file_counts {
    return 1;
}

sub _generate_standard_output {
    my $self = shift;
    my $output = $self->output_directory."/indels.hq.v2.bed";
    my $output_link = $self->output_directory."/indels.hq.bed";
    Genome::Sys->create_symlink($output, $output_link);
    return 1;
}

1;
