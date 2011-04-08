package Genome::Model::Tools::DetectVariants2::Filter::PindelSomaticCalls;

use warnings;
use strict;

use Genome;

class Genome::Model::Tools::DetectVariants2::Filter::PindelSomaticCalls{
    is => 'Genome::Model::Tools::DetectVariants2::Filter',
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

    my $output_file = $self->_temp_staging_directory."/indels.hq.bed";
    my $output_lq_file = $self->_temp_staging_directory."/indels.lq.bed";
    my $indel_file = $self->input_directory."/indels.hq.bed";

    $self->find_somatic_events($indel_file, $output_file, $output_lq_file);

    return 1;
}

sub find_somatic_events {
    my $self = shift;
    my $indel_file = shift;
    my $output_file = shift;
    my $output_lq_file = shift;

    my $output = Genome::Sys->open_file_for_writing($output_file);
    my $output_lq = Genome::Sys->open_file_for_writing($output_lq_file);
    my %indels;
    my %answers;

    my $fh = Genome::Sys->open_file_for_reading($indel_file);
    while (my $line = $fh->getline){
        chomp $line;
        my ($chr,$start,$stop,$refvar) = split /\t/, $line;
        my ($ref,$var) = split "/", $refvar;
        $indels{$chr}{$start} = $refvar;
    }

    for my $chr (sort(keys(%indels))){
        my %indels_by_chr = %{$indels{$chr}};
        $self->process_file($chr, \%indels_by_chr, $output, $output_lq);
        delete $indels{$chr};
    }
    $output->close;
    $output_lq->close;

}

sub process_file {
    my $self = shift;
    my $chr = shift;
    my $indels_by_chrom = shift;
    my $output = shift;
    my $output_lq = shift;
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
                $read=$line;
            }
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
            unless(exists $indels_by_chrom->{$start}){
                next;
            }
            my @bed_line = $self->parse($call, $reference, $read);
            next unless scalar(@bed_line)>1;
            unless((@bed_line)&& scalar(@bed_line)==4){
                next;
            }
            my $type_and_size = $type."/".$size;
            $events{$bed_line[0]}{$bed_line[1]}{$type_and_size}{'bed'}=join("\t",@bed_line);
            if($normal_support){
                $events{$bed_line[0]}{$bed_line[1]}{$type_and_size}{'normal'}=$normal_support;
            }
        }
    }
    for $chrom (sort {$a cmp $b} (keys(%events))){
        for $pos (sort{$a <=> $b} (keys( %{$events{$chrom}}))){
            for my $type_and_size (sort(keys( %{$events{$chrom}{$pos}}))){
                if(not exists($events{$chrom}{$pos}{$type_and_size}{'normal'})){
                    my ($type,$size) = split /\//, $type_and_size;
                    my $stop = $pos;
                    my $bed_output = $events{$chrom}{$pos}{$type_and_size}{'bed'}."\n";
                    print $output $bed_output;
                }
                else {
                    my ($type,$size) = split /\//, $type_and_size;
                    my $stop = $pos;
                    my $bed_output = $events{$chrom}{$pos}{$type_and_size}{'bed'}."\n";
                    print $output_lq $bed_output;
                }
            }
        }
    }
}

sub parse {
    my $self = shift;
    my $reference_fasta = $self->reference_sequence_input;
    my ($call, $reference, $first_read) = @_;
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
        return undef;
    }
    my $refvar = "$ref/$var";
    return ($chr,$start,$stop,$refvar);
}

sub _check_file_counts {
    return 1;
}

sub _generate_standard_output {
    return 1;
}

1;
