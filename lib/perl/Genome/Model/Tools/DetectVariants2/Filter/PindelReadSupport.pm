package Genome::Model::Tools::DetectVariants2::Filter::PindelReadSupport;

use warnings;
use strict;

use Genome;

my %positions;

class Genome::Model::Tools::DetectVariants2::Filter::PindelReadSupport{
    is => 'Genome::Model::Tools::DetectVariants2::Filter',
    has => [
        germline_events => {
            is => 'Boolean',
            default => 0,
            doc => 'Set this to only include events with some support in the control',
        },
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

    ],
    has_constant => [
        use_old_pindel => {
            is => 'Number',
            default => 1,
            doc => 'This will be updated when more than one version of pindel, 0.2,  is available',
        },
    ],
};

sub _filter_variants {
    my $self = shift;

    my $read_support_file = $self->_temp_staging_directory."/indels.hq.read_support.bed";
    my $output_file = $self->_temp_staging_directory."/indels.hq.bed";
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

    my $fh = Genome::Sys->open_file_for_reading($indel_file);
    while (my $line = $fh->getline){
        chomp $line;
        my ($chr,$start,$stop,$refvar) = split /\t/, $line;
        $positions{$chr}{$start}{$stop}=$refvar;
        my ($ref,$var) = split "/", $refvar;
        $indels{$chr}{$start} = $refvar;
    }

    #print $output "CHR\tSTART\tSTOP\tREF/VAR\tINDEL_SUPPORT\tREFERENCE_SUPPORT\t%+STRAND\n";
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
    my $dir = $self->detector_directory;
    my $filename = $dir."/".$chr."/indels_all_sequences";
    my $pindel_output = Genome::Sys->open_file_for_reading($filename); #IO::File->new($filename);
    my $tumor_bam = $self->aligned_reads_input;

    my %events;
    my ($chrom,$pos,$size,$type);

    while(my $line = $pindel_output->getline){
        my $normal_support=0;
        my $read = 0;
        if($line =~ m/^#+$/){
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
#charris speed hack
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
#charris speed hack
            unless(exists $indels_by_chrom->{$start}){
                next;
            }
            my @bed_line = $self->parse($call, $reference, $read);
            next unless scalar(@bed_line)>1;
            unless((@bed_line)&& scalar(@bed_line)==4){
                next;
            }
            my $type_and_size = $type."/".$size;
            $events{$bed_line[0]}{$bed_line[1]}{$type_and_size}{'neg'}=$neg_strand;
            $events{$bed_line[0]}{$bed_line[1]}{$type_and_size}{'pos'}=$pos_strand;
            $events{$bed_line[0]}{$bed_line[1]}{$type_and_size}{'bed'}=join("\t",@bed_line);
            if($normal_support){
                $events{$bed_line[0]}{$bed_line[1]}{$type_and_size}{'normal'}=$normal_support;
            }
        }
    }
    for $chrom (sort {$a cmp $b} (keys(%events))){
        for $pos (sort{$a <=> $b} (keys( %{$events{$chrom}}))){
            for my $type_and_size (sort(keys( %{$events{$chrom}{$pos}}))){
                unless(exists($events{$chrom}{$pos}{$type_and_size}{'normal'})&&(not $self->germline_events)){
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
                    my @stop = keys(%{$positions{$chrom}{$pos}});
                    #unless(scalar(@stop)==1){
                    #    
                    #    die "too many stop positions at ".$chrom." ".$pos."\n";
                    #}
                    my ($type,$size) = split /\//, $type_and_size;
                    #my $stop = ($type eq 'I') ? $pos+2 : $pos + $size;
                    my $stop = $pos;
                    my @results = `samtools view $tumor_bam $chrom:$pos-$stop | grep -v "XT:A:M"`;
                    if($self->germline_events){
                        push @results, `samtools view $tumor_bam $chrom:$pos-$stop | grep -v "XT:A:M"`;
                    }
                    my $read_support=0;
                    for my $result (@results){
                        #print $result;
                        chomp $result;
                        my @details = split /\t/, $result;
                        if($result =~ /NM:i:(\d+)/){
                            if($1>2){
                                next;
                            }
                        }
                        unless($details[5] =~ m/[ID]/){
                            if(($details[3] > ($pos - 40))&&($details[3] < ($pos -10))){
                                $read_support++;
                            }
                        }
                    }
                    my $bed_output = $events{$chrom}{$pos}{$type_and_size}{'bed'}."\t".$reads."\t".$read_support."\t".$pos_percent."\n";
                    print $output $bed_output;
                }
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
        my ($chr,$start,$stop,$refvar,$vs,$rs,$ps) = split "\t", $line;
        my $hq=1;
        unless($vs >= $self->min_variant_support){
            $hq = 0;
        }
        unless($vs/($vs+$rs) <= $self->var_to_ref_read_ratio){
            $hq = 0;
        }
        if($self->remove_single_stranded){
            unless(($ps != 1)&&($ps !=0)){
                $hq=0;
            }
        }
        if($hq==1){
            print $output join("\t", ($chr,$start,$stop,$refvar))."\n";
        }
        else {
            print $output_lq join("\t", ($chr,$start,$stop,$refvar))."\n";
        }
    }

    $input->close;
    $output->close;
    $output_lq->close;

    return 1;
}


1;
